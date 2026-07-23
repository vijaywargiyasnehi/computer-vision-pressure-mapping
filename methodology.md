# Methodology

## 1. Experimental input

The workflow analyzes a video containing a visible grid or textured pattern on the fabric region of interest. The grid provides trackable visual features whose motion acts as a proxy for local fabric deformation.

## 2. Frame labeling

`frameOverlay.m` reads the input video sequentially and adds a visible frame number to each image. Optional labels are placed on the left and right halves of a side-by-side recording. The output retains the source video's frame rate.

This step supports alignment between:

- Video observations
- Manual experimental notes
- Caliper or displacement readings
- Algorithmic detection results

## 3. Region-of-interest selection

Both analysis scripts display the first frame and ask the user to draw a rectangular region around the grid. Processing is then restricted to this region.

## 4. Image preprocessing

Each cropped frame is converted to grayscale. Adaptive histogram equalization is applied to increase local contrast and improve detection in weak or unevenly illuminated areas.

## 5. Feature selection

Minimum-eigenvalue corner features are detected in the first processed frame. To avoid concentrating points in only the highest-contrast region, the image is divided into spatial cells and a limited number of strong points is selected from each cell. Points near the ROI border are removed.

## 6. Point tracking

A bidirectional point tracker estimates the location of each initialized point in subsequent frames. Only points valid in both the current and previous frame are used for frame-to-frame displacement calculations.

## 7. Drift correction

For each tracked point:

```text
displacement vector = current point − previous point
```

The median displacement vector across all valid points is treated as global frame drift and subtracted from each point's displacement vector. This reduces the effect of small camera translations.

## 8. Deformation magnitude

The displacement magnitude for each point is calculated as:

```text
magnitude = sqrt(dx² + dy²)
```

`NEWdeformationHeatmap.m` records the median displacement magnitude for each frame and uses all valid point magnitudes to construct a spatial deformation map.

## 9. Heatmap interpolation

Tracked displacement values are interpolated onto a regular grid using natural-neighbor interpolation. Unsupported areas are filled using nearest-neighbor interpolation and visually faded. The resulting values are mapped to a fixed color scale and written to a video.

## 10. Minimum reliable motion detection

`minDetectionNew.m` uses the first portion of the video as a no-touch baseline. For each frame, the analysis metric is the 95th percentile of drift-corrected point displacement magnitudes.

The detection threshold is:

```text
threshold = baseline mean + kSigma × baseline standard deviation
```

A movement is declared reliable only when the metric remains above the threshold for a configured number of consecutive frames. This reduces sensitivity to isolated noisy frames.

## 11. Interpretation

The current scripts measure visible displacement in image pixels. Translating these values into millimeters requires a spatial calibration object or known grid spacing in the same imaging plane.

The heatmap represents localized image motion and should be described as a fabric-deformation or displacement map. A direct pressure estimate would require calibration against a known pressure measurement system.

## 12. Validation opportunities

A stronger validation study could include:

- Synthetic image translations with known pixel displacement
- Repeated no-touch recordings to characterize false-positive rates
- Known physical displacements applied continuously rather than in jumps
- Multiple lighting and camera-angle conditions
- Comparison with pressure sensors or mechanical testing equipment
- Measurement of tracking error and point-retention rate
