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
            'faster': 3000,
            'fast': 1000,
            'slow': 200,
            'default': 200  # Changed from 2000 to 200 for safer/slower operation
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

    def send_raw_command(self, raw_command):
        """Send a raw command without homing safety checks for advanced users"""
        print(f"Sending raw command without safety checks: {raw_command}")
        if self.comm and hasattr(self.comm, 'send_raw_command'):
            response = self.comm.send_raw_command(raw_command)
            return response
        else:
            print("No active serial connection")
            return None

    def get_machine_status(self):
        """Get current machine status"""
        if self.comm and hasattr(self.comm, 'get_machine_status'):
            return self.comm.get_machine_status()
        else:
            print("No active serial connection")
            return None
    
    def jog_x_positive(self):
        """Jog X axis positive by current jog distance using relative moves"""
        distance = self.jog_distance
        # Use relative mode for single axis move to avoid coordinate issues
        command = f"G91G1F{self.current_feed_rate}X{distance}\rG90"  # Move only X, then return to absolute
        logging.info(f"Jogging X+ by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging X+ by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("X+ jog command sent but no response - check motor power")
        return result

    def jog_x_negative(self):
        """Jog X axis negative by current jog distance using relative moves"""
        distance = self.jog_distance
        command = f"G91G1F{self.current_feed_rate}X-{distance}\rG90"  # Move only X, then return to absolute
        logging.info(f"Jogging X- by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging X- by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("X- jog command sent but no response - check motor power")
        return result

    def jog_y_positive(self):
        """Jog Y axis positive by current jog distance using relative moves"""
        distance = self.jog_distance
        command = f"G91G1F{self.current_feed_rate}Y{distance}\rG90"  # Move only Y, then return to absolute
        logging.info(f"Jogging Y+ by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging Y+ by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("Y+ jog command sent but no response - check motor power")
        return result

    def jog_y_negative(self):
        """Jog Y axis negative by current jog distance using relative moves"""
        distance = self.jog_distance
        command = f"G91G1F{self.current_feed_rate}Y-{distance}\rG90"  # Move only Y, then return to absolute
        logging.info(f"Jogging Y- by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging Y- by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("Y- jog command sent but no response - check motor power")
        return result

    def jog_z_positive(self):
        """Jog Z axis positive by current jog distance using relative moves"""
        distance = min(self.jog_distance, 10.0)  # Safety limit
        command = f"G91G1F{self.current_feed_rate}Z{distance}\rG90"  # Move only Z, then return to absolute
        logging.info(f"Jogging Z+ by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging Z+ by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("Z+ jog command sent but no response - check motor power")
        return result

    def jog_z_negative(self):
        """Jog Z axis negative by current jog distance using relative moves"""
        distance = min(self.jog_distance, 10.0)  # Safety limit
        command = f"G91G1F{self.current_feed_rate}Z-{distance}\rG90"  # Move only Z, then return to absolute
        logging.info(f"Jogging Z- by {distance}mm at feed rate {self.current_feed_rate}")
        print(f"Jogging Z- by {distance}mm at feed rate {self.current_feed_rate}")
        result = self.comm.send_command(command)
        # Ensure we wait for the move to complete before next command
        time.sleep(0.1)  # Small delay to ensure command completes
        if result is None:
            print("Z- jog command sent but no response - check motor power")
        return result

    def reset_alarm_state(self):
        """Reset the alarm state when machine is in alarm condition"""
        return self.comm.reset_alarm_state()
    
    def home_and_setup(self):
        """
        Perform complete home and setup sequence

        Returns:
            bool: True if all operations successful, False otherwise
        """
        print("Starting home and setup sequence...")
        print("Note: This requires the main power supply (12V/24V) to be connected to the CNC shield")

        operations = [
            ("Unlocking machine", self.comm.unlock_machine),
            ("Homing machine", self.comm.home_machine),
            ("Setting feed rate to safe default", lambda: self.comm.set_feed(200)),  # Changed from 2000 to 200
            ("Setting origin", self.comm.set_origin),
            ("Setting relative mode", self.comm.set_relative_mode)
        ]

        for op_name, op_func in operations:
            print(f"Performing: {op_name}")
            result = op_func()
            if result is None:
                print(f"Warning: {op_name} completed but no confirmation received")
                print("This may be due to motors not being powered")
            else:
                print(f"Completed: {op_name}")
            time.sleep(1.0)  # Increased pause between operations for better reliability

        print("Home and setup sequence completed")
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