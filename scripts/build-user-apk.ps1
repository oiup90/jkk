[CmdletBinding()]
param(
    [ValidateRange(1, 2100000000)] [int] $BuildNumber,
    [ValidatePattern('^\d+\.\d+\.\d+$')] [string] $BuildName
)
. "$PSScriptRoot/build-common.ps1"
$repoRoot = Split-Path $PSScriptRoot -Parent
try {
    Push-Location $repoRoot
    foreach ($path in @('config/production.json', 'android/app/google-services.json', 'android/key.properties')) {
        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
            throw "Missing $path. Set up the original release signing files and Firebase config as described in docs/ONE_COMMAND_BUILDS.md."
        }
    }
    $flutter = Get-FlutterCommand
    Assert-FlutterVersion $flutter
    Invoke-Flutter $flutter @('pub', 'get', '--enforce-lockfile')
    $buildArgs = @('build', 'apk', '--release', '--no-pub', '--dart-define-from-file=config/production.json')
    if ($PSBoundParameters.ContainsKey('BuildNumber')) { $buildArgs += "--build-number=$BuildNumber" }
    if ($PSBoundParameters.ContainsKey('BuildName')) { $buildArgs += "--build-name=$BuildName" }
    Invoke-Flutter $flutter $buildArgs
    $apk = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) { throw 'Build completed but the release APK was not found.' }
    Write-Host "`nUser APK ready: $apk"
    Write-Host 'For an update, use a build number higher than all previously distributed versions and verify the signing certificate before publishing.'
} catch {
    Write-Error "User APK build failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
} finally {
    Pop-Location
}
