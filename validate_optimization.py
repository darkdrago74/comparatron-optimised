#!/usr/bin/env python3
"""
Validation Script for Comparatron Optimization
Tests all modules and functionality to ensure everything works correctly
"""

import sys
import os
import platform
import subprocess
import importlib.util
import time

def detect_system():
    """Detect the system type (Linux vs Raspberry Pi)"""
    print("Detecting system type...")

    # Check if this is a Raspberry Pi by looking for Pi-specific identifiers
    try:
        with open('/proc/cpuinfo', 'r') as f:
            cpuinfo = f.read().lower()

        if 'raspberry' in cpuinfo or 'bcm' in cpuinfo or 'armv7l' in platform.machine() or 'aarch64' in platform.machine():
            print("✓ System detected: Raspberry Pi")
            return "raspberry_pi"
    except:
        pass

    # Check for Raspberry Pi by checking for specific hardware
    if os.path.exists('/opt/vc/bin/vcgencmd') or os.path.exists('/boot/firmware/config.txt'):
        print("✓ System detected: Raspberry Pi")
        return "raspberry_pi"

    print("✓ System detected: Linux (non-Raspberry Pi)")
    return "linux"

def test_system_installation():
    """Test if packages are properly installed in system Python"""
    print("\nTesting system installation...")

    system_type = detect_system()
    print(f"Running on {system_type}: {sys.executable}")

    # Check installation by trying to import required packages
    required_packages = [
        ("numpy", "numpy"),
        ("flask", "flask"),
        ("PIL", "PIL"),
        ("serial", "serial"),
        ("ezdxf", "ezdxf"),
        ("cv2", "cv2")
    ]

    missing_packages = []
    for display_name, import_name in required_packages:
        try:
            if import_name == "serial":
                import serial
            elif import_name == "PIL":
                from PIL import Image
            elif import_name == "cv2":
                import cv2
            else:
                __import__(import_name)
            print(f"  ✓ {display_name} available")
        except ImportError as e:
            print(f"  ✗ {display_name} not available: {e}")
            missing_packages.append(display_name)

    if missing_packages:
        print(f"✗ Missing packages: {missing_packages}")
        return False
    else:
        print("✓ All required packages are available")
        return True


def test_module_import(module_name, file_path=None):
    """Test if a module can be imported successfully"""
    print(f"Testing import of {module_name}...")

    try:
        # Check installation method
        system_type = detect_system()
        print(f"  Running on {system_type}: {sys.executable}")

        # First try to import directly
        if file_path:
            # Load module from file path
            spec = importlib.util.spec_from_file_location(module_name, file_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        else:
            # Import normally
            module = importlib.import_module(module_name)

        # Check if module is from system packages
        if hasattr(module, '__file__') and module.__file__:
            if 'site-packages' in module.__file__ or 'dist-packages' in module.__file__ or 'comparatron' not in module.__file__:
                print(f"  ✓ Module loaded from system packages: {module.__file__}")
            else:
                print(f"  ✓ Module loaded from: {module.__file__}")

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
            print(f"✗ DXF point count incorrect: expected 1, got {count}")
            return False

        return True
    except Exception as e:
        print(f"✗ DXF handling functionality test failed: {e}")
        return False


def test_dependencies_script():
    """Test if dependencies installation script exists and is executable"""
    print("\nTesting dependencies script...")

    # Check for the unified installation script
    script_path = "dependencies/install_dependencies.sh"

    if os.path.exists(script_path):
        if os.access(script_path, os.X_OK):
            print(f"✓ Dependencies installation script exists and is executable ({script_path})")
            return True
        else:
            print(f"? Dependencies installation script exists but is not executable ({script_path})")
            # Try to make it executable
            try:
                os.chmod(script_path, 0o755)
                print(f"  Made script executable: {script_path}")
                return True
            except Exception:
                print(f"  Could not make script executable: {script_path}")
                return False

    print("✗ Dependencies installation script does not exist")
    print("  Expected file: dependencies/install_dependencies.sh")
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
        ("System installation", test_system_installation),
        ("Module imports", lambda: all([
            test_module_import("cv2"),
            test_module_import("numpy"),
            test_module_import("flask"),
            test_module_import("PIL"),
            test_module_import("serial"),
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
        print(f"Running: {test_name}")
        result = test_func()
        results.append((test_name, result))
        print()

    # Summary
    print("="*50)
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
        print("? Comparatron may still work, but validation showed issues with some components.")
        return False


if __name__ == "__main__":
    success = run_all_tests()
    sys.exit(0 if success else 1)