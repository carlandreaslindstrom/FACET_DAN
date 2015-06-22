function [ image ] = getProcessedImage(preheader, struct, indices, shot, background, camera)
    
    % read image
    image = imread([preheader struct.dat{indices(shot)}]);

    % rotate if CMOS_FAR
    if strcmp(camera,'CMOS_FAR') || strcmpi(camera,'WLanex')
        image = image';
    end

    % subtract background
    if numel(background)
        image = image - background;
    end            

    % special case flipping left-right on WLANEX
    if strcmp(camera,'CMOS_WLAN') || strcmp(camera,'CMOS_FAR')
        image = fliplr(image);
    end
            
    % fix orientations
    if struct.X_ORIENT(shot)
        if struct.Y_ORIENT(shot)
            image = rot90(image,2);
        else
            image = fliplr(image);
        end
    elseif struct.Y_ORIENT(shot)
        image = flipud(image);
    end

end

