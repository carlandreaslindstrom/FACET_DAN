function [ ] = multiCameraVisualizer( dataset, cameras, bitDepthAndROI, shots, specifiedUIDs)

    % white plot background
    set(gcf, 'Color', 'w');
    
    % colormaps
    % "white -> blue -> green -> yellow -> red"
    D = [1 1 1; 0 0 1; 0 1 0; 1 1 0; 1 0 0;];
    F = [0 0.25 0.5 0.75 1];
    G = linspace(0, 1, 256);
    cmap.wbgyr = interp1(F,D,G);
    colormap(cmap.wbgyr);
                                    
    % import data structure
    fprintf('Importing data... ');
    [data, preheader, dataset] = FACETautoImport(dataset);
    
    
    % intersect UIDs
    N = numel(cameras);
    structs = cell(N,1);
    indices = cell(N,1);
    for i = 1:N
        struct = data.raw.images.(cameras{i});
        structs(i) = {struct};
        
        % making sure there are actually files
        fileMask = cellfun(@numel, struct.dat) > 0;
        
        if i==1
            UIDs = struct.UID(fileMask);
        end
        UIDs = intersect(UIDs, struct.UID(fileMask));
    end
    
    % intersect with user specified UIDs
    if exist('specifiedUIDs', 'var') && numel(specifiedUIDs) > 0
        UIDs = intersect(UIDs, specifiedUIDs);
    end
    
    % get indices
    for i = 1:N
        [~, ind] = intersect(structs{i}.UID, UIDs);
        indices(i) = { ind };
    end

    % find backgrounds if saved
    background = cell(N,1);
    subBg = zeros(N,1);
    if data.raw.metadata.param.save_back 
        for i = 1:N
            bg = load([preheader structs{i}.background_dat{1}]);
            multiplier = 2;
            if strcmpi(cameras{i}, 'IP2A') || strcmp(cameras{i},'CMOS_FAR')
                bg.img = fliplr(bg.img);
                subBg(i) = true;
            elseif numel(strfind(cameras{i}, 'CMOS')) % subtract if CMOS
                subBg(i) = true;
            end
            background(i) = { multiplier * bg.img };            
        end
    end

    % set bit depths and ROIs
    xROIs = cell(N,1);
    yROIs = cell(N,1);
    bitDepths = cell(N,1);
    for i =1:N
        bitDepths(i) = { 0 };
        xROIs(i) = { 1:structs{i}.ROI_XNP };
        yROIs(i) = { 1:structs{i}.ROI_YNP };
        if exist('bitDepthAndROI','var') && i <= numel(bitDepthAndROI)
            bdroi = bitDepthAndROI{i};
            if strcmpi(class(bdroi),'double')
                bitDepths(i) = { bdroi };
            elseif strcmpi(class(bdroi),'cell') && numel(bdroi)
                bitDepths(i) = { bdroi{1} };
                if numel(bdroi) >= 2 && numel(bdroi{2})
                    yROIs(i) = { intersect(bdroi{2}, yROIs{i}) };
                end
                if numel(bdroi) >= 3 && numel(bdroi{3})
                    xROIs(i) = { intersect(bdroi{3}, xROIs{i}) };
                end
            end
        end
    end
    
    % make list for user-selected shots
    markedUIDs = [];

    % if 1 shot entered, start with this. if none, show all.
    nShots = numel(UIDs);
    if exist('shots', 'var') && numel(shots)>0
        if numel(shots) == 1
            shots = shots:nShots;
        end
        shots = shots(and(shots>0, shots<=nShots));
    else
        shots = 1:nShots;
    end    
    
    % display images shot for shot
    disp('Press Enter for next shot. Type "s", then Enter to mark shot.');
    for shot = shots

        % cycle through cameras
        for i = 1:N
            
            % unique identifier
            UID = structs{i}.UID(indices{i}(shot));
            
	        % read image
            image = imread([preheader structs{i}.dat{indices{i}(shot)}]);
            
            % rotate if CMOS_FAR
            if strcmp(cameras{i},'CMOS_FAR')
                image = image';
            end
            
            % subtract background
	        if subBg(i)
                processedImage = image - background{i};
            else
	    	    processedImage = image;
            end            
            
            % fix orientations
            if structs{i}.X_ORIENT(shot) == 1
                processedImage = fliplr(processedImage);
            end
            if structs{i}.Y_ORIENT(shot) == 1
                processedImage = flipud(processedImage);
            end

            % plot image (tries to make square layout)
            subplot(ceil(N/floor(sqrt(N))),floor(sqrt(N)),i);
            imagesc(xROIs{i}, yROIs{i}, processedImage(yROIs{i}, xROIs{i}));
            colorbar;
            caxis([0 bitDepths{i}]);
            title([ cameras{i} ' (' num2str(shot) '/' num2str(nShots) ', ' num2str(UID) ', dataset ' dataset ')'],'Interpreter','none');
            
            % show custom function
            if strcmp(cameras{i},'E224_Vert')
                 [amplitude, width, brightness] = oscAmp(processedImage, 250:650,200:1100)
            end
        end
        
        % pause, show progress and mark shots
        if strcmpi(input(['Image ' num2str(shot) '/' num2str(nShots) ' (' num2str(UID) ') '],'s'),'s')
            format long;
            markedUIDs = [markedUIDs; UID]
        end
            
    end
    
end
