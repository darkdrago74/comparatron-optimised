"""
Comparatron V1.1 - Refactored
by Cameron Coward 
fork by RGP
http://www.cameroncoward.com

This is a DIY digital optical comparator that uses a USB microscope mounted to a 
CNC pen plotter to take precise measurements of physical objects through visual means.

Refactored by Qwen3 to improve modularity and maintainability.
"""

import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')

from camera_manager import select_camera_interactive, initialize_camera
from serial_comm import SerialCommunicator
from machine_control import MachineController
from dxf_handler import DXFHandler
from gui_handler import ComparatronGUI
import cv2 as cv
import numpy as np
import sys
from math import sqrt


def main():
    # Camera selection
    print("Starting Comparatron...")
    selected_camera = select_camera_interactive()
    
    if selected_camera is None:
        print("No camera selected. You may need to:")
        print("  1. Check if cameras are connected")
        print("  2. Add your user to the video group: sudo usermod -a -G video $USER")
        print("  3. Log out and log back in")
        print("  4. Or run with appropriate permissions")
        print("Continuing without camera access...")
        vid = None
    else:
        # Initialize camera
        vid = initialize_camera(selected_camera)
        if vid is None:
            print("Failed to initialize camera. You may need to:")
            print("  1. Add your user to the video group: sudo usermod -a -G video $USER")
            print("  2. Log out and log back in")
            print("  3. Or run with appropriate permissions")
            print("Continuing without camera access...")
            vid = None
    
    # Get video parameters if camera is available
    if vid is not None:
        ret, frame = vid.read()
        if not ret:
            print("Failed to read from camera. Using last frame or dummy frame...")
            ret, frame = vid.read()  # Try again
            if not ret:
                frame = np.zeros((480, 640, 3), dtype=np.uint8)  # Black frame
                frame_width = 640
                frame_height = 480
                video_fps = 30  # Default FPS
            else:
                frame_width = int(vid.get(cv.CAP_PROP_FRAME_WIDTH))
                frame_height = int(vid.get(cv.CAP_PROP_FRAME_HEIGHT))
                video_fps = int(vid.get(cv.CAP_PROP_FPS))
        else:
            frame_width = int(vid.get(cv.CAP_PROP_FRAME_WIDTH))
            frame_height = int(vid.get(cv.CAP_PROP_FRAME_HEIGHT))
            video_fps = int(vid.get(cv.CAP_PROP_FPS))
        
        print(f"Camera initialized: {frame_width}x{frame_height} @ {video_fps}fps")
    else:
        # Use dummy values when no camera is available
        frame = np.zeros((480, 640, 3), dtype=np.uint8)  # Black frame
        frame_width = 640
        frame_height = 480
        video_fps = 30  # Default FPS
        print(f"Using dummy frame: {frame_width}x{frame_height}")
    
    # Initialize other components
    serial_comm = SerialCommunicator()
    controller = MachineController(serial_comm)
    dxf_handler = DXFHandler()
    
    # Get available ports for GUI
    ports = serial_comm.get_available_ports()
    port_names = [str(port) for port in ports]
    
    # Initialize GUI
    gui = ComparatronGUI(int(frame_width), int(frame_height))
    gui.setup_gui_elements(frame, port_names)
    gui.show_and_run()
    
    # Main application loop
    prev_point_x = float(0)  # Previous recorded point X
    prev_point_y = float(0)  # Previous recorded point Y
    difference_x = float(0)  # Difference in X
    difference_y = float(0)  # Difference in Y
    difference_distance = float(0)  # Distance between points
    old_jog_count = 0  # Count of jog operations
    old_control_ser = "initialize string"  # Previous serial control string
    data_acq_status = "ready"  # Data acquisition status
    
    # Set up a blank frame if no camera is available
    if vid is None:
        # Create a dummy frame for GUI purposes
        frame = np.zeros((480, 640, 3), dtype=np.uint8)  # Black frame
        frame_width, frame_height = 640, 480
        print("Using dummy frame for camera display")
    else:
        # Get video parameters
        ret, frame = vid.read()
        if not ret:
            print("Failed to read from camera. Using last frame or dummy frame...")
            ret, frame = vid.read()  # Try again
            if not ret:
                frame = np.zeros((480, 640, 3), dtype=np.uint8)  # Black frame
                frame_width = 640
                frame_height = 480
            else:
                frame_width = int(vid.get(cv.CAP_PROP_FRAME_WIDTH))
                frame_height = int(vid.get(cv.CAP_PROP_FRAME_HEIGHT))
        else:
            frame_width = int(vid.get(cv.CAP_PROP_FRAME_WIDTH))
            frame_height = int(vid.get(cv.CAP_PROP_FRAME_HEIGHT))
        
        print(f"Camera initialized: {frame_width}x{frame_height}")
    
    def connect_to_com():
        nonlocal serial_comm
        port_selection = dpg.get_value("port_selection")
        com_port = port_selection.split(' ')[0]  # Get just the port name
        success = serial_comm.connect_to_com(com_port)
        if success:
            print(f"Connected to {com_port}")
        else:
            print(f"Failed to connect to {com_port}")
    
    def home_machine():
        serial_comm.home_machine()
    
    def unlock_machine():
        serial_comm.unlock_machine()
    
    def set_feed():
        serial_comm.set_feed(2000)
    
    def set_origin():
        serial_comm.set_origin()
    
    def set_rel():
        serial_comm.set_relative_mode()
    
    def jog_x_pos():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        controller.jog_x_positive()
        nonlocal old_jog_count
        old_jog_count += 1
    
    def jog_x_neg():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        controller.jog_x_negative()
        nonlocal old_jog_count
        old_jog_count += 1
    
    def jog_y_pos():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        controller.jog_y_positive()
        nonlocal old_jog_count
        old_jog_count += 1
    
    def jog_y_neg():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        controller.jog_y_negative()
        nonlocal old_jog_count
        old_jog_count += 1
    
    def jog_z_pos():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        # Limit Z movement to 10mm for safety
        if float(distance) > 10.00:
            distance = 10.00
        controller.set_jog_distance(distance)
        controller.jog_z_positive()
    
    def jog_z_neg():
        nonlocal controller
        distance = dpg.get_value("jog_distance")
        controller.set_jog_distance(distance)
        # Limit Z movement to 10mm for safety
        if float(distance) > 10.00:
            distance = 10.00
        controller.set_jog_distance(distance)
        controller.jog_z_negative()
    
    def fast_feed():
        controller.set_feed_rate('fast')
    
    def slow_feed():
        controller.set_feed_rate('slow')
    
    def create_new_point():
        nonlocal controller, dxf_handler, prev_point_x, prev_point_y
        nonlocal difference_x, difference_y, difference_distance, old_jog_count
        nonlocal old_control_ser, data_acq_status
        
        current_jog_count = old_jog_count  # This would come from controller in the real implementation
        
        # In the refactored version, we'll simplify this
        pos = controller.get_current_position()
        if pos and 'x' in pos and 'y' in pos:
            point_x = pos['x']
            point_y = pos['y']
            
            # Calculate differences
            if prev_point_x != 0.0 and prev_point_y != 0.0:
                difference_x = point_x - prev_point_x
                difference_y = point_y - prev_point_y
                difference_distance = sqrt((difference_x * difference_x) + (difference_y * difference_y))
            else:
                difference_x = 0.0
                difference_y = 0.0
                difference_distance = 0.0
            
            # Update previous point
            prev_point_x = point_x
            prev_point_y = point_y
            
            # Add to DXF
            dxf_handler.add_point(point_x, point_y)
            
            # Add to GUI plot
            gui.add_point_to_plot(point_x, point_y)
            
            # Update GUI with differences
            gui.update_difference_values(difference_x, difference_y, difference_distance)
            
            print(f"New point recorded: ({point_x}, {point_y})")
        else:
            print("Could not get current position")
    
    def export_dxf_now():
        filename = dpg.get_value("dxf_name")
        success = dxf_handler.export_dxf(filename)
        if success:
            print(f"DXF exported to: {filename}")
    
    def close_ser_now():
        # Release video
        vid.release()
        print("Released video")
        
        # Close serial connection
        serial_comm.disconnect()
        print("Closed serial connection")
        
        # Clean up GUI
        gui.cleanup()
        print("Destroyed DearPyGUI context")
        
        sys.exit()
    
    # Connect callbacks to the GUI
    gui.connect_callback = connect_to_com
    gui.home_callback = home_machine
    gui.unlock_callback = unlock_machine
    gui.set_feed_callback = set_feed
    gui.set_origin_callback = set_origin
    gui.set_rel_callback = set_rel
    gui.jog_x_pos_callback = jog_x_pos
    gui.jog_x_neg_callback = jog_x_neg
    gui.jog_y_pos_callback = jog_y_pos
    gui.jog_y_neg_callback = jog_y_neg
    gui.jog_z_pos_callback = jog_z_pos
    gui.jog_z_neg_callback = jog_z_neg
    gui.fast_feed_callback = fast_feed
    gui.slow_feed_callback = slow_feed
    gui.create_new_point_callback = create_new_point
    gui.export_dxf_callback = export_dxf_now
    gui.close_callback = close_ser_now
    
    # Main GUI loop
    while gui.is_running():
        # Update status in GUI
        gui.update_status(data_acq_status)
        
        # Update video feed if camera is available and open
        if vid is not None and vid.isOpened():
            ret, frame = vid.read()
            if ret:
                gui.update_frame_texture(frame)
        # If no camera, we could periodically update with a static frame or skip
        # For now, the GUI will continue running without updating camera feed
        
        gui.render_frame()
    
    # Cleanup
    if vid is not None and vid.isOpened():
        vid.release()
    gui.cleanup()
    serial_comm.disconnect()


if __name__ == "__main__":
    main()