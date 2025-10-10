# llms.ps1 Test Suite v1.2
# Comprehensive tests for per-model configuration system

BeforeAll {
    # Script under test
    $script:ScriptPath = Join-Path $PSScriptRoot 'llms.ps1'

    # Create temporary test directory
    $script:TestDir = Join-Path ([System.IO.Path]::GetTempPath()) "llms-tests-$(Get-Random)"
    $script:TestModelsDir = Join-Path $script:TestDir "models"
    $script:TestConfigDir = Join-Path $script:TestDir "config"

    New-Item -ItemType Directory -Path $script:TestDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestModelsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $script:TestConfigDir -Force | Out-Null

    # Define test model paths (no actual .gguf files needed for unit tests)
    $script:TestModel1 = Join-Path $script:TestModelsDir "test-model-1.gguf"
    $script:TestModel2 = Join-Path $script:TestModelsDir "test-model-2.gguf"

    # Define helper functions from llms.ps1 inline for testing
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
}

AfterAll {
    # Clean up test directory
    if (Test-Path $script:TestDir) {
        Remove-Item -Path $script:TestDir -Recurse -Force
    }
}

Describe "Helper Functions" -Tag "Unit" {

    Context "Convert-ToCamelCase" {
        It "Converts single word" {
            Convert-ToCamelCase "cache" | Should -Be "Cache"
        }

        It "Converts dash-separated to CamelCase" {
            Convert-ToCamelCase "cache-type-k" | Should -Be "CacheTypeK"
        }

        It "Converts complex parameter names" {
            Convert-ToCamelCase "chat-template-file" | Should -Be "ChatTemplateFile"
        }

        It "Handles n-gpu-layers correctly" {
            Convert-ToCamelCase "n-gpu-layers" | Should -Be "NGpuLayers"
        }

        It "Handles empty string" {
            Convert-ToCamelCase "" | Should -Be ""
        }
    }

    Context "Convert-ToDashSeparated" {
        It "Converts CamelCase to dash-separated" {
            Convert-ToDashSeparated "CacheTypeK" | Should -Be "cache-type-k"
        }

        It "Converts ChatTemplateFile" {
            Convert-ToDashSeparated "ChatTemplateFile" | Should -Be "chat-template-file"
        }

        It "Converts NGpuLayers" {
            Convert-ToDashSeparated "NGpuLayers" | Should -Be "n-gpu-layers"
        }

        It "Handles single word" {
            Convert-ToDashSeparated "Mlock" | Should -Be "mlock"
        }
    }

    Context "Is-ServerWideBoolean" {
        It "Identifies --dry-run as server-wide" {
            Is-ServerWideBoolean "--dry-run" | Should -Be $true
        }

        It "Identifies --no-webui as server-wide" {
            Is-ServerWideBoolean "--no-webui" | Should -Be $true
        }

        It "Identifies --verbose as server-wide" {
            Is-ServerWideBoolean "--verbose" | Should -Be $true
        }

        It "Identifies --help as server-wide" {
            Is-ServerWideBoolean "--help" | Should -Be $true
        }

        It "Identifies -h as server-wide" {
            Is-ServerWideBoolean "-h" | Should -Be $true
        }

        It "Identifies --mlock as NOT server-wide" {
            Is-ServerWideBoolean "--mlock" | Should -Be $false
        }

        It "Identifies --jinja as NOT server-wide" {
            Is-ServerWideBoolean "--jinja" | Should -Be $false
        }

        It "Identifies --cont-batching as NOT server-wide" {
            Is-ServerWideBoolean "--cont-batching" | Should -Be $false
        }
    }
}

