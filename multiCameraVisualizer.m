function [ ] = multiCameraVisualizer( dataset, cameras, bitDepthAndROI, shots, specifiedUIDs)

    % white plot background
    set(gcf, 'Color', 'w');
    
    % colormaps: "white -> blue -> green -> yellow -> red"
    D = [1 1 1; 0 0 1; 0 1 0; 1 1 0; 1 0 0;];
    F = [0 0.25 0.5 0.75 1];
    G = linspace(0, 1, 256);
    cmap.wbgyr = interp1(F,D,G);
    colormap(cmap.wbgyr);
                                    
    % import data structure
    [data, preheader, dataset] = FACETautoImport(dataset);
    
    % intersect UIDs
    if ~exist('specifiedUIDs', 'var') 
        specifiedUIDs = []; end;
    [ structs, UIDs, indices, Ncams ] = intersectUIDs(data, specifiedUIDs, cameras);

    % find backgrounds if saved
    background = backgroundSubtraction(data.raw.metadata.param.save_back, structs, preheader, cameras);

    % set bit depths and ROIs
    xROIs = cell(Ncams, 1);
    yROIs = cell(Ncams, 1);
    bitDepths = cell(Ncams, 1);
    for i =1:Ncams
        bitDepths(i) = { 0 };
        xROIs(i) = { 1:structs{i}.ROI_XNP };
        yROIs(i) = { 1:structs{i}.ROI_YNP };
        if exist('bitDepthAndROI','var') && i <= numel(bitDepthAndROI)
            bdroi = bitDepthAndROI{i};
            if strcmpi(class(bdroi),'double')
                bitDepths(i) = { bdroi };
            elseif iscell(bdroi) && numel(bdroi)
                bitDepths(i) = bdroi(1);
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
        
        % clear figure to avoid subplot shrinking
        clf;

        % cycle through cameras
        for i = 1:Ncams
            
            % unique identifier
            UID = structs{i}.UID(indices{i}(shot));
            
	        % read image
            image = getProcessedImage(preheader, structs{i}, indices{i}, shot, background{i}, cameras{i});
            
            % plot image (tries to make square layout)
            subplot(ceil(Ncams/floor(sqrt(Ncams))),floor(sqrt(Ncams)),i);
            imagesc(xROIs{i}, yROIs{i}, image(yROIs{i}, xROIs{i}));
            colorbar;
            caxis([0 bitDepths{i}]);
            title([ cameras{i} ' (' num2str(shot) '/' num2str(nShots) ', ' num2str(UID) ', dataset ' dataset ')'],'Interpreter','none');
            
            % apply energy axis if appropriate (ELAN, WLAN)
            isWLAN = strcmp(cameras{i},'CMOS_WLAN');
            isWLanex = strcmp(cameras{i},'WLanex');
            isELAN = strcmp(cameras{i},'CMOS_ELAN') && ( isfield(data.raw.metadata.E200_state, 'XPS_LI20_MC01_M5_RBV') || ( false && isfield(data.raw.metadata.E200_state, 'XPS_LI20_DWFA_M5') ) );
            isCFAR = strcmp(cameras{i},'CMOS_FAR');
            if isELAN || isWLAN || isCFAR || isWLanex
                
                % ROI
                yROI = yROIs{i};

                % camera specific properties
                resolution = structs{i}.RESOLUTION(1)*1e-6;
                yStart = structs{i}.ROI_Y(1);
                if isWLAN
                    yNominal = 755;
                    zScreen = 2015.6;
                elseif isWLanex
                    yNominal = 582;
                    zScreen = 2015.6;
                elseif isELAN
                    if isfield(data.raw.metadata.E200_state, 'XPS_LI20_MC01_M5_RBV')
                        mtrPosY = data.raw.metadata.E200_state.XPS_LI20_MC01_M5_RBV.dat; % Elanex y-motor
                    else % turns out energy axis 
                        mtrPosY = data.raw.metadata.E200_state.XPS_LI20_DWFA_M5.dat; % Elanex y-motor
                    end% if
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
                eAxis = p0 ./ (1-(y0-yROI)*resolution/DBend);

                numETicks = 10;
                lineSize = numel(yROI);
                eindices = 1:floor(lineSize/numETicks):lineSize;
                eticks = (min(yROI)-1) + eindices;
                etickVals = num2str(eAxis(eindices)','%.1f');
                etickVals(eAxis(eindices)<0,:) = ' ';

                % only use if not other bend on Elanex (screws up)
                if ~(isELAN && abs(pBend-p0) > 0.1 )
                    set(gca, 'YTick', eticks);
                    set(gca, 'YTickLabel', etickVals);
                    ylabel('Projection / GeV');
                end
                
            end
            
            % show custom function
            if strcmp(cameras{i},'E224_Vert')
                %[amplitude, width, brightness] = oscAmp(processedImage, 250:650,200:1100)
            end
        end
        
        % pause, show progress and mark shots
        if strcmpi(input(['Image ' num2str(shot) '/' num2str(nShots) ' (' num2str(UID) ') '],'s'),'s')
            format long;
            markedUIDs = [markedUIDs; UID]
        end
            
    end
end
