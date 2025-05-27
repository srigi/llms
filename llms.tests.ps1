Describe "llms.ps1" {
    BeforeAll {
        # a helper function to capture output
        function Test-Output {
            param (
                [scriptblock]$ScriptBlock,
                [string]$ExpectedOutput
            )

            $output = (& $ScriptBlock 2>&1) -join "`n"
            $output | Should -BeExactly $ExpectedOutput
        }
    }


    It "prints help when no arguments are provided" {
        $expectedOutput = @"
usage:
  llms list
  llms <partial_model_name> <context_size> [llama-server args...] [--dry-run]

example:
  llms list
  llms Devstral-Small-2505-UD 24000
  llms Mistral-Small-3.1-24B 32000 --jinja
  llms Mistral-Small-3.1-24B 32000 --jinja --dry-run

"@

        Test-Output { ./llms.ps1 } $expectedOutput
    }
}
