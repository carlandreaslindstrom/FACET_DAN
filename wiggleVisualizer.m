function [] = wiggleVisualizer(dataset, bitdepth1, bitdepth2)

    [data, preheader, dataset] = FACETautoImport(dataset);
    
    prof_name1 = 'E224_Trans';
    prof_name2 = 'E224_Vert';
    prof_name3 = 'E217_Trans';
    prof_name4 = 'CMOS_ELAN';
    
    % fix UIDs
    imgstruct1 = data.raw.images.(prof_name1);
    imgstruct2 = data.raw.images.(prof_name2);
    imgstruct3 = data.raw.images.(prof_name3);
    imgstruct4 = data.raw.images.(prof_name4);
    UIDs1 = imgstruct1.UID;
    UIDs2 = imgstruct2.UID;
    UIDs3 = imgstruct3.UID;
    UIDs4 = imgstruct4.UID;
    UIDs = intersect(intersect(intersect(UIDs1,UIDs2),UIDs3),UIDs4);
    [~, indices1] = intersect(UIDs1, UIDs);
    [~, indices2] = intersect(UIDs2, UIDs);
    [~, indices3] = intersect(UIDs3, UIDs);
    [~, indices4] = intersect(UIDs4, UIDs);

    % import backgrounds
    %background1 = load([preheader imgstruct1.background_dat{1}]);
    %background2 = load([preheader imgstruct2.background_dat{1}]);
    background3 = load([preheader imgstruct3.background_dat{1}]);
    background4 = load([preheader imgstruct4.background_dat{1}]);
    
    num_shots = length(UIDs);
    for i = 1:num_shots
        
        % ROIs on images
        %trans_xroi = 1:1200; % for PAMM 1
        %vert_xroi = 128:1076; % for PAMM 1
        %trans_yroi = 320:510; % for PAMM 1
        %vert_yroi = 270:440; % for PAMM 1
        trans_xroi = 36:1260; % for PAMM 2
        vert_xroi = 190:1240; % for PAMM 2
        trans_yroi = 280:530; % for PAMM 2
        vert_yroi = 225:445; % for PAMM 2
        
        % importing images, flip and vertical ROI
        %%{
        image_trans = imread([preheader imgstruct1.dat{indices1(i)}]);% - background1.img;
        processed_image_trans = fliplr(image_trans);
        processed_image_trans = processed_image_trans(trans_yroi,trans_xroi);
        
        image_vert = imread([preheader imgstruct2.dat{indices2(i)}]);% - background2.img;
        processed_image_vert = rot90(image_vert,2);
        processed_image_vert = processed_image_vert(vert_yroi,vert_xroi);
        %}
        
        
        % calibration shots
        %{
        image_trans = load('trans_calib.mat');
        image_vert = load('vert_calib.mat');
        processed_image_trans = image_trans.data.img;
        processed_image_vert = flipud(image_vert.data.img);
        processed_image_trans = processed_image_trans(trans_yroi,trans_xroi);
        processed_image_vert = processed_image_vert(vert_yroi,vert_xroi);
        %}
        
        % E224_Trans image
        subplot(2,3,1);
        imagesc(processed_image_trans);
        set(gca,'YDir','normal');
        colorbar;
        caxis([0 bitdepth1]);
        title([prof_name1 ' (shot ' num2str(i) ', set ' dataset ')'],'Interpreter','none'); 
        
        % E224_Vert image
        subplot(2,3,4);
        imagesc(processed_image_vert);
        set(gca,'YDir','normal');
        colorbar;
        caxis([0 bitdepth2]);
        title([prof_name2 ' (shot ' num2str(i) ', set ' dataset ')'],'Interpreter','none');
        
        %%{
        % FOV calibration
        %trans_calibration = 67.49; % for PAMM 1
        %vert_calibration = trans_calibration*1.2615; % for PAMM 1
        trans_calibration = 70.9; % for PAMM 2
        vert_calibration = 74.8; % for PAMM 2
        
        % calculating centroids
        trans_centroids = y_centroids(processed_image_trans, 3);
        vert_centroids = y_centroids(processed_image_vert, 3);
        
        % vertical pixel sums
        trans_sum = sum(processed_image_trans, 1);
        vert_sum = sum(processed_image_vert, 1);
        %trans_sum = sum(processed_image_trans(1:50,:), 1);
        %vert_sum = sum(processed_image_vert(110:150,:), 1);
        norm_trans_sum = trans_sum/mean(trans_sum);
        norm_vert_sum = vert_sum/mean(vert_sum);
        
        % calibrated positions (also relative z-offset)
        %trans_sync_xpos = 625; % for PAMM 1
        %vert_sync_xpos = 625; % for PAMM 1
        trans_sync_xpos = 622; % for PAMM 2
        vert_sync_xpos = 687; % for PAMM 2
        trans_positions = (trans_xroi - trans_sync_xpos)*trans_calibration;
        vert_positions = (vert_xroi - vert_sync_xpos)*vert_calibration;
        
        startPos = max(trans_positions(1), vert_positions(1));
        endPos = min(trans_positions(end), vert_positions(end));
        
        % sum vs. position plot
        subplot(2,3,2);
        plot(trans_positions, norm_trans_sum,'b');
        hold on;
        plot(vert_positions, norm_vert_sum,'r');
        xlim([startPos, endPos]);
        legend({'E224_Trans', 'E224_Vert'},'Interpreter','none');
        hold off;
        title('Pixel sum vs. z-position'); 
        
        % verticle centroid offset from mean vs. position plot
        subplot(2,3,5);
        plot(trans_positions, trans_centroids,'b');
        hold on;
        plot(vert_positions, vert_centroids,'r');
        xlim([startPos, endPos]);
        legend({'E224_Trans', 'E224_Vert'},'Interpreter','none');
        hold off;
        title('Centroid offset (slope corrected) vs. z-position');
        
        %{
        % E217 trans image
        image_E217 = imread([preheader imgstruct3.dat{indices3(i)}]);
        subplot(2,3,3);
        imagesc(image_E217);
        colorbar;
        caxis([0 400]);
        title(prof_name3,'Interpreter','none'); 
        
        % ELANEX image
        image_ELAN = imread([preheader imgstruct4.dat{indices4(i)}]);
        processed_image_ELAN = image_ELAN;% - 2*background4.img';
        subplot(2,3,6);
        imagesc(processed_image_ELAN);
        colorbar;
        caxis([0 3000]);
        title(prof_name4,'Interpreter','none'); 
        %}
        
        % 3D centroid visualizer
        subplot(2,3,6);
        numPoints = 100;
        dz = (endPos - startPos)/numPoints;
        Z = (1:numPoints)*dz;
        X = zeros(numPoints,1);
        Y = zeros(numPoints,1);
        for i = 1:numPoints
            X(i) = mean(vert_centroids(abs(vert_positions - startPos - i*dz) < dz/2));
            Y(i) = mean(trans_centroids(abs(trans_positions - startPos - i*dz) < dz/2));
        end
        plot3(X, Y, Z);
        axis tight; grid on; view(35,40);
        
        pause();
        
    end

end