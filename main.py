# Comparatron V1.1
# by Cameron Coward 
# fork by RGP
# http://www.cameroncoward.com
# Manually install the different modules using "python -m pip install _modulenamelistedbelow_""
# list of the module name to replace : numpy - dearpygui - pyserial - opencv-python - ezdxf - serial-tool - pyinstaller 
#for compiling the script with pyinstaller using the command : pyinstaller main.py -F   for a one file executable  

# DearPyGUI for GUI, OpenCV for video capture, NumPy for calculations,
#PySerial for communication with machine, EZDXF for creating DXF drawings, sys for clean exit
import dearpygui.dearpygui as dpg
import cv2 as cv
import numpy as np
import serial
import serial.tools.list_ports
import ezdxf
import sys
from math import sqrt

# Chapter for selecting the camera
# Get a list of available cameras
camera_list = []
for i in range(6):
    cap = cv.VideoCapture(i)
    
    if cap.read()[0]:
         camera_list.append(i)
    cap.release()

# Prompt the user to select a camera
if not camera_list:
    print("No cameras found!")
else:
    print("Available cameras:")
    for i, camera in enumerate(camera_list):
        print(f"{i+1}. Camera {camera}")
    selected_camera = int(input("Select a camera (1-{}): ".format(len(camera_list))))

    # Open the selected camera
    cap = cv.VideoCapture(camera_list[selected_camera-1])

    # Display the live video stream
    while True:
        ret, frame = cap.read()
        if not ret:
            print("Error reading frame!")
            break

        # Resize the frame to 800x600
        frame = cv.resize(frame, (800, 600))

        # Display text in the top right corner
        text = "Press q to validate this cam"
        org = (50, 50)
        font = cv.FONT_HERSHEY_SIMPLEX
        font_scale = 1
        color = (255, 255, 255)
        thickness = 2
        cv.putText(frame, text, org, font, font_scale, color, thickness, cv.LINE_AA)

        # Display the frame
        cv.imshow('Camera', frame)

        # Wait for user input (q to exit)
        if cv.waitKey(1) == ord('q'):
            break

    # Release the camera and close the window
    cap.release()
    cv.destroyAllWindows()
# END Chapter for selecting the camera

doc = ezdxf.new(dxfversion="R2010") #create new DXF drawing
doc.layers.add("COMPARATRON_OUTPUT", color=2) #add layer for our drawing
msp = doc.modelspace() #create a modelspace for our drawing

ser = None #for use with the serial connection later
ports = serial.tools.list_ports.comports()

dpg.create_context() #create DearPyGUI object
dpg.create_viewport(title='Comparatron by Cameron Coward', width=1280, height=720) #main program window
dpg.setup_dearpygui() #setup DearPyGUI

vid = cv.VideoCapture(camera_list[selected_camera-1]) #create OpenCV object with first video feed available
ret, frame = vid.read() #pull frame from video feed

# get the video parameters
frame_width = vid.get(cv.CAP_PROP_FRAME_WIDTH)
frame_height = vid.get(cv.CAP_PROP_FRAME_HEIGHT)
video_fps = vid.get(cv.CAP_PROP_FPS)

# calculate center point for adding crosshair reticle
target_x = int(frame_width / 2)
target_y = int(frame_height / 2)

data = np.flip(frame, 2)  # flip video BGR colorspace to RGB
data = data.ravel()  # flatten camera data to 1D
data = np.asfarray(data, dtype='f')  # change data type to 32bit floats
texture_data = np.true_divide(data, 255.0)  # normalize image data to prepare for GPU

prev_point_x = float(0) #set the historical point to 0
prev_point_y = float(0) #set the historical point to 0
difference_x = float(0) #set the historical point to 0
difference_y = float(0) #set the historical point to 0
difference_distance = float(0)
old_pos_str = "initialize text"
jog_count = 1 #count if the jog order was sent to avoid multiple "create new point command"
old_jog_count = 0 #used to compare if order was sent
old_control_ser = "initialize string" #use to double  check the motor recorded position
data_acq_status = "ready" #can display if the acquisition is ongoing or ready


def connect_to_com(): #connect to the COM port specified by user
    global ser #to use the same object we already created
    com_port_full = str((dpg.get_value("port_selection"))) #pull COM port selection as a string
    com_port = com_port_full.split(' ') #split at " " so first string is just the COM port
    print("Trying to connect to:", com_port[0])
    ser = serial.Serial(com_port[0], 115200, bytesize=8, parity='N', stopbits=1, timeout=None, xonxoff=1, rtscts=0) #connect to COM port
    ser_in = ser.readline() #listen for connection status from machine
    print(ser_in)

