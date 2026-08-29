function [Data,DataEM,Params,ParamsEM] = trackpoints(Data,DataEM,Params,ParamsEM)

Data.manual = 0;
DataEM.manual = 0;
frameIni = Data.trackFrames(1);
frameEnd = Data.trackFrames(end);

% backward-compatible defaults for the supervised-control settings (so an old
% Params saved before these fields existed does not error)
if ~isfield(ParamsEM,'useControls'),          ParamsEM.useControls = true;          end
if ~isfield(ParamsEM,'ctrlReinitSegments'),   ParamsEM.ctrlReinitSegments = 6;       end
if ~isfield(ParamsEM,'ctrlLenJumpThresh'),    ParamsEM.ctrlLenJumpThresh = 7.5;      end
if ~isfield(ParamsEM,'ctrlPennMin'),          ParamsEM.ctrlPennMin = 14;             end
if ~isfield(ParamsEM,'ctrlPennMax'),          ParamsEM.ctrlPennMax = 35;             end
if ~isfield(ParamsEM,'ctrlMinMaxDiffThresh'), ParamsEM.ctrlMinMaxDiffThresh = 0.1;   end
if ~isfield(ParamsEM,'ctrlDerivAgreeFrac'),   ParamsEM.ctrlDerivAgreeFrac = 0.3;     end
if ~isfield(ParamsEM,'ctrlEnReinit'),         ParamsEM.ctrlEnReinit  = true;         end
if ~isfield(ParamsEM,'ctrlEnDeriv'),          ParamsEM.ctrlEnDeriv   = true;         end
if ~isfield(ParamsEM,'ctrlEnMinMax'),         ParamsEM.ctrlEnMinMax  = true;         end
if ~isfield(ParamsEM,'ctrlEnLenJump'),        ParamsEM.ctrlEnLenJump = true;         end
if ~isfield(ParamsEM,'ctrlEnPenn'),           ParamsEM.ctrlEnPenn    = true;         end

% read in video file
videoFileReader = vision.VideoFileReader(Data.trialName);
for i = 1:frameIni % step through to starting frames
    videoFrame = step(videoFileReader);
end
videoFrame_bw = rgb2gray(videoFrame);
videoFrame_bwEM=DataEM.frame(frameIni).videoFrame;

%% Track points over trial
% initialize point tracker
% object 1 is high contrast (black and white) deep aponeourosis

pointTracker = vision.PointTracker('MaxBidirectionalError',Params.userInputMaxBiDirectionalError,...
    'NumPyramidLevels',Params.userInputPyramidLevels,'BlockSize',Params.userInputBlockSize);
points = Data.frame(frameIni).points;
group = Data.frame(frameIni).group;
initialize(pointTracker, points, videoFrame_bw)

%initialize the EM point tracker
pointTrackerEM = vision.PointTracker('MaxBidirectionalError',ParamsEM.userInputMaxBiDirectionalError,...
    'NumPyramidLevels',ParamsEM.userInputPyramidLevels,'BlockSize',ParamsEM.userInputBlockSize);
pointsEM = DataEM.frame(frameIni).points;
groupEM = DataEM.frame(frameIni).group;
initialize(pointTrackerEM, pointsEM,videoFrame_bwEM)

% Make a copy of the points to be used for computing the geometric
% transformation between the points in the previous and the current frames
oldPoints = points;
oldPointsEM=pointsEM;

if Params.displayTracking
    videoPlayerEM  = vision.VideoPlayer('Position',ParamsEM.figPos);
    videoFrameEM=repmat(videoFrame_bwEM,[1,1,3]);
    step(videoPlayerEM, videoFrameEM);
end

redefineInd = frameIni*ones(Params.n_struct,1);

n = frameIni+1;
ind1 = frameIni+1;
wrong = 0;
derivCounter=0;prevAgree=1;agree=1;
dialogBox=0;reinitPrev=zeros(1,4000);
%tissue_angle and trackable are called
while ~isDone(videoFileReader) % tracking and plotting main

