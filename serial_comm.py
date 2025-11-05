"""
Serial Communication Module for Comparatron
Handles communication with the CNC machine via serial port
"""

import serial
import serial.tools.list_ports
import time
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


class SerialCommunicator:
    """
    Class to handle serial communication with the CNC machine
    """
    
    def __init__(self):
        self.ser = None
        self.baudrate = 115200
        self.bytesize = 8
        self.parity = 'N'
        self.stopbits = 1
        self.timeout = None
        self.xonxoff = 1
        self.rtscts = 0
    
    def connect_to_com(self, com_port):
        """
        Connect to the specified COM port
        
        Args:
            com_port (str): COM port to connect to (e.g., 'COM3')
        
        Returns:
            bool: True if connection successful, False otherwise
        """
        try:
            logging.info(f"Attempting to connect to: {com_port}")
            print(f"Trying to connect to: {com_port}")
            
            # Close any existing connection first
            if self.ser and self.ser.is_open:
                self.ser.close()
                logging.info("Closed existing serial connection")
            
            self.ser = serial.Serial(
                com_port, 
                self.baudrate, 
                bytesize=self.bytesize, 
                parity=self.parity, 
                stopbits=self.stopbits, 
                timeout=self.timeout, 
                xonxoff=self.xonxoff, 
                rtscts=self.rtscts
            )
            
            # Wait a moment for connection to establish
            time.sleep(1)
            
            # Read initial response
            if self.ser.is_open and self.ser.in_waiting > 0:
                ser_in = self.ser.readline()
                response_str = ser_in.decode('utf-8', errors='ignore').strip()
                print(f"Connection response: {response_str}")
                logging.info(f"Connection response: {response_str}")
            
            logging.info(f"Successfully connected to {com_port}")
            return True
        except serial.SerialException as e:
            logging.error(f"Serial connection error to {com_port}: {e}")
            print(f"Serial connection error to {com_port}: {e}")
            return False
        except Exception as e:
            logging.error(f"Unexpected error connecting to {com_port}: {e}")
            print(f"Error connecting to {com_port}: {e}")
            return False
    
    def disconnect(self):
        """
        Close the serial connection
        """
        if self.ser and self.ser.is_open:
            try:
                self.ser.close()
                logging.info("Serial connection closed")
                print("Serial connection closed")
            except Exception as e:
                logging.error(f"Error closing serial connection: {e}")
                print(f"Error closing serial connection: {e}")
        else:
            logging.info("No open serial connection to close")
            print("No open serial connection to close")
    
    def send_command(self, command_string):
        """
        Send a command string to the machine
        
        Args:
            command_string (str or bytes): Command to send
        
        Returns:
            str: Response from the machine, or None if error
        """
        if not self.ser or not self.ser.is_open:
            logging.warning("No active serial connection")
            print("No active serial connection")
            return None
        
        try:
            # Convert to bytes if it's a string
            if isinstance(command_string, str):
                command_bytes = command_string.encode()
            else:
                command_bytes = command_string
            
            logging.debug(f"Sending command: {command_string}")
            
            # Send the command
            bytes_written = self.ser.write(command_bytes)
            self.ser.flush()  # Ensure data is sent
            
            # Read response with timeout
            response = None
            start_time = time.time()
            timeout = 3.0  # 3 second timeout
            
            while (time.time() - start_time) < timeout:
                if self.ser.in_waiting > 0:
                    response = self.ser.readline()
                    response_str = response.decode('utf-8', errors='ignore').strip()
                    logging.debug(f"Received response: {response_str}")
                    print(f"Response: {response_str}")
                    return response_str
                time.sleep(0.01)  # Small delay to prevent busy waiting
            
            logging.warning(f"Timeout waiting for response to command: {command_string}")
            return None
            
        except serial.SerialException as e:
            logging.error(f"Serial communication error when sending command '{command_string}': {e}")
            print(f"Serial error sending command: {e}")
            return None
        except Exception as e:
            logging.error(f"Unexpected error sending command '{command_string}': {e}")
            print(f"Error sending command: {e}")
            return None
    
    def get_available_ports(self):
        """
        Get list of available COM ports
        
        Returns:
            list: List of available COM ports
        """
        ports = serial.tools.list_ports.comports()
        return ports
    
    def home_machine(self):
        """Send home command to the machine ($H)"""
        return self.send_command(b'$H\r')
    
    def unlock_machine(self):
        """Send unlock command to the machine ($X)"""
        return self.send_command(b'$X\r')
    
    def set_feed(self, feed_rate=2000):
        """Set feed rate (default 2000)"""
        command = f'F{feed_rate}\r'
        return self.send_command(command)
    
    def set_origin(self):
        """Set work coordinate system origin (G92X0Y0)"""
        return self.send_command(b'G92X0Y0\r')
    
    def set_relative_mode(self):
        """Set machine to relative coordinate mode (G91)"""
        return self.send_command(b'G91\r')
    
    def jog_axis(self, x=0, y=0, z=0):
        """
        Jog machine along specified axes
        
        Args:
            x (float): X-axis movement distance
            y (float): Y-axis movement distance 
            z (float): Z-axis movement distance
        """
        command = f'G1X{x}Y{y}Z{z}\r'
        return self.send_command(command)
    
    def get_machine_status(self):
        """
        Get current machine status and position
        
        Returns:
            dict: Dictionary with status and position info
        """
        if not self.ser or not self.ser.is_open:
            return None
        
        # Query machine position
        self.ser.write(b'?\r')
        
        # Read response (with timeout)
        start_time = time.time()
        while self.ser.in_waiting == 0 and (time.time() - start_time) < 2.0:
            time.sleep(0.01)
        
        if self.ser.in_waiting > 0:
            response = self.ser.readline()
            response_str = response.decode('utf-8').strip()
            
            if response_str.startswith('<Idle|WPos'):
                # Parse position info
                pos_str = response_str.removeprefix('<Idle|WPos:')
                coords_str = pos_str.split('|')[0]  # Get position part before other info
                coords = coords_str.split(',')
                
                if len(coords) >= 3:
                    try:
                        x, y, z = float(coords[0]), float(coords[1]), float(coords[2])
                        return {
                            'status': 'idle',
                            'x': x,
                            'y': y, 
                            'z': z,
                            'raw_response': response_str
                        }
                    except ValueError:
                        print(f"Error parsing coordinates: {coords}")
                        return {'raw_response': response_str}
            
            return {'raw_response': response_str}
        
        return None


if __name__ == "__main__":
    # Test serial communication
    comm = SerialCommunicator()
    ports = comm.get_available_ports()
    print("Available ports:")
    for port in ports:
        print(f"  {port}")