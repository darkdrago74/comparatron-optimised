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
    """Check if using virtual environment, otherwise use system installation."""
    # Check if we're already running in a virtual environment
    current_prefix = Path(sys.prefix)
    venv_path = Path(__file__).parent.absolute() / "dependencies" / "comparatron_env"

    # Check if we're already running in the virtual environment
    if hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix):
        print(f"Currently running in virtual environment: {current_prefix}")
        return True
    elif venv_path.exists():
        # Virtual environment exists but we're not in it
        print(f"Virtual environment detected at: {venv_path}, but not active")
        print("Consider activating it or using system installation")
        return False
    else:
        # No virtual environment, use system installation
        print("Using system Python installation")
        return False

def main():
    """Main entry point with virtual environment support and auto-start capability."""
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


def toggle_autostart_service(enable):
    """Function to enable/disable the systemd service for auto-start"""
    import subprocess
    import os

    try:
        # Check if user has sudo access
        if os.getenv('SUDO_USER') is not None or os.geteuid() == 0:
            # Already running as root/sudo
            if enable:
                result = subprocess.run(['systemctl', 'enable', 'comparatron.service'],
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    subprocess.run(['systemctl', 'start', 'comparatron.service'],
                                 capture_output=True, text=True)
                    return True, "Auto-start enabled successfully"
                else:
                    return False, f"Failed to enable auto-start: {result.stderr}"
            else:
                subprocess.run(['systemctl', 'stop', 'comparatron.service'],
                             capture_output=True, text=True)
                result = subprocess.run(['systemctl', 'disable', 'comparatron.service'],
                                      capture_output=True, text=True)
                if result.returncode == 0 or 'disabled' in result.stdout.lower():
                    return True, "Auto-start disabled successfully"
                else:
                    return False, f"Failed to disable auto-start: {result.stderr}"
        else:
            # Use sudo to run systemctl
            if enable:
                result = subprocess.run(['sudo', 'systemctl', 'enable', 'comparatron.service'],
                                      capture_output=True, text=True)
                if result.returncode == 0:
                    subprocess.run(['sudo', 'systemctl', 'start', 'comparatron.service'],
                                 capture_output=True, text=True)
                    return True, "Auto-start enabled successfully"
                else:
                    return False, f"Failed to enable auto-start: {result.stderr}"
            else:
                subprocess.run(['sudo', 'systemctl', 'stop', 'comparatron.service'],
                             capture_output=True, text=True)
                result = subprocess.run(['sudo', 'systemctl', 'disable', 'comparatron.service'],
                                      capture_output=True, text=True)
                if result.returncode == 0 or 'disabled' in result.stdout.lower():
                    return True, "Auto-start disabled successfully"
                else:
                    return False, f"Failed to disable auto-start: {result.stderr}"
    except Exception as e:
        return False, f"Error managing auto-start: {str(e)}"


if __name__ == "__main__":
    # Check if command line arguments were provided for auto-start management
    if len(sys.argv) > 1:
        arg = sys.argv[1].upper()
        if arg in ['ON', 'ENABLE', 'TRUE']:
            success, message = toggle_autostart_service(True)
            print(message)
            sys.exit(0 if success else 1)
        elif arg in ['OFF', 'DISABLE', 'FALSE']:
            success, message = toggle_autostart_service(False)
            print(message)
            sys.exit(0 if success else 1)
        elif arg in ['-H', '--HELP', 'HELP']:
            print("Usage: python main.py [ON|OFF|ENABLE|DISABLE]")
            print("  ON/ENABLE: Enable auto-start on boot")
            print("  OFF/DISABLE: Disable auto-start on boot")
            print("  No argument: Start the Comparatron web interface normally")
            sys.exit(0)

    # Normal operation - start the web interface
    main()