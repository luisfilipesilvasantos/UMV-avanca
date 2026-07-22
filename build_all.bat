@echo off
REM ============================================
REM UMC - Unified Memory Controller Build Script
REM ============================================
echo Building UMC...

REM Build UMC DLL
msbuild "umc.vcxproj" /p:Configuration=Release /p:Platform=x64 /v:minimal
if errorlevel 1 (
    echo [FAIL] UMC DLL build failed
    exit /b 1
)
echo [OK] UMC.dll built

REM Build demo executable  
msbuild "umc_demo.vcxproj" /p:Configuration=Release /p:Platform=x64 /v:minimal
if errorlevel 1 (
    echo [FAIL] UMC Demo build failed
    exit /b 1
)
echo [OK] umc_demo.exe built

echo ============================================
echo Build complete!
echo   DLL: x64\Release\umc.dll
echo   Demo: x64\Release\umc_demo.exe
echo ============================================
echo.
echo To run the demo:
echo   x64\Release\umc_demo.exe
