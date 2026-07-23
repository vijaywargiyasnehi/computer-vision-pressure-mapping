%% Overlay frame numbers on an existing side-by-side video
clear; clc; close all;

%% ---------------- USER SETTINGS ----------------
inputVideo  = 'side.mov';              % your synced side-by-side video
outputVideo = 'sidebyside_with_frames4.23.mp4';  % output file name

% Text settings
fontSize   = 24;
boxOpacity = 0.6;

% Label positions
% Left/top label for whole frame number
frameLabelPos = [20 20];

% Optional extra labels for left and right halves
showSideLabels = true;

%% ---------------- READ VIDEO ----------------
v = VideoReader(inputVideo);

fprintf('Input video: %s\n', inputVideo);
fprintf('Frame rate: %.3f fps\n', v.FrameRate);
fprintf('Duration: %.3f s\n', v.Duration);

%% ---------------- VIDEO WRITER ----------------
vw = VideoWriter(outputVideo, 'MPEG-4');
vw.FrameRate = v.FrameRate;
open(vw);

%% ---------------- PROCESS FRAMES ----------------
frameNum = 0;

while hasFrame(v)
    frame = readFrame(v);
    frameNum = frameNum + 1;

    H = size(frame,1);
    W = size(frame,2);

    % Overlay main frame number
    frame = insertText(frame, frameLabelPos, ...
        sprintf('Frame %d', frameNum), ...
        'FontSize', fontSize, ...
        'BoxOpacity', boxOpacity, ...
        'TextColor', 'white');

    % Optional labels for left and right halves
    if showSideLabels
        leftPos  = [20, H - 50];
        rightPos = [round(W/2) + 20, H - 50];

        frame = insertText(frame, leftPos, ...
            sprintf('Left side | Frame %d', frameNum), ...
            'FontSize', 18, ...
            'BoxOpacity', 0.5, ...
            'TextColor', 'white');

        frame = insertText(frame, rightPos, ...
            sprintf('Right side | Frame %d', frameNum), ...
            'FontSize', 18, ...
            'BoxOpacity', 0.5, ...
            'TextColor', 'white');
    end

    writeVideo(vw, frame);
end

%% ---------------- WRAP UP ----------------
close(vw);

fprintf('Done.\n');
fprintf('Wrote: %s\n', outputVideo);
