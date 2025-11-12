param(
    [string]$BuildPath = "C:\XenoRAT-Build-2-0",
    [string]$SourcePath = "C:\Users\Administrator\xeno-rat-main"  # Path to existing source code
)

# Colors for output
$Host.UI.RawUI.ForegroundColor = "White"

function Write-ColorOutput {
    param(
        [string]$Message,
        [string]$Color = "White"
    )
    Write-Host $Message -ForegroundColor $Color
}

function Write-Step {
    param([string]$Message)
    Write-ColorOutput "`n===> $Message" "Cyan"
}

function Write-Success {
    param([string]$Message)
    Write-ColorOutput "[OK] $Message" "Green"
}

function Write-Error-Custom {
    param([string]$Message)
    Write-ColorOutput "[ERROR] $Message" "Red"
}

function Write-Warning-Custom {
    param([string]$Message)
    Write-ColorOutput "[WARNING] $Message" "Yellow"
}

# Header
Clear-Host
Write-ColorOutput @"
+==============================================================+
|                                                              |
|              Xeno RAT - Local Build Script v2                |
|                                                              |
|  Source Path: $SourcePath
|  Build Path: $BuildPath
|                                                              |
+==============================================================+
"@ "Cyan"

# Step 1: Check administrator privileges
Write-Step "Checking administrator privileges"
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Warning-Custom "Script is running without administrator privileges. Some operations may fail."
    Write-Host "It is recommended to run PowerShell as administrator." -ForegroundColor Yellow
    $continue = Read-Host "Continue? (y/n)"
    if ($continue -ne 'y') {
        exit 1
    }
} else {
    Write-Success "Script is running with administrator privileges"
}

# Step 2: Check if source directory exists
Write-Step "Checking source directory"
if (-not (Test-Path $SourcePath)) {
    Write-Error-Custom "Source directory not found: $SourcePath"
    Write-Host "Please ensure the xeno-rat source code is located at: $SourcePath" -ForegroundColor Yellow
    Write-Host "Or specify a different path using -SourcePath parameter" -ForegroundColor Yellow
    exit 1
}
Write-Success "Source directory found: $SourcePath"

# Count files in source directory to verify it's not empty
$sourceFiles = Get-ChildItem -Path $SourcePath -Recurse -File | Measure-Object
Write-Host "  Total files in source: $($sourceFiles.Count)" -ForegroundColor Gray

# Step 3: Find MSBuild
Write-Step "Finding MSBuild"

# Extended list including Build Tools paths
$msbuildPaths = @(
    # VS 2022 Build Tools paths (MOST LIKELY based on Find-MSBuild.ps1 output)
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe",
    
    # VS 2022 Full versions
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe"
)

# Try to find MSBuild using vswhere (more reliable method)
Write-Host "Searching for MSBuild using multiple methods..." -ForegroundColor Gray

$msbuildPath = $null

# Method 1: Try vswhere.exe
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswherePath) {
    Write-Host "Using vswhere to locate MSBuild..." -ForegroundColor Gray
    try {
        $vsInstallPath = & $vswherePath -latest -products * -requires Microsoft.Component.MSBuild -property installationPath
        if ($vsInstallPath) {
            $possibleMSBuildPath = Join-Path $vsInstallPath "MSBuild\Current\Bin\MSBuild.exe"
            if (Test-Path $possibleMSBuildPath) {
                $msbuildPath = $possibleMSBuildPath
                Write-Host "Found MSBuild via vswhere: $msbuildPath" -ForegroundColor Gray
            }
        }
    } catch {
        Write-Host "vswhere search failed: $_" -ForegroundColor Gray
    }
}

# Method 2: Check predefined paths
if ($null -eq $msbuildPath) {
    Write-Host "Checking predefined paths..." -ForegroundColor Gray
    foreach ($path in $msbuildPaths) {
        if (Test-Path $path) {
            $msbuildPath = $path
            Write-Host "Found MSBuild at: $path" -ForegroundColor Gray
            break
        }
    }
}

if ($null -eq $msbuildPath) {
    Write-Error-Custom "MSBuild not found!"
    Write-Host "Please install Visual Studio Build Tools 2022" -ForegroundColor Yellow
    exit 1
}

Write-Success "MSBuild found: $msbuildPath"

# Step 4: Check NuGet
Write-Step "Checking NuGet availability"
$nugetPath = "C:\nuget\nuget.exe"
if (-not (Test-Path $nugetPath)) {
    Write-Warning-Custom "NuGet not found, downloading..."
    $nugetDir = "C:\nuget"
    if (-not (Test-Path $nugetDir)) {
        New-Item -ItemType Directory -Path $nugetDir -Force | Out-Null
    }
    try {
        Invoke-WebRequest -Uri "https://dist.nuget.org/win-x86-commandline/latest/nuget.exe" -OutFile $nugetPath
        Write-Success "NuGet downloaded: $nugetPath"
    } catch {
        Write-Error-Custom "Failed to download NuGet: $_"
        exit 1
    }
} else {
    Write-Success "NuGet found: $nugetPath"
}

