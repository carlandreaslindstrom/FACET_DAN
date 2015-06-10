function [ result ] = filamentSize( img )

    % remove background
    img = img - mean(mean(img));
    img(img < 0) = 0;

    % standard deviations
    n = size(img,2);
    stds = zeros(n,1);
    for i = 1:n
        x = 1:size(img,1);
        fx = img(:,i);
        stds(i) = sqrt( sum((x.^2).*fx)/sum(fx) - (sum(x.*fx)/sum(fx))^2); % sigma
    end
    
    % use the median size
    result = median(stds);
end
