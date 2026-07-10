
clear variables; close all; clc;

% Ensure all pipeline subfolders (tracking, image_processing, ...) are on the path
% (this script lives in CODICE/scripts, so go up one level to the CODICE root)
addpath(genpath(fileparts(fileparts(mfilename('fullpath')))));

% Parameters
scrsz = get(0,'Screensize');
fight = 700;
figwd = 700;
scrx = 0.1 * (scrsz(3) - figwd);
scry = 0.1 * (scrsz(4) - fight);
probe = 'p6';

% Get trials and paths to process

% Data directory
global subdir
%subdir = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\From Github\ultrasound_tracking-master\'; % insert the main path in which the two subfolders code and Ultrasound can be found
subdir = 'E:\Tesi_Fra\Tracking\Clips';
datadir = fullfile(subdir);
datafiles = dir(fullfile(datadir,('*.mat')));
nfiles = size(datafiles);
if nfiles(1) > 1
    for i1 = 1:nfiles(1)
        datafileStr{i1} = datafiles(i1).name;
    end
    
    [s,v] = listdlg('PromptString','Select Data file to Analyze:',...
                'SelectionMode','single','ListString',datafileStr);
     dataname = datafiles(s).name;
else
     dataname = datafiles.name;
end
Data1 = load(fullfile(datadir,dataname));

% Load in param structure
paramsfiles = dir(fullfile(subdir,[probe,'*.mat']));
nparams = size(paramsfiles);
if nparams(1) > 1
    for i1 = 1:nparams(1)
        paramsStr{i1} = paramsfiles(i1).name;
    end
    [s,v] = listdlg('PromptString','Select Data file to Analyze:',...
                'SelectionMode','single','ListString',datafileStr);
    paramname = paramsfiles(s).name;
else
    paramname = paramsfiles.name;
end
load(fullfile(paramsfiles(1).folder,paramname));
Params.isbiodex = 1;
Params.viddir = datadir;

% Select trials to analyze

trialStr = fieldnames(Data1.clips);
[s,v] = listdlg('PromptString','Select Data file to Analyze:',...
                'SelectionMode','multiple','ListString',trialStr);
i1Trial = trialStr{s};
Params.nome_Video=i1Trial;
% view one frame and select the video box coordinates
%name = strsplit(trialStr{s},'_');
datadir = uigetdir(datadir,'Select the clip folder');
%tmp = input('Nome cartella contenente il video: ');
%datadir = fullfile(datadir,tmp);
% videoFileReader1 = VideoReader(fullfile(datadir,[trialStr{(s)},'.mp4'])); %lettura del file mp4
% immagine= read(videoFileReader1,1);figure, imshow(immagine), title('Seleziona i 4 vertici in senso orario dal vertice in alto a sinistra');
% [x,y]=ginput(4);
% Params.imCropRect = [x(1),y(1), x(3)-x(4), y(4)-y(1)];
x=[1;634;634;1];y=[1;1;632;632];
Params.imCropRect = [x(1),y(1), x(3)-x(4), y(4)-y(1)];
Params.nx = x(3)-x(4);
Params.ny = y(4)-y(1);
Params.ulcornerx = x(1);
Params.ulcornery = y(1);
%depth=input("inserire la depth dell'immagine (mm) "); %40 mm
depth=40;
%probeWidth=input("inserire dimensione probe (mm) "); % 40 mm
probeWidth=40;
Params.px2mmX=probeWidth/Params.nx; %mm-to-pixel conversion factor
Params.px2mmY=depth/Params.ny;
Params.framerate=Data1.clips.(trialStr{s}).framerate;
Params.downsampling_framerate=Data1.clips.(trialStr{s}).downsampleframerate;
%nFascicles=input('inserire il numero di fascicoli da traccare ');
nFascicles=1;
Params.n_struct=nFascicles+2;
Params.ritracciati=0;
Params.Init=zeros(1,300);
Params.cancellato=0;ParamsEM.cancellato=0;
Params.contatore1=0;Params.contatore2=0;
Params.contatore3=0;Params.contatore4=0;
Params.contatore5=0;Params.box=0;

%legend labels for the plots
legendLabels=cell(1,nFascicles);
for i=1:nFascicles
    legendLabels(i)={strcat('Fascicle'," ",num2str(i))};
