function [ ] = multiCameraWaterfall( dataset, cameras, imageFunctions, bitDepths, shots, isScan, doAvg, cutoffs )

    % ROI input: {bitdepth,bitdepth}  e.g. {0, 1e4} 
    %            or {{bitdepth,yroi}, {bitdepth,yroi}}  e.g. {{0,1:100}, {1e4,10:150}}
    %            or {{bitdepth,yroi,xroi}, {bitdepth,yroi,xroi}}  e.g. {{0,1:100,300:400}, {1e4,10:150,200:500}}
    %            or {{bitdepth,yroi,xroi}, bitdepth}  e.g. {{0,1:100,300:400}, 1e4}

    
    % import 2D to 1D projection functions
    addpath('2Dto1D');
    addpath('2DtoNUM');

    % white plot background
    set(gcf, 'Color', 'w');
    
    % colormaps:  "white -> blue -> green -> yellow -> red"
    D = [1 1 1; 0 0 1; 0 1 0; 1 1 0; 1 0 0;];
    F = [0 0.25 0.5 0.75 1];
    G = linspace(0, 1, 256);
    cmap.wbgyr = interp1(F,D,G);
    colormap(cmap.wbgyr);

    % import data structure
    [data, preheader, dataset] = FACETautoImport(dataset);
    
    if ~exist('specifiedUIDs', 'var') 
        specifiedUIDs = []; end;
    [ structs, UIDs, indices, Ncams, labels, N, ~, Ncuts, isCutCam ] = intersectUIDs(data, specifiedUIDs, cameras, imageFunctions, {}, cutoffs, isScan);
    
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
    fprintf(['Cutting/sorting ' num2str(sum(isCutCam)*nshots) ' images...']);
    progress = 0;
    shotsUncut = shots;
    for i = 1:Ncuts
        if isCutCam(i) % cut by camera function
            imgCutVals = zeros(nshots,1);
            imgFunction = cutoffs{i}{2};
            
            % make background for cut images
            cutStructs = structs( (Ncams+1):(Ncams+Ncuts));
            cutCam = cutoffs{i}(1);
            background = backgroundSubtraction(data.raw.metadata.param.save_back, cutStructs, preheader, cutCam);
            cutbg = background{1};
            
            % cycle through shots
            for j = 1:nshots
                % show progress (because people are impatient)
                current = floor((nshots*(sum(isCutCam(1:i))-1) + j)/(nshots*sum(isCutCam))*100);
                if current >= progress + 10
                    progress = floor(current/10)*10;
                    fprintf([num2str(progress) '%% ']);
                end
                
                % read image and apply function
                shot = shotsUncut(j);
                image = getProcessedImage(preheader, structs{Ncams+i}, indices{Ncams+i}, shot, cutbg, cutCam);
                imgCutVals(j) = imgFunction( image );
            end
            
            % save values
            cutValues(i) = { imgCutVals' };
        else  % cut by scalar
            cutValues(i) = { structs{Ncams+i}.dat(indices{Ncams+i}(shotsUncut)) };
        end
        
        % do cuts: allow not cutting for first "cutoff" (sorting only)
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
    fprintf(['Analyzing ' num2str(Ncams*nshots) ' images... ']);
    progress = 0;
    nPlots = Ncams + 1;
    nHor = floor(sqrt(nPlots));
    nVert = ceil(nPlots/floor(sqrt(nPlots)));
    for i = 1:Ncams
        
        % temporary function values
        f = imageFunctions{i};
        testImage = getProcessedImage(preheader, structs{i}, indices{i}, shots(1), [], cameras{i});
        lineSize = numel(f(testImage));
        lines = zeros(lineSize, nshots);
        
        for j = 1:nshots
            shot = shots(j);
            
            % show progress (because people are impatient)
            current = floor((nshots*(i-1) + j)/(nshots*Ncams)*100);
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
            ylabel(labels{Ncams+1},'Interpreter','None');
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
            ylabel(labels{Ncams+1},'Interpreter','None');
        else
            stairs([shots shots(end)]);
            xlim([1 nshots+1]);
            ylabel('Shot # (all shots)');
        end
    end
    
    % title and x-label
    set(gca,'FontSize', 13);
    title(['\bf Dataset ' dataset ' \rm (' num2str(nshots) '/' num2str(nUIDs) ' shots)']);
    set(gca,'FontSize', 12);
    xlabel(xlab, 'Interpreter', 'None');
    
    % invisible color bar for alignment
    clbr = colorbar;
    set(clbr,'visible','off');
    
    disp('...done.');
end
