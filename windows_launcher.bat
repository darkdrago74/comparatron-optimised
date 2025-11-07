@echo off
REM Comparatron Windows Launcher Script
REM This script starts the Flask server and automatically opens the browser

echo Starting Comparatron Flask Server...
echo The interface will be available at http://localhost:5001
echo.

REM Change to the script's directory
cd /d "%~dp0"

REM Check if virtual environment exists and activate it
if exist "comparatron_env\Scripts\activate.bat" (
    echo Activating virtual environment...
    call comparatron_env\Scripts\activate.bat
) else (
    echo Virtual environment not found. Using system Python.
)

REM Start the Comparatron Flask server
echo Starting Comparatron server...
start /min python main.py

REM Wait a bit for server to initialize
timeout /t 5 /nobreak >nul

REM Open the browser to the interface
echo Opening Comparatron interface in browser...
start http://localhost:5001

echo.
echo Comparatron is now running!
echo Interface: http://localhost:5001
echo To stop the server, close the Python process or use Ctrl+C in its console window.
echo.
pause