end

imageType=questdlg('superficial aponeurosis visible','','yes','no ','yes');
Params.apo_visibile=imageType;
Params=selezione_incl_fascicoli(Params);
Params = tracking_params(Params);
% Save Params structure in saved directory
if ~exist(Params.trackedSaveDir,'dir')
    mkdir(Params.trackedSaveDir)
end
save(fullfile(Params.trackedSaveDir,[probe,'_params.mat']),'Params');

close all 

%% Full video
clear Fascicle Data DataEM Results
close all
Params.ritracciati=0;
Params.Init=zeros(1,300);
Params.cancellato=0;ParamsEM.cancellato=0;
Params.contatore1=0;Params.contatore2=0;
Params.contatore3=0;Params.contatore4=0;
Params.contatore5=0;Params.box=0;

first = 1;

i1Trial = trialStr{s};
fprintf('Processing %s...\n',i1Trial)
i1Data = Data1.clips.(i1Trial);
       
% track fascicles
TrackingData.trialName = fullfile(datadir,[i1Trial,'.mp4']); % setting the trial name
TrackingData.mocapTime = i1Data.time; % time vector 
TrackingData.imageTime = i1Data.time(i1Data.frameInds); % extracting from the time vector the time instants of the frames selected 
TrackingData.trackFrames = (i1Data.start:i1Data.downsampleframerate:i1Data.frameInds(end)); % number of frames to track (row vector)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

[Fascicle,Data,DataEM,Params,init,initEM] = trackfascicle(TrackingData,Params,first,i1Trial);     %%%%%%%%% IMPORTANT - DOES EVERYTHING HERE

%store tracked data into data structure
Results.(i1Trial).fascicle = Fascicle;
Results.(i1Trial).init = init;
Results.(i1Trial).initEM = initEM;
% Results.(i1Trial).Data = Data;
% Results.(i1Trial).DataEM = DataEM;
Results.(i1Trial).Params = Params;
% modify if analysing a single video
length_tot(:,i) = Fascicle.automatic_EM.length(1);
pennation_tot(:,i) = Fascicle.automatic_EM.pennation(1);
time = Fascicle.automatic_EM.time;
%te(:,i)=DataEM.frame.angletexture;


 figure
 subplot(1,3,1)
%for i =1:length(pennation_tot(1,:))
% 
%plot(Fascicle.automatic_EM.time  , Fascicle.automatic_EM.tissueAngle);hold on
plot(Fascicle.automatic_EM.time(1:length(Fascicle.automatic_EM.pennation))  ,Fascicle.automatic_EM.pennation,'r');
xlabel('Time(s)')
ylabel('Angle (deg)')
legend('traditional')
title('Pennation angle')
%    % hold on
% 
% %end 
 subplot(1,3,2)
 signal=Data.filtered_hough(1:length(Fascicle.automatic_EM.pennation));
 
 % freqz(b,a,512,512)
 signal_orig_f=smoothdata(Fascicle.automatic_EM.pennation,'movmean',round(0.2*Params.framerate));
 plot(Fascicle.automatic_EM.time(1:length(Fascicle.automatic_EM.pennation)) ,signal./max(signal),'b');hold on
 plot(Fascicle.automatic_EM.time(1:length(Fascicle.automatic_EM.pennation)) ,signal_orig_f./max(signal_orig_f),'r');
 xlabel('time (s)')
 ylabel('normalised angle')
 legend('filtered Hough','traditional')
 title('Pennation Angle')
 subplot(1,3,3)
 plot(Fascicle.automatic_EM.time(1:length(Fascicle.automatic_EM.pennation))  ,Fascicle.automatic_EM.length);
 xlabel('time (s)')
 ylabel('length (mm)')
 title('Fascicle Length')

% ind=find(Fascicle.automatic_EM.length>80);
% if ~isempty(ind)
%     for i=1:length(ind)
%     Fascicle.automatic_EM.length(ind(i))=Fascicle.automatic_EM.length(ind(i)-1);
%     Fascicle.automatic_EM.pennation(ind(i))=Fascicle.automatic_EM.pennation(ind(i)-1);
% 
%     end
% end
% 
% ind=find(Fascicle.automatic_EM.pennation>35);
% if ~isempty(ind)
%     for i=1:length(ind)
%     Fascicle.automatic_EM.length(ind(i))=Fascicle.automatic_EM.length(ind(i)-1);
%     Fascicle.automatic_EM.pennation(ind(i))=Fascicle.automatic_EM.pennation(ind(i)-1);
% 
%     end
% end
% save Data structure to tracked folder after each run...
write2mat = fullfile(Params.trackedSaveDir,'TrackedData.mat');
save(write2mat,'Results')       
fprintf('Tracking complete - data saved!\n')


