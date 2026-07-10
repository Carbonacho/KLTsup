function [Data,Params] = trackablepoints(Data,videoFrame,Params,i1,pts0,redrawPts,videoFrame_bordo_nero,frame)
%joshrbaxter@gmail.com
% videoFrame = Data.frame(end).videoFrame;
pts0_empty = false;
if (nargin < 5) || (isempty(pts0))% get user input for points otherwise build points from current available pts
    if nargin > 5
        if (isempty(pts0)) % if the vector is empty, re-track the lines
           pts0_empty = true;
        end
    end
    % (drawing happens on the shared aponeurosis figure Params.initFig - see the
    %  fascicle branch below - so no separate "let us draw the lines" window)
    if Params.blindUser
        tname = 'Blinded Review';
    else
        [~,tname,~] = fileparts(Data.trialName);
        tname = strrep(tname,'_','\_');
    end
    if strcmp(Params.landmarkString{i1}, 'Fascicle') || Params.da_tracciare_apo==1
    % if nargin>5 &&Params.cancellato==1
    %     angle_h=Data.filtered_hough(frame); angle_h_pre=Data.filtered_hough(frame-20);
    %     angle_penn_pre=Data.frame(frame-20).fascicle.pennation; rapporto=angle_h/angle_h_pre;
    %     angle_penn=rapporto*angle_penn_pre;
    %     m = tan((angle_penn*pi/180-5*pi/180));
    %     p=Data.frame(frame-1).pts{3};
    %     punto_x = mean(p(:,2));
    %     punto_y = mean(p(:,1));
    %     q=punto_x-m*punto_y;
    %
    %     % Draw the line on the image
    %     figure,imshow(videoFrame);hold on;
    %     x=1:1:600;
    %     y=m*x+q;
    %     plot(x,y)
    %
    %     pts0=[x;y]';Params.rectHt(3)=8;
    %         initPts = true;
    % redrawPts = false;
    % end
    % if length(callStack) > 1 && strcmp(callStack(2).name, 'trackpoints')
    %     for m=3:length(Params.landmarkString)
    % iTitle = sprintf('Select %s - Trial: %s',Params.landmarkString{m},tname);
    % title(iTitle)
    % iLine = imline();
    % pts0 = iLine.getPosition(); % return a 2x2 matrix that contains the x,y of the 2 end point of the line
    % title('select the height of the ROI');
    % iLine2 = imline();
    % ht = iLine2.getPosition(); % return a 2x2 matrix that contains the x,y of the 2 end point of the line
    % Params.rectHt(m)=abs(round((ht(2,2)-ht(1,2))/2));
    %     end
    % else
    if ~Data.traditionalDrazan && nargin < 8 && isfield(Params,'initFascicleLine') && ...
            numel(Params.initFascicleLine)>=i1 && ~isempty(Params.initFascicleLine{i1})
        % EM initialization only (nargin<8 => not a mid-tracking re-seed): reuse
        % the line drawn during the traditional init, so the user is not asked to
        % draw the same fascicle twice
        pts0 = Params.initFascicleLine{i1};
    else
        % draw on the shared aponeurosis figure (approve apo, then draw the
        % fascicle on the same window) instead of a separate one
        if isfield(Params,'initFig') && ~isempty(Params.initFig) && ishandle(Params.initFig)
            figure(Params.initFig); hold on;
        else
            figure('Name','Select structure'); imshow(videoFrame); hold on;
        end
        iTitle = sprintf('Select %s - Trial: %s',Params.landmarkString{i1},tname);
        title(iTitle)
        iLine = imline();
        pts0 = iLine.getPosition(); % return a 2x2 matrix that contains the x,y of the 2 end point of the line
        title('select the height of the ROI');
        iLine2 = imline();
        ht = iLine2.getPosition(); % return a 2x2 matrix that contains the x,y of the 2 end point of the line
        Params.rectHt(i1)=abs(round((ht(2,2)-ht(1,2))/2));
        if Data.traditionalDrazan
            Params.initFascicleLine{i1} = pts0;   % remember it for the EM init
        end
    end
    %end
    initPts = true;
    redrawPts = false;
    else
        for i=1:length(Params.linee_apon1)
            iLine1(i,:)=Params.linee_apon1(i).point1;
            iLine2(i,:)=Params.linee_apon1(i).point2;
        end
        for i=1:length(Params.linee_apon2)
            iLine3(i,:)=Params.linee_apon2(i).point1;
            iLine4(i,:)=Params.linee_apon2(i).point2;
        end
        if i1==1
             Params.rectHt(i1)=Params.rectHt1;
        elseif i1==2
            Params.rectHt(i1)=Params.rectHt2;
        end
        mean1=mean(iLine1);
        mean2=mean(iLine2);
        if size(iLine3,1)>1
        mean3=mean(iLine3);
        mean4=mean(iLine4);
        else
            mean3=iLine3;
            mean4=iLine4;
        end
        pts01=[mean1;mean2];
        pts02=[mean3;mean4];

        if i1==1
        pts0=pts01;
        elseif i1==2
        pts0=pts02;
        end
        initPts = true;
        redrawPts = false;
    end
    if pts0_empty
        close gcf
    end

