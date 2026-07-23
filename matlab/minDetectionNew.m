%% Find first reliably detected motion from grid poking video
% frame 335 --> coresponds to 2.71 mm = 0.271 cm
% At frame 335: motion crossed threshold, AND stayed above it for 3 frames --> so MATLAB says: this is real movement
% We’re trying to measure the minimum detectable displacement, but the caliper
% is being moved in jumps rather than smoothly. 
% Because of that, when the algorithm first detects motion, 
% we don’t know the exact displacement at that moment—it could 
% be anywhere between 0 and 2.71mm.
% the good thing is the the matlab code is telling me that there is
% displacement the exact momentwe create displacement but the issue
clear; clc; close all;

%% ---------------- USER SETTINGS ----------------
videoFile = 'correct2.mp4';

% Tracking params
maxBidirectionalError = 3.0;
numPyramidLevels = 5;

% Detection params
maxInitPts   = 30000;
cellSizePx   = 25;
ptsPerCell   = 3;
minQuality   = 0.003;
borderMargin = 10;

% Analysis params
maxFrames = inf;

% Baseline and detection settings
baselineFrames = 60;      % no-touch baseline at start
kSigma = 3;               % threshold = mean + kSigma*std (99.7%) --> “what level is too big to be noise?”
nConsecutive = 3;         % require this many consecutive frames above threshold

%% ---------------- READ FIRST FRAME ----------------
v = VideoReader(videoFile);
fps = v.FrameRate;
frame1 = readFrame(v);

%% ---------------- SELECT ROI ----------------
figure; imshow(frame1);
title('Draw ROI around grid (double-click to confirm)');
h = drawrectangle('Color','y');
wait(h);
roi = round(h.Position);
close;

frame1_roi = imcrop(frame1, roi);
gray1_roi  = rgb2gray(frame1_roi);
gray1_eq   = adapthisteq(gray1_roi);

%% ---------------- DETECT FEATURES ----------------
corners = detectMinEigenFeatures(gray1_eq, 'MinQuality', minQuality);
corners = corners.selectStrongest(maxInitPts);

pts = selectPointsPerCell(corners, size(gray1_roi), cellSizePx, ptsPerCell);
pts = filterBorderPoints(pts, size(gray1_roi), borderMargin);

fprintf('Initial candidate points: %d\n', corners.Count);
fprintf('After cell selection + border filter: %d\n', size(pts,1));

%% ---------------- INITIALIZE TRACKER ----------------
tracker = vision.PointTracker( ...
    'MaxBidirectionalError', maxBidirectionalError, ...
    'NumPyramidLevels', numPyramidLevels);

initialize(tracker, pts, gray1_eq);

%% ---------------- STORAGE ----------------
frameCount = 0;
prevPtsAll = [];
prevValidAll = [];

metricSeries = [];      % 95th percentile displacement
maxDispSeries = [];
medianDispSeries = [];

threshold = NaN;
firstDetectFrame = NaN;
firstDetectMetricPx = NaN;

%% ---------------- MAIN LOOP ----------------
v = VideoReader(videoFile);

while hasFrame(v) && frameCount < maxFrames
    frame = readFrame(v);
    frameCount = frameCount + 1;

    frame_roi = imcrop(frame, roi);
    gray_roi = rgb2gray(frame_roi);
    gray_eq  = adapthisteq(gray_roi);

    [trackedPtsAll, validAll] = step(tracker, gray_eq);

    if isempty(prevPtsAll)
        prevPtsAll = trackedPtsAll;
        prevValidAll = validAll;

        metricSeries(end+1,1) = NaN;
        maxDispSeries(end+1,1) = NaN;
        medianDispSeries(end+1,1) = NaN;
        continue;
    end

    validBothPrev = validAll & prevValidAll;
    cur  = trackedPtsAll(validBothPrev, :);
    prev = prevPtsAll(validBothPrev, :);

    if size(cur,1) < 4
        metricSeries(end+1,1) = NaN;
        maxDispSeries(end+1,1) = NaN;
        medianDispSeries(end+1,1) = NaN;

        prevPtsAll = trackedPtsAll;
        prevValidAll = validAll;
        continue;
    end

    % Frame-to-frame displacement
    dxy = cur - prev;

    % Remove global drift
    globalShift = median(dxy, 1, 'omitnan');
    dxy = dxy - globalShift;

    dispMag = sqrt(sum(dxy.^2, 2));

    % Store metrics
    metricSeries(end+1,1)     = prctile(dispMag, 95);
    maxDispSeries(end+1,1)    = max(dispMag);
    medianDispSeries(end+1,1) = median(dispMag, 'omitnan');

    prevPtsAll = trackedPtsAll;
    prevValidAll = validAll;
