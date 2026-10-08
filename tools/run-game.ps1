param([switch]$LiveTest)
$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path $PSScriptRoot -Parent
$engine = Join-Path $PSScriptRoot 'local/godot/Godot_v4.6.2-stable_win64_console.exe'
$envFile = Join-Path $projectRoot '.env'
$keyNames = @('ANTHROPIC_API_KEY', 'DEEPSEEK_API_KEY', 'NVIDIA_API_KEY')
$previousKeys = @{}
foreach ($name in $keyNames) { $previousKeys[$name] = [Environment]::GetEnvironmentVariable($name, 'Process') }
try {
    if (Test-Path -LiteralPath $envFile) {
        $keys = @{}
        foreach ($line in [IO.File]::ReadAllLines($envFile)) {
            if ($line -match '^\s*(?:export\s+)?(ANTHROPIC_API_KEY|ANTHROPIC_KEY|DEEPSEEK_API_KEY|NVIDIA_API_KEY)\s*=\s*(.*?)\s*$') {
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
        # Fallback providers, used when Anthropic has no key or no budget left.
        if ($keys.ContainsKey('DEEPSEEK_API_KEY')) { $env:DEEPSEEK_API_KEY = $keys['DEEPSEEK_API_KEY'] }
        if ($keys.ContainsKey('NVIDIA_API_KEY')) { $env:NVIDIA_API_KEY = $keys['NVIDIA_API_KEY'] }
    }
    if ($LiveTest -and [string]::IsNullOrWhiteSpace($env:ANTHROPIC_API_KEY)) { throw 'No Anthropic key is configured.' }
    $arguments = @('--path', (Join-Path $projectRoot 'game'))
    if ($LiveTest) { $arguments += @('--headless', '--script', 'res://tests/claude_live_test.gd', '--', '--live') }
    & $engine @arguments
    $engineExit = $LASTEXITCODE
} finally {
    foreach ($name in $keyNames) { [Environment]::SetEnvironmentVariable($name, $previousKeys[$name], 'Process') }
    $keys = $null
    $value = $null
}
exit $engineExit
