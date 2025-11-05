"""
Control Module for Comparatron
Handles machine control functions like jogging, homing, etc.
"""

from serial_comm import SerialCommunicator
import time
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


class MachineController:
    """
    Class to handle machine control operations
    """
    
    def __init__(self, serial_communicator):
        self.comm = serial_communicator
        self.feed_rates = {
            'fast': 1000,
            'slow': 200,
            'default': 2000
        }
        self.current_feed_rate = self.feed_rates['default']
        self.jog_distance = 10.0  # Default jog distance
        self.position_history = []
    
    def set_jog_distance(self, distance):
        """
        Set the jog distance for movement commands
        
        Args:
            distance (float or str): Distance to jog in mm
        """
        try:
            self.jog_distance = float(distance)
        except ValueError:
            print(f"Invalid jog distance: {distance}")
    
    def set_feed_rate(self, rate_type='default'):
        """
        Set feed rate for machine movements
        
        Args:
            rate_type (str): 'fast', 'slow', or 'default'
        """
        if rate_type in self.feed_rates:
            self.current_feed_rate = self.feed_rates[rate_type]
            return self.comm.set_feed(self.current_feed_rate)
        else:
            print(f"Invalid rate type: {rate_type}")
            return None
    
    def jog_x_positive(self):
        """Jog X axis positive by current jog distance"""
        distance = self.jog_distance
        command = f"G1X{distance}Y0\r"
        logging.info(f"Jogging X+ by {distance}mm")
        return self.comm.send_command(command)
    
    def jog_x_negative(self):
        """Jog X axis negative by current jog distance"""
        distance = self.jog_distance
        command = f"G1X-{distance}Y0\r"
        logging.info(f"Jogging X- by {distance}mm")
        return self.comm.send_command(command)
    
    def jog_y_positive(self):
        """Jog Y axis positive by current jog distance"""
        distance = self.jog_distance
        command = f"G1X0Y{distance}\r"
        logging.info(f"Jogging Y+ by {distance}mm")
        return self.comm.send_command(command)
    
    def jog_y_negative(self):
        """Jog Y axis negative by current jog distance"""
        distance = self.jog_distance
        command = f"G1X0Y-{distance}\r"
        logging.info(f"Jogging Y- by {distance}mm")
        return self.comm.send_command(command)
    
    def jog_z_positive(self):
        """Jog Z axis positive by current jog distance (with safety limit)"""
        distance = min(self.jog_distance, 10.0)  # Safety limit
        command = f"G1Z{distance}\r"
        logging.info(f"Jogging Z+ by {distance}mm")
        return self.comm.send_command(command)
    
    def jog_z_negative(self):
        """Jog Z axis negative by current jog distance (with safety limit)"""
        distance = min(self.jog_distance, 10.0)  # Safety limit
        command = f"G1Z-{distance}\r"
        logging.info(f"Jogging Z- by {distance}mm")
        return self.comm.send_command(command)
    
    def home_and_setup(self):
        """
        Perform complete home and setup sequence
        
        Returns:
            bool: True if all operations successful, False otherwise
        """
        operations = [
            ("Unlocking machine", self.comm.unlock_machine),
            ("Homing machine", self.comm.home_machine),
            ("Setting feed rate", lambda: self.comm.set_feed(2000)),
            ("Setting origin", self.comm.set_origin),
            ("Setting relative mode", self.comm.set_relative_mode)
        ]
        
        for op_name, op_func in operations:
            print(f"Performing: {op_name}")
            result = op_func()
            if result is None:
                print(f"Failed to perform: {op_name}")
                return False
            time.sleep(0.5)  # Brief pause between operations
        
        return True
    
    def get_current_position(self):
        """
        Get current machine position
        
        Returns:
            dict: Position information from machine
        """
        return self.comm.get_machine_status()
    
    def record_position(self):
        """
        Record current position in history
        
        Returns:
            dict: Current position or None if unavailable
        """
        pos = self.get_current_position()
        if pos and 'x' in pos and 'y' in pos:
            self.position_history.append({
                'x': pos['x'],
                'y': pos['y'],
                'z': pos['z'],
                'timestamp': time.time()
            })
            return pos
        return None
    
    def get_position_differences(self, pos1, pos2):
        """
        Calculate differences between two positions
        
        Args:
            pos1 (dict): First position
            pos2 (dict): Second position
            
        Returns:
            tuple: (diff_x, diff_y, distance)
        """
        if not pos1 or not pos2:
            return 0.0, 0.0, 0.0
        
        if 'x' not in pos1 or 'y' not in pos1 or 'x' not in pos2 or 'y' not in pos2:
            return 0.0, 0.0, 0.0
        
        diff_x = pos2['x'] - pos1['x']
        diff_y = pos2['y'] - pos1['y']
        distance = ((diff_x ** 2) + (diff_y ** 2)) ** 0.5
        
        return diff_x, diff_y, distance
    
    def get_last_position(self):
        """
        Get the last recorded position
        
        Returns:
            dict: Last position in history or None
        """
        if self.position_history:
            return self.position_history[-1]
        return None


if __name__ == "__main__":
    # Test the MachineController class
    # Note: This requires an actual serial connection to work
    print("MachineController test - requires actual machine connection")