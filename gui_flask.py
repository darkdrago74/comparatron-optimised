"""
Flask GUI Module for Comparatron
Provides a web interface that works locally and can be accessed from any device on the same network
"""

from flask import Flask, render_template, request, jsonify, Response
import cv2 as cv
import numpy as np
from PIL import Image
import threading
import time
import logging
import serial.tools.list_ports
from camera_manager import find_available_cameras, initialize_camera
from serial_comm import SerialCommunicator
from machine_control import MachineController
from dxf_handler import DXFHandler
import json


class ComparatronFlaskGUI:
    """
    Flask-based GUI class for the Comparatron application
    """
    
    def __init__(self):
        self.app = Flask(__name__)
        self.setup_routes()
        
        # Initialize components
        self.serial_comm = SerialCommunicator()
        self.controller = MachineController(self.serial_comm)
        self.dxf_handler = DXFHandler()
        
        # State variables
        self.camera = None
        self.camera_index = None
        self.prev_point_x = 0.0
        self.prev_point_y = 0.0
        self.difference_x = 0.0
        self.difference_y = 0.0
        self.difference_distance = 0.0
        self.data_acq_status = "ready"
        self.jog_distance = 10.0
        
        # Store recorded points for visualization
        self.recorded_points = []
        
        # Camera thread variables
        self.camera_thread = None
        self.current_frame = np.zeros((480, 640, 3), dtype=np.uint8)
        self.frame_lock = threading.Lock()
        self.running = False
        
        # Available ports
        self.ports = self.serial_comm.get_available_ports()
        self.port_names = [str(port) for port in self.ports]
    
    def setup_routes(self):
        """Setup Flask routes"""
        @self.app.route('/')
        def index():
            return render_template('index.html')
        
        @self.app.route('/video_feed')
        def video_feed():
            return Response(self.generate_frames(), mimetype='multipart/x-mixed-replace; boundary=frame')
        
        @self.app.route('/api/cameras')
        def get_cameras():
            cameras = find_available_cameras()
            return jsonify(cameras)

        @self.app.route('/api/refresh_cameras', methods=['POST'])
        def refresh_cameras():
            """Endpoint to refresh camera detection and find newly connected cameras."""
            try:
                from camera_manager import refresh_camera_detection
                cameras = refresh_camera_detection()
                logging.info(f"Camera refresh completed: {cameras}")
                return jsonify({
                    'success': True,
                    'cameras': cameras,
                    'message': f'Found {len(cameras)} camera(s) after refresh'
                })
            except Exception as e:
                logging.error(f"Error refreshing cameras: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e),
                    'message': 'Error refreshing camera list'
                }), 500
        
        @self.app.route('/api/initialize_camera', methods=['POST'])
        def initialize_camera_endpoint():
            camera_idx = int(request.json.get('camera_index', 0))
            self.camera = initialize_camera(camera_idx)
            if self.camera is not None:
                self.camera_index = camera_idx
                # Start camera thread if not already running
                if not self.running:
                    self.running = True
                    self.camera_thread = threading.Thread(target=self.update_frames)
                    self.camera_thread.daemon = True
                    self.camera_thread.start()
                return jsonify({'success': True, 'message': f'Camera {camera_idx} initialized'})
            else:
                return jsonify({'success': False, 'message': f'Failed to initialize camera {camera_idx}'}), 400
        
        @self.app.route('/api/ports')
        def get_ports():
            return jsonify(self.port_names)

        @self.app.route('/api/refresh_ports', methods=['POST'])
        def refresh_ports():
            """Endpoint to refresh serial port detection and find newly connected devices."""
            try:
                # Refresh the available ports by calling the serial_comm's method
                self.ports = self.serial_comm.get_available_ports()
                self.port_names = [str(port) for port in self.ports]
                logging.info(f"Port refresh completed: {self.port_names}")
                return jsonify({
                    'success': True,
                    'ports': self.port_names,
                    'message': f'Found {len(self.port_names)} port(s) after refresh'
                })
            except Exception as e:
                logging.error(f"Error refreshing ports: {e}")
                return jsonify({
                    'success': False,
                    'error': str(e),
                    'message': 'Error refreshing port list'
                }), 500
        
        @self.app.route('/api/connect_serial', methods=['POST'])
        def connect_serial():
            port_name = request.json.get('port_name', '').split(' ')[0]  # Get just the port name
            success = self.serial_comm.connect_to_com(port_name)
            if success:
                return jsonify({'success': True, 'message': f'Connected to {port_name}'})
            else:
                return jsonify({'success': False, 'message': f'Failed to connect to {port_name}'}), 400
        
        @self.app.route('/api/jog', methods=['POST'])
        def jog():
            axis = request.json.get('axis')
            direction = request.json.get('direction')
            distance = float(request.json.get('distance', 10.0))
            
            self.controller.set_jog_distance(distance)
            
            if axis == 'x':
                if direction == 'positive':
                    self.controller.jog_x_positive()
                else:
                    self.controller.jog_x_negative()
            elif axis == 'y':
                if direction == 'positive':
                    self.controller.jog_y_positive()
                else:
                    self.controller.jog_y_negative()
            elif axis == 'z':
                if direction == 'positive':
                    # Limit Z movement to 10mm for safety
                    dist = min(distance, 10.00)
                    self.controller.set_jog_distance(dist)
                    self.controller.jog_z_positive()
                else:
                    # Limit Z movement to 10mm for safety
                    dist = min(distance, 10.00)
                    self.controller.set_jog_distance(dist)
                    self.controller.jog_z_negative()
            
            return jsonify({'success': True})
        
        @self.app.route('/api/feed_rate', methods=['POST'])
        def set_feed_rate():
            rate_type = request.json.get('rate_type')
            self.controller.set_feed_rate(rate_type)
            return jsonify({'success': True})
        
        @self.app.route('/api/machine_control', methods=['POST'])
        def machine_control():
            command = request.json.get('command')

            if command == 'home':
                self.serial_comm.home_machine()
            elif command == 'unlock':
                self.serial_comm.unlock_machine()
            elif command == 'set_feed':
                self.serial_comm.set_feed(2000)
            elif command == 'set_origin':
                self.serial_comm.set_origin()
            elif command == 'set_relative':
                self.serial_comm.set_relative_mode()
            elif command == 'send_command':
                # Allow sending of arbitrary GRBL commands (for advanced users)
                raw_command = request.json.get('raw_command', '')
                if raw_command:
                    response = self.serial_comm.send_command(raw_command)
                    return jsonify({'success': True, 'response': response, 'command_sent': raw_command})
            elif command == 'reset_alarm':
                # Reset alarm state when machine is in alarm condition (like ALARM:2)
                status = self.serial_comm.reset_alarm_state()
                return jsonify({'success': True, 'status': status})

            return jsonify({'success': True})

        @self.app.route('/api/raw_command', methods=['POST'])
        def raw_command():
            """Route for sending raw commands to GRBL without safety checks (advanced users)"""
            raw_command = request.json.get('command', '').strip()
            if raw_command:
                # Determine if this is a command that expects multiple responses
                multi_line = raw_command.strip() in ['$$', '$#']
                response = self.serial_comm.send_command(raw_command + '\r', multi_line_response=multi_line)
                return jsonify({
                    'success': True,
                    'response': response,
                    'command_sent': raw_command
                })
            else:
                return jsonify({'success': False, 'error': 'No command provided'})

        @self.app.route('/api/settings_list', methods=['GET', 'POST'])
        def get_settings_list():
            """Route for getting all GRBL settings ($$ command) - works for both GET and POST"""
            try:
                # Handle both GET (for direct API access) and POST (for API access from UI)
                if request.method == 'POST':
                    params = request.json
                else:
                    params = {}

                response = self.serial_comm.get_settings_list()
                if response is not None:
                    return jsonify({
                        'success': True,
                        'response': response,
                        'command_sent': '$$'
                    })
                else:
                    return jsonify({'success': False, 'error': 'No response received for settings command'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})

        @self.app.route('/api/parameters_list', methods=['POST'])
        def get_parameters_list():
            """Route for getting all GRBL parameters ($# command)"""
            try:
                response = self.serial_comm.get_parameters_list()
                if response is not None:
                    return jsonify({
                        'success': True,
                        'response': response,
                        'command_sent': '$#'
                    })
                else:
                    return jsonify({'success': False, 'error': 'No response received for parameters command'})
            except Exception as e:
                return jsonify({'success': False, 'error': str(e)})

        @self.app.route('/api/get_machine_status', methods=['GET'])
        def get_machine_status_api():
            """Get current machine status from GRBL"""
            try:
                # Send '?' command to get machine status
                response = self.serial_comm.send_command('?')
                return jsonify({'status': 'success', 'response': response})
            except Exception as e:
                return jsonify({'status': 'error', 'message': str(e)})
        
        @self.app.route('/api/create_point', methods=['POST'])
        def create_point():
            pos = self.controller.get_current_position()
            if pos and 'x' in pos and 'y' in pos:
                point_x = pos['x']
                point_y = pos['y']
                
                # Calculate differences
                if self.prev_point_x != 0.0 or self.prev_point_y != 0.0:
                    self.difference_x = point_x - self.prev_point_x
                    self.difference_y = point_y - self.prev_point_y
                    self.difference_distance = ((self.difference_x ** 2) + (self.difference_y ** 2)) ** 0.5
                else:
                    self.difference_x = 0.0
                    self.difference_y = 0.0
                    self.difference_distance = 0.0
                
                # Update previous point
                self.prev_point_x = point_x
                self.prev_point_y = point_y
                
                # Add to recorded points list
                self.recorded_points.append({'x': point_x, 'y': point_y})
                
                # Add to DXF
                self.dxf_handler.add_point(point_x, point_y)
                
                return jsonify({
                    'success': True, 
                    'point': {'x': point_x, 'y': point_y},
                    'differences': {
                        'x': self.difference_x,
                        'y': self.difference_y,
                        'distance': self.difference_distance
                    }
                })
            else:
                return jsonify({'success': False, 'message': 'Could not get current position'}), 400
        
        @self.app.route('/api/recorded_points')
        def get_recorded_points():
            return jsonify(self.recorded_points)
        
        @self.app.route('/api/export_dxf', methods=['POST'])
        def export_dxf():
            filename = request.json.get('filename', 'comparatron.dxf')
            success = self.dxf_handler.export_dxf(filename)
            if success:
                return jsonify({'success': True, 'message': f'DXF exported to {filename}'})
            else:
                return jsonify({'success': False, 'message': 'Failed to export DXF'}), 400
        
        @self.app.route('/api/test_camera', methods=['POST'])
        def test_camera():
            camera_index = int(request.json.get('camera_index', -1))
            if camera_index < 0:
                return jsonify({'success': False, 'message': 'No camera index provided'}), 400
            
            # Test the specific camera
            from camera_manager import test_camera_connection
            success, message = test_camera_connection(camera_index)
            
            return jsonify({'success': success, 'message': message})
        
        @self.app.route('/api/status')
        def get_status():
            return jsonify({
                'difference_x': self.difference_x,
                'difference_y': self.difference_y,
                'difference_distance': self.difference_distance,
                'data_acq_status': self.data_acq_status
            })

        @self.app.route('/api/auto_start_status')
        def get_auto_start_status():
            """Check if auto-start is enabled on boot"""
            import subprocess
            try:
                result = subprocess.run(['systemctl', 'is-enabled', 'comparatron.service'],
                                      capture_output=True, text=True)
                is_enabled = result.returncode == 0
                return jsonify({'enabled': is_enabled})
            except:
                # If systemctl is not available or service doesn't exist, return False
                return jsonify({'enabled': False})

        @self.app.route('/api/toggle_auto_start', methods=['POST'])
        def toggle_auto_start():
            """Toggle auto-start on boot"""
            import subprocess
            import os

            data = request.json
            enable = data.get('enable', False)

            try:
                # Check if user has sudo access
                if os.getenv('SUDO_USER') is None:
                    # Try to run with sudo
                    if enable:
                        result = subprocess.run(['sudo', 'systemctl', 'enable', 'comparatron.service'],
                                              capture_output=True, text=True)
                        if result.returncode == 0:
                            subprocess.run(['sudo', 'systemctl', 'start', 'comparatron.service'],
                                         capture_output=True, text=True)
                    else:
                        subprocess.run(['sudo', 'systemctl', 'stop', 'comparatron.service'],
                                     capture_output=True, text=True)
                        result = subprocess.run(['sudo', 'systemctl', 'disable', 'comparatron.service'],
                                              capture_output=True, text=True)
                else:
                    # Already running as sudo/root
                    if enable:
                        result = subprocess.run(['systemctl', 'enable', 'comparatron.service'],
                                              capture_output=True, text=True)
                        if result.returncode == 0:
                            subprocess.run(['systemctl', 'start', 'comparatron.service'],
                                         capture_output=True, text=True)
                    else:
                        subprocess.run(['systemctl', 'stop', 'comparatron.service'],
                                     capture_output=True, text=True)
                        result = subprocess.run(['systemctl', 'disable', 'comparatron.service'],
                                              capture_output=True, text=True)

                if enable and result.returncode != 0 and 'enabled' not in getattr(result, 'stdout', ''):
                    return jsonify({'success': False, 'message': 'Failed to enable auto-start'}), 500
                elif not enable and result.returncode != 0 and 'disabled' not in getattr(result, 'stdout', ''):
                    return jsonify({'success': False, 'message': 'Failed to disable auto-start'}), 500

                return jsonify({'success': True, 'message': f'Auto-start {"enabled" if enable else "disabled"} successfully. Changes will take effect on next reboot.'})
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/restart_server', methods=['POST'])
        def restart_server():
            """Restart the Comparatron web server"""
            import subprocess
            import os
            import signal
            import sys
            import time

            try:
                # Schedule a delayed restart to allow the response to be sent
                def delayed_restart():
                    time.sleep(1)  # Wait 1 second to ensure response is sent
                    os.kill(os.getpid(), signal.SIGTERM)  # Terminate the current process

                import threading
                restart_thread = threading.Thread(target=delayed_restart)
                restart_thread.daemon = True
                restart_thread.start()

                return jsonify({'success': True, 'message': 'Server restart initiated'})
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/shutdown_server', methods=['POST'])
        def shutdown_server():
            """Shutdown the Comparatron web server"""
            import subprocess
            import os
            import signal
            import sys
            import time

            try:
                # Schedule a delayed shutdown to allow the response to be sent
                def delayed_shutdown():
                    time.sleep(30)  # Wait 30 seconds before shutting down
                    os.kill(os.getpid(), signal.SIGTERM)  # Terminate the current process

                import threading
                shutdown_thread = threading.Thread(target=delayed_shutdown)
                shutdown_thread.daemon = True
                shutdown_thread.start()

                return jsonify({'success': True, 'message': 'Server shutdown initiated. Server will shut down in 30 seconds.'})
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/restart_pi', methods=['POST'])
        def restart_pi():
            """Restart the Raspberry Pi (only works on Raspberry Pi systems)"""
            import subprocess
            import os
            import platform

            try:
                # Check if this is a Raspberry Pi by checking hardware
                is_raspberry_pi = False
                try:
                    with open('/proc/cpuinfo', 'r') as f:
                        cpuinfo = f.read()
                        if 'Raspberry Pi' in cpuinfo or 'BCM' in cpuinfo:
                            is_raspberry_pi = True
                except:
                    # Alternative check
                    try:
                        result = subprocess.run(['cat', '/sys/firmware/devicetree/base/model'],
                                              capture_output=True, text=True)
                        if 'Raspberry' in result.stdout:
                            is_raspberry_pi = True
                    except:
                        pass

                if not is_raspberry_pi:
                    return jsonify({'success': False, 'message': 'This system does not appear to be a Raspberry Pi'}), 400

                # Check if user has sudo access
                if os.getenv('SUDO_USER') is None:
                    # Try to run with sudo
                    result = subprocess.run(['sudo', 'reboot'],
                                          capture_output=True, text=True)
                else:
                    # Already running as sudo/root
                    result = subprocess.run(['reboot'],
                                          capture_output=True, text=True)

                if result.returncode == 0:
                    return jsonify({'success': True, 'message': 'Raspberry Pi restart initiated'})
                else:
                    return jsonify({'success': False, 'message': f'Failed to restart Pi: {result.stderr}'}), 500
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/laserweb_status', methods=['GET'])
        def laserweb_status():
            """Check the status of the LaserWeb service"""
            import subprocess

            try:
                # Check if LaserWeb service exists and its status
                result = subprocess.run(['systemctl', 'is-active', 'laserweb.service'],
                                      capture_output=True, text=True)

                status = result.stdout.strip()

                # Also check if the service file exists
                service_exists = subprocess.run(['test', '-f', '/etc/systemd/system/laserweb.service'],
                                              capture_output=True).returncode == 0

                return jsonify({
                    'success': True,
                    'status': status if status else 'unknown',
                    'service_exists': service_exists,
                    'message': f'LaserWeb service status: {status}'
                })
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/control_laserweb', methods=['POST'])
        def control_laserweb():
            """Start, stop, or restart the LaserWeb service"""
            import subprocess
            import os

            data = request.json
            action = data.get('action', 'status')  # start, stop, restart, status

            if action not in ['start', 'stop', 'restart', 'status']:
                return jsonify({'success': False, 'message': 'Invalid action. Use start, stop, restart, or status'}), 400

            try:
                # Check if user has sudo access
                if os.getenv('SUDO_USER') is None:
                    # Try to run with sudo
                    result = subprocess.run(['sudo', 'systemctl', action, 'laserweb.service'],
                                          capture_output=True, text=True)
                else:
                    # Already running as sudo/root
                    result = subprocess.run(['systemctl', action, 'laserweb.service'],
                                          capture_output=True, text=True)

                if result.returncode == 0:
                    return jsonify({
                        'success': True,
                        'message': f'LaserWeb service {action} command executed successfully'
                    })
                else:
                    return jsonify({
                        'success': False,
                        'message': f'Failed to {action} LaserWeb service: {result.stderr}'
                    }), 500
            except Exception as e:
                return jsonify({'success': False, 'message': str(e)}), 500

        @self.app.route('/api/param_info/<param_num>', methods=['GET'])
        def get_param_info(param_num):
            """Get detailed information about a specific GRBL parameter"""
            # Dictionary of GRBL parameter descriptions and options
            param_descriptions = {
                "0": {"description": "Step pulse time", "options": "Range: 3-20 microseconds. Sets time for step pulse in microseconds. Set to zero to enable step pulse invert."},
                "1": {"description": "Step idle delay", "options": "Range: 25-255 milliseconds. Time length for step pulse to be held after the step is complete. A value of 255 sets the delay to 255 milliseconds, though this isn't typically needed."},
                "2": {"description": "Step port invert mask", "options": "Bitmask: bit0=X, bit1=Y, bit2=Z. Inverts step signal for axes. Each bit controls the respective axis."},
                "3": {"description": "Direction port invert mask", "options": "Bitmask: bit0=X, bit1=Y, bit2=Z. Inverts direction signal for axes. Each bit controls the respective axis."},
                "4": {"description": "Step enable invert", "options": "0=normal, 1=inverted. Inverts the step enable pin signal."},
                "5": {"description": "Limit pins invert", "options": "0=normal, 1=inverted. Inverts the limit pins signal, active low or active high."},
                "6": {"description": "Probe pin invert", "options": "0=normal, 1=inverted. Inverts the probe pin signal, active low or active high."},
                "10": {"description": "Status report mask", "options": "Bitmask: bit0=position, bit1=buffer, bit2=limit pins. Controls what is reported in status reports. Set bit 0 for machine position, bit 1 for real-time feed rate, bit 2 for pin states."},
                "11": {"description": "Junction deviation", "options": "Range: 0.01-5.0mm. Controls the path planning and cornering speed. Lower values result in more exact path following but can cause stops to maintain acceleration limits."},
                "12": {"description": "Arc tolerance", "options": "Range: 0.001-0.5mm. Controls accuracy of arc motion. Lower values result in more exact path following but much longer compile times."},
                "13": {"description": "Report inches", "options": "0=mm, 1=inches. Units for all reports. 0=mm, 1=inches. This only affects the reports, not the motion commands."},
                "20": {"description": "Soft limits enable", "options": "0=disable, 1=enable. Enable soft limits. Requires homing to be enabled as well. Provides software-based travel limits."},
                "21": {"description": "Hard limits enable", "options": "0=disable, 1=enable. Enable hard limits. Provides hardware-based travel limits using limit switches."},
                "22": {"description": "Homing cycle enable", "options": "0=disable, 1=enable. Enable homing cycle. Requires limit switches to be configured properly."},
                "23": {"description": "Homing direction invert mask", "options": "Bitmask: bit0=X, bit1=Y, bit2=Z. Sets homing search direction. Each bit controls the respective axis."},
                "24": {"description": "Homing locate feed rate", "options": "Range: 1-1000mm/min. Feed rate used during homing locate cycle. Rate at which the limit switches are approached during homing."},
                "25": {"description": "Homing search seek rate", "options": "Range: 1-5000mm/min. Seek rate used during homing search cycle. Rate at which the limit switches are searched during homing."},
                "26": {"description": "Homing switch debounce delay", "options": "Range: 1-100ms. Delay for homing switch to debounce. Time to wait after switch is triggered before continuing."},
                "27": {"description": "Homing switch pull-off distance", "options": "Range: 0.1-20mm. Distance to move off homing switch after triggering. Ensures switch is released after homing."},
                "30": {"description": "Maximum spindle speed", "options": "Range: 0-20000 RPM. Maximum spindle speed in RPM. Used for S-value in M3/M4 commands."},
                "31": {"description": "Minimum spindle speed", "options": "Range: 0-20000 RPM. Minimum spindle speed in RPM. Used for S-value in M3/M4 commands."},
                "32": {"description": "Laser mode enable", "options": "0=disable, 1=enable. Enable laser mode. Enables dynamic laser power control based on feed rate."},
                "100": {"description": "X-axis travel resolution", "options": "Range: 1.0-999.999 steps/mm. Steps per millimeter for X axis. Critical for proper movement. Calculate: (steps per revolution) / (mm per revolution)."},
                "101": {"description": "Y-axis travel resolution", "options": "Range: 1.0-999.999 steps/mm. Steps per millimeter for Y axis. Critical for proper movement. Calculate: (steps per revolution) / (mm per revolution)."},
                "102": {"description": "Z-axis travel resolution", "options": "Range: 1.0-999.999 steps/mm. Steps per millimeter for Z axis. Critical for proper movement. Calculate: (steps per revolution) / (mm per revolution)."},
                "110": {"description": "X-axis maximum rate", "options": "Range: 1.0-60000.0 mm/min. Maximum rate for X axis. Determines the maximum feed rate for this axis."},
                "111": {"description": "Y-axis maximum rate", "options": "Range: 1.0-60000.0 mm/min. Maximum rate for Y axis. Determines the maximum feed rate for this axis."},
                "112": {"description": "Z-axis maximum rate", "options": "Range: 1.0-60000.0 mm/min. Maximum rate for Z axis. Determines the maximum feed rate for this axis."},
                "120": {"description": "X-axis acceleration", "options": "Range: 1.0-10000.0 mm/sec^2. Acceleration for X axis. Affects how quickly the axis accelerates and decelerates."},
                "121": {"description": "Y-axis acceleration", "options": "Range: 1.0-10000.0 mm/sec^2. Acceleration for Y axis. Affects how quickly the axis accelerates and decelerates."},
                "122": {"description": "Z-axis acceleration", "options": "Range: 1.0-10000.0 mm/sec^2. Acceleration for Z axis. Affects how quickly the axis accelerates and decelerates."},
                "130": {"description": "X-axis maximum travel", "options": "Range: 1.0-2000.0 mm. Maximum travel for X axis. Used for soft limits and coordinate system calculations."},
                "131": {"description": "Y-axis maximum travel", "options": "Range: 1.0-2000.0 mm. Maximum travel for Y axis. Used for soft limits and coordinate system calculations."},
                "132": {"description": "Z-axis maximum travel", "options": "Range: 1.0-2000.0 mm. Maximum travel for Z axis. Used for soft limits and coordinate system calculations."},
            }

            if param_num in param_descriptions:
                return jsonify(param_descriptions[param_num])
            else:
                return jsonify({
                    "description": f"Parameter ${param_num} - Description not available in database",
                    "options": "Check GRBL documentation for more details"
                })

        @self.app.route('/calibration')
        def calibration():
            """Route for the calibration/settings page"""
            return render_template('calibration.html')

    def update_frames(self):
        """Continuously update frames from camera"""
        while self.running:
            if self.camera is not None and self.camera.isOpened():
                ret, frame = self.camera.read()
                if ret:
                    with self.frame_lock:
                        # Resize frame to desired resolution for performance
                        if frame.shape[0] != 480 or frame.shape[1] != 640:
                            frame = cv.resize(frame, (640, 480))
                        self.current_frame = frame
            else:
                # Use a dummy frame if no camera is available
                with self.frame_lock:
                    self.current_frame = np.zeros((480, 640, 3), dtype=np.uint8)
            time.sleep(1/15)  # 15 FPS
    
    def generate_frames(self):
        """Generate frames for the video feed"""
        while True:
            with self.frame_lock:
                frame = self.current_frame.copy()
            
            # Draw crosshair for target
            h, w = frame.shape[:2]
            center_x, center_y = w // 2, h // 2
            
            # Draw crosshair
            cv.line(frame, (center_x - 20, center_y), (center_x + 20, center_y), (0, 0, 255), 1)
            cv.line(frame, (center_x, center_y - 20), (center_x, center_y + 20), (0, 0, 255), 1)
            
            # Encode frame as JPEG
            ret, buffer = cv.imencode('.jpg', frame)
            if ret:
                frame_bytes = buffer.tobytes()
                yield (b'--frame\r\n'
                       b'Content-Type: image/jpeg\r\n\r\n' + frame_bytes + b'\r\n')
            time.sleep(0.03)  # ~30 FPS cap to prevent overwhelming the client
    
    def run(self, host='0.0.0.0', port=5000, debug=False):
        """Run the Flask application"""
        # Run the Flask app
        self.app.run(host=host, port=port, debug=debug, threaded=True)


def main():
    """Main function to run the Flask GUI"""
    gui = ComparatronFlaskGUI()
    print("Starting Comparatron Flask GUI...")
    print("Access the interface at: http://localhost:5001 or http://[RPI_IP]:5001")
    gui.run(host='0.0.0.0', port=5001, debug=False)


if __name__ == "__main__":
    main()