else
    initPts = false;
end
% fit line to screen (aponeourses, i<3) or fascicle to aponeuroses (i > 2)
p = polyfit(pts0(:,1),pts0(:,2),1);

% pts1x will expand best fit line to cover width of image for aponerousis
% or length of fascicle for fascicle
if i1 < 3 && Params.retrack==1% aponeurosis line definition
    thesePts(:,1) = [1;Params.nx];
    thesePts(:,2) = polyval(p,thesePts(:,1));
elseif i1 < 3 && Params.retrack==0% aponeurosis line definition
    thesePts(:,1) = [1;Params.nx];
    thesePts(:,2) = polyval(p,thesePts(:,1));%figure,plot(thesePts(1,1),thesePts(1,2),'x');hold on;plot(thesePts(2,1),thesePts(2,2),'x')
  if nargin<5 && Data.traditionalDrazan   % apo figure + "confirm lines" only on the traditional pass (skip the EM re-confirm)
    if i1==1
    Params.initFig = figure; imshow(videoFrame); hold on
    title ('automated selected ROI for aponeuroses')
    end
  line(thesePts(:,1),thesePts(:,2),'LineWidth', 3);hold on
  meanX = mean(thesePts(:,1));
  meanY = mean(thesePts(:,2));

    % Compute the limits of the second vertical line based on Params.rectHt1
  halfRectHt1 = round(Params.rectHt1 / 2);
  startY = meanY - halfRectHt1;
  endY = meanY + halfRectHt1;

  % Draw the second vertical line at the midpoint of the previous line
  line([meanX meanX], [startY endY], 'LineWidth', 3);hold on
  if i1==2
      button=questdlg('confirm lines','','Yes','No','Yes');
  if strcmp(button,'No')
     i1=1;
     Params.da_tracciare_apo=1;
     Params.retrack=1;
     close all;
     return;
  end
  end
  end
else %fascicle
    % calc intersection between fascicle and aponeurosis
    % deep aponeurosis = 1; superficial aponeurosis = 2

    ptsx = [1;Params.nx];

    p1 = polyfit(Data.frame(end).pts{1}(:,1),Data.frame(end).pts{1}(:,2),1);
    p2 = polyfit(Data.frame(end).pts{2}(:,1),Data.frame(end).pts{2}(:,2),1);

    pts1y = polyval(p1,ptsx);
    pts2y = polyval(p2,ptsx);

    pts0_1 = [ptsx,pts1y];
    pts0_2 = [ptsx,pts2y];

    [intx1,inty1] = linesintersect(pts0_1,pts0);
    [intx2,inty2] = linesintersect(pts0_2,pts0);

    % fascicle end points
    thesePts = [intx1,inty1;intx2,inty2];
    % check pts1 - if leave image - refit
    pts1x = thesePts(:,1);
    pts1x(pts1x < 1) = 1;
    pts1x(pts1x > Params.nx) = Params.nx;
    pts1y = polyval(p,pts1x);
    thesePts = sort([pts1x,pts1y]);