end

release(tracker);

%% ---------------- BASELINE THRESHOLD ----------------
baselineVals = metricSeries(2:baselineFrames);
baselineVals = baselineVals(~isnan(baselineVals));

baseMean = mean(baselineVals, 'omitnan');
baseStd  = std(baselineVals, 'omitnan');
threshold = baseMean + kSigma * baseStd;

fprintf('\nBaseline using frames 2:%d\n', baselineFrames); % 95th percentile displacement per frame averages 0.1943 px, “average of the top-moving points (95th percentile) during no-touch
fprintf('Metric = 95th percentile displacement\n');
fprintf('Baseline mean = %.4f px\n', baseMean); % the avg of the top moving points (95%)
fprintf('Baseline std  = %.4f px\n', baseStd); % How much that 95th-percentile value fluctuates from frame to frame during no-touch
fprintf('Threshold     = %.4f px\n', threshold);

%% ---------------- FIRST SUSTAINED DETECTION ----------------
above = metricSeries > threshold;

runCount = 0;
for i = baselineFrames+1:numel(metricSeries)
    if ~isnan(above(i)) && above(i)
        runCount = runCount + 1;
    else
        runCount = 0;
    end

    if runCount >= nConsecutive
        firstDetectFrame = i - nConsecutive + 1;
        firstDetectMetricPx = metricSeries(firstDetectFrame);
        break;
    end
end

if isnan(firstDetectFrame)
    fprintf('\nNo sustained detection found.\n');
else
    fprintf('\nFIRST RELIABLE DETECTION:\n');
    fprintf('Frame = %d\n', firstDetectFrame);
    fprintf('Detected displacement metric = %.4f px\n', firstDetectMetricPx);
    fprintf('Definition: 95th percentile displacement > threshold for %d consecutive frames\n', nConsecutive);
end

%% ---------------- SAVE RESULTS ----------------
save('first_detection_result.mat', ...
    'metricSeries', 'maxDispSeries', 'medianDispSeries', ...
    'threshold', 'firstDetectFrame', 'firstDetectMetricPx', ...
    'baselineFrames', 'kSigma', 'nConsecutive', 'fps');

%% ---------------- PLOT ----------------
frames = (1:numel(metricSeries))';

figure;
plot(frames, metricSeries, 'LineWidth', 1.4); hold on;
yline(threshold, '--r', 'Threshold', 'LineWidth', 1.3);
if ~isnan(firstDetectFrame)
    xline(firstDetectFrame, '--g', 'First reliable detect', 'LineWidth', 1.3);
end
xlabel('Frame');
ylabel('95th percentile displacement (px)');
title('Detection metric over time');
grid on;

%% ================= HELPER FUNCTIONS =================

function ptsOut = selectPointsPerCell(corners, imgSize, cellSize, ptsPerCell)
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
    H = imgSize(1);
    W = imgSize(2);

    keep = ptsIn(:,1) > borderMargin & ptsIn(:,1) < (W - borderMargin) & ...
           ptsIn(:,2) > borderMargin & ptsIn(:,2) < (H - borderMargin);

    ptsOut = ptsIn(keep, :);
end
