function DataValidate = trackpoints_validate(Data,Params)
%% Manual validation of the fascicle after automatic tracking.
%  The aponeuroses are taken from the automatic track; the user only draws /
%  adjusts the fascicle. From the second sampled frame the previous fascicle
%  is pre-placed as a draggable line so it only needs nudging. On every frame:
%    SPACE / ENTER (or the Confirm button) = accept and advance
%    R = redraw all fascicles,  1..N = redraw that fascicle
%    Esc / close window = stop early (keeps the frames done so far)

DataValidate.manual = Data.manual;
DataValidate.validate = 1;
DataValidate.trialName = Data.trialName;

% frames to validate (stepped by the validation frame step)
frameInd = [Data.trackFrames(1):Params.manualFrameStep:Data.trackFrames(end)];
nFrames = length(frameInd);
n = 0;
frameCount = 1;

% Initialize video reader
videoFileReader = vision.VideoFileReader(Data.trialName);

DataValidate.trackFrames = frameInd;
DataValidate.imageTime = Data.mocapTime(frameInd);

% one reusable figure with confirm/redraw controls
hFig = figure('Name','Validation - adjust fascicle then confirm', ...
    'NumberTitle','off','WindowState','maximized', ...
    'KeyPressFcn',@vKey,'UserData',struct('action','','redoIdx',0));
hAx = axes('Parent',hFig);
uicontrol(hFig,'Style','pushbutton','String','Confirm (Space)', ...
    'Units','normalized','Position',[0.87 0.01 0.12 0.05], ...
    'Callback',@(s,e)vBtn(hFig));

prevPos = cell(1,Params.n_struct);   % previous fascicle line positions
cancelled = false;

