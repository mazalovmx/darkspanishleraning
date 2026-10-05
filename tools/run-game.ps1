param([switch]$LiveTest)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $PSScriptRoot 'local/godot/Godot_v4.6.2-stable_win64_console.exe'
$envFile = Join-Path $projectRoot '.env'
$previousKey = [Environment]::GetEnvironmentVariable('ANTHROPIC_API_KEY', 'Process')
try {
    if (Test-Path -LiteralPath $envFile) {
        $keys = @{}
        foreach ($line in [IO.File]::ReadAllLines($envFile)) {
            if ($line -match '^\s*(?:export\s+)?(ANTHROPIC_API_KEY|ANTHROPIC_KEY)\s*=\s*(.*?)\s*$') {
                $name = $Matches[1]
                $value = $Matches[2].Trim()
                if ($value.Length -ge 2 -and (($value.StartsWith('"') -and $value.EndsWith('"')) -or ($value.StartsWith("'") -and $value.EndsWith("'")))) {
                    $value = $value.Substring(1, $value.Length - 2)
                }
                if ($value) { $keys[$name] = $value }
            }
        }
        if ($keys.ContainsKey('ANTHROPIC_API_KEY')) { $env:ANTHROPIC_API_KEY = $keys['ANTHROPIC_API_KEY'] }
        elseif ($keys.ContainsKey('ANTHROPIC_KEY')) { $env:ANTHROPIC_API_KEY = $keys['ANTHROPIC_KEY'] }
    }
    if ($LiveTest -and [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) { throw 'No Anthropic key is configured.' }
    $arguments = @('--path', (Join-Path $projectRoot 'game'))
    if ($LiveTest) { $arguments += @('--headless', '--script', 'res://tests/claude_live_test.gd', '--', '--live') }
    & $engine @arguments
    $engineExit = $LASTEXITCODE
} finally {
    [Environment]::SetEnvironmentVariable('ANTHROPIC_API_KEY', $previousKey, 'Process')
    $keys = $null
    $value = $null
}
exit $engineExit
