# Creating Windows Executable for Comparatron

This document explains how to create a standalone Windows executable for the Comparatron software using PyInstaller.

## Prerequisites

- Python installed on your Windows system
- All required dependencies installed (numpy, dearpygui, pyserial, opencv-python, ezdxf, serial-tools)
- PyInstaller installed (install with `pip install pyinstaller`)

## Creating the Executable

### Method 1: One-File Executable (Recommended)
This creates a single .exe file that contains everything needed to run the application:

```bash
pyinstaller main_refactored.py -F --name Comparatron --add-data "LICENSE;." --add-data "README.md;."
```

### Method 2: Directory with Dependencies
This creates a directory containing the executable and all dependencies:

```bash
pyinstaller main_refactored.py --name Comparatron --add-data "LICENSE;." --add-data "README.md;."
```

## PyInstaller Options Explained

- `-F` or `--onefile`: Creates a single executable file
- `--name`: Sets the name of the executable (default: main_refactored)
- `--add-data`: Includes additional files in the executable
  - Format on Windows: `"source;destination"`
  - Format on Linux/Mac: `"source:destination"`
- `--windowed`: Use this if you want to run without a console window (optional)

## Complete Command with Optimizations

For the best results with the Comparatron application, use this command:

```bash
pyinstaller main_refactored.py -F --name Comparatron --add-data "LICENSE;." --add-data "README.md;." --hidden-import=cv2 --hidden-import=dearpygui --hidden-import=serial --hidden-import=ezdxf
```

## Advanced Options

If you encounter issues, you can use additional options:

- `--exclude-module`: Exclude specific modules to reduce file size
- `--icon`: Add an icon to the executable: `--icon=icon.ico`
- `--clean`: Clean PyInstaller cache and temporary files before building

Example with icon:
```bash
pyinstaller main_refactored.py -F --name Comparatron --icon=comparatron_icon.ico --add-data "LICENSE;." --add-data "README.md;."
```

## Troubleshooting

### Common Issues and Solutions:

1. **Missing modules error**
   - Add `--hidden-import=module_name` for each missing module

2. **Large file size**
   - Use `--exclude-module` to exclude unnecessary modules
   - Consider using directory output instead of single file

3. **OpenCV issues**
   - Ensure opencv-python is installed correctly
   - Add `--hidden-import=cv2`

4. **DearPyGUI issues**
   - Add `--hidden-import=dearpygui`

## Example Complete Build Script

Create a batch file to automate the build process:

```batch
@echo off
echo Building Comparatron executable...
pyinstaller main_refactored.py -F --name Comparatron --add-data "LICENSE;." --add-data "README.md;." --hidden-import=cv2 --hidden-import=dearpygui --hidden-import=serial --hidden-import=ezdxf
if %ERRORLEVEL% EQU 0 (
    echo Build completed successfully!
    echo Executable is located in the dist folder.
) else (
    echo Build failed with error level %ERRORLEVEL%
)
pause
```

## Distribution

Once built, the executable can be run on any Windows system without requiring Python to be installed. The executable will be found in the `dist/` folder created by PyInstaller.

Place the executable in a dedicated folder for distribution. Users can run it directly without any additional setup.

## Updating the Executable

To update the executable with new features:
1. Make changes to the source code
2. Delete the old build directories (`build/`, `dist/`, and `*.spec` file)
3. Run the PyInstaller command again