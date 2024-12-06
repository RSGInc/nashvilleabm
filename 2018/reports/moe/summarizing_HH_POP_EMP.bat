@echo off
set PYTHON_EXEC=%~dp0..\..\..\..\..\..\GitHub\nashvillePopSim\Setup\software\Anaconda2\envs\py3env\python.exe
set SCRIPT_DIR=%~dp0
set LOG_FILE=%SCRIPT_DIR%error_log.txt

:: Debugging path resolution
echo Batch File Directory: %~dp0
for %%I in ("%PYTHON_EXEC%") do set RESOLVED_PATH=%%~fI

:: Check if resolved Python executable exists
if exist "%RESOLVED_PATH%" (
    echo Python executable found at: "%RESOLVED_PATH%"
) else (
    echo Python executable NOT found at: "%RESOLVED_PATH%"
    pause
    exit /b 1
)

:: Clear the previous log file if it exists
if exist "%LOG_FILE%" del "%LOG_FILE%"

cd %SCRIPT_DIR%

"%RESOLVED_PATH%" process_data.py >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo An error occurred. Check the error log at "%LOG_FILE%".
    exit /b 1
)

:: Exit gracefully if successful
exit /b 0