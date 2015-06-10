function [ amplitude ] = wiggleAmp( img, z_start, z_end )

    amp = 0;
    if nargin == 3
        [~, amp] = wiggleWavelength(img, z_start, z_end);
    else if nargin == 2
        [~, amp] = wiggleWavelength(img, z_start);
    else
        [~, amp] = wiggleWavelength(img);
    end
    
    amplitude = amp;
end