def home_machine(): #use the built-in GRBL command to home machine
    global ser #to use the same object we already created
    ser.write(b'$H\r') #home command and return as bytes
    ser_in = ser.readline()
    print(ser_in)
    
def unlock_machine(): #use the built-in GRBL command to unlock machine motors
    global ser #to use the same object we already created
    ser.write(b'$X\r')
    ser_in = ser.readline()
    print(ser_in)
    
def set_feed(): #set feedrate to 2000 (fast is 1000 and slow is 200)
    global ser #to use the same object we already created
    ser.write(b'F2000\r')
    ser_in = ser.readline()
    print(ser_in)
    
def set_origin(): #set the WPS coordinate origins to zero
    global ser #to use the same object we already created
    ser.write(b'G92X0Y0\r')
    ser_in = ser.readline()
    print(ser_in)
    
def set_rel(): #set G91 (to use relative coordinates from now on)
    global ser #to use the same object we already created
    ser.write(b'G91\r')
    ser_in = ser.readline()
    print(ser_in)
    
def jog_x_pos(): #move X axis right by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    command_string = ("G1X" + distance + "Y0\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    global jog_count #increase the jog count to allow the "create new point"
    jog_count = jog_count + 1
    
def jog_x_neg(): #move X axis left by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    command_string = ("G1X-" + distance + "Y0\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    global jog_count #increase the jog count to allow the "create new point"
    jog_count = jog_count + 1
    
def jog_y_pos(): #move Y axis up by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    command_string = ("G1X0Y" + distance + "\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    global jog_count #increase the jog count to allow the "create new point"
    jog_count = jog_count + 1
    
def jog_y_neg(): #move Y axis down by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    command_string = ("G1X0Y-" + distance + "\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    global jog_count #increase the jog count to allow the "create new point"
    jog_count = jog_count + 1
    