%% One manual

subdir_man = 'C:\Users\franc\Desktop\Tesi\Video\manual';
datadir_man = fullfile(subdir_man);
DataT = uigetdir((datadir_man),'select the corresponding manual tracking ');
datafiles = dir(fullfile(DataT,('*.mat')));
for i1 = 1:length(datafiles)
        datafileStr{i1} = datafiles(i1).name;
end
[selectedIndex, ok] = listdlg('ListString', datafileStr, 'SelectionMode', 'single', 'PromptString', 'Select a subfolder');
load(fullfile(DataT,datafiles(selectedIndex).name));



%%%%%%%%%
%normalise the value at the start, to make the manual independent of the
%fascicolo tracciato
%%%%%%%% CONSIDER ADDING A BUTTON FOR AN ANTI-DRIFT HIGH-PASS
button4=questdlg('Drift observed?','','yes','no','no');
if strcmp (button4,'yes')
    [b,a]=butter(3,0.4/Params.framerate/2,"high");
    e=filtfilt(b,a,Fascicle.automatic_EM.pennation);
    f=filtfilt(b,a,Fascicle.automatic_EM.length);
    Fascicle.automatic_EM.pennation=e+mean(Fascicle.automatic_EM.pennation  );
    Fascicle.automatic_EM.length=f+mean(Fascicle.automatic_EM.length  );
