param(
    [Parameter(Position=0)]
    [ValidateNotNullOrEmpty()]
    [string]$ModelPattern,

    [Parameter(ValueFromRemainingArguments)]
    [string[]]$RemainingArgs = @()
)

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

function Convert-ToCamelCase {
    param([string]$DashSeparated)

    $parts = $DashSeparated -split '-'
    $result = ''
    foreach ($part in $parts) {
        if ($part.Length -gt 0) {
            $result += $part.Substring(0, 1).ToUpper() + $part.Substring(1)
        }
    }
    return $result
}

function Convert-ToDashSeparated {
    param([string]$CamelCase)

    # Insert dash before uppercase letters and convert to lowercase
    $result = $CamelCase -creplace '([A-Z])', '-$1'
    $result = $result.ToLower()
    # Remove leading dash if present
    if ($result.StartsWith('-')) {
        $result = $result.Substring(1)
    }
    return $result
}

function Is-ServerWideBoolean {
    param([string]$Flag)

    $serverWideBooleans = @(
        '--help', '--usage', '--version', '--completion-bash', '--list-devices',
        '--log-disable', '--log-prefix', '--log-timestamps', '--verbose', '--log-verbose',
        '--offline', '--no-webui',
        '--reranking', '--rerank',
        '--metrics', '--props', '--slots', '--no-slots',
        '--dry-run',
        '-h', '-v'
    )

    return $serverWideBooleans -contains $Flag
}

function Load-ModelConfig {
    param([string]$ModelFile)

    $modelIni = [System.IO.Path]::ChangeExtension($ModelFile, '.ini')
    $config = @{}

    if (Test-Path $modelIni) {
        Get-Content $modelIni | ForEach-Object {
            $line = $_.Trim()
            # Skip empty lines and comments
            if ($line -and $line -notmatch '^[;#]') {
                if ($line -match '^(.+?)\s*=\s*(.+)$') {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    # Remove quotes if present
                    $value = $value -replace '^[''"]|[''"]$', ''
                    $config[$key] = $value
                }
            }
        }
    }

    return $config
}

function Save-ModelConfig {
    param(
        [string]$ModelFile,
        [hashtable]$Params
    )

    $modelIni = [System.IO.Path]::ChangeExtension($ModelFile, '.ini')

    # Load existing config and merge with new params
    $existingConfig = Load-ModelConfig -ModelFile $ModelFile

    # Merge: new params override existing ones
    foreach ($key in $Params.Keys) {
        $existingConfig[$key] = $Params[$key]
    }

    # Build content with CtxSize first, then alphabetically sorted
    $lines = @()

    if ($existingConfig.ContainsKey('CtxSize')) {
        $lines += "CtxSize = $($existingConfig['CtxSize'])"
    }

    # Add other parameters alphabetically
    $otherParams = $existingConfig.GetEnumerator() |
        Where-Object { $_.Key -ne 'CtxSize' } |
        Sort-Object Key

    foreach ($param in $otherParams) {
        $value = $param.Value
        # Add quotes if value contains spaces
        if ($value -match '\s') {
            $lines += "$($param.Key) = '$value'"
        } else {
            $lines += "$($param.Key) = $value"
        }
    }

    # Write to file
    $lines | Out-File -FilePath $modelIni -Encoding UTF8
}

function Show-Help {
    $ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

    Write-Output "version 1.2"
    Write-Output ""
    Write-Output "usage:"
    Write-Output "  $ScriptName list"
    Write-Output "  $ScriptName <partial_model_name> [<context_size>] [llama-server args...] [--dry-run]"
    Write-Output ""
    Write-Output "example:"
    Write-Output "  $ScriptName list"
    Write-Output "  $ScriptName Devstral-Small-2505-UD 24000"
    Write-Output "  $ScriptName Mistral-Small-3.1-24B 32000 --jinja"
    Write-Output "  $ScriptName Mistral-Small-3.1-24B 32000 --jinja --dry-run"
    Write-Output "  $ScriptName Mistral-Small-3.1-24B  # uses saved config"
    Write-Output ""
}

