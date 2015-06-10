function [ sigma ] = beamSigma(img)

   % subtract background (smallest mean of 4 corners)
    sampleN = floor(size(img,2)/100);
    corner = zeros(4,1);
    corner(1) = mean(mean(img(1:sampleN, 1:sampleN)));
    corner(2) = mean(mean(img(end-sampleN:end, 1:sampleN)));
    corner(3) = mean(mean(img(1:sampleN, end-sampleN:end)));
    corner(4) = mean(mean(img(end-sampleN:end, end-sampleN:end)));
    bg = min(corner);
    img = img - bg;
    
    xproj = sum(img,1);
    xs = (1:size(img,2));
    mux = sum( xproj .* xs ) / sum(xproj);
    mux2 = sum( xproj .* (xs.^2) ) / sum(xproj);
    sigmax = sqrt( mux2 - mux^2 );

    yproj = sum(img,2);
    ys = (1:size(img,1))';
    muy = sum( yproj .* ys ) / sum(yproj);
    muy2 = sum( yproj .* (ys.^2) ) / sum(yproj);
    sigmay = sqrt( muy2 - muy^2 );

    sigma = sqrt( sigmax^2 + sigmay^2 );
    
end
