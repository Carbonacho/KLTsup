function [Fascicle,Data,DataEM,ParamsEM,init,init_EM] = trackfascicle(Data,Params,first,name,previousData,previousDataEM)

% Josh R Baxter, PhD - University of Pennsylvania
% joshrbaxter@gmail.com
% version history
% v1 - 2017-06-06 - main layout

% DEF !!!!

%% initialize tracking algorithm
% Data.trackFrames = frms; % passed thru function
% Data.trialName = ''; % full AVI path

% track points for trial
HoldData = Data; %hold Data struct in case reprocess is clicked
% Data is a structure that contains mocapTime, imagetime, track frame and
% the path of the trial selected
errorCount = 0;
while 1
    Data = HoldData;
    Data.manual = 0;
    DataEM.manual = 0;
    Data.validate = 0;
    Data.traditionalDrazan = 1;
    ParamsEM=Params;
    if first ==1 %initialize only if first==1 (first video)

        %initialization of feature points
        [Data,Params,videoFrame_bw] = initializepoints(Data,Params);
        % inside initializepoint: automatic aponeuroses estimation (Hough
        % transform for frame==1) and hough fascicle calculation ( the
        % function "hough_fas" is recalled)

        %processing with the FFT
        [DataEM,enhancedFrame,enhancedFrameBlack, ~, ~,Params]= Tissue_angle(Data,videoFrame_bw,Params,Data.trackFrames(1));
        DataEM.traditionalDrazan = 0;

        % features initialization with frequency processing
        [DataEM,ParamsEM] = initializepoints(DataEM,Params,enhancedFrame,enhancedFrameBlack); %feature point initialization with border
        init = Data;
        init_EM = DataEM;
    end
    try
        tic;
        if first == 0 % when the initialization is the same of a reference tracked video

            previousData.mocapTime =  Data.mocapTime;
            previousData.imageTime = Data.imageTime;
            previousData.trackFrames = Data.trackFrames;
            previousDataEM.mocapTime =  Data.mocapTime;
            previousDataEM.imageTime = Data.imageTime;
            previousDataEM.trackFrames = Data.trackFrames;

            videoFileReader1 = VideoReader(Data.trialName);
            NFrames = videoFileReader1.NumFrames;
            global subdir
            path = fullfile(tempdir,'VIDEO_Flipped_ref.mp4'); % path where to save the flipped video (writable temp dir)
            videoFileReader = VideoWriter(path,'MPEG-4');
            open(videoFileReader);

            for frame=1:length(Data.trackFrames)
                %same pre-processing as in the reference video
                [imm]=preprocessing(Params,frame,videoFileReader1);
                [Data,Params]=hough_fas(Data,Params,imm,frame); % Hough fascicle estimation

                % Write to video file
                Img=repmat(imm,[1,1,3]);
                writeVideo(videoFileReader,Img);
            end
            fNy=Params.framerate/2;
    if isfield(Params,'houghCutoff'), fcH=Params.houghCutoff; else, fcH=1; end
    [b,a]=butter(6,fcH/fNy,"low");
    Data.filtered_hough=filtfilt(b,a,Data.hough); %low-pass filtering to enhance peaks

    % figure,plot(segnale);hold on;
    [val,pos]=findpeaks(Data.filtered_hough,MinPeakHeight=18);
    if length(pos)<=2
       [val,pos]=findpeaks(Data.filtered_hough);
    end
    % title('Hough signal');
    %legend('Original','filtered');
    % xlabel('samples');ylabel('angle (deg)')
    Params.punti_di_controllo=pos;       %Hough transform peaks

    % we have H, thus the angle and thus m
    % we have plotinsertions --> compute thickness
    %compute length from fascicle-deep apo intersection and m
    % find intersection with superficial apo and compute length
    min_H=min(Data.filtered_hough);
    max_H=max(Data.filtered_hough);

    % valori=Data.frame.fascicle.plotInsertions;
    % apo1x=valori(1).x; apo1y=valori(1).y;
    % m_apo1=(diff(apo1y)./diff(apo1x));
    % coeff_90 = -1/m_apo1;
    % punto_centrale_apo1x=(apo1x(1)+apo1x(2))/2; punto_centrale_apo1y=(apo1y(1)+apo1y(2))/2;
    %
    % int_90 = punto_centrale_apo1y - coeff_90 *punto_centrale_apo1x;
    % retta_superficiale = polyfit(valori(2).x,valori(2).y,1);
    %
    % x_int =(int_90-retta_superficiale(2))./(retta_superficiale(1)-coeff_90);
    % y_int = coeff_90*x_int + int_90;
    % muscle_thickness=sqrt((x_int-punto_centrale_apo1x)^2+(y_int-punto_centrale_apo1y)^2)*Params.px2mmY;
    %
    % % insert_deep=Data.frame.fascicle.insertionDeep_px;
    %
    % m_min=tand(min_H);m_max=tand(max_H);
    % FL_max=muscle_thickness/sind(min_H);
    % FL_min=muscle_thickness/sind(max_H);
    % Params.soglia_lunghezza=abs(FL_max-FL_min);
            %Close the output video file
            close(videoFileReader);
            videoFileReader = vision.VideoFileReader(path);
            Data.trialName = path;
            previousData.trialName = path;
            previousDataEM.trialName = path;
            previousData.hough=Data.hough;
            previousData.filtered_hough=Data.filtered_hough;
            previousDataEM.hough=Data.hough;
            previousDataEM.filtered_hough=Data.filtered_hough;
            [Data,DataEM,Params,ParamsEM] = trackpoints(previousData,previousDataEM,Params,ParamsEM); % previous data was defined at the start of the loop; here the function updates it
            Data.trackTime = toc;

        elseif first == 1
            [Data,DataEM,Params,ParamsEM] = trackpoints(Data,DataEM,Params,ParamsEM);
            Data.trackTime = toc;
        end

        Data.flag = questdlg('Approve tracking trial','','Yes','Redo Autotrack','Validate','Yes');
    catch exception
        disp(exception.message);  % Show the error message
        disp(exception.identifier);  % Show the error identifier
        disp(exception.stack);  % Show the stack trace
        fprintf('tracking algorithm errored - please reselect aponeuroses and fascicle to track...\n')
        Data.flag = 'fail';
        errorCount = errorCount + 1;
    end


    switch lower(Data.flag)
        case {'yes','skip'}
            AutoData = Data;
            AutoDataEM=DataEM;
            break;
        case {'redo autotrack'}
            continue;
        case {'validate'}
            AutoData = Data;
            AutoDataEM = DataEM;
            Data.validate = 1; % set validate flag to 1
            ValidateData = trackpoints_validate(Data,Params);
            break;
    end
