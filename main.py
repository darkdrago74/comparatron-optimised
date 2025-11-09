"""
Comparatron V1.1 - Flask Version
by Cameron Coward 
fork by RGP
http://www.cameroncoward.com

This is a DIY digital optical comparator that uses a USB microscope mounted to a 
CNC pen plotter to take precise measurements of physical objects through visual means.

Flask version for web compatibility and better UI scaling.

Note: This script will automatically detect and use the virtual environment if available,
otherwise it will attempt to import from the system Python installation.
"""
import os
import sys
import subprocess
from pathlib import Path

def setup_virtual_environment():
    """Detect and set up the virtual environment if available."""
    # Look for virtual environment relative to this script's location
    script_dir = Path(__file__).parent.absolute()
    venv_paths = [
        script_dir / "dependencies" / "comparatron_env",
        Path.home() / "comparatron_env",
        Path(os.environ.get("VIRTUAL_ENV", "")) if os.environ.get("VIRTUAL_ENV") else None
    ]
    
    for venv_path in venv_paths:
        if venv_path and venv_path.exists():
            venv_bin = venv_path / "bin" if os.name != "nt" else venv_path / "Scripts"
            python_executable = venv_bin / "python3"
            
            if python_executable.exists():
                # Check if we're already running in the virtual environment
                current_prefix = Path(sys.prefix)
                if current_prefix.resolve() != venv_path.resolve():
                    print(f"Virtual environment detected at: {venv_path}")
                    print("Re-executing with virtual environment...")
                    
                    # Re-execute the script using the virtual environment's Python
                    os.execv(str(python_executable), [str(python_executable), str(Path(__file__))] + sys.argv[1:])
                else:
                    print(f"Already running in virtual environment: {current_prefix}")
                    return True
    
    # If no virtual environment found, continue with system installation
    print("No virtual environment detected, using system Python installation")
    return False

def main():
    """Main entry point with virtual environment support."""
    # Setup virtual environment if available
    venv_used = setup_virtual_environment()
    
    if venv_used:
        print("Using packages from virtual environment")
    else:
        print("Using packages from system installation")
    
    # Import the Flask GUI after ensuring proper environment
    try:
        from gui_flask import main as run_flask_gui
        print("Successfully imported Flask GUI")
    except ImportError as e:
        print(f"Error importing GUI: {e}")
        print("Trying to ensure dependencies are available...")
        
        # Try to install missing packages if needed
        try:
            import subprocess
            import importlib
            missing_packages = []
            
            for pkg in ["flask", "numpy", "cv2", "PIL", "serial", "ezdxf"]:
                try:
                    if pkg == "cv2":
                        import cv2 as cv
                    elif pkg == "PIL":
                        import PIL
                    elif pkg == "serial":
                        import serial
                    else:
                        importlib.import_module(pkg)
                except ImportError:
                    missing_packages.append(pkg)
            
            if missing_packages:
                print(f"Missing packages detected: {missing_packages}")
                print("Please run the installation script first:")
                print("cd dependencies/")
                print("./install_dependencies_universal.sh")
                return
        except Exception as e:
            print(f"Error checking packages: {e}")
        
        raise e
    
    # Run the Flask GUI
    run_flask_gui()

if __name__ == "__main__":
    main()