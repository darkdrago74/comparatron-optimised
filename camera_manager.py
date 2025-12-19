"""
Camera Management Module for Comparatron
Handles camera selection, initialization, and video capture
"""

import cv2 as cv
import numpy as np
import logging
import os

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


def find_available_cameras(max_cameras=20):
    """
    Find only cameras that are both physically present AND accessible.
    This uses a more efficient approach focusing on speed and reducing errors.
    Only returns cameras that can be opened AND provide valid frames.

    Args:
        max_cameras (int): Maximum number of camera indices to check

    Returns:
        list: List of available camera indices that are both present AND accessible
    """
    import os
    import threading
    import time
    available_cameras = []

    # First, check which video devices exist at the system level
    existing_video_devices = []
    for i in range(max_cameras):
        if os.path.exists(f"/dev/video{i}"):
            existing_video_devices.append(i)

    logging.info(f"Found {len(existing_video_devices)} video devices: {existing_video_devices}")

    # Test each device efficiently with timeout to avoid hanging on problematic cameras
    for i in existing_video_devices:
        # Try multiple backends to increase success rate
        backends = [cv.CAP_V4L2, cv.CAP_GSTREAMER, cv.CAP_FFMPEG]  # V4L2 first as it's most common for USB cameras
        backends.append(None)  # Finally try default backend

        for backend in backends:
            try:
                if backend is not None:
                    cap = cv.VideoCapture(i, backend)
                else:
                    cap = cv.VideoCapture(i)  # Default backend

                if cap.isOpened():
                    # Set optimal properties for faster initialization
                    cap.set(cv.CAP_PROP_BUFFERSIZE, 1)
                    cap.set(cv.CAP_PROP_FRAME_WIDTH, 640)
                    cap.set(cv.CAP_PROP_FRAME_HEIGHT, 480)
                    cap.set(cv.CAP_PROP_FPS, 30)

                    # Wait briefly for camera to initialize
                    time.sleep(0.1)

                    # Try to read a frame to verify it's working
                    ret, frame = cap.read()
                    if ret and frame is not None and frame.size > 0:
                        # Double check by trying to read another frame
                        ret2, frame2 = cap.read()
                        if ret2 and frame2 is not None and frame2.size > 0:
                            if i not in available_cameras:  # Avoid duplicates
                                available_cameras.append(i)
                                logging.info(f"Confirmed working camera at index {i} with backend {backend}")
                            break  # Exit the backend loop if successful
                    cap.release()

            except Exception as e:
                logging.debug(f"Error testing camera {i} with backend {backend}: {e}")
                try:
                    cap.release()
                except:
                    pass

    logging.info(f"Final working cameras found: {len(available_cameras)} - {available_cameras}")
    return available_cameras


def refresh_camera_detection(max_cameras=20):
    """
    Refresh camera detection by re-scanning for newly connected cameras.
    This function forces a re-detection of cameras which might help with
    hot-plugged cameras that weren't detected originally.

    Args:
        max_cameras (int): Maximum number of camera indices to check

    Returns:
        list: List of newly detected camera indices
    """
    import os
    import time
    import cv2 as cv

    working_cameras = []

    # Check for video devices that exist
    for i in range(max_cameras):
        if os.path.exists(f"/dev/video{i}"):
            # Test if this camera is actually working
            backends = [cv.CAP_V4L2, cv.CAP_GSTREAMER, cv.CAP_FFMPEG, None]  # Default as last resort

            for backend in backends:
                try:
                    if backend is not None:
                        cap = cv.VideoCapture(i, backend)
                    else:
                        cap = cv.VideoCapture(i)  # Default backend

                    if cap.isOpened():
                        # Set optimal properties for faster initialization
                        cap.set(cv.CAP_PROP_BUFFERSIZE, 1)
                        time.sleep(0.1)  # Brief wait for initialization

                        # Try to read a frame to verify it's working
                        ret, frame = cap.read()
                        if ret and frame is not None and frame.size > 0:
                            # Double check with another read
                            ret2, frame2 = cap.read()
                            if ret2 and frame2 is not None and frame2.size > 0:
                                if i not in working_cameras:  # Avoid duplicates
                                    working_cameras.append(i)
                                cap.release()
                                break  # Break if successful
                        cap.release()

                except Exception:
                    try:
                        cap.release()
                    except:
                        pass

    logging.info(f"Newly detected cameras after refresh: {working_cameras}")
    return working_cameras


