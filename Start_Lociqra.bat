
@echo off
setlocal EnableExtensions EnableDelayedExpansion
title Lociqra Launcher

REM =====================================================
REM LOCIQRA - WINDOWS DESKTOP LAUNCHER
REM Flutter + FastAPI + Ollama
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
echo                  LOCIQRA
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
    echo Run Setup_Lociqra.bat first.
    goto error
)

if not exist "%ROOT%backend\main.py" (
    echo.
    echo ERROR: Backend main.py was not found.
    goto error
)

if not exist "%APP_EXE%" (
    echo.
    echo ERROR: Flutter release executable was not found.
    echo Expected:
    echo %APP_EXE%
    echo.
    echo Run Setup_Lociqra.bat first.
    echo Or build manually using:
    echo flutter build windows --release
    goto error
)

where curl.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: curl.exe was not found.
    goto error
)

echo Application files found.
echo.

REM =====================================================
REM STEP 2 - CHECK OLLAMA
REM =====================================================

echo [2/6] Checking Ollama...

curl.exe --silent --fail --max-time 3 "%OLLAMA_URL%/api/tags" >nul 2>&1

if not errorlevel 1 goto ollama_ready

where ollama.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Ollama was not found.
    echo Install Ollama or run Setup_Lociqra.bat.
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

if !OLLAMA_ATTEMPTS! GEQ 30 (
    echo.
    echo ERROR: Ollama did not become ready.
    echo Check whether port 11434 is available.
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

where ollama.exe >nul 2>&1

if errorlevel 1 (
    echo.
    echo ERROR: Ollama command was not found.
    goto error
)

ollama list | findstr /i /c:"%OLLAMA_MODEL%" >nul

if errorlevel 1 (
    echo.
    echo ERROR: Required AI model is missing.
    echo Model: %OLLAMA_MODEL%
    echo.
    echo Run:
    echo ollama pull %OLLAMA_MODEL%
    echo.
    echo Or run Setup_Lociqra.bat first.
    goto error
)

echo AI model detected: %OLLAMA_MODEL%
echo.

REM =====================================================
REM STEP 4 - START FASTAPI BACKEND
REM =====================================================

echo [4/6] Checking Python backend...

curl.exe --silent --fail --max-time 3 "%BACKEND_URL%/health" >nul 2>&1

if not errorlevel 1 (
    echo Backend is already responding.
    goto backend_ready
)

echo Starting FastAPI backend...

REM Launch from the project root so Python can
REM import backend.main correctly.

start "Lociqra Backend" /min /d "%ROOT%" cmd /k ""%PYTHON%" -m uvicorn backend.main:app --host 127.0.0.1 --port 8000"

echo Waiting for backend to become ready...

set /a BACKEND_ATTEMPTS=0

:wait_backend

curl.exe --silent --fail --max-time 2 "%BACKEND_URL%/health" >nul 2>&1

if not errorlevel 1 goto backend_ready

set /a BACKEND_ATTEMPTS+=1

if !BACKEND_ATTEMPTS! GEQ 60 (
    echo.
    echo ERROR: Backend did not become ready.
    echo.
    echo Check the Lociqra Backend window for errors.
    echo.
    echo Possible causes:
    echo - Missing Python dependencies
    echo - MiniLM embedding model not downloaded
    echo - Port 8000 is already occupied
    echo - Backend startup error
    goto error
)

timeout /t 2 /nobreak >nul
goto wait_backend

:backend_ready

echo FastAPI backend is ready.
echo.

REM =====================================================
REM STEP 5 - VERIFY LOCAL SERVICES
REM =====================================================

echo [5/6] Verifying local services...

curl.exe --silent --fail --max-time 3 "%BACKEND_URL%/health" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Backend health check failed.
    goto error
)

curl.exe --silent --fail --max-time 3 "%OLLAMA_URL%/api/tags" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Ollama connection failed.
    goto error
)

echo.
echo Backend: ONLINE
echo Ollama:  ONLINE
echo AI Model: %OLLAMA_MODEL%
echo.

REM =====================================================
REM STEP 6 - LAUNCH FLUTTER DESKTOP APPLICATION
REM =====================================================

echo [6/6] Launching Lociqra...
echo.

start "Lociqra" /d "%APP_DIR%" "%APP_EXE%"

if errorlevel 1 (
    echo.
    echo ERROR: Could not launch Lociqra.
    goto error
)

echo.
echo ==============================================
echo        LOCIQRA LAUNCH COMMAND COMPLETED
echo ==============================================
echo.
echo The application should now be opening.
echo.
echo Keep the backend running while using Lociqra.
echo.

exit /b 0

REM =====================================================
REM ERROR HANDLER
REM =====================================================

:error

echo.
echo ==============================================
echo          LOCIQRA STARTUP FAILED
echo ==============================================
echo.
echo Review the error messages above.
echo.
pause
exit /b 1
