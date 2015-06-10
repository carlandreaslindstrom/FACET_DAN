function [ quality ] = wiggleQuality( img, z_start, z_end )

    if nargin =	3
        [wavelength amplitude quality] = wiggleWavelength(img, z_start, z_end);
    else if nargin = 2
        [wavelength amplitude quality] = wiggleWavelength(img, z_start);
    else    
        [wavelength amplitude quality] = wiggleWavelength(img);
    end

end