# ============================================================================
# CONFIGURATION LOADING
# ============================================================================

if (-not $ModelPattern) {
    Show-Help
    exit 1
}

# Load global config files
$appDataPath = [Environment]::GetFolderPath("LocalApplicationData")
$iniFile = @(
    Join-Path $PSScriptRoot 'llms.ini'
    Join-Path $appDataPath  'llms.ini'
) | Where-Object { Test-Path $_ } | Select-Object -First 1

$config = if ($iniFile) {
    Get-Content $iniFile |
        Where-Object { $_ -and $_ -notmatch '^\s*[;#]' -and ($_ -split '=',2).Count -eq 2 } |
        ForEach-Object {
            $parts = $_ -split '=',2
            [PSCustomObject]@{
                Key = $parts[0].Trim()
                Value = $parts[1].Trim()
            }
        }
} else { @() }

# Get ModelsDirs from ENV or config
$ModelsDirs = $Env:LLMS_MODELS_DIRS -split ',' | Where-Object { $_ }
if (-not $ModelsDirs -or $ModelsDirs.Count -eq 0) {
    $ModelsDirs = ($config | Where-Object Key -eq 'ModelsDirs').Value -split ',' | Where-Object { $_ }
}
if (-not $ModelsDirs -or $ModelsDirs.Count -eq 0) {
    Write-Host "`e[91mError:`e[39m `e[95mModelsDirs`e[39m not configured (either by ENV variable `e[94mLLMS_MODELS_DIRS`e[39m, or in `e[94mllms.ini`e[39m file)!`n"
    exit 1
}

# ============================================================================
# LIST MODELS
# ============================================================================

if ($ModelPattern -eq "list") {
    Write-Host "Searching for .gguf models in:"
    $foundModels = $false
    foreach ($dir in $ModelsDirs) {
        Write-Host "`n  $dir`:"
        $modelFiles = Get-ChildItem -Path $dir -Filter "*.gguf" -File -ErrorAction SilentlyContinue
        if ($modelFiles) {
            $foundModels = $true
            $modelFiles | ForEach-Object {
                $sizeGB = [math]::Round($_.Length / 1GB, 2)
                $padding = if ($sizeGB -lt 10) { "( " } else { "(" }
                $sizeFormatted = "{0:N2}GB)" -f $sizeGB
                Write-Host "    `e[38;5;244m$padding$sizeFormatted`e[39m $($_.Name)"
            }
        } else {
            Write-Host "    No models found"
        }
    }
    if (-not $foundModels) {
        Write-Host "`n`e[91mError:`e[39m No models found in any configured directory!`n"
        exit 1
    }
    exit 0
}

# ============================================================================
# FIND MODEL FILE
# ============================================================================

$modelFile = $null
foreach ($dir in $ModelsDirs) {
    $modelFile = Get-ChildItem -Path $dir -Filter "*$ModelPattern*.gguf" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($modelFile) {
        break
    }
}

if (-not $modelFile) {
    Write-Host "`e[91mError:`e[39m No model file found matching '*$ModelPattern*.gguf' in any of the configured directories:`n  $($ModelsDirs -join ', ')`n"
    exit 1
}
Write-Host -NoNewline "Using model: `e[38;5;117m$($modelFile.FullName)`e[39m"

# Load per-model configuration
$ModelConfig = Load-ModelConfig -ModelFile $modelFile.FullName

# ============================================================================
# PARSE CLI ARGUMENTS
# ============================================================================

$cliArgs = @()           # Key-value pairs: @(@{key='--cache-type-k'; value='q4_0'})
$cliBooleans = @()       # Boolean flags: @('--mlock', '--jinja')
$passthroughArgs = @()   # Server-wide flags: @('--no-webui', '--dry-run')
$ctxSize = $null
$hasCliCtxSize = $false

