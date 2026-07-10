function  [imm]=preprocessing(Params,frame,videoFileReader1)


        Img = read(videoFileReader1, frame);
        if Params.cambiaredir==1
        Img = flip(Img, 2); % * comment if the fascicle are oriented bottom left top right
        end
        Img=imcrop(Img,Params.imCropRect);
        Img=rgb2gray(Img);
        Img=im2single(Img); %figure,imshow(Img)
        if strcmp(Params.apo_visibile,'no ')
        [height, width, numChannels] = size(Img);

        % Take the mean of the whole image
        m=mean(Img(:));

        % Replicate the mean across the full image width
        mean_row = repmat(m, 30, width, 1);

        % Take everything except the last 30 rows
        remaining_img = Img(1:end-30, :, :);

        % Stack the mean row on top of the rest of the image
        Img = [mean_row; remaining_img];
        end




        % Flip each frame
        % Img = flip(Img, 2); % * comment if the fascicle are oriented bottom left top right
        %figure,imshow(Img)
        % DAS
        Img = medfilt2(Img, [3 3]);
        %Img=imgaussfilt(Img,1);
        %Img = imnlmfilt(Img);
        % Contrast and brightness adjustment
        p=prctile(Img(:),20);
        Img_contrast = imadjust(Img, [p, 0.95], [0.0,1.0]); %figure, imshow(Img_contrast)
        im=Img_contrast*1.5;%figure,imshow(im)
        im(im>1)=1;
        % % 2. Edge enhancement for both DAS and FDMAS
        Img_sharp = imsharpen(im, 'Amount',0.8, 'Radius',15);
        Img_sharp(Img_sharp<0)=0;
        Img_sharp(Img_sharp>1)=1;  %figure,imshow((Img_sharp))

        % Write to video file
        imm=Img_sharp;
        %imm=(imm-min(min(imm)))./(max(max(imm))-min(min(imm)));
        imm(imm<0)=0;
        imm(imm>1)=1; %figure,imshow((imm)), title('processed FDMAS image')



end
