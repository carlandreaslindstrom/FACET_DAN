function [ centroids ] = y_centroids( img, medFiltOrder)
    
    % convert to double
    img = double(img);
    
    % calculate y-centroids
    n_rows = size(img,1);
    n_cols = size(img,2);
    centroids = zeros(n_cols, 1);
    for i = 1:n_cols
        centroids(i) = sum(img(:,i)' .* double((1:n_rows))) / sum(img(:,i));
    end
    
    % straighten tilt
    leftMean = mean(centroids(floor(0.05*n_cols):floor(0.45*n_cols)));
    rightMean = mean(centroids(floor(0.55*n_cols):floor(0.95*n_cols)));
    slope = (rightMean-leftMean)/(0.5*n_cols);
    centroids = centroids - (1:n_cols)'*slope;
    
    % apply median filter of given order
    if medFiltOrder > 0
        centroids = medfilt1(centroids, medFiltOrder);
        centroids([1:medFiltOrder, end-medFiltOrder:end]) = mean(centroids);
    end

    % subract mean of centroids to obtain residues
    centroids = centroids - mean(centroids);
    
end

