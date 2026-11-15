[CmdletBinding()]
param([switch] $Run)
. "$PSScriptRoot/build-common.ps1"
$repoRoot = Split-Path $PSScriptRoot -Parent
try {
    Push-Location $repoRoot
    $flutter = Get-FlutterCommand
    Assert-FlutterVersion $flutter
    Invoke-Flutter $flutter @('pub', 'get', '--enforce-lockfile')
    Invoke-Flutter $flutter @('build', 'windows', '--release', '--no-pub', '-t', 'lib/admin_main.dart')
    $releaseDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
    $exe = Join-Path $releaseDir 'growth_circle_admin.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Build completed but the admin executable was not found.' }
    $zip = Join-Path $repoRoot 'build/freelan-space-admin-windows.zip'
    $temporaryZip = Join-Path $repoRoot ("build/admin-" + [guid]::NewGuid().ToString('N') + '.zip')
    try {
        Compress-Archive -Path (Join-Path $releaseDir '*') -DestinationPath $temporaryZip
        Move-Item -LiteralPath $temporaryZip -Destination $zip -Force
    } finally {
        if (Test-Path -LiteralPath $temporaryZip) { Remove-Item -LiteralPath $temporaryZip -Force }
    }
    Write-Host "`nAdmin EXE: $exe"
    Write-Host "Admin ZIP (includes required files): $zip"
    if ($Run) { Start-Process -FilePath $exe -WorkingDirectory $releaseDir }
} catch {
    Write-Error "Admin Windows build failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
} finally {
    Pop-Location
}
