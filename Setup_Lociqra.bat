
@echo off
setlocal EnableExtensions
title Lociqra - First Time Setup

REM ================================================
REM LOCIQRA - WINDOWS FIRST-TIME SETUP
REM ================================================

cd /d "%~dp0"

set "ROOT=%~dp0"
set "BACKEND=%ROOT%backend"
set "PYTHON=%BACKEND%\.venv\Scripts\python.exe"
set "APP=%ROOT%pocketbrain_app"
set "MODEL=qwen2.5:1.5b"

echo.
echo ================================================
echo                  LOCIQRA
echo             FIRST-TIME SETUP
echo ================================================
echo.

REM ================================================
REM STEP 1 - CHECK PROJECT FILES
REM ================================================

echo [1/8] Checking project files...

if not exist "%BACKEND%\main.py" (
    echo ERROR: backend\main.py not found.
    goto error
)

if not exist "%BACKEND%\requirements.txt" (
    echo ERROR: backend\requirements.txt not found.
    echo Create this file on the developer laptop
    echo and push it to GitHub.
    goto error
)

if not exist "%APP%\pubspec.yaml" (
    echo ERROR: Flutter project not found.
    goto error
)

echo Project files found.
echo.

REM ================================================
REM STEP 2 - CHECK PYTHON
REM ================================================

echo [2/8] Checking Python...

where py.exe >nul 2>&1

if errorlevel 1 (
    echo ERROR: Python launcher not found.
    echo Install Python with the py launcher.
    goto error
)

py -3 -c "import sys; assert sys.version_info >= (3,10)" >nul 2>&1

if errorlevel 1 (
    echo ERROR: Python 3.10 or newer is required.
    goto error
)

echo Python found.
echo.

REM ================================================
REM STEP 3 - CHECK FLUTTER
REM ================================================

echo [3/8] Checking Flutter...

where flutter.bat >nul 2>&1

if errorlevel 1 (
    echo ERROR: Flutter was not found in PATH.
    echo Install Flutter and configure its PATH.
    goto error
)

call flutter --version

if errorlevel 1 goto error

echo Flutter found.
echo.

REM ================================================
REM STEP 4 - CHECK OLLAMA
REM ================================================

echo [4/8] Checking Ollama...

where ollama.exe >nul 2>&1

if errorlevel 1 (
    echo ERROR: Ollama was not found in PATH.
    echo Install Ollama and try again.
    goto error
)

ollama --version

if errorlevel 1 goto error

echo Ollama found.
echo.

REM ================================================
REM STEP 5 - PREPARE PYTHON BACKEND
REM ================================================

echo [5/8] Preparing Python backend...

if not exist "%PYTHON%" (
    echo Creating virtual environment...

    py -3 -m venv "%BACKEND%\.venv"

    if errorlevel 1 (
        echo ERROR: Could not create virtual environment.
        goto error
    )
)

echo Installing Python dependencies...

"%PYTHON%" -m pip install -r "%BACKEND%\requirements.txt"

if errorlevel 1 (
    echo ERROR: Python dependency installation failed.
    goto error
)

echo Python backend ready.
echo.

REM ================================================
REM STEP 6 - DOWNLOAD MINILM EMBEDDING MODEL
REM ================================================

echo [6/8] Preparing MiniLM embedding model...
echo This may take several minutes on first setup.

"%PYTHON%" -c "from sentence_transformers import SentenceTransformer; SentenceTransformer('sentence-transformers/all-MiniLM-L6-v2')"

if errorlevel 1 (
    echo ERROR: MiniLM model download failed.
    echo Check your internet connection.
    goto error
)

echo MiniLM ready.
echo.

REM ================================================
REM STEP 7 - DOWNLOAD QWEN MODEL
REM ================================================

echo [7/8] Preparing Ollama AI model...

ollama pull %MODEL%

if errorlevel 1 (
    echo ERROR: Failed to download %MODEL%.
    echo Ensure Ollama is running and connected.
    goto error
)

echo AI model ready.
echo.

REM ================================================
REM STEP 8 - BUILD FLUTTER WINDOWS APPLICATION
REM ================================================

echo [8/8] Building Flutter desktop application...

cd /d "%APP%"

call flutter pub get

if errorlevel 1 (
    echo ERROR: Flutter dependency installation failed.
    goto error
)

call flutter build windows --release

if errorlevel 1 (
    echo ERROR: Flutter Windows build failed.
    echo Check Flutter Doctor and Visual Studio C++ tools.
    goto error
)

cd /d "%ROOT%"

if not exist "%APP%\build\windows\x64\runner\Release\pocketbrain_app.exe" (
    echo ERROR: Expected Windows executable was not found.
    goto error
)

REM ================================================
REM SETUP COMPLETE
REM ================================================

echo.
echo ================================================
echo          LOCIQRA SETUP COMPLETE
echo ================================================
echo.
echo Python backend: READY
echo MiniLM embeddings: READY
echo Qwen AI model: READY
echo Flutter desktop build: READY
echo.
echo You can now run:
echo Start_Lociqra.bat
echo.
pause
exit /b 0

REM ================================================
REM ERROR HANDLER
REM ================================================

:error

cd /d "%ROOT%"

echo.
echo ================================================
echo           LOCIQRA SETUP FAILED
echo ================================================
echo.
echo Review the error above and try again.
echo.
pause
exit /b 1
