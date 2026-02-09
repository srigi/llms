Describe "llms.ps1" {
    BeforeAll {
        $TestDir = Join-Path $PSScriptRoot "test_env"
        $ModelDir = Join-Path $TestDir "models"
        if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
        New-Item -ItemType Directory -Path $ModelDir | Out-Null
        
        $DummyModel = Join-Path $ModelDir "test-model.gguf"
        "dummy" | Out-File -FilePath $DummyModel
        
        $TestIni = Join-Path $TestDir "llms.ini"
        "ModelsDirs = $ModelDir" | Out-File -FilePath $TestIni
        
        $env:LLMS_MODELS_DIRS = $null
    }

    AfterAll {
        if (Test-Path $TestDir) { Remove-Item -Path $TestDir -Recurse -Force }
    }

    Context "Basic Functionality" {
        It "prints help when no arguments are provided" {
            $output = & powershell -ExecutionPolicy Bypass -File ./llms.ps1 2>&1 | Out-String
            $output | Should Match "usage:"
            $output | Should Match "llms list"
        }

        It "lists models correctly" {
            # Point to our test ini
            # We move the real one temporarily or just use ENV to override
            $env:LLMS_MODELS_DIRS = $ModelDir
            $output = & powershell -ExecutionPolicy Bypass -File ./llms.ps1 list 2>&1 | Out-String
            $output | Should Match "test-model.gguf"
            $env:LLMS_MODELS_DIRS = $null
        }
    }

    Context "Dry Run and Config" {
        It "shows the correct command in dry-run" {
            $env:LLMS_MODELS_DIRS = $ModelDir
            $output = & powershell -ExecutionPolicy Bypass -File ./llms.ps1 test-model 8000 --dry-run 2>&1 | Out-String
            $output | Should Match "llama-server"
            $output | Should Match "--ctx-size 8000"
            $output | Should Match "--model .*test-model.gguf"
            # Verify CacheType defaults
            $output | Should Match "--cache-type-k q8_0"
            $env:LLMS_MODELS_DIRS = $null
        }

        It "handles custom arguments in dry-run" {
            $env:LLMS_MODELS_DIRS = $ModelDir
            $output = & powershell -ExecutionPolicy Bypass -File ./llms.ps1 test-model 8000 --temp 0.5 --dry-run 2>&1 | Out-String
            $output | Should Match "--temp 0.5"
            $env:LLMS_MODELS_DIRS = $null
        }
    }
}