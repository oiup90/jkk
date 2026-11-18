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
    # Each build needs its own symbols: later builds must not overwrite them.
    $symbols = Join-Path $repoRoot "release-symbols/$([guid]::NewGuid().ToString())"
    New-Item -ItemType Directory -Path $symbols -ErrorAction Stop | Out-Null
    $buildArgs = @('build', 'apk', '--release', '--no-pub', '--dart-define-from-file=config/production.json', '--dart-define=AUTH_CAPTCHA_ENABLED=true', '--obfuscate', "--split-debug-info=$symbols")
    if ($PSBoundParameters.ContainsKey('BuildNumber')) { $buildArgs += "--build-number=$BuildNumber" }
    if ($PSBoundParameters.ContainsKey('BuildName')) { $buildArgs += "--build-name=$BuildName" }
    Invoke-Flutter $flutter $buildArgs
    $apk = Join-Path $repoRoot 'build/app/outputs/flutter-apk/app-release.apk'
    if (-not (Test-Path -LiteralPath $apk -PathType Leaf)) { throw 'Build completed but the release APK was not found.' }
    foreach ($arch in @('arm', 'arm64', 'x64')) {
        $symbolFile = Join-Path $symbols "app.android-$arch.symbols"
        if (-not (Test-Path -LiteralPath $symbolFile -PathType Leaf) -or (Get-Item -LiteralPath $symbolFile).Length -eq 0) {
            throw "Build completed but Dart symbols were not found or were empty: $symbolFile"
        }
    }
    Write-Host "`nUser APK ready: $apk"
    Write-Host "Keep these Dart symbols privately with this APK: $symbols"
    Write-Host 'For an update, use a build number higher than all previously distributed versions and verify the signing certificate before publishing.'
} catch {
    Write-Error "User APK build failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
} finally {
    Pop-Location
}
