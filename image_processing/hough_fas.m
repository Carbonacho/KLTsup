function [Data,Params]=hough_fas(Data,Params,videoFrame_bw,n)
%figure, imshow(videoFrame_bw)
% take the ROI limits from the aponeurosis estimate computed on the first
% frame.
% figure, imshow(videoFrame_bw)
for i1=1:2 %aponeuroses
    iPts = Params.(['apon_media' num2str(i1)]);
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
theta_1 = atan2(ip{1}(1),1); % angle from horizontal
iTform = affine2d([cos(theta_1) -sin(theta_1) 0;...
                    sin(theta_1) cos(theta_1) 0; 0 0 1]);
[im2,~] = imwarp(videoFrame_bw,iTform,'nearest');

% figure,subplot(1,2,1),imshow(videoFrame_bw);hold on, subplot(1,2,2),
% imshow(im2)
xy = [Params.linee_apon1.point1; Params.linee_apon1.point2];
    % plot(xy(:,1), xy(:,2), 'LineWidth', 2, 'Color', 'red');
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
 im3=im2single(im2); %figure,imshow(im3)

% % Crop the image
im = imcrop(im3, [x_1,y_1, 600, 250]);%figure, imshow(im)

% % Old version
y_1_o = floor(linePtsPlot(2).y(1)+17); %move away from the superficial and deep aponeuroses with px offsets
h_o =floor(linePtsPlot(1).y(2)-linePtsPlot(2).y(1)-33);
im1g=imgaussfilt(im,1);
im2g=imgaussfilt(im,12);
%figure,imshow(im1g-im2g)
mask = imbinarize(im1g-im2g,'global');
mask=bwareaopen(mask,50);
im(mask == 0) = 0;
%figure,imshow(im)% subtract background
% Compute power spectrum
a = fft2(im);
a = fftshift(a);
power = log(1+(abs(a).^2));

[~,ind_c]=max(max(power)); % index of the central column
[~,ind_r]=max(max(power')); % index of the central row
centre = [ind_r,ind_c];
%power(ind_r,ind_c)=0;
% Threshold for picking points
thr = max(prctile(power,93));
[r,c,specVals] = find(power > thr);
%hold on, plot(c,r,'+r')

% Build mask
mask = zeros(size(power,1),size(power,2));
%mask(power>thr) = power(power>thr);
mask(power>thr)=1;%imshow(mask)

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

%figure, imshow(mask.*imag(a)), axis off

% Inverse transform
a_fin = ifftshift(mask.*(a));
imm_fin = ifft2(a_fin);
%figure, imshow(imm_fin)

% Filtering
% lapl=fspecial('laplacian',0.5);
% %lapl = fspecial("log",[11,11],7);
% im2 = imfilter(imm_fin,lapl);
% I = abs(im2)+imm_fin;
I=(imm_fin); %imshow(imadjust(I))
%I = rescale(I,-0.5,0.8); % (was -1.4,0.6)
I = rescale(real(I),-1.4,1.0); %% to be tuned
%figure, imshow(I), title('frequency-domain processing of the fascicle ROI')

%% Fiber metric , Frangi filter

im2=imbinarize(I,"global");%figure,imshow(im2)
im2=edge(im2);%figure,imshow(im2)
[H,theta,rho] = hough(im2,'RhoResolution',1,'Theta',-75:0.1:-30);
%figure,imshow(imadjust(rescale(H)),'XData',theta,'YData',rho,'InitialMagnification','fit'),colormap(gca,hot),xlabel('\theta'),ylabel('\rho'),axis on, axis normal;
peaks = houghpeaks(H,15);
%hold on , x = theta(peaks(:,2)); y = rho(peaks(:,1)),plot(x,y,'s','color','green','LineWidth',2);
 lines = houghlines(im2,theta,rho,peaks,'FillGap',5,'MinLength',15);
 %figure, imshow(im2), hold on
for k = 1:length(lines)
   xy = [lines(k).point1; lines(k).point2];
   % plot(xy(:,1),xy(:,2),'LineWidth',2,'Color','green');
   %Plot beginnings and ends of lines
   %plot(xy(1,1),xy(1,2),'x','LineWidth',2,'Color','yellow');
   %plot(xy(2,1),xy(2,2),'x','LineWidth',2,'Color','red');
end

theta1 = 90 + [lines.theta].';%figure,plot(theta1);hold on

try
window_size = 5; % Median filter window size
meanAngle = mean(theta1);
    alpha=abs(atan2d(ip{1}(1),1));
    penn = meanAngle;     %+alpha;
    % fascicle_length = h/sind(penn); %consider computing here
    if penn>0
    Data.hough(n) = penn;
    else
    Data.hough(n)=Data.hough(n-1);
    end
catch
    Data.hough(n) = [];
end


end