end

% rotate image and line
%x' = cos(theta)*x - sin(theta)*y
%y' = sin(theta)*x + cos(theta)*y
theta = atan2(p(1),1); % angle from horizontal
iTform = affine2d([cos(theta) -sin(theta) 0;...
                    sin(theta) cos(theta) 0; 0 0 1]);
% line transform requires a rotation + translation
[X2,Y2] = transformPointsForward(iTform,thesePts(:,1),thesePts(:,2)); % rotate line
shiftX = abs(sin(theta)) * Params.ny;
shiftY = abs(sin(theta)) * Params.nx;
%shift up-down or right-left
if theta < 0 % shift line x Data.frame(end) by amount of rotation*#ofrows
   X2 = X2+shiftX;
else % shift line y Data.frame(end) by amount of rotation*#ofcolumns
   Y2 = Y2+shiftY;
end
% detect best points for tracking
rectLength1 = abs(X2(2)-X2(1));
moveInPx = Params.padBorder(i1) * rectLength1; % user defined padding, a tenth of lateral margin on x
rectLength2 = rectLength1 - 2*moveInPx;
rectROI = [X2(1)+moveInPx, Y2(1)-Params.rectHt(i1), rectLength2,2*Params.rectHt(i1)]; % top corner coordinate, width and height
roi2Points = bbox2points(rectROI); % only works if the ROI is horizontal, not if the ROI is tilted

%figure, imshow(im2), hold on ,fill(roi2Points(:,1),roi2Points(:,2),'b','FaceAlpha',0.3)
%if i1 <= Params.n_struct % set image contrast - perform contrasting for deep aponeurosis, superficial aponeurosis and fascicle
    %if initPts % analyse only inside the box, only on the first frame
tmpInd = uint16(roi2Points);

if Data.traditionalDrazan || (Data.traditionalDrazan==0 && i1<3)
    [im2,~] = imwarp(videoFrame,iTform,'nearest');   %nearest-neighbour interpolation is used, assigning the value of the closest pixel to the new point during the transform.

