function [ pixelCount ] = pxcount(img, z_start, z_end )

    % ROI
    if nargin == 2
        img = img(:,z_start:end);
    else if nargin == 3
        img = img(:,z_start:z_end);
    end
    
    % sum rows and columns
    pixelCount = sum(sum(img));
    
end