end
frr=(round(length(eval(['Fascicle.automatic_EM.trackFrames']))/max(eval(['Fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;

% tmp1=smoothdata(Fascicle.automatic_EM.pennation, 'movmean',window_length);tmp1=tmp1(1);
% tmp2=smoothdata(manual.pennation, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
% idx=tmp1>tmp2;
% if idx==1
%     manual.pennation=manual.pennation+abs(tmp1-tmp2);
% else
%     manual.pennation=manual.pennation-abs(tmp1-tmp2);
% end
% 
% tmp1=smoothdata(Fascicle.automatic_EM.length, 'movmean',window_length);tmp1=tmp1(1);
% tmp2=smoothdata(manual.length, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
% idx=tmp1>tmp2;
% if idx==1
%     manual.length=manual.length+abs(tmp1-tmp2);
% else
%     manual.length=manual.length-abs(tmp1-tmp2);
% end

addpath("BlandAltman")
% 
figure
t = Fascicle.automatic_EM.time;
lenEM = smoothdata(Fascicle.automatic_EM.length, 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man(1:length(len_man)),len_man,'g','LineWidth',1)
 legend('em','val')
xlabel('Time(s)')
ylabel('Length(mm)')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len,corr_coeff_fl] = getMetrics(lenEM, len_man, t(1:length(lenEM)), t_man(1:length(len_man))); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),' Spearman corr coef -->',num2str(corr_coeff_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t = Fascicle.automatic_EM.time;
pennEM =  smoothdata(Fascicle.automatic_EM.pennation, 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man(1:length(penn_man)),penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coeff_pa] = getMetrics(pennEM, penn_man, t(1:length(pennEM)), t_man(1:length(penn_man)));
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),' Spearman corr coef -->',num2str(corr_coeff_pa));
sgtitle(title_m)
r=3;

%% Load old initialization

clear Fascicle Data DataEM Results

% Old initialization

path = 'C:\Users\franc\Desktop\Tesi\Video\tracked\PAw2_50FDMAS_20241107_115025\TrackedData.mat';
load(path)

ref = 'PAw2_50FDMAS';

% init = Results.(ref).Data;    
% init.frame = Results.(ref).Data.frame(1);
% init.trackFrames = Results.(ref).Data.trackFrames; init.mocapTime = Results.(ref).Data.mocapTime; init.imageTime = Results.(ref).Data.imageTime;
% initEM = Results.(ref).DataEM;
% initEM.frame = Results.(ref).DataEM.frame(1);
% initEM.trackFrames = Results.(ref).DataEM.trackFrames; initEM.mocapTime = Results.(ref).DataEM.mocapTime; initEM.imageTime = Results.(ref).DataEM.imageTime;
trackedSaveDir = Params.trackedSaveDir;
Params = Results.(ref).Params;
Params.trackedSaveDir = trackedSaveDir;
Params.ritracciati=0;
Params.Init=zeros(1,300);
Params.cancellato=0;ParamsEM.cancellato=0;
Params.contatore1=0;Params.contatore2=0;
Params.contatore3=0;Params.contatore4=0;
Params.contatore5=0;Params.box=0;
Params.box=0;
% aggiunta per cambiare il framerate
f=strsplit(i1Trial,'_');
num_str = regexp(f{2}, '\d+', 'match');  % Estrae le cifre
num = str2double(num_str{1}); 
Params.framerate=num;

init = Results.(ref).init;
initEM = Results.(ref).initEM;
first = 0;

% Params from previous initialization 
% Params.rectHt(1) = 11;
%Params.redefinePtsThresh(3) = 0.7;
% Params.nx = 632; Params.ny = 628; 
% Params.imCropRect = [0,0,632,628];

i1Trial = trialStr{s};
fprintf('Processing %s...\n',i1Trial)
i1Data = Data1.clips.(i1Trial);

% track fascicles
TrackingData.trialName = fullfile(datadir,[i1Trial,'.mp4']); % setting the trial name
TrackingData.mocapTime = i1Data.time; % time vector 
TrackingData.imageTime = i1Data.time(i1Data.frameInds); % extracting from the time vector the time instants of the frames selected 
TrackingData.trackFrames = (i1Data.start:i1Data.downsampleframerate:i1Data.frameInds(end)); % number of frames to track (row vector)   %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% TrackingData.frame.fascicle.plotInsertions=i1Data.frame.fascicle.plotInsertions;
[Fascicle,Data,DataEM,Params] = trackfascicle(TrackingData,Params,first,i1Trial,init,initEM);

%store tracked data into data structure
ResultsFascicle.(i1Trial).fascicle = Fascicle;
ResultsFascicle.(i1Trial).Params = Params;
ResultsFascicle.(i1Trial).ritracciati=length(Params.ritracciati)-1;
ResultsFascicle.(i1Trial).box=Params.box;

% ResultsData.(i1Trial).Data = Data;
% ResultsDataEM.(i1Trial).DataEM = DataEM;

ind=find(Fascicle.automatic_EM.length>85);
if ~isempty(ind)
    for i=1:length(ind)
    Fascicle.automatic_EM.length(ind(i))=Fascicle.automatic_EM.length(ind(i)-1);
    Fascicle.automatic_EM.pennation(ind(i))=Fascicle.automatic_EM.pennation(ind(i)-1);

    end
end

ind=find(Fascicle.automatic_EM.pennation>35);
if ~isempty(ind)
    for i=1:length(ind)
    Fascicle.automatic_EM.length(ind(i))=Fascicle.automatic_EM.length(ind(i)-1);
    Fascicle.automatic_EM.pennation(ind(i))=Fascicle.automatic_EM.pennation(ind(i)-1);

    end
end
ResultsFascicle.(i1Trial).fascicle = Fascicle;
ResultsFascicle.(i1Trial).Params = Params;
ResultsFascicle.(i1Trial).ritracciati=length(Params.ritracciati)-1;
ResultsFascicle.(i1Trial).box=Params.box;



% save Data structure to tracked folder after each run...
write2mat = fullfile(Params.trackedSaveDir,'TrackedData_fascicle.mat');
save(write2mat,'ResultsFascicle') 
% write2mat = fullfile(Params.trackedSaveDir,'TrackedData_data.mat');
% save(write2mat,'ResultsData') 
fprintf('Tracking complete - data saved!\n')

%% salvataggio dei tracking manuali
% %i1Trial='PEhr1_25FDMAS';
button2=questdlg('Did you perform manual tracking?','','yes','no','yes');
if strcmp(button2,'yes')
fullPath='C:\Users\franc\Desktop\Tesi\Video\manual\';
r=[fullPath,'manual_',i1Trial,'.mat'];
manual=eval(['Fascicle.validate']);
save(r,'manual');
end
% l=smoothdata(manual.length,'movmean',5);
% figure,plot(manual.time(1:112),l);hold on
% plot(Results.PFw2_25FDMAS.fascicle.automatic_EM.time(1:223), Results.PFw2_25FDMAS.fascicle.automatic_EM.length);

%% One manual
%%%%%%%%%
%normalise the value at the start, to make the manual independent of the
%fascicolo tracciato
%%%%%%%% CONSIDER ADDING A BUTTON FOR AN ANTI-DRIFT HIGH-PASS
button4=questdlg('Drift observed?','','yes','no','no');
if strcmp (button4,'yes')
    [b,a]=butter(3,0.5/Params.framerate/2,"high");
    e=filtfilt(b,a,Fascicle.automatic_EM.pennation);
    f=filtfilt(b,a,Fascicle.automatic_EM.length);
    Fascicle.automatic_EM.pennation=e+mean(Fascicle.automatic_EM.pennation  );
    Fascicle.automatic_EM.length=f+mean(Fascicle.automatic_EM.length  );
end
frr=(round(length(eval(['Fascicle.automatic_EM.trackFrames']))/max(eval(['Fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;

% tmp1=smoothdata(Fascicle.automatic_EM.pennation, 'movmean',window_length);tmp1=tmp1(1);
% tmp2=smoothdata(manual.pennation, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
% idx=tmp1>tmp2;
% if idx==1
%     manual.pennation=manual.pennation+abs(tmp1-tmp2);
% else
%     manual.pennation=manual.pennation-abs(tmp1-tmp2);
% end
% 
% tmp1=smoothdata(Fascicle.automatic_EM.length, 'movmean',window_length);tmp1=tmp1(1);
% tmp2=smoothdata(manual.length, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
% idx=tmp1>tmp2;
% if idx==1
%     manual.length=manual.length+abs(tmp1-tmp2);
% else
%     manual.length=manual.length-abs(tmp1-tmp2);
% end

addpath("BlandAltman")
% 
figure
t = Fascicle.automatic_EM.time;
lenEM = smoothdata(Fascicle.automatic_EM.length, 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man(1:length(len_man)),len_man,'g','LineWidth',1)
 legend('em','val')
xlabel('Time(s)')
ylabel('Length(mm)')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len,corr_coeff_fl] = getMetrics(lenEM, len_man, t(1:length(lenEM)), t_man(1:length(len_man))); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),' Spearman corr coef -->',num2str(corr_coeff_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t = Fascicle.automatic_EM.time;
pennEM =  smoothdata(Fascicle.automatic_EM.pennation, 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man(1:length(penn_man)),penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coeff_pa] = getMetrics(pennEM, penn_man, t(1:length(pennEM)), t_man(1:length(penn_man)));
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),' Spearman corr coef -->',num2str(corr_coeff_pa));
sgtitle(title_m)

%figure,plot(Results.PFhr3_25DAS.fascicle.automatic_EM.filtered_hough)

%% Results loading
%caricamento tracking automatico
subdir = 'C:\Users\franc\Desktop\Tesi\Video\tracked';
datadir = fullfile(subdir);
DataT = uigetdir((datadir),'select the tracked video');
datafiles = dir(fullfile(DataT,('*.mat')));
load(fullfile(DataT,datafiles(1).name));
[~, file_name, ~] = fileparts(DataT);
split_name = split(file_name, '_');
name = strcat(split_name{1}, '_', split_name{2});
%caricamento tracking manuale corrispondente
subdir = 'C:\Users\franc\Desktop\Tesi\Video\manual_mediati';
datadir = fullfile(subdir);
DataT = uigetdir((datadir),'select the corresponding manual tracking ');
datafiles = dir(fullfile(DataT,('*.mat')));
for i1 = 1:length(datafiles)
        datafileStr{i1} = datafiles(i1).name;
end
[selectedIndex, ok] = listdlg('ListString', datafileStr, 'SelectionMode', 'single', 'PromptString', 'Select a subfolder');
load(fullfile(DataT,datafiles(selectedIndex).name));

button4=questdlg('Drift observed?','','yes','no','no');
if strcmp (button4,'yes')
    [b,a]=butter(3,0.5/(eval(['Results.',name,'.Params.framerate'])/2),"high");
    e=filtfilt(b,a,eval(['Results.',name,'.fascicle.automatic_EM.pennation']));
    f=filtfilt(b,a,eval(['Results.',name,'.fascicle.automatic_EM.length']));
    Results.(name).fascicle.automatic_EM.pennation=e+mean(eval(['Results.',name,'.fascicle.automatic_EM.pennation']) );
    Results.(name).fascicle.automatic_EM.length=f+mean(eval(['Results.',name,'.fascicle.automatic_EM.length']) );
end
frr=(round(length(eval(['Results.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['Results.',name,'.fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;

figure
t = eval(['Results.',name,'.fascicle.automatic_EM.time']);
frr=(round(length(eval(['Results.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['Results.',name,'.fascicle.automatic_EM.time']))));
window_time=10/25;
window_length_manual=5;
window_length=window_time*frr;
lenEM = smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man,len_man,'g','LineWidth',1)
xlabel('Time(s)')
ylabel('Length(mm)')
 legend('em','val')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len, corr_coef_fl] = getMetrics(lenEM, len_man, t, t_man); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),'Spearman corr coef-->',num2str(corr_coef_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t =eval(['Results.',name,'.fascicle.automatic_EM.time']);
pennEM =  smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man,penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coef_pa] = getMetrics(pennEM, penn_man, t, t_man);
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),'Spearman corr coef-->',num2str(corr_coef_pa));
sgtitle(title_m)

button_shift=questdlg('Initial shift visible?','','yes','no','no');
if strcmp(button_shift,'yes')
 tmp1=smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);tmp1=tmp1(1);
 tmp2=smoothdata(manual.pennation, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
idx=tmp1>tmp2;
if idx==1
    manual.pennation=manual.pennation+abs(tmp1-tmp2);
else
    manual.pennation=manual.pennation-abs(tmp1-tmp2);
end

tmp1=smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);tmp1=tmp1(1);
tmp2=smoothdata(manual.length, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
idx=tmp1>tmp2;
if idx==1
    manual.length=manual.length+abs(tmp1-tmp2);
else
    manual.length=manual.length-abs(tmp1-tmp2);
end

figure
t = eval(['Results.',name,'.fascicle.automatic_EM.time']);
frr=(round(length(eval(['Results.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['Results.',name,'.fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;
lenEM = smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man,len_man,'g','LineWidth',1)
xlabel('Time(s)')
ylabel('Length(mm)')
 legend('em','val')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len, corr_coef_fl] = getMetrics(lenEM, len_man, t, t_man); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),'Spearman corr coef-->',num2str(corr_coef_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t =eval(['Results.',name,'.fascicle.automatic_EM.time']);
pennEM =  smoothdata(eval(['Results.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man,penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coef_pa] = getMetrics(pennEM, penn_man, t, t_man);
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),'Spearman corr coef-->',num2str(corr_coef_pa));
sgtitle(title_m)
end
% write2mat = fullfile(Params.trackedSaveDir,'TrackedData.mat');
% save(write2mat,'Results')       
% fprintf('Tracking complete - data saved!\n')
%% results loading (dei file Res con il riferimento)
%caricamento tracking automatico
subdir = 'C:\Users\franc\Desktop\Tesi\Video\tracked';
datadir = fullfile(subdir);
DataT = uigetdir((datadir),'select the tracked video');
datafiles = dir(fullfile(DataT,('*.mat')));
load(fullfile(DataT,datafiles(1).name));
[~, file_name, ~] = fileparts(DataT);
split_name = split(file_name, '_');
name = strcat(split_name{1}, '_', split_name{2});
%caricamento tracking manuale corrispondente
subdir = 'C:\Users\franc\Desktop\Tesi\Video\manual_mediati';
datadir = fullfile(subdir);
DataT = uigetdir((datadir),'select the corresponding manual tracking ');
datafiles = dir(fullfile(DataT,('*.mat')));
for i1 = 1:length(datafiles)
        datafileStr{i1} = datafiles(i1).name;
end
[selectedIndex, ok] = listdlg('ListString', datafileStr, 'SelectionMode', 'single', 'PromptString', 'Select a subfolder');
load(fullfile(DataT,datafiles(selectedIndex).name));
button4=questdlg('Drift observed?','','yes','no','no');
if strcmp (button4,'yes')
    [b,a]=butter(3,0.1/(eval(['ResultsFascicle.',name,'.Params.framerate'])/2),"high");
    e=filtfilt(b,a,eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']));
    f=filtfilt(b,a,eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.length']));
    ResultsFascicle.(name).fascicle.automatic_EM.pennation=e+mean(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']) );
    ResultsFascicle.(name).fascicle.automatic_EM.length=f+mean(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.length']) );
end
frr=(round(length(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;

tmp1=smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);tmp1=tmp1(1);
tmp2=smoothdata(manual.pennation, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);

figure
t = eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']);
frr=(round(length(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;
lenEM = smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man,len_man,'g','LineWidth',1)
xlabel('Time(s)')
ylabel('Length(mm)')
 legend('em','val')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len, corr_coef_fl] = getMetrics(lenEM, len_man, t, t_man); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),'Spearman corr coef-->',num2str(corr_coef_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t =eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']);
pennEM =  smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man,penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coef_pa] = getMetrics(pennEM, penn_man, t, t_man);
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),'Spearman corr coef-->',num2str(corr_coef_pa));
sgtitle(title_m)

button_shift=questdlg('Initial shift visible?','','yes','no','no');
if strcmp(button_shift,'yes')
 tmp1=smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);tmp1=tmp1(1);
 tmp2=smoothdata(manual.pennation, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
idx=tmp1>tmp2;
if idx==1
    manual.pennation=manual.pennation+abs(tmp1-tmp2);
else
    manual.pennation=manual.pennation-abs(tmp1-tmp2);
end

tmp1=smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);tmp1=tmp1(1);
tmp2=smoothdata(manual.length, 'movmean',window_length_manual);tmp2=tmp2(1);%, 'movmean',window_length);tmp2=tmp2(1);
idx=tmp1>tmp2;
if idx==1
    manual.length=manual.length+abs(tmp1-tmp2);
else
    manual.length=manual.length-abs(tmp1-tmp2);
end

figure
t = eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']);
frr=(round(length(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.trackFrames']))/max(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']))));
window_time=6/25;
window_length_manual=3;
window_length=window_time*frr;
lenEM = smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.length']), 'movmean',window_length);
plot(t(1:length(lenEM)), lenEM),hold on
% path_m = 'C:\Users\cesti\Dropbox (Politecnico Di Torino Studenti)\File di Elena Cesti\ultrasound_tracking-master\Ultrasound\Clips\PF\PFhr3\manual_pfhr3_fdmas.mat';
% load(path_m)
t_man = manual.time; len_man = smoothdata(manual.length, 'movmean',window_length_manual);
hold on, plot(t_man,len_man,'g','LineWidth',1)
xlabel('Time(s)')
ylabel('Length(mm)')
 legend('em','val')
title('length of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length.png']))
 [rmse_len, metrics_len, corr_coef_fl] = getMetrics(lenEM, len_man, t, t_man); 
 title_m = strcat('Fascicle length : rmse --> ', num2str(rmse_len),'Spearman corr coef-->',num2str(corr_coef_fl));
 sgtitle(title_m)
% save(fullfile(Params.trackedSaveDir,'metrics_len.mat'),'metrics_len');
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_length_metrics.png']))
% 
figure
t =eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.time']);
pennEM =  smoothdata(eval(['ResultsFascicle.',name,'.fascicle.automatic_EM.pennation']), 'movmean',window_length);
 plot(t(1:length(pennEM)), pennEM)
t_man = manual.time; penn_man = smoothdata(manual.pennation,'movmean',window_length_manual);
hold on, plot(t_man,penn_man,'g','LineWidth',1)
legend('em','val')
xlabel('Time(s)')
ylabel('Angle(°)')
title('angle of the fascicle')
% saveas(gcf,fullfile(Params.trackedSaveDir,['fascicle','_angle.png']))
[rmse_penn, metrics_penn,corr_coef_pa] = getMetrics(pennEM, penn_man, t, t_man);
title_m = strcat('Pennation angle : rmse --> ', num2str(rmse_penn),'Spearman corr coef-->',num2str(corr_coef_pa));
sgtitle(title_m)
end
