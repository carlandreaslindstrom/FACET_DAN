function [] = wiggleAnalyzer(dataset, prof_name1, bitdepth1, start_shot)

    % import data structure
    fprintf('Importing data... ');
    [data, preheader] = FACETautoImport(dataset);
    disp('Done.');

    pressure = num2str(data.raw.metadata.E200_state.VGCM_LI20_M3202_PMONRAW.dat);
    disp(['Pressure: ' pressure]);

    imgstruct1 = data.raw.images.(prof_name1);
    UIDs1 = imgstruct1.UID;
    [UIDs indices1] = sort(UIDs1);
    
    %background1 = load([preheader imgstruct1.background_dat{1}]);
    %bg1 = 2*rot90(background1.img,2);
    
    disp('Zoom, then type "w" and press Enter for wavelength measurement');
    disp(' ');

    if strcmpi(prof_name1,'E217_Trans')
	cutoff = 1e7;
    elseif strcmpi(prof_name1,'E224_Trans')
        cutoff = 5e7;
    else
	cutoff = 0;
    end

    num_shots = length(UIDs);
    if ~exist('start_shot','var')
        start_shot = 1;
    end
    for i = start_shot:num_shots

        index1 = indices1(i);
        UID = num2str(UIDs(index1));

        image1 = imread([preheader imgstruct1.dat{index1}]);
        processed_image1 = image1;% - bg1;
        
        % IMAGE
        subplot(2,2,[1,2]);
        imagesc(processed_image1);
        colorbar;
        caxis([0 bitdepth1]);
        title([prof_name1 ' (shot ' num2str(i) ', set ' dataset ')'],'Interpreter','none'); 
        
        subplot(2,2,3);
        plot(sum(processed_image1,1));
	title('Pixel sum projected onto beam axis');       
 
        subplot(2,2,4);
        plot(y_centroids(processed_image1,1));
	title('Centroid offsets from beam axis');
        
	if sum(sum(image1)) < cutoff
	    if mod(i,10) == 0 
		disp([' - ' num2str(i) '/' num2str(num_shots)]);
	    end 
	    continue;
	end
	% sum(sum(image1))

        if true	
	    zoom on;
	    if strcmpi(input(['Shot ' num2str(i) '/' num2str(num_shots) ' '],'s'),'w')
                disp('Click consequtive wave crests, then click Enter.');
		pause(0.1);
		[zs ~] = ginput();
	    	if numel(zs) > 0
	            dzs = zs(2:end)' - zs(1:(end-1))';
                    formt = '%5.2f';
                    dzmean = num2str(mean(dzs), formt);
                    dzmedian = num2str(median(dzs), formt);
                    dzstd = num2str(std(dzs), formt);
                    N = num2str(numel(zs));
                    dzmin = num2str(min(dzs), formt);
                    dzmax = num2str(max(dzs), formt);
                    fprintf('Dataset\tUID\t\tTorr\tMean\tMedian\tMin\tMax\tStDev\tN\n');
                    fprintf([dataset '\t' UID '\t' pressure '\t' dzmean '\t' dzmedian '\t' dzmin '\t' dzmax '\t' dzstd '\t' N '\n']);
		    disp(' ');
	        end
	    end
        else
	    pause();
        end
	
    end

end
