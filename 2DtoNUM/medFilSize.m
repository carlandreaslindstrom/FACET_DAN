function [ medFilament ] = medFilSize(img, zROI, camera)

    [wavelengthMean, wavelengthStrongest, wiggleStrength, rmsWiggleAmp, medFilament] = wiggleDemystifier(img, zROI, camera);
    
end
