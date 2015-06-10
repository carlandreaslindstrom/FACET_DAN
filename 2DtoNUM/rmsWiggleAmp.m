function [ rmsWiggleAmplitude ] = rmsWiggleAmp(img, zROI, camera)

    [~, ~, ~, rmsWiggleAmplitude, ~] = wiggleDemystifier(img, zROI, camera);
        
end
