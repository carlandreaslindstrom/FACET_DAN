function [ count ] = unaffectedCharge(img, xROI, yROI)
    
    imgROI = img(xROI, yROI);

    if false
        imagesc(img);
        pause;
        imagesc(imgROI);
        pause;
    end
    
    count = sum(sum(imgROI));
    
end