end

if strcmpi(Data.flag,'validate')
    nr = 3; %autodata and validatedata
else
    nr = 2; %autodata only
end

for i1 = 1:nr
    if i1 == 1
        thisData = AutoData;
        iField = 'automatic_traditional';
    elseif i1==2
        thisData = AutoDataEM;
        iField = 'automatic_EM';
    elseif i1==3
        thisData= ValidateData;
        iField = 'validate';
    end
    %save the structures into data: they go into fascicle
    Fascicle.(iField).time = [thisData.imageTime];
    Fascicle.(iField).sampleRate = 1 / mean(diff(thisData.imageTime));
    Fascicle.(iField).trackFrames = thisData.trackFrames;
    if i1~=3
    Fascicle.(iField).hough=thisData.hough;
    Fascicle.(iField).filtered_hough=thisData.filtered_hough;
    end
    for jF =thisData.trackFrames(1) :length(thisData.frame)
        j=jF-thisData.trackFrames(1)+1;
        Fascicle.(iField).length(j,:) = thisData.frame(jF).fascicle.length;
        Fascicle.(iField).pennation(j,:) = thisData.frame(jF).fascicle.pennation;
        % if i1==2 %we compute it only in the EM case for all frames and not in the traditional one
        % Fascicle.(iField).tissueAngle(j,:)=thisData.frame(jF).angletexture;
        % end
        Fascicle.(iField).insertDeep(:,:,j) = thisData.frame(jF).fascicle.insertionDeep_mm;
        Fascicle.(iField).insertSup(:,:,j) = thisData.frame(jF).fascicle.insertionSuperficial_mm;
        Fascicle.(iField).plotInsertions{j} = thisData.frame(jF).fascicle.plotInsertions;

        %aponeuroses distance
        deepLine = polyfit(thisData.frame(jF).fascicle.plotInsertions(1).x,thisData.frame(jF).fascicle.plotInsertions(1).y,1);
        deepMid = polyval(deepLine,round(thisData.frame(jF).fascicle.plotInsertions(1).x(2)-thisData.frame(jF).fascicle.plotInsertions(1).x(1))/2);
        supLine = polyfit(thisData.frame(jF).fascicle.plotInsertions(2).x,thisData.frame(jF).fascicle.plotInsertions(2).y,1);
        supMid = polyval(supLine,round(thisData.frame(jF).fascicle.plotInsertions(2).x(2)-thisData.frame(jF).fascicle.plotInsertions(2).x(1))/2);
        a = [thisData.frame(jF).fascicle.plotInsertions(1).y(1),deepMid,thisData.frame(jF).fascicle.plotInsertions(1).y(2)];
        b = [thisData.frame(jF).fascicle.plotInsertions(2).y(1),supMid,thisData.frame(jF).fascicle.plotInsertions(2).y(2)];
        Fascicle.(iField).aponeurosis_distance(j,1)=mean(a-b)*Params.px2mmY;

    end

    if (Params.saveVideo && i1 == 2)% save auto tracking video in both condition : traditional and EM

        [~,originalVideoName,~] = fileparts(thisData.originalVideoName);
        try
            fprintf('\tSaving tracked video %s...\n',name)
            % suppress warnings
            warning('off','all')
            if ~exist(Params.trackedSaveDir,'dir')
                mkdir(Params.trackedSaveDir)
            end
            if i1==1
                % open video to record
                videoFileReader = vision.VideoFileReader(thisData.trialName);
                videoSavePath = fullfile(Params.trackedSaveDir,[name,'_',iField,'.mp4']);
                TrackingVideo = VideoWriter(videoSavePath,'MPEG-4');
                %TrackingVideo.FrameRate =Params.framerate /Params.downsampling_framerate;
                TrackingVideo.Quality = 90;    % Default 75
                open(TrackingVideo);

                for i = 1:thisData.trackFrames(1) % step through to starting frames
                    videoFrame = step(videoFileReader);
                end

                for jF = thisData.trackFrames(1) :length(thisData.frame)

                    videoFrame = step(videoFileReader);
                    %videoFrame = imcrop(videoFrame,Params.imCropRect);
                    videoFrame = plottrial(thisData,videoFrame,Params,jF);
                    writeVideo(TrackingVideo,videoFrame);

                end
                close(TrackingVideo);
                warning('on','all')
            end
            if i1==2
                videoSavePath = fullfile(Params.trackedSaveDir,[name,'_',iField,'.mp4']);
                TrackingVideo = VideoWriter(videoSavePath,'MPEG-4');
                %TrackingVideo.FrameRate = Params.framerate /Params.downsampling_framerate;
                TrackingVideo.Quality = 90;    % Default 75
                open(TrackingVideo);
                for jF = thisData.trackFrames(1) :thisData.trackFrames(end)

                    videoFrame =repmat(thisData.frame(jF).videoFrame,[1,1,3]);
                    videoFrame = plottrial(thisData,videoFrame,ParamsEM,jF);
                    writeVideo(TrackingVideo,videoFrame);

                end
                close(TrackingVideo);
                warning('on','all')
            end
        catch exception
            disp(exception.message);  % Show the error message
            disp(exception.identifier);  % Show the error identifier
            disp(exception.stack);  % Show the stack trace

            warning(sprintf('Did not save tracked video of trial %s...',originalVideoName))
        end
    end


end

end % end function
