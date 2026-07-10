function Params = tracking_params(Params)

% Josh R Baxter, PhD - University of Pennsylvania
% joshrbaxter@gmail.com
% version history
% v1 - 2017-12-12 - parameters used for tracking
%% input: Params - ultrasound parameters

%% output: Params - updated params structure with tracking parameters

%% parameters

Params.padBorder = [0.01,0.01];
for i=3:Params.n_struct
    Params.padBorder(i)=0.05; % was 0.05
end
Params.userInputHt = 1; % in mm
Params.rectHt = round(Params.userInputHt / Params.px2mmX); %region of interest height
Params.getUserInputSaveDir = false; % if true, let user select directory to save

Params.landmarkString = {'Deep Aponeurosis','Superficial Aponeurosis'};
Params.markerColor = {'blue','blue'};

for i=3:Params.n_struct
    Params.landmarkString(i)={'Fascicle'};
    Params.markerColor(i)={'red'};
end
Params.blindUser = true;


% tracking settings
Params.displayTracking = true;
Params.saveVideo = true;
Params.saveData = true;
Params.plotPoints = true; % plot tracking points as '+'
Params.showLines = true; % lines from tracked points
Params.rejectOutliers = false; % reject poorly tracked markers - select false for longer trials
Params.displayPtRetention = true; % display number of points retained throughout tracking
Params.redefinePts = true; %
Params.maxTrackingPts = [150;150]; % number of points seeded along line
for i=3:Params.n_struct
    Params.maxTrackingPts(i)=100;
end
Params.padAVIframes = 5;
Params.manual = 'excursion'; % just calculate first and last frame fascicle length and pennation.

% supervised drift-correction controls (Hough-signal based, EM path only)
% Set useControls=false for plain KLT tracking (no Hough-based re-initialization).
Params.useControls = true;
Params.houghCutoff = 1;   % Hz, low-pass cutoff applied to the Hough signal (used by the controls)
% per-control enables (all on when useControls is on; can disable individually)
Params.ctrlEnReinit  = true;   % periodic re-seed
Params.ctrlEnDeriv   = true;   % derivative-agreement check (check 2)
Params.ctrlEnMinMax  = true;   % min-max difference near Hough peaks (check 3)
Params.ctrlEnLenJump = true;   % frame-to-frame length jump (check 4)
Params.ctrlEnPenn    = true;   % pennation-range check (check 5)
Params.ctrlReinitSegments   = 6;    % periodic re-seed: split the trial into N segments
Params.ctrlLenJumpThresh    = 7.5;  % mm, max plausible frame-to-frame length jump (check 4)
Params.ctrlPennMin          = 14;   % deg, min plausible pennation (check 5)
Params.ctrlPennMax          = 35;   % deg, max plausible pennation (check 5)
Params.ctrlMinMaxDiffThresh = 0.1;  % normalised EM-vs-Hough difference near peaks (check 3)
Params.ctrlDerivAgreeFrac   = 0.3;  % min fraction of agreeing derivatives in the window (check 2)


% user inputs for optical flow tracking
Params.userInputBiDirect_mm = 3; % in mm % previous 2mm --> do not increase (we raise it because the points do not move enough)
Params.userInputMaxBiDirectionalError = round(Params.userInputBiDirect_mm / Params.px2mmX);
Params.userInputPyramidLevels = 5; % previous 4
Params.userInputBlockSizemm = 3; % previous 3 % odd numbers
blocksizex = 2*round(((Params.userInputBlockSizemm/Params.px2mmX)+1)/2)-1;
blocksizey = 2*round(((Params.userInputBlockSizemm/Params.px2mmY)+1)/2)-1;
Params.userInputBlockSize = [blocksizex blocksizey];
Params.redefinePtsThresh = [0.9;0.9]; % ratio of tracked points to original points
Params.redefineWidthThresh = [0.9;0.9]; % ratio of width with points
for i=3:Params.n_struct
    Params.redefinePtsThresh(i)=0.5;
    Params.redefineWidthThresh(i)=0.00005;
end


% Manual tracking (Validation parameters)
Params.validateFrameType = 'position'; % biodex channels - 'position' or 'cyclepercent' of clip for gait and other movements
Params.validateFrameVal = [-20:10:30];
% Params.validateFramePercent = [0:0.2:1]; previous
%Params.validateFramePercent = [0,0.1,0.15,0.2,0.25,0.3,0.35,0.4,0.45,0.5,0.55,0.6,0.65,0.7,0.75,0.8,0.85,0.9,0.95,1];
Params.manualFrameStep = 4; %

% paths for saving
Params.userInitials = 'user';

Params.date_time_track = datestr(now,'yyyymmdd_HHMMSS');
Params.trackedSaveDir = fullfile(Params.viddir,'tracked',[Params.nome_Video,'_',Params.date_time_track]);

end
