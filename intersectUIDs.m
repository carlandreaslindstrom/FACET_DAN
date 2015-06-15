function [ structs, UIDs, indices, Ncams, labels, N, Nscal, Ncuts, isCutCam ] = intersectUIDs( data, specifiedUIDs, cameras, imageFunctions, scalars, cutoffs, isScan )

    % fail if wrong number of functions
    if exist('imageFunctions','var')
        assert(numel(cameras) == numel(imageFunctions)); 
    else
        imageFunctions = {};
    end
    
    % import the dictionary between real and easier scalar names
    dictionary = getDictionary();
    
    % toggle for activating CMOS_WLAN bugfix
    activateWLANbugfix = true;

    % number of cameras
    Ncams = numel(cameras);
    
    % number of scalars
    if exist('scalars','var')
        Nscal = numel(scalars);
    else
        Nscal = 0;
    end
    
    % figure out whether cutoffs are cameras or not
    if exist('cutoffs','var')
        Ncuts = numel(cutoffs);
        isCutCam = zeros(Ncuts,1);
        for i = 1:Ncuts
            isCutCam(i) = numel(cutoffs{i}) > 1 && strcmpi(class(cutoffs{i}{2}), 'function_handle');
        end
    else
        Ncuts = 0;
        isCutCam = [];
    end
    
    % default: it's not a scan
    if ~exist('isScan','var')
       isScan = false;
    end
    
    % total number of UID structs to intersect
    N = Ncams + Nscal + Ncuts + isScan;
    
    % declare cells to keep 
    structs = cell(N, 1);
    indices = cell(N, 1);
    labels  = cell(N, 1);
    
    % go through all structs
    for i = 1:N
        % cameras
        if i <= Ncams 
	        struct = data.raw.images.(cameras{i});
            if Nscal
                fstr = strtrim(func2str(imageFunctions{i}));
                fstr = strrep(fstr, 'sum(sum','Pixel count');
                fstr = strtrim(strrep(fstr,'@(x)',''));
                fstr = strtok(fstr,'(');
                label = [fstr ' @ ' cameras{i}];
            elseif numel(imageFunctions)
                label = [cameras{i} ' ' strtrim(func2str(imageFunctions{i}))];
            else
                label = '';
            end
            
            % fix for 2015 CMOS_WLAN bug
            if activateWLANbugfix && strcmp(cameras{i},'CMOS_WLAN')
                struct.UID = struct.UID - 1; % shifts
            end
            
        % scalars
        elseif ( i > Ncams ) && ( i <= Ncams + Nscal )
            scalar = scalars{i-Ncams};
            label = scalar;
            
            % translate to and from simpler words
            for lookup = dictionary
                scalar = strrep(scalar, lookup{1}{2}, lookup{1}{1});
                label = strrep(label, lookup{1}{1}, lookup{1}{2});
            end
            struct = data.raw.scalars.(scalar);
            
        % cutoffs
        elseif ( i > Ncams + Nscal ) && ( i <= Ncams + Nscal + Ncuts )
            j = i - Ncams + Nscal;
            
            % camera cutoffs
            if isCutCam(j)
                label = [cutoffs{j}{1} ' ' strtrim(func2str(cutoffs{j}{2}))];
                struct = data.raw.images.(cutoffs{j}{1});
                
            % scalar cutoffs
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
            
        % scan variable
        elseif isScan
            struct = data.raw.scalars.('step_value');
            label = 'Scan variable';
        end
        
        % save structures and labels
	    structs(i) = { struct };
        labels(i) = { label };
        
        % intersect UIDs (or save only if first UIDs)
        if i == 1
            UIDs = struct.UID;
        end
        UIDs = intersect(UIDs, struct.UID);
    end
    
    % intersect with user specified UIDs
    if numel(specifiedUIDs) > 0
        UIDs = intersect(UIDs, specifiedUIDs);
    end
    
    % get indices
    for i = 1:N
        [~, ind] = intersect(structs{i}.UID, UIDs);
        indices(i) = { ind };
    end

end

