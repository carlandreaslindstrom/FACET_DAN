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
    
    % import image to number functions
    addpath('2DtoNUM');
    
    % white plot background
    set(gcf, 'Color', 'w');

    % import data structure
    [data, preheader, dataset] = FACETautoImport(dataset);

    % default no scalars
    if ~exist('scalars','var')
	    scalars = cell(0); 
    end;

    % parse scalar names and cutoffs
    cutoffs = cell(numel(scalars), 1);
    for i = 1:numel(scalars)
        if iscell(scalars{i})
            name = scalars{i}{1};
            cutoffs(i) = scalars{i}(2);
            scalars(i) = { name };
        end
    end
    
    % intersect UIDs
    if ~exist('specifiedUIDs', 'var') 
        specifiedUIDs = []; end;
    [structs, UIDs, indices, Ncams, labels, N, Nscal] = intersectUIDs(data, specifiedUIDs, cameras, imageFunctions, scalars);
    
    % default no combineFunctions
    if exist('combineFunctions','var')
        Ncfun = numel(combineFunctions);
    else
        Ncfun = 0;
    end;
    Nall = N + Ncfun;
  
    % if 1 shot entered, start with this. if none, show all.
    nUIDs = numel(UIDs);
    if exist('shots', 'var') && numel(shots)>0
        if numel(shots) == 1
            shots = shots:nUIDs; 
        end;
        shots = shots(and(shots > 0, shots <= nUIDs));
    else
        shots = 1:nUIDs;
    end;
    
    % do shot cutoff filtering
    for i = 1:Nscal
        if numel(cutoffs{i})
            values = structs{Ncams+i}.dat(indices{Ncams+i}(shots));
            shots = shots(and(values < max(cutoffs{i}), values > min(cutoffs{i})));
        end
    end
    nshots = numel(shots);

    % find backgrounds if saved
    background = backgroundSubtraction(data.raw.metadata.param.save_back, structs, preheader, cameras);

    % clear figure to avoid subplot shrinking
    clf;
    
    % cycle through all cameras
    fprintf(['Analyzing ' num2str(Ncams*nshots) ' images... ']);
    funcValues = cell(Nall, 1);
    zeroMask = cell(Nall, 1);
    progress = 0;
    for i = 1:Ncams
        
        % temporary function values
        values = zeros(nshots,1);
        
        % cycle through shots
        for j = 1:nshots
            shot = shots(j);
            
            % show progress (because people are impatient)
            current = floor((nshots*(i-1) + j)/(nshots*Ncams)*100);
            if current >= progress + 10
               progress = floor(current/10)*10;
               fprintf([num2str(progress) '%% ']);
            end
            
            % aqcuire image
            image = getProcessedImage(preheader, structs{i}, indices{i}, shot, background{i}, cameras{i});
            
            % apply function and save
            f = imageFunctions{i};
            values(j) = f(image);
        end
        
        % save function values
        funcValues(i) = { values };
        zeroMask(i) = { abs(funcValues{i}) > 1e-9 };
        
    end
    disp('... Done. ');

    % cycle through all scalars
    for i = (Ncams+1):N
    	funcValues(i) = { structs{i}.dat(indices{i}(shots))' };
        zeroMask(i) = { or( strcmpi(scalars{i-Ncams},'step_value'),  abs(funcValues{i}) > 1e-9 ) };
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
        if strcmpi(func2str(func),'minus') && strcmp(labels(arg1), 'DS TOROID') && strcmp(labels(arg2), 'US TOROID')
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
            if j>N && ( i == combineFunctions{j-N}{2} || i == combineFunctions{j-N}{3} )
                continue;
            end
            
            % subplot array
            subplot(floor(sqrt(nPlots)), ceil(nPlots/floor(sqrt(nPlots))), count);
            
	        % masking out zeros
	        mask = and(zeroMask{i}, zeroMask{j});
            if (numel(mask) > sum(mask))
		        fprintf(['ignoring zeros (plot ' num2str(count) ')... ']);
            end
	    
	        % correlation matrix
            M = corrcoef(funcValues{i}(mask), funcValues{j}(mask));
            if abs( M(1,2) ) <= 1
		        R = M(1,2);
            else
                R = 0;
            end
            
            % point colors based on correlation
            c = winter(100);
            corrcolor = c(ceil(abs(R*99)+1),:);
            
	        % plot and choose color based on R^2
            scatter(funcValues{j}(mask), funcValues{i}(mask), 30, corrcolor, 'filled');

            % add dataset title once
            if count == 1
                set(gca,'FontSize', 13);
                title(['\bf Dataset ' dataset]);
            end
            
            % add labels
            set(gca,'FontSize', 12);
            xlabel(labels{j}, 'Interpreter', 'None');
            ylabel(labels{i}, 'Interpreter', 'None');
            
            % increment to next plot
            count = count + 1;
            
        end
    end
    
    disp('Done.');
    
end