def test_camera_connection(camera_index):
    """
    Test if a specific camera index is accessible and working
    
    Args:
        camera_index (int): Camera index to test
    
    Returns:
        tuple: (bool: connection_success, str: status_message)
    """
    try:
        # Try with V4L2 backend first (recommended for Linux USB cameras)
        cap = cv.VideoCapture(camera_index, cv.CAP_V4L2)
        cap.set(cv.CAP_PROP_BUFFERSIZE, 1)  # Reduce buffering for faster response
        
        if cap.isOpened():
            # Wait briefly for camera to initialize
            import time
            time.sleep(0.05)  # Reduced sleep time for faster response
            
            # Try to read a frame to test if it's really working
            ret, frame = cap.read()
            cap.release()
            
            if ret and frame is not None and frame.size > 0:
                return True, f"Camera {camera_index} is working properly with V4L2 backend"
            else:
                return False, f"Camera {camera_index} opened with V4L2 but no valid frames returned"
        else:
            cap.release()
            # Try default backend if V4L2 didn't work
            cap = cv.VideoCapture(camera_index)
            cap.set(cv.CAP_PROP_BUFFERSIZE, 1)  # Reduce buffering for faster response
            
            if cap.isOpened():
                import time
                time.sleep(0.05)  # Reduced sleep time for faster response
                ret, frame = cap.read()
                cap.release()
                if ret and frame is not None and frame.size > 0:
                    return True, f"Camera {camera_index} is working with default backend"
                else:
                    return False, f"Camera {camera_index} opened with default backend but no valid frames returned"
            else:
                return False, f"Cannot open camera at index {camera_index}"
                
    except Exception as e:
        logging.error(f"Error testing camera at index {camera_index}: {e}")
        try:
            cap.release()
        except:
            pass
        return False, f"Error accessing camera {camera_index}: {str(e)}"


def initialize_camera(camera_index):
    """
    Initialize and return a camera object for the given index
    
    Args:
        camera_index (int): Camera index to initialize
    
    Returns:
        VideoCapture: OpenCV VideoCapture object or None if failed
    """
    try:
        # Try with V4L2 backend first (recommended for USB cameras on Linux)
        cap = cv.VideoCapture(camera_index, cv.CAP_V4L2)
        
        if cap.isOpened():
            # Try to read a frame to verify it works
            ret, frame = cap.read()
            if ret and frame is not None and frame.size > 0:
                logging.info(f"Successfully initialized camera {camera_index} using V4L2 backend")
                return cap
            else:
                # V4L2 didn't work, try default backend
                cap.release()
                cap = cv.VideoCapture(camera_index)
                if cap.isOpened():
                    ret, frame = cap.read()
                    if ret and frame is not None and frame.size > 0:
                        logging.info(f"Successfully initialized camera {camera_index} using default backend")
                        return cap
                    else:
                        cap.release()
                        logging.warning(f"Camera {camera_index} opened but failed to read frame with default backend")
                        return None
                else:
                    logging.warning(f"Failed to open camera {camera_index} with default backend")
                    return None
        else:
            # V4L2 didn't work, try default
            cap = cv.VideoCapture(camera_index)
            if cap.isOpened():
                ret, frame = cap.read()
                if ret and frame is not None and frame.size > 0:
                    logging.info(f"Successfully initialized camera {camera_index} using default backend")
                    return cap
                else:
                    cap.release()
                    logging.warning(f"Camera {camera_index} opened but failed to read frame")
                    return None
            else:
                logging.warning(f"Failed to open camera {camera_index}")
                return None
    except Exception as e:
        logging.error(f"Error initializing camera {camera_index}: {e}")
        try:
            cap.release()
        except:
            pass
        return None


if __name__ == "__main__":
    # Test the camera selection functionality
    print("Testing camera detection...")
    cameras = find_available_cameras(20)
    print(f"Available cameras: {cameras}")
    
    if cameras:
        for camera in cameras:
            print(f"Testing camera {camera}...")
            success, msg = test_camera_connection(camera)
            print(f"  {msg}")
    else:
        print("No cameras detected")