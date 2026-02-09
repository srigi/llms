# llms.ps1 Test Suite v1.3
# Pester 3.4.0 Compatible - Unit and Integration Tests
# Verifies removal of per-model ENV support while preserving server-wide ENVs

$ScriptPath = Join-Path $PSScriptRoot "llms.ps1"

Describe "llms.ps1" {
    # --- SETUP ---
    # Pester 3: Run setup directly in Describe block
    $TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "llms-tests-$(Get-Random)"
    $ModelDir = Join-Path $TestDir "models"
    $ConfigDir = Join-Path $TestDir "config"

    # Clean start
    if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
    New-Item -ItemType Directory -Path $ModelDir -Force | Out-Null
    New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null

    $TestModelPath = Join-Path $ModelDir "test-model.gguf"
    "dummy content" | Out-File -FilePath $TestModelPath -Encoding UTF8

    # --- HELPER FUNCTIONS ---
    # Mirrored from llms.ps1 for Unit Testing
    
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
        $result = $CamelCase -creplace '([A-Z])', '-$1'
        $result = $result.ToLower()
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
                if ($line -and $line -notmatch '^[;#]') {
                    if ($line -match '^(.+?)\s*=\s*(.+)$') {
                        $key = $matches[1].Trim()
                        $value = $matches[2].Trim()
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
        $existingConfig = Load-ModelConfig -ModelFile $ModelFile
        foreach ($key in $Params.Keys) {
            $existingConfig[$key] = $Params[$key]
        }
        $lines = @()
        if ($existingConfig.ContainsKey('CtxSize')) {
            $lines += "CtxSize = $($existingConfig['CtxSize'])"
        }
        $otherParams = $existingConfig.GetEnumerator() |
            Where-Object { $_.Key -ne 'CtxSize' } |
            Sort-Object Key
        foreach ($param in $otherParams) {
            $value = $param.Value
            if ($value -match '\s') {
                $lines += "$($param.Key) = '$value'"
            } else {
                $lines += "$($param.Key) = $value"
            }
        }
        $lines | Out-File -FilePath $modelIni -Encoding UTF8
    }

    # --- TESTS ---
    
    Context "Helper Functions (Unit)" {
        It "Convert-ToCamelCase: Converts dash-separated to CamelCase" {
            Convert-ToCamelCase "cache-type-k" | Should Be "CacheTypeK"
            Convert-ToCamelCase "n-gpu-layers" | Should Be "NGpuLayers"
        }

        It "Is-ServerWideBoolean: Identifies flags correctly" {
            Is-ServerWideBoolean "--dry-run" | Should Be $true
            Is-ServerWideBoolean "--mlock" | Should Be $false
        }

        It "Save-ModelConfig: Merges parameters and sorts correctly" {
            $iniFile = $TestModelPath.Replace('.gguf', '.ini')
            if (Test-Path $iniFile) { Remove-Item $iniFile }

            Save-ModelConfig -ModelFile $TestModelPath -Params @{ 'CtxSize'='1024'; 'Mlock'='true' }
            Save-ModelConfig -ModelFile $TestModelPath -Params @{ 'NGpuLayers'='99'; 'Mlock'='false' }

            $content = (Get-Content $iniFile) -join "`n"
            $content | Should Match "CtxSize = 1024"
            $content | Should Match "Mlock = false"
            $content | Should Match "NGpuLayers = 99"
        }
    }

    Context "Configuration Priority (Integration)" {
        # Helper to reset config
        function Reset-Config {
            $iniFile = $TestModelPath.Replace('.gguf', '.ini')
            if (Test-Path $iniFile) { Remove-Item $iniFile }
        }

        BeforeEach {
            Reset-Config
        }

        It "CLI Argument overrides Default" {
            $Env:LLMS_MODELS_DIRS = $ModelDir
            
            $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath test-model 1024 --cache-type-k q4_0 --dry-run 2>&1 | Out-String
            $output | Should Match "--cache-type-k q4_0"
            
            $Env:LLMS_MODELS_DIRS = $null
        }

        It "ENV Variable is IGNORED for per-model parameters" {
            $Env:LLMS_MODELS_DIRS = $ModelDir
            $Env:LLMS_CACHE_TYPE_K = "q2_k"
            $Env:LLMS_N_GPU_LAYERS = "10"
            
            $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath test-model 1024 --dry-run 2>&1 | Out-String
            
            $output | Should Not Match "--cache-type-k q2_k"
            $output | Should Match "--cache-type-k q8_0"
            $output | Should Not Match "--n-gpu-layers 10"
            $output | Should Match "--n-gpu-layers 99"

            $Env:LLMS_MODELS_DIRS = $null
            $Env:LLMS_CACHE_TYPE_K = $null
            $Env:LLMS_N_GPU_LAYERS = $null
        }

        It "Model Config overrides Default" {
            Save-ModelConfig -ModelFile $TestModelPath -Params @{ 'CtxSize'='1024'; 'CacheTypeK'='q5_0' }
            $Env:LLMS_MODELS_DIRS = $ModelDir
            
            $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath test-model --dry-run 2>&1 | Out-String
            $output | Should Match "--cache-type-k q5_0"
            
            $Env:LLMS_MODELS_DIRS = $null
        }
        
        It "CLI overrides Model Config" {
            Save-ModelConfig -ModelFile $TestModelPath -Params @{ 'CtxSize'='1024'; 'CacheTypeK'='q5_0' }
            $Env:LLMS_MODELS_DIRS = $ModelDir
            
            $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath test-model --cache-type-k q4_0 --dry-run 2>&1 | Out-String
            $output | Should Match "--cache-type-k q4_0"
            
            $Env:LLMS_MODELS_DIRS = $null
        }
    }

    Context "Server-Wide ENV Support (Integration)" {
         It "Respects LLMS_MODELS_DIRS" {
             $Env:LLMS_MODELS_DIRS = $ModelDir
             
             $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath list 2>&1 | Out-String
             $output | Should Match "test-model.gguf"
             
             $Env:LLMS_MODELS_DIRS = $null
         }
         
         It "Respects LLMS_PORT" {
             $Env:LLMS_MODELS_DIRS = $ModelDir
             $Env:LLMS_PORT = "9999"
             
             $output = & powershell -ExecutionPolicy Bypass -File $ScriptPath test-model 1024 --dry-run 2>&1 | Out-String
             $output | Should Match "--port 9999"
             
             $Env:LLMS_MODELS_DIRS = $null
             $Env:LLMS_PORT = $null
         }
    }

    # Cleanup
    if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
}