# Step 5: Create working directory
Write-Step "Creating build output directory"
if (Test-Path $BuildPath) {
    Write-Warning-Custom "Directory $BuildPath already exists"
    $cleanup = Read-Host "Delete and create new? (y/n)"
    if ($cleanup -eq 'y') {
        Remove-Item -Path $BuildPath -Recurse -Force
        Write-Success "Old directory deleted"
    }
}

if (-not (Test-Path $BuildPath)) {
    New-Item -ItemType Directory -Path $BuildPath -Force | Out-Null
    Write-Success "Directory created: $BuildPath"
}

# Step 6: Find .sln files in source directory
Write-Step "Finding solution files (.sln)"
$slnFiles = Get-ChildItem -Path $SourcePath -Filter "*.sln" -Recurse
if ($slnFiles.Count -eq 0) {
    Write-Error-Custom ".sln files not found in source directory!"
    Write-Host "Please ensure the source directory contains valid Visual Studio solution files." -ForegroundColor Yellow
    exit 1
}

Write-Success "Found .sln files: $($slnFiles.Count)"
foreach ($sln in $slnFiles) {
    Write-Host "  - $($sln.FullName)" -ForegroundColor Gray
}

# Change to source directory for building
Set-Location $SourcePath

# Step 7: Restore NuGet packages
Write-Step "Restoring NuGet packages"
foreach ($sln in $slnFiles) {
    Write-Host "Restoring packages for: $($sln.Name)" -ForegroundColor Gray
    try {
        & $nugetPath restore $sln.FullName
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Packages restored for $($sln.Name)"
        } else {
            Write-Warning-Custom "Package restore may have issues for $($sln.Name) (exit code: $LASTEXITCODE)"
        }
    } catch {
        Write-Warning-Custom "Package restore error for $($sln.Name): $_"
    }
}

# Step 8: Clean previous builds (optional)
Write-Step "Cleaning previous builds"
foreach ($sln in $slnFiles) {
    Write-Host "Cleaning: $($sln.Name)" -ForegroundColor Gray
    try {
        & $msbuildPath $sln.FullName /t:Clean /v:minimal
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Cleaned: $($sln.Name)"
        }
    } catch {
        Write-Warning-Custom "Clean failed for $($sln.Name): $_"
    }
}

# Step 9: Compile projects
Write-Step "Compiling projects"
$buildConfig = "Release"
$buildPlatform = "Any CPU"

foreach ($sln in $slnFiles) {
    Write-Host "Compiling: $($sln.Name)" -ForegroundColor Gray
    try {
        & $msbuildPath $sln.FullName /p:Configuration=$buildConfig /p:Platform="$buildPlatform" /t:Rebuild /m /v:minimal
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Compilation successful: $($sln.Name)"
        } else {
            Write-Error-Custom "Compilation error: $($sln.Name) (code: $LASTEXITCODE)"
        }
    } catch {
        Write-Error-Custom "Exception during compilation of $($sln.Name): $_"
    }
}

# Step 10: Build release folder
Write-Step "Building release folder"
$releasePath = Join-Path $BuildPath "XenoRAT-Release"
if (Test-Path $releasePath) {
    Remove-Item -Path $releasePath -Recurse -Force
}
New-Item -ItemType Directory -Path $releasePath -Force | Out-Null

# Find compiled files in source directory
$serverExe = Get-ChildItem -Path $SourcePath -Filter "xeno rat server.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1
$clientExe = Get-ChildItem -Path $SourcePath -Filter "xeno rat client.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1

if ($null -eq $serverExe) {
    Write-Error-Custom "xeno rat server.exe not found in Release!"
    Write-Host "Build may have failed. Check compilation output above for errors." -ForegroundColor Yellow
} else {
    Copy-Item -Path $serverExe.FullName -Destination $releasePath
    Write-Success "Copied: xeno rat server.exe"
    
    # Copy all DLLs from server directory
    $serverDir = $serverExe.Directory.FullName
    Get-ChildItem -Path $serverDir -Filter "*.dll" | ForEach-Object {
        Copy-Item -Path $_.FullName -Destination $releasePath
    }
    Write-Success "Copied server dependencies"
}

if ($null -eq $clientExe) {
    Write-Warning-Custom "xeno rat client.exe not found in Release (this is normal, client is built through Builder)"
} else {
    # Create stub folder for Builder
    $stubPath = Join-Path $releasePath "stub"
    New-Item -ItemType Directory -Path $stubPath -Force | Out-Null
    Copy-Item -Path $clientExe.FullName -Destination $stubPath
    Write-Success "Copied: stub/xeno rat client.exe"
}

