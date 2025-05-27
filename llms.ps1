#!/usr/bin/env pwsh

param(
    [Parameter(Position=0)]
    [string]$ModelPattern,
    [Parameter(Position=1)]
    [int]$CtxSize,
    [Parameter(ValueFromRemainingArguments)]
    [string[]]$LlamaServerArgs
)

if (-not $ModelPattern) {
    $ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

    Write-Host "usage:`n  $ScriptName list`n  $ScriptName <partial_model_name> <context_size> [llama-server args...] [--dry-run]"
    Write-Host "`nexample:`n  $ScriptName list`n  $ScriptName Devstral-Small-2505-UD 24000`n  $ScriptName Mistral-Small-3.1-24B 32000 --jinja`n  $ScriptName Mistral-Small-3.1-24B 32000 --jinja --dry-run`n"
    exit 1
}

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
$ModelsDirs = $Env:LLMS_MODELS_DIRS -split ',' | Where-Object { $_ } # drop any empty entries
if (-not $ModelsDirs -or $ModelsDirs.Count -eq 0) {
    $ModelsDirs = ($config | Where-Object Key -eq 'ModelsDirs').Value -split ',' | Where-Object { $_ }
}
if (-not $ModelsDirs -or $ModelsDirs.Count -eq 0) {
    Write-Host "`e[91mError:`e[39m `e[95mModelsDirs`e[39m not configured (either by ENV variable `e[94mLLMS_MODELS_DIRS`e[39m, or in `e[94mllms.ini`e[39m file)!`n"
    exit 1
}

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

# Find the model file
$modelFile = $null
foreach ($dir in $ModelsDirs) {
    $modelFile = Get-ChildItem -Path $dir -Filter "*$ModelPattern*.gguf" -File -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($modelFile) {
        break # Found the model, exit the loop
    }
}

if (-not $modelFile) {
    Write-Host "`e[91mError:`e[39m No model file found matching '*$ModelPattern*.gguf' in any of the configured directories:`n  $($ModelsDirs -join ', ')`n"
    exit 1
}
$modelName = [System.IO.Path]::GetFileNameWithoutExtension($modelFile.Name)
Write-Host -NoNewline "Using model: `e[38;5;117m$($modelFile.FullName)`e[39m"

# Set CtxSize from cli arg
if (-not $PSBoundParameters.ContainsKey('CtxSize')) {
    Write-Host "`n`e[91mError:`e[39m You must specify a <context_size> parameter!`n"
    exit 1
}
Write-Host " (context size: `e[38;5;226m$CtxSize`e[39m)"

# Check for mmproj files
$mmprojFiles = Get-ChildItem -Path $modelFile.DirectoryName -Filter "$($modelFile.BaseName).mmproj-*.gguf" -File -ErrorAction SilentlyContinue
if ($mmprojFiles -and $mmprojFiles.Count -gt 0) {
    $mmprojFile = $mmprojFiles[0]
    $LlamaServerArgs += "--mmproj", "$($mmprojFile.FullName)"
    $LlamaServerArgs += "--no-mmproj-offload"
    Write-Host "Adding companion model: `e[38;5;117m$($mmprojFile.FullName)`e[39m"
} else {
    $LlamaServerArgs += "--no-mmproj"
}

# Assemble the command
$cmdArgs = @(
    "llama-server"
) + $LlamaServerArgs + @(
    "--model '$($modelFile.FullName)'"
    "--ctx-size $CtxSize"
    "--cache-type-k $(($Env:LLMS_CACHE_TYPE_K ?? ($config | Where-Object Key -eq 'CacheTypeK').Value) ?? "q8_0")"
    "--cache-type-v $(($Env:LLMS_CACHE_TYPE_V ?? ($config | Where-Object Key -eq 'CacheTypeV').Value) ?? "q8_0")"
    "--ubatch-size $(($Env:LLMS_UBATCH_SIZE ?? ($config | Where-Object Key -eq 'UbatchSize').Value) ?? 1024)"
    "--n-gpu-layers $(($Env:LLMS_N_GPU_LAYERS ?? ($config | Where-Object Key -eq 'NGpuLayers').Value) ?? 999)"
    "--flash-attn"
    "--threads $([Environment]::ProcessorCount)"
    "--host $(($Env:LLMS_HOST ?? ($config | Where-Object Key -eq 'Host').Value) ?? "127.0.0.1")"
    "--port $(($Env:LLMS_PORT ?? ($config | Where-Object Key -eq 'Port').Value) ?? "8080")"
    "--api-key $(($Env:LLMS_API_KEY ?? ($config | Where-Object Key -eq 'ApiKey').Value) ?? "secret")"
)
$command = $cmdArgs -join ' '

if ($LlamaServerArgs -contains "--dry-run") {
    # remove --dry-run from the command for display
    $displayCommand = $command -replace ' --dry-run', ''
    # replace the API key value with asterisks
    $displayCommand = $displayCommand -replace '--api-key [^ ]+', '--api-key ****'
    Write-Host ("Dry run: $displayCommand" -replace ' --', "`n  --")
    exit 0
}

# Execute the command
Invoke-Expression $command
