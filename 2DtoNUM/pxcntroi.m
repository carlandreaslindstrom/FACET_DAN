function [ count ] = pxcntroi(img, xROI, yROI)
    
    imgROI = img(xROI, yROI);
    count = sum(sum(imgROI));
    
end
