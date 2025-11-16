# Comparatron Machine Calibration Guide

## Overview

This document describes the calibration procedures for the Comparatron optical comparator to compensate for mechanical inaccuracies and maintain precision in measurements.

## Types of Calibration Required

### 1. Step/mm Calibration
- Adjust the number of steps per millimeter on X and Y axes
- Compensate for belt stretch, gear ratios, and mechanical wear

### 2. Squareness Calibration
- Measure and compensate for deviation from 90° between X and Y axes
- Correct for mechanical misalignment

### 3. Orthogonality Compensation
- Measure deviation when moving one axis while the other remains stationary
- Apply corrections to coordinate system

## Required Calibration Items

### Physical References
- Precision square (90° reference)
- Calibrated measuring squares of known dimensions (e.g., 100x100mm, 50x50mm)
- Precision ruler or linear scale (optional for verification)

## Calibration Procedures

### Step 1: Step/mm Calibration (X and Y axes separately)

**Requirements:**
- Known reference measurement (calibrated square or ruler)
- Ability to mark precise positions

**Procedure:**
1. Home the machine: `$H`
2. Move to a known reference point (e.g., corner of calibration square)
3. Mark current position on work surface
4. Command a known move: `G21 G91 G0 X100` (moves 100mm in X direction)
5. Mark the ending position
6. Physically measure the distance traveled using calibrated ruler
7. Calculate actual steps/mm using formula:
   ```
   New_steps_mm = Old_steps_mm * (Commanded_distance / Measured_distance)
   ```
8. Update GRBL settings:
   - For X axis: `$100=value` 
   - For Y axis: `$101=value`
   - For Z axis: `$102=value` (if applicable)

9. Repeat for both X and Y axes with multiple distances for accuracy

### Step 2: Squareness/Orthogonality Calibration

**Requirements:**
- Precision 90° reference square OR ability to measure orthogonality through motion

**Method 1: Using Precision Square Reference**
1. Place precision square on machine table aligned with X/Y axes
2. Use camera to capture image of square corner
3. Mark three points: corner (X1, Y1), point along X-axis (X2, Y1), point along Y-axis (X1, Y2)
4. Calculate the angle using the formula:
   ```
   angle = arccos( (dot_product_of_vectors) / (magnitude_vector1 * magnitude_vector2) )
   ```
   Or simpler using tangent:
   ```
   angle = arctan2(|Y2-Y1|, |X2-X1|) * (180/π)
   ```
   For a perfect square, this should equal 90°
5. Squareness error = Measured_angle - 90°

**Method 2: Motion-Based Orthogonality Measurement**
1. Home the machine: `$H`
2. Position camera and mark starting position (X1, Y1)
3. Move Y-axis only: `G91 G0 Y100` (move 100mm in Y direction)
4. Mark ending position (X2, Y2) - this should have same X coordinate if Y-axis is perfectly orthogonal
5. Move back to origin: `G90 G0 X(X1) Y(Y1)`
6. Move X-axis only: `G91 G0 X100` (move 100mm in X direction)
7. Mark ending position (X3, Y3) - this should have same Y coordinate if X-axis is perfectly orthogonal
8. Calculate orthogonality/squareness error:
   ```
   Deviation_when_moving_Y = |X2 - X1|  # This measures X-drift when moving Y
   Deviation_when_moving_X = |Y3 - Y1|  # This measures Y-drift when moving X

   Angular_error_X = arctan(Deviation_when_moving_Y / 100) * (180/π) degrees
   Angular_error_Y = arctan(Deviation_when_moving_X / 100) * (180/π) degrees
   ```

Both methods measure the same fundamental property - whether the axes are perpendicular to each other.

## Coordinate System Compensation Methods

### Method 1: Software Compensation (Recommended)

Store calibration coefficients in a configuration file that adjusts coordinates during measurement:

```python
# Configuration would store values like:
calibration_factors = {
    'steps_per_mm_x': 80.00,      # Adjusted through step calibration
    'steps_per_mm_y': 80.00,      # Adjusted through step calibration  
    'squareness_error': 0.001,    # Radians of deviation from 90°
    'orthogonality_x_compensation': 0.00,  # mm offset when moving in Y
    'orthogonality_y_compensation': 0.00   # mm offset when moving in X
}
```

### Method 2: Mathematical Correction

Apply corrections during coordinate conversion:

For a measured point (xm, ym), corrected coordinates (xc, yc) are calculated as:

```
xc = xm + compensation_function_x(xm, ym)
yc = ym + compensation_function_y(xm, ym)
```

Where compensation functions use the calibrated parameters to adjust for:
- Step/mm discrepancies
- Squareness errors
- Orthogonality deviations