# Check if first remaining arg is a number (context size)
if ($RemainingArgs.Count -gt 0 -and $RemainingArgs[0] -match '^\d+$') {
    $ctxSize = $RemainingArgs[0]
    $hasCliCtxSize = $true
    # Skip the context size argument
    if ($RemainingArgs.Count -gt 1) {
        $remainingArgsToProcess = $RemainingArgs[1..($RemainingArgs.Count - 1)]
    } else {
        $remainingArgsToProcess = @()
    }
} else {
    $remainingArgsToProcess = $RemainingArgs
}

# Parse remaining arguments
$i = 0
while ($i -lt $remainingArgsToProcess.Count) {
    $arg = $remainingArgsToProcess[$i]

    if ($arg -match '^--') {
        # Check if next arg exists and is not a flag
        if (($i + 1) -lt $remainingArgsToProcess.Count -and $remainingArgsToProcess[$i + 1] -notmatch '^-') {
            # Key-value pair
            $cliArgs += @{key = $arg; value = $remainingArgsToProcess[$i + 1]}
            $i += 2
        } else {
            # Boolean flag
            if (Is-ServerWideBoolean $arg) {
                $passthroughArgs += $arg
            } else {
                $cliBooleans += $arg
            }
            $i++
        }
    } elseif ($arg -match '^-') {
        # Short flag
        if (Is-ServerWideBoolean $arg) {
            $passthroughArgs += $arg
        } else {
            $cliBooleans += $arg
        }
        $i++
    } else {
        # Unknown argument, pass through
        $passthroughArgs += $arg
        $i++
    }
}

# ============================================================================
# DETERMINE CONTEXT SIZE
# ============================================================================

if (-not $ctxSize) {
    if ($ModelConfig.ContainsKey('CtxSize')) {
        $ctxSize = $ModelConfig['CtxSize']
    } else {
        Write-Host "`n`e[91mError:`e[39m You must specify a <context_size> parameter or have a saved model configuration!`n"
        Show-Help
        exit 1
    }
}
Write-Host " (context size: `e[38;5;226m$ctxSize`e[39m)"

# ============================================================================
# CHECK FOR MMPROJ FILES
# ============================================================================

$mmprojArgs = @()
$mmprojFiles = Get-ChildItem -Path $modelFile.DirectoryName -Filter "$($modelFile.BaseName).mmproj-*.gguf" -File -ErrorAction SilentlyContinue
if ($mmprojFiles -and $mmprojFiles.Count -gt 0) {
    $mmprojFile = $mmprojFiles[0]
    $mmprojArgs += "--mmproj"
    $mmprojArgs += $mmprojFile.FullName
    $mmprojArgs += "--no-mmproj-offload"
    Write-Host "Adding companion model: `e[38;5;117m$($mmprojFile.FullName)`e[39m"
} else {
    $mmprojArgs += "--no-mmproj"
}

# ============================================================================
# CONFIGURATION PRIORITY: CLI > ENV > ModelConfig > Default
# ============================================================================

$DEFAULT_CACHE_TYPE_K = "q8_0"
$DEFAULT_CACHE_TYPE_V = "q8_0"
$DEFAULT_N_GPU_LAYERS = "99"
$DEFAULT_HOST = "127.0.0.1"
$DEFAULT_PORT = "8080"
$DEFAULT_API_KEY = "secret"

# Helper function to get CLI arg value
function Get-CliArgValue {
    param([string]$Key)
    $match = $cliArgs | Where-Object { $_.key -eq $Key } | Select-Object -First 1
    if ($match) { return $match.value }
    return $null
}

# CacheTypeK
$cacheTypeK = Get-CliArgValue '--cache-type-k'
if (-not $cacheTypeK) { $cacheTypeK = $Env:LLMS_CACHE_TYPE_K }
if (-not $cacheTypeK) { $cacheTypeK = $ModelConfig['CacheTypeK'] }
if (-not $cacheTypeK) { $cacheTypeK = $DEFAULT_CACHE_TYPE_K }

# CacheTypeV
$cacheTypeV = Get-CliArgValue '--cache-type-v'
if (-not $cacheTypeV) { $cacheTypeV = $Env:LLMS_CACHE_TYPE_V }
if (-not $cacheTypeV) { $cacheTypeV = $ModelConfig['CacheTypeV'] }
if (-not $cacheTypeV) { $cacheTypeV = $DEFAULT_CACHE_TYPE_V }

