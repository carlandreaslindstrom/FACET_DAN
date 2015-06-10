function [ FWHM, maxPos ] = FWHMy(img)
    
    projY = sum(img,2);
    [maxVal maxPos] = max(projY);    
    cutProjY = find(projY <= maxVal/2);
    FWHMleft = max(cutProjY(cutProjY < maxPos));
    FWHMright = min(cutProjY(cutProjY > maxPos));
    FWHM = FWHMright - FWHMleft;
     
end
