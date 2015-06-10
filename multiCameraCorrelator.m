function [ ] = multiCameraCorrelator( dataset, cameras, imageFunctions, scalars, combineFunctions, shots, specifiedUIDs )

    % Argument guide:
    % "dataset" is the 5-digit dataset number as a string (e.g. '16875')
    % "cameras" is a cell of strings of camera names (e.g. {'E224_Trans','E224_Vert'} )
    % "imageFunctions" is a cell of image-to-scalar functions (e.g. {@(x) sum(sum(x)), @wiggleAmplitude} )
    % "scalars" is a cell of scalar names (e.g. {'BPMS_LI20_3265_Y','step_value'} )
    % "combineFunctions" is a cell of cells with function to apply, and 2 input numbers to use as
    %                        arguments in that function (e.g. {{@minus, 2, 3}, {@plus, 1,5}} )
    % "shots" is a list of shot numbers (e.g. 1:3:100 or 40:50)
    % "specifiedUIDs" is a list of UIDs to show
    
    addpath('2DtoNUM');
    
    % white plot background
    set(gcf, 'Color', 'w');
    
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

    % default no scalars
    if ~exist('scalars','var')
	    scalars = cell(0);
    end

    % default no combineFunctions
    Ncfun = 0;
    if exist('combineFunctions','var')
        Ncfun = numel(combineFunctions);
    end

    % intersect UIDs
    Ncam = numel(cameras);
    Nscal = numel(scalars);
    N = Ncam + Nscal;
    Nall = N + Ncfun;
    structs = cell(N,1);
    indices = cell(N,1);
    labels = cell(N,1);
    UIDs = [];
    for i = 1:N
        if i <= Ncam
	        struct = data.raw.images.(cameras{i});
            fstr = strtrim(func2str(imageFunctions{i}));
            fstr = strrep(fstr, 'sum(sum','Pixel count');
            fstr = strtrim(strrep(fstr,'@(x)',''));
            fstr = strtok(fstr,'(');
            label = [fstr ' @ ' cameras{i}];
        else 
            scalar = scalars{i-Ncam};
            scalar = strrep(scalar, ustoroid{2},   ustoroid{1});
            scalar = strrep(scalar, dstoroid{2},   dstoroid{1});
            scalar = strrep(scalar, pyro{2},       pyro{1});
            scalar = strrep(scalar, laserpower{2}, laserpower{1});
            struct = data.raw.scalars.(scalar);
            
            label = scalars{i-Ncam};
            label = strrep(label, ustoroid{1}, ustoroid{2});
            label = strrep(label, dstoroid{1}, dstoroid{2});
            label = strrep(label, pyro{1}, pyro{2});
            label = strrep(label, laserpower{1}, laserpower{2});
            label = strrep(label,'LI20_','');
        end
	    structs(i) = {struct};
        labels(i) = { label };
        
	    if i==1
            UIDs = struct.UID;
        else
            UIDs = intersect(UIDs, struct.UID);
        end
    end
    
    % intersect with user specified UIDs
    if exist('specifiedUIDs', 'var') && numel(specifiedUIDs) > 0
        UIDs = intersect(UIDs, specifiedUIDs);
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
    nshots = numel(shots);

    % find backgrounds if saved
    background = cell(Ncam,1);
    subBg = zeros(Ncam,1);
    if data.raw.metadata.param.save_back
        for i = 1:Ncam
            bg = load([preheader structs{i}.background_dat{1}]);
            multiplier = 2;
            if strcmpi(cameras{i}, 'IP2A')
                bg.img = fliplr(bg.img);
                subBg(i) = true;
            elseif numel(strfind(cameras{i}, 'CMOS')) > 0
                subBg(i) = true;
	    end
            background(i) = { multiplier * bg.img };
        end
    end

    % cycle through all cameras
    funcValues = cell(Nall, 1);
    zeroMask = cell(Nall, 1);

    fprintf(['Analyzing ' num2str(Ncam*nshots) ' images... ']);
    progress = 0;
    for i = 1:Ncam
        
        % temporary function values
        values = zeros(nshots,1);
        
        % cycle through shots
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
            

            % read image
            image = imread([preheader structs{i}.dat{indices{i}(shot)}]);
            
            % subtract backgrounds
            if subBg(i)
                processedImage = image - background{i};
            else
                processedImage = image;
            end
            
            f = imageFunctions{i};
            values(j) = f(processedImage);
        end
        
        % save function values
        funcValues(i) = { values };
        zeroMask(i) = { abs(funcValues{i}) > 1e-9 };
        
    end
    disp('... Done. ');

    % cycle through all scalars
    for i = (Ncam+1):N
    	funcValues(i) = { structs{i}.dat(indices{i}(shots))' };
        zeroMask(i) = { or( strcmpi(scalars{i-Ncam},'step_value'),  abs(funcValues{i}) > 1e-9 ) };
    end

    % cycle through all combination functions
    for i = 1:Ncfun
        j = N + i;
        func = combineFunctions{i}{1};
        arg1 = combineFunctions{i}{2};
        arg2 = combineFunctions{i}{3};

        % calculate values and labels
        values = zeros(nshots,1);
   	    for k = 1:nshots
            values(k) = func(funcValues{ arg1 }(k), funcValues{ arg2 }(k) );                
        end
        labels(j) = { [ func2str(func) ' @ inputs ' num2str(arg1) ' and ' num2str(arg2) ] };
        
        % special case for dark current function
        if strcmpi(func2str(func),'minus') && strcmpi(labels(arg1), dstoroid{2}) && strcmpi(labels(arg2), ustoroid{2})
            labels(j) = { 'TRAPPED CHARGE' };
        end

        funcValues(j) = { values };
        zeroMask(j) = { abs(funcValues{j}) > 1e-9 };	
    end

    % plot all correlations
    nPlots = Nall*(Nall-1)/2 - 2*Ncfun;
    count = 1;
    fprintf('Plotting data... ');
    for i = 1:Nall

        for j = (i+1):Nall
            
            % drop if combination function correlates with constituent part
            if j>N
                if i == combineFunctions{j-N}{2} || i == combineFunctions{j-N}{3}
                    continue;
                end    
            end
            
            % subplot array
            subplot(floor(sqrt(nPlots)), ceil(nPlots/floor(sqrt(nPlots))), count);
            
	        % masking out zeros
	        mask = and(zeroMask{i}, zeroMask{j});
            if numel(mask) > sum(mask)
		        fprintf(['ignoring zeros (plot ' num2str(count) ')... ']);
	        end
	    
	        % correlation matrix
            M = corrcoef(funcValues{i}(mask), funcValues{j}(mask));
	        R = 0;
            if abs( M(1,2) ) <= 1
		        R = M(1,2);
            end
            
	        % plot and choose color based on R^2
            c = winter(100);
            scatter(funcValues{j}(mask), funcValues{i}(mask), 30, c(ceil(abs(R*99)+1),:), 'filled');

            % labels and title
            set(gca,'FontSize', 11);
            xlabel(labels{j}, 'Interpreter', 'None');
            ylabel(labels{i}, 'Interpreter', 'None');
            set(gca,'FontSize', 9);
            
            if count == 1
                title(['\bfDataset ' dataset]);
            end
            % title(['\bfR = ' num2str(R,'%1.2f')]);
            
            % increment to next plot
            count = count + 1;
            
        end
    end

    % add main title
    %axes('Position',[0 0 1 1],'Visible','off');
    %set(gca,'FontSize', 14);
    %text(0.03, 0.03, ['\bf Dataset ' dataset ', ' num2str(nshots) '/' num2str(nUIDs) ' shots.'])
      
    disp('Done.');
end