%initialize flag for recalculting tracking points
Data.frame(n).redefinePtsFlag = zeros(Params.n_struct,1);
DataEM.frame(n).redefinePtsFlag = zeros(ParamsEM.n_struct,1);
% get the next frame
videoFrame = step(videoFileReader);
videoFrame_bw = rgb2gray(videoFrame);

% Track the points. Note that some points may be lost.
[points, isFound] = step(pointTracker, videoFrame_bw); 
%the step function applies the optical flow. Each time it is called it
%advances to the next frame!
% this block checks whether all points were found
visiblePoints = points(isFound, :);
oldInliers = oldPoints(isFound, :);

%% VARIOUS CHECKS
% below are the checks to make sure too many points are not lost
% PointTracker sees the error, and if it is too high, it removes the points
% restructure group array to account for removed tracking points
[~,ia,~] = setxor(oldPoints,oldInliers,'rows','stable'); %exclusive or.
group(ia) = [];

% check to redefine tracking points
n_npts = [size(group(group==1),1);size(group(group==2),1)];
n_opts = [Data.frame(redefineInd(1)).oPts(1);Data.frame(redefineInd(2)).oPts(2)];
for i=3:Params.n_struct
    n_npts = [n_npts; size(group(group==i),1)];
    n_opts = [n_opts; Data.frame(redefineInd(i)).oPts(i)];
end

nVisiblePoints = [];nGroup = [];
Params.clusterDistanceThreshold=10;
cluster_flag = false(1, Params.n_struct); % Initialize the flag vector
for i = 1:Params.n_struct
    iInd = (group == i); %take the points belonging to the i-th structure
    Data.frame(n).pts{i} = visiblePoints(iInd,:);
    iPtsThreshHit = (n_npts(i) / Data.frame(frameIni).oPts(i,1)) < Params.redefinePtsThresh(i); %compare the lost points relative to the first-frame points against the structure-specific threshold
     counter = 0;
        for k = 1:size(Data.frame(n).pts{i}, 1)
            for j = k+1:size(Data.frame(n).pts{i}, 1)
                distance = norm(Data.frame(n).pts{i}(k,:) - Data.frame(n).pts{i}(j,:)); % Compute the Euclidean distance between points
                if distance < Params.clusterDistanceThreshold
                    counter = counter + 1; % Increment the counter if the distance is below threshold
                end
            end
        end
        % Check whether the number of close point-pairs exceeds 10% of the possible point combinations and set the flag
        if counter > 0.1 * n_npts(i) * (n_npts(i) - 1) / 2 % total number of possible pairs
            % Set the flag to indicate that the points are clustered
            cluster_flag(i) = true; % this runs for all structures (apo and fascicle)
        end

    if i < 3 % aponeuroses --> the clustering criterion applies only here because it is easier
        iPtMin = min(Data.frame(n).pts{i}(:,1));
        iPtMax = max(Data.frame(n).pts{i}(:,1));
        iPtRange = (iPtMax-iPtMin) / Params.nx;
        iWidthThreshHit = iPtRange < Params.redefineWidthThresh(i);
        c=or(cluster_flag(1), cluster_flag(2));
        iWidthThreshHit=or(iWidthThreshHit,c);
    else % fascicle
        
        iWidthThreshHit=(cluster_flag(3));
    end
    redrawPts = or(iPtsThreshHit,iWidthThreshHit);
    %recompute the points if they are not good
    Data = trackablepoints(Data,videoFrame_bw,Params,i,Data.frame(n).pts{i},redrawPts);
    n_npts(i) = size(Data.frame(n).pts{i},1);
    nGroup = [nGroup;i*ones(n_npts(i),1)];
    nVisiblePoints = [nVisiblePoints;Data.frame(n).pts{i}];
end

%% update traditional pointTracker, save data into Data
Data.frame(n).oPts = n_npts;
visiblePoints = nVisiblePoints;
group = nGroup;

% store frame n points and group data
Data.frame(n).points = visiblePoints;
Data.frame(n).group = group;

% calculate fascicle angle and length
Data.frame(n).fascicle = calculatefascicle(Data.frame(n),Params);
% call plotting subroutines
videoFrame = plottrial(Data,videoFrame,Params,n);

