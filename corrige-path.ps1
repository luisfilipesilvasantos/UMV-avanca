@echo off
setlocal enabledelayedexpansion

:: Define the existing PATH as provided
set EXISTING_PATH=C:\py\pyenv\pyenv-win\bin;C:\py\pyenv\pyenv-win\shims;C:\py\pyenv\pyenv-win\bin;C:\py\pyenv\pyenv-win\shims;%USERPROFILE%\AppData\Local\Microsoft\WindowsApps;C:\Users\luisf\AppData\Local\pnpm;C:\Users\luisf\AppData\Local\Programs\oh-my-posh\bin;C:\Windows\system32;C:\Users\luisf\;

:: List of essential paths to add based on your directories (deduplicated and prioritized for tools/compilers)
:: These are inferred from common bin directories in your C:\ root folders
set NEW_PATHS=C:\mingw64\bin;C:\msys64\mingw64\bin;C:\msys64\usr\bin;C:\cmake\bin;C:\ninja;C:\ffmpeg-2024-10-13-git-e347b4ff31-full_build\bin;C:\node-v22.18.0-win-x64;C:\clang+llvm-19.1.1-x86_64-pc-windows-msvc\bin;C:\w64devkit-2.3.0\bin;C:\vcpkg;C:\nvm4w;C:\npm;C:\WinFBE_Suite\toolchains\FreeBASIC-1.10.0-winlibs-gcc-9.3.0\bin;C:\WinFBE_Suite\toolchains\FreeBASIC-1.10.0-winlibs-gcc-9.3.0\bin\win64;C:\VisualFBEditor.1.3.6\bin;C:\cygwin64\bin;C:\curl-8.9.1_3-win64-mingw\bin;C:\winlibs-x86_64-posix-seh-gcc-14.2.0-mingw-w64msvcrt-12.0.0-r3\bin;C:\VulkanSDK\Bin;C:\TensorRT\bin;C:\openvino\bin;C:\SDL3-3.2.20-win32-x64;C:\SDL\bin;C:\msys64\bin;C:\msys641\bin;C:\Powershell7;C:\python313\Scripts;C:\python313;C:\python311\Scripts;C:\python311;C:\python310\Scripts;C:\python310;C:\python38\Scripts;C:\python38;C:\TURBOC3\BIN;C:\rubberband\bin;C:\sox;C:\sqlite;C:\ffmpeg\bin;C:\ffmpeg-7.0.2-full_build\bin

:: Combine existing and new paths, avoiding duplicates
set FULL_PATH=!EXISTING_PATH!
for %%p in (%NEW_PATHS:;= %) do (
    echo !FULL_PATH! | findstr /C:%%p >nul
    if errorlevel 1 (
        set FULL_PATH=!FULL_PATH!%%p;
    )
)

:: Set the PATH persistently using setx (user-level)
setx PATH !FULL_PATH! /M

echo PATH updated. Restart your command prompt or system for changes to take effect.
pause