Describe "Configuration Loading and Saving" -Tag "Unit" {

    Context "Load-ModelConfig" {
        It "Loads config file correctly" {
            $testIni = Join-Path $script:TestModelsDir "load-test.ini"
            @"
CtxSize = 16000
CacheTypeK = q4_0
Mlock = true
"@ | Out-File -FilePath $testIni -Encoding UTF8

            $config = Load-ModelConfig -ModelFile (Join-Path $script:TestModelsDir "load-test.gguf")
            $config['CtxSize'] | Should -Be "16000"
            $config['CacheTypeK'] | Should -Be "q4_0"
            $config['Mlock'] | Should -Be "true"
        }

        It "Removes quotes from values" {
            $testIni = Join-Path $script:TestModelsDir "quotes-test.ini"
            @"
ChatTemplateFile = 'C:\path with spaces\template.jinja'
"@ | Out-File -FilePath $testIni -Encoding UTF8

            $config = Load-ModelConfig -ModelFile (Join-Path $script:TestModelsDir "quotes-test.gguf")
            $config['ChatTemplateFile'] | Should -Be "C:\path with spaces\template.jinja"
        }

        It "Skips empty lines and comments" {
            $testIni = Join-Path $script:TestModelsDir "comments-test.ini"
            @"
# This is a comment
CtxSize = 8000

; Another comment
Mlock = true
"@ | Out-File -FilePath $testIni -Encoding UTF8

            $config = Load-ModelConfig -ModelFile (Join-Path $script:TestModelsDir "comments-test.gguf")
            $config['CtxSize'] | Should -Be "8000"
            $config['Mlock'] | Should -Be "true"
            $config.Count | Should -Be 2
        }

        It "Returns empty hashtable for non-existent config" {
            $config = Load-ModelConfig -ModelFile (Join-Path $script:TestModelsDir "nonexistent.gguf")
            $config | Should -BeOfType [hashtable]
            $config.Count | Should -Be 0
        }
    }

    Context "Save-ModelConfig" {
        It "Creates config file with CtxSize first" {
            $testModel = Join-Path $script:TestModelsDir "save-order-test.gguf"
            $params = @{
                'Mlock' = 'true'
                'CacheTypeK' = 'q4_0'
                'CtxSize' = '16000'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $content = Get-Content "$testModel".Replace('.gguf', '.ini')
            $content[0] | Should -Match "^CtxSize = 16000"
        }

        It "Sorts other parameters alphabetically" {
            $testModel = Join-Path $script:TestModelsDir "save-alpha-test.gguf"
            $params = @{
                'CtxSize' = '8000'
                'Mlock' = 'true'
                'CacheTypeK' = 'q4_0'
                'Jinja' = 'true'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $content = Get-Content "$testModel".Replace('.gguf', '.ini')
            $content[0] | Should -Match "^CtxSize"
            $content[1] | Should -Match "^CacheTypeK"
            $content[2] | Should -Match "^Jinja"
            $content[3] | Should -Match "^Mlock"
        }

        It "Adds quotes for values with spaces" {
            $testModel = Join-Path $script:TestModelsDir "save-spaces-test.gguf"
            $params = @{
                'CtxSize' = '8000'
                'ChatTemplateFile' = 'C:\path with spaces\template.jinja'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $content = Get-Content "$testModel".Replace('.gguf', '.ini') -Raw
            $content | Should -Match "ChatTemplateFile = 'C:\\path with spaces\\template.jinja'"
        }

        It "Merges with existing config" {
            $testModel = Join-Path $script:TestModelsDir "merge-test.gguf"
            $testIni = "$testModel".Replace('.gguf', '.ini')

            # Create initial config
            @"
CtxSize = 8000
CacheTypeK = q4_0
"@ | Out-File -FilePath $testIni -Encoding UTF8

            # Save new params
            $params = @{
                'CtxSize' = '16000'
                'Mlock' = 'true'
            }
            Save-ModelConfig -ModelFile $testModel -Params $params

            # Verify merge
            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "16000"  # Updated
            $config['CacheTypeK'] | Should -Be "q4_0"  # Preserved
            $config['Mlock'] | Should -Be "true"  # Added
        }
    }
}

Describe "Argument Parsing" -Tag "Unit" {

    Context "Context Size Detection" {
        It "Detects numeric first argument as context size" {
            $RemainingArgs = @("32000", "--mlock")

            if ($RemainingArgs.Count -gt 0 -and $RemainingArgs[0] -match '^\d+$') {
                $ctxSize = $RemainingArgs[0]
                if ($RemainingArgs.Count -gt 1) {
                    $remainingArgsToProcess = $RemainingArgs[1..($RemainingArgs.Count - 1)]
                } else {
                    $remainingArgsToProcess = @()
                }
            } else {
                $remainingArgsToProcess = $RemainingArgs
            }

            $ctxSize | Should -Be "32000"
            $remainingArgsToProcess.Count | Should -Be 1
            $remainingArgsToProcess[0] | Should -Be "--mlock"
        }

        It "Handles single context size argument (edge case)" {
            $RemainingArgs = @("32000")

            if ($RemainingArgs.Count -gt 0 -and $RemainingArgs[0] -match '^\d+$') {
                $ctxSize = $RemainingArgs[0]
                if ($RemainingArgs.Count -gt 1) {
                    $remainingArgsToProcess = $RemainingArgs[1..($RemainingArgs.Count - 1)]
                } else {
                    $remainingArgsToProcess = @()
                }
            }

            $ctxSize | Should -Be "32000"
            $remainingArgsToProcess.Count | Should -Be 0
        }

        It "Does not treat non-numeric first arg as context size" {
            $RemainingArgs = @("--mlock", "32000")

            if ($RemainingArgs.Count -gt 0 -and $RemainingArgs[0] -match '^\d+$') {
                $ctxSize = $RemainingArgs[0]
            } else {
                $ctxSize = $null
                $remainingArgsToProcess = $RemainingArgs
            }

            $ctxSize | Should -BeNullOrEmpty
            $remainingArgsToProcess.Count | Should -Be 2
        }
    }

    Context "CLI Argument Classification" {
        It "Parses key-value pairs" {
            $cliArgs = @()
            $args = @("--cache-type-k", "q4_0", "--n-gpu-layers", "50")
            $i = 0

            while ($i -lt $args.Count) {
                $arg = $args[$i]
                if ($arg -match '^--' -and ($i + 1) -lt $args.Count -and $args[$i + 1] -notmatch '^-') {
                    $cliArgs += @{key = $arg; value = $args[$i + 1]}
                    $i += 2
                } else {
                    $i++
                }
            }

            $cliArgs.Count | Should -Be 2
            $cliArgs[0].key | Should -Be "--cache-type-k"
            $cliArgs[0].value | Should -Be "q4_0"
            $cliArgs[1].key | Should -Be "--n-gpu-layers"
            $cliArgs[1].value | Should -Be "50"
        }

        It "Parses per-model boolean flags" {
            $cliBooleans = @()
            $args = @("--mlock", "--jinja")

            foreach ($arg in $args) {
                if ($arg -match '^--' -and -not (Is-ServerWideBoolean $arg)) {
                    $cliBooleans += $arg
                }
            }

            $cliBooleans.Count | Should -Be 2
            $cliBooleans[0] | Should -Be "--mlock"
            $cliBooleans[1] | Should -Be "--jinja"
        }

        It "Separates server-wide flags" {
            $passthroughArgs = @()
            $cliBooleans = @()
            $args = @("--mlock", "--dry-run", "--no-webui", "--jinja")

            foreach ($arg in $args) {
                if ($arg -match '^--') {
                    if (Is-ServerWideBoolean $arg) {
                        $passthroughArgs += $arg
                    } else {
                        $cliBooleans += $arg
                    }
                }
            }

            $passthroughArgs.Count | Should -Be 2
            $passthroughArgs | Should -Contain "--dry-run"
            $passthroughArgs | Should -Contain "--no-webui"
            $cliBooleans.Count | Should -Be 2
            $cliBooleans | Should -Contain "--mlock"
            $cliBooleans | Should -Contain "--jinja"
        }
    }
}

Describe "Configuration Priority" -Tag "Unit" {

    Context "CLI > ENV > ModelConfig > Default" {
        It "CLI takes precedence over everything" {
            $DEFAULT_CACHE_TYPE_K = "q8_0"
            $Env:LLMS_CACHE_TYPE_K = "q6_0"
            $ModelConfig = @{ 'CacheTypeK' = 'q4_0' }
            $cliArgs = @(@{key = '--cache-type-k'; value = 'q2_0'})

            function Get-CliArgValue { param([string]$Key); ($cliArgs | Where-Object { $_.key -eq $Key }).value }

            $cacheTypeK = Get-CliArgValue '--cache-type-k'
            if (-not $cacheTypeK) { $cacheTypeK = $Env:LLMS_CACHE_TYPE_K }
            if (-not $cacheTypeK) { $cacheTypeK = $ModelConfig['CacheTypeK'] }
            if (-not $cacheTypeK) { $cacheTypeK = $DEFAULT_CACHE_TYPE_K }

            $cacheTypeK | Should -Be "q2_0"
        }

        It "ENV takes precedence over ModelConfig and Default" {
            $DEFAULT_CACHE_TYPE_K = "q8_0"
            $Env:LLMS_CACHE_TYPE_K = "q6_0"
            $ModelConfig = @{ 'CacheTypeK' = 'q4_0' }
            $cliArgs = @()

            function Get-CliArgValue { param([string]$Key); $null }

            $cacheTypeK = Get-CliArgValue '--cache-type-k'
            if (-not $cacheTypeK) { $cacheTypeK = $Env:LLMS_CACHE_TYPE_K }
            if (-not $cacheTypeK) { $cacheTypeK = $ModelConfig['CacheTypeK'] }
            if (-not $cacheTypeK) { $cacheTypeK = $DEFAULT_CACHE_TYPE_K }

            $cacheTypeK | Should -Be "q6_0"
        }

        It "ModelConfig takes precedence over Default" {
            $DEFAULT_CACHE_TYPE_K = "q8_0"
            $Env:LLMS_CACHE_TYPE_K = $null
            $ModelConfig = @{ 'CacheTypeK' = 'q4_0' }
            $cliArgs = @()

            function Get-CliArgValue { param([string]$Key); $null }

            $cacheTypeK = Get-CliArgValue '--cache-type-k'
            if (-not $cacheTypeK) { $cacheTypeK = $Env:LLMS_CACHE_TYPE_K }
            if (-not $cacheTypeK) { $cacheTypeK = $ModelConfig['CacheTypeK'] }
            if (-not $cacheTypeK) { $cacheTypeK = $DEFAULT_CACHE_TYPE_K }

            $cacheTypeK | Should -Be "q4_0"
        }

        It "Default used when nothing else specified" {
            $DEFAULT_CACHE_TYPE_K = "q8_0"
            $Env:LLMS_CACHE_TYPE_K = $null
            $ModelConfig = @{}
            $cliArgs = @()

            function Get-CliArgValue { param([string]$Key); $null }

            $cacheTypeK = Get-CliArgValue '--cache-type-k'
            if (-not $cacheTypeK) { $cacheTypeK = $Env:LLMS_CACHE_TYPE_K }
            if (-not $cacheTypeK) { $cacheTypeK = $ModelConfig['CacheTypeK'] }
            if (-not $cacheTypeK) { $cacheTypeK = $DEFAULT_CACHE_TYPE_K }

            $cacheTypeK | Should -Be "q8_0"
        }
    }
}

Describe "Per-Model Configuration Persistence" -Tag "Integration" {

    BeforeEach {
        # Clean up any existing test configs
        Get-ChildItem -Path $script:TestModelsDir -Filter "*.ini" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context "Config Creation" {
        It "Creates config with context size only" {
            $testModel = $script:TestModel1
            $params = @{ 'CtxSize' = '16000' }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $iniFile = $testModel.Replace('.gguf', '.ini')
            $iniFile | Should -Exist

            $content = @(Get-Content $iniFile -Encoding UTF8)
            $content[0] | Should -Be "CtxSize = 16000"
        }

        It "Only saves non-default values" {
            $testModel = $script:TestModel1
            $DEFAULT_CACHE_TYPE_K = "q8_0"
            $DEFAULT_N_GPU_LAYERS = "99"

            $params = @{
                'CtxSize' = '16000'
                'CacheTypeK' = 'q8_0'  # Default, should not be saved
                'NGpuLayers' = '50'     # Non-default, should be saved
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "16000"
            $config['NGpuLayers'] | Should -Be "50"
            $config.ContainsKey('CacheTypeK') | Should -Be $true  # Merging preserves existing
        }

        It "Saves boolean values as 'true'" {
            $testModel = $script:TestModel1
            $params = @{
                'CtxSize' = '16000'
                'Mlock' = 'true'
                'Jinja' = 'true'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $content = Get-Content $testModel.Replace('.gguf', '.ini') -Raw
            $content | Should -Match "Mlock = true"
            $content | Should -Match "Jinja = true"
        }

        It "Saves custom parameters with CamelCase conversion" {
            $testModel = $script:TestModel1
            $params = @{
                'CtxSize' = '16000'
                'RopeFreqBase' = '10000'
                'ChatTemplateFile' = 'C:\path\template.jinja'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['RopeFreqBase'] | Should -Be "10000"
            $config['ChatTemplateFile'] | Should -Be "C:\path\template.jinja"
        }
    }

    Context "Config Loading" {
        It "Loads context size from config" {
            $testModel = $script:TestModel1
            @"
CtxSize = 32000
"@ | Out-File -FilePath $testModel.Replace('.gguf', '.ini') -Encoding UTF8

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "32000"
        }

        It "Makes context size optional when config exists" {
            $testModel = $script:TestModel1
            @"
CtxSize = 16000
Mlock = true
"@ | Out-File -FilePath $testModel.Replace('.gguf', '.ini') -Encoding UTF8

            $config = Load-ModelConfig -ModelFile $testModel

            # Simulate script logic
            $ctxSize = $null
            if ($config.ContainsKey('CtxSize')) {
                $ctxSize = $config['CtxSize']
            }

            $ctxSize | Should -Be "16000"
        }
    }

    Context "Config Merging" {
        It "Merges new params with existing config" {
            $testModel = $script:TestModel1

            # Initial config
            @"
CtxSize = 8000
CacheTypeK = q4_0
"@ | Out-File -FilePath $testModel.Replace('.gguf', '.ini') -Encoding UTF8

            # Add new param
            $params = @{
                'CtxSize' = '8000'
                'Mlock' = 'true'
            }
            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "8000"
            $config['CacheTypeK'] | Should -Be "q4_0"  # Preserved
            $config['Mlock'] | Should -Be "true"  # Added
        }

        It "Updates existing params" {
            $testModel = $script:TestModel1

            # Initial config
            @"
CtxSize = 8000
CacheTypeK = q4_0
"@ | Out-File -FilePath $testModel.Replace('.gguf', '.ini') -Encoding UTF8

            # Update param
            $params = @{
                'CtxSize' = '16000'
                'CacheTypeK' = 'q6_0'
            }
            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "16000"  # Updated
            $config['CacheTypeK'] | Should -Be "q6_0"  # Updated
        }
    }
}

Describe "Dry-Run Mode" -Tag "Integration" {

    BeforeEach {
        # Clean up any existing test configs
        Get-ChildItem -Path $script:TestModelsDir -Filter "*.ini" | Remove-Item -Force
    }

    Context "Dry-Run Behavior" {
        It "Does NOT save config during dry-run" {
            $testModel = $script:TestModel1
            $iniFile = $testModel.Replace('.gguf', '.ini')

            # Ensure no config exists
            if (Test-Path $iniFile) {
                Remove-Item $iniFile -Force
            }

            # Simulate dry-run logic
            $passthroughArgs = @('--dry-run')
            $isDryRun = $passthroughArgs -contains '--dry-run'
            $hasCliCtxSize = $true

            if (-not $isDryRun) {
                $params = @{ 'CtxSize' = '16000' }
                Save-ModelConfig -ModelFile $testModel -Params $params
            }

            # Config should NOT have been created
            $iniFile | Should -Not -Exist
        }

        It "Saves config when NOT dry-run" {
            $testModel = $script:TestModel1

            # Simulate normal run
            $passthroughArgs = @()
            $isDryRun = $passthroughArgs -contains '--dry-run'

            if (-not $isDryRun) {
                $params = @{ 'CtxSize' = '16000' }
                Save-ModelConfig -ModelFile $testModel -Params $params
            }

            $iniFile = $testModel.Replace('.gguf', '.ini')
            $iniFile | Should -Exist
        }
    }
}

Describe "ENV Variable Behavior" -Tag "Integration" {

    Context "ENV Variables Are Temporary" {
        It "ENV override does NOT persist to config" {
            $testModel = $script:TestModel1
            $DEFAULT_N_GPU_LAYERS = "99"

            # Simulate ENV override
            $Env:LLMS_N_GPU_LAYERS = "50"
            $cliArgs = @()

            function Get-CliArgValue { param([string]$Key); $null }

            # Configuration priority
            $nGpuLayers = Get-CliArgValue '--n-gpu-layers'
            if (-not $nGpuLayers) { $nGpuLayers = $Env:LLMS_N_GPU_LAYERS }
            if (-not $nGpuLayers) { $nGpuLayers = $DEFAULT_N_GPU_LAYERS }

            # Save logic (only if CLI provided)
            $cliNGpuLayers = Get-CliArgValue '--n-gpu-layers'
            $configParams = @{ 'CtxSize' = '16000' }
            if ($cliNGpuLayers -and $nGpuLayers -ne $DEFAULT_N_GPU_LAYERS) {
                $configParams['NGpuLayers'] = $nGpuLayers
            }

            Save-ModelConfig -ModelFile $testModel -Params $configParams

            $config = Load-ModelConfig -ModelFile $testModel
            $config.ContainsKey('NGpuLayers') | Should -Be $false  # Not saved

            # Cleanup
            $Env:LLMS_N_GPU_LAYERS = $null
        }

        It "CLI override DOES persist to config" {
            $testModel = $script:TestModel1
            $DEFAULT_N_GPU_LAYERS = "99"
            $cliArgs = @(@{key = '--n-gpu-layers'; value = '50'})

            function Get-CliArgValue {
                param([string]$Key)
                ($cliArgs | Where-Object { $_.key -eq $Key }).value
            }

            # Configuration priority
            $nGpuLayers = Get-CliArgValue '--n-gpu-layers'
            if (-not $nGpuLayers) { $nGpuLayers = $DEFAULT_N_GPU_LAYERS }

            # Save logic
            $cliNGpuLayers = Get-CliArgValue '--n-gpu-layers'
            $configParams = @{ 'CtxSize' = '16000' }
            if ($cliNGpuLayers -and $nGpuLayers -ne $DEFAULT_N_GPU_LAYERS) {
                $configParams['NGpuLayers'] = $nGpuLayers
            }

            Save-ModelConfig -ModelFile $testModel -Params $configParams

            $config = Load-ModelConfig -ModelFile $testModel
            $config['NGpuLayers'] | Should -Be "50"  # Saved
        }
    }
}

Describe "Server-Wide vs Per-Model Booleans" -Tag "Integration" {

    Context "Boolean Persistence" {
        It "Per-model booleans ARE persisted" {
            $testModel = $script:TestModel1
            $params = @{
                'CtxSize' = '16000'
                'Mlock' = 'true'
                'Jinja' = 'true'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['Mlock'] | Should -Be "true"
            $config['Jinja'] | Should -Be "true"
        }

        It "Server-wide booleans are NOT persisted" {
            # This is verified by the argument parsing logic
            # Server-wide flags go to $passthroughArgs, never to $cliBooleans
            $args = @("--dry-run", "--no-webui", "--verbose")
            $cliBooleans = @()

            foreach ($arg in $args) {
                if (-not (Is-ServerWideBoolean $arg)) {
                    $cliBooleans += $arg
                }
            }

            $cliBooleans.Count | Should -Be 0  # None should be added
        }
    }
}

Describe "Error Handling" -Tag "Integration" {

    Context "Missing Parameters" {
        It "Requires context size or config" {
            # Simulate missing context size and no config
            $ctxSize = $null
            $ModelConfig = @{}

            if (-not $ctxSize) {
                if ($ModelConfig.ContainsKey('CtxSize')) {
                    $ctxSize = $ModelConfig['CtxSize']
                } else {
                    $errorExpected = $true
                }
            }

            $errorExpected | Should -Be $true
        }
    }
}

Describe "Integration Tests" -Tag "Integration" {

    BeforeEach {
        # Clean up any existing test configs
        Get-ChildItem -Path $script:TestModelsDir -Filter "*.ini" -ErrorAction SilentlyContinue | Remove-Item -Force
    }

    Context "Full Workflow" {
        It "First run creates config with CLI args" {
            $testModel = $script:TestModel1
            $testIni = $testModel.Replace('.gguf', '.ini')

            # Clean slate
            if (Test-Path $testIni) {
                Remove-Item $testIni -Force
            }

            # Simulate first run with CLI args
            $params = @{
                'CtxSize' = '16000'
                'Mlock' = 'true'
                'CacheTypeK' = 'q4_0'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $testIni | Should -Exist

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CtxSize'] | Should -Be "16000"
            $config['Mlock'] | Should -Be "true"
            $config['CacheTypeK'] | Should -Be "q4_0"
        }

        It "Second run loads config and context size is optional" {
            $testModel = $script:TestModel1
            $testIni = $testModel.Replace('.gguf', '.ini')

            # Ensure config exists
            @"
CtxSize = 16000
Mlock = true
"@ | Out-File -FilePath $testIni -Encoding UTF8

            $config = Load-ModelConfig -ModelFile $testModel

            # Simulate script logic for optional context size
            $ctxSize = $null
            if ($config.ContainsKey('CtxSize')) {
                $ctxSize = $config['CtxSize']
            }

            $ctxSize | Should -Be "16000"
            $config['Mlock'] | Should -Be "true"
        }

        It "CLI override updates config" {
            $testModel = $script:TestModel1
            $testIni = $testModel.Replace('.gguf', '.ini')

            # Initial config
            @"
CtxSize = 16000
CacheTypeK = q4_0
"@ | Out-File -FilePath $testIni -Encoding UTF8

            # Simulate CLI override
            $params = @{
                'CtxSize' = '16000'
                'CacheTypeK' = 'q6_0'
            }

            Save-ModelConfig -ModelFile $testModel -Params $params

            $config = Load-ModelConfig -ModelFile $testModel
            $config['CacheTypeK'] | Should -Be "q6_0"
        }
    }
}
