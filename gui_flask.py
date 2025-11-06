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
            
            return jsonify({'success': True})
        
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
        
        @self.app.route('/api/status')
        def get_status():
            return jsonify({
                'difference_x': self.difference_x,
                'difference_y': self.difference_y,
                'difference_distance': self.difference_distance,
                'data_acq_status': self.data_acq_status
            })
    
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
    print("Access the interface at: http://localhost:5001 or http://127.0.0.1:5001")
    gui.run(host='127.0.0.1', port=5001, debug=False)


if __name__ == "__main__":
    main()