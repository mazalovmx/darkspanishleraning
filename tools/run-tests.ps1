# Runs every non-live Godot suite headless and prints one line per suite.
# Usage: ./tools/run-tests.ps1 [-Filter ghost] [-TimeoutSeconds 600]
# Never runs claude_live_test; the Anthropic key is removed from this process
# for the duration of the run so no suite can make a paid request.
param(
    [string]$Filter = "",
    [int]$TimeoutSeconds = 600
)

$root = Split-Path -Parent $PSScriptRoot
$godot = Join-Path $root "tools/local/godot/Godot_v4.6.2-stable_win64_console.exe"
# A git worktree has no tools/local; GODOT_BIN names the engine binary to use instead.
if (-not (Test-Path $godot) -and $env:GODOT_BIN) { $godot = $env:GODOT_BIN }
if (-not (Test-Path $godot)) {
    Write-Error "Godot binary not found: $godot"
    exit 2
}
$logs = Join-Path $root "tools/local/test-logs"
New-Item -ItemType Directory -Force -Path $logs | Out-Null

$skip = @("claude_live_test", "save_restart_test")
$scenes = @("side_catalog_test", "equipment_ghost_catalog_test")
$suites = Get-ChildItem (Join-Path $root "game/tests") -Filter "*_test.gd" |
    ForEach-Object { $_.BaseName } |
    Where-Object { $skip -notcontains $_ -and ($Filter -eq "" -or $_ -like "*$Filter*") } |
    Sort-Object

$savedKeys = @{}
foreach ($name in @("ANTHROPIC_API_KEY", "ANTHROPIC_KEY")) {
    $savedKeys[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
    [Environment]::SetEnvironmentVariable($name, $null, "Process")
}

function Invoke-Suite([string]$label, [string[]]$arguments) {
    $log = Join-Path $logs "$label.log"
    $allArguments = @("--headless", "--path", (Join-Path $root "game")) + $arguments
    $process = Start-Process -FilePath $godot -ArgumentList $allArguments -NoNewWindow -PassThru `
        -RedirectStandardOutput $log -RedirectStandardError "$log.err"
    # Reading Handle keeps the exit code available after the process ends.
    $null = $process.Handle
    if (-not $process.WaitForExit($TimeoutSeconds * 1000)) {
        $process.Kill()
        return @{ label = $label; status = "TIMEOUT"; checks = 0; failures = -1 }
    }
    $text = (Get-Content $log -Raw) + (Get-Content "$log.err" -Raw)
    $checks = 0
    $failures = -1
    $match = [regex]::Matches($text, "(\d+), failures: (\d+)")
    if ($match.Count -gt 0) {
        $checks = [int]$match[$match.Count - 1].Groups[1].Value
        $failures = [int]$match[$match.Count - 1].Groups[2].Value
    } elseif ($text -match "PASS" -and $text -notmatch "FAIL") {
        $failures = 0
    }
    $scriptError = $text -match "SCRIPT ERROR|Parse Error"
    $passed = $process.ExitCode -eq 0 -and $failures -eq 0 -and -not $scriptError
    $status = "FAIL"
    if ($passed) { $status = "PASS" }
    return @{ label = $label; status = $status; checks = $checks; failures = $failures }
}

$results = @()
try {
    foreach ($suite in $suites) {
        if ($scenes -contains $suite) {
            $result = Invoke-Suite $suite @("res://tests/$suite.tscn")
        } else {
            $result = Invoke-Suite $suite @("--script", "res://tests/$suite.gd")
        }
        Write-Host ("{0,-8} {1,-34} checks {2,6}  failures {3}" -f $result.status, $result.label, $result.checks, $result.failures)
        $results += $result
    }
    if ($Filter -eq "" -or "save_restart_test" -like "*$Filter*") {
        $path = "user://save_restart_" + [guid]::NewGuid().ToString("N") + ".json"
        foreach ($mode in @("write", "read")) {
            $result = Invoke-Suite "save_restart_test_$mode" @("--script", "res://tests/save_restart_test.gd", "--", "--$mode", $path)
            Write-Host ("{0,-8} {1,-34}" -f $result.status, $result.label)
            $results += $result
        }
    }
} finally {
    foreach ($name in $savedKeys.Keys) {
        [Environment]::SetEnvironmentVariable($name, $savedKeys[$name], "Process")
    }
}

$bad = @($results | Where-Object { $_.status -ne "PASS" })
$total = ($results | ForEach-Object { $_.checks } | Measure-Object -Sum).Sum
Write-Host ""
Write-Host ("Suites: {0}, not passed: {1}, counted checks: {2}. Logs: tools/local/test-logs" -f $results.Count, $bad.Count, $total)
if ($bad.Count -gt 0) { exit 1 }
exit 0