# NGpuLayers
$nGpuLayers = Get-CliArgValue '--n-gpu-layers'
if (-not $nGpuLayers) { $nGpuLayers = $Env:LLMS_N_GPU_LAYERS }
if (-not $nGpuLayers) { $nGpuLayers = $ModelConfig['NGpuLayers'] }
if (-not $nGpuLayers) { $nGpuLayers = $DEFAULT_N_GPU_LAYERS }

# FlashAttn
$flashAttn = Get-CliArgValue '--flash-attn'
if (-not $flashAttn) { $flashAttn = $Env:LLMS_FLASH_ATTN }
if (-not $flashAttn) { $flashAttn = $ModelConfig['FlashAttn'] }

# Server-wide parameters (ENV > config > default)
$serverHost = if ($Env:LLMS_HOST) { $Env:LLMS_HOST } elseif (($config | Where-Object Key -eq 'Host').Value) { ($config | Where-Object Key -eq 'Host').Value } else { $DEFAULT_HOST }
$serverPort = if ($Env:LLMS_PORT) { $Env:LLMS_PORT } elseif (($config | Where-Object Key -eq 'Port').Value) { ($config | Where-Object Key -eq 'Port').Value } else { $DEFAULT_PORT }
$apiKey = if ($Env:LLMS_API_KEY) { $Env:LLMS_API_KEY } elseif (($config | Where-Object Key -eq 'ApiKey').Value) { ($config | Where-Object Key -eq 'ApiKey').Value } else { $DEFAULT_API_KEY }

$threads = [Environment]::ProcessorCount

# ============================================================================
# BUILD ADDITIONAL ARGS FROM CLI AND MODEL CONFIG
# ============================================================================

$additionalArgs = @()

# Add CLI args (custom parameters - skip core ones)
$coreParams = @('--cache-type-k', '--cache-type-v', '--n-gpu-layers', '--flash-attn')
foreach ($arg in $cliArgs) {
    if ($arg.key -notin $coreParams) {
        $additionalArgs += $arg.key
        $additionalArgs += $arg.value
    }
}

# Add CLI booleans
foreach ($flag in $cliBooleans) {
    $additionalArgs += $flag
}

# Add args from model config (if not in CLI)
$coreConfigKeys = @('CtxSize', 'CacheTypeK', 'CacheTypeV', 'NGpuLayers', 'FlashAttn')
foreach ($key in $ModelConfig.Keys) {
    if ($key -in $coreConfigKeys) {
        continue
    }

    $flagName = Convert-ToDashSeparated $key

    # Skip if already in CLI
    $inCli = $false
    foreach ($cliArg in $cliArgs) {
        if ($cliArg.key -eq "--$flagName") {
            $inCli = $true
            break
        }
    }
    foreach ($cliBoolean in $cliBooleans) {
        if ($cliBoolean -eq "--$flagName") {
            $inCli = $true
            break
        }
    }

    if (-not $inCli) {
        $value = $ModelConfig[$key]
        if ($value -eq 'true') {
            $additionalArgs += "--$flagName"
        } else {
            $additionalArgs += "--$flagName"
            $additionalArgs += $value
        }
    }
}

# ============================================================================
# ASSEMBLE COMMAND
# ============================================================================

$llmsArgsList = [System.Collections.Generic.List[string]]::new()
if ($passthroughArgs) { $llmsArgsList.AddRange([string[]]$passthroughArgs) }
if ($additionalArgs) { $llmsArgsList.AddRange([string[]]$additionalArgs) }
if ($mmprojArgs) { $llmsArgsList.AddRange([string[]]$mmprojArgs) }

$llmsArgsList.Add("--model")
$llmsArgsList.Add($modelFile.FullName)

