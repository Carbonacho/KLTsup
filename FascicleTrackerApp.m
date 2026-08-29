classdef FascicleTrackerApp < handle
%FASCICLETRACKERAPP  GUI front-end for the FFT/HFR fascicle-tracking pipeline.
%
%   A programmatic uifigure app that replaces the manual setup portion of
%   main_FFT_HFR.m (file dialogs, listdlg selections, hardcoded geometry and
%   the missing selezione_incl_fascicoli) with editable controls, then runs
%   trackfascicle() and displays the results.
%
%   USAGE
%       app = FascicleTrackerApp;
%   Keep this file on the MATLAB path together with the rest of the CODICE
%   pipeline (it self-adds the subfolders on startup).
%
%   INPUT: a single video file (mp4/avi/mov). Everything the pipeline used
%   to read from the list_of_clips .mat is entered directly in the GUI:
%       - Frame rate (Hz)   -> Params.framerate            (auto-filled from video)
%       - First frame       -> first frame to track
%       - Last frame        -> last frame to track         (auto-filled = #frames)
%       - Frame step        -> Params.downsampling_framerate (tracking stride)
%   The per-frame time vector is synthesized as (0:N-1)/framerate.
%
%   The Preview tab lets you scrub the video, pick first/last frames and draw
%   the crop ROI directly onto a frame (which fills the Crop x/y/w/h fields).
%
%   IMPORTANT - the deep tracking functions are still interactive: while a
%   run is in progress the pipeline pops its own figures / questdlg boxes.
%   This app manages everything AROUND those steps; it does not suppress them.

    properties
        Fig                 % uifigure handle
        h = struct()        % struct of UI component handles
        VideoFile = ''      % full path to the loaded video
        VideoFolder = ''    % folder holding the video (output 'tracked' dir goes here)
        TrialName = ''      % sanitized name derived from the video file
        NumFrames = 0       % number of frames in the loaded video
        PrevW = 0           % video width  (px)
        PrevH = 0           % video height (px)
        PreviewVR = []      % VideoReader used for the preview
        PlayTimer = []      % timer driving preview playback
        CurFrame = 1        % current preview frame index
        Results = struct()  % accumulated tracking results
        CurFascicle = []    % Fascicle currently shown on Results tab (for frame-rate re-scaling)
        Init = struct()     % stored initialisation (for track-from-reference)
        InitEM = struct()
        InitParams = struct() % Params from the initializing run (reused by first=0)
        HasInit = false
    end

    methods
        function app = FascicleTrackerApp()
            % ensure all pipeline subfolders (tracking, image_processing, ...) are on the path
            addpath(genpath(fileparts(mfilename('fullpath'))));
            buildUI(app);
        end
    end

    methods (Access = private)

        %% ------------------------------------------------------------ UI
        function buildUI(app)
            app.Fig = uifigure('Name','KLTsup - supervised fascicle tracking', ...
                'Position',[100 100 1180 720], ...
                'CloseRequestFcn',@(s,e)onClose(app));
            outer = uigridlayout(app.Fig,[1 2]);
            outer.ColumnWidth = {380,'1x'};
            outer.RowHeight = {'1x'};

            % ---- left: scrollable controls -------------------------------
            ctrlPanel = uipanel(outer,'Title','Setup & parameters', ...
                'Scrollable','on');
            ctrlPanel.Layout.Row = 1; ctrlPanel.Layout.Column = 1;
            g = uigridlayout(ctrlPanel,[62 2]);
            g.RowHeight = repmat({26},1,62);
            g.ColumnWidth = {150,'1x'};
            g.Scrollable = 'on';
            r = 0;

            % ---- video ----
            r = r+1; app.h.btnVideo = uibutton(g,'Text','Load video (mp4/avi)...', ...
                'ButtonPushedFcn',@(s,e)onBrowseVideo(app));
            app.h.btnVideo.Layout.Row = r; app.h.btnVideo.Layout.Column = [1 2];

            r = r+1; addLabel(g,r,'Video:');
            app.h.lblVideo = addRO(g,r,'(none)');
            r = r+1; addLabel(g,r,'Info:');
            app.h.lblInfo = addRO(g,r,'-');
            r = r+1; addLabel(g,r,'Trial name:');
            app.h.edTrial = uieditfield(g,'text','Value','');
            app.h.edTrial.Layout.Row = r; app.h.edTrial.Layout.Column = 2;

            % ---- frame selection (replaces the clip .mat fields) ----
            r = r+1; addSection(g,r,'Frames & timing');
            r = r+1; addLabel(g,r,'Frame rate (Hz):');
            app.h.numFrameRate = addNum(g,r,25);
            app.h.numFrameRate.ValueChangedFcn = @(s,e)onFrameRateChanged(app);
            r = r+1; addLabel(g,r,'Hough cutoff (Hz):');
            app.h.numHoughCut = addNum(g,r,1);
            app.h.numHoughCut.ValueChangedFcn = @(s,e)onFrameRateChanged(app);
            r = r+1; addLabel(g,r,'First frame:');
            app.h.numStart = addNum(g,r,1);
            app.h.numStart.ValueChangedFcn = @(s,e)previewFrameField(app,app.h.numStart);
            r = r+1; addLabel(g,r,'Last frame:');
            app.h.numLast = addNum(g,r,1);
            app.h.numLast.ValueChangedFcn = @(s,e)previewFrameField(app,app.h.numLast);
            r = r+1; addLabel(g,r,'Frame step:');
            app.h.numStep = addNum(g,r,1);
            r = r+1; addLabel(g,r,'Validation step:');
            app.h.numValStep = addNum(g,r,4);

            % ---- geometry ----
            r = r+1; addSection(g,r,'Image geometry');
            r = r+1; addLabel(g,r,'Depth (mm):');
            app.h.numDepth = addNum(g,r,40);
            r = r+1; addLabel(g,r,'Probe width (mm):');
            app.h.numProbe = addNum(g,r,40);
            r = r+1; addLabel(g,r,'Crop x:');
            app.h.numCropX = addNum(g,r,1);
            r = r+1; addLabel(g,r,'Crop y:');
            app.h.numCropY = addNum(g,r,1);
            r = r+1; addLabel(g,r,'Crop width (nx):');
            app.h.numCropW = addNum(g,r,633);
            r = r+1; addLabel(g,r,'Crop height (ny):');
            app.h.numCropH = addNum(g,r,631);
            % live preview refresh when the crop rectangle (resolution) changes
            app.h.numCropX.ValueChangedFcn = @(s,e)refreshPreview(app);
            app.h.numCropY.ValueChangedFcn = @(s,e)refreshPreview(app);
            app.h.numCropW.ValueChangedFcn = @(s,e)refreshPreview(app);
            app.h.numCropH.ValueChangedFcn = @(s,e)refreshPreview(app);

            % ---- acquisition options (replaces selezione_incl_fascicoli) ----
            r = r+1; addSection(g,r,'Acquisition');
            r = r+1; addLabel(g,r,'Superficial apo visible:');
            app.h.chkApo = uicheckbox(g,'Text','','Value',true);
            app.h.chkApo.Layout.Row = r; app.h.chkApo.Layout.Column = 2;
            r = r+1; addLabel(g,r,'Flip horizontally:');
            app.h.chkFlip = uicheckbox(g,'Text','check if NOT bottom rigth - top left','Value',false, ...
                'ValueChangedFcn',@(s,e)refreshPreview(app));
            app.h.chkFlip.Layout.Row = r; app.h.chkFlip.Layout.Column = 2;
            r = r+1; addLabel(g,r,'Number of fascicles:');
            app.h.numFas = uispinner(g,'Value',1,'Limits',[1 5],'Step',1);
            app.h.numFas.Layout.Row = r; app.h.numFas.Layout.Column = 2;

            % ---- tracking parameters ----
            r = r+1; addSection(g,r,'Tracking parameters (KLT)');
            r = r+1; addLabel(g,r,'Block size (mm):');
            app.h.numBlock = addNum(g,r,3);
            r = r+1; addLabel(g,r,'Pyramid levels:');
            app.h.numPyr = addNum(g,r,5);
            r = r+1; addLabel(g,r,'Bidir. error (mm):');
            app.h.numBiDir = addNum(g,r,3);
            r = r+1; addLabel(g,r,'Max pts (aponeurosis):');
            app.h.numMaxApo = addNum(g,r,150);
            r = r+1; addLabel(g,r,'Max pts (fascicle):');
            app.h.numMaxFas = addNum(g,r,100);
            r = r+1; addLabel(g,r,'Redefine thresh (apo):');
            app.h.numThrApo = addNum(g,r,0.9);
            r = r+1; addLabel(g,r,'Redefine thresh (fasc):');
            app.h.numThrFas = addNum(g,r,0.5);
            r = r+1; addLabel(g,r,'Save tracked video:');
            app.h.chkSaveVid = uicheckbox(g,'Text','','Value',true);
            app.h.chkSaveVid.Layout.Row = r; app.h.chkSaveVid.Layout.Column = 2;

            % ---- supervised drift-correction controls ----
            r = r+1; addSection(g,r,'Supervised controls');
            r = r+1; addLabel(g,r,'Use supervised controls:');
            app.h.chkControls = uicheckbox(g,'Text','(select all; asks to re-track on error)', ...
                'Value',true,'ValueChangedFcn',@(s,e)onMasterControls(app));
            app.h.chkControls.Layout.Row = r; app.h.chkControls.Layout.Column = 2;

            r = r+1; addLabel(g,r,'  Periodic re-seed:');
            app.h.chkEnReinit = uicheckbox(g,'Text','','Value',true);
            app.h.chkEnReinit.Layout.Row = r; app.h.chkEnReinit.Layout.Column = 2;
            r = r+1; addLabel(g,r,'  Re-seed segments:');
            app.h.numReinitSeg = addNum(g,r,6);

            r = r+1; addLabel(g,r,'  Derivative agreement:');
            app.h.chkEnDeriv = uicheckbox(g,'Text','','Value',true);
            app.h.chkEnDeriv.Layout.Row = r; app.h.chkEnDeriv.Layout.Column = 2;
            r = r+1; addLabel(g,r,'  Deriv-agree fraction:');
            app.h.numDerivFrac = addNum(g,r,0.3);

            r = r+1; addLabel(g,r,'  Min-max diff (peaks):');
            app.h.chkEnMinMax = uicheckbox(g,'Text','','Value',true);
            app.h.chkEnMinMax.Layout.Row = r; app.h.chkEnMinMax.Layout.Column = 2;
            r = r+1; addLabel(g,r,'  Min-max diff thresh:');
            app.h.numMinMaxDiff = addNum(g,r,0.1);

            r = r+1; addLabel(g,r,'  Length jump:');
            app.h.chkEnLenJump = uicheckbox(g,'Text','','Value',true);
            app.h.chkEnLenJump.Layout.Row = r; app.h.chkEnLenJump.Layout.Column = 2;
            r = r+1; addLabel(g,r,'  Length-jump thresh (mm):');
            app.h.numLenJump = addNum(g,r,7.5);

            r = r+1; addLabel(g,r,'  Fascicle angle range:');
            app.h.chkEnPenn = uicheckbox(g,'Text','','Value',true);
            app.h.chkEnPenn.Layout.Row = r; app.h.chkEnPenn.Layout.Column = 2;
            r = r+1; addLabel(g,r,'  Angle min (deg):');
            app.h.numPennMin = addNum(g,r,14);
            r = r+1; addLabel(g,r,'  Angle max (deg):');
            app.h.numPennMax = addNum(g,r,35);

            % ---- run buttons ----
            r = r+1; app.h.btnRun = uibutton(g,'Text','Initialize & Track', ...
                'BackgroundColor',[0.30 0.65 0.35],'FontColor','w', ...
                'FontWeight','bold','ButtonPushedFcn',@(s,e)onRun(app,true));
            app.h.btnRun.Layout.Row = r; app.h.btnRun.Layout.Column = [1 2];
            r = r+1; app.h.btnRunRef = uibutton(g,'Text','Track from reference init...', ...
                'ButtonPushedFcn',@(s,e)onRun(app,false));
            app.h.btnRunRef.Layout.Row = r; app.h.btnRunRef.Layout.Column = [1 2];
            r = r+1; app.h.btnManual = uibutton(g,'Text','Manual tracking (no auto)...', ...
                'BackgroundColor',[0.35 0.5 0.7],'FontColor','w', ...
                'ButtonPushedFcn',@(s,e)onManualTrack(app));
            app.h.btnManual.Layout.Row = r; app.h.btnManual.Layout.Column = [1 2];
            r = r+1; app.h.btnLoadRes = uibutton(g,'Text','Load tracked result (display)...', ...
                'ButtonPushedFcn',@(s,e)onLoadResult(app));
            app.h.btnLoadRes.Layout.Row = r; app.h.btnLoadRes.Layout.Column = [1 2];
            r = r+1; app.h.btnSave = uibutton(g,'Text','Save results...', ...
                'ButtonPushedFcn',@(s,e)onSave(app));
            app.h.btnSave.Layout.Row = r; app.h.btnSave.Layout.Column = [1 2];
            r = r+1; app.h.btnExportCSV = uibutton(g,'Text','Export CSV...', ...
                'ButtonPushedFcn',@(s,e)onExportCSV(app));
            app.h.btnExportCSV.Layout.Row = r; app.h.btnExportCSV.Layout.Column = [1 2];
            r = r+1; app.h.btnSaveSet = uibutton(g,'Text','Save settings...', ...
                'ButtonPushedFcn',@(s,e)onSaveSettings(app));
            app.h.btnSaveSet.Layout.Row = r; app.h.btnSaveSet.Layout.Column = 1;
            app.h.btnLoadSet = uibutton(g,'Text','Load settings...', ...
                'ButtonPushedFcn',@(s,e)onLoadSettings(app));
            app.h.btnLoadSet.Layout.Row = r; app.h.btnLoadSet.Layout.Column = 2;
            r = r+1; app.h.btnAbout = uibutton(g,'Text','About / How to cite', ...
                'ButtonPushedFcn',@(s,e)onAbout(app));
            app.h.btnAbout.Layout.Row = r; app.h.btnAbout.Layout.Column = [1 2];

            % ---- right: status + tabbed preview/results ------------------
            rp = uigridlayout(outer,[2 1]);
            rp.Layout.Row = 1; rp.Layout.Column = 2;
            rp.RowHeight = {28,'1x'};
            app.h.status = uilabel(rp,'Text','Load a video to begin.', ...
                'FontWeight','bold');
            app.h.status.Layout.Row = 1;

            app.h.tg = uitabgroup(rp); app.h.tg.Layout.Row = 2;
            tabPrev = uitab(app.h.tg,'Title','Preview');
            app.h.tabRes = uitab(app.h.tg,'Title','Results');

            % --- Preview tab ---
            pg = uigridlayout(tabPrev,[4 1]);
            pg.RowHeight = {'1x',22,50,34};
            app.h.axPrev = uiaxes(pg); app.h.axPrev.Layout.Row = 1;
            title(app.h.axPrev,'Video preview');

            app.h.lblReadout = uilabel(pg,'Text','','HorizontalAlignment','center', ...
                'FontColor',[0.15 0.3 0.55]);
            app.h.lblReadout.Layout.Row = 2;

            cg = uigridlayout(pg,[1 3]); cg.Layout.Row = 3;
            cg.ColumnWidth = {'1x',140,120};
            cg.Padding = [0 5 0 5]; cg.ColumnSpacing = 8;
            app.h.sldFrame = uislider(cg,'Limits',[1 2],'Value',1, ...
                'MajorTicks',[],'ValueChangedFcn',@(s,e)onSlider(app));
            app.h.sldFrame.Layout.Column = 1;
            app.h.chkOverlay = uicheckbox(cg,'Text','Overlay tracking','Value',false, ...
                'ValueChangedFcn',@(s,e)refreshPreview(app));
            app.h.chkOverlay.Layout.Column = 2;
            app.h.lblFrame = uilabel(cg,'Text','Frame - / -', ...
                'HorizontalAlignment','center');
            app.h.lblFrame.Layout.Column = 3;

            bg = uigridlayout(pg,[1 5]); bg.Layout.Row = 4;
            bg.Padding = [0 0 0 0]; bg.ColumnSpacing = 6;
            bg.ColumnWidth = {'1x','1x','1x','1x','1x'};
            app.h.btnPlay = uibutton(bg,'Text','Play', ...
                'ButtonPushedFcn',@(s,e)onPlayToggle(app));
            app.h.btnSetFirst = uibutton(bg,'Text','Set first', ...
                'ButtonPushedFcn',@(s,e)onSetFirst(app));
            app.h.btnSetLast = uibutton(bg,'Text','Set last', ...
                'ButtonPushedFcn',@(s,e)onSetLast(app));
            app.h.btnCrop = uibutton(bg,'Text','Draw crop', ...
                'ButtonPushedFcn',@(s,e)onDrawCrop(app));
            app.h.btnResetCrop = uibutton(bg,'Text','Reset crop', ...
                'ButtonPushedFcn',@(s,e)onResetCrop(app));

            % --- Results tab ---
            rg = uigridlayout(app.h.tabRes,[4 1]);
            rg.RowHeight = {30,'1x','1x','1x'};
            tog = uigridlayout(rg,[1 5]); tog.Layout.Row = 1;
            tog.Padding = [0 0 0 0]; tog.ColumnSpacing = 6;
            app.h.chkShowEM  = uicheckbox(tog,'Text','Automatic','Value',true, ...
                'ValueChangedFcn',@(s,e)onFrameRateChanged(app));
            app.h.chkShowVal = uicheckbox(tog,'Text','Informed manual','Value',true, ...
                'ValueChangedFcn',@(s,e)onFrameRateChanged(app));
            app.h.chkShowMan = uicheckbox(tog,'Text','Pure manual','Value',true, ...
                'ValueChangedFcn',@(s,e)onFrameRateChanged(app));
            app.h.btnBA      = uibutton(tog,'Text','Bland-Altman', ...
                'ButtonPushedFcn',@(s,e)onBlandAltman(app));
            app.h.btnPopOut  = uibutton(tog,'Text','Pop out', ...
                'ButtonPushedFcn',@(s,e)onPopOut(app));
            app.h.axPenn = uiaxes(rg); app.h.axPenn.Layout.Row = 2;
            title(app.h.axPenn,'Fascicle angle'); xlabel(app.h.axPenn,'Time (s)');
            ylabel(app.h.axPenn,'Angle (deg)');
            app.h.axLen = uiaxes(rg); app.h.axLen.Layout.Row = 3;
            title(app.h.axLen,'Fascicle length'); xlabel(app.h.axLen,'Time (s)');
            ylabel(app.h.axLen,'Length (mm)');
            app.h.axHough = uiaxes(rg); app.h.axHough.Layout.Row = 4;
            title(app.h.axHough,'Hough signal (filtered)'); xlabel(app.h.axHough,'Frame');
            ylabel(app.h.axHough,'Angle (deg)');
        end

        %% ------------------------------------------------------- callbacks
        function onBrowseVideo(app)
            [f,p] = uigetfile({'*.mp4;*.avi;*.mov;*.m4v','Video files'; ...
                               '*.*','All files'},'Select an ultrasound video');
            if ~ischar(f), return; end
            vf = fullfile(p,f);
            try
                v = VideoReader(vf);
                nFrames = v.NumFrames;
                fps = v.FrameRate;
                w = v.Width; ht = v.Height;
            catch ME
                setStatus(app,['ERROR reading video: ' ME.message],true); return;
            end
            stopPlay(app);
            app.VideoFile = vf;
            app.VideoFolder = p;
            app.NumFrames = nFrames;
            app.PrevW = w; app.PrevH = ht;
            app.PreviewVR = v;
            app.CurFrame = 1;
            [~,base,~] = fileparts(f);
            app.TrialName = matlab.lang.makeValidName(base);

            app.h.lblVideo.Text = f;
            app.h.lblInfo.Text = sprintf('%d frames @ %.1f fps  (%.1f s, %dx%d)', ...
                nFrames, fps, v.Duration, w, ht);
            app.h.edTrial.Value = app.TrialName;
            if fps > 0, app.h.numFrameRate.Value = round(fps); end
            app.h.numStart.Value = 1;
            app.h.numLast.Value = nFrames;
            % default the crop to the full frame; user can tighten it
            app.h.numCropX.Value = 1;   app.h.numCropY.Value = 1;
            app.h.numCropW.Value = w;   app.h.numCropH.Value = ht;

            % preview slider
            app.h.sldFrame.Limits = [1 max(nFrames,2)];
            app.h.sldFrame.Value = 1;
            app.h.sldFrame.Enable = matlab.lang.OnOffSwitchState(nFrames >= 2);
            showFrame(app,1);

            setStatus(app,sprintf('Loaded %s.',f),false);
        end

        function onRun(app,first)
            try
                assert(~isempty(app.VideoFile),'Load a video first.');
                assert(isfile(app.VideoFile),sprintf('Video not found:\n%s',app.VideoFile));
                stopPlay(app);
                N  = app.NumFrames;
                fr = app.h.numFrameRate.Value;
                startF = round(app.h.numStart.Value);
                lastF  = round(app.h.numLast.Value);
                step   = round(app.h.numStep.Value);
                assert(fr > 0,'Frame rate must be > 0.');
                assert(step >= 1,'Frame step must be >= 1.');
                assert(startF >= 1,'First frame must be >= 1.');
                assert(lastF <= N,sprintf('Last frame (%d) exceeds video length (%d).',lastF,N));
                assert(lastF > startF,'Last frame must be greater than first frame.');

                app.TrialName = matlab.lang.makeValidName(app.h.edTrial.Value);
                trial = app.TrialName;

                % pipeline reads the video path from this global (temp video only)
                global subdir %#ok<GVMIS>
                subdir = app.VideoFolder;

                % --- synthesize what the clip .mat used to provide ---
                time = (0:N-1)/fr;               % per-frame timestamps (s)
                frameInds = startF:step:lastF;   % selected / tracked frames
                TD.trialName   = app.VideoFile;
                TD.mocapTime   = time;
                TD.imageTime   = time(frameInds);
                TD.trackFrames = startF:step:lastF;

                if first
                    Params = buildParams(app,fr,step);
                    setStatus(app,'Tracking (with initialization)... follow the pipeline dialogs.',false);
                    drawnow;
                    [Fascicle,~,~,Params,ini,iniEM] = trackfascicle(TD,Params,1,trial); %#ok<ASGLU>
                    app.Init = ini; app.InitEM = iniEM; app.InitParams = Params; app.HasInit = true;
                else
                    if ~app.HasInit
                        [app.Init,app.InitEM,app.InitParams] = loadReferenceInit(app);
                        if isempty(fieldnames(app.Init)), return; end
                    end
                    % Reuse the initialization run's Params - it carries the fields the
                    % reference path needs (apon_media1/2, linee_apon*, da_tracciare_apo,
                    % geometry, ...). Only per-run bits are overridden below.
                    Params = app.InitParams;
                    Params.nome_Video = trial;
                    Params.viddir = app.VideoFolder;
                    Params.framerate = fr;
                    Params.downsampling_framerate = step;
                    Params.manualFrameStep = max(1,round(app.h.numValStep.Value));
                    Params.houghCutoff          = max(0.01,app.h.numHoughCut.Value);
                    Params.useControls          = app.h.chkControls.Value;
                    Params.ctrlEnReinit         = app.h.chkEnReinit.Value;
                    Params.ctrlEnDeriv          = app.h.chkEnDeriv.Value;
                    Params.ctrlEnMinMax         = app.h.chkEnMinMax.Value;
                    Params.ctrlEnLenJump        = app.h.chkEnLenJump.Value;
                    Params.ctrlEnPenn           = app.h.chkEnPenn.Value;
                    Params.ctrlReinitSegments   = max(1,round(app.h.numReinitSeg.Value));
                    Params.ctrlLenJumpThresh    = app.h.numLenJump.Value;
                    Params.ctrlPennMin          = app.h.numPennMin.Value;
                    Params.ctrlPennMax          = app.h.numPennMax.Value;
                    Params.ctrlMinMaxDiffThresh = app.h.numMinMaxDiff.Value;
                    Params.ctrlDerivAgreeFrac   = app.h.numDerivFrac.Value;
                    Params.trackedSaveDir = fullfile(app.VideoFolder,'tracked', ...
                        [trial '_' datestr(now,'yyyymmdd_HHMMSS')]);
                    Params.ritracciati = 0; Params.Init = zeros(1,300);
                    Params.cancellato = 0;
                    Params.contatore1=0; Params.contatore2=0; Params.contatore3=0;
                    Params.contatore4=0; Params.contatore5=0; Params.box=0;
                    setStatus(app,'Tracking from stored initialization...',false);
                    drawnow;
                    [Fascicle,~,~,Params] = trackfascicle(TD,Params,0,trial,app.Init,app.InitEM);
                end

                % keep previously drawn manual curves for this trial (informed and
                % pure) so they overlay the auto result regardless of order
                if isfield(app.Results,trial) && isfield(app.Results.(trial),'fascicle')
                    prevF = app.Results.(trial).fascicle;
                    if isfield(prevF,'validate') && ~isfield(Fascicle,'validate')
                        Fascicle.validate = prevF.validate;
                    end
                    if isfield(prevF,'manual') && ~isfield(Fascicle,'manual')
                        Fascicle.manual = prevF.manual;
                    end
                end
                app.Results.(trial).fascicle = Fascicle;
                app.Results.(trial).Params   = Params;
                app.Results.(trial).init      = app.Init;   % stored so this run can serve as a future reference
                app.Results.(trial).initEM    = app.InitEM;
                plotResults(app,Fascicle);
                autoSave(app,Params);
                setStatus(app,sprintf('Done: %s tracked (%d frames).',trial, ...
                    numel(Fascicle.automatic_EM.pennation)),false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function onManualTrack(app)
            % Standalone manual tracking (no automatic tracking).
            % Frame 1: draw deep apo, superficial apo and fascicle(s) by hand.
            % Frame 2+: the previous frame's lines are pre-placed as draggable
            %   ROIs; nudge the endpoints. On every frame press SPACE/ENTER (or
            %   the Confirm button) to accept, so a misclick can be fixed first.
            % Produces a "validate" curve comparable to the auto output.
            try
                assert(~isempty(app.VideoFile) && ~isempty(app.PreviewVR),'Load a video first.');
                stopPlay(app);
                fr = app.h.numFrameRate.Value; if fr<=0, fr=1; end
                startF  = round(app.h.numStart.Value);
                lastF   = round(app.h.numLast.Value);
                valStep = max(1,round(app.h.numValStep.Value));    % validation frame step
                assert(startF>=1 && lastF<=app.NumFrames && lastF>startF, ...
                    'Check first/last frame and video length.');
                trial  = matlab.lang.makeValidName(app.h.edTrial.Value);
                Params = buildParams(app,fr,valStep);

                frameInd = startF:valStep:lastF;
                doFlip = app.h.chkFlip.Value;
                crop = [app.h.numCropX.Value app.h.numCropY.Value ...
                        app.h.numCropW.Value app.h.numCropH.Value];
                nS = Params.n_struct;
                len  = nan(numel(frameInd),1);
                penn = nan(numel(frameInd),1);
                plotIns = cell(1,numel(frameInd));
                colr = cell(1,nS);
                for i=1:nS
                    if i==1,     colr{i}=[0 1 1];   % deep apo  - cyan
                    elseif i==2, colr{i}=[1 1 0];   % sup apo   - yellow
                    else,        colr{i}=[1 0 0];   % fascicle  - red
                    end
                end

                hFig = figure('Name','Manual tracking','NumberTitle','off', ...
                    'WindowState','maximized','KeyPressFcn',@(s,e)manualKeyPress(s,e));
                hAx = axes('Parent',hFig);
                uicontrol(hFig,'Style','pushbutton','String','Confirm (Space)', ...
                    'Units','normalized','Position',[0.87 0.01 0.12 0.05], ...
                    'Callback',@(s,e)manualConfirmBtn(hFig));
                prevPos = cell(1,nS);

                for k = 1:numel(frameInd)
                    if ~isvalid(hFig)
                        setStatus(app,'Manual tracking cancelled.',true); return;
                    end
                    fn = frameInd(k);
                    img = read(app.PreviewVR,fn);
                    if doFlip, img = flip(img,2); end
                    if size(img,3)==3, img = rgb2gray(img); end
                    img = imcrop(img,crop);
                    imshow(img,'Parent',hAx);

                    % place / draw the line ROIs
                    rois = gobjects(1,nS);
                    for i = 1:nS
                        if k==1 || isempty(prevPos{i})
                            title(hAx,sprintf('Frame %d (%d/%d): draw %s (click-drag)', ...
                                fn,k,numel(frameInd),manualLabel(i)));
                            rois(i) = drawline(hAx,'Color',colr{i});
                            if ~isvalid(hFig) || ~isvalid(rois(i)) || isempty(rois(i).Position)
                                setStatus(app,'Manual tracking cancelled.',true);
                                if isvalid(hFig), delete(hFig); end
                                return;
                            end
                        else
                            rois(i) = images.roi.Line(hAx,'Position',prevPos{i},'Color',colr{i});
                        end
                    end

                    % adjust / redraw / confirm loop
                    confirmed = false;
                    while ~confirmed
                        title(hAx,sprintf(['Frame %d (%d/%d): drag to adjust | SPACE=confirm | ' ...
                            'R=redraw all, 1..%d=redraw one | Esc=cancel'], ...
                            fn,k,numel(frameInd),nS));
                        act = waitForAction(app,hFig);
                        switch act.type
                            case 'confirm'
                                confirmed = true;
                            case 'redo'
                                if act.idx==0, idxs = 1:nS; else, idxs = act.idx; end
                                idxs = idxs(idxs>=1 & idxs<=nS);
                                for i = idxs
                                    if isvalid(rois(i)), delete(rois(i)); end
                                    title(hAx,sprintf('Frame %d (%d/%d): REDRAW %s (click-drag)', ...
                                        fn,k,numel(frameInd),manualLabel(i)));
                                    rois(i) = drawline(hAx,'Color',colr{i});
                                    if ~isvalid(hFig) || ~isvalid(rois(i)) || isempty(rois(i).Position)
                                        setStatus(app,'Manual tracking cancelled.',true);
                                        if isvalid(hFig), delete(hFig); end
                                        return;
                                    end
                                end
                            otherwise   % cancel / closed
                                setStatus(app,'Manual tracking cancelled.',true);
                                if isvalid(hFig), delete(hFig); end
                                return;
                        end
                    end

                    fd = struct(); fd.pts = cell(1,nS);
                    for i = 1:nS
                        p = rois(i).Position; fd.pts{i} = p; prevPos{i} = p;
                    end
                    fc = calculatefascicle(fd,Params);
                    len(k)  = fc.length(1);
                    penn(k) = fc.pennation(1);
                    plotIns{k} = fc.plotInsertions;   % for the preview overlay
                    delete(rois(isvalid(rois)));
                end
                if isvalid(hFig), close(hFig); end

                manual = struct('time',(frameInd(:).'-1)/fr, ...
                                'trackFrames',frameInd, ...
                                'pennation',penn,'length',len);
                manual.plotInsertions = plotIns;   % per-frame lines for overlay
                if ~isfield(app.Results,trial) || ~isfield(app.Results.(trial),'fascicle')
                    app.Results.(trial).fascicle = struct();
                end
                app.Results.(trial).fascicle.manual = manual;   % PURE manual (independent of auto)
                app.Results.(trial).Params = Params;
                plotResults(app,app.Results.(trial).fascicle);
                app.h.tg.SelectedTab = app.h.tabRes;   % jump to Results
                autoSave(app,Params);                  % write TrackedData.mat
                setStatus(app,sprintf('Manual tracking done: %d frames. Saved to %s', ...
                    numel(frameInd),Params.trackedSaveDir),false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function act = waitForAction(app,hFig) %#ok<INUSL>
            % Block (ROIs stay interactive) until the user acts:
            %   Space/Enter/Confirm button -> 'confirm'
            %   R -> 'redo' all (idx 0);  1..N -> 'redo' that structure
            %   Esc / closed window       -> 'cancel'
            act = struct('type','cancel','idx',0);
            if ~isvalid(hFig), return; end
            hFig.UserData = struct('action','','redoIdx',0);
            uiwait(hFig);
            if ~isvalid(hFig), return; end   % figure closed -> cancel
            switch hFig.UserData.action
                case 'confirm', act.type = 'confirm';
                case 'redo',    act.type = 'redo'; act.idx = hFig.UserData.redoIdx;
                otherwise,      act.type = 'cancel';
            end
        end

        function onMasterControls(app)
            % master checkbox selects/deselects all sub-controls; when off they
            % are also greyed out (only tunable while supervised controls are on)
            v = app.h.chkControls.Value;
            en = matlab.lang.OnOffSwitchState(v);
            subs = {'chkEnReinit','chkEnDeriv','chkEnMinMax','chkEnLenJump','chkEnPenn'};
            for k = 1:numel(subs)
                app.h.(subs{k}).Value  = v;
                app.h.(subs{k}).Enable = en;
            end
        end

        function onLoadResult(app)
            % load a previously tracked result (TrackedData.mat) and display it
            % on the Results tab (no re-tracking)
            [f,p] = uigetfile({'*.mat','Tracked results'}, ...
                'Select a TrackedData.mat to display');
            if ~ischar(f), return; end
            S = load(fullfile(p,f));
            if isfield(S,'Results'),            R = S.Results;
            elseif isfield(S,'ResultsFascicle'), R = S.ResultsFascicle;
            else, fn = fieldnames(S); R = S.(fn{1});
            end
            if ~isstruct(R) || isempty(fieldnames(R))
                setStatus(app,'ERROR: no results structure found in that file.',true); return;
            end
            refs = fieldnames(R);
            idx = 1;
            if numel(refs) > 1
                [idx,ok] = listdlg('ListString',refs,'SelectionMode','single', ...
                    'PromptString','Trial to display:');
                if ~ok, return; end
            end
            trial = refs{idx};
            if ~isfield(R.(trial),'fascicle')
                setStatus(app,'ERROR: selected trial has no fascicle data.',true); return;
            end
            app.Results.(trial) = R.(trial);
            app.TrialName = trial;
            app.h.edTrial.Value = trial;
            % use the stored frame rate for a correct time axis, if available
            if isfield(R.(trial),'Params') && isfield(R.(trial).Params,'framerate') ...
                    && R.(trial).Params.framerate > 0
                app.h.numFrameRate.Value = R.(trial).Params.framerate;
            end
            plotResults(app,R.(trial).fascicle);
            app.h.tg.SelectedTab = app.h.tabRes;
            setStatus(app,sprintf('Loaded result for display: %s',trial),false);
        end

        function onExportCSV(app)
            % export the displayed time series (+ EM-vs-manual metrics) to CSV
            try
                assert(~isempty(app.CurFascicle),'No results to export.');
                F = app.CurFascicle;
                fr = app.h.numFrameRate.Value; if fr<=0, fr=1; end
                def = 'results'; if ~isempty(app.TrialName), def = app.TrialName; end
                [f,p] = uiputfile('*.csv','Export time series as...',[def '_timeseries.csv']);
                if ~ischar(f), return; end
                base = fullfile(p,regexprep(f,'(_timeseries)?\.csv$',''));

                names = {}; S = {};
                if isfield(F,'automatic_EM') && isfield(F.automatic_EM,'pennation')
                    names{end+1}='EM';       S{end+1}=F.automatic_EM; end
                if isfield(F,'validate') && isfield(F.validate,'pennation')
                    names{end+1}='informed'; S{end+1}=F.validate; end
                if isfield(F,'manual') && isfield(F.manual,'pennation')
                    names{end+1}='pure';     S{end+1}=F.manual; end
                assert(~isempty(names),'No series to export.');

                allF = [];
                for i=1:numel(S), allF = union(allF,S{i}.trackFrames(:)); end
                allF = allF(:);
                T = table(allF,(allF-1)/fr,'VariableNames',{'frame','time_s'});
                for i=1:numel(S)
                    tf = S{i}.trackFrames(:); pv0 = S{i}.pennation(:); lv0 = S{i}.length(:);
                    m = min([numel(tf) numel(pv0) numel(lv0)]);
                    tf=tf(1:m); pv0=pv0(1:m); lv0=lv0(1:m);
                    [mem,loc] = ismember(allF,tf);
                    pv = nan(numel(allF),1); lv = nan(numel(allF),1);
                    pv(mem) = pv0(loc(mem)); lv(mem) = lv0(loc(mem));
                    T.([names{i} '_pennation_deg']) = pv;
                    T.([names{i} '_length_mm'])     = lv;
                end
                writetable(T,[base '_timeseries.csv']);

                % metrics (EM vs each manual)
                extra = '';
                if any(strcmp(names,'EM'))
                    em = S{strcmp(names,'EM')};
                    ne = min([numel(em.trackFrames) numel(em.pennation) numel(em.length)]);
                    emT = (em.trackFrames(1:ne).'-1)/fr; emP = em.pennation(1:ne); emL = em.length(1:ne);
                    M = cell(0,5);
                    for tgt = {'informed','pure'}
                        if any(strcmp(names,tgt{1}))
                            V = S{strcmp(names,tgt{1})};
                            nv = min([numel(V.trackFrames) numel(V.pennation) numel(V.length)]);
                            vt = (V.trackFrames(1:nv).'-1)/fr;
                            [rp,cp,np_] = agreementMetrics(emT,emP,vt,V.pennation(1:nv));
                            [rl,cl,nl_] = agreementMetrics(emT,emL,vt,V.length(1:nv));
                            M(end+1,:) = {['EM_vs_' tgt{1}],'pennation_deg',cp,rp,np_}; %#ok<AGROW>
                            M(end+1,:) = {['EM_vs_' tgt{1}],'length_mm',cl,rl,nl_};      %#ok<AGROW>
                        end
                    end
                    if ~isempty(M)
                        writetable(cell2table(M,'VariableNames', ...
                            {'comparison','metric','pearson_r','rmse','n'}),[base '_metrics.csv']);
                        extra = ' + _metrics.csv';
                    end
                end
                setStatus(app,['Exported ' base '_timeseries.csv' extra],false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function names = settingNames(~)
            % GUI input controls whose .Value is saved/restored as a preset
            names = {'numFrameRate','numHoughCut','numStart','numLast','numStep', ...
                'numValStep','numDepth','numProbe','numCropX','numCropY','numCropW', ...
                'numCropH','chkApo','chkFlip','numFas','numBlock','numPyr','numBiDir', ...
                'numMaxApo','numMaxFas','numThrApo','numThrFas','chkSaveVid','chkControls', ...
                'chkEnReinit','chkEnDeriv','chkEnMinMax','chkEnLenJump','chkEnPenn', ...
                'numReinitSeg','numLenJump','numPennMin','numPennMax','numMinMaxDiff', ...
                'numDerivFrac','chkShowEM','chkShowVal','chkShowMan'};
        end

        function onSaveSettings(app)
            try
                nm = settingNames(app); s = struct();
                for k = 1:numel(nm)
                    if isfield(app.h,nm{k}) && isvalid(app.h.(nm{k}))
                        s.(nm{k}) = app.h.(nm{k}).Value;
                    end
                end
                [f,p] = uiputfile('*.mat','Save settings as...','tracker_settings.mat');
                if ~ischar(f), return; end
                save(fullfile(p,f),'-struct','s');
                setStatus(app,['Saved settings to ' f],false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function onLoadSettings(app)
            try
                [f,p] = uigetfile('*.mat','Load settings...');
                if ~ischar(f), return; end
                s = load(fullfile(p,f));
                nm = settingNames(app);
                for k = 1:numel(nm)
                    if isfield(s,nm{k}) && isfield(app.h,nm{k}) && isvalid(app.h.(nm{k}))
                        try, app.h.(nm{k}).Value = s.(nm{k}); catch, end
                    end
                end
                onMasterControls(app);   % sync sub-control enabled state
                if ~isempty(app.CurFascicle), plotResults(app,app.CurFascicle); end
                setStatus(app,['Loaded settings from ' f],false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function onAbout(app)
            msg = sprintf([ ...
                'KLTsup - supervised KLT-based fascicle tracking\n\n' ...
                'Open-source MATLAB implementation of the KLTsup method:\n' ...
                'automatic FFT/Hough + KLT tracking with a supervision module,\n' ...
                'plus manual tracking, validation and comparison.\n\n' ...
                'How to cite:\n' ...
                'Cesti E. et al. Ultrasound-based methods to track skeletal muscle\n' ...
                'architecture in dynamic tasks: a comparative study. (year). DOI: [tbd]\n\n' ...
                'https://github.com/Carbonacho/KLTsup']);
            uialert(app.Fig,msg,'About KLTsup','Icon','info');
        end

        function [ini,iniEM,refParams] = loadReferenceInit(app)
            ini = struct(); iniEM = struct(); refParams = struct();
            [f,p] = uigetfile({'*.mat','Tracked results'},'Select a reference TrackedData.mat');
            if ~ischar(f), return; end
            S = load(fullfile(p,f));
            if isfield(S,'Results'), R = S.Results; else
                fn = fieldnames(S); R = S.(fn{1});
            end
            refs = fieldnames(R);
            idx = 1;
            if numel(refs) > 1
                [idx,ok] = listdlg('ListString',refs,'SelectionMode','single', ...
                    'PromptString','Reference trial for initialization:');
                if ~ok, return; end
            end
            ref = refs{idx};
            if isfield(R.(ref),'init') && isfield(R.(ref),'initEM') && isfield(R.(ref),'Params')
                ini = R.(ref).init; iniEM = R.(ref).initEM; refParams = R.(ref).Params;
                app.HasInit = true;
            else
                setStatus(app,['ERROR: reference is missing init/initEM/Params ' ...
                    '(save it from this app or from main_FFT_HFR, which store them).'],true);
            end
        end

        function onSave(app)
            if isempty(fieldnames(app.Results))
                setStatus(app,'Nothing to save yet.',true); return;
            end
            trial = app.TrialName;
            if isfield(app.Results,trial) && isfield(app.Results.(trial),'Params')
                outdir = app.Results.(trial).Params.trackedSaveDir;
            else
                outdir = fullfile(app.VideoFolder,'tracked');
            end
            if ~exist(outdir,'dir'), mkdir(outdir); end
            Results = app.Results; %#ok<PROPLC>
            save(fullfile(outdir,'TrackedData.mat'),'Results');
            setStatus(app,['Saved TrackedData.mat to ' outdir],false);
        end

        %% ------------------------------------------------- preview helpers
        function showFrame(app,idx)
            if isempty(app.PreviewVR), return; end
            idx = max(1,min(round(idx),app.NumFrames));
            app.CurFrame = idx;
            try
                img = read(app.PreviewVR,idx);
            catch
                return;
            end
            overlayOn = isfield(app.h,'chkOverlay') && app.h.chkOverlay.Value ...
                && ~isempty(app.CurFascicle) && ~isempty(app.TrialName) ...
                && isfield(app.Results,app.TrialName) ...
                && isfield(app.Results.(app.TrialName),'Params');
            if overlayOn
                % show the tracked (cropped/flipped) frame and overlay the lines,
                % so the tracked-line coordinates align directly
                P = app.Results.(app.TrialName).Params;
                if isfield(P,'cambiaredir') && P.cambiaredir==1, img = flip(img,2); end
                if isfield(P,'imCropRect'), img = imcrop(img,P.imCropRect); end
                imshow(img,'Parent',app.h.axPrev); hold(app.h.axPrev,'on');
                overlayTracked(app,idx);
                hold(app.h.axPrev,'off');
                title(app.h.axPrev,sprintf('Tracked overlay (frame %d)',idx));
            else
                if app.h.chkFlip.Value, img = flip(img,2); end
                imshow(img,'Parent',app.h.axPrev);
                cr = [app.h.numCropX.Value, app.h.numCropY.Value, ...
                      app.h.numCropW.Value, app.h.numCropH.Value];
                if all(cr(3:4) > 0)
                    hold(app.h.axPrev,'on');
                    rectangle(app.h.axPrev,'Position',cr,'EdgeColor',[1 1 0], ...
                        'LineWidth',1.5,'LineStyle','--');
                    hold(app.h.axPrev,'off');
                end
                title(app.h.axPrev,sprintf('Video preview (frame %d)',idx));
            end
            app.h.lblFrame.Text = sprintf('Frame %d / %d',idx,app.NumFrames);
            if app.h.sldFrame.Value ~= idx, app.h.sldFrame.Value = idx; end
            updateResultsCursor(app,idx);   % move the frame cursor on the Results plots
            updateReadout(app,idx);         % numeric length/pennation at this frame
        end

        function updateReadout(app,idx)
            if ~isfield(app.h,'lblReadout') || ~isvalid(app.h.lblReadout), return; end
            F = app.CurFascicle;
            if isempty(F), app.h.lblReadout.Text = ''; return; end
            parts = {seriesReadout(F,'automatic_EM','EM',idx), ...
                     seriesReadout(F,'validate','Inf',idx), ...
                     seriesReadout(F,'manual','Pure',idx)};
            parts = parts(~cellfun(@isempty,parts));
            app.h.lblReadout.Text = strjoin(parts,'     ');
        end

        function overlayTracked(app,idx)
            % overlay tracked lines for the nearest frame: EM (apo blue/yellow +
            % fascicle red), informed-manual (green fascicle), pure-manual
            % (magenta fascicle). Honours the Results show-toggles.
            F = app.CurFascicle; drewAny = false;
            if app.h.chkShowEM.Value && isfield(F,'automatic_EM')
                plotInsertionsAt(app,F.automatic_EM,idx,{[0 0.4 1],[1 0.9 0],[1 0 0]},'FAS',false);
                drewAny = true;
            end
            if app.h.chkShowVal.Value && isfield(F,'validate')
                plotInsertionsAt(app,F.validate,idx,{[0 1 0]},'Informed manual',true);
                drewAny = true;
            end
            if app.h.chkShowMan.Value && isfield(F,'manual')
                plotInsertionsAt(app,F.manual,idx,{[1 0 1]},'Pure manual',true);
                drewAny = true;
            end
            if drewAny, legend(app.h.axPrev,'show','Location','northeast'); end
        end

        function plotInsertionsAt(app,S,idx,colors,label,fascOnly)
            if ~isfield(S,'plotInsertions') || ~isfield(S,'trackFrames'), return; end
            tf = S.trackFrames(:);
            [~,j] = min(abs(tf - idx));         % nearest tracked frame
            if isempty(j) || numel(S.plotInsertions) < j, return; end
            pl = S.plotInsertions{j};
            for k = 1:numel(pl)
                if fascOnly && k < 3, continue; end   % manual: only the fascicle
                c = colors{min(k,numel(colors))};
                if k >= 3   % fascicle -> a legend entry
                    plot(app.h.axPrev,pl(k).x,pl(k).y,'Color',c,'LineWidth',2,'DisplayName',label);
                else        % aponeurosis -> exclude from legend
                    ln = plot(app.h.axPrev,pl(k).x,pl(k).y,'Color',c,'LineWidth',2);
                    ln.Annotation.LegendInformation.IconDisplayStyle = 'off';
                end
            end
        end

        function updateResultsCursor(app,idx)
            % vertical frame-cursor on the Results plots (embedded + pop-out)
            if isempty(app.CurFascicle), return; end
            fr = app.h.numFrameRate.Value; if fr<=0, fr=1; end
            t = (idx-1)/fr;
            app.h.vPenn  = cursorOn(app.h.axPenn , getField(app.h,'vPenn') , t);
            app.h.vLen   = cursorOn(app.h.axLen  , getField(app.h,'vLen')  , t);
            app.h.vHough = cursorOn(app.h.axHough, getField(app.h,'vHough'), idx);
            if isfield(app.h,'popPenn') && ~isempty(app.h.popPenn) && isvalid(app.h.popPenn)
                app.h.vPopPenn  = cursorOn(app.h.popPenn , getField(app.h,'vPopPenn') , t);
                app.h.vPopLen   = cursorOn(app.h.popLen  , getField(app.h,'vPopLen')  , t);
                app.h.vPopHough = cursorOn(app.h.popHough, getField(app.h,'vPopHough'), idx);
            end
        end

        function refreshPreview(app)
            if ~isempty(app.PreviewVR), showFrame(app,app.CurFrame); end
        end

        function previewFrameField(app,fld)
            % jump the preview to the frame typed into a First/Last frame field
            if ~isempty(app.PreviewVR), showFrame(app,fld.Value); end
        end

        function onFrameRateChanged(app)
            % re-scale the Results time axis if a tracked result is displayed
            if ~isempty(app.CurFascicle), plotResults(app,app.CurFascicle); end
        end

        function onSlider(app)
            stopPlay(app);
            showFrame(app,app.h.sldFrame.Value);
        end

        function onPlayToggle(app)
            if isempty(app.PreviewVR) || app.NumFrames < 2, return; end
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer) && ...
                    strcmp(app.PlayTimer.Running,'on')
                stopPlay(app); return;
            end
            fps = 12; % capped preview playback rate
            app.PlayTimer = timer('ExecutionMode','fixedRate', ...
                'Period',max(0.03,round(1/fps,3)),'BusyMode','drop', ...
                'TimerFcn',@(~,~)playStep(app));
            app.h.btnPlay.Text = 'Pause';
            start(app.PlayTimer);
        end

        function playStep(app)
            try
                nxt = app.CurFrame + 1;
                if nxt > app.NumFrames, nxt = 1; end
                showFrame(app,nxt);
            catch
                stopPlay(app);
            end
        end

        function stopPlay(app)
            if ~isempty(app.PlayTimer) && isvalid(app.PlayTimer)
                stop(app.PlayTimer); delete(app.PlayTimer);
            end
            app.PlayTimer = [];
            if isfield(app.h,'btnPlay') && isvalid(app.h.btnPlay)
                app.h.btnPlay.Text = 'Play';
            end
        end

        function onSetFirst(app)
            if isempty(app.PreviewVR), return; end
            app.h.numStart.Value = app.CurFrame;
            setStatus(app,sprintf('First frame set to %d.',app.CurFrame),false);
        end

        function onSetLast(app)
            if isempty(app.PreviewVR), return; end
            app.h.numLast.Value = app.CurFrame;
            setStatus(app,sprintf('Last frame set to %d.',app.CurFrame),false);
        end

        function onDrawCrop(app)
            if isempty(app.PreviewVR)
                setStatus(app,'Load a video first.',true); return;
            end
            stopPlay(app);
            setStatus(app,'Draw the crop rectangle on the preview (click-drag)...',false);
            try
                roi = drawrectangle(app.h.axPrev,'Color',[1 1 0]);
            catch ME
                setStatus(app,['Crop draw cancelled: ' ME.message],true); return;
            end
            if isempty(roi) || isempty(roi.Position)
                setStatus(app,'Crop draw cancelled.',true); return;
            end
            pos = round(roi.Position); % [x y w h] in frame pixels
            delete(roi);
            app.h.numCropX.Value = max(1,pos(1));
            app.h.numCropY.Value = max(1,pos(2));
            app.h.numCropW.Value = max(1,pos(3));
            app.h.numCropH.Value = max(1,pos(4));
            showFrame(app,app.CurFrame);
            setStatus(app,sprintf('Crop set to [x=%d y=%d w=%d h=%d].', ...
                app.h.numCropX.Value,app.h.numCropY.Value, ...
                app.h.numCropW.Value,app.h.numCropH.Value),false);
        end

        function onResetCrop(app)
            if app.PrevW > 0
                app.h.numCropX.Value = 1;      app.h.numCropY.Value = 1;
                app.h.numCropW.Value = app.PrevW; app.h.numCropH.Value = app.PrevH;
                showFrame(app,app.CurFrame);
                setStatus(app,'Crop reset to full frame.',false);
            end
        end

        function onClose(app)
            stopPlay(app);
            if isfield(app.h,'popFig') && ~isempty(app.h.popFig) && isvalid(app.h.popFig)
                delete(app.h.popFig);
            end
            delete(app.Fig);
        end

        %% --------------------------------------------------------- helpers
        function Params = buildParams(app,fr,step)
            % Geometry
            nx = app.h.numCropW.Value; ny = app.h.numCropH.Value;
            cx = app.h.numCropX.Value; cy = app.h.numCropY.Value;
            Params.isbiodex = 1;
            Params.viddir = app.VideoFolder;
            Params.nome_Video = app.TrialName;
            Params.imCropRect = [cx cy nx ny];
            Params.nx = nx; Params.ny = ny;
            Params.ulcornerx = cx; Params.ulcornery = cy;
            Params.px2mmX = app.h.numProbe.Value / nx;
            Params.px2mmY = app.h.numDepth.Value / ny;
            Params.framerate = fr;
            Params.downsampling_framerate = step;

            % Structure count: 2 aponeuroses + N fascicles
            Params.n_struct = app.h.numFas.Value + 2;

            % State counters (as reset in main_FFT_HFR.m)
            Params.ritracciati = 0; Params.Init = zeros(1,300);
            Params.cancellato = 0;
            Params.contatore1 = 0; Params.contatore2 = 0; Params.contatore3 = 0;
            Params.contatore4 = 0; Params.contatore5 = 0; Params.box = 0;

            % Acquisition options
            if app.h.chkApo.Value, Params.apo_visibile = 'yes';
            else,                  Params.apo_visibile = 'no '; % trailing space matches preprocessing.m
            end
            % --- fields normally set by the missing selezione_incl_fascicoli ---
            Params.cambiaredir = double(app.h.chkFlip.Value);
            scr = get(0,'ScreenSize');
            figwd = 700; fight = 700;
            Params.figPos = [0.1*(scr(3)-figwd), 0.1*(scr(4)-fight), figwd, fight];

            % Fill remaining defaults from the project file, then override
            Params = tracking_params(Params);

            % UI overrides (recompute derived pixel quantities)
            Params.userInputPyramidLevels = app.h.numPyr.Value;
            Params.userInputBlockSizemm  = app.h.numBlock.Value;
            bx = 2*round(((Params.userInputBlockSizemm/Params.px2mmX)+1)/2)-1;
            by = 2*round(((Params.userInputBlockSizemm/Params.px2mmY)+1)/2)-1;
            Params.userInputBlockSize = [bx by];
            Params.userInputBiDirect_mm = app.h.numBiDir.Value;
            Params.userInputMaxBiDirectionalError = ...
                round(Params.userInputBiDirect_mm/Params.px2mmX);

            Params.maxTrackingPts(1:2) = app.h.numMaxApo.Value;
            Params.redefinePtsThresh(1:2) = app.h.numThrApo.Value;
            for i = 3:Params.n_struct
                Params.maxTrackingPts(i) = app.h.numMaxFas.Value;
                Params.redefinePtsThresh(i) = app.h.numThrFas.Value;
            end
            Params.saveVideo = app.h.chkSaveVid.Value;
            Params.manualFrameStep = max(1,round(app.h.numValStep.Value)); % validation frame step

            Params.houghCutoff          = max(0.01,app.h.numHoughCut.Value);

            % supervised drift-correction controls (master + per-control enables)
            Params.useControls          = app.h.chkControls.Value;
            Params.ctrlEnReinit         = app.h.chkEnReinit.Value;
            Params.ctrlEnDeriv          = app.h.chkEnDeriv.Value;
            Params.ctrlEnMinMax         = app.h.chkEnMinMax.Value;
            Params.ctrlEnLenJump        = app.h.chkEnLenJump.Value;
            Params.ctrlEnPenn           = app.h.chkEnPenn.Value;
            Params.ctrlReinitSegments   = max(1,round(app.h.numReinitSeg.Value));
            Params.ctrlLenJumpThresh    = app.h.numLenJump.Value;
            Params.ctrlPennMin          = app.h.numPennMin.Value;
            Params.ctrlPennMax          = app.h.numPennMax.Value;
            Params.ctrlMinMaxDiffThresh = app.h.numMinMaxDiff.Value;
            Params.ctrlDerivAgreeFrac   = app.h.numDerivFrac.Value;
        end

        function plotResults(app,Fascicle)
            app.CurFascicle = Fascicle;   % remember so the frame-rate field can re-scale
            renderResults(app,Fascicle,app.h.axPenn,app.h.axLen,app.h.axHough);
            if isfield(app.h,'popPenn') && ~isempty(app.h.popPenn) && isvalid(app.h.popPenn)
                renderResults(app,Fascicle,app.h.popPenn,app.h.popLen,app.h.popHough);
            end
            updateResultsCursor(app,app.CurFrame);   % keep the frame cursor in sync
            updateReadout(app,app.CurFrame);
        end

        function renderResults(app,F,axP,axL,axH)
            % draw the three tracking series (EM auto / informed-manual / pure-
            % manual), honouring the show-toggles, into the given axes
            fr = app.h.numFrameRate.Value; if fr <= 0, fr = 1; end
            showEM  = app.h.chkShowEM.Value  && isfield(F,'automatic_EM') ...
                && isfield(F.automatic_EM,'pennation');
            showVal = app.h.chkShowVal.Value && isfield(F,'validate') ...
                && isfield(F.validate,'pennation');
            showMan = app.h.chkShowMan.Value && isfield(F,'manual') ...
                && isfield(F.manual,'pennation');

            cla(axP); cla(axL);
            emT=[]; emP=[]; emL=[];

            if showEM
                S = F.automatic_EM;
                [t,nn] = frameTime(S,numel(S.pennation),fr);
                p = S.pennation(:); l = S.length(:);
                emT = t; emP = p(1:nn); emL = l(1:nn);
                plot(axP,emT,emP,'r','DisplayName','Automatic');
                plot(axL,emT,emL,'b','DisplayName','Automatic');
                hold(axP,'on'); hold(axL,'on');
            end
            [vTp,vP,vTl,vL] = plotManualSeries(app,F,'validate',showVal,axP,axL,'g-o','Informed manual',fr);
            [mTp,mP,mTl,mL] = plotManualSeries(app,F,'manual'  ,showMan,axP,axL,'m-s','Pure manual'    ,fr);
            hold(axP,'off'); hold(axL,'off');

            if (showEM+showVal+showMan) >= 2
                legend(axP,'show','Location','best'); legend(axL,'show','Location','best');
            end
            title(axP,'Fascicle angle'); xlabel(axP,'Time (s)'); ylabel(axP,'Angle (deg)');
            title(axL,'Fascicle length'); xlabel(axL,'Time (s)'); ylabel(axL,'Length (mm)');

            % --- agreement readout (EM vs each manual) ---
            subP=''; subL='';
            if showEM && showVal
                [rp,cp,~]=agreementMetrics(emT,emP,vTp,vP); [rl,cl,~]=agreementMetrics(emT,emL,vTl,vL);
                subP=[subP sprintf('Inf: r=%.2f RMSE=%.2f%c  ',cp,rp,char(176))];
                subL=[subL sprintf('Inf: r=%.2f RMSE=%.2f mm  ',cl,rl)];
            end
            if showEM && showMan
                [rp,cp,~]=agreementMetrics(emT,emP,mTp,mP); [rl,cl,~]=agreementMetrics(emT,emL,mTl,mL);
                subP=[subP sprintf('Pure: r=%.2f RMSE=%.2f%c',cp,rp,char(176))];
                subL=[subL sprintf('Pure: r=%.2f RMSE=%.2f mm',cl,rl)];
            end
            subtitle(axP,subP); subtitle(axL,subL);

            % --- Hough: raw + filtered at chosen cutoff (frame axis) ---
            cla(axH);
            if isfield(F,'automatic_EM') && isfield(F.automatic_EM,'hough')
                rawH = F.automatic_EM.hough(:);
                plot(axH,rawH,'Color',[0.6 0.6 0.6],'DisplayName','raw');
                hold(axH,'on');
                fc = app.h.numHoughCut.Value; fNy = fr/2;
                if fc>0 && fc<fNy && numel(rawH)>18
                    [bh,ah] = butter(6,fc/fNy,'low');
                    plot(axH,filtfilt(bh,ah,rawH),'k','LineWidth',1.5, ...
                        'DisplayName',sprintf('filtered %.2f Hz',fc));
                elseif isfield(F.automatic_EM,'filtered_hough')
                    plot(axH,F.automatic_EM.filtered_hough,'k','DisplayName','filtered');
                end
                hold(axH,'off');
                legend(axH,'show','Location','best');
            end
            title(axH,'Hough signal (raw + filtered)');
            xlabel(axH,'Frame'); ylabel(axH,'Angle (deg)');
        end

        function [tp,yp,tl,yl] = plotManualSeries(app,F,fld,show,axP,axL,style,name,fr) %#ok<INUSL>
            tp=[]; yp=[]; tl=[]; yl=[];
            if ~show, return; end
            S = F.(fld);
            p = S.pennation(:); l = S.length(:);
            tt = frameTime(S,max(numel(p),numel(l)),fr);
            np = min(numel(tt),numel(p)); nl = min(numel(tt),numel(l));
            tp=tt(1:np); yp=p(1:np); tl=tt(1:nl); yl=l(1:nl);
            plot(axP,tp,yp,style,'MarkerSize',4,'LineWidth',1,'DisplayName',name);
            plot(axL,tl,yl,style,'MarkerSize',4,'LineWidth',1,'DisplayName',name);
            hold(axP,'on'); hold(axL,'on');
        end

        function onBlandAltman(app)
            % Bland-Altman: EM (auto) vs each available manual series, for
            % pennation and length, in a separate figure
            try
                assert(~isempty(app.CurFascicle),'No results yet.');
                F = app.CurFascicle;
                fr = app.h.numFrameRate.Value; if fr<=0, fr=1; end
                assert(isfield(F,'automatic_EM') && isfield(F.automatic_EM,'pennation'), ...
                    'Bland-Altman needs an automatic tracking result.');
                em = F.automatic_EM;
                ne = min([numel(em.trackFrames) numel(em.pennation) numel(em.length)]);
                emT = (em.trackFrames(1:ne).'-1)/fr; emP = em.pennation(1:ne); emL = em.length(1:ne);

                comps = {};
                if isfield(F,'validate') && isfield(F.validate,'pennation')
                    comps{end+1} = {'Informed manual',F.validate}; end
                if isfield(F,'manual') && isfield(F.manual,'pennation')
                    comps{end+1} = {'Pure manual',F.manual}; end
                assert(~isempty(comps),'Bland-Altman needs a manual series.');

                hF = figure('Name','Bland-Altman: EM vs manual','NumberTitle','off','Color','w');
                tl = tiledlayout(hF,numel(comps),2,'Padding','compact','TileSpacing','compact');
                for i = 1:numel(comps)
                    nm = comps{i}{1}; V = comps{i}{2};
                    nv = min([numel(V.trackFrames) numel(V.pennation) numel(V.length)]);
                    vt = (V.trackFrames(1:nv).'-1)/fr;
                    baPlot(nexttile(tl),emT,emP,vt,V.pennation(1:nv),[nm ' - pennation'],char(176));
                    baPlot(nexttile(tl),emT,emL,vt,V.length(1:nv),   [nm ' - length'],  'mm');
                end
                setStatus(app,'Bland-Altman plotted.',false);
            catch ME
                setStatus(app,['ERROR: ' ME.message],true);
            end
        end

        function onPopOut(app)
            if isempty(app.CurFascicle)
                setStatus(app,'Nothing to pop out yet.',true); return;
            end
            if isfield(app.h,'popFig') && ~isempty(app.h.popFig) && isvalid(app.h.popFig)
                figure(app.h.popFig); return;   % already open -> bring to front
            end
            app.h.popFig = uifigure('Name','Results (undocked)','Position',[220 120 720 720]);
            pgp = uigridlayout(app.h.popFig,[3 1]);
            app.h.popPenn  = uiaxes(pgp); app.h.popPenn.Layout.Row  = 1;
            app.h.popLen   = uiaxes(pgp); app.h.popLen.Layout.Row   = 2;
            app.h.popHough = uiaxes(pgp); app.h.popHough.Layout.Row = 3;
            plotResults(app,app.CurFascicle);   % renders into embedded + pop-out
        end

        function autoSave(app,Params)
            try
                if ~exist(Params.trackedSaveDir,'dir'), mkdir(Params.trackedSaveDir); end
                Results = app.Results; %#ok<PROPLC>
                save(fullfile(Params.trackedSaveDir,'TrackedData.mat'),'Results');
            catch
                % non-fatal; user can still Save... manually
            end
        end

        function setStatus(app,msg,isErr)
            app.h.status.Text = msg;
            if isErr, app.h.status.FontColor = [0.8 0 0];
            else,     app.h.status.FontColor = [0 0 0];
            end
            drawnow;
        end
    end
end

%% ============================ local UI helpers ============================
function addLabel(g,row,txt)
    l = uilabel(g,'Text',txt); l.Layout.Row = row; l.Layout.Column = 1;
end
function e = addNum(g,row,val)
    e = uieditfield(g,'numeric','Value',val);
    e.Layout.Row = row; e.Layout.Column = 2;
end
function e = addRO(g,row,txt)
    e = uilabel(g,'Text',txt,'FontColor',[0.3 0.3 0.3]);
    e.Layout.Row = row; e.Layout.Column = 2;
end
function addSection(g,row,txt)
    l = uilabel(g,'Text',txt,'FontWeight','bold','FontColor',[0.1 0.3 0.6]);
    l.Layout.Row = row; l.Layout.Column = [1 2];
end
function manualKeyPress(src,evt)
    % Space/Enter = confirm; R = redraw all lines; 1..N = redraw that line;
    % Esc = cancel the whole session.
    switch evt.Key
        case {'space','return'}
            src.UserData.action = 'confirm';  uiresume(src);
        case 'escape'
            src.UserData.action = 'cancel';   uiresume(src);
        case 'r'
            src.UserData.action = 'redo'; src.UserData.redoIdx = 0;  uiresume(src);
        case {'1','2','3','4','5','6'}
            src.UserData.action = 'redo'; src.UserData.redoIdx = str2double(evt.Key);
            uiresume(src);
    end
end
function manualConfirmBtn(hFig)
    hFig.UserData.action = 'confirm'; uiresume(hFig);
end
function s = manualLabel(i)
    if i==1,     s = 'DEEP aponeurosis';
    elseif i==2, s = 'SUPERFICIAL aponeurosis';
    else,        s = sprintf('FASCICLE %d',i-2);
    end
end
function [rmse,r,npair] = agreementMetrics(tEM,yEM,tMan,yMan)
    % RMSE and Pearson r between the auto (EM) and manual curves. The two are
    % sampled at different frames, so the EM curve is linearly interpolated
    % onto the manual sample times over their overlapping range.
    tEM=tEM(:); yEM=yEM(:); tMan=tMan(:); yMan=yMan(:);
    rmse=NaN; r=NaN; npair=0;
    if numel(tEM)<2 || numel(tMan)<1, return; end
    [tEMs,si] = sort(tEM); yEMs = yEM(si);
    [tEMu,ui] = unique(tEMs); yEMu = yEMs(ui);
    if numel(tEMu)<2, return; end
    emAtMan = interp1(tEMu,yEMu,tMan,'linear',NaN);   % NaN outside EM range
    valid = ~isnan(emAtMan) & ~isnan(yMan);
    npair = nnz(valid);
    if npair<2, return; end
    d = emAtMan(valid) - yMan(valid);
    rmse = sqrt(mean(d.^2));
    c = corrcoef(emAtMan(valid),yMan(valid));
    r = c(1,2);
end
function s = metricStr(rmse,r,npair,unit)
    if isnan(rmse)
        s = 'RMSE / r: not enough overlapping samples';
    else
        s = sprintf('RMSE = %.2f%s    r = %.2f    (n = %d)',rmse,unit,r,npair);
    end
end
function [a,b] = pairedValues(tEM,yEM,tMan,yMan)
    % pair EM and manual by interpolating EM onto the manual sample times
    a=[]; b=[];
    tEM=tEM(:); yEM=yEM(:); tMan=tMan(:); yMan=yMan(:);
    if numel(tEM)<2 || numel(tMan)<1, return; end
    [tu,ia] = unique(tEM); yu = yEM(ia);       % unique() returns sorted times
    if numel(tu)<2, return; end
    em = interp1(tu,yu,tMan,'linear',NaN);
    v = ~isnan(em) & ~isnan(yMan);
    a = em(v); b = yMan(v);                     % a = EM, b = manual
end
function baPlot(ax,tEM,yEM,tMan,yMan,ttl,unit)
    [a,b] = pairedValues(tEM,yEM,tMan,yMan);
    if numel(a) < 2
        title(ax,[ttl ' (insufficient overlap)']); axis(ax,'off'); return;
    end
    m = (a+b)/2; d = a - b;                      % EM - manual
    bias = mean(d); sd = std(d); lo = bias-1.96*sd; hi = bias+1.96*sd;
    scatter(ax,m,d,20,'filled','MarkerFaceColor',[0.2 0.4 0.8]); hold(ax,'on');
    yline(ax,bias,'-','Color',[0 0 0],'LineWidth',1);
    yline(ax,hi,'--','Color',[0.75 0 0]);
    yline(ax,lo,'--','Color',[0.75 0 0]);
    hold(ax,'off'); grid(ax,'on');
    xlabel(ax,['mean (' unit ')']); ylabel(ax,['auto - manual (' unit ')']);
    title(ax,sprintf('%s   bias=%.2f, LoA[%.2f, %.2f], n=%d',ttl,bias,lo,hi,numel(a)));
end
function s = seriesReadout(F,fld,label,idx)
    % "label: L=52.3mm  phi=18.4deg" for the series' nearest frame to idx
    s = '';
    if ~isfield(F,fld) || ~isfield(F.(fld),'pennation') || ~isfield(F.(fld),'trackFrames')
        return;
    end
    S = F.(fld); tf = S.trackFrames(:);
    [~,j] = min(abs(tf - idx));
    if isempty(j), return; end
    L = NaN; P = NaN;
    if numel(S.length)   >= j, L = S.length(j);   end
    if numel(S.pennation)>= j, P = S.pennation(j); end
    s = [' L=' num2str(L,'%.1f') 'mm  ' char(966) '=' num2str(P,'%.1f') char(176)];
end
function c = cursorOn(ax,c,val)
    % create the vertical frame-cursor if missing/deleted, else move it
    if isempty(c) || ~isvalid(c)
        c = xline(ax,val,'Color',[0.3 0.3 0.3]);
        c.Annotation.LegendInformation.IconDisplayStyle = 'off';
    else
        c.Value = val;
    end
end
function v = getField(s,f)
    if isfield(s,f), v = s.(f); else, v = []; end
end
function [t,nn] = frameTime(S,n,fr)
    % Time axis (s) from a Fascicle sub-struct's tracked frame numbers and a
    % frame rate: t(k) = (frame_k - 1)/fr. Reproduces the run's original time
    % axis when fr equals the frame rate used during tracking, and re-scales
    % it otherwise. Falls back to the stored .time if trackFrames is absent.
    if isfield(S,'trackFrames') && ~isempty(S.trackFrames)
        tf = S.trackFrames(:);
        nn = min(n,numel(tf));
        t  = (tf(1:nn) - 1)/fr;
    else
        tt = S.time(:);
        nn = min(n,numel(tt));
        t  = tt(1:nn);
    end
end