# FIXED: Copy only plugin DLL files, not source code
Write-Step "Copying plugin DLL files"
$pluginsRelease = Join-Path $releasePath "Plugins"
New-Item -ItemType Directory -Path $pluginsRelease -Force | Out-Null

# Find all plugin DLL files from Release folders
$pluginDlls = Get-ChildItem -Path "$SourcePath\xeno rat server\bin\Release\plugins" -Filter "*.dll" -ErrorAction SilentlyContinue
if ($pluginDlls) {
    foreach ($dll in $pluginDlls) {
        Copy-Item -Path $dll.FullName -Destination $pluginsRelease
        Write-Host "  Copied plugin: $($dll.Name)" -ForegroundColor Gray
    }
    Write-Success "Copied $($pluginDlls.Count) plugin DLL files"
} else {
    # Alternative: search for plugin DLLs in Plugins folder
    $pluginDlls = Get-ChildItem -Path "$SourcePath\Plugins" -Filter "*.dll" -Recurse | Where-Object { $_.Directory.Name -eq "Release" }
    if ($pluginDlls) {
        foreach ($dll in $pluginDlls) {
            Copy-Item -Path $dll.FullName -Destination $pluginsRelease
            Write-Host "  Copied plugin: $($dll.Name)" -ForegroundColor Gray
        }
        Write-Success "Copied $($pluginDlls.Count) plugin DLL files"
    } else {
        Write-Warning-Custom "No plugin DLL files found"
    }
}

# Step 11: Create archive
Write-Step "Creating archive"
$archivePath = Join-Path $BuildPath "XenoRAT-Release.zip"
if (Test-Path $archivePath) {
    Remove-Item -Path $archivePath -Force
}

try {
    Compress-Archive -Path "$releasePath\*" -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Success "Archive created: $archivePath"
    
    # Show archive size
    $archiveInfo = Get-Item $archivePath
    $sizeMB = [math]::Round($archiveInfo.Length / 1MB, 2)
    Write-Host "  Archive size: $sizeMB MB" -ForegroundColor Gray
} catch {
    Write-Error-Custom "Archive creation error: $_"
}

# Step 12: Summary information
Write-Step "Build completed!"
Write-Host @"

+==============================================================+
|                     BUILD RESULTS                            |
+--------------------------------------------------------------+
|                                                              |
|  Source: $SourcePath
|  Release folder: $releasePath
|  Archive: $archivePath
|                                                              |
|  Release contents:                                           |
"@ -ForegroundColor Green

$releaseFiles = Get-ChildItem -Path $releasePath -Recurse -File
Write-Host "|  Total files: $($releaseFiles.Count)" -ForegroundColor White

# Show file types summary
$fileGroups = $releaseFiles | Group-Object Extension
foreach ($group in $fileGroups | Sort-Object Name) {
    Write-Host "|    $($group.Name) files: $($group.Count)" -ForegroundColor Gray
}

# List main files
Write-Host "|" -ForegroundColor Green
Write-Host "|  Main files:" -ForegroundColor White
$mainFiles = $releaseFiles | Where-Object { $_.Extension -in ".exe", ".dll" } | Select-Object -First 10
foreach ($file in $mainFiles) {
    $relativePath = $file.FullName.Replace($releasePath, "").TrimStart('\')
    Write-Host "|    - $relativePath" -ForegroundColor Gray
}

if ($releaseFiles.Count -gt 10) {
    Write-Host "|    ... and $($releaseFiles.Count - 10) more files" -ForegroundColor Gray
}

Write-Host @"
|                                                              |
+--------------------------------------------------------------+
|                     SECURITY WARNINGS                        |
+--------------------------------------------------------------+
"@ -ForegroundColor Yellow

Write-Host @"
|  Several NuGet packages have known vulnerabilities:         |
|  - BouncyCastle 1.8.9 (3 moderate)                          |
|  - System.Net.Http 4.3.0 (2 HIGH)                           |
|  - System.Text.Json 8.0.0 (2 HIGH)                          |
|  - System.Text.RegularExpressions 4.3.0 (2 HIGH)            |
|                                                              |
|  Consider updating these packages to latest versions!        |
"@ -ForegroundColor Yellow

Write-Host @"
+--------------------------------------------------------------+
|                     NEXT STEPS                               |
+--------------------------------------------------------------+
|                                                              |
|  1. Extract the archive on the target machine                |
|  2. Run "xeno rat server.exe" as administrator               |
|  3. Use Builder to create the client                         |
|  4. Read the documentation in the repository                 |
|                                                              |
+==============================================================+
"@ -ForegroundColor Green

Write-Host "`nPress any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")