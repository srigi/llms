#!/usr/bin/env pwsh

param(
    [Parameter(Position=0)]
    [string]$ModelPattern,
    [Parameter(Position=1)]
    [int]$CtxSize
)

$DefaultContextSize = 20000
$ModelsDirs = $Env:LLMS_MODELS_DIRS -split ','

function Get-ModelsDirsFromIni {
    param([string]$filePath)

    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        if ($content -match '^\s*ModelsDirs\s*=\s*([^\r\n]*)') {
            return ($Matches[1] -split ',') | ForEach-Object { $_.Trim() }
        }
    }

    return $null
}

if (-not $ModelsDirs -or $ModelsDirs.Length -eq 0) {
    # try load ModelsDirs from .ini file in the current directory
    $ModelsDirs = Get-ModelsDirsFromIni $(Join-Path $PSScriptRoot "llms.ini")
}
if (-not $ModelsDirs -or $ModelsDirs.Length -eq 0) {
    # try load ModelsDirs from .ini file in AppData/Local
    $appDataPath = [Environment]::GetFolderPath("LocalApplicationData")
    $ModelsDirs = Get-ModelsDirsFromIni $(Join-Path $appDataPath "llms.ini")
}
if (-not $ModelsDirs -or $ModelsDirs.Length -eq 0) {
    Write-Host "`e[91mError:`e[39m `e[95mModelsDirs`e[39m not configured (either by ENV variable `e[94mLLMS_MODELS_DIRS`e[39m, or in `e[94mllms.ini`e[39m file)!`n"
    exit 1
}

if (-not $ModelPattern) {
    $ScriptName = [System.IO.Path]::GetFileNameWithoutExtension($PSCommandPath)

    Write-Host "usage:`n  $ScriptName [list | <partial_model_name>]`n  $ScriptName [<partial_model_name>] [<context_size>]"
    Write-Host "`nexample:`n  $ScriptName list`n  $ScriptName codethink 15000"
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
Write-Host -NoNewline "Using model: $modelName"

# Ensure context.ini exists in the model's directory
$contextIni = Join-Path $modelFile.DirectoryName "context.ini"
if (-not (Test-Path $contextIni)) {
    New-Item -Path $contextIni -ItemType File | Out-Null
}

# Set CtxSize, either from cli arg, or by reading from .ini file, or use default (safe) value
if ($PSBoundParameters.ContainsKey('CtxSize')) {
    $lines = Get-Content $contextIni | Where-Object { -not ($_ -match "^$modelName=") }
    if (-not $lines) {
        $lines = @()
    } elseif ($lines -is [string]) {
        $lines = @($lines)
    }
    $lines += "$modelName=$CtxSize"

    Set-Content $contextIni -Value $lines
} else {
    $entry = Select-String "^$modelName=" $contextIni | Select-Object -First 1
    if ($entry) {
        $CtxSize = $entry.Line.Split('=')[1]
    } else {
        $CtxSize = $DefaultContextSize
    }
}
Write-Host " (context size: $CtxSize)"

# Run llama-server with found model
llama-server `
    --model "$($modelFile.FullName)" `
    --ctx-size "$CtxSize" `
    --n-gpu-layers 99 `
    --threads "$([Environment]::ProcessorCount)" `
    --host "$($Env:LLMS_HOST ?? "127.0.0.1")" `
    --port "$($Env:LLMS_PORT ?? "8080")" `
    --api-key "$($Env:LLMS_API_KEY ?? "secret")"
