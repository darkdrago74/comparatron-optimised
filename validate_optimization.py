#!/usr/bin/env python3
"""
Validation Script for Comparatron Optimization
Tests all modules and functionality to ensure everything works correctly
"""

import sys
import os
import subprocess
import importlib.util

def test_module_import(module_name, file_path=None):
    """Test if a module can be imported successfully"""
    print(f"Testing import of {module_name}...")
    
    try:
        if file_path:
            # Load module from file path
            spec = importlib.util.spec_from_file_location(module_name, file_path)
            module = importlib.util.module_from_spec(spec)
            spec.loader.exec_module(module)
        else:
            # Import normally
            module = importlib.import_module(module_name)
        
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

def test_main_script_exists():
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
        ("Module imports", lambda: all([
            test_module_import("cv2"),
            test_module_import("numpy"),
            test_module_import("flask"),  # Added Flask as main GUI framework
            test_module_import("PIL"),    # Added Pillow for imaging
            test_module_import("serial"),
            test_module_import("ezdxf"),
            test_module_import("camera_manager", "camera_manager.py"),
            test_module_import("serial_comm", "serial_comm.py"),
            test_module_import("machine_control", "machine_control.py"),
            test_module_import("dxf_handler", "dxf_handler.py"),
            test_module_import("gui_flask", "gui_flask.py")  # Test Flask GUI module
        ])),
        ("Camera functionality", test_camera_functionality),
        ("Serial functionality", test_serial_functionality),
        ("Machine control functionality", test_machine_control),
        ("DXF functionality", test_dxf_functionality),
        ("Dependencies script", test_dependencies_script),
        ("Main script", test_main_script_exists)
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