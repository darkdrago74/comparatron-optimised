"""
DXF Handling Module for Comparatron
Handles creation and export of DXF files
"""

import ezdxf
import logging

# Set up logging
logging.basicConfig(level=logging.INFO, format='%(asctime)s - %(levelname)s - %(message)s')


class DXFHandler:
    """
    Class to handle DXF file creation and export
    """
    
    def __init__(self, dxf_version="R2010"):
        """
        Initialize DXF handler with a new drawing
        
        Args:
            dxf_version (str): DXF version to use
        """
        self.doc = ezdxf.new(dxfversion=dxf_version)
        self.doc.layers.new(name="COMPARATRON_OUTPUT", dxfattribs={"color": 2})
        self.msp = self.doc.modelspace()
        self.points = []
    
    def add_point(self, x, y, layer="COMPARATRON_OUTPUT"):
        """
        Add a point to the DXF drawing
        
        Args:
            x (float): X coordinate
            y (float): Y coordinate
            layer (str): Layer name for the point
        """
        try:
            point = self.msp.add_point((x, y), dxfattribs={"color": 7, "layer": layer})
            self.points.append({"x": x, "y": y, "entity": point})
            return True
        except Exception as e:
            print(f"Error adding point ({x}, {y}): {e}")
            return False
    
    def add_points_from_list(self, points_list):
        """
        Add multiple points from a list of (x, y) tuples
        
        Args:
            points_list (list): List of (x, y) tuples
        """
        success_count = 0
        for x, y in points_list:
            if self.add_point(x, y):
                success_count += 1
        return success_count
    
    def get_point_count(self):
        """
        Get the number of points in the drawing
        
        Returns:
            int: Number of points
        """
        return len(self.points)
    
    def get_points(self):
        """
        Get all points in the drawing
        
        Returns:
            list: List of point dictionaries
        """
        return self.points.copy()
    
    def clear_points(self):
        """
        Clear all points from the drawing
        """
        # In ezdxf, we can't easily remove entities after they're added,
        # so we create a new document instead
        self.__init__(dxf_version=self.doc.dxfversion)
    
    def export_dxf(self, filename):
        """
        Export the DXF drawing to a file
        
        Args:
            filename (str): Path to save the DXF file
            
        Returns:
            bool: True if export successful, False otherwise
        """
        try:
            self.doc.saveas(filename)
            print(f"DXF exported to: {filename}")
            return True
        except Exception as e:
            print(f"Error exporting DXF to {filename}: {e}")
            return False
    
    def get_bounds(self):
        """
        Get the bounding box of all points
        
        Returns:
            dict: Dictionary with min_x, min_y, max_x, max_y values
        """
        if not self.points:
            return {"min_x": 0, "min_y": 0, "max_x": 0, "max_y": 0}
        
        x_coords = [p["x"] for p in self.points]
        y_coords = [p["y"] for p in self.points]
        
        return {
            "min_x": min(x_coords),
            "min_y": min(y_coords),
            "max_x": max(x_coords),
            "max_y": max(y_coords)
        }


if __name__ == "__main__":
    # Test the DXFHandler class
    dxf_handler = DXFHandler()
    
    # Add some test points
    dxf_handler.add_point(0, 0)
    dxf_handler.add_point(10, 10)
    dxf_handler.add_point(20, 5)
    
    print(f"Added {dxf_handler.get_point_count()} points")
    print(f"Points: {dxf_handler.get_points()}")
    
    bounds = dxf_handler.get_bounds()
    print(f"Bounds: {bounds}")
    
    # Export to a test file (commented out to avoid creating files during testing)
    # dxf_handler.export_dxf("test_output.dxf")