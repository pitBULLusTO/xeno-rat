# Find-MSBuild.ps1
# Diagnostic script to locate MSBuild on Windows Server

Write-Host "=== MSBuild Locator Script ===" -ForegroundColor Cyan
Write-Host "This script will search for MSBuild installation on your system" -ForegroundColor White
Write-Host ""

$foundPaths = @()

# Method 1: Use vswhere.exe (most reliable for VS 2017+)
Write-Host "[1/4] Searching using vswhere.exe..." -ForegroundColor Yellow
$vswherePath = "${env:ProgramFiles(x86)}\Microsoft Visual Studio\Installer\vswhere.exe"
if (Test-Path $vswherePath) {
    Write-Host "      vswhere.exe found, querying installations..." -ForegroundColor Gray
    try {
        # Get all VS installations
        $vsInstalls = & $vswherePath -all -products * -format json | ConvertFrom-Json
        
        foreach ($install in $vsInstalls) {
            Write-Host "      Found: $($install.displayName)" -ForegroundColor Green
            Write-Host "        Path: $($install.installationPath)" -ForegroundColor Gray
            
            # Check for MSBuild in this installation
            $msbuildTestPaths = @(
                "$($install.installationPath)\MSBuild\Current\Bin\MSBuild.exe",
                "$($install.installationPath)\MSBuild\Current\Bin\amd64\MSBuild.exe",
                "$($install.installationPath)\MSBuild\15.0\Bin\MSBuild.exe"
            )
            
            foreach ($testPath in $msbuildTestPaths) {
                if (Test-Path $testPath) {
                    Write-Host "        MSBuild: $testPath" -ForegroundColor Green
                    $foundPaths += $testPath
                    break
                }
            }
        }
    } catch {
        Write-Host "      vswhere query failed: $_" -ForegroundColor Red
    }
} else {
    Write-Host "      vswhere.exe not found" -ForegroundColor Gray
}

# Method 2: Check common installation paths
Write-Host ""
Write-Host "[2/4] Checking common installation paths..." -ForegroundColor Yellow

$commonPaths = @(
    # VS 2022 Build Tools
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2022\BuildTools\MSBuild\Current\Bin\amd64\MSBuild.exe",
    
    # VS 2019 Build Tools
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2019\BuildTools\MSBuild\Current\Bin\MSBuild.exe",
    
    # VS 2022 Community/Professional/Enterprise
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Professional\MSBuild\Current\Bin\MSBuild.exe",
    "${env:ProgramFiles}\Microsoft Visual Studio\2022\Enterprise\MSBuild\Current\Bin\MSBuild.exe",
    
    # Older MSBuild versions
    "${env:ProgramFiles(x86)}\MSBuild\14.0\Bin\MSBuild.exe",
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio\2017\BuildTools\MSBuild\15.0\Bin\MSBuild.exe"
)

foreach ($path in $commonPaths) {
    if (Test-Path $path) {
        Write-Host "      Found: $path" -ForegroundColor Green
        $foundPaths += $path
    }
}

# Method 3: Search using Windows Registry
Write-Host ""
Write-Host "[3/4] Searching Windows Registry..." -ForegroundColor Yellow

$regPaths = @(
    "HKLM:\SOFTWARE\Microsoft\MSBuild\ToolsVersions\",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\MSBuild\ToolsVersions\"
)

foreach ($regPath in $regPaths) {
    if (Test-Path $regPath) {
        $versions = Get-ChildItem $regPath -ErrorAction SilentlyContinue
        foreach ($version in $versions) {
            try {
                $msbuildPath = (Get-ItemProperty -Path $version.PSPath -Name MSBuildToolsPath -ErrorAction SilentlyContinue).MSBuildToolsPath
                if ($msbuildPath) {
                    $fullPath = Join-Path $msbuildPath "MSBuild.exe"
                    if (Test-Path $fullPath) {
                        Write-Host "      Registry version $($version.PSChildName): $fullPath" -ForegroundColor Green
                        $foundPaths += $fullPath
                    }
                }
            } catch {
                # Ignore errors
            }
        }
    }
}

# Method 4: Search Program Files directories
Write-Host ""
Write-Host "[4/4] Deep searching Program Files..." -ForegroundColor Yellow

$searchDirs = @(
    "${env:ProgramFiles(x86)}\Microsoft Visual Studio",
    "${env:ProgramFiles}\Microsoft Visual Studio"
)

foreach ($searchDir in $searchDirs) {
    if (Test-Path $searchDir) {
        Write-Host "      Searching in: $searchDir" -ForegroundColor Gray
        $msbuildFiles = Get-ChildItem -Path $searchDir -Filter "MSBuild.exe" -Recurse -ErrorAction SilentlyContinue | 
                        Where-Object { $_.FullName -notlike "*\Temp\*" -and $_.FullName -notlike "*\Cache\*" }
        
        foreach ($file in $msbuildFiles) {
            Write-Host "        Found: $($file.FullName)" -ForegroundColor Green
            $foundPaths += $file.FullName
        }
    }
}

# Display results
Write-Host ""
Write-Host "=== SEARCH RESULTS ===" -ForegroundColor Cyan

if ($foundPaths.Count -eq 0) {
    Write-Host "[ERROR] No MSBuild installations found!" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install one of the following:" -ForegroundColor Yellow
    Write-Host "1. Visual Studio Build Tools 2022" -ForegroundColor White
    Write-Host "   Download: https://visualstudio.microsoft.com/downloads/#build-tools-for-visual-studio-2022" -ForegroundColor Gray
    Write-Host "   During installation, select: '.NET desktop build tools' workload" -ForegroundColor Gray
    Write-Host ""
    Write-Host "2. Visual Studio 2022 Community (free)" -ForegroundColor White
    Write-Host "   Download: https://visualstudio.microsoft.com/vs/community/" -ForegroundColor Gray
} else {
    Write-Host "Found $($foundPaths.Count) MSBuild installation(s):" -ForegroundColor Green
    $uniquePaths = $foundPaths | Select-Object -Unique
    
    for ($i = 0; $i -lt $uniquePaths.Count; $i++) {
        Write-Host ""
        Write-Host "[$($i+1)] $($uniquePaths[$i])" -ForegroundColor White
        
        # Test if this MSBuild works
        try {
            $version = & $uniquePaths[$i] -version 2>&1 | Select-Object -First 1
            Write-Host "    Version: $version" -ForegroundColor Gray
        } catch {
            Write-Host "    [Warning] Could not get version" -ForegroundColor Yellow
        }
    }
    
    Write-Host ""
    Write-Host "=== RECOMMENDED PATH TO USE ===" -ForegroundColor Cyan
    Write-Host $uniquePaths[0] -ForegroundColor Green
    
    # Copy to clipboard if possible
    try {
        $uniquePaths[0] | Set-Clipboard
        Write-Host ""
        Write-Host "[INFO] Path copied to clipboard!" -ForegroundColor Cyan
    } catch {
        # Clipboard not available
    }
    
    Write-Host ""
    Write-Host "To use this MSBuild path in the Build script, you can:" -ForegroundColor Yellow
    Write-Host "1. The script should automatically find it now" -ForegroundColor White
    Write-Host "2. Or manually specify it if needed" -ForegroundColor White
}

Write-Host ""
Write-Host "Press any key to exit..." -ForegroundColor Cyan
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")