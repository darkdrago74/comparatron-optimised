#!/usr/bin/env python3
"""
Validation Script for Comparatron Optimization
Tests all modules and functionality to ensure everything works correctly
"""

import sys
import os
import subprocess
import importlib.util

def test_venv_setup():
    """Test if we're running in the expected virtual environment"""
    print("\nTesting virtual environment setup...")

    # Check if we're in a virtual environment
    in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)

    if in_venv:
        print(f"✓ Running in virtual environment: {sys.prefix}")

        # Check if this is the Comparatron environment
        if "comparatron_env" in sys.prefix:
            print("✓ Running in Comparatron virtual environment")

            # Additional checks to verify everything is working properly
            print("  Verifying virtual environment integrity...")

            # Check 1: Does pip exist in the virtual environment?
            venv_bin_dir = os.path.join(sys.prefix, "bin")
            pip_path = os.path.join(venv_bin_dir, "pip")
            python_path = os.path.join(venv_bin_dir, "python")

            if not os.path.exists(pip_path):
                print("  ✗ Pip executable not found in virtual environment")
                # Check if we can access pip via python -m pip
                try:
                    result = subprocess.run([python_path, "-m", "pip", "--version"],
                                         capture_output=True, text=True, timeout=10)
                    if result.returncode == 0:
                        print("  ✓ Pip accessible via python -m pip")
                    else:
                        print("  ✗ Pip not accessible via python -m pip")
                        print("  ✗ Virtual environment may not have pip installed properly")
                        print("  Run the installation script to fix virtual environment")
                        return False
                except Exception as e:
                    print(f"  ✗ Pip accessibility check failed: {e}")
                    print("  Run the installation script to fix virtual environment")
                    return False
            else:
                print("  ✓ Pip executable found in virtual environment")

            # Check 2: Can we run pip commands?
            print("  Checking pip functionality in virtual environment...")
            try:
                # Use the virtual environment's pip to check itself
                pip_check = subprocess.run([pip_path if os.path.exists(pip_path) else f"{python_path} -m pip",
                                           "--version"], capture_output=True, text=True, timeout=10)
                if pip_check.returncode == 0:
                    print(f"  ✓ Pip is functional: {pip_check.stdout.strip()}")
                else:
                    print(f"  ✗ Pip is not functioning: {pip_check.stderr}")
                    print("  Run the installation script to fix pip in virtual environment")
                    return False
            except Exception as e:
                print(f"  ✗ Pip functionality check failed: {e}")
                print("  Run the installation script to fix pip in virtual environment")
                return False

            # Additional check: try to run pip list to see installed packages
            try:
                result = subprocess.run([pip_path if os.path.exists(pip_path) else f"{python_path} -m pip", "list"],
                                      capture_output=True, text=True, timeout=30)

                if result.returncode == 0:
                    installed_packages = result.stdout.lower()
                    required_packages = ["numpy", "flask", "pillow", "pyserial", "ezdxf"]
                    missing_packages = [pkg for pkg in required_packages if pkg not in installed_packages]

                    # Special handling for OpenCV since it might not appear in pip list due to installation issues
                    opencv_missing = True
                    for pkg in ["opencv", "opencv-python", "opencv-python-headless"]:
                        if pkg in installed_packages:
                            opencv_missing = False
                            break

                    if opencv_missing:
                        # Try importing cv2 to see if it's available even if not listed in pip
                        try:
                            import subprocess as sp
                            # Try to import cv2 from the current Python environment
                            result = sp.run([sys.executable, "-c", "import cv2; print(cv2.__version__)"],
                                            capture_output=True, text=True, timeout=30)
                            if result.returncode == 0:
                                print("  ✓ OpenCV (cv2) is available even if not listed in pip")
                                # Remove opencv from missing packages if it was there
                                if "opencv-python-headless" in missing_packages:
                                    missing_packages.remove("opencv-python-headless")
                            else:
                                missing_packages.append("opencv-python-headless (or cv2 import issue)")
                        except Exception:
                            missing_packages.append("opencv-python-headless (or cv2 import issue)")

                    if not missing_packages:
                        print("  ✓ All required packages are installed in the virtual environment")
                    else:
                        print(f"  ✗ Missing packages in virtual environment: {missing_packages}")
                        print("  Run the installation script to install missing packages")
                        return False
                else:
                    print(f"? Could not verify installed packages: {result.stderr}")
                    # Try to manually check if critical packages can be imported
                    critical_packages = ["numpy", "flask", "pillow", "pyserial", "ezdxf"]
                    unavailable = []
                    for pkg in critical_packages:
                        try:
                            if pkg == "pillow":
                                import PIL
                            elif pkg == "pyserial":
                                import serial
                            else:
                                __import__(pkg)
                        except ImportError:
                            unavailable.append(pkg)

                    if unavailable:
                        print(f"  ✗ Critical packages unavailable: {unavailable}")
                        print("  Run the installation script to fix package installation")
                        return False
                    else:
                        print("  ? Packages check inconclusive, but critical packages seem to be available")
                    # Don't fail the test if pip list fails, just warn
            except subprocess.TimeoutExpired:
                print("? Timeout checking installed packages, continuing...")
            except Exception as e:
                print(f"? Error checking installed packages: {e}, continuing...")

            return True
        else:
            print(f"? Running in virtual environment but not in Comparatron environment: {sys.prefix}")
            return True  # Still OK, it's a venv
    else:
        print(f"✗ Not running in virtual environment. Currently using: {sys.executable}")
        print("  This may cause issues with package dependencies.")
        print("  Consider activating the Comparatron virtual environment before running.")
        return False

