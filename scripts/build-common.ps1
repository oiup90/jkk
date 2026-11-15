# Shared helpers for the Windows release build commands.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Get-FlutterCommand {
    $command = Get-Command flutter -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $command) {
        throw 'Flutter was not found on PATH. Install Flutter 3.47.9 and reopen Visual Studio. See docs/ONE_COMMAND_BUILDS.md.'
    }
    return $command.Source
}

function Assert-FlutterVersion([string] $Flutter) {
    $versionOutput = & $Flutter --version --machine
    if ($LASTEXITCODE -ne 0) { throw 'Could not read Flutter version. Run flutter doctor -v.' }
    $versionInfo = $versionOutput | ConvertFrom-Json
    if ($versionInfo.frameworkVersion -ne '3.47.9') {
        throw "Flutter 3.47.9 is required by this project; found $($versionInfo.frameworkVersion). See docs/ONE_COMMAND_BUILDS.md."
    }
}

function Invoke-Flutter([string] $Flutter, [string[]] $Arguments) {
    & $Flutter @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Flutter command failed (exit $LASTEXITCODE): flutter $($Arguments -join ' ')"
    }
}
