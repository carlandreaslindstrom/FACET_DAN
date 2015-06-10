function [ amplitude, width, brightness ] = oscAmp(img, yROI, xROI )
    %cut = 20;
    %img(img < cut) = 0;
    addpath('utils');
    
    img = double(img(yROI,xROI));

    n = 20;
    ny = floor(size(img,1)/n);
    nx = floor(size(img,2)/n);
    means = zeros(ny, nx);
    px = 1:ny;
    centroids = zeros(nx,1);
    widths = zeros(nx,1);
    brightnesses = zeros(nx,1);
    line = zeros(ny,1);
    guess = [];
    for j = 0:(nx-1)
        for i = 0:(ny-1)
            line(i+1) = mean(mean( img((n*i+1):(n*(i+1)), (n*j+1):(n*(j+1))) ));
            %means(i+1,j+1) = sum(sum( img((n*i+1):(n*(i+1)), (n*j+1):(n*(j+1))) )); 
        end
        [A mu sigma] = gaussianFit(px', line, false, guess);
        %[A mu sigma] = gaussianFit(px', means(:,j+1), false, guess);
        guess = [A mu sigma];
        centroids(j+1) = mu;
        widths(j+1) = sigma;
        brightnesses(j+1) = A;
        
        %plot(px, means(:,j+1), px, A*exp(-0.5*((px-mu)/sigma).^2) )
        %pause(0.1)
    end

    %centroids = sum(ndgrid(1:size(means,1),1:size(means,2)).*means,1)./sum(means,1);
    
    
    visu = false;
    if visu
        imagesc(means)
        pause 

        subplot(2,1,1);
        plot(centroids)
    end
    
    zs = 1:numel(centroids);
    p = polyfit(zs', centroids, 1);
    centroids = centroids - p(2) - zs'.*p(1);
    
    %ord = 15;
    %centroids = medfilt1([centroids(1:ord) centroids centroids((end-ord):end)], ord);
    %centroids = centroids(ord:(end-ord));
    %centroids(isnan(centroids)) = 0;

    %zs = 1:numel(centroids);
    %p = polyfit(zs, centroids, 1);
    %centroids = centroids - p(2) - zs.*p(1);
    
    if visu
        subplot(2,1,2)
        plot(centroids,'r');
    end
    
    width = mean(widths)*n;
    amplitude = std(centroids)*n;
    brightness = mean(brightnesses);
     
end
