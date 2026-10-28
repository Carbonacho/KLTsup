function [ videoFrame ] = plottrial( Data,videoFrame,Params,frame,structure2plot )
% if ~exist('structure2plot','var')
if nargin < 5
    structure2plot = [1:Params.n_struct];
end
% update videoFrame with aponeurosis and fascicle lines   
for i1 = structure2plot
    iLandmarkString = Params.landmarkString{i1};
    if Params.showLines && Data.manual == 0
        iColor = 'white';
        % plot best fit lines
        iLineX = Data.frame(frame).fascicle.plotInsertions(i1).x;
        iLineY = Data.frame(frame).fascicle.plotInsertions(i1).y;
        iLineXY = [iLineX(1),iLineY(1),iLineX(2),iLineY(2)];
        if Data.manual
            linew = 1;
            alphaval = 0.5;
        else
            linew = 3;
            alphaval = 1;
        end
        videoFrame = insertShape(videoFrame,'line',iLineXY,...
            'Color',iColor,'LineWidth',linew,'opacity',alphaval);
        if i1 > 2 % plot fascicle angle and length
            if iLineX < 0
                iLineX = 0;
            end
            fascicleStringPos = [5, Params.ny-5];
            fascicleString = sprintf('Frame number: %d',frame);
            % optionally overlay fascicle length and pennation angle on the video
            % fascicleString = sprintf('Fascicle Length: %2.1f mm\nPennation Angle: %2.0f degrees\nFrame: %d/%d',...
            %     Data.frame(frame).fascicle.length,Data.frame(frame).fascicle.pennation,frame,Data.trackFrames(end));
            videoFrame = insertText(videoFrame,fascicleStringPos,fascicleString,...
                'FontSize',12,'TextColor','red','AnchorPoint','LeftBottom'); 
        end
    end
    if Params.plotPoints && Data.manual == 0 && Data.validate == 0% display points being tracked
        iPts = Data.frame(frame).pts{i1};
        iColor = Params.markerColor{i1};
        videoFrame = insertMarker(videoFrame,iPts,'+','Color',iColor);
    end
    if Params.displayPtRetention && Data.manual == 0 && Data.validate == 0 % display info on # of points being tracked
        iNpts = size(Data.frame(frame).pts{i1},1);
        ioPts = Data.frame(frame).oPts(i1);
        iPercent = round((iNpts / ioPts) * 100);
        ptRetentionStr{i1} = sprintf('%s: %i%% (%i/%i)',iLandmarkString,...
            iPercent,iNpts,ioPts);
    end
end
end


