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
        self.baudrate = 115200  # Standard GRBL baud rate
        self.bytesize = 8
        self.parity = 'N'
        self.stopbits = 1
        self.timeout = 2  # Set a reasonable timeout to avoid hanging
        self.xonxoff = 0  # Disable software flow control to reduce potential issues
        self.rtscts = 0   # Disable hardware flow control
    
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
            time.sleep(2)  # Increased wait time to allow for proper initialization

            # Try to get status from GRBL - this is the key test to see if it's responsive
            if self.ser.is_open:
                # Send the status query command
                self.ser.write(b'?\r')
                self.ser.flush()

                # Wait briefly for response
                time.sleep(0.5)

                # Read any response
                if self.ser.in_waiting > 0:
                    ser_in = self.ser.readline()
                    response_str = ser_in.decode('utf-8', errors='ignore').strip()
                    print(f"Connection response: {response_str}")
                    logging.info(f"Connection response: {response_str}")

                    # Check if the response is from GRBL
                    if 'grbl' in response_str.lower() or response_str.startswith('<'):
                        logging.info(f"Successfully connected to GRBL controller on {com_port}")
                        return True
                    else:
                        # If we get a response but it's not GRBL-like, it might be an unpowered device
                        print(f"Connected to device but may not be an active GRBL controller: {response_str}")
                        print("Possible issue: Main power supply (12V/24V) may not be connected to the CNC shield")
                else:
                    # No response received - device may be present but not responding (unpowered)
                    print("Device detected but no response received - check main power supply (12V/24V) connection")
                    print("GRBL controller typically requires main power to be fully operational")

            logging.info(f"Successfully opened serial port {com_port} but device may not be responsive")
            return True  # Return True even if not fully responsive so user can try other operations
        except serial.SerialException as e:
            logging.error(f"Serial connection error to {com_port}: {e}")
            if "permission" in str(e).lower():
                print(f"Permission error: Make sure you have access to {com_port}")
                print("Try: sudo usermod -a -G dialout $USER")
                print("Then log out and log back in, or run with sudo")
            elif "access" in str(e).lower() or "busy" in str(e).lower():
                print(f"Port in use or access denied: {com_port}")
                print("Make sure no other program is using this serial port")
            else:
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
    
    def send_command(self, command_string, multi_line_response=False):
        """
        Send a command string to the machine with improved reliability

        Args:
            command_string (str or bytes): Command to send
            multi_line_response (bool): Whether to expect multiple line responses

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
                command_string = command_string.strip()  # Clean up the command
                command_bytes = command_string.encode() + b'\n'  # Add newline for proper GRBL command termination
            else:
                command_bytes = command_string

            logging.debug(f"Sending command: {command_string}")

            # Clear input buffer to start fresh (get rid of any backlog from previous operations)
            if self.ser.in_waiting > 0:
                self.ser.reset_input_buffer()
                time.sleep(0.05)  # Brief pause after clearing buffer

            # Send the command
            bytes_written = self.ser.write(command_bytes)
            self.ser.flush()  # Ensure data is sent

            # Read response with timeout
            start_time = time.time()
            timeout = 5.0  # Default timeout

            # Use a longer timeout for settings and parameters commands that return multiple lines
            if command_string.strip() in ['$$', '$#']:
                timeout = 8.0 if command_string.strip() == '$$' else 5.0
                multi_line_response = True  # Force multi-line for these commands

            if multi_line_response:
                # Collect multiple responses for commands that return multiple lines
                responses = []
                # Give GRBL a moment to start responding
                time.sleep(0.1 if command_string.strip() in ['$$', '$#'] else 0.05)

                while (time.time() - start_time) < timeout:
                    if self.ser.in_waiting > 0:
                        response = self.ser.readline()
                        response_str = response.decode('utf-8', errors='ignore').strip()
                        if response_str:
                            responses.append(response_str)
                            logging.debug(f"Received response: {response_str}")
                            print(f"Response: {response_str}")

                            # Check if it's the final 'ok' response for multi-line commands
                            # For $$ and $# commands, GRBL ends with 'ok'
                            if (command_string.strip() in ['$$', '$#'] and
                                response_str.startswith('ok')):
                                break
                    else:
                        # Small delay to prevent excessive CPU usage
                        time.sleep(0.02)

                        # For multi-line responses, if we've received some data and no more is coming,
                        # we might be done (but we wait for the 'ok' response for $$ and $#)
                        if command_string.strip() not in ['$$', '$#'] and responses:
                            # For other multi-line responses, if no more data is arriving, we might be done
                            if (time.time() - start_time) > 1.5:  # Wait a bit to ensure all responses have arrived
                                break

                # Return combined responses if any received
                if responses:
                    full_response = '\n'.join(responses)
                    return full_response
            else:
                # For single-line responses - implement more robust response reading
                response_buffer = []
                response_str = ""

                while (time.time() - start_time) < timeout:
                    if self.ser.in_waiting > 0:
                        # Read one byte at a time to avoid corruption
                        byte = self.ser.read(1)
                        char = byte.decode('utf-8', errors='ignore')

                        if char == '\n' or char == '\r':  # End of line
                            if response_str.strip():  # Only add non-empty responses
                                response_buffer.append(response_str.strip())
                                logging.debug(f"Received response: {response_str.strip()}")
                                print(f"Response: {response_str.strip()}")
                                response_str = ""
                        else:
                            response_str += char  # Accumulate character

                        # Check if we have a complete response (for single commands)
                        if response_buffer and response_buffer[-1] != 'ok':  # Keep reading until 'ok' or timeout
                            time.sleep(0.01)  # Small delay to allow more data to arrive
                        elif response_buffer and response_buffer[-1] == 'ok':  # Got the 'ok' response
                            break
                    else:
                        time.sleep(0.02)  # Brief pause to reduce CPU usage

                # If we have accumulated a response string that hasn't been captured due to no newline
                if response_str.strip():
                    response_buffer.append(response_str.strip())

                # Return the response
                if response_buffer:
                    # Return the last meaningful response (not 'ok' if we need a specific response)
                    # For commands like ?, we want the status, not the 'ok' confirmation
                    for resp in reversed(response_buffer):
                        if resp.lower() != 'ok' or len(response_buffer) == 1:
                            return resp

                    # If all we got was 'ok', return that
                    if 'ok' in response_buffer:
                        return 'ok'
                    # If we got something else, return the last non-'ok' item
                    for resp in reversed(response_buffer):
                        if resp.lower() != 'ok':
                            return resp
                    # If only 'ok' exists, return 'ok'
                    return 'ok'

            # If we timed out without getting a proper response
            logging.warning(f"Timeout waiting for response to command: {command_string}")
            print(f"Timeout waiting for response to command: {command_string}")
            print("Possible issues:")
            print("  - Main power supply (12V/24V) is not connected to the CNC shield")
            print("  - Motors or drivers are not receiving power")
            print("  - GRBL controller is not fully operational without main power")
            return None

        except serial.SerialException as e:
            logging.error(f"Serial communication error when sending command '{command_string}': {e}")
            if "write" in str(e).lower() or "output" in str(e).lower():
                print(f"Cannot send command - device may not be properly powered: {e}")
                print("Check that main power supply (12V/24V) is connected to the CNC shield")
            else:
                print(f"Serial error sending command: {e}")
            return None
        except Exception as e:
            logging.error(f"Unexpected error sending command '{command_string}': {e}")
            print(f"Error sending command: {e}")
            return None
    
    def get_available_ports(self):
        """
        Get list of available COM ports filtered to prioritize potential GRBL devices
        
        Returns:
            list: List of available COM ports that are likely to be GRBL controllers
        """
        import platform
        all_ports = serial.tools.list_ports.comports()
        
        # Filter for likely GRBL/Arduino devices using multiple criteria
        grbl_ports = []
        arduino_ports = []
        
        for port in all_ports:
            # Check the description for keywords that indicate likely Arduino/GRBL devices
            desc = port.description.lower()
            vid_pid = f"{port.vid}:{port.pid}".lower() if port.vid else ""
            product = port.product.lower() if port.product else ""
            manuf = port.manufacturer.lower() if port.manufacturer else ""
            
            # Criteria for GRBL devices (common identifiers for Arduino-based CNC controllers)
            is_grbl_device = (
                # Common descriptions in Arduino/GRBL controllers
                ('arduino' in desc or 'arduino' in product or 'arduino' in manuf) or
                ('grbl' in desc or 'grbl' in product or 'grbl' in manuf) or
                ('cnc' in desc or 'cnc' in product) or
                ('ch340' in desc or 'ch340' in manuf) or  # Common USB-serial chip
                ('cp210' in desc or 'cp210' in manuf) or  # Another common chip
                ('ftdi' in desc or 'ftdi' in manuf) or    # FTDI chips are common in Arduinos
                ('atmega' in desc or 'atmega' in product) or  # Atmel ATMega chips
                # Common VID/PID combinations for Arduino/compatible boards
                ('2341' in vid_pid or  # Arduino official
                 '1a86' in vid_pid or  # CH340 Chinese Arduinos
                 '0403' in vid_pid or  # FTDI
                 '10c4' in vid_pid or  # CP210x
                 '03eb' in vid_pid)    # Atmel (Arduino Mega)
            )
            
            # Common USB serial converters used with GRBL
            is_usb_serial = (
                'ch340' in desc or 'ch340' in manuf or
                'cp210' in desc or 'cp210' in manuf or 
                'ftdi' in desc or 'ftdi' in manuf or
                'usb' in desc
            )
            
            # On Linux, prioritize USB serial ports that are likely for microcontrollers
            if platform.system().lower() == 'linux':
                # On Linux, USB serial adapters typically show up as /dev/ttyUSB* or /dev/ttyACM*
                is_usb_adapter = port.device.startswith('/dev/ttyUSB') or port.device.startswith('/dev/ttyACM')
                
                if is_grbl_device or (is_usb_serial and is_usb_adapter):
                    grbl_ports.append(port)
                elif 'arduino' in manuf or 'grbl' in manuf or 'cnc' in manuf:
                    # Additional check for manufacturer names
                    grbl_ports.append(port)
                elif is_usb_serial:
                    # Less certain but possibly relevant devices go to a secondary list
                    arduino_ports.append(port)
            else:
                # On other systems (Windows/MacOS), include devices that match criteria
                if is_grbl_device:
                    grbl_ports.append(port)
                elif is_usb_serial:
                    arduino_ports.append(port)
        
        # Combine the lists: definitely GRBL devices first, then potential Arduino devices
        filtered_ports = grbl_ports + [port for port in arduino_ports if port not in grbl_ports]
        
        if not filtered_ports:
            # If no filtered ports are found, return all ports as backup
            logging.info("No GRBL-specific ports found, returning all available ports")
            filtered_ports = list(all_ports)
        
        # Log what we found
        port_info = [(port.device, port.description) for port in filtered_ports]
        logging.info(f"Filtered ports for GRBL devices: {port_info}")
        
        return filtered_ports
    
    def home_machine(self):
        """Send home command to the machine ($H)"""
        print("Sending home command ($H) to machine...")
        result = self.send_command(b'$H\r')
        if result is None:
            print("Home command sent but no confirmation received")
            print("Check power connections to motors and drivers")
        return result

    def unlock_machine(self):
        """Send unlock command to the machine ($X)"""
        print("Sending unlock command ($X) to machine...")
        result = self.send_command(b'$X\r')
        if result is None:
            print("Unlock command sent but no confirmation received")
        return result

    def reset_alarm_state(self):
        """Send multiple commands to reset alarm state - for limit alarms like ALARM:2"""
        print("Resetting alarm state...")

        # First try the regular unlock
        self.send_command(b'$X\r')

        # Then try sending a soft reset command (Ctrl+X equivalent)
        self.send_command(b'\x18')  # This is Ctrl+X (soft reset)
        time.sleep(0.5)  # Wait for reset to complete

        # Try unlock again after reset
        self.send_command(b'$X\r')

        # Check status
        status = self.send_command(b'?\r')
        print(f"Status after alarm reset attempt: {status}")

        return status

    def set_feed(self, feed_rate=2000):
        """Set feed rate (default 2000)"""
        command = f'F{feed_rate}\r'
        print(f"Setting feed rate to {feed_rate}...")
        result = self.send_command(command)
        if result is None:
            print(f"Feed rate command sent but no confirmation received")
        return result

    def set_origin(self):
        """Set work coordinate system origin (G92X0Y0)"""
        print("Setting work coordinate system origin (G92X0Y0)...")
        result = self.send_command(b'G92X0Y0\r')
        if result is None:
            print("Origin setting command sent but no confirmation received")
        return result

    def set_relative_mode(self):
        """Set machine to relative coordinate mode (G91)"""
        print("Setting machine to relative coordinate mode (G91)...")
        result = self.send_command(b'G91\r')
        if result is None:
            print("Relative mode command sent but no confirmation received")
        return result

    def jog_axis(self, x=0, y=0, z=0):
        """
        Jog machine along specified axes

        Args:
            x (float): X-axis movement distance
            y (float): Y-axis movement distance
            z (float): Z-axis movement distance
        """
        command = f'G1X{x}Y{y}Z{z}\r'
        print(f"Sending jog command: {command.strip()}")
        result = self.send_command(command)
        if result is None:
            print("Jog command sent but no confirmation received")
            print("Check that motors and drivers are properly powered")
        return result
    
    def get_machine_status(self):
        """
        Get current machine status and position

        Returns:
            dict: Dictionary with status and position info
        """
        if not self.ser or not self.ser.is_open:
            logging.warning("No active serial connection")
            print("No active serial connection")
            return None

        try:
            # Send the status query command '?'
            command_bytes = b'?\r'
            logging.debug(f"Sending status query command: {command_bytes}")

            # Send the command
            bytes_written = self.ser.write(command_bytes)
            self.ser.flush()  # Ensure data is sent

            # Read response with timeout
            response = None
            start_time = time.time()
            timeout = 2.0

            while (time.time() - start_time) < timeout:
                if self.ser.in_waiting > 0:
                    response = self.ser.readline()
                    response_str = response.decode('utf-8', errors='ignore').strip()
                    logging.debug(f"Received status response: {response_str}")
                    print(f"Status response: {response_str}")
                    return response_str
                time.sleep(0.05)

            logging.warning("Timeout waiting for status response")
            print("Timeout waiting for status response")
            return None

        except Exception as e:
            logging.error(f"Error getting machine status: {e}")
            print(f"Error getting machine status: {e}")
            return None

    def send_raw_command(self, raw_command):
        """
        Send a raw command to the machine without any safety checks

        Args:
            raw_command (str): Raw command to send

        Returns:
            str: Response from the machine, or None if error
        """
        # Add carriage return if not present
        if not raw_command.endswith('\r'):
            raw_command += '\r'

        print(f"Sending raw command: {raw_command}")
        return self.send_command(raw_command)

    def get_settings_list(self):
        """
        Get the list of all GRBL settings using the $$ command

        Returns:
            str: Response from the machine with all settings, or None if error
        """
        if not self.ser or not self.ser.is_open:
            logging.warning("No active serial connection")
            print("No active serial connection")
            return None

        print("Sending $$ command to get all GRBL settings...")
        try:
            # Send the settings list command '$$'
            command_bytes = b'$$\r'
            logging.debug(f"Sending settings list command: {command_bytes}")

            # Send the command
            bytes_written = self.ser.write(command_bytes)
            self.ser.flush()  # Ensure data is sent

            # Small delay for the command to be processed by GRBL
            time.sleep(0.1)

            # Read response (GRBL settings command typically returns multiple lines)
            responses = []
            start_time = time.time()
            timeout = 8.0  # Increased timeout significantly to allow time for all settings to be returned
            received_ok = False  # Flag to track if we've received the 'ok' response

            # For $$ command, we need to wait for all responses including the final 'ok'
            # The responses might come in quickly or slowly depending on the GRBL version and machine
            while (time.time() - start_time) < timeout and not received_ok:
                if self.ser.in_waiting > 0:
                    response = self.ser.readline()
                    response_str = response.decode('utf-8', errors='ignore').strip()
                    if response_str:
                        responses.append(response_str)
                        logging.debug(f"Received settings response: {response_str}")
                        print(f"Settings response: {response_str}")

                        # GRBL ends the settings list with an 'ok' response
                        if response_str.startswith('ok'):
                            received_ok = True
                else:
                    # Brief pause to prevent excessive CPU usage when no data is available
                    time.sleep(0.03)

            # If we have collected responses, return the complete list
            if responses:
                full_response = '\n'.join(responses)
                logging.info(f"Settings retrieved successfully ({len(responses)} lines)")
                return full_response
            else:
                logging.warning("No response received for settings list command")
                print("No response received for settings list command")
                return None

        except Exception as e:
            logging.error(f"Error getting settings list: {e}")
            print(f"Error getting settings list: {e}")
            return None

    def get_parameters_list(self):
        """
        Get the list of all GRBL parameters using the $# command

        Returns:
            str: Response from the machine with all parameters, or None if error
        """
        if not self.ser or not self.ser.is_open:
            logging.warning("No active serial connection")
            print("No active serial connection")
            return None

        print("Sending $# command to get all GRBL parameters...")
        try:
            # Send the parameters list command '$#'
            command_bytes = b'$#\r'
            logging.debug(f"Sending parameters list command: {command_bytes}")

            # Send the command
            bytes_written = self.ser.write(command_bytes)
            self.ser.flush()  # Ensure data is sent

            # Small delay for the command to be processed by GRBL
            time.sleep(0.1)

            # Read response (GRBL parameters command typically returns multiple lines)
            responses = []
            start_time = time.time()
            timeout = 5.0  # Increased timeout to allow time for all parameters to be returned
            received_ok = False  # Flag to track if we've received the 'ok' response

            # For $# command, we need to wait for all responses including the final 'ok'
            # The responses might come in quickly or slowly depending on the GRBL version and machine
            while (time.time() - start_time) < timeout and not received_ok:
                if self.ser.in_waiting > 0:
                    response = self.ser.readline()
                    response_str = response.decode('utf-8', errors='ignore').strip()
                    if response_str:
                        responses.append(response_str)
                        logging.debug(f"Received parameters response: {response_str}")
                        print(f"Parameters response: {response_str}")

                        # GRBL ends the parameters list with an 'ok' response
                        if response_str.startswith('ok'):
                            received_ok = True
                else:
                    # Brief pause to prevent excessive CPU usage when no data is available
                    time.sleep(0.03)

            # If we have collected responses, return the complete list
            if responses:
                full_response = '\n'.join(responses)
                logging.info(f"Parameters retrieved successfully ({len(responses)} lines)")
                return full_response
            else:
                logging.warning("No response received for parameters list command")
                print("No response received for parameters list command")
                return None

        except Exception as e:
            logging.error(f"Error getting parameters list: {e}")
            print(f"Error getting parameters list: {e}")
            return None


if __name__ == "__main__":
    # Test serial communication
    comm = SerialCommunicator()
    ports = comm.get_available_ports()
    print("Available ports:")
    for port in ports:
        print(f"  {port}")