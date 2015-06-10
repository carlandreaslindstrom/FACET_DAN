function [ ] = mcw_temp( dataset, cameras, imageFunctions, bitDepths, shots, isScan, doAvg, cutoffs )

    % white figure backgrounds
    set(gcf, 'Color', 'w');
    
    % colormaps
    % "white -> blue -> green -> yellow -> red"
    D = [1 1 1; 0 0 1; 0 1 0; 1 1 0; 1 0 0;];
    F = [0 0.25 0.5 0.75 1];
    G = linspace(0, 1, 256);
    cmap.wbgyr = interp1(F,D,G);
    colormap(cmap.wbgyr);
    
    % scalar dictionary
    dstoroid = {'GADC0_LI20_EX01_CALC_CH3_', 'DS TOROID'};
    ustoroid = {'GADC0_LI20_EX01_CALC_CH2_', 'US TOROID'};
    pyro = {'BLEN_LI20_3014_BRAW', 'PYRO'};
    laserpower = {'PMTR_LA20_10_PWR','LASER POWER'};
    
        % fail if wrong number of functions 
    assert(numel(cameras) == numel(imageFunctions));

    % import data structure
    fprintf('Importing data... ');
    [data, preheader, dataset] = FACETautoImport(dataset);
    
    % intersect UIDs
    Ncam = numel(cameras);
    Ncuts = numel(cutoffs);
    N = Ncam + Ncuts + isScan;
    structs = cell(N,1);
    indices = cell(N,1);
    labels = cell(N,1);
    UIDs = [];
    for i = 1:N
        if i <= Ncam
	        struct = data.raw.images.(cameras{i});
            fstr = strtrim(func2str(imageFunctions{i}));
            label = [fstr ' @ ' cameras{i}];
        elseif i > Ncam && i <= Ncam + Ncuts
            scalar = cutoffs{i-Ncam}{1};
            scalar = strrep(scalar, ustoroid{2},   ustoroid{1});
            scalar = strrep(scalar, dstoroid{2},   dstoroid{1});
            scalar = strrep(scalar, pyro{2},       pyro{1});
            scalar = strrep(scalar, laserpower{2}, laserpower{1});
            struct = data.raw.scalars.(scalar);
            
            label = cutoffs{i-Ncam}{1};
            label = strrep(label, ustoroid{1}, ustoroid{2});
            label = strrep(label, dstoroid{1}, dstoroid{2});
            label = strrep(label, pyro{1}, pyro{2});
            label = strrep(label, laserpower{1}, laserpower{2});
            label = strrep(label,'LI20_','');
        elseif isScan
            struct = data.raw.scalars.('step_value');
            label = 'Scan variable';
        end
	    structs(i) = {struct};
        labels(i) = { label };
        
	    if i == 1
            UIDs = struct.UID;
        else
            UIDs = intersect(UIDs, struct.UID);
        end
    end

    % get indices
    for i = 1:N
        [~, ind] = intersect(structs{i}.UID, UIDs);
        indices(i) = {ind};
    end
    
    % if 1 shot entered, start with this. if none, show all.
    nUIDs = numel(UIDs);
    if exist('shots', 'var') && numel(shots)>0
        if numel(shots) == 1
            shots = shots:nUIDs;
        end
        shots = shots(shots > 0);
        shots = shots(shots <= nUIDs);
    else
        shots = 1:nUIDs;
    end
    
    % do shot cutoff filtering
    for i = 1:Ncuts
        if i == 1 && numel(cutoffs{i}) > 1
            cutValues = structs{Ncam+i}.dat(indices{Ncam+i}(shots));        
            minCut = min(cutoffs{i}{2});
            maxCut = max(cutoffs{i}{2});
            shots = shots(and(minCut <= cutValues, cutValues <= maxCut));
        end
    end
    nshots = numel(shots);
    
    % do scan sorting
    if isScan
        stepValues = structs{N}.dat(indices{N}(shots));
        if Ncuts > 0
            uniqueStepValues = unique(stepValues);
            sortedValues = zeros(numel(shots), 1);
            ticks = zeros(numel(uniqueStepValues),1);
            count = 0;
            for i = 1:numel(uniqueStepValues)
                valueShots = shots(stepValues == uniqueStepValues(i));
                sortValues = structs{Ncam+1}.dat(indices{Ncam+1}(valueShots));
                [sortValues, sortIndices] = sort(sortValues);
                sortedValues((count+1):(count + numel(valueShots))) = sortValues;
                shots((count+1):(count + numel(valueShots))) = valueShots(sortIndices);
                count = count + numel(valueShots);
                ticks(i) = count;
            end
            xticks = [0 ticks'];
            xticks = (xticks(1:(end-1)) + xticks(2:end))/2  + 0.5;
        else
            sortedValues = stepValues;
        end
    else
        if Ncuts > 0
            sortValues = structs{Ncam+1}.dat(indices{Ncam+1}(shots));
            [sortedValues, sortIndices] = sort(sortValues);
            shots = shots(sortIndices);
        end
    end

    % find backgrounds if saved
    background = cell(Ncam,1);
    subBg = zeros(Ncam,1);
    if data.raw.metadata.param.save_back
        for i = 1:Ncam
            subBg(i) = ( numel(strfind(cameras{i}, 'CMOS')) > 0 );
            bg = load([preheader structs{i}.background_dat{1}]);
            multiplier = 2;
            background(i) = { multiplier * bg.img };
        end
    end

    % cycle through cameras
    fprintf(['Analyzing ' num2str(Ncam*nshots) ' images... ']);
    progress = 0;
    nPlots = Ncam +1;
    nHor = floor(sqrt(nPlots));
    nVert = ceil(nPlots/floor(sqrt(nPlots)));
    for i = 1:Ncam
        
        % temporary function values
        f = imageFunctions{i};
        testImage = imread([preheader structs{i}.dat{indices{i}(1)}]);
        lineSize = numel(f(testImage));
        lines = zeros(lineSize, nshots);
        for j = 1:nshots
            shot = shots(j);
            
            % show progress (because people are impatient)
            current = floor((nshots*(i-1) + j)/(nshots*Ncam)*100);
            if current >= progress + 10
               progress = floor(current/10)*10;
               fprintf([num2str(progress) '%% ']);
            end
            
            % read image
            image = imread([preheader structs{i}.dat{indices{i}(shot)}]);
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
            
            % special case flipping left-right on WLANEX
            if strcmpi(cameras{i},'CMOS_WLAN')
                processedImage = fliplr(processedImage);
            end
            
	        % do 2D to 1D projection
            lines(:,j) = f(processedImage)';
        end
        
        % plot waterfalls
        subplot(nVert, nHor, i);
        imagesc(1:nshots, 1:lineSize, lines);
        if isScan && Ncuts > 0
            set(gca, 'XTick', xticks);
            set(gca, 'XTickLabel', uniqueStepValues);
            if( isfield(data.raw.metadata.param, 'fcnHandle') )
                step_str = [', "' func2str(data.raw.metadata.param.fcnHandle) '"'];
            else
                step_str = '';
            end
            xlabel(['Step value' step_str], 'Interpreter', 'None');
            for x = ticks + 0.5
                line([x x], ylim, 'Color', [0 0 0]);
            end
        else
            xlabel('Shot # (used shots)');
        end
        ylabel('Projection');
        title(labels{i}, 'Interpreter', 'None');
        colorbar;
        caxis([0 bitDepths{i}]);
    end
    
    % plot sorting plot
    subplot(nVert, nHor, nPlots:(nVert*nHor));
    xlab = 'Shot # (used shots)';
    if isScan
        if Ncuts > 0
            stairs(sortedValues);
            xlim([1 (numel(sortedValues))]);
            xlab = ['Step value' step_str];
            ylabel(labels{Ncam+1});
            set(gca, 'XTick', xticks + 0.5);
            set(gca, 'XTickLabel', uniqueStepValues);
            for x = ticks + 1
                line([x x], ylim, 'Color', [0 0 0]);
            end
        else
            stairs(stepValues);
            ylabel('Step value');
        end
    else
        if Ncuts > 0
            stairs(sortedValues);
            ylabel(labels{Ncam+1});
        else
            stairs(shots);
            ylabel('Shot # (all shots)');
        end
    end
    title(['Sorting plot, dataset ' dataset ' (' num2str(nshots) '/' num2str(nUIDs) ' shots)']);
    xlabel(xlab, 'Interpreter', 'None');
    
    disp('...done.');
end

