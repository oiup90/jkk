[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Build')] [switch] $Run,
    [Parameter(ParameterSetName = 'Build')] [switch] $VerboseBuild,
    [Parameter(ParameterSetName = 'Build')] [switch] $DisableCaptcha,
    [Parameter(Mandatory, ParameterSetName = 'Diagnose')] [switch] $DiagnoseInstall
)
. "$PSScriptRoot/build-common.ps1"
$repoRoot = Split-Path $PSScriptRoot -Parent
try {
    Push-Location $repoRoot
    if ($DiagnoseInstall) {
        $nativeBuild = Join-Path $repoRoot 'build/windows/x64'
        $cache = Join-Path $nativeBuild 'CMakeCache.txt'
        if (-not (Test-Path -LiteralPath $cache -PathType Leaf)) {
            throw 'Windows CMake cache not found. Run the admin build first.'
        }
        $cmakeEntry = Select-String -LiteralPath $cache -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$' | Select-Object -First 1
        if (-not $cmakeEntry) { throw 'CMake executable was not recorded in CMakeCache.txt.' }
        $cmake = $cmakeEntry.Matches[0].Groups[1].Value
        if (-not (Test-Path -LiteralPath $cmake -PathType Leaf)) { throw 'The cached CMake executable no longer exists. Reconfigure the Windows build.' }
        # Use the exact executable and working directory selected by Flutter.
        # This reruns installation only and exposes the error hidden by MSBuild.
        Push-Location $nativeBuild
        try {
            & $cmake '-DBUILD_TYPE=Release' '-P' 'cmake_install.cmake'
            if ($LASTEXITCODE -ne 0) { throw "CMake install failed (exit $LASTEXITCODE). See the CMake error above." }
        } finally {
            Pop-Location
        }
        Write-Host 'CMake install succeeded. Run the admin build again to create the ZIP.'
        return
    }
    $flutter = Get-FlutterCommand
    Assert-FlutterVersion $flutter
    Invoke-Flutter $flutter @('pub', 'get', '--enforce-lockfile')
    $buildArgs = @('build', 'windows', '--release', '--no-pub', '-t', 'lib/admin_main.dart')
    if (-not $DisableCaptcha) { $buildArgs += '--dart-define=AUTH_CAPTCHA_ENABLED=true' }
    if ($VerboseBuild) { $buildArgs += '--verbose' }
    Invoke-Flutter $flutter $buildArgs
    $releaseDir = Join-Path $repoRoot 'build/windows/x64/runner/Release'
    $exe = Join-Path $releaseDir 'freelan_space_admin.exe'
    if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Build completed but the admin executable was not found.' }
    $zip = Join-Path $repoRoot 'build/freelan-space-admin-windows.zip'
    $temporaryZip = Join-Path $repoRoot ("build/admin-" + [guid]::NewGuid().ToString('N') + '.zip')
    try {
        # A previous build can leave the old executable in the output folder.
        $files = Get-ChildItem -LiteralPath $releaseDir | Where-Object { $_.Name -notin @('growth_circle_admin.exe', 'growth_circle_admin.pdb') }
        Compress-Archive -Path @($files | ForEach-Object { $_.FullName }) -DestinationPath $temporaryZip
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
