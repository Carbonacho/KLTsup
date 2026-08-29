function [Data,Params,videoFrame0] = initializepoints(Data,Params,videoFrame,videoFrame_bordo_nero)

iniFrame = Data.trackFrames(1); % first frame to track
if nargin < 3
    %% read in video
    videoFileReader1 = VideoReader(Data.trialName); %read the mp4 file
    Data.originalVideoName = Data.trialName;
    NFrames = videoFileReader1.NumFrames;
    global subdir
    path = fullfile(tempdir,'VIDEO_Flipped.mp4'); % path where to save the flipped video (writable temp dir)
    videoFileReader = VideoWriter(path,'MPEG-4');
    open(videoFileReader);

%% set up the pre-processing progress bar
h = waitbar(0, 'Pre-processing progress...');  % progress bar
selectedInterval=1:length(Data.trackFrames);
totalSteps = length(selectedInterval);  % Total number of steps

    for frame=1:length(Data.trackFrames)
        % pre-processing
        [imm]=preprocessing(Params,frame,videoFileReader1);
%% Hough for the aponeuroses at frame 1
if frame==1
        SE=strel("rectangle",[3,3]);
imm_apo=imerode(imbinarize(imm),SE);
% Hough transform to detect the aponeurosis lines
theta_range = [70:0.1:89];
[selected_lines, centroids] = find_lines(imm_apo, theta_range, 400, 200, 70);
[partialLines, partialCentroids] = find_lines(imm_apo(1:100, :), theta_range, 400, 50, 5);
selected_lines = [selected_lines, partialLines];
centroids = [centroids; partialCentroids];
rowsWithZeros = any(centroids == 0, 2);
centroids = centroids(~rowsWithZeros, :);

for k = 1:length(selected_lines)
    % Compute the distance between the two points (line length)
    point1 = selected_lines(k).point1;
    point2 = selected_lines(k).point2;
    selected_lines(k).lunghezza = sqrt((point1(1) - point2(1))^2 + (point1(2) - point2(2))^2);
end
centroids = centroids(~rowsWithZeros, :); 
maxDiffs = max(abs(diff(centroids))); 

if maxDiffs(2)>200 %threshold to understand whether both the aponeuroses have been detected
    lines1=selected_lines(find(centroids(:,2)>250));
    lines2=selected_lines(find(centroids(:,2)<250));
    Params.linee_apon{1}=lines1;
    Params.linee_apon{2}=lines2;
    Params.centroidi_apon{1}=centroids(find(centroids(:,2)>250));
    Params.centroidi_apon{2}=centroids(find(centroids(:,2)<250));
    Params.da_tracciare_apo=0; 
elseif mean(centroids(:,2))>200
    Params.linee_apon{1}=selected_lines;
    Params.centroidi_apon{1}=centroids;
    Params.da_tracciare_apo1=0; 
    Params.da_tracciare_apo2=1;
elseif mean(centroids(:,2))<=200
    Params.linee_apon{2}=selected_lines;
    Params.centroidi_apon{2}=centroids;
    Params.da_tracciare_apo1=1; 
    Params.da_tracciare_apo2=0;
end
for y=1:2
for k=1:length(Params.linee_apon{y})
    point1 = Params.linee_apon{y}(k).point1;
    point2 = Params.linee_apon{y}(k).point2;
    Params.linee_apon{y}(k).lunghezza = sqrt((point1(1) - point2(1))^2 + (point1(2) - point2(2))^2);