% Reset the points
oldPoints = visiblePoints;
setPoints(pointTracker, oldPoints);

%% pointTrackerEM
% assign to DataEM the aponeuroses found in the traditional Data and
% prepare to overwrite group and points

DataEM.frame(n).pts{1}=Data.frame(n).pts{1};
DataEM.frame(n).pts{2}=Data.frame(n).pts{2};
nVisiblePointsEM=nVisiblePoints(find(nGroup<3),:);
nGroupEM=nGroup(find(nGroup<3),:);
[DataEM, videoFrame_bwEM,videoFrame_bwEM_black,y,h] = Tissue_angle(DataEM,videoFrame_bw,ParamsEM,n);
DataEM.frame(n).videoFrame = videoFrame_bwEM; %save the preprocessed frames to store a new video

% Track the points. Note that some points may be lost.
[pointsEM, isFound] = step(pointTrackerEM, videoFrame_bwEM);
visiblePointsEM = pointsEM(isFound, :);
oldInliersEM = oldPointsEM(isFound, :);
%% VARIOUS CHECKS on EM, to be done only on the fascicles

[~,ia,~] = setxor(oldPointsEM,oldInliersEM,'rows','stable');
groupEM(ia) = [];

% check to redefine tracking points

for i=3:ParamsEM.n_struct
    n_npts(i) = size(groupEM(groupEM==i),1);
    n_opts(i) = DataEM.frame(redefineInd(i)).oPts(i);
end
for i=3:ParamsEM.n_struct
    iInd = (groupEM== i);
    try
    DataEM.frame(n).pts{i} = visiblePointsEM(iInd,:);
    catch exception
        disp(exception.message)
    end
    iPtsThreshHit = (n_npts(i) / DataEM.frame(frameIni).oPts(i,1)) < ParamsEM.redefinePtsThresh(i); %compare the lost points relative to the first-frame points
    iPtMin = min(DataEM.frame(n).pts{i}(:,1));
    iPtMax = max(DataEM.frame(n).pts{i}(:,1));
    iPtRange = (iPtMax-iPtMin) / Params.nx;
    iWidthThreshHit = iPtRange < Params.redefineWidthThresh(i);
    %iWidthThreshHit = 0;
    %re-evaluate the points to track
    redrawPts = or(iPtsThreshHit,iWidthThreshHit);
    %split the video into N and recompute the points to fix drift (supervised)
    if ParamsEM.useControls && ParamsEM.ctrlEnReinit && n == ind1 + round(DataEM.trackFrames(end)/ParamsEM.ctrlReinitSegments)
        redrawPts=1;
        ind1=n;
    end
    %redrawPts=0;
    if wrong == 1
        if length(ParamsEM.landmarkString)>3
        DataEM.frame(n).pts(i:length(ParamsEM.landmarkString)) = {[]}; % empty the fascicle/aponeurosis ROI if wrong = 1
        else
            DataEM.frame(n).pts{i} = [];
        end
        wrong=0;
        ParamsEM.cancellato=1;
        Params.cancellato=1;
        ParamsEM.ritracciati=[Params.ritracciati;n-1];
        Params.ritracciati=[Params.ritracciati;n-1];
        Params.Init(n-1)=1;
        reinitPrev(n-1)=1;
    end
    close all
    [DataEM,ParamsEM] = trackablepoints(DataEM,videoFrame_bwEM,ParamsEM,i,DataEM.frame(n).pts{i},redrawPts, ...
        videoFrame_bwEM_black,n);
    % Remove the points on the border of the cropped rectangle
    %ind = find((DataEM.frame(n).pts{i}(:,2) > y-10) & (DataEM.frame(n).pts{i}(:,2) < y+10));
    ind = find(DataEM.frame(n).pts{i}(:,2) < y+15);
    DataEM.frame(n).pts{i}(ind,:) = [];
    %ind = find((DataEM.frame(n).pts{i}(:,2) > y+h-10) & (DataEM.frame(n).pts{i}(:,2) < y+h+10));
    ind = find(DataEM.frame(n).pts{i}(:,2) > y+h-5);
    DataEM.frame(n).pts{i}(ind,:) = [];

    n_npts(i) = size(DataEM.frame(n).pts{i},1);
    nGroupEM = [nGroupEM;i*ones(n_npts(i),1)];
    nVisiblePointsEM = [nVisiblePointsEM;DataEM.frame(n).pts{i}];
