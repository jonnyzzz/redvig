@echo off
rem Bazel wrapper for Windows. Same job as ./bazelw: download a pinned Bazelisk,
rem check its SHA-256, cache it, and run it with the given arguments.
setlocal

set "BAZELISK_VERSION=v1.31.0"
if /i "%PROCESSOR_ARCHITEW6432%"=="ARM64" (set "BAZELISK_CPU=arm64") else if /i "%PROCESSOR_ARCHITECTURE%"=="ARM64" (set "BAZELISK_CPU=arm64") else (set "BAZELISK_CPU=amd64")
if "%BAZELISK_CPU%"=="arm64" (set "BAZELISK_SHA256=4fb1de3f6e66c88a33d7eb119350d32c229f058f6e50580891670781359d0e93") else (set "BAZELISK_SHA256=19ec714cfaae7bffbf9379c4f19cf7f7b22fce7f2573950f6815cb0da977e398")

set "BAZELISK_ASSET=bazelisk-windows-%BAZELISK_CPU%.exe"
set "BAZELISK_DIR=%LOCALAPPDATA%\redvig\bazelisk\%BAZELISK_VERSION%"
set "BAZELISK=%BAZELISK_DIR%\%BAZELISK_ASSET%"

if not exist "%BAZELISK%" (
  powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -Command ^
    "$ErrorActionPreference = 'Stop'; $ProgressPreference = 'SilentlyContinue';" ^
    "[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;" ^
    "New-Item -ItemType Directory -Force -Path $env:BAZELISK_DIR | Out-Null;" ^
    "$tmp = Join-Path $env:BAZELISK_DIR ('.tmp.' + [guid]::NewGuid());" ^
    "$url = 'https://github.com/bazelbuild/bazelisk/releases/download/' + $env:BAZELISK_VERSION + '/' + $env:BAZELISK_ASSET;" ^
    "[Console]::Error.WriteLine('bazelw: downloading ' + $url);" ^
    "Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmp;" ^
    "$actual = (Get-FileHash -Algorithm SHA256 -Path $tmp).Hash.ToLowerInvariant();" ^
    "if ($actual -ne $env:BAZELISK_SHA256) { Remove-Item -Force $tmp; throw ('SHA-256 mismatch: expected ' + $env:BAZELISK_SHA256 + ', got ' + $actual) };" ^
    "Move-Item -Force -Path $tmp -Destination $env:BAZELISK"
  if errorlevel 1 exit /b 1
)

"%BAZELISK%" %*
exit /b %ERRORLEVEL%
