
@echo off
setlocal EnableExtensions
title Lociqra Launcher

REM =====================================================
REM LOCIQRA - WINDOWS DESKTOP LAUNCHER
REM =====================================================

cd /d "%~dp0"

set "ROOT=%~dp0"
set "PYTHON=%ROOT%backend\.venv\Scripts\python.exe"
set "APP_DIR=%ROOT%pocketbrain_app\build\windows\x64\runner\Release"
set "APP_EXE=%APP_DIR%\pocketbrain_app.exe"

set "BACKEND_URL=http://127.0.0.1:8000"
set "OLLAMA_URL=http://127.0.0.1:11434"
set "OLLAMA_MODEL=qwen2.5:1.5b"

echo.
echo ==============================================
echo                 LOCIQRA
echo          Local AI Document Assistant
echo ==============================================
echo.

REM =====================================================
REM STEP 1 - CHECK REQUIRED FILES
REM =====================================================

echo [1/6] Checking application files...

if not exist "%PYTHON%" (
    echo.
    echo ERROR: Python environment was not found.
    echo Expected:
    echo %PYTHON%
    echo.
    echo Set up the backend virtual environment first.
    goto error
)

if not exist "%APP_DIR%" (
    echo.
    echo ERROR: Flutter release folder was not found.
    echo.
    echo Build the application using:
    echo flutter build windows --release
    goto error
)

if not exist "%APP_EXE%" (
    echo.
    echo ERROR: Lociqra executable was not found.
    echo Expected:
    echo %APP_EXE%
    echo.
    echo Build the application using:
    echo flutter build windows --release
    goto error
)

where curl.exe >nul 2>&1
if errorlevel 1 (
    echo.
    echo ERROR: curl.exe was not found.
    echo A supported Windows installation is required.
    goto error
)

echo Application files found.
echo.

REM =====================================================
REM STEP 2 - CHECK OLLAMA
REM =====================================================

echo [2/6] Checking Ollama...

curl.exe --silent --fail --max-time 3 "%OLLAMA_URL%/api/tags" >nul 2>&1

if not errorlevel 1 (
    echo Ollama is already running.
    goto ollama_ready
)

where ollama.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Ollama was not found in PATH.
    echo Install Ollama or add it to your system PATH.
    goto error
)

echo Starting Ollama...

start "Lociqra Ollama" /min cmd /c "ollama serve"

echo Waiting for Ollama...

set /a OLLAMA_ATTEMPTS=0

:wait_ollama

curl.exe --silent --fail --max-time 2 "%OLLAMA_URL%/api/tags" >nul 2>&1

if not errorlevel 1 goto ollama_ready

set /a OLLAMA_ATTEMPTS+=1

if %OLLAMA_ATTEMPTS% GEQ 30 (
    echo.
    echo ERROR: Ollama did not start within the expected time.
    goto error
)

timeout /t 2 /nobreak >nul
goto wait_ollama

:ollama_ready

echo Ollama is ready.
echo.

REM =====================================================
REM STEP 3 - CHECK AI MODEL
REM =====================================================

echo [3/6] Checking local AI model...

curl.exe --silent --fail --max-time 10 "%OLLAMA_URL%/api/tags" | findstr /i /c:"%OLLAMA_MODEL%" >nul

if errorlevel 1 (
    echo.
    echo WARNING: Required AI model was not detected.
    echo Model: %OLLAMA_MODEL%
    echo.
    echo If the model is missing, run:
    echo ollama pull %OLLAMA_MODEL%
    echo.
    echo Lociqra may not answer questions until the
    echo required model is installed.
    echo.
) else (
    echo AI model detected: %OLLAMA_MODEL%
)

REM =====================================================
REM STEP 4 - START FASTAPI
REM =====================================================

echo [4/6] Checking Python backend...

curl.exe --silent --fail --max-time 3 "%BACKEND_URL%/health" >nul 2>&1

if not errorlevel 1 (
    echo FastAPI backend is already running.
    goto backend_ready
)

echo Starting FastAPI...

start "Lociqra Backend" /min cmd /k ""%PYTHON%" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000"

echo.
echo Waiting for backend to become ready...

set /a BACKEND_ATTEMPTS=0

:wait_backend

curl.exe --silent --fail --max-time 2 "%BACKEND_URL%/health" >nul 2>&1

if not errorlevel 1 goto backend_ready

set /a BACKEND_ATTEMPTS+=1

if %BACKEND_ATTEMPTS% GEQ 60 (
    echo.
    echo ERROR: Backend did not become ready.
    echo.
    echo Check the Lociqra Backend terminal for errors.
    goto error
)

timeout /t 2 /nobreak >nul
goto wait_backend

:backend_ready

echo FastAPI backend is ready.
echo.

REM =====================================================
REM STEP 5 - FINAL CONNECTION CHECK
REM =====================================================

echo [5/6] Checking local services...

curl.exe --silent --fail --max-time 3 "%BACKEND_URL%/health" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Backend connection failed.
    goto error
)

curl.exe --silent --fail --max-time 3 "%OLLAMA_URL%/api/tags" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Ollama connection failed.
    goto error
)

echo Backend: ONLINE
echo Ollama:  ONLINE
echo.

REM =====================================================
REM STEP 6 - LAUNCH LOCIQRA
REM =====================================================

echo [6/6] Launching Lociqra...
echo.

start "Lociqra" /d "%APP_DIR%" "%APP_EXE%"

if errorlevel 1 (
    echo.
    echo ERROR: Failed to launch Lociqra.
    goto error
)

echo ==============================================
echo       LOCIQRA LAUNCH COMMAND COMPLETED
echo ==============================================
echo.
echo You can close this launcher window.
echo.

exit /b 0

REM =====================================================
REM ERROR HANDLER
REM =====================================================

:error

echo.
echo ==============================================
echo         LOCIQRA STARTUP FAILED
echo ==============================================
echo.
pause
exit /b 1
