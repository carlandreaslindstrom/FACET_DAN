function [ emit, xSize, divergence, pinchLocation ] = emittance(img, yROI)

    addpath('utils');
    
    % subtract background (smallest mean of 4 corners)
    sampleN = floor(size(img,2)/10);
    corner = zeros(4,1);
    corner(1) = mean(mean(img(1:sampleN, 1:sampleN)));
    corner(2) = mean(mean(img(end-sampleN:end, 1:sampleN)));
    corner(3) = mean(mean(img(1:sampleN, end-sampleN:end)));
    corner(4) = mean(mean(img(end-sampleN:end, end-sampleN:end)));
    bg = min(corner);
    img = img - bg;
    %img(img < 0) = 0;
    
    % average every n rows together
    n = 5;
    nROI = yROI(1):n:yROI(end);
    nrows = numel(nROI);
    ncols = size(img,2);
    sigma_x = zeros(nrows,1);
    mu_x = zeros(nrows,1);
    for i = 1:nrows
        means = mean(img(nROI(i):(nROI(i)+n-1),:));
        [A mu sigma] = gaussianFit(1:ncols, means);
        sigma_x(i) = sigma;
        mu_x(i) = mu;
    end
    %plot(sigma_x)
    %pause;
        
    % parabolic fit
    nROI = double(yROI(1:n:(n*numel(sigma_x))))';
    y = (1:numel(sigma_x))';
    [p, S] = polyfit(y, sigma_x, 2); % use relative ROI to ease calc.
    [fitted errors] = polyval(p, y, S);

    % plot the fit
    if false
        xROI = 900:1250;
        imagesc(img(yROI, xROI)')
        hold on;
        scatter(nROI-nROI(1), sigma_x + mean(mu_x)-xROI(1), 'r');
        plot(nROI-nROI(1), fitted + mean(mu_x)-xROI(1), 'g');
        hold off; 
        pause;
    end

    divergence = p(1);
    xSize = p(3) - p(2)^2/(4*p(1));
    pinchLocation = nROI(1) - n * p(2)/(2*p(1));
    emit = xSize * divergence;
    
    % if bad fit, only return 0s
    if(divergence < 0 || xSize < 0 || mean(errors) > 10)
        xSize = 0;
        emit = 0;
        divergence = 0;
        pinchLocation = 0;
    end

end