def jog_z_pos(): #move Z axis up by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    if float(distance) > 10.00: #prevent moving Z axis by 50.00
        distance = "10.00"
    command_string = ("G1Z" + distance + "\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    
def jog_z_neg(): #move Z axis down by the set amount
    global ser #to use the same object we already created
    distance = (dpg.get_value("JD"))
    if float(distance) > 10.00: #prevent moving Z axis by 50.00
        distance = "10.00"
    command_string = ("G1Z-" + distance + "\r")
    command_bytes = command_string.encode()
    ser.write(command_bytes)
    ser_in = ser.readline()
    print(ser_in)
    
def fast_feed(): #set feedrate to 1000 for quick movement
    global ser #to use the same object we already created
    ser.write(b'F1000\r')
    ser_in = ser.readline()
    print(ser_in)

def slow_feed(): #set feedrate to 200 for slow movement
    global ser #to use the same object we already created
    ser.write(b'F200\r')
    ser_in = ser.readline()
    print(ser_in)
    
def create_new_point():
    global ser #to use the same object we already created
    global prev_point_x #declare this variable even outside of this block
    global prev_point_y 
    global difference_x 
    global difference_y 
    global difference_distance
    global old_pos_str
    global old_jog_count
    global jog_count
    global data_acq_status
    global old_control_ser

    if jog_count != old_jog_count:#check if the motors have moved from the previous point
        print ("jog count is", jog_count)
        data_acq_status = "ongoing" #display if the program is measuring and waiting for motors position
        dpg.set_value("data_acq_status", data_acq_status)
        old_jog_count = jog_count
        measure = False 
        while measure == False: #loop for reading the data in case of empty respond from grbl
            ser.write(b'?\r') #queries the current coordinates
            ser_in = ser.readline() #read the data
            ser_str = ser_in.decode("utf-8") #convert the returned coordinates from bytes to string
                    
            try: #block function to test
                if ser_str.startswith('<Idle|WPos'):
                    print(ser_str)
                    #control that WPos really changed and not the rest
                    control_ser1 = ser_str.removeprefix('<Idle|WPos:') #remove everything before the first (X) coordinate
                    control_ser2 = control_ser1.split('|') #split the rest of the string by
                    control_ser3 = control_ser2[0] #remove everything after |FS as it may change
                    print(control_ser3)
                    if control_ser3 != old_control_ser: #control that WPos really changed and nothing else on the string
                        old_control_ser = control_ser3
                        old_pos_str = ser_str
                        measure = True
                    else:
                        print("motor position feedback is still not updated yet")
                else:
                    print("Invalid motor position:", ser_str)
            except:
                print("Error while processing motor position:", ser_str)

        ser_str = ser_str.removeprefix('<Idle|WPos:') #remove everything before the first (X) coordinate
        ser_str = ser_str.removesuffix('|FS')
        print(ser_str)
        coords = ser_str.split(',') #split the rest of the string by commas
        print(coords[0]) #first split is X coordinates
        print(coords[1]) #second split is Y coordinates
        point_x = float(coords[0]) #convert X coordinate string to float
        point_y = float(coords[1]) #convert Y coordinate string to float

        if prev_point_x != float(0) and prev_point_y != float(0):
            difference_x = point_x - prev_point_x #calculate the difference in x
            difference_y = point_y - prev_point_y #calculate the difference in y
            difference_distance = sqrt((difference_x * difference_x) + (difference_y * difference_y)) #calculate the distance using pythagorean theorem
        prev_point_x = point_x #store the actual position for a delta calcul
        prev_point_y = point_y #store the actual position for a delta calcul
        global msp #to use the same modelspace we already created
        msp.add_point((point_x,point_y), dxfattribs={"color": 7}) #create a point in the DXF at the coordinates
        draw_x = 5 + int(-2 * point_x) #scale coordinate for use in the DearPyGUI drawing plot
        draw_y = 5 + int(-2 * point_y) #scale coordinate for use in the DearPyGUI drawing plot
        dpg.draw_circle(center=(draw_x, draw_y), radius=1, color=(255, 0, 0, 255), thickness=1, parent="plot") #add a circle to the DearPyGUI drawing plot at coordinates
        dpg.set_value("difference_x", difference_x)
        dpg.set_value("difference_y", difference_y)
        dpg.set_value("difference_distance", difference_distance)
        data_acq_status = "ready"
        dpg.set_value("data_acq_status", data_acq_status)
    else:
        print("position didn't moved")
    
def export_dxf_now(): #save the ongoing DXF file as the filename set by the user
    dxf_filename = (dpg.get_value("dxf_name"))
    doc.saveas(dxf_filename)
    print("DXF output to: ",dxf_filename)
    
def close_ser_now(): #close the serial connection to the machine, allowing for a new connection without a power cycle
    vid.release() #closes video feed
    print("Released video")
    global ser #to use the same object we already created
    
    if ser.isOpen() == True:
        ser.close() #closes the serial COM port connection to machine
        print("Closed serial connection")
    else:
        print("No open serial connection to close")
    
    dpg.destroy_context()
    print("Destroyed DearPyGUI context")
    sys.exit()

"""### tries to use the dearpygui keypress event to jog the machine but without success.
def on_key_press_left(sender, app_data, user_data):
    jog_x_neg()

def on_key_press_right(sender, app_data, user_data):
    jog_x_pos()

def on_key_press_up(sender, app_data, user_data):
    jog_y_pos()

def on_key_press_down(sender, app_data, user_data):
    jog_y_neg()

def on_key_press_space(sender, app_data, user_data):
    create_new_point()

def setup_keyboard_events():

    dpg.add_key_press_handler((dpg.mvKey_Left, on_key_press_left))
    dpg.add_key_press_handler((dpg.mvKey_Right, on_key_press_right))
    dpg.add_key_press_handler((dpg.mvKey_Up, on_key_press_up))
    dpg.add_key_press_handler((dpg.mvKey_Down, on_key_press_down))
    dpg.add_key_press_handler((dpg.mvKey_Space, on_key_press_space))


with dpg.window():
    
    setup_keyboard_events()
   
dpg.start_dearpygui()###"""

with dpg.texture_registry(show=False): #creates a "texture" of the video feed so we can display it
    dpg.add_raw_texture(frame.shape[1], frame.shape[0], texture_data, tag="texture_tag", format=dpg.mvFormat_Float_rgb)

with dpg.window(label="Microscope View", pos=(20,20), no_close=True): #window showing the video feed
    dpg.add_image("texture_tag")
    
with dpg.window(label="Jog Distance", pos=(20,frame_height+80), width=200, height=200, no_close=True): #window with the jog distance settings
    dpg.add_text("Millimeters:")
    def print_me(sender, data): #for some reason this is necessary for the radio buttons to work right
        print(dpg.get_value("JD")) #for some reason this is necessary for the radio buttons to work right
    dpg.add_radio_button(tag="JD", items=['50.00', '10.00', '1.00', '0.10', '0.01'], default_value='10.00', callback=print_me)
    with dpg.group(horizontal=True):
        dpg.add_button(tag="fast_feed", label="Fast F1000", callback=fast_feed)
        dpg.add_button(tag="slow_feed", label="Slow F200", callback=slow_feed)

with dpg.window(label="Jog Control", pos=(240,frame_height+80), width=200, height=200, no_close=True): #window with the jog controls
    dpg.add_button(tag="x_pos", label="X+", pos=(140,90), width=40, height=40, callback=jog_x_pos)
    dpg.add_button(tag="x_neg", label="X-", pos=(20,90), width=40, height=40, callback=jog_x_neg)
    dpg.add_button(tag="y_pos", label="Y+", pos=(80,30), width=40, height=40, callback=jog_y_pos)
    dpg.add_button(tag="y_neg", label="Y-", pos=(80,150), width=40, height=40, callback=jog_y_neg)
    dpg.add_button(tag="z_pos", label="Z+", pos=(90,90), callback=jog_z_pos)
    dpg.add_button(tag="z_neg", label="Z-", pos=(90,110), callback=jog_z_neg)
    
with dpg.window(label="Startup Sequence", pos=(20,frame_height+300), width=420, height=200, no_close=True): #window with the startup sequence buttons
    dpg.add_combo(tag="port_selection", items=ports)
    dpg.add_button(tag="connect_com", label="Connect to above COM port", callback=connect_to_com)
    dpg.add_button(tag="mach_home", label="Home ($H)", callback=home_machine)
    dpg.add_button(tag="mach_unlock", label="Unlock motors ($X)", callback=unlock_machine)
    dpg.add_button(tag="mach_feed", label="Set feedrate (F2000mm/s)", callback=set_feed)
    dpg.add_button(tag="mach_origin", label="Set origin point (G92X0Y0)", callback=set_origin)
    dpg.add_button(tag="mach_rel", label="Set to relative coordinates (G91)", callback=set_rel)
    
with dpg.window(label="Draw", pos=(460,frame_height+80), width=215, height=200, no_close=True): #window with drawing controls (just adding a point for now)
    dpg.add_text("Add new point at actual pos:")
    dpg.add_button(tag="new_point", label="New Point", width=80, height=40, callback=create_new_point) #button to create the new point
    
    #added the function to show the delta between the previous point and the actual one
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
        dpg.add_text("pos measurment :")
        dpg.add_text(tag="data_acq_status")

with dpg.window(label="DXF Output", pos=(460,frame_height+300), width=215, height=200, no_close=True): #window with DXF export controls
    dpg.add_text("Enter a filename")
    dpg.add_text("for the DXF output:")
    dpg.add_input_text(tag="dxf_name", default_value="comparatron.dxf")
    dpg.add_button(tag="export_dxf", label="Export DXF", callback=export_dxf_now)
    dpg.add_separator()
    dpg.add_text("Close serial and")
    dpg.add_text("release video:")
    dpg.add_button(tag="close_ser", label="Clean exit", callback=close_ser_now)
    
with dpg.window(label="Created Plot", pos=(frame_width+55, 20), width=700, height=960, no_close=True): #window that shows a visualization of plotted points
    with dpg.drawlist(tag="plot", width=660, height=920): #the drawing space for the plot
        dpg.draw_circle(center=(100, 200), radius=2, color=(255, 0, 0, 255), thickness=2, show=False) #hidden circle, necessary because drawlist requires a child object to initialize
    

dpg.show_viewport() #renders the DearPyGUI viewport
dpg.maximize_viewport() #maximizes the window
while dpg.is_dearpygui_running(): #DearPyGUI render loop
    dpg.set_value("data_acq_status", data_acq_status) #update the status in dpg  
    if vid.isOpened():
        ret, frame = vid.read()
        cv.drawMarker(frame, (target_x, target_y), (0, 0, 255), cv.MARKER_CROSS, 10, 1)
        data = np.flip(frame, 2)
        data = data.ravel()
        data = np.asfarray(data, dtype='f')
        texture_data = np.true_divide(data, 255.0)
        dpg.set_value("texture_tag", texture_data)


        # DearPyGUI framerate is tied to video feed framerate in this loop
        
    
    dpg.render_dearpygui_frame()

vid.release() #closes video feed
dpg.destroy_context() #closes DearPyGUI objects