end
%% update pointTrackerEM
DataEM.frame(n).oPts = n_npts;
groupEM = nGroupEM;
DataEM.frame(n).points = nVisiblePointsEM;
DataEM.frame(n).group = groupEM;
DataEM.frame(n).fascicle = calculatefascicle(DataEM.frame(n),ParamsEM);
if ParamsEM.n_struct==3
angleList(n)=DataEM.frame(n).fascicle.pennation;
else
angleList(n,1:ParamsEM.n_struct-2)=DataEM.frame(n).fascicle.pennation;
end
if ParamsEM.useControls   % ===== supervised drift-correction controls (toggle) =====
tolerance=0.15*(mean(diff(Params.punti_di_controllo)));
        peakSpacing=mean(diff(Params.punti_di_controllo));
         prevWindow=round(0.3*peakSpacing);
 if n >0.4*Params.framerate+3  && n >= Params.punti_di_controllo(1) && n>prevWindow&& sum(reinitPrev(round(n-(0.4*Params.framerate-2)):n-1))==0
        sig1 = smoothdata(angleList(1:n),'movmean',round(0.2*Params.framerate)); % Filter the signal from 1 to n
        sig2 = Data.filtered_hough(1:n); % Hough signal already filtered
        sig1Norm=(sig1-min(sig1))./(max(sig1)-min(sig1)); %min-max scaling normalisation
        sig2Norm=(sig2-min(sig2))./(max(sig2)-min(sig2));
        %%% analysis of angle differences between the two filtered signals
        diffNorm =sig2Norm-sig1Norm; % Normalised difference up to n
        Params.differenza=diffNorm;
        ParamsEM.differenza=diffNorm;

        %% signal-trend analysis (derivative)
        peakSpacing=mean(diff(Params.punti_di_controllo));
         prevWindow=round(0.3*peakSpacing);
         prevDeriv=(diff(sig1(n-prevWindow:n-2))); %derivative over a window of samples (0.4*frame rate)
         prevDerivHough=diff(sig2(n-prevWindow:n-2));

         prevDeriv=prevDeriv>=0;
         prevDerivHough=prevDerivHough>=0;
         nAgree=sum(prevDeriv==prevDerivHough); % count of agreeing derivatives in the previous window

         currDeriv=diff(sig1(n-2:n-1));
         rising= currDeriv >0;
         derivHough=(diff(sig2(n-2:n-1)));
         if derivHough>0 & rising | derivHough<=0 & rising==0
            agree=1;
         elseif derivHough>0 & rising==0 | derivHough<=0 & rising
            agree=0;
         end
         Params.Init(n)=0;
         % if agree ==0
         %     derivCounter=derivCounter+1; %count of consecutive disagreeing derivatives
         % end

         win=(0.15*(mean(diff(Params.punti_di_controllo))));
         halfWin = floor(win/2);
          e=0; % flag for the third check (during shortening)
          for r=1:length(Params.punti_di_controllo)
          range=Params.punti_di_controllo(r)-halfWin:Params.punti_di_controllo(r)+halfWin;
          for k=1:length(range)
              if n==range(k)
                  diff_normalised=abs(sig1Norm(n)-sig2Norm(n));
                  if ParamsEM.ctrlEnMinMax && diff_normalised>ParamsEM.ctrlMinMaxDiffThresh
                      e=1;
                  end
              end
          end
          end

        if ((ParamsEM.ctrlEnDeriv && nAgree<=round(ParamsEM.ctrlDerivAgreeFrac*prevWindow)) ||e==1) && sum(Params.Init(n-(floor(0.4*Params.framerate)):n-1))==0
             wrong=1; % wrong=1 if the derivatives disagree consecutively for many samples (>tolerance, check 1), if the number of
             %agreeing derivatives is below 10% of the previous window
             %length (check 2), or if the min-max difference near the
             %Hough peak is larger than the set value
             if e==1
             ParamsEM.contatore3=ParamsEM.contatore3+1;
             end

            if (ParamsEM.ctrlEnDeriv && nAgree<=round(ParamsEM.ctrlDerivAgreeFrac*prevWindow))
                ParamsEM.contatore1=ParamsEM.contatore1+1;
            end

         end

