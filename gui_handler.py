"""
GUI Module for Comparatron
Handles the DearPyGUI interface
"""

import dearpygui.dearpygui as dpg
import cv2 as cv
import numpy as np
from math import sqrt
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


class ComparatronGUI:
    """
    Class to handle the DearPyGUI interface for Comparatron
    """
    
    def __init__(self, frame_width=800, frame_height=600):
        self.frame_width = frame_width
        self.frame_height = frame_height
        self.target_x = int(frame_width / 2)
        self.target_y = int(frame_height / 2)
        
        # Initialize DearPyGUI
        dpg.create_context()
        dpg.create_viewport(title='Comparatron by Cameron Coward', width=1280, height=720)
        dpg.setup_dearpygui()
        
        # Variables for tracking differences
        self.prev_point_x = float(0)
        self.prev_point_y = float(0)
        self.difference_x = float(0)
        self.difference_y = float(0)
        self.difference_distance = float(0)
        self.data_acq_status = "ready"
        
        # Create value registry for GUI elements
        with dpg.value_registry():
            dpg.add_float_value(tag="jog_distance", default_value=10.0)
            dpg.add_string_value(tag="port_selection", default_value="")
            dpg.add_string_value(tag="dxf_filename", default_value="comparatron.dxf")
            dpg.add_string_value(tag="difference_x", default_value="0.00")
            dpg.add_string_value(tag="difference_y", default_value="0.00")
            dpg.add_string_value(tag="difference_distance", default_value="0.00")
            dpg.add_string_value(tag="data_acq_status", default_value="ready")
    
    def setup_texture_registry(self, frame):
        """Setup texture registry for video feed"""
        # Get the video parameters and create texture data
        data = np.flip(frame, 2)  # flip video BGR colorspace to RGB
        data = data.ravel()  # flatten camera data to 1D
        data = np.asfarray(data, dtype='f')  # change data type to 32bit floats
        texture_data = np.true_divide(data, 255.0)  # normalize image data
        
        with dpg.texture_registry(show=False):
            dpg.add_raw_texture(frame.shape[1], frame.shape[0], texture_data, 
                              tag="texture_tag", format=dpg.mvFormat_Float_rgb)
    
    def setup_microscope_window(self):
        """Setup microscope view window"""
        with dpg.window(label="Microscope View", pos=(20,20), no_close=True):
            dpg.add_image("texture_tag")
    
    def setup_jog_distance_window(self):
        """Setup jog distance settings window"""
        with dpg.window(label="Jog Distance", pos=(20, self.frame_height + 80), 
                        width=200, height=200, no_close=True):
            dpg.add_text("Millimeters:")
            
            def jog_distance_callback(sender, app_data):
                dpg.set_value("jog_distance", app_data)
            
            dpg.add_radio_button(
                items=['50.00', '10.00', '1.00', '0.10', '0.01'], 
                default_value='10.00', 
                callback=jog_distance_callback,
                tag="jog_distance_radio"
            )
            
            with dpg.group(horizontal=True):
                dpg.add_button(tag="fast_feed", label="Fast F1000", 
                              callback=self.fast_feed_callback)
                dpg.add_button(tag="slow_feed", label="Slow F200", 
                              callback=self.slow_feed_callback)
    
    def setup_jog_control_window(self):
        """Setup jog control window"""
        with dpg.window(label="Jog Control", pos=(240, self.frame_height + 80), 
                        width=200, height=200, no_close=True):
            dpg.add_button(tag="x_pos", label="X+", pos=(140,90), width=40, height=40, 
                          callback=self.jog_x_pos_callback)
            dpg.add_button(tag="x_neg", label="X-", pos=(20,90), width=40, height=40, 
                          callback=self.jog_x_neg_callback)
            dpg.add_button(tag="y_pos", label="Y+", pos=(80,30), width=40, height=40, 
                          callback=self.jog_y_pos_callback)
            dpg.add_button(tag="y_neg", label="Y-", pos=(80,150), width=40, height=40, 
                          callback=self.jog_y_neg_callback)
            dpg.add_button(tag="z_pos", label="Z+", pos=(90,90), 
                          callback=self.jog_z_pos_callback)
            dpg.add_button(tag="z_neg", label="Z-", pos=(90,110), 
                          callback=self.jog_z_neg_callback)
    
    def setup_startup_window(self, ports_list):
        """Setup startup sequence window"""
        with dpg.window(label="Startup Sequence", pos=(20, self.frame_height + 300), 
                        width=420, height=200, no_close=True):
            dpg.add_combo(tag="port_selection", items=ports_list)
            dpg.add_button(tag="connect_com", label="Connect to above COM port", 
                          callback=self.connect_callback)
            dpg.add_button(tag="mach_home", label="Home ($H)", callback=self.home_callback)
            dpg.add_button(tag="mach_unlock", label="Unlock motors ($X)", 
                          callback=self.unlock_callback)
            dpg.add_button(tag="mach_feed", label="Set feedrate (F2000mm/s)", 
                          callback=self.set_feed_callback)
            dpg.add_button(tag="mach_origin", label="Set origin point (G92X0Y0)", 
                          callback=self.set_origin_callback)
            dpg.add_button(tag="mach_rel", label="Set to relative coordinates (G91)", 
                          callback=self.set_rel_callback)
    
    def setup_draw_window(self):
        """Setup draw controls window"""
        with dpg.window(label="Draw", pos=(460, self.frame_height + 80), 
                        width=215, height=200, no_close=True):
            dpg.add_text("Add new point at actual pos:")
            dpg.add_button(tag="new_point", label="New Point", width=80, height=40, 
                          callback=self.create_new_point_callback)
            
            # Display differences between points
            with dpg.group(horizontal=True):
                dpg.add_text("Difference X:")
                dpg.add_text(tag="difference_x")
            
            with dpg.group(horizontal=True):
                dpg.add_text("Difference Y:")
                dpg.add_text(tag="difference_y")
            
            with dpg.group(horizontal=True):
                dpg.add_text("Difference Distance:")
                dpg.add_text(tag="difference_distance")
                
            with dpg.group(horizontal=True):
                dpg.add_text("Pos measurement:")
                dpg.add_text(tag="data_acq_status")
    
    def setup_dxf_window(self):
        """Setup DXF export window"""
        with dpg.window(label="DXF Output", pos=(460, self.frame_height + 300), 
                        width=215, height=200, no_close=True):
            dpg.add_text("Enter a filename")
            dpg.add_text("for the DXF output:")
            dpg.add_input_text(tag="dxf_name", default_value="comparatron.dxf")
            dpg.add_button(tag="export_dxf", label="Export DXF", 
                          callback=self.export_dxf_callback)
            dpg.add_separator()
            dpg.add_text("Close serial and")
            dpg.add_text("release video:")
            dpg.add_button(tag="close_ser", label="Clean exit", 
                          callback=self.close_callback)
    
    def setup_plot_window(self):
        """Setup the plot visualization window"""
        with dpg.window(label="Created Plot", pos=(self.frame_width + 55, 20), 
                        width=700, height=960, no_close=True):
            with dpg.drawlist(tag="plot", width=660, height=920):
                # Hidden circle, necessary because drawlist requires a child object to initialize
                dpg.draw_circle(center=(100, 200), radius=2, color=(255, 0, 0, 255), 
                               thickness=2, show=False)
    
    def setup_gui_elements(self, frame, ports_list):
        """Setup all GUI elements"""
        self.setup_texture_registry(frame)
        self.setup_microscope_window()
        self.setup_jog_distance_window()
        self.setup_jog_control_window()
        self.setup_startup_window(ports_list)
        self.setup_draw_window()
        self.setup_dxf_window()
        self.setup_plot_window()
    
    def update_frame_texture(self, frame):
        """Update the frame texture with new video data"""
        if dpg.does_item_exist("texture_tag"):
            # Process the frame for display
            cv.drawMarker(frame, (self.target_x, self.target_y), (0, 0, 255), 
                         cv.MARKER_CROSS, 10, 1)
            data = np.flip(frame, 2)
            data = data.ravel()
            data = np.asfarray(data, dtype='f')
            texture_data = np.true_divide(data, 255.0)
            dpg.set_value("texture_tag", texture_data)
    
    def update_difference_values(self, diff_x, diff_y, diff_distance):
        """Update the difference values displayed in the GUI"""
        dpg.set_value("difference_x", f"{diff_x:.2f}")
        dpg.set_value("difference_y", f"{diff_y:.2f}")
        dpg.set_value("difference_distance", f"{diff_distance:.2f}")
    
    def update_status(self, status):
        """Update the acquisition status in the GUI"""
        self.data_acq_status = status
        dpg.set_value("data_acq_status", status)
    
    def add_point_to_plot(self, x, y):
        """Add a point to the visualization plot"""
        # Scale coordinates for the plot (inverted Y axis, scaled)
        draw_x = 5 + int(-2 * x)
        draw_y = 5 + int(-2 * y)
        if dpg.does_item_exist("plot"):
            dpg.draw_circle(center=(draw_x, draw_y), radius=1, color=(255, 0, 0, 255), 
                           thickness=1, parent="plot")
    
    # Callback methods (these will be connected to external functions)
    def connect_callback(self, sender, app_data):
        """Callback for connect button"""
        pass  # Will be connected to external function
    
    def home_callback(self, sender, app_data):
        """Callback for home button"""
        pass  # Will be connected to external function
    
    def unlock_callback(self, sender, app_data):
        """Callback for unlock button"""
        pass  # Will be connected to external function
    
    def set_feed_callback(self, sender, app_data):
        """Callback for set feed button"""
        pass  # Will be connected to external function
    
    def set_origin_callback(self, sender, app_data):
        """Callback for set origin button"""
        pass  # Will be connected to external function
    
    def set_rel_callback(self, sender, app_data):
        """Callback for set relative button"""
        pass  # Will be connected to external function
    
    def jog_x_pos_callback(self, sender, app_data):
        """Callback for X+ jog button"""
        pass  # Will be connected to external function
    
    def jog_x_neg_callback(self, sender, app_data):
        """Callback for X- jog button"""
        pass  # Will be connected to external function
    
    def jog_y_pos_callback(self, sender, app_data):
        """Callback for Y+ jog button"""
        pass  # Will be connected to external function
    
    def jog_y_neg_callback(self, sender, app_data):
        """Callback for Y- jog button"""
        pass  # Will be connected to external function
    
    def jog_z_pos_callback(self, sender, app_data):
        """Callback for Z+ jog button"""
        pass  # Will be connected to external function
    
    def jog_z_neg_callback(self, sender, app_data):
        """Callback for Z- jog button"""
        pass  # Will be connected to external function
    
    def fast_feed_callback(self, sender, app_data):
        """Callback for fast feed button"""
        pass  # Will be connected to external function
    
    def slow_feed_callback(self, sender, app_data):
        """Callback for slow feed button"""
        pass  # Will be connected to external function
    
    def create_new_point_callback(self, sender, app_data):
        """Callback for create new point button"""
        pass  # Will be connected to external function
    
    def export_dxf_callback(self, sender, app_data):
        """Callback for export DXF button"""
        pass  # Will be connected to external function
    
    def close_callback(self, sender, app_data):
        """Callback for close button"""
        pass  # Will be connected to external function
    
    def show_and_run(self):
        """Show the viewport and run the GUI loop"""
        dpg.show_viewport()
        dpg.maximize_viewport()
    
    def render_frame(self):
        """Render a single frame of the GUI"""
        dpg.render_dearpygui_frame()
    
    def is_running(self):
        """Check if the GUI is still running"""
        return dpg.is_dearpygui_running()
    
    def cleanup(self):
        """Clean up GUI resources"""
        dpg.destroy_context()


if __name__ == "__main__":
    # Test the GUI class
    print("Testing GUI module - this requires actual video frame and ports")