## GRBL Capabilities

### Built-in Compensation
GRBL does not have built-in squareness compensation as of version 1.1h. However, it supports:

- Axis steps per unit adjustments ($100, $101, $102)
- Backlash compensation ($110, $111, $112) - for systems with backlash
- Junction deviation ($108) - affects curve following
- Arc tolerance ($109) - affects arc accuracy

### Workaround Solutions
Since GRBL doesn't directly support squareness compensation, the compensation must be applied in the controller software (in Comparatron's case, in the Python code) before sending coordinates to GRBL or after receiving feedback from measurements.

## Storage Format for Calibration Data

Calibration data should be stored in a JSON configuration file:

```json
{
  "calibration_timestamp": "2025-01-14T12:00:00Z",
  "axes_calibration": {
    "x": {
      "steps_per_mm": 80.00,
      "laser_offset_mm": 0.0,
      "calibration_reference": "100mm gauge block"
    },
    "y": {
      "steps_per_mm": 80.00,
      "laser_offset_mm": 0.0,
      "calibration_reference": "100mm gauge block"
    },
    "z": {
      "steps_per_mm": 2560.00,
      "calibration_reference": "thread pitch"
    }
  },
  "geometric_calibration": {
    "squareness_error_degrees": 0.000,  // Deviation from 90° between X and Y axes
    "squareness_measurement_distance": 100.0, // Distance used for measurement (mm)
    "reference_tool_used": "precision 90-degree square"
  },
  "measurement_accuracy": {
    "repeatability_x": 0.01,  // mm, 3-sigma
    "repeatability_y": 0.01,  // mm, 3-sigma
    "linearity_x": 0.02,      // mm over full travel
    "linearity_y": 0.02       // mm over full travel
  },
  "calibration_procedure_version": "1.0"
}
```

## Software Integration

### Coordinate Transformation Functions

```python
import math

def apply_coordinate_correction(x_raw, y_raw, calibration_data):
    """
    Apply geometric corrections to raw coordinates
    """
    # Apply squareness/orthogonality compensation
    # If axes are not perfectly orthogonal, we get a skew matrix transformation
    squareness_error_degrees = calibration_data['geometric_calibration']['squareness_error_degrees']
    squareness_rad = math.radians(squareness_error_degrees)

    # For small angles, tan(squareness_error) ≈ squareness_error (in radians)
    # The transformation accounts for the deviation from 90° between axes
    # If axis X is tilted by angle α from true perpendicular to Y-axis:
    # X_corrected = X_raw + Y_raw * sin(α) ≈ X_raw + Y_raw * α (for small α)
    # Y_corrected = Y_raw (assuming Y-axis is reference)

    # For symmetric squareness error where both axes might be tilted:
    # We use half the total angular error for each axis correction
    half_squareness_rad = squareness_rad / 2.0

    x_corrected = x_raw + y_raw * math.tan(half_squareness_rad)  # Correct X-axis tilt
    y_corrected = y_raw + x_raw * math.tan(half_squareness_rad)  # Correct Y-axis tilt

    return x_corrected, y_corrected

def record_calibrated_point(x_pixel, y_pixel, calibration_data):
    """
    Convert pixel coordinates to calibrated machine coordinates
    """
    # Convert from pixels to machine units using calibrated steps_per_mm
    x_raw = x_pixel / calibration_data['axes_calibration']['x']['steps_per_mm']
    y_raw = y_pixel / calibration_data['axes_calibration']['y']['steps_per_mm']
    
    # Apply geometric corrections
    x_final, y_final = apply_coordinate_correction(x_raw, y_raw, calibration_data)
    
    return x_final, y_final
```

## Verification Process

After applying calibrations:

1. Measure known dimensions with calibrated machine
2. Compare against reference measurements
3. Document accuracy improvements
4. Store verification results in calibration file

**Verification of Squareness Correction:**
- Use a calibrated square to check 90° angles
- Measure diagonal of a square drawn on the machine to verify consistent measurements
- Measure multiple rectangles/squares at different positions to ensure calibration is uniform

## Recommended Calibration Schedule

- **Initial Setup**: Full calibration when first setting up
- **Monthly**: Check step calibration with known reference
- **Quarterly**: Full geometric calibration if precision requirements demand it
- **After Moving**: Recalibrate if machine frame subjected to stress or transport
- **After Maintenance**: Recalibrate if belts, pulleys, or mechanical components adjusted

## Safety Considerations

- Limit speeds during calibration moves if testing accuracy at high speeds
- Ensure work area is clear before automated moves
- Use appropriate safety features (limits, homing switches) during calibration moves