wrong2=0;  val_change=0;
if n>=3
     wrong2= ParamsEM.ctrlEnLenJump && abs(DataEM.frame(n).fascicle.length(1) - DataEM.frame(n-1).fascicle.length(1)) > ParamsEM.ctrlLenJumpThresh; % frame-to-frame length jump (check 4)
     if wrong2==1
         ParamsEM.contatore4=ParamsEM.contatore4+1; % (check 4)
         val_change=1;
     end
     wrong3 = ParamsEM.ctrlEnPenn && (any((DataEM.frame(n).fascicle.pennation<ParamsEM.ctrlPennMin)) || any(DataEM.frame(n).fascicle.pennation>ParamsEM.ctrlPennMax));
     if wrong3==1
         ParamsEM.contatore5=ParamsEM.contatore5+1; % check no.5, on the difference between the aponeurosis angles and the tracked fascicle angle
     end
     wrong2=or(wrong2,wrong3);
end
wrong=or(wrong,wrong2);
if n>0.4*Params.framerate-2
if wrong==1 && dialogBox<=0 && sum(reinitPrev(round(n-(0.4*Params.framerate-2)):n-1))==0 % request only if wrong=1 and no retrack requested for a series of frames
    dialogBox=0;
% supervised control tripped -> ask whether to re-track (re-seed) the fascicle
button = lower(questdlg(sprintf(['Tracking looks wrong around frame %d.\n' ...
    'Re-track (re-seed) the fascicle here?'],n),'Supervised control','Yes','No','Yes'));
if isempty(button), button='no'; end
ParamsEM.box=ParamsEM.box+1;
             if strcmp(button,'yes') %&& sum(reinitPrev(n-round(tolerance):n-1))==0
                wrong=1;
                if val_change==1
                    DataEM.frame(n).fascicle.pennation=DataEM.frame(n-2).fascicle.pennation;
                    DataEM.frame(n-1).fascicle.pennation=DataEM.frame(n-2).fascicle.pennation;
                    DataEM.frame(n).fascicle.length=DataEM.frame(n-2).fascicle.length;
                    DataEM.frame(n-1).fascicle.length=DataEM.frame(n-2).fascicle.length;
                end
             else
                wrong=0;
                dialogBox=round(2*tolerance); % to avoid asking again on the next cycle
             end
elseif wrong==1
    wrong=0;
end
end

end
end   % ===== end supervised drift-correction controls =====
dialogBox=dialogBox-1;
videoFrameEM= repmat(videoFrame_bwEM,[1,1,3]);
videoFrameEM = plottrial(DataEM,videoFrameEM,ParamsEM,n);

% Reset the points
oldPointsEM = nVisiblePointsEM;

%update the pointtracker object
setPoints(pointTrackerEM, oldPointsEM);

%% Display the annotated video frame using the video player object
if Params.displayTracking
   %step(videoPlayer, videoFrame);
    step(videoPlayerEM,videoFrameEM)
end
% increment step count

redefineInd = [n,n]; %update indexing
for i=3:ParamsEM.n_struct
    redefineInd= [redefineInd,n];
end
n = n + 1;

if n > frameEnd
%         disp(sprintf('stopped tracking trial at frame %i',n-1))
    break; % break out of loop if frame count exceeds

end
end
%% Clean up
% release needed for the pointtracker and the videoreader
release(videoFileReader);
release(pointTracker);
release(pointTrackerEM);
if Params.displayTracking
    %release(videoPlayer);
    release(videoPlayerEM);
end
% end
