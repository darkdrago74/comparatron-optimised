"""
Camera Management Module for Comparatron
Handles camera selection, initialization, and video capture
"""

import cv2 as cv
import numpy as np
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def find_available_cameras(max_cameras=6):
    """
    Find all available cameras on the system
    
    Args:
        max_cameras (int): Maximum number of camera indices to check
    
    Returns:
        list: List of available camera indices
    """
    available_cameras = []
    for i in range(max_cameras):
        try:
            cap = cv.VideoCapture(i)
            if cap.isOpened():
                ret = cap.read()[0]
                if ret:
                    available_cameras.append(i)
                    logging.info(f"Found camera at index {i}")
                else:
                    logging.debug(f"Camera at index {i} opened but failed to read frame")
                cap.release()
            else:
                # Try using CAP_DSHOW backend for Windows systems
                try:
                    cap = cv.VideoCapture(i, cv.CAP_DSHOW)
                    if cap.isOpened():
                        ret = cap.read()[0]
                        if ret:
                            available_cameras.append(i)
                            logging.info(f"Found camera at index {i} using DSHOW backend")
                        else:
                            logging.debug(f"Camera at index {i} (DSHOW) opened but failed to read frame")
                        cap.release()
                except:
                    # DSHOW backend not available (e.g., on Linux)
                    logging.debug(f"DSHOW backend not available for camera index {i}")
        except Exception as e:
            logging.warning(f"Error accessing camera index {i}: {e}")
    return available_cameras


def select_camera_interactive():
    """
    Interactively select a camera with proper display and quit functionality
    
    Returns:
        int: Selected camera index or None if no camera is selected
    """
    camera_list = find_available_cameras()
    
    if not camera_list:
        logging.warning("No cameras found!")
        print("No cameras found!")
        return None
    
    print("Available cameras:")
    for i, camera in enumerate(camera_list):
        print(f"{i+1}. Camera {camera}")
    
    try:
        selected_idx = int(input(f"Select a camera (1-{len(camera_list)}): ")) - 1
        if selected_idx < 0 or selected_idx >= len(camera_list):
            logging.warning("Invalid camera selection!")
            print("Invalid selection!")
            return None
    except ValueError:
        logging.warning("Invalid input for camera selection!")
        print("Invalid input! Please enter a number.")
        return None
    
    selected_camera_idx = camera_list[selected_idx]
    
    # Open the selected camera
    cap = cv.VideoCapture(selected_camera_idx)
    
    if not cap.isOpened():
        logging.error(f"Could not open camera {selected_camera_idx}")
        print(f"Error: Could not open camera {selected_camera_idx}")
        return None
    
    logging.info(f"Successfully opened camera {selected_camera_idx}")
    print(f"Opened camera {selected_camera_idx}. Press 'q' to confirm or 'ESC' to cancel...")
    
    # Display the live video stream with proper text overlay
    try:
        while True:
            ret, frame = cap.read()
            if not ret:
                logging.error("Error reading frame from camera!")
                print("Error reading frame!")
                break

            # Resize the frame to 800x600 if needed
            if frame.shape[1] != 800 or frame.shape[0] != 600:
                frame = cv.resize(frame, (800, 600))

            # Display text in the top left corner with better visibility
            text = "Press 'q' to confirm this camera, 'ESC' to cancel"
            org = (10, 30)  # Changed position to top-left for better visibility
            font = cv.FONT_HERSHEY_SIMPLEX
            font_scale = 0.7
            color = (0, 255, 0)  # Changed to green for better contrast
            thickness = 2
            cv.putText(frame, text, org, font, font_scale, color, thickness, cv.LINE_AA)

            # Display help text
            help_text = "Controls: 'q' = confirm, 'ESC' = cancel"
            org_help = (10, 60)  # Position below the main text
            cv.putText(frame, help_text, org_help, font, font_scale * 0.6, (255, 255, 255), 1, cv.LINE_AA)

            # Display the frame
            cv.imshow('Camera Selection - Comparatron', frame)

            # Wait for user input (q to confirm, ESC to cancel)
            key = cv.waitKey(1) & 0xFF
            if key == ord('q') or key == ord('Q'):
                logging.info(f"Camera {selected_camera_idx} selected and confirmed!")
                print(f"Camera {selected_camera_idx} selected and confirmed!")
                break
            elif key == 27:  # ESC key
                logging.info("Camera selection cancelled by user.")
                print("Camera selection cancelled.")
                selected_camera_idx = None
                break
    except KeyboardInterrupt:
        logging.info("Camera selection interrupted by user.")
        print("\nCamera selection interrupted.")
        selected_camera_idx = None
    finally:
        # Release the camera and close the window
        cap.release()
        cv.destroyAllWindows()
    
    return selected_camera_idx


def initialize_camera(camera_index):
    """
    Initialize and return a camera object for the given index
    
    Args:
        camera_index (int): Camera index to initialize
    
    Returns:
        VideoCapture: OpenCV VideoCapture object or None if failed
    """
    cap = cv.VideoCapture(camera_index)
    if cap.isOpened():
        return cap
    else:
        print(f"Failed to initialize camera {camera_index}")
        return None


if __name__ == "__main__":
    # Test the camera selection functionality
    selected_cam = select_camera_interactive()
    if selected_cam is not None:
        print(f"Successfully selected camera: {selected_cam}")
    else:
        print("No camera selected")