while ~isDone(videoFileReader) && isvalid(hFig)

    % step the reader to the next frame to validate
    frame2track = frameInd(frameCount);
    while n < frame2track
        videoFrame = step(videoFileReader);
        n = n + 1;
    end

    DataValidate.frame(frameCount).points = [];
    DataValidate.frame(frameCount).group = [];

    % overlay the (automatic) aponeurosis lines on the frame
    videoFrame = plottrial(Data,videoFrame,Params,n,[1,2]);

    % reference fascicle to show as a guide: automatic on frame 1, else the
    % previously validated fascicle
    if frameCount == 1
        deepFascPts    = Data.frame(n).fascicle.insertionDeep_px;
        supFascPts     = Data.frame(n).fascicle.insertionSuperficial_px;
        plotInsertions = Data.frame(n).fascicle.plotInsertions;
    else
        deepFascPts    = DataValidate.frame(frameCount-1).fascicle.insertionDeep_px;
        supFascPts     = DataValidate.frame(frameCount-1).fascicle.insertionSuperficial_px;
        plotInsertions = DataValidate.frame(frameCount-1).fascicle.plotInsertions;
    end
    videoFrame = insertMarker(videoFrame,deepFascPts,'x','color','red','size',12);

    imshow(videoFrame,'Parent',hAx); hold(hAx,'on');
    plot(hAx,[deepFascPts(1) supFascPts(1)],[deepFascPts(2) supFascPts(2)],'w');
    plot(hAx,[plotInsertions(1).x(1) deepFascPts(1)],[plotInsertions(1).y(1) deepFascPts(2)],'r');
    plot(hAx,[supFascPts(1) plotInsertions(2).x(2)],[supFascPts(2) plotInsertions(2).y(2)],'r');
    plot(hAx,deepFascPts(1),deepFascPts(2),'xb');
    plot(hAx,supFascPts(1),supFascPts(2),'xb');
    hold(hAx,'off');

    % aponeuroses: keep the automatic ones (1 = deep, 2 = superficial)
    for i1 = 1:2
        for i2 = 1:2 % 1 = left, 2 = right end
            DataValidate.frame(frameCount).pts{i1}(i2,:) = ...
                [Data.frame(n).fascicle.plotInsertions(i1).x(i2), ...
                 Data.frame(n).fascicle.plotInsertions(i1).y(i2)];
        end
    end

    % fascicle(s): inherit the previous line as a draggable ROI, or draw it
    % on the first frame
    rois = gobjects(1,Params.n_struct);
    for i1 = 3:Params.n_struct
        if frameCount==1 || isempty(prevPos{i1})
            title(hAx,sprintf('Frame %d of %d: draw %s (click-drag)', ...
                n,frameInd(end),Params.landmarkString{i1}));
            rois(i1) = drawline(hAx,'Color','r');
            if ~isvalid(hFig) || ~isvalid(rois(i1)) || isempty(rois(i1).Position)
                cancelled = true; break;
            end
        else
            rois(i1) = images.roi.Line(hAx,'Position',prevPos{i1},'Color','r');
        end
    end
    if cancelled, break; end

    % adjust / redraw / confirm loop
    confirmed = false;
    while ~confirmed && isvalid(hFig)
        title(hAx,sprintf(['Frame %d of %d: drag to adjust | SPACE=confirm | ' ...
            'R=redraw fascicle | Esc=stop'],n,frameInd(end)));
        act = vWait(hFig);
        switch act.type
            case 'confirm'
                confirmed = true;
            case 'redo'
                if act.idx==0, idxs = 3:Params.n_struct; else, idxs = act.idx+2; end
                idxs = idxs(idxs>=3 & idxs<=Params.n_struct);
                for i1 = idxs
                    if isvalid(rois(i1)), delete(rois(i1)); end
                    title(hAx,sprintf('Frame %d of %d: REDRAW %s (click-drag)', ...
                        n,frameInd(end),Params.landmarkString{i1}));
                    rois(i1) = drawline(hAx,'Color','r');
                    if ~isvalid(hFig)||~isvalid(rois(i1))||isempty(rois(i1).Position)
                        cancelled = true; break;
                    end
                end
                if cancelled, break; end
            otherwise   % cancel / closed
                cancelled = true; break;
        end
    end
    if cancelled, break; end

    % store the confirmed fascicle line(s) and carry them to the next frame
    for i1 = 3:Params.n_struct
        p = rois(i1).Position;
        DataValidate.frame(frameCount).pts{i1} = p;
        prevPos{i1} = p;
    end
    delete(rois(isvalid(rois)));

    % calculate fascicle angle and length
    DataValidate.frame(frameCount).fascicle = calculatefascicle(DataValidate.frame(frameCount),Params);

    frameCount = frameCount + 1;
    if frameCount > nFrames
        break; % finished validation
    end
end

% Clean up
release(videoFileReader);
if isvalid(hFig), close(hFig); end

% if the user stopped early, trim the frame list to what was actually done
nDone = frameCount - 1;
if nDone < nFrames && nDone >= 1
    DataValidate.trackFrames = frameInd(1:nDone);
    DataValidate.imageTime   = Data.mocapTime(frameInd(1:nDone));
end

end

%% ---- local interaction helpers -------------------------------------------
function vKey(src,evt)
    % SPACE/ENTER=confirm, R=redraw all fascicles, 1..N=redraw one, Esc=stop
    switch evt.Key
        case {'space','return'}, src.UserData.action='confirm'; uiresume(src);
        case 'escape',           src.UserData.action='cancel';  uiresume(src);
        case 'r',                src.UserData.action='redo'; src.UserData.redoIdx=0; uiresume(src);
        case {'1','2','3','4','5','6'}
            src.UserData.action='redo'; src.UserData.redoIdx=str2double(evt.Key); uiresume(src);
    end
end
function vBtn(hFig)
    hFig.UserData.action='confirm'; uiresume(hFig);
end
function act = vWait(hFig)
    act = struct('type','cancel','idx',0);
    if ~isvalid(hFig), return; end
    hFig.UserData = struct('action','','redoIdx',0);
    uiwait(hFig);
    if ~isvalid(hFig), return; end   % figure closed -> cancel
    switch hFig.UserData.action
        case 'confirm', act.type='confirm';
        case 'redo',    act.type='redo'; act.idx=hFig.UserData.redoIdx;
        otherwise,      act.type='cancel';
    end
end
