function [ loss ] = energyLoss(img, yROI)
    
    % subtract background (smallest mean of 4 corners)
    sampleN = floor(size(img,2)/100);
    corner = zeros(4,1);
    corner(1) = mean(mean(img(1:sampleN, 1:sampleN)));
    corner(2) = mean(mean(img(end-sampleN:end, 1:sampleN)));
    corner(3) = mean(mean(img(1:sampleN, end-sampleN:end)));
    corner(4) = mean(mean(img(end-sampleN:end, end-sampleN:end)));
    bg = min(corner);
    img = img - bg;
    
    % calculate sigma of y-projection given an ROI
    imgROI = img(yROI,:);
    energyWeighted = sum(imgROI,2) .* (1:numel(yROI))';
    loss = sum( energyWeighted );
    
end
