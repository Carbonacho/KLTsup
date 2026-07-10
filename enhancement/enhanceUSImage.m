function out = enhanceUSImage(frame, apoDeep, apoSup, opts)
%ENHANCEUSIMAGE  Standalone image enhancement for ultrasound fascicle images.
%
%   This function reproduces, in a single self-contained routine, the two
%   image-enhancement stages that the tracking pipeline normally runs in
%   parallel with the point tracking:
%       1) spatial pre-processing   (from preprocessing.m)
%       2) frequency-domain (FFT) muscle-belly enhancement (from Tissue_angle.m)
%
%   It has NO dependency on the Params/Data structures, no globals and no
%   file I/O, so it can be shared and run on a single image on its own.
%
%   USAGE
%   -----
%   out = enhanceUSImage(frame)
%       Runs pre-processing only, and prompts you to draw the two
%       aponeuroses (deep first, then superficial) for the FFT stage.
%
%   out = enhanceUSImage(frame, apoDeep, apoSup)
%       apoDeep / apoSup are 2x2 matrices [x1 y1; x2 y2] giving two points
%       on the deep and superficial aponeurosis respectively (image
%       coordinates, in the SAME frame you pass in). No user interaction.
%
%   out = enhanceUSImage(frame, apoDeep, apoSup, opts)
%       opts is a struct overriding any of the defaults below.
%
%   INPUT
%   -----
%   frame     RGB or grayscale image (uint8 or single/double). If RGB it is
%             converted to grayscale. If you pass a cropped region, pass the
%             matching aponeurosis coordinates in that cropped frame.
%
%   opts fields (all optional):
%       .flip          (false) horizontally flip the frame first (the
%                              pipeline does this via Params.cambiaredir so
%                              fascicles run bottom-left -> top-right).
%       .cropRect      ([])    [x y w h] crop applied before everything.
%       .apoVisible    (true)  if false, the superficial-apo "no aponeurosis"
%                              trick is applied (top 30 rows -> mean value).
%       .sharpenAmount (0.8)   imsharpen amount.
%       .sharpenRadius (15)    imsharpen radius.
%       .brightness    (1.5)   post-contrast multiplicative gain.
%       .roiTopOffset  (17)    px added below the superficial aponeurosis.
%       .roiBotOffset  (33)    px removed above the deep aponeurosis.
%       .powerPrctile  (97)    percentile threshold on the log-power spectrum.
%       .rescaleLimits ([-0.4 0.8]) rescale limits for the inverse-FFT image.
%       .show          (true)  draw a summary figure.
%
%   OUTPUT (struct)
%   ---------------
%       .raw            grayscale frame after crop/flip (single, [0 1])
%       .preprocessed   after median/contrast/sharpen (the "pre-processing")
%       .roiEnhanced    FFT-enhanced muscle-belly ROI only
%       .powerSpectrum  log power spectrum of the ROI
%       .fftMask        binary spectral mask that was applied
%       .enhanced       full-frame FFT-enhanced image (belly reinserted)
%       .apoDeep/.apoSup the aponeurosis lines actually used
%       .theta          belly rotation angle used (rad)
%
%   The default numeric constants match the original pipeline; expose them
%   through opts if you retune for a different probe / depth.

if nargin < 4 || isempty(opts), opts = struct(); end
def = struct('flip',false,'cropRect',[],'apoVisible',true, ...
             'sharpenAmount',0.8,'sharpenRadius',15,'brightness',1.5, ...
             'roiTopOffset',17,'roiBotOffset',33,'powerPrctile',97, ...
             'rescaleLimits',[-0.4 0.8],'show',true);
fn = fieldnames(def);
for k = 1:numel(fn)
    if ~isfield(opts,fn{k}) || isempty(opts.(fn{k}))
        opts.(fn{k}) = def.(fn{k});
    end
end

%% ---------- Stage 0: geometry normalisation ----------
if opts.flip
    frame = flip(frame,2);
end
if ~isempty(opts.cropRect)
    frame = imcrop(frame,opts.cropRect);
end
if size(frame,3) == 3
    frame = rgb2gray(frame);
end
img = im2single(frame);
out.raw = img;

%% ---------- Stage 1: spatial pre-processing (preprocessing.m) ----------
if ~opts.apoVisible
    % "no superficial aponeurosis" trick: overwrite the top 30 rows with the
    % image mean so the belly ROI logic is not thrown off by the skin line.
    w = size(img,2);
    img(1:30,:) = repmat(mean(img(:)),30,w);
end
img = medfilt2(img,[3 3]);
p   = prctile(img(:),20);
imgC = imadjust(img,[p 0.95],[0 1]);
imgC = min(imgC*opts.brightness,1);
imgS = imsharpen(imgC,'Amount',opts.sharpenAmount,'Radius',opts.sharpenRadius);
imgS = min(max(imgS,0),1);
out.preprocessed = imgS;

%% ---------- Aponeurosis geometry for the FFT ROI ----------
if nargin < 3 || isempty(apoDeep) || isempty(apoSup)
    hF = figure('Name','Draw aponeuroses'); imshow(out.preprocessed);
    title('Draw the DEEP aponeurosis (2 clicks)');
    dl = drawline();  apoDeep = dl.Position;
    title('Draw the SUPERFICIAL aponeurosis (2 clicks)');
    sl = drawline();  apoSup  = sl.Position;
    close(hF);
end
out.apoDeep = apoDeep;
out.apoSup  = apoSup;

