%% Smart Bra Pressure Experiment: Grid Tracking -> Deformation Map (FRAME-TO-FRAME)
clear; clc; close all;

%% ---------------- USER SETTINGS ----------------
videoFile   = 'largeSmoothOn.MOV';
outVideo1   = 'tracked_points_overlay_revised_smoothOn2.mp4';
outVideo2   = 'deformation_heatmap_revised_smoothOn2.mp4';

% Tracking params
maxBidirectionalError = 3.0;   % less strict -> fewer dropouts
numPyramidLevels = 5;          % better for larger motion

% Detection params
maxInitPts   = 30000;
cellSizePx   = 25;             % denser spatial sampling
ptsPerCell   = 3;              % more points per cell
minQuality   = 0.003;
borderMargin = 10;             % avoid points too close to ROI edge

% Heatmap params
heatmapGridSize = [250 250];   % denser heatmap
smoothSigma     = 0.0;         % no smoothing for debugging/localization

% Analysis window
maxFrames = inf;

% Debug options
showInitialPoints = true;
showLostPointsDebug = false;   % set true if you want green/red debug frames

%% ---------------- READ VIDEO ----------------
v = VideoReader(videoFile);
fps = v.FrameRate;

frame1 = readFrame(v);

%% ---------------- SELECT ROI ----------------
figure; imshow(frame1);
title('Draw ROI around grid (double-click to confirm)');
h = drawrectangle('Color','y');
wait(h);
roi = round(h.Position);   % [x y w h]
close;

frame1_roi = imcrop(frame1, roi);
gray1_roi  = rgb2gray(frame1_roi);

% Contrast enhancement helps weaker regions
gray1_eq = adapthisteq(gray1_roi);

%% ---------------- DETECT FEATURES UNIFORMLY ----------------
corners = detectMinEigenFeatures(gray1_eq, 'MinQuality', minQuality);
corners = corners.selectStrongest(maxInitPts);

pts = selectPointsPerCell(corners, size(gray1_roi), cellSizePx, ptsPerCell);

% Remove points too close to ROI border
pts = filterBorderPoints(pts, size(gray1_roi), borderMargin);

fprintf('Initial candidate points: %d\n', corners.Count);
fprintf('After cell selection + border filter: %d\n', size(pts,1));

if showInitialPoints
    figure; imshow(frame1_roi); hold on;
    plot(pts(:,1), pts(:,2), 'go', 'MarkerSize', 5, 'LineWidth', 1);
    title(sprintf('Uniform selection: %d pt(s) per %d px cell', ptsPerCell, cellSizePx));
    hold off;
end

%% ---------------- INITIALIZE TRACKER ----------------
tracker = vision.PointTracker( ...
    'MaxBidirectionalError', maxBidirectionalError, ...
    'NumPyramidLevels', numPyramidLevels);

% Initialize tracker on equalized first frame
initialize(tracker, pts, gray1_eq);

%% ---------------- OUTPUT VIDEO WRITERS ----------------
vw1 = VideoWriter(outVideo1, 'MPEG-4');
vw1.FrameRate = fps;
open(vw1);

vw2 = VideoWriter(outVideo2, 'MPEG-4');
vw2.FrameRate = fps;
open(vw2);

%% ---------------- STORAGE ----------------
frameCount = 0;
medianDisp = [];

% For frame-to-frame motion
prevPtsAll = [];
prevValidAll = [];

%% ---------------- MAIN LOOP ----------------
v = VideoReader(videoFile);

