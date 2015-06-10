function [ wavelength, amplitude, quality ] = wiggleWavelength( img, z_start, z_end )

    % cut off unwanted edges
    if nargin == 2
        img = img(:,z_start:end);
    else if nargin == 3
        img = img(:,z_start:z_end);
    end

    % remove nasty background
    img = img - mean(mean(img));
    img(img < 0) = 0;

    % calculate centroids
    centroids = y_centroids(img, 30);

    % remove artifacts from median filter
    centroids = centroids(ceil(0.2*end):ceil(0.8*end));

    % remove centroid slope and mean value
    p = polyfit(1:numel(centroids), centroids', 1);
    centroids = centroids - (1:numel(centroids))'*p(1);
    centroids = centroids - mean(centroids);
    
    % TEST DATA: perfect sinusoidal data (should get 100% quality and correct wavelength)
    % testWavelength = 100;
    % testSize = 1000;
    % testAmplitude = 4;
    % centroids = testAmplitude*sin(2*pi*(1:testSize)/testWavelength)';
    
    % autocorrelation (select last half as symmetric)
    autocor = xcorr(centroids);
    autocor = autocor((floor(end/2)-2):end);
    
    %{
    % find minima and maxima and their locations
    [maxs maxlocs] = peakfinder(autocor,0,0);
    [mins minlocs] = peakfinder(-autocor,0,0);
    mins = -mins;

    % combine maxima and minima to list of extrema
    extrs = zeros(numel(mins)+numel(maxs),1);
    extrlocs = extrs; 
    extrs(1:2:end) = maxs;
    extrs(2:2:end) = mins;
    extrlocs(1:2:end) = maxlocs;
    extrlocs(2:2:end) = minlocs;
    halfperiod = extrlocs(2:(end-1)) - extrlocs(1:(end-2));

    if false && numel(extrs) == 0
        wavelength = 0;
        amplitude = 0;
        quality = 0;
        return;
    end

    % filter out tiny noise by making a mask
    noiseFloor = 0.1;
    periodMask = halfperiod > noiseFloor * max(halfperiod);

    % do (half) wavelength statistics after masking
    meanhalf = mean(halfperiod(periodMask));
    % meanhalf = sum(halfperiod(periodMask)./(1:numel(periodMask))')/sum(1./(1:numel(periodMask)));
    % halfperiod = halfperiod(periodMask);
    % meanhalf = mean(halfperiod(1));
    stdhalf = std(halfperiod(periodMask));

    % calculate quality based on [variations in wavelength] and [number of noisy periods]
    quality1a = 1 - stdhalf/meanhalf;
    quality1b = sum(periodMask)/numel(periodMask);

    % ratios 
    %ratios = extrs(1:end)/extrs(1) .* ( (-1).^(1:(numel(extrs))) )';
    %modFactors = 1 - (extrlocs(1:end) - maxlocs(1)) ./ (numel(autocor) - maxlocs(1) + 1);
    %weightedRatios = ratios ./ modFactors(1:numel(ratios));
    %ratioMask = and(weightedRatios < 1.05, weightedRatios > 0); 

    % quality factors based on ratios
    %quality2a = mean(weightedRatios(ratioMask));
    %quality2b = sum(ratioMask)/numel(ratioMask);

    % composite quality factors
    qualityProduct = quality1a^(1/4) * quality1b; % * quality2a^(1/2) * quality2b;
    %qualityMean = mean([quality1a, quality1b, quality2a, quality2b]);
    
    % return results
    wavelength = 2*meanhalf;
    amplitude = sqrt(abs(maxs(1) - mins(1))/(numel(autocor)-3));
    quality = qualityProduct;
    %}
    
    % code used in development (has plots)
    if true
	
        %{
	subplot(4,1,1);
    	plot(centroids);

    	subplot(4,1,2);
    	plot(autocor)

        freqs = abs(fft(centroids));
    	freqs = freqs(1:ceil(end/2));
        %}
    	autofreqs = abs(fft(autocor));
    	autofreqs = autofreqs(1:ceil(end/2));
	%{
    	subplot(4,1,3);
    	plot(1:numel(autofreqs), autofreqs)
    	set(gca, 'xscale', 'log');
    	set(gca, 'yscale', 'log');
    	xlim([2,numel(autofreqs)]);
    	%}
    	fs = (1:numel(autofreqs))';
    	p = polyfit(log(fs(4:end)),log(autofreqs(4:end)),1);
    	ft = exp(p(1) * log(fs) + p(2));
    	
        %{
        plot(autofreqs);
    	hold on;
    	plot(ft,'r');
    	hold off;
    	set(gca, 'xscale', 'log');
    	set(gca, 'yscale', 'log');
    	xlim([2, numel(ft)]);
    	%}
    	
        nobg = autofreqs./ft;
    	
        %{
        subplot(4,1,4);
    	plot(nobg);
    	set(gca, 'xscale', 'log');
    	set(gca, 'yscale', 'log');
    	xlim([2, numel(nobg)]);
        %}
        
    	[maxintensity maxfreq] = max(nobg);
    	stdintensity = std(nobg(4:end));
    	intensityratio = maxintensity/stdintensity;
    	fftwavelength = 2*numel(autocor)/maxfreq;
    	wavelength = fftwavelength;
        amplitude = intensityratio;
        quality = 0;
    end

end
