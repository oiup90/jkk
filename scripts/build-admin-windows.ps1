[CmdletBinding()]
param(
    [Parameter(ParameterSetName = 'Build')] [switch] $Run,
    [Parameter(ParameterSetName = 'Build')] [switch] $VerboseBuild,
    [Parameter(ParameterSetName = 'Build')] [switch] $DisableCaptcha,
    [Parameter(ParameterSetName = 'Build')] [string] $BuildName,
    [Parameter(ParameterSetName = 'Build')] [int] $BuildNumber,
    [Parameter(Mandatory, ParameterSetName = 'Diagnose')] [switch] $DiagnoseInstall
)
. "$PSScriptRoot/build-common.ps1"
$repoRoot = Split-Path $PSScriptRoot -Parent
$outputRoot = Join-Path (Split-Path $repoRoot -Parent) 'freelan-space-admin-builds'

# Copy only the Flutter project inputs used by the Windows build. Do not copy
# build caches or Android signing files into the separate build workspace.
function Copy-WindowsSource([string] $Source, [string] $Destination) {
    New-Item -ItemType Directory -Path $Destination -Force | Out-Null
    foreach ($item in Get-ChildItem -LiteralPath $Source -Force) {
        if ($item.PSIsContainer) {
            if ($item.FullName -in @(
                (Join-Path $repoRoot 'windows/flutter/ephemeral'),
                (Join-Path $repoRoot 'windows/x64'),
                (Join-Path $repoRoot 'windows/x86')
            )) { continue }
            Copy-WindowsSource $item.FullName (Join-Path $Destination $item.Name)
        } else {
            Copy-Item -LiteralPath $item.FullName -Destination $Destination
        }
    }
}

