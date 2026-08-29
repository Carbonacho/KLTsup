function[Data,enhancedFrame,enhancedFrameBlack,y_roi,h_roi,Params]= Tissue_angle(Data,videoFrame_bw,Params,n)
for i1=1:2 %aponeuroses
    iPts = Data.frame(n).pts{i1};
    iX = iPts(:,1);
    iY = iPts(:,2);
    ip{i1} = polyfit(iX,iY,1); %slope coefficients
    iXpts = [min(iX);max(iX)];
    iYpts = polyval(ip{i1},iXpts);
    linePts(i1).x = iXpts;
    linePts(i1).y = iYpts;
    linePtsPlot(i1).x = [1;Params.nx];
    linePtsPlot(i1).y = polyval(ip{i1},linePtsPlot(i1).x);
end
% Rotate the image so more of the central region is captured
theta_1 = atan2(ip{2}(1),1); % angle from horizontal
iTform = affine2d([cos(theta_1) -sin(theta_1) 0;...
                    sin(theta_1) cos(theta_1) 0; 0 0 1]);
[im2,~] = imwarp(videoFrame_bw,iTform,'nearest');
x = [linePtsPlot(1).x; linePtsPlot(2).x];
y = [linePtsPlot(1).y; linePtsPlot(2).y];
[X2,Y2] = transformPointsForward(iTform,x,y); % rotate line
shiftX = abs(sin(theta_1)) * Params.ny;
shiftY = abs(sin(theta_1)) * Params.nx; 
%shift up-down or right-left
if theta_1 < 0 % shift line x Data.frame(end) by amount of rotation*#ofrows
   X2 = X2+shiftX;
else % shift line y Data.frame(end) by amount of rotation*#ofcolumns
   Y2 = Y2+shiftY;
end
% Find the longest, most horizontal contour
x_1 =floor(X2(3));
y_1 = floor(Y2(3)+17); %move away from the superficial and deep aponeuroses with px offsets
h =floor(Y2(2)-Y2(3)-33);
w =floor(X2(2)-X2(3));
 im3=im2single(im2); 
% % Crop the image
im = imcrop(im3, [x_1,y_1, w, h]);
% % Old version
y_roi = floor(linePtsPlot(2).y(1)+17); %move away from the superficial and deep aponeuroses with px offsets
h_roi =floor(linePtsPlot(1).y(2)-linePtsPlot(2).y(1)-33);
im1g=imgaussfilt(im,1); im2g=imgaussfilt(im,12); %difference of Gaussian filters
mask = imbinarize(im1g-im2g,'global');
mask=bwareaopen(mask,50);
im(mask == 0) = 0;

% Compute power spectrum
a = fft2(im);
a = fftshift(a);
power = log(1+(abs(a).^2));

% Central point coordinates
[~,ind_c]=max(max(power)); % index of the central column
[~,ind_r]=max(max(power')); % index of the central row
centre = [ind_r,ind_c];
%power(ind_r,ind_c)=0;
% Threshold for picking points
thr = max(prctile(power,97));
[r,c,specVals] = find(power > thr);

% Build mask
mask = zeros(size(power,1),size(power,2));
%mask(power>thr) = power(power>thr);
mask(power>thr)=1;

% Compute Euclidean distances
euclideanDist=sqrt((r-centre(1)).^2+(c-centre(2)).^2);
thr = mean(euclideanDist)-0.8*std(euclideanDist);
thr2= mean(euclideanDist)-0.6*std(euclideanDist);
for i=1:length(specVals)
    if euclideanDist(i) > thr
        if (c(i)>ind_c && r(i)>ind_r) || (c(i)<ind_c && r(i)<ind_r) || (r(i) == ind_r) || (c(i) == ind_c)
           mask(r(i),c(i))=0;
        end
    end
     if euclideanDist(i) > thr2
        if (c(i) == ind_c)
           mask(r(i),c(i))=0;
        end
    end
end

% Inverse transform
a_fin = ifftshift(mask.*(a));
imm_fin = ifft2(a_fin);
% Filtering
I=(imm_fin); 
I = rescale(real(I),-0.4,0.8); %% to be tuned
enhancedFrameBlack=zeros(size(im3));
%%%%% multiply by im3 (fascicle region of interest)
enhancedFrameBlack(y_1:y_1+h,x_1:x_1+w)=I.*im3(y_1:y_1+h,x_1:x_1+w); % isolate the preprocessed muscle belly using coordinates matching the original image
enhancedFrameBlack(y_1,:)=0;
enhancedFrameBlack(y_1+h,:)=0;
enhancedFrameBlack(:,x_1)=0;
enhancedFrameBlack(:,x_1+w)=0;
enhancedFrame=enhancedFrameBlack+im3; % original border
p=prctile(enhancedFrame(:),30);
enhancedFrame=imadjust(enhancedFrame, [p, 0.95], [0.0,1.0]);

% Invert the transform
theta_1 = -atan2(ip{2}(1),1); % angle from horizontal
iTform = affine2d([cos(theta_1) -sin(theta_1) 0;...
                    sin(theta_1) cos(theta_1) 0; 0 0 1]);
[I_inv,~] = imwarp(enhancedFrame,iTform,'nearest');
enhancedFrameBlack=enhancedFrame;
shiftX = abs(sin(theta_1)) * Params.ny;
shiftY = abs(sin(theta_1)) * Params.nx;
enhancedFrame = imcrop(I_inv,[shiftX,shiftY,size(videoFrame_bw,2),size(videoFrame_bw,1)]);
enhancedFrame(enhancedFrame>1)=1;
enhancedFrame(enhancedFrame<0)=0;
enhancedFrame = enhancedFrame(1:size(videoFrame_bw,1),1:size(videoFrame_bw,2));
end