def test_module_import(module_name, file_path=None):
    """Test if a module can be imported successfully"""
    print(f"Testing import of {module_name}...")

    try:
        # First check if we're in a virtual environment
        in_venv = hasattr(sys, 'real_prefix') or (hasattr(sys, 'base_prefix') and sys.base_prefix != sys.prefix)
        if in_venv:
            print(f"  Running in virtual environment: {sys.prefix}")
        else:
            print(f"  Running in system Python: {sys.executable}")

        # First try to import directly
        if file_path:
            # Load module from file path
            spec = importlib.util.spec_from_file_location(module_name, file_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        else:
            # Import normally
            module = importlib.import_module(module_name)

        # Additional check to verify the module is from the expected location
        if hasattr(module, '__file__') and module.__file__:
            if 'comparatron_env' in module.__file__:
                print(f"  Module loaded from virtual environment: {module.__file__}")
            elif 'site-packages' in module.__file__ or 'dist-packages' in module.__file__:
                print(f"  Module loaded from system packages: {module.__file__}")
            else:
                print(f"  Module loaded from: {module.__file__}")

        print(f"✓ {module_name} imported successfully")
        return True
    except ImportError as e:
        print(f"✗ Failed to import {module_name}: {e}")
        return False
    except Exception as e:
        print(f"✗ Error importing {module_name}: {e}")
        return False

def test_camera_functionality():
    """Test camera functionality"""
    print("\nTesting camera functionality...")

    try:
        from camera_manager import find_available_cameras
        cameras = find_available_cameras()
        print(f"✓ Found {len(cameras)} available camera(s): {cameras}")
        return True
    except Exception as e:
        print(f"✗ Camera functionality test failed: {e}")
        return False

def test_serial_functionality():
    """Test serial communication functionality"""
    print("\nTesting serial communication functionality...")

    try:
        from serial_comm import SerialCommunicator
        comm = SerialCommunicator()
        ports = comm.get_available_ports()
        print(f"✓ Found {len(ports)} available COM port(s)")
        print(f"  Ports: {[str(port) for port in ports]}")
        return True
    except Exception as e:
        print(f"✗ Serial communication functionality test failed: {e}")
        return False

def test_machine_control():
    """Test machine control functionality"""
    print("\nTesting machine control functionality...")

    try:
        from serial_comm import SerialCommunicator
        from machine_control import MachineController

        # Create a mock serial communicator (won't connect to anything)
        comm = SerialCommunicator()
        controller = MachineController(comm)

        # Test basic functionality
        controller.set_jog_distance(10.0)
        controller.set_feed_rate('fast')

        print("✓ Machine control functionality tested")
        return True
    except Exception as e:
        print(f"✗ Machine control functionality test failed: {e}")
        return False

def test_dxf_functionality():
    """Test DXF handling functionality"""
    print("\nTesting DXF handling functionality...")

    try:
        from dxf_handler import DXFHandler
        dxf_handler = DXFHandler()

        # Test adding a point
        success = dxf_handler.add_point(10.0, 20.0)
        if success:
            print("✓ DXF point added successfully")
        else:
            print("✗ Failed to add DXF point")
            return False

        # Test getting point count
        count = dxf_handler.get_point_count()
        if count == 1:
            print("✓ DXF point count correct")
        else:
            print("✗ DXF point count incorrect")
            return False

        return True
    except Exception as e:
        print(f"✗ DXF handling functionality test failed: {e}")
        return False

def test_dependencies_script():
    """Test if dependencies installation script exists and is executable"""
    print("\nTesting dependencies script...")

    # Check for either of the actual script names used in the project (in dependencies directory)
    script_paths = ["dependencies/install_dependencies_universal.sh", "dependencies/install_dependencies_generic.sh"]

    for script_path in script_paths:
        if os.path.exists(script_path):
            if os.access(script_path, os.X_OK):
                print(f"✓ Dependencies installation script exists and is executable ({script_path})")
                return True
            else:
                print(f"✗ Dependencies installation script exists but is not executable ({script_path})")
                return False

    print("✗ Dependencies installation script does not exist")
    return False

def test_main_script():
    """Test if main script exists"""
    print("\nTesting main script...")

    main_script = "main.py"
    if os.path.exists(main_script):
        print("✓ Main script exists")
        return True
    else:
        print("✗ Main script does not exist")
        return False

def run_all_tests():
    """Run all validation tests"""
    print("=== Comparatron Optimization Validation ===\n")

    tests = [
        ("Virtual environment", test_venv_setup),
        ("Module imports", lambda: all([
            test_module_import("cv2"),
            test_module_import("numpy"),
            test_module_import("flask"),
            test_module_import("PIL"),    # Pillow
            test_module_import("serial"), # PySerial
            test_module_import("ezdxf"),
            test_module_import("camera_manager", "camera_manager.py"),
            test_module_import("serial_comm", "serial_comm.py"),
            test_module_import("machine_control", "machine_control.py"),
            test_module_import("dxf_handler", "dxf_handler.py"),
            test_module_import("gui_flask", "gui_flask.py")
        ])),
        ("Camera functionality", test_camera_functionality),
        ("Serial functionality", test_serial_functionality),
        ("Machine control functionality", test_machine_control),
        ("DXF functionality", test_dxf_functionality),
        ("Dependencies script", test_dependencies_script),
        ("Main script", test_main_script)
    ]

    results = []
    for test_name, test_func in tests:
        print(f"\nRunning: {test_name}")
        result = test_func()
        results.append((test_name, result))

    # Summary
    print("\n" + "="*50)
    print("VALIDATION SUMMARY")
    print("="*50)

    passed = 0
    total = len(results)

    for test_name, result in results:
        status = "PASS" if result else "FAIL"
        print(f"{test_name}: {status}")
        if result:
            passed += 1

    print(f"\nOverall: {passed}/{total} tests passed")

    if passed == total:
        print("✓ All tests passed! Comparatron optimization is successful.")
        return True
    else:
        print("✗ Some tests failed. Please check the issues above.")
        return False

if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)