try {
    Push-Location $repoRoot
    if ($DiagnoseInstall) {
        $marker = Join-Path $outputRoot 'last-workspace.txt'
        $nativeBuild = Join-Path $repoRoot 'build/windows/x64'
        if (Test-Path -LiteralPath $marker -PathType Leaf) {
            $nativeBuild = Join-Path (Get-Content -LiteralPath $marker -Raw).Trim() 'build/windows/x64'
        }
        $cache = Join-Path $nativeBuild 'CMakeCache.txt'
        if (-not (Test-Path -LiteralPath $cache -PathType Leaf)) {
            throw 'Windows CMake cache not found. Run the admin build first.'
        }
        $cmakeEntry = Select-String -LiteralPath $cache -Pattern '^CMAKE_COMMAND:INTERNAL=(.+)$' | Select-Object -First 1
        if (-not $cmakeEntry) { throw 'CMake executable was not recorded in CMakeCache.txt.' }
        $cmake = $cmakeEntry.Matches[0].Groups[1].Value
        if (-not (Test-Path -LiteralPath $cmake -PathType Leaf)) { throw 'The cached CMake executable no longer exists. Reconfigure the Windows build.' }
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
    $versionLine = Select-String -LiteralPath (Join-Path $repoRoot 'pubspec.yaml') -Pattern '^version:\s*(\d+\.\d+\.\d+)\+(\d+)\s*(?:#.*)?$' | Select-Object -First 1
    if (-not $versionLine) { throw 'Expected a version like 1.2.3+4 in pubspec.yaml.' }
    $defaultName = $versionLine.Matches[0].Groups[1].Value
    $defaultNumber = $versionLine.Matches[0].Groups[2].Value
    if (-not $PSBoundParameters.ContainsKey('BuildName')) {
        $BuildName = $defaultName
        if (-not [Console]::IsInputRedirected) {
            $answer = Read-Host "Admin version name (example 1.2.0; Enter for $defaultName)"
            if ($answer) { $BuildName = $answer.Trim() }
        }
    }
    if (-not $PSBoundParameters.ContainsKey('BuildNumber')) {
        $numberText = $defaultNumber
        if (-not [Console]::IsInputRedirected) {
            $answer = Read-Host "Admin build code (example 18; Enter for $defaultNumber)"
            if ($answer) { $numberText = $answer.Trim() }
        }
        if ($numberText -notmatch '^\d+$' -or $numberText.Length -gt 5 -or [int]$numberText -gt 65535) { throw 'Build code must be a number from 1 to 65535.' }
        $BuildNumber = [int]$numberText
    }
    if ($BuildName -notmatch '^\d+\.\d+\.\d+$') { throw 'Version name must contain three numbers, for example 1.2.0.' }
    foreach ($part in $BuildName.Split('.')) {
        if ($part.Length -gt 5 -or [int]$part -gt 65535) { throw 'Each version name number must be between 0 and 65535.' }
    }
    if ($BuildNumber -lt 1 -or $BuildNumber -gt 65535) { throw 'Build code must be a number from 1 to 65535.' }
    if (-not (Get-Command nuget -CommandType Application -ErrorAction SilentlyContinue) -and $env:LOCALAPPDATA) {
        $localTools = Join-Path $env:LOCALAPPDATA 'FreelanTools'
        if (Test-Path -LiteralPath (Join-Path $localTools 'nuget.exe') -PathType Leaf) {
            $env:PATH = "$localTools$([System.IO.Path]::PathSeparator)$env:PATH"
        }
    }
    if (-not (Get-Command nuget -CommandType Application -ErrorAction SilentlyContinue)) {
        throw 'NuGet CLI not found on PATH. See docs/ONE_COMMAND_BUILDS.md for the Windows NuGet setup command.'
    }
    $flutter = Get-FlutterCommand
    Assert-FlutterVersion $flutter
    $runDir = Join-Path $outputRoot ("v$BuildName-$BuildNumber-" + [guid]::NewGuid().ToString('N'))
    $sourceDir = Join-Path $runDir 'source'
    New-Item -ItemType Directory -Path $sourceDir -Force | Out-Null
    foreach ($file in @('pubspec.yaml', 'pubspec.lock', '.metadata')) {
        Copy-Item -LiteralPath (Join-Path $repoRoot $file) -Destination $sourceDir
    }
    foreach ($folder in @('lib', 'assets', 'windows')) {
        Copy-WindowsSource (Join-Path $repoRoot $folder) (Join-Path $sourceDir $folder)
    }
    Set-Content -LiteralPath (Join-Path $outputRoot 'last-workspace.txt') -Value $sourceDir
    Push-Location $sourceDir
    try {
        Invoke-Flutter $flutter @('pub', 'get', '--enforce-lockfile')
        $buildArgs = @('build', 'windows', '--release', '--no-pub', '-t', 'lib/admin_main.dart', "--build-name=$BuildName", "--build-number=$BuildNumber")
        if (-not $DisableCaptcha) { $buildArgs += '--dart-define=AUTH_CAPTCHA_ENABLED=true' }
        if ($VerboseBuild) { $buildArgs += '--verbose' }
        Invoke-Flutter $flutter $buildArgs
        $releaseDir = Join-Path $sourceDir 'build/windows/x64/runner/Release'
        $exe = Join-Path $releaseDir 'freelan_space_admin.exe'
        if (-not (Test-Path -LiteralPath $exe -PathType Leaf)) { throw 'Build completed but the admin executable was not found.' }
        $zip = Join-Path $runDir "freelan-space-admin-v$BuildName-$BuildNumber.zip"
        $files = Get-ChildItem -LiteralPath $releaseDir | Where-Object { $_.Name -notin @('growth_circle_admin.exe', 'growth_circle_admin.pdb') }
        Compress-Archive -Path @($files | ForEach-Object { $_.FullName }) -DestinationPath $zip
        Write-Host "`nAdmin version: $BuildName (build $BuildNumber)"
        Write-Host "Admin EXE: $exe"
        Write-Host "Admin ZIP (includes required files): $zip"
        if ($Run) { Start-Process -FilePath $exe -WorkingDirectory $releaseDir }
    } finally {
        Pop-Location
    }
} catch {
    Write-Error "Admin Windows build failed: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
} finally {
    Pop-Location
}
