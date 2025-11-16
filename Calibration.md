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

### Step 2: Squareness Calibration

**Requirements:**
- Precision 90° reference square
- Ability to take measurements at multiple positions

**Procedure:**
1. Place precision square on machine table aligned with X/Y axes
2. Use camera to capture image of square corner
3. Mark two points along X-direction edge of the square: (X1, Y1) and (X2, Y1)
4. Mark two points along Y-direction edge of the square: (X1, Y1) and (X1, Y2)
5. Calculate the angle deviation using the formula:
   ```
   angle = arctan(|ΔY| / |ΔX|) * (180/π)
   ```
   Where (X1,Y1) is the corner, (X2,Y1) is second X point, (X1,Y2) is second Y point

6. If angle ≠ 90°, calculate squareness error:
   ```
   Squareness_error = Angle - 90°
   ```

### Step 3: Orthogonality Measurement

**Requirements:**
- Machine movement capabilities
- Camera positioning

**Procedure:**
1. Home the machine: `$H`
2. Position camera at (X1, Y1)
3. Take measurement point
4. Move Y-axis only: `G91 G0 Y50` (move 50mm in Y direction)
5. Take second measurement point (X2, Y2)
6. Move X-axis only (relative to starting position): `G90 G0 X(X1+50) Y(Y1)`
7. Take third measurement point (X3, Y3)
8. Calculate the deviation from orthogonality:
   ```
   Deviation_X = |X2 - X1|
   Deviation_Y = |Y3 - Y1|
   ```

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
    "squareness_error_degrees": 0.000,
    "squareness_measurement_distance": 100.0, // mm used for measurement
    "orthogonality_x_on_y": 0.000, // mm deviation in X when moving Y
    "orthogonality_y_on_x": 0.000, // mm deviation in Y when moving X
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
    # Apply squareness compensation
    squareness_rad = math.radians(calibration_data['geometric_calibration']['squareness_error_degrees'])
    
    # Orthogonality compensation
    ortho_x_on_y = calibration_data['geometric_calibration']['orthogonality_x_on_y']
    ortho_y_on_x = calibration_data['geometric_calibration']['orthogonality_y_on_x']
    
    # Calculate corrected coordinates
    x_corrected = x_raw + (y_raw * math.tan(squareness_rad)) + (y_raw * ortho_x_on_y)
    y_corrected = y_raw + (x_raw * ortho_y_on_x)
    
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