while hasFrame(v) && frameCount < maxFrames
    frame = readFrame(v);
    frameCount = frameCount + 1;

    % Crop to ROI
    frame_roi = imcrop(frame, roi);

    % Track on equalized grayscale
    gray_roi = rgb2gray(frame_roi);
    gray_eq  = adapthisteq(gray_roi);

    % Track all original points in fixed order
    [trackedPtsAll, validAll] = step(tracker, gray_eq);

    % First frame: initialize previous-frame storage and skip heatmap
    if isempty(prevPtsAll)
        prevPtsAll = trackedPtsAll;
        prevValidAll = validAll;

        goodPts = trackedPtsAll(validAll, :);
        overlay = insertMarker(frame_roi, goodPts, 'o', ...
            'Color', 'green', 'Size', 3);
        overlay = insertText(overlay, [10 10], ...
            sprintf('Frame %d | initializing previous frame', frameCount), ...
            'FontSize', 18, 'BoxOpacity', 0.6);
        writeVideo(vw1, overlay);

        % Heatmap video must use ROI-sized frames consistently
        blankHeat = uint8(255 * ones(size(frame_roi,1), size(frame_roi,2), 3));
        writeVideo(vw2, blankHeat);

        medianDisp(end+1,1) = NaN;
        continue;
    end

    % Use only points valid in BOTH previous and current frame
    validBothPrev = validAll & prevValidAll;

    cur = trackedPtsAll(validBothPrev, :);
    prev = prevPtsAll(validBothPrev, :);

    if size(cur,1) < 4
        overlay = insertText(frame_roi, [10 10], ...
            sprintf('Frame %d | too few valid points', frameCount), ...
            'FontSize', 18, 'BoxOpacity', 0.6);
        writeVideo(vw1, overlay);

        % Heatmap video must use ROI-sized frames consistently
        blankHeat = uint8(255 * ones(size(frame_roi,1), size(frame_roi,2), 3));
        writeVideo(vw2, blankHeat);

        medianDisp(end+1,1) = NaN;

        % Still update previous frame storage
        prevPtsAll = trackedPtsAll;
        prevValidAll = validAll;
        continue;
    end

    %% --- Frame-to-frame displacement ---
    dxy = cur - prev;

    % Remove whole-frame drift
    globalShift = median(dxy, 1, 'omitnan');
    dxy = dxy - globalShift;

    dispMag = sqrt(sum(dxy.^2, 2));
    medianDisp(end+1,1) = median(dispMag, 'omitnan');

    fprintf('Frame %d: median = %.3f px, max = %.3f px\n', ...
        frameCount, medianDisp(end), max(dispMag));

    %% --- Build heatmap ---
    [heat, mask] = buildHeatmap(cur, dispMag, heatmapGridSize, size(gray_roi), smoothSigma);

    %% --- Overlay frame ---
    if showLostPointsDebug
        overlay = frame_roi;
        overlay = insertMarker(overlay, trackedPtsAll(validAll,:), 'o', ...
            'Color', 'green', 'Size', 3);
        overlay = insertMarker(overlay, trackedPtsAll(~validAll,:), 'o', ...
            'Color', 'red', 'Size', 3);
    else
        overlay = insertMarker(frame_roi, cur, 'o', ...
            'Color', 'green', 'Size', 3);
    end

    overlay = insertText(overlay, [10 10], ...
        sprintf('Frame %d | median disp = %.2f px | valid pts = %d', ...
        frameCount, medianDisp(end), size(cur,1)), ...
        'FontSize', 18, 'BoxOpacity', 0.6);

    writeVideo(vw1, overlay);

    %% --- Heatmap frame ---
    heatRGB = heatmapToRGBMasked(heat, mask);

    % Resize heatmap to ROI size so every vw2 frame matches
    heatRGB = imresize(heatRGB, [size(frame_roi,1), size(frame_roi,2)]);

    writeVideo(vw2, heatRGB);

    % Update previous-frame storage for next loop
    prevPtsAll = trackedPtsAll;
    prevValidAll = validAll;

    if mod(frameCount, 30) == 0
        fprintf('Processed frame %d | valid pts = %d\n', frameCount, size(cur,1));
    end
end

%% ---------------- WRAP UP ----------------
release(tracker);
close(vw1);
close(vw2);

fprintf('\nDone!\n');
fprintf('Overlay video: %s\n', outVideo1);
fprintf('Heatmap video: %s\n', outVideo2);

%% ---------------- PLOT ----------------
figure;
plot(medianDisp, 'LineWidth', 1.5);
xlabel('Frame');
ylabel('Median frame-to-frame displacement (px)');
title('Motion Over Time');
grid on;

%% =================== HELPER FUNCTIONS ===================

function ptsOut = selectPointsPerCell(corners, imgSize, cellSize, ptsPerCell)
% Select up to ptsPerCell strongest points from each cell

    pts = corners.Location;
    metric = corners.Metric;

    H = imgSize(1);
    W = imgSize(2);

    nRows = ceil(H / cellSize);
    nCols = ceil(W / cellSize);

    ptsOut = zeros(0,2);

    for r = 1:nRows
        yMin = (r-1)*cellSize + 1;
        yMax = min(r*cellSize, H);

        for c = 1:nCols
            xMin = (c-1)*cellSize + 1;
            xMax = min(c*cellSize, W);

            inCell = pts(:,1) >= xMin & pts(:,1) <= xMax & ...
                     pts(:,2) >= yMin & pts(:,2) <= yMax;

            if any(inCell)
                cellPts = pts(inCell, :);
                cellMetric = metric(inCell);

                [~, order] = sort(cellMetric, 'descend');
                k = min(ptsPerCell, numel(order));

                ptsOut = [ptsOut; cellPts(order(1:k), :)];
            end
        end
    end
end

function ptsOut = filterBorderPoints(ptsIn, imgSize, borderMargin)
% Remove points too close to image border

    H = imgSize(1);
    W = imgSize(2);

    keep = ptsIn(:,1) > borderMargin & ptsIn(:,1) < (W - borderMargin) & ...
           ptsIn(:,2) > borderMargin & ptsIn(:,2) < (H - borderMargin);

    ptsOut = ptsIn(keep, :);
end

function [heat, mask] = buildHeatmap(xy, val, gridSize, imgSize, smoothSigma)
% Interpolates tracked values to regular ROI grid

    Himg = imgSize(1);
    Wimg = imgSize(2);

    H = gridSize(1);
    W = gridSize(2);

    x = double(xy(:,1));
    y = double(xy(:,2));
    val = double(val);

    xq = linspace(1, Wimg, W);
    yq = linspace(1, Himg, H);
    [Xq, Yq] = meshgrid(xq, yq);

    F = scatteredInterpolant(x, y, val, 'natural', 'none');
    heat = F(Xq, Yq);

    mask = ~isnan(heat);

    if any(~mask, 'all')
        Ffill = scatteredInterpolant(x, y, val, 'nearest', 'nearest');
        heatFilled = Ffill(Xq, Yq);
        heat(~mask) = heatFilled(~mask);
    end

    if smoothSigma > 0
        heat = imgaussfilt(heat, smoothSigma);
    end
end

function rgb = heatmapToRGBMasked(heat, mask)
% Convert heatmap to RGB using a fixed scale and guaranteed uint8 HxWx3 output

    maxDispForColor = 3;   % pixels; adjust if needed

    % Clean up any NaNs/Infs just in case
    heat(~isfinite(heat)) = 0;

    % Clip to fixed display range
    heatClipped = min(max(heat, 0), maxDispForColor);
    heatNorm = heatClipped / maxDispForColor;

    % Convert to colormap indices
    idx = round(heatNorm * 255) + 1;
    idx = max(1, min(256, idx));

    cmap = parula(256);

    % Build RGB explicitly
    rgb = uint8(zeros(size(idx,1), size(idx,2), 3));
    for c = 1:3
        channel = cmap(idx, c);
        channel = reshape(channel, size(idx,1), size(idx,2));
        rgb(:,:,c) = uint8(255 * channel);
    end

    % Resize mask if needed
    if ~isequal(size(mask), [size(rgb,1), size(rgb,2)])
        mask = imresize(mask, [size(rgb,1), size(rgb,2)], 'nearest');
    end
    mask = logical(mask);

    % Fade unsupported zones toward white
    for c = 1:3
        channel = double(rgb(:,:,c));
        channel(~mask) = 0.65 * channel(~mask) + 0.35 * 255;
        rgb(:,:,c) = uint8(channel);
    end
end
