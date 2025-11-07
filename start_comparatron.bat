@echo off
REM Comparatron Windows Launcher
REM Starts the Flask server and opens the browser automatically

echo Starting Comparatron Flask Server...
echo This will open the Comparatron interface in your default browser

REM Change to the script's directory
cd /d "%~dp0"

REM Activate virtual environment if it exists
if exist "comparatron_env\Scripts\activate.bat" (
    call comparatron_env\Scripts\activate.bat
    echo Virtual environment activated
) else (
    echo Warning: Virtual environment not found. Using system Python.
)

REM Start the Flask server in a separate process
start python main.py

REM Wait a bit for the server to start, then open browser
timeout /t 3 /nobreak >nul
start http://localhost:5001

echo Comparatron server launched. Interface is available at http://localhost:5001
echo Close this window to shut down the server.
pause