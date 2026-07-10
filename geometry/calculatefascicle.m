function [ Fascicle ] = calculatefascicle( Data,Params )
%calculatefascicles

%  fit lines to data points, find end points, and calculate fascicle
    % parameters

    % fit lines to data points
    for i1 = 1:Params.n_struct
        iPts = Data.pts{i1};
        iX = iPts(:,1);
        iY = iPts(:,2);

        ip{i1} = polyfit(iX,iY,1); %slope coefficients

        iXpts = [min(iX);max(iX)];
        iYpts = polyval(ip{i1},iXpts);
        linePts(i1).x = iXpts;
        linePts(i1).y = iYpts;

        % calculate line points for end of frame of animating purposes
        if i1 < 3
            linePtsPlot(i1).x = [1;Params.nx];
            linePtsPlot(i1).y = polyval(ip{i1},linePtsPlot(i1).x);
        end
    end

    % find intersections between lines 1-3 and 2-3 (fascicle insertions)
    for i=3:Params.n_struct
    lineCombination = [1,i;2,i]; % set 1 - deep apo+fascicle; set 2 - super apo+fascicle
    for i1 = 1:2
        iLineCom = lineCombination(i1,:);

        l1 = [linePts(iLineCom(1)).x,linePts(iLineCom(1)).y];
        l2 = [linePts(iLineCom(2)).x,linePts(iLineCom(2)).y];
        % calculate point of intersection between aponeurosis and fascicle
        [interceptPtX(i1),interceptPtY(i1)] = linesintersect(l1,l2);
    end
    linePtsPlot(i).x = [interceptPtX(1);interceptPtX(2)];
    linePtsPlot(i).y = [interceptPtY(1);interceptPtY(2)];

    % calculate fascicle length and pennation angle
    % fascicle length
    fascicleXmm = interceptPtX * Params.px2mmX;
    fascicleYmm = interceptPtY * Params.px2mmY;
    fascicleL(1,i-2) = sqrt(diff(fascicleXmm).^2+diff(fascicleYmm).^2);

    % pennation angle
    u = [ip{1}(1),1,0];
    v = [ip{i}(1),1,0];
    pennation(:,i-2)= atan2d(norm(cross(u,v)),dot(u,v)); %atan2 (deg) of sine over cosine between unit vectors u and v

    Fascicle.insertionDeep_px(i-2,:) = [interceptPtX(1),interceptPtY(1)];
    Fascicle.insertionSuperficial_px (i-2,:)= [interceptPtX(2),interceptPtY(2)];
    Fascicle.insertionDeep_mm (i-2,:)= [fascicleXmm(1),fascicleYmm(1)];
    Fascicle.insertionSuperficial_mm (i-2,:)= [fascicleXmm(2),fascicleYmm(2)];
    end
    %% data to return
    Fascicle.length = fascicleL;
    Fascicle.pennation = pennation;

    Fascicle.plotInsertions = linePtsPlot;
    Fascicle.polycoef = ip;

end
