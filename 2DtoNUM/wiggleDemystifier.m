function [wavelengthMean, wavelengthStrongest, wiggleStrength, rmsWiggleAmp, medFilament, typeEnum] = wiggleDemystifier(img, zROI, camera, dataset, UID, pressure)

    % types: 1 = nothing, 2 = straight, 3 = wiggle, 4 = saturated
    
    % visualisation toggle
    visu = true;
    analysing = true;
    
    % default full ROI
    if numel(zROI) == 0
        zROI = 1:size(img,2);
        switch camera
            case 'E224_Vert'
                if str2num(dataset) > 16918
                    %zROI = 1:1100;
                    zROI = 1:400;
                elseif str2num(dataset) > 16495
                    zROI = 200:1200;
                else
                    zROI = 100:1200;
                end
            case 'E224_Trans'
                if str2num(dataset) > 16918
                    zROI = 1:1200;
                elseif str2num(dataset) > 16495
                    zROI = 50:1250;
                end
            case 'E217_Trans'
                zROI = 700:size(img,2);
        end
    end
    
    % subtract background (smallest mean of 4 corners)
    img = double(img);
    sampleN = floor(size(img,2)/100);
    corner = [ mean(mean(img(1:sampleN, 1:sampleN))) ...
                mean(mean(img(end-sampleN:end, 1:sampleN))) ...
                mean(mean(img(1:sampleN, end-sampleN:end))) ...
                mean(mean(img(end-sampleN:end, end-sampleN:end)))];
    bg = min(corner);
    img = img - bg;
    
    % average every n rows together
    n = ceil(numel(zROI)/250);
    ny = 1;
    nROI = zROI(1):n:zROI(end);
    nrows = size(img,1);
    ncols = numel(nROI);
    sigmas = zeros(ncols,1);
    mus = zeros(ncols,1);
    if visu && ~analysing
        disp('Calculating...');
        tic;
    end
    for i = 1:ncols
        means = mean(img(:,nROI(i):min([(nROI(i)+n-1), end]))');
        rows = 1:ny:nrows;
        %means = arrayfun(@(i) mean(means(i:min([i+ny-1, end]))), rows);
        [A mu sigma] = gaussianFit(rows, means, true);
        sigmas(i) = sigma;
        mus(i) = mu;
    end
    if visu && ~analysing
        toc;
    end
    
    % remove noise
    mus = medfilt1([mus(1); mus; mus(end)], 3);
    mus = mus(2:end-1);
    
    % remove slopes and offsets
    zs = (1:numel(mus))';
    p = polyfit(zs, mus, 1);
    slope = p(1);
    offset = p(2);
    centroids = mus - slope*zs - offset;
    
    % filament width
    medFilament = 2*median(sigmas);
    meanFilament = 2*mean(sigmas);
    
    % wiggle amplitude
    rmsWiggleAmp = sqrt(2*mean(centroids.^2));
    
    % autocorrelate
    autocor = xcorr(centroids);
    FTa = abs(fft(autocor));
    L = n*numel(autocor);
    fs = (2:ceil(numel(FTa)/2))';
    FTa = FTa(fs);
    [b index] = max(FTa);
    maxFreq1 = fs(index);
    L/maxFreq1;
    meanFreq = (sum(fs.*FTa)/sum(FTa));
    L/meanFreq;
    noisefs = [fs(2); fs(ceil(end/2):end)];
    noiseFTa = [FTa(2); FTa(ceil(end/2):end)];
    p = polyfit(log(noisefs), log(noiseFTa), 1);
    noisefit = exp(p(1) * log(fs) + p(2));
    processedFT = FTa./noisefit;

    fs2 = fs(1:ceil(end/2));
    processedFT = processedFT(1:ceil(end/2));
    
    [A2, index] = max(processedFT);
    wiggleStrength2 = A2;
    maxFreq2 = fs2(index);
    
    wavelengthStrongest = L/maxFreq2;
    wFT = processedFT - 1;     
    wFT(wFT < 4) = 0;
    %wl2 = L/(sum(fs2.*wFT)/sum(wFT));

    [AFreq muFreq sigmaFreq] = gaussianFit(fs2, wFT);
    wiggleStrength = AFreq;
    wavelengthMean = L/muFreq;
    uniformity = wiggleStrength / rmsWiggleAmp;
    quality = wiggleStrength / sigmaFreq;
    qualityThreshold = 11;
    
    saturated = false;
    nothing = false;
    meanCount = sum(sum(img))/(size(img,1)*size(img,2));
    switch camera
        case 'IPOTR1'
            nothing = meanCount < 18;
            saturated = meanCount > 2100;
        case 'IPOTR2'
            nothing = meanCount < 18;
            saturated = meanCount > 2100;
        case 'E224_Vert'
            nothing = meanCount < 10;
            saturated = meanCount > 2100;
        case 'E224_Trans'
            nothing = meanCount < 10;
            saturated = meanCount > 2100;
        case 'E217_Trans'
            nothing = meanCount < 50;
            saturated = meanCount > 2100;
    end
        
    % distinguish types
    if saturated
        if visu && ~analysing
            disp('Saturated');
        end
        wavelengthMean = 0;
        wavelengthStrongest = 0;
        medFilament = 0;
        wiggleAmplitude = 0;
        typeEnum = 4; % saturated
    elseif nothing
        if visu && ~analysing
            disp('Nothing/Laser');
        end
        wavelengthMean = 0;
        wavelengthStrongest = 0;
        medFilament = 0;
        rmsWiggleAmp = 0;
        typeEnum = 1; % nothing
    elseif wiggleStrength2 < 18 || isnan(sigmaFreq) || quality < qualityThreshold || muFreq < 0 || rmsWiggleAmp < 1
        if visu && ~analysing
            disp('Straight');
        end
        typeEnum = 2; % straight
    else
        if visu && ~analysing
            disp('Wiggle');
        end
        typeEnum = 3; % wiggle
    end
    
    % visualize
    if visu
        
        hold off;
        subplot(2,3,1:3);    
        imagesc(img);
        xlim([zROI(1), zROI(end)]);
        ylim([max([1, mean(mu) - 4*max(sigmas)]), min([size(img,1), mean(mu) + 4*max(sigmas)])]);
        colorbar;
        caxis([0, max(max(img))*0.95]);
        hold on;
        plot(nROI, mus, 'k');
        title([camera ' ' num2str(UID)], 'Interpreter', 'None');
        hold off;
        
        subplot(2,3,4);
        plot(autocor);
        
        subplot(2,3,5:6);

        plot(L./fs2, processedFT, '.');
        xlim([0, max(L./fs2)]/3);
        hold on;
        plot(L./fs2, AFreq.*exp(-(1/2)*((fs2-muFreq)/sigmaFreq).^2) + 1, 'r');
        hold off;
        
        if analysing 
            frmt = '%5.2f';
            %fprintf('Dataset\tUID\t\tTorr\tMean\tMax\tStrngth\tSigma\tFilWdth\tType\tCamera\n');
            fprintf([dataset '\t' num2str(UID) '\t' num2str(pressure,frmt) '\t' num2str(wavelengthMean,frmt) '\t' num2str(wavelengthStrongest,frmt) '\t' num2str(wiggleStrength2,frmt) '\t' num2str(sigmaFreq,frmt) '\t' num2str(medFilament,frmt) '\t' num2str(typeEnum) '\t' camera '\n']);
            %disp(' ');
        else
            disp(['Mean wavelength = ' num2str(wavelengthMean) ' px' ]);
            disp(['Max wavelength = ' num2str(wavelengthStrongest) ' px']);
            disp(['Wiggle strength = ' num2str(wiggleStrength2) ' (' num2str(wiggleStrength) ')']);
            disp(['Wiggle amplitude = ' num2str(rmsWiggleAmp)]);
            disp(['Filament width = ' num2str(medFilament) ' px']);
            disp(['Frequency sigma = ' num2str(sigmaFreq)]);
        end
        pause(1);
    end

end
