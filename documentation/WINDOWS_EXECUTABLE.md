# Creating Windows Executable for Comparatron Flask Version

This document explains how to create a standalone Windows executable for the Comparatron Flask-based software using PyInstaller.

## Important Note: Web-Based Architecture

The current Comparatron uses a **Flask web interface** which creates a web server that can be accessed through any browser at `http://localhost:5001`. Unlike traditional desktop applications, this creates a web server that runs locally but requires a browser for the interface.

## Prerequisites

- Python installed on your Windows system (3.7 or later)
- All required dependencies installed (numpy, flask, pyserial, opencv-python, ezdxf, pillow)
- PyInstaller installed (install with `pip install pyinstaller`)

## Creating the Executable

### Option 1: Flask Server Executable (Primary Method)
This creates an executable that starts the Flask server:

```bash
pyinstaller main.py --name ComparatronWeb --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;."
```

### Option 2: One-File Executable
This creates a single .exe file that contains everything:

```bash
pyinstaller main.py -F --name ComparatronWeb --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;."
```

## PyInstaller Options Explained

- `-F` or `--onefile`: Creates a single executable file (larger, slower startup)
- `--name`: Sets the name of the executable
- `--add-data`: Includes additional files/directories in the executable
  - Format on Windows: `"source;destination"`
  - Format on Linux/Mac: `"source:destination"`
- `--hidden-import`: Explicitly include modules that PyInstaller might miss
- `--collect-all`: Collect all files from a package

## Recommended Command

For the best results with the Comparatron Flask application, use this command:

```bash
pyinstaller main.py --name ComparatronFlask --add-data "templates;templates" --add-data "LICENSE;." --add-data "README.md;." --hidden-import=flask --hidden-import=cv2 --hidden-import=PIL --hidden-import=serial --hidden-import=ezdxf
```

## Alternative: Enhanced Launcher Batch File

Since the Flask web interface requires a browser, consider creating both the executable and a batch file that starts it and opens the browser automatically:

Create `launch_comparatron.bat`:
```batch
@echo off
REM Comparatron Launcher
REM Starts the Flask server and opens the browser automatically

echo Starting Comparatron Flask Server...
echo Opening browser at http://localhost:5001

REM Change to the script's directory
cd /d "%~dp0"

REM Activate virtual environment if it exists
if exist "comparatron_env\Scripts\activate.bat" (
    call comparatron_env\Scripts\activate.bat
)

REM Start the Flask server in the background
start python main.py

REM Wait for server to start, then open browser
timeout /t 3 /nobreak >nul
start http://localhost:5001

echo Comparatron is running. Browse to http://localhost:5001
echo Close this window to stop the server.
pause
```

## Troubleshooting

### Common Issues and Solutions:

1. **Missing templates error**
   - Ensure `--add-data "templates;templates"` is included
   - Flask needs access to the templates directory

2. **Import errors after building**
   - Add `--hidden-import=module_name` for each missing module
   - Common ones: `--hidden-import=flask`, `--hidden-import=cv2`

3. **Large file size**
   - Flask applications tend to be larger due to web framework requirements
   - Consider distributing as a directory instead of single file

4. **Template directory not found**
   - If using one-file approach, some resources might not resolve properly
   - Consider using directory-based executable for reliability

## Distribution

After building, distribute:
- The executable in the `dist/` folder
- A shortcut or batch file that opens the browser to `http://localhost:5001`
- Inform users that the interface will be available in their browser

## User Experience

When users run the executable:
1. A console window appears showing server startup
2. The Flask server starts listening on `http://localhost:5001`
3. Users access the interface by opening a browser 
4. All functionality is available through the web interface

## Important Considerations

- **Internet Browser Required**: Users must have a web browser installed
- **Local Network Access**: The interface can be accessed from other devices on the same network
- **Multiple Interfaces**: Both the Flask web interface and any browser can access the same server
- **Port Configuration**: The server runs on port 5001 by default