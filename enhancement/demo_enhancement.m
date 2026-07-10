%% demo_enhancement.m
% Minimal, demonstration of the ultrasound image enhancement
% (spatial pre-processing + frequency-domain muscle-belly enhancement)
% decoupled from the tracking pipeline. Uses enhanceUSImage.m.
%
% Run each cell (Ctrl+Enter). No Params/Data structures required.

clear; close all; clc;

%% 1. Load one frame
% ---- Option A: from an .mp4 clip -----------------------------------------
% [f,p]  = uigetfile({'*.mp4;*.avi','Video'},'Pick an ultrasound clip');
% v      = VideoReader(fullfile(p,f));
% frame  = read(v,1);                 % first frame

% ---- Option B: from a saved image ----------------------------------------
[f,p]  = uigetfile({'*.png;*.jpg;*.tif;*.mp4;*.avi','Image or video'}, ...
                   'Pick an ultrasound frame or clip');
assert(ischar(f),'No file selected.');
[~,~,ext] = fileparts(f);
if any(strcmpi(ext,{'.mp4','.avi'}))
    v = VideoReader(fullfile(p,f));
    frame = read(v,1);
else
    frame = imread(fullfile(p,f));
end

%% 2. Enhance – interactive (draw the two aponeuroses when prompted)
opts = struct();
opts.flip        = false;   % set true if fascicles do not run bottom-left -> top-right
opts.apoVisible  = true;    % set false if the superficial aponeurosis is not in view
% opts.cropRect  = [1 1 633 631];   % uncomment to crop to the US image region

out = enhanceUSImage(frame, [], [], opts);

%% 3. (Optional) Re-run non-interactively with fixed aponeurosis lines
% Reuse the lines you just drew so the result is reproducible / scriptable:
apoDeep = out.apoDeep;      % [x1 y1; x2 y2]
apoSup  = out.apoSup;       % [x1 y1; x2 y2]
out = enhanceUSImage(frame, apoDeep, apoSup, opts);

%% 4. Save the enhanced frame to share
imwrite(out.preprocessed, 'enhanced_step2_preprocessed.png');
imwrite(out.enhanced,     'enhanced_step3_fft.png');
fprintf('Saved enhanced_step2_preprocessed.png and enhanced_step3_fft.png\n');
