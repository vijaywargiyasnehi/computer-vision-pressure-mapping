# Smart Bra Pressure and Fabric Deformation Analysis

A MATLAB-based computer-vision pipeline for tracking fabric-grid displacement, visualizing localized deformation, and estimating the minimum reliably detectable movement during smart-bra pressure experiments.

## Project overview

This repository organizes three analysis scripts into one experimental workflow:

```text
Experimental video
        ↓
Frame synchronization and labeling
        ↓
Feature-point detection and tracking
        ↓
Global camera-drift removal
        ↓
Frame-to-frame displacement measurement
        ↓
Deformation heatmap generation
        ↓
Minimum reliable motion detection
```

The project is intended as a research and prototyping tool for analyzing deformation in a marked fabric region. It has not been clinically validated and should not be interpreted as a medical diagnostic system.

## Repository structure

```text
smart-bra-pressure-mapping/
├── README.md
├── LICENSE
├── .gitignore
├── matlab/
│   ├── frameOverlay.m
│   ├── minDetectionNew.m
│   └── NEWdeformationHeatmap.m
├── docs/
│   └── methodology.md
└── sample-results/
    └── README.md
```

## MATLAB scripts

### `frameOverlay.m`

Adds frame numbers to an existing side-by-side video. Optional labels identify the left and right halves of the frame. This helps synchronize visual observations with displacement measurements and other experimental records.

### `NEWdeformationHeatmap.m`

Performs the main deformation analysis:

- Allows the user to select a region of interest around the grid.
- Enhances local contrast using adaptive histogram equalization.
- Detects strong image features across spatial cells.
- Tracks points with a bidirectional point tracker.
- Removes whole-frame drift using the median displacement vector.
- Calculates frame-to-frame displacement magnitude.
- Interpolates tracked displacement into a deformation heatmap.
- Exports a tracked-point overlay video and a heatmap video.
- Plots median displacement over time.

### `minDetectionNew.m`

Estimates the first reliably detected movement:

- Uses an initial no-touch period as the baseline.
- Computes the 95th-percentile point displacement for each frame.
- Defines a motion threshold as baseline mean plus a configurable number of standard deviations.
- Requires several consecutive frames above the threshold to reduce false detections.
- Saves the detection metrics and first reliable detection frame to a MAT file.

## Requirements

- MATLAB
- Computer Vision Toolbox
- Image Processing Toolbox

The scripts use functions including `VideoReader`, `VideoWriter`, `vision.PointTracker`, `detectMinEigenFeatures`, `adapthisteq`, `scatteredInterpolant`, and `insertText`.

## Getting started

1. Clone or download this repository.
2. Place your experimental videos in a local data folder.
3. Open the required script in MATLAB.
4. Update the filename variables under **USER SETTINGS**.
5. Run the script.
6. Draw a region of interest around the grid when prompted.

Example:

```matlab
videoFile = 'largeSmoothOn.MOV';
```

Input videos are not included in this repository because they may be large or contain experiment-specific data.

## Key configurable parameters

The scripts expose parameters for:

- Point-tracking error tolerance
- Pyramid levels
- Maximum detected features
- Spatial cell size
- Points retained per cell
- Minimum feature quality
- Heatmap resolution
- Baseline-frame count
- Statistical detection threshold
- Number of consecutive frames required for detection

These parameters should be calibrated for the camera, grid pattern, lighting conditions, motion scale, and experiment design.

## Recommended result figures

For a strong project presentation, add the following to `sample-results/`:

1. The selected fabric-grid region
2. Detected or tracked feature points
3. A representative deformation heatmap
4. The displacement-over-time graph
5. A short GIF or compressed video showing the tracking result

Then embed the images in this README, for example:

```markdown
![Tracked feature points](sample-results/tracked-points-example.png)
![Deformation heatmap](sample-results/deformation-heatmap-example.png)
```

## Current limitations

- The region of interest is selected manually.
- Displacement is reported in pixels unless an external spatial calibration is applied.
- Heatmap quality depends on feature density and tracking stability.
- Frame-to-frame displacement does not by itself provide cumulative deformation.
- Camera motion is approximated as a global median translation.
- The minimum physical displacement cannot be established precisely when the applied displacement occurs in discrete jumps.
- The present workflow does not directly estimate pressure; it measures visible fabric deformation that may be associated with applied loading.

## Potential extensions

- Add pixel-to-millimeter calibration.
- Calculate cumulative displacement relative to the first frame.
- Estimate local strain from the displacement field.
- Add confidence scores for tracked regions.
- Automatically detect the grid region.
- Compare deformation maps with external pressure-sensor measurements.
- Build a MATLAB App Designer interface.
- Port the workflow to Python and provide a Streamlit demonstration.

## Research relevance

This project demonstrates practical experience with:

- Biomedical and wearable-device image analysis
- Feature detection and optical tracking
- Motion-noise characterization
- Quantitative threshold selection
- Spatial interpolation
- Deformation visualization
- Reproducible experimental analysis

## License

This project is available under the MIT License. See `LICENSE`.
