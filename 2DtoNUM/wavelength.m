function [ lambda ] = wavelength(img, zROI, camera)
    
    [wavelengthMean, wavelengthStrongest, wiggleStrength, rmsWiggleAmp, medFilament] = wiggleDemystifier(img, zROI, camera);
    lambda = mean([wavelengthMean, wavelengthStrongest]);    
    
end