end
end
lm_apo(1)=mean([Params.linee_apon{1}.lunghezza].'); %mean length calculation
lm_apo(2)=mean([Params.linee_apon{2}.lunghezza].');

for j=1:2
for i=1:length(Params.linee_apon{j})
        iLine1{j}(i,:)=Params.linee_apon{j}(i).point1;
        iLine2{j}(i,:)=Params.linee_apon{j}(i).point2;
        ang{j}(i)=Params.linee_apon{j}(i).theta;
end
end
for j=1:2
p25Lines{j} = prctile(ang{j}, 25);
p75Lines{j} = prctile(ang{j}, 75);
% "lines1" filtering according to percentiles and length calculation
    lineLengths = arrayfun(@(line) sqrt((line.point1(1) - line.point2(1))^2 + (line.point1(2) - line.point2(2))^2), Params.linee_apon{j});
    % dimensional check
    if length(ang{j}) == length(Params.linee_apon{j}) && length(lineLengths) == length(Params.linee_apon{j})
        % Filtering based on angles percentiles and segments length
        filteredLines{j} = Params.linee_apon{j}(...
            ang{j} >= p25Lines{j} & ...    % Angles >= 25th percentile
            ang{j} <= p75Lines{j} & ...    % Angles <= 75th percentile
            lineLengths > 0.5 * lm_apo(j));             % Length > 50% of lm_apo(j)
    else
        error('Dimension mismatch between ang{j}, lineLengths, and Params.linee_apon{j}');
    end
end
Params.linee_apon1 = filteredLines{1}; % update Params
Params.linee_apon2 = filteredLines{2};

mean1=mean(iLine1{1});mean2=mean(iLine2{1}); %aponeuroses thickness estimation
d=abs(diff(iLine1{1}));d2=abs(diff(iLine2{1}));
percentile_25 = prctile(d, 25); percentile_75 = prctile(d, 75);
aponeurosis_thickness = percentile_75 - percentile_25;
if aponeurosis_thickness(2)>8 && aponeurosis_thickness(2)<=25
Params.rectHt1=aponeurosis_thickness(2);
else
    Params.rectHt1=20;
end
if size(iLine1{2},1)>1
mean3=mean(iLine1{2});
mean4=mean(iLine2{2});
d=abs(diff(iLine1{2}));
percentile_25 = prctile(d, 25);
percentile_75 = prctile(d, 75);

aponeurosis_thickness = percentile_75 - percentile_25;
    if aponeurosis_thickness(2)>8 && aponeurosis_thickness(2)<=25
    Params.rectHt2=aponeurosis_thickness(2);
    else
        Params.rectHt2=10;
    end
else
    mean3=iLine1{2}; mean4=iLine2{2};
    Params.rectHt2=10;
end
Params.apon_media1=[mean1;mean2];
Params.apon_media2=[mean3;mean4];
m=mean([selected_lines.theta].');
s=std([selected_lines.theta].');
i=1;l=length([selected_lines.theta].');
while i<l
    if selected_lines(i).theta< m-2*s
        selected_lines(i)=[];
    end
    i=i+1;
    l=length([selected_lines.theta].');
end
figure,imshow(imm_apo);
hold on;
for j=1:2
for k = 1:length(filteredLines{j})
    xy = [filteredLines{j}(k).point1; filteredLines{j}(k).point2];
    plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'red');
end
end
end
%Fascicle Hough transform calculation
 [Data,Params]=hough_fas(Data,Params,imm,frame);

        Img=repmat(imm,[1,1,3]);
        writeVideo(videoFileReader,Img);
        waitbar(frame/totalSteps, h, sprintf('Pre-processing: %d%%', round(frame/totalSteps*100)));
    end
     close(h);

    % %Close the output video file
    close(videoFileReader);

    videoFileReader = vision.VideoFileReader(path);
    Data.trialName = path;
    for i = 1:iniFrame % step through to starting frame
        videoFrame = step(videoFileReader);
    end
    videoFrame = rgb2gray(videoFrame);

end

%% Get user input and define trackable points for all landmarks
videoFrame0 = videoFrame;
getuserinput = true;
%Data.frame(1).videoFrame= [];
while getuserinput
    videoFrame = videoFrame0;
    Data.frame(iniFrame).videoFrame = videoFrame;
    for i = 1:Params.n_struct
        if Data.manual == 0 %auto tracking
            if Data.traditionalDrazan
                Params.retrack=0; % equals 1 if the automatic aponeurosis initialization is not approved
            [Data,Params] = trackablepoints(Data,videoFrame,Params,i);
            if Params.retrack==1
                 for k=1:2
                 [Data,Params] = trackablepoints(Data,videoFrame,Params,k);

                 end
            end
            else
                if i<3
                 [Data,Params] = trackablepoints(Data,videoFrame,Params,i);
                else
                 [Data,Params] = trackablepoints(Data,videoFrame,Params,i,[],[],videoFrame_bordo_nero); %
                end
            end
        else % manual tracking
            [Data,Params] = trackablepoints_manual(Data,videoFrame,Params,i);
        end
    end
    close gcf
    %save
    pts1 = Data.frame(iniFrame).pts{1};
    pts2 = Data.frame(iniFrame).pts{2};
    nPts1 = size(pts1,1);
    nPts2 = size(pts2,1);

   Data.frame(iniFrame).points = [pts1;pts2];
   Data.frame(iniFrame).group = [1*ones(nPts1,1);2*ones(nPts2,1)];
   Data.frame(iniFrame).oPts = [nPts1;nPts2];
    for i=3:Params.n_struct
        pts=Data.frame(iniFrame).pts{i};
        nPts = size(pts,1);
        Data.frame(iniFrame).points = [Data.frame(iniFrame).points ;pts];
        Data.frame(iniFrame).group = [Data.frame(iniFrame).group;i*ones(nPts,1)];
        Data.frame(iniFrame).oPts = [Data.frame(iniFrame).oPts;nPts];
    end
    % calculate fascicle info
    Data.frame(iniFrame).fascicle = calculatefascicle(Data.frame(iniFrame),Params);

    fNy=Params.framerate/2;
    if isfield(Params,'houghCutoff'), fcH=Params.houghCutoff; else, fcH=1; end
    [b,a]=butter(6,fcH/fNy,"low");
    signal=Data.hough;
    signal=filtfilt(b,a,Data.hough);
    Data.filtered_hough=signal;
    [val,pos]=findpeaks(signal,MinPeakHeight=18);
    if length(pos)<=2
       [val,pos]=findpeaks(signal);
    end
    Params.punti_di_controllo=pos;

    % we have H, thus the angle and thus m
    % we have plotinsertions --> compute thickness
    % compute length from fascicle-deep apo intersection and m
    % find intersection with superficial apo and compute length
    min_H=min(Data.filtered_hough);
    max_H=max(Data.filtered_hough);
    apoInsertions=Data.frame.fascicle.plotInsertions;
    apo1x=apoInsertions(1).x; apo1y=apoInsertions(1).y;
    m_apo1=(diff(apo1y)./diff(apo1x));
    coeff_90 = -1/m_apo1;
    apo1MidX=(apo1x(1)+apo1x(2))/2; apo1MidY=(apo1y(1)+apo1y(2))/2;

    int_90 = apo1MidY - coeff_90 *apo1MidX;
    supLine = polyfit(apoInsertions(2).x,apoInsertions(2).y,1);

    x_int =(int_90-supLine(2))./(supLine(1)-coeff_90);
    y_int = coeff_90*x_int + int_90;
    muscle_thickness=sqrt((x_int-apo1MidX)^2+(y_int-apo1MidY)^2)*Params.px2mmY;

    insert_deep=Data.frame.fascicle.insertionDeep_px;

    m_min=tand(min_H);m_max=tand(max_H);
    FL_max=muscle_thickness/sind(min_H);
    FL_min=muscle_thickness/sind(max_H);
    Params.soglia_lunghezza=abs(FL_max-FL_min); %take 50% of the maximum variation
    % plot points
    videoFrame = plottrial(Data,videoFrame,Params,iniFrame);

    if ~Data.traditionalDrazan
        % EM pass: aponeuroses + fascicle are inherited from the traditional
        % pass, so accept automatically (no confirmation window)
        return;
    end

    figure('Position',Params.figPos)
    imshow(videoFrame)

    % plot and ask user for approval
    button = questdlg('Confirm points and lines','','Yes','No','Yes');

    if strcmp(button,'Yes')
        if nargin < 3
         release(videoFileReader);
        end
        close gcf
    return;
    end
    % otherwise repeat loop
    close gcf

end

end
function [selected_lines, centroids] = find_lines(imm_apo, theta_range, y_max, min_length, num_peaks)
    [H, theta, rho] = hough(double(imm_apo), 'Theta', theta_range);
    peaks = houghpeaks(H, num_peaks);
    lines = houghlines(imm_apo, theta, rho, peaks);
    selected_lines = [];
    centroids = [];
    for k = 1:length(lines)
        line_length = norm(lines(k).point1 - lines(k).point2);
        centroid = [(lines(k).point1(1) + lines(k).point2(1)) / 2, ...
                    (lines(k).point1(2) + lines(k).point2(2)) / 2];
        if line_length >= min_length && centroid(2) <= y_max
            selected_lines = [selected_lines, lines(k)];
            centroids = [centroids; centroid];
        end
    end
end
