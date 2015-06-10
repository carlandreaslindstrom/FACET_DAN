function [ rms ] = wiggleAmplitude( img, z_start, z_end )
    
    % ROI
    if nargin == 2
	img = img(:,z_start:end);
    else if nargin == 3
        img = img(:,z_start:z_end);
    end 
        
    % skip if signal/noise ratio is too low
    signal = max(mean(img'));
    noise = min(mean(img'));
    if signal/noise < 6.0
        rms = 0;
        return;
    end

    % filter noise floor
    img = img - 2*mean(mean(img'));
    img(img < 0) = 0;

    % find centroids in y
    centroids = y_centroids(img, 30);

    % remove artifacts from median filter 
    centroids = centroids(ceil(0.25*end):ceil(0.75*end));

    % remove centroid slope and mean value
    p = polyfit(1:numel(centroids), centroids', 1);
    centroids = centroids - (1:numel(centroids))'*p(1);
    centroids = centroids - mean(centroids);    

    % amplitude defined as the rms of the centroids
    rms = sqrt(mean(centroids.^2));
 
end