%% ---------- Stage 2: frequency-domain enhancement (Tissue_angle.m) ----------
% work on the pre-processed frame, exactly like the pipeline
vf = out.preprocessed;
[ny,nx] = size(vf);

% line fits: index 1 = deep, index 2 = superficial
ip{1} = polyfit(apoDeep(:,1),apoDeep(:,2),1);
ip{2} = polyfit(apoSup(:,1),apoSup(:,2),1);
xEdge = [1;nx];
linePlot(1).x = xEdge; linePlot(1).y = polyval(ip{1},xEdge);
linePlot(2).x = xEdge; linePlot(2).y = polyval(ip{2},xEdge);

% rotate the frame so the superficial aponeurosis is horizontal
theta = atan2(ip{2}(1),1);
out.theta = theta;
tform = affine2d([cos(theta) -sin(theta) 0; sin(theta) cos(theta) 0; 0 0 1]);
im2 = imwarp(vf,tform,'nearest');

x = [linePlot(1).x; linePlot(2).x];
y = [linePlot(1).y; linePlot(2).y];
[X2,Y2] = transformPointsForward(tform,x,y);
shiftX = abs(sin(theta))*ny;
shiftY = abs(sin(theta))*nx;
if theta < 0, X2 = X2+shiftX; else, Y2 = Y2+shiftY; end

% ROI between the two aponeuroses (indices: 3=sup-left, 2=deep-right)
x_1 = floor(X2(3));
y_1 = floor(Y2(3)+opts.roiTopOffset);
h   = floor(Y2(2)-Y2(3)-opts.roiBotOffset);
w   = floor(X2(2)-X2(3));
im3 = im2single(im2);

% clamp ROI to valid image extent (robustness the original assumed away)
x_1 = max(1,x_1); y_1 = max(1,y_1);
w   = min(w, size(im3,2)-x_1);
h   = min(h, size(im3,1)-y_1);
imROI = imcrop(im3,[x_1 y_1 w h]);

% band-pass (difference of Gaussians) + background suppression
g1 = imgaussfilt(imROI,1);
g2 = imgaussfilt(imROI,12);
mask = imbinarize(g1-g2,'global');
mask = bwareaopen(mask,50);
imROI(mask==0) = 0;

% power spectrum
a = fftshift(fft2(imROI));
power = log(1+abs(a).^2);
out.powerSpectrum = power;

[~,ind_c] = max(max(power));
[~,ind_r] = max(max(power'));
centre = [ind_r ind_c];
thr = max(prctile(power,opts.powerPrctile));
[r,c,vals] = find(power > thr);

fmask = zeros(size(power));
fmask(power>thr) = 1;

d = sqrt((r-centre(1)).^2 + (c-centre(2)).^2);
s1 = mean(d)-0.8*std(d);
s2 = mean(d)-0.6*std(d);
for i = 1:numel(vals)
    if d(i) > s1
        if (c(i)>ind_c && r(i)>ind_r) || (c(i)<ind_c && r(i)<ind_r) || ...
           (r(i)==ind_r) || (c(i)==ind_c)
            fmask(r(i),c(i)) = 0;
        end
    end
    if d(i) > s2 && c(i)==ind_c
        fmask(r(i),c(i)) = 0;
    end
end
out.fftMask = fmask;

% inverse transform -> enhanced ROI
imm_fin = ifft2(ifftshift(fmask.*a));
I = rescale(real(imm_fin),opts.rescaleLimits(1),opts.rescaleLimits(2));
out.roiEnhanced = I;

% reinsert enhanced belly into a full-size frame
belly = zeros(size(im3));
yr = y_1:y_1+h; xr = x_1:x_1+w;
belly(yr,xr) = I .* im3(yr,xr);
belly(y_1,:) = 0; belly(y_1+h,:) = 0; belly(:,x_1) = 0; belly(:,x_1+w) = 0;

full = belly + im3;
pAdj = prctile(full(:),30);
full = imadjust(full,[pAdj 0.95],[0 1]);

% rotate back and crop to the original frame size
tformInv = affine2d([cos(-theta) -sin(-theta) 0; sin(-theta) cos(-theta) 0; 0 0 1]);
Iinv = imwarp(full,tformInv,'nearest');
enhanced = imcrop(Iinv,[shiftX shiftY nx ny]);
enhanced = min(max(enhanced,0),1);
enhanced = enhanced(1:min(ny,end),1:min(nx,end));
out.enhanced = enhanced;

%% ---------- summary figure ----------
if opts.show
    figure('Name','US image enhancement','Color','w');
    tiledlayout(2,3,'Padding','compact','TileSpacing','compact');
    nexttile; imshow(out.raw);          title('1. Raw (gray)');
    nexttile; imshow(out.preprocessed); title('2. Pre-processed');
    hold on
    plot(linePlot(1).x,linePlot(1).y,'c','LineWidth',1);
    plot(linePlot(2).x,linePlot(2).y,'c','LineWidth',1); hold off
    nexttile; imshow(out.enhanced);     title('3. FFT-enhanced (full frame)');
    nexttile; imshow(out.roiEnhanced,[]); title('Belly ROI (inverse FFT)');
    nexttile; imagesc(out.powerSpectrum); axis image off; colormap(gca,gray);
    title('Log power spectrum');
    nexttile; imagesc(out.fftMask); axis image off; colormap(gca,gray);
    title('Spectral mask');
end
end
