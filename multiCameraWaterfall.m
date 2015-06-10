function [ ] = multiCameraWaterfall( dataset, cameras, imageFunctions, bitDepths, shots, isScan, doAvg, cutoffs )

    % ROI input: {bitdepth,bitdepth}  e.g. {0, 1e4} 
    %            or {{bitdepth,yroi}, {bitdepth,yroi}}  e.g. {{0,1:100}, {1e4,10:150}}
    %            or {{bitdepth,yroi,xroi}, {bitdepth,yroi,xroi}}  e.g. {{0,1:100,300:400}, {1e4,10:150,200:500}}
    %            or {{bitdepth,yroi,xroi}, bitdepth}  e.g. {{0,1:100,300:400}, 1e4}

    
    % import 2D to 1D projection functions
    addpath('2Dto1D');

    % white plot background
    set(gcf, 'Color', 'w');
    
    % colormaps:  "white -> blue -> green -> yellow -> red"
    D = [1 1 1; 0 0 1; 0 1 0; 1 1 0; 1 0 0;];
    F = [0 0.25 0.5 0.75 1];
    G = linspace(0, 1, 256);
    cmap.wbgyr = interp1(F,D,G);
    colormap(cmap.wbgyr);
    
    % scalar dictionary
    dictionary = {{'GADC0_LI20_EX01_CALC_CH3_', 'DS TOROID'} ...
                  {'GADC0_LI20_EX01_CALC_CH2_', 'US TOROID'} ...
                  {'BLEN_LI20_3014_BRAW', 'PYRO'} ...
                  {'PMTR_LA20_10_PWR','LASER POWER'}};
    
    % fail if wrong number of functions 
    assert(numel(cameras) == numel(imageFunctions));

    % import data structure
    fprintf('Importing data... ');
    [data, preheader, dataset] = FACETautoImport(dataset);
    
    % record whether to cut variable
    Ncam = numel(cameras);
    Ncuts = 0;
    if exist('cutoffs','var')
        Ncuts = numel(cutoffs);
        isCutCam = zeros(Ncuts,1);
        for i = 1:Ncuts
            isCutCam(i) = numel(cutoffs{i}) > 1 && strcmpi(class(cutoffs{i}{2}), 'function_handle');
        end
    end

    % intersect UIDs
    N = Ncam + Ncuts + isScan;
    structs = cell(N,1);
    indices = cell(N,1);
    labels = cell(N,1);
    for i = 1:N
        if i <= Ncam
	        struct = data.raw.images.(cameras{i});
            label = [cameras{i} ' ' strtrim(func2str(imageFunctions{i}))];
        elseif i > Ncam && i <= Ncam + Ncuts
            j = i - Ncam;
            if isCutCam(j)
                struct = data.raw.images.(cutoffs{j}{1});
                label = [cutoffs{j}{1} ' ' strtrim(func2str(cutoffs{j}{2}))];
            else
                scalar = cutoffs{j}{1};
                label = scalar;
                % translate to and from simpler words
                for lookup = dictionary
                    scalar = strrep(scalar, lookup{1}{2}, lookup{1}{1});
                    label = strrep(label, lookup{1}{1}, lookup{1}{2});
                end
                struct = data.raw.scalars.(scalar);
           end
        elseif isScan
            struct = data.raw.scalars.('step_value');
            label = 'Scan variable';
        end
	    structs(i) = { struct };
        labels(i) = { label };
        
        if i == 1
            UIDs = struct.UID;
        end
        UIDs = intersect(UIDs, struct.UID);
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
        shots = shots(and(shots > 0, shots <= nUIDs));
    else
        shots = 1:nUIDs;
    end
    nshots = numel(shots);
    
    % do shot cutoff filtering
    cutValues = cell(Ncuts+isScan,1);
    fprintf('Cutting/sorting images...');
    progress = 0;
    shotsUncut = shots;
    for i = 1:Ncuts
        if isCutCam(i) % by camera function
            imgCutVals = zeros(nshots,1);
            imgFunction = cutoffs{i}{2};
            for j = 1:nshots
                % show progress (because people are impatient)
                current = floor((nshots*(sum(isCutCam(1:i))-1) + j)/(nshots*sum(isCutCam))*100);
                if current >= progress + 10
                    progress = floor(current/10)*10;
                    fprintf([num2str(progress) '%% ']);
                end
                
                shot = shotsUncut(j);
                image = imread([preheader structs{Ncam+i}.dat{indices{Ncam+i}(shot)}]);
                imgCutVals(j) = imgFunction( image );
            end
            cutValues(i) = { imgCutVals' };
        else    % by scalar
            cutValues(i) = { structs{Ncam+i}.dat(indices{Ncam+i}(shotsUncut)) };
        end
        % allow no cuts for first cutoff (sorting)
        if i > 1 || numel(cutoffs{i}) > 1 + isCutCam(i)
            cutRange = cutoffs{i}{2+isCutCam(i)};
            shots = intersect(shots, shotsUncut(and(min(cutRange) <= cutValues{i}, cutValues{i} <= max(cutRange))));
        end
    end

    % refine cutValues
    [~, keep] = intersect(shotsUncut, shots);
    for i = 1:Ncuts
        cutValues{i} = cutValues{i}(keep);
    end
    disp('...done.');
    nshots = numel(shots);
    
    % do scan sorting
    if isScan
        stepValues = structs{N}.dat(indices{N}(shots));
        uniqueStepValues = unique(stepValues);
        sortedValues = zeros(numel(shots), 1);
        ticks = zeros(numel(uniqueStepValues),1);
        cutValues(Ncuts+isScan) = { stepValues };
        count = 0;
        sortedShots = shots;
        for i = 1:numel(uniqueStepValues)
            valueShots = shots(stepValues == uniqueStepValues(i));
            [sortValues, sortIndices] = sort(cutValues{1}(stepValues == uniqueStepValues(i)));
            sortedValues((count+1):(count + numel(valueShots))) = sortValues;
            sortedShots((count+1):(count + numel(valueShots))) = valueShots(sortIndices);
            count = count + numel(valueShots);
            ticks(i) = count;
        end
        shots = sortedShots;
        xticks = [0 ticks'];
        xticks = (xticks(1:(end-1)) + xticks(2:end))/2  + 0.5;
    elseif Ncuts > 0
        [sortedValues, sortIndices] = sort(cutValues{1});
        shots = shots(sortIndices);
    end

    % find backgrounds if saved
    background = backgroundSubtraction(data.raw.metadata.param.save_back, structs, preheader, cameras);
    
    % clear figure to avoid subplot shrinking
    clf;
    
    % cycle through cameras
    fprintf(['Analyzing ' num2str(Ncam*nshots) ' images... ']);
    progress = 0;
    nPlots = Ncam + 1;
    nHor = floor(sqrt(nPlots));
    nVert = ceil(nPlots/floor(sqrt(nPlots)));
    for i = 1:Ncam
        
        % temporary function values
        f = imageFunctions{i};
        testImage = imread([preheader structs{i}.dat{indices{i}(1)}]);
        
        % rotate if CMOS_FAR
        if strcmp(cameras{i},'CMOS_FAR')
            testImage = rot90(testImage,3);
        end
        
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
            image = getProcessedImage(preheader, structs{i}, indices{i}, shot, background{i}, cameras{i});
            
	        % do 2D to 1D projection
            lines(:,j) = f(image)';
            
        end
        
        % perform averaging in step
        if isScan && doAvg
            stepFirstShots= [0 ticks'] + 1;
            for j = 1:(numel(stepFirstShots)-1)
                meanshots = stepFirstShots(j):(stepFirstShots(j+1)-1);
                meanlines = mean(lines(:,meanshots),2);
                for k = meanshots
                    lines(:,k) = meanlines;
                end
            end 
        end
        
        % plot waterfalls
        subplot(nVert, nHor, i);
        imagesc(1:nshots, 1:lineSize, lines);
        if isScan
            set(gca, 'XTick', xticks);
            set(gca, 'XTickLabel', num2str(uniqueStepValues','%.2f'));
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
        ylabel('Projection / px');
        title(labels{i}, 'Interpreter', 'None');
        colorbar;
        caxis([0 bitDepths{i}]);

        % apply energy axis if appropriate (ELAN, WLAN)
        isWLAN = strcmp(cameras{i},'CMOS_WLAN') || strcmp(cameras{i},'WLanex');
        isELAN = strcmp(cameras{i},'CMOS_ELAN');
        isCFAR = strcmp(cameras{i},'CMOS_FAR');
        if isELAN || isWLAN || isCFAR
            fstr = strtrim(func2str(f));
            fparts = regexp(fstr,'[(,)]','split');
            isProjection = strcmp(fparts(1),'@') && strcmp(fparts(2), fparts(4)) && strcmp(fparts(3),'sum');
            isYproj = strcmp(fparts(end-1),'2');
            if isProjection && isYproj
                % check if function defines ROI
                yROI = ':';
                if numel(fparts) == 9
                    yROI = fparts{5};
                end
                
                % convert to list
                yMax = size(testImage,1);
                yROIactual = 1:yMax;
                if strcmp(yROI,':')
                    yROI = yROIactual;
                else
                    yROI = eval(yROI);
                end
                
                % camera specific properties
                resolution = structs{i}.RESOLUTION(1)*1e-6;
                yStart = structs{i}.ROI_Y(1);
                if isWLAN
                    yNominal = 755;
                    zScreen = 2015.6;
                elseif isELAN
                    mtrPosY = data.raw.metadata.E200_state.XPS_LI20_MC01_M5_RBV.dat; % Elanex y-motor
                    yNominal = 210 - (mtrPosY-53.51)*1e-3/resolution;
                    zScreen = 2015.22;
                elseif isCFAR
                    yNominal = 973;
                    zScreen = 2016.04;
                end

                z_B5D36 = 2005.65085; % middle of magnet
                L = zScreen - z_B5D36;
                p0 = 20.35;
                pBend = data.raw.metadata.E200_state.LI20_LGPS_3330_BDES.dat;
                theta0 = 5.73e-3;
                D0 = theta0 * L;
                DBend = D0 * (pBend/p0);
                yBendShift = (D0 - DBend)/resolution;
                
                y0 = yNominal - yStart - yBendShift;
                %yInf = y0 - DBend/resolution;
                eAxis = p0 ./ (1-(y0-yROI)*resolution/DBend);
                
                numETicks = 10;
                eticks = 1:floor(lineSize/numETicks):lineSize;
                etickVals = num2str(eAxis(eticks)','%.1f');
                etickVals(eAxis(eticks)<0,:) = ' ';
                
                % only use if not other bend on Elanex (screws up)
                if ~(isELAN && abs(pBend-p0) > 0.1 )
                    set(gca, 'YTick', eticks);
                    set(gca, 'YTickLabel', etickVals);
                    ylabel('Projection / GeV');
                end
            end
        end    
        
    end

    % plot sorting plot
    subplot(nVert, nHor, nPlots:(nVert*nHor));
    xlab = 'Shot # (used shots)';
    if isScan
        if Ncuts > 0
            stairs([sortedValues; sortedValues(end)]);
            xlim([1 numel(sortedValues)+1]);
            xlab = ['Step value' step_str];
            ylabel(labels{Ncam+1},'Interpreter','None');
            set(gca, 'XTick', xticks + 0.5);
            set(gca, 'XTickLabel', num2str(uniqueStepValues','%.2f'));
            for x = ticks + 1
                line([x x], ylim, 'Color', [0 0 0]);
            end
        else
            stairs([stepValues stepValues(end)]);
            xlim([1 numel(stepValues)+1]);
            ylabel('Step value');
        end
    else
        if Ncuts > 0
            stairs([sortedValues sortedValues(end)]);
            xlim([1 numel(sortedValues)+1]);
            ylabel(labels{Ncam+1},'Interpreter','None');
        else
            stairs([shots shots(end)]);
            xlim([1 nshots+1]);
            ylabel('Shot # (all shots)');
        end
    end
    title(['\bfDataset ' dataset ' \rm(' num2str(nshots) '/' num2str(nUIDs) ' shots)']);
    xlabel(xlab, 'Interpreter', 'None');
    
    % invisible color bar for alignment
    clbr = colorbar;
    set(clbr,'visible','off');
    
    disp('...done.');
end