% im2=im2*1.6; imshow(im2)
%     im2(im2>1)=1;
    tmpIm2 = im2(tmpInd(1,2)+1:tmpInd(4,2),tmpInd(1,1):tmpInd(2,1));%select the small rectangle
    maxTmpIm2 = max(tmpIm2);
    stdTmpIm2 = std(tmpIm2);
    meanTmpIm2= mean(tmpIm2(:));
    %binarization threshold for the specific ROI
    if meanTmpIm2>0.5
        if i1<3
          threshTmpIm2 = mean(maxTmpIm2)- 0.5 * mean(stdTmpIm2); %%%%%%%%
        else
        threshTmpIm2 = mean(maxTmpIm2)- 1 * mean(stdTmpIm2); %%%%%%%%
        end
    else
        if i1<3
          threshTmpIm2 = mean(maxTmpIm2)- 0.8 * mean(stdTmpIm2); %%%%%%%%
        else
        threshTmpIm2 = mean(maxTmpIm2)- 1.2 * mean(stdTmpIm2); %%%%%%%%%

        end
    end
    Params.roi2Points{i1} = tmpInd; % the 4 corner coordinates of the bounding box are stored
     % if length(Data.frame)==47
     %     print('hello')
     % end

     Params.thresholdAponeurosis(i1) = threshTmpIm2;
     im2 = (im2 < Params.thresholdAponeurosis(i1)) == 0; %threshold found on the roi applied to the whole image and only for the first frame
    % ROI placement check
    %figure, imshow(im2), hold on,fill(roi2Points(:,1),roi2Points(:,2),'b','FaceAlpha',0.3)
    tmpIm2 = (tmpIm2 < Params.thresholdAponeurosis(i1)) == 0;
    labels= bwlabel(tmpIm2);
    area= regionprops(labels,'Area');
    nLabels=length([area.Area].');
    % p=prctile([area.Area].',95);
    % for i=1:numel(area)
    %     if area(i).Area<p
    %         labels(labels==i)=0;
    %     end
    % end
    %figure, imshow(labels)
    [sortedAreas,sortedAreaIdx]=sort(cell2mat(struct2cell(area)),'descend');
    sumPixels=sum(sortedAreas);
    if length(sortedAreas)>4
        sum4=sum(sortedAreas(1:4));
        if sum4< round(sumPixels/2)
            idx=sortedAreaIdx(1:round(length(sortedAreaIdx)/2));
            areaVal=sortedAreas(round(length(sortedAreaIdx)/2));
        else
            idx=sortedAreaIdx(1:4);
            areaVal=sortedAreas(4);
        end
    else
        idx=sortedAreaIdx;
        areaVal=sortedAreas(end);
    end

    for i=1:numel(area)
        if area(i).Area<areaVal
            labels(labels==i)=0;
        end
    end
    mask=labels; %figure, imshow(mask)
    %%%%%%%%%%% CHECK IF THIS NEEDS TO BE MODIFIED
    mask(mask>1)=1; %build the binary mask of the ROI without small areas
    red_2=0;
    nTop=length(find(mask(1,:)==1));
    nBot=length(find(mask(end,:)==1));
    if i1==1 && (nTop>round(size(labels,2)/5)|| nBot>round(size(labels,2)/5))
        if nTop>round(size(labels,2)/5)
           rectROI = [X2(1)+moveInPx-5, Y2(1)-Params.rectHt(i1)-5, rectLength2,2*Params.rectHt(i1)]; % top corner coordinate, width and height
        elseif nBot>round(size(labels,2)/5)
            rectROI = [X2(1)+moveInPx+5, Y2(1)-Params.rectHt(i1)+5, rectLength2,2*Params.rectHt(i1)]; % top corner coordinate, width and height
        end
    end
    [r,~,~]=find(mask==1);
    shiftDist=min(r)-(size(mask,1)-(max(r))); %ROI shift distance, positive downward and negative upward
    redrawROI= abs(shiftDist)>ceil(size(mask,1)*0.1);
    redrawROI=redrawROI|red_2;

    if i1>2
        redrawROI=0; % to not revaluate the point of the ROI of the fascicle
    end
    % if redrawROI
    %     rectROI = [X2(1)+moveInPx, Y2(1)-Params.rectHt(i1)+shiftDist, rectLength2,2*Params.rectHt(i1)]; % top corner coordinate, width and height
    % end
    %roi2Points = bbox2points(rectROI);
    %figure, imshow(mask)
    %figure, imshow(im2), hold on,fill(roi2Points(:,1),roi2Points(:,2),'b','FaceAlpha',0.3)

    %Data.frame(end).RoiDesplacement(i1,1)=shiftDist;                    %%%%%%%%%%%%%
    Data.frame(end).thr(i1,1)=Params.thresholdAponeurosis(i1);         %%%%%%%%%%%%%

    if initPts || redrawROI  || redrawPts
        detect_im2s = detectSIFTFeatures(imcrop(im2,rectROI)); % function to find the feature points --> gives position
        if i1~=1
        detect_im2= detectMinEigenFeatures(im2,'ROI',rectROI);
        else
                se = strel('line',15,4);
                im2_er=imerode(im2,se);
                detect_im2= detectMinEigenFeatures(im2_er,'ROI',rectROI);
        end
        points_im2 = detect_im2.Location;
        points_im2s=detect_im2s.Location;
        points_im2s=[points_im2s(:,1)+rectROI(1),points_im2s(:,2)+rectROI(2)];
        npoints_im2 = detect_im2.Count; %figure, imshow(im2), hold on, plot(detect_im2.Location(:,1),detect_im2.Location(:,2),'*b')
        %  figure,imshow(im2);hold on
        %  plot(detect_im2s.Location(:,1)+rectROI(1),detect_im2s.Location(:,2)+rectROI(2),'ro');hold on
        % plot(points_im2(:,1),points_im2(:,2),'b+')
        % reduce number of tracking points to user defined
        if npoints_im2 > Params.maxTrackingPts(i1) %if too many, keep the most reliable
            %select points based on the point confidence metric.
            [~,I]=sort(detect_im2.Metric,'descend');
            points_im2 = points_im2(I(1:Params.maxTrackingPts(i1) ),:);
        end
        points_im2=[points_im2;points_im2s];
        % figure,imshow(im2),hold on
        % plot(points_im2(:,1),points_im2(:,2),'ro');
        % transform points back to image coordinate system ( we found them
        % in the rotated image)
        if theta < 0 %shift X back
            points_im2(:,1) = points_im2(:,1)...
                - repmat(shiftX,length(points_im2),1);
        else % shift Y back
            points_im2(:,2) = points_im2(:,2)...
                - repmat(shiftY,length(points_im2),1);
        end
        [points1X,points1Y] = transformPointsInverse(iTform,...
            points_im2(:,1),points_im2(:,2));
        pts_trackable = [points1X,points1Y];
        pts_trackable_endptsx = [min(points1X);max(points1X)];
        pts_trackable_endptsy = polyval(p,pts_trackable_endptsx);
        pts_trackable_endpts = [pts_trackable_endptsx,pts_trackable_endptsy];

        Data.frame(end).pts{i1} = pts_trackable;
        try isempty (Data.frame(end).pts{i1});
        catch exception
            disp(exception)
        end
        Data.frame(end).endPts{i1} = pts_trackable_endpts;
        Data.frame(end).redefinePtsFlag(i1,1) = 1;
    end

else  %inverse-FFT method, different thresholding. We arrive here if the method
%is not Drazan's traditional one or if we are in the initialization phase

    if initPts %initialization phase
        [im2,~] = imwarp(videoFrame_bordo_nero,iTform,'nearest');   %nearest-neighbour interpolation is used, assigning the value of the closest pixel to the new point during the transform.
        fiber = fibermetric(im2,[6,8]);
        fiber=edge(fiber,'canny');
        fiber= bwareaopen(fiber,80); %remove elements smaller than 80px
        detect_im2 = detectMinEigenFeatures(fiber,'ROI',rectROI);
        detect_im2s = detectSIFTFeatures(imcrop(im2,rectROI)); % function to find the feature points --> gives position
        points_im2 = detect_im2.Location;
        points_im2s=detect_im2s.Location;
        points_im2s=[points_im2s(:,1)+rectROI(1),points_im2s(:,2)+rectROI(2)];
        npoints_im2 = detect_im2.Count; %figure, imshow(fiber), hold on, plot(points_im2(:,1),points_im2(:,2),'*b')
        points_im2=[points_im2;points_im2s];
        % transform points back to image coordinate system
        if theta < 0 %shift X back
            points_im2(:,1) = points_im2(:,1)...
                - repmat(shiftX,length(points_im2),1);
        else % shift Y back
            points_im2(:,2) = points_im2(:,2)...
                - repmat(shiftY,length(points_im2),1);
        end
        [points1X,points1Y] = transformPointsInverse(iTform,...
            points_im2(:,1),points_im2(:,2));
        pts_trackable = [points1X,points1Y];
        pts_trackable_endptsx = [min(points1X);max(points1X)];
        pts_trackable_endptsy = polyval(p,pts_trackable_endptsx);
        pts_trackable_endpts = [pts_trackable_endptsx,pts_trackable_endptsy];
        Data.frame(end).pts{i1} = pts_trackable;
        Data.frame(end).endPts{i1} = pts_trackable_endpts;
        Data.frame(end).redefinePtsFlag(i1,1) = 1;

    elseif redrawPts

        % Try
%         [im2,~] = imwarp(videoFrame_bordo_nero,iTform,'nearest');   %nearest-neighbour interpolation is used, assigning the value of the closest pixel to the new point during the transform.
%         fiber = fibermetric(im2,[6,8]);
%         fiber=edge(fiber,'canny');
%         fiber= bwareaopen(fiber,80); %remove elements smaller than 80px
%         detect_im2 = detectMinEigenFeatures(fiber,'ROI',rectROI);
        [im2,~] = imwarp(videoFrame,iTform,'nearest');   %nearest-neighbour interpolation is used, assigning the value of the closest pixel to the new point during the transform.
        % fiber = fibermetric(im2,[6,8]);
        % fiber=edge(fiber,'canny');
        % fiber= bwareaopen(fiber,80); %remove elements smaller than 80px

        detect_im2 = detectMinEigenFeatures(im2,'ROI',rectROI);
        detect_im2s = detectSIFTFeatures(imcrop(im2,rectROI)); % function to find the feature points --> gives position

        points_im2 = detect_im2.Location;
        points_im2s=detect_im2s.Location;
        points_im2s=[points_im2s(:,1)+rectROI(1),points_im2s(:,2)+rectROI(2)];

        npoints_im2 = detect_im2.Count; %figure, imshow(im2), hold on, plot(points_im2(:,1),points_im2(:,2),'*b')
        points_im2=[points_im2;points_im2s];        % transform points back to image coordinate system figure, imshow(im2), hold on ,fill(rectROI(:,1),rectROI(:,2),'b','FaceAlpha',0.3)
        if theta < 0 %shift X back
            points_im2(:,1) = points_im2(:,1)...
                - repmat(shiftX,length(points_im2),1);
        else % shift Y back
            points_im2(:,2) = points_im2(:,2)...
                - repmat(shiftY,length(points_im2),1);
        end
        [points1X,points1Y] = transformPointsInverse(iTform,...
            points_im2(:,1),points_im2(:,2));
        pts_trackable = [points1X,points1Y];
        pts_trackable_endptsx = [min(points1X);max(points1X)];
        pts_trackable_endptsy = polyval(p,pts_trackable_endptsx);
        pts_trackable_endpts = [pts_trackable_endptsx,pts_trackable_endptsy];
        Data.frame(end).pts{i1} = pts_trackable;
        Data.frame(end).endPts{i1} = pts_trackable_endpts;
        Data.frame(end).redefinePtsFlag(i1,1) = 1;

% %     % Old version
        theta = -atan2(p(1),1); % angle from horizontal

        iTform = affine2d([cos(theta) -sin(theta) 0;...
                        sin(theta) cos(theta) 0; 0 0 1]);
        [im2,~] = imwarp(videoFrame,iTform,'nearest');
        im2_no_rot=videoFrame_bordo_nero;
        fiber = fibermetric(videoFrame_bordo_nero,[4]);
        fiber(round(Data.frame(end-1).fascicle.plotInsertions(1).y(2)-20):end,:)=0;
        fiber(1:round(Data.frame(end-1).fascicle.plotInsertions(2).y(1)+20),:)=0;
        fiber(:,1:10)=0;
        fiber(:,end-10:end)=0;
        checkMask = imbinarize(fiber,"global");
        checkMask= imdilate(checkMask, strel('disk',1));
        %figure, imshow(checkMask), title('binarization of the fascicle ROI'), hold on , plot(pts0(:,1),pts0(:,2),'*g');
        stats = regionprops(checkMask, 'PixelList','Centroid');
        for i = 1:length(stats)
            pixelList = stats(i).PixelList;
            commonPts= intersect(pixelList,round(pts0),"rows");
            nCommonPts(i)=length(commonPts);
        end
        [~,y]=max(nCommonPts);
        passPoint=stats(y).Centroid;
        %figure, imshow(checkMask), hold on , plot(passPoint(:,1),passPoint(:,2),'+r');
        meanAngle=Data.hough(frame);
        if ~isempty(meanAngle) || abs(meanAngle-Data.frame(end-1).angletexture)<5
            tiltAngle=deg2rad(meanAngle);
            m = tan(tiltAngle);
            y1 = passPoint(2) - m * passPoint(1);
            y2 = m*size(im2_no_rot,2)+ y1;
            thesePts(1,1)=1; thesePts(1,2)=y1;
            thesePts(2,1)= size(im2_no_rot,2); thesePts(2,2)=y2;
        end
        deltax = 9*sin(theta);%deltax = Params.rectHt(i1)*sin(theta);
        deltay = 9*cos(theta);%deltay = Params.rectHt(i1)*cos(theta);
        try
        roi2Points = [thesePts(1,1)+3*deltax, thesePts(1,2)-deltay;...
                      thesePts(2,1)-deltax  , thesePts(2,2)-deltay;...
                      thesePts(2,1)-3*deltax, thesePts(2,2)+deltay;...
                      thesePts(1,1)+deltax  , thesePts(1,2)+deltay;...
                      thesePts(1,1)+3*deltax, thesePts(1,2)-deltay];
        %figure, imshow(im2), hold on ,fill(roi2Points(:,1),roi2Points(:,2),'b','FaceAlpha',0.3)
        %figure, imshow(im2_no_rot), hold on ,fill(roi2Points(:,1),roi2Points(:,2),'b','FaceAlpha',0.3)
            mask = roipoly(im2_no_rot, roi2Points(:,1),roi2Points(:,2));
        catch
            pause
        end
        %im2_no_rot=im2_no_rot.*mask; %mask that isolates the ROI without rotating!
        fiber = fibermetric(im2_no_rot,[4,6]);
        fiber=edge(fiber,'canny');%figure,imshow(fiber);figure,imshow(mask)
        fiber=fiber.*mask;%figure,imshow(fiber)
        fiber=bwareaopen(fiber,80); %remove elements smaller than 80px
        fiber=bwareafilt(fiber,2);
        %figure, imshow(fiber);

        [H,thetaList,rho] = hough(fiber,"Theta",-85:0.1:-40);
        % figure,imshow(imadjust(rescale(H)),'XData',theta,'YData',rho,'InitialMagnification','fit'),colormap(gca,hot),xlabel('\theta'),ylabel('\rho'),axis on, axis normal;
        peaks = houghpeaks(H,20);
        %hold on , x = theta(peaks(:,2)); y = rho(peaks(:,1)); plot(x,y,'s','color','green');
        lines = houghlines(fiber,thetaList,rho,peaks,'FillGap',5,'MinLength',30);
        thetaList=[lines.theta].'+90;
        meanAngle=mean(thetaList);
        angleDiff=abs(thetaList-meanAngle);
        lines (angleDiff>1)=[];
        %figure, imshow(im2_no_rot), hold on
%         for k = 1:length(lines)
%            xy = [lines(k).point1; lines(k).point2];
%            plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','green');
%
%            % Plot beginnings and ends of lines
%            plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
%            plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
%         end
        checkMask=checkMask.*mask; %figure,imshow(checkMask),title('selected fascicle ROI');
        toRemove=[];
        toSum=[];
        for i = 1 : size(pts0,1)
            centre = round(pts0(i,:));
            coords = [centre(1)-1,centre(2)-1; centre(1), centre(2)-1; centre(1)+1,centre(2)-1;...
                         centre(1)-1,centre(2)  ; centre(1), centre(2)  ; centre(1)+1,centre(2);...
                         centre(1)-1,centre(2)+1; centre(1), centre(2)+1; centre(1)+1,centre(2)+1];
             %figure, imshow(checkMask), hold on , plot(centre(1),centre(2),'+r'), hold on , plot(coords(:,1), coords(:,2),'*g')
            for j= 1 : 6
                if (coords(j,1)<=0)||(coords(j,2)<=0)
                    coords(j,:)=[];
                else
                    try
                        toSum(j) = checkMask(coords(j,2),coords(j,1));
                    catch exception
                        disp(exception.message);
                    end

                end
            end
            if  any(toSum) == false
                toRemove=[toRemove,i];
            end
        end
        pts0(toRemove,:)=[];
        points_im2=pts0;
        % remove nearby and clustered points
        distMatrix=pdist2(points_im2,points_im2,"euclidean");
        i=1;
        while i<= size(distMatrix,2)
            [rowsToDrop, ~]= find(distMatrix(:,i)<3 & distMatrix(:,i)~= 0);
            distMatrix(rowsToDrop,:)=[];
            distMatrix(:,rowsToDrop)=[];
            points_im2(rowsToDrop,:)=[];
            i=i+1;
        end
%         % figure, imshow(checkMask), hold on , plot(points_im2(:,1),points_im2(:,2),'*g')
%         %  figure, imshow(checkMask), hold on , plot(pts0(:,1),pts0(:,2),'*r')
%
nPtsToAdd = floor((Params.maxTrackingPts(i1)-size(points_im2,1)));
pts_trackable = points_im2;

for pp = 1:size(points_im2, 1) - 1
    % Compute the midpoint between two points
    midX = (points_im2(pp, 1) + points_im2(pp + 1, 1)) / 2;
    midY = (points_im2(pp, 2) + points_im2(pp + 1, 2)) / 2;

    % Check whether the midpoint is inside the ROI
    if midX >= roi2Points(1, 1) && midX <= roi2Points(2, 1) && ...
            midY >= roi2Points(1, 2) && midY <=roi2Points(3, 2)
        % Add the midpoint to the trackable points
        pts_trackable(size(points_im2, 1) + pp, 1) = midX;
        pts_trackable(size(points_im2, 1) + pp, 2) = midY;

        % Update the count of points to add
        nPtsToAdd = nPtsToAdd - 1;
    end
end
% Segment the binary image into distinct regions
[labeled, nRegions] = bwlabel(checkMask);

% Compute the contours of the labeled regions
labeledContours = bwboundaries(labeled);

% Compute the properties of the segmented regions
regionAreas = regionprops(labeled, 'Area');

% Extract the area of each region
areas = [regionAreas.Area];

% Sort the areas in descending order and get the sort indices
[sorted_areas, sorted_indices] = sort(areas,'descend');
% Reorder the contours according to the sort indices
sortedContours = labeledContours(sorted_indices);
% contours of the selected aponeurosis
% Sample points along the contour
contourPts = [];
for k = 1:round(length(sortedContours)/4)
    contour = sortedContours{k};
    currArea=sorted_areas(k);
    % Compute the number of points to sample along the contour
    nContourPts = round(length(contour)/5);

    % Interpolate points along the contour
    idx = linspace(1, size(contour, 1), nContourPts);
    if currArea>20
    xInterp = interp1(1:size(contour, 1), contour(:, 2), idx, 'linear');
    yInterp = interp1(1:size(contour, 1), contour(:, 1), idx, 'linear');
    uniformPts = [xInterp', yInterp'];
    contourPts = [contourPts; uniformPts];
    end
end

% Add the trackable points
for i = 1:size(contourPts, 1)
    x = contourPts(i, 1);
    y = contourPts(i, 2);
    % Check whether the point is inside the ROI
    if x >= roi2Points(1, 1) && x <= roi2Points(2, 1) && ...
            y >= roi2Points(1, 2) && y <= roi2Points(3, 2)
        % Add the point to the trackable points list
        pts_trackable = [pts_trackable; x, y];
    end
end
    end
end
end
 % end gettrackablepts