if ($ctxSize) { $llmsArgsList.Add("--ctx-size"); $llmsArgsList.Add($ctxSize) }
if ($cacheTypeK) { $llmsArgsList.Add("--cache-type-k"); $llmsArgsList.Add($cacheTypeK) }
if ($cacheTypeV) { $llmsArgsList.Add("--cache-type-v"); $llmsArgsList.Add($cacheTypeV) }
if ($nGpuLayers) { $llmsArgsList.Add("--n-gpu-layers"); $llmsArgsList.Add($nGpuLayers) }
if ($flashAttn) { $llmsArgsList.Add("--flash-attn"); $llmsArgsList.Add($flashAttn) }
if ($threads) { $llmsArgsList.Add("--threads"); $llmsArgsList.Add($threads) }
if ($serverHost) { $llmsArgsList.Add("--host"); $llmsArgsList.Add($serverHost) }
if ($serverPort) { $llmsArgsList.Add("--port"); $llmsArgsList.Add($serverPort) }
if ($apiKey) { $llmsArgsList.Add("--api-key"); $llmsArgsList.Add($apiKey) }

$llmsArgs = $llmsArgsList.ToArray()

# Build command string for dry-run display (with proper quoting)
$commandParts = @("llama-server")
foreach ($arg in $llmsArgs) {
    if ($arg -match '\s') {
        $commandParts += "`"$arg`""
    } else {
        $commandParts += $arg
    }
}
$commandString = $commandParts -join ' '

# ============================================================================
# DRY-RUN MODE
# ============================================================================

$isDryRun = $passthroughArgs -contains '--dry-run'

if ($isDryRun) {
    # Remove --dry-run from display
    $displayCmd = $commandString -replace ' --dry-run', ''
    # Replace API key with asterisks
    $displayCmd = $displayCmd -replace "--api-key [^ ]+", "--api-key ****"
    # Format with line breaks
    Write-Host ("Dry run: " + ($displayCmd -replace ' --', "`n  --"))
    exit 0
}

# ============================================================================
# SAVE MODEL CONFIGURATION
# ============================================================================

$shouldSave = ($hasCliCtxSize -or $cliArgs.Count -gt 0 -or $cliBooleans.Count -gt 0)

if ($shouldSave) {
    $configParams = @{}

    # Always include CtxSize
    $configParams['CtxSize'] = $ctxSize

    # Add known parameters if non-default AND came from CLI (not ENV)
    # Only save if CLI arg was provided, otherwise ENV overrides would be persisted
    $cliCacheTypeK = Get-CliArgValue '--cache-type-k'
    if ($cliCacheTypeK -and $cacheTypeK -ne $DEFAULT_CACHE_TYPE_K) {
        $configParams['CacheTypeK'] = $cacheTypeK
    }

    $cliCacheTypeV = Get-CliArgValue '--cache-type-v'
    if ($cliCacheTypeV -and $cacheTypeV -ne $DEFAULT_CACHE_TYPE_V) {
        $configParams['CacheTypeV'] = $cacheTypeV
    }

    $cliNGpuLayers = Get-CliArgValue '--n-gpu-layers'
    if ($cliNGpuLayers -and $nGpuLayers -ne $DEFAULT_N_GPU_LAYERS) {
        $configParams['NGpuLayers'] = $nGpuLayers
    }

    $cliFlashAttn = Get-CliArgValue '--flash-attn'
    if ($cliFlashAttn) {
        $configParams['FlashAttn'] = $flashAttn
    }

    # Add CLI args (custom parameters)
    foreach ($arg in $cliArgs) {
        $paramName = $arg.key -replace '^--', ''
        $camelKey = Convert-ToCamelCase $paramName
        if ($camelKey -notin @('CacheTypeK', 'CacheTypeV', 'NGpuLayers', 'FlashAttn')) {
            $configParams[$camelKey] = $arg.value
        }
    }

    # Add CLI booleans
    foreach ($flag in $cliBooleans) {
        $flagName = $flag -replace '^--', ''
        $camelKey = Convert-ToCamelCase $flagName
        $configParams[$camelKey] = 'true'
    }

    Save-ModelConfig -ModelFile $modelFile.FullName -Params $configParams
}

# ============================================================================
# EXECUTE COMMAND
# ============================================================================

& llama-server $llmsArgs
