function [ data, preheader, dataset, filename ] = FACETautoImport( dataset, quiet )
    
    fprintf('Importing data... ');
    
    % convert to string if number
    if strcmpi(class(dataset),'double') || strcmpi(class(dataset),'int')
        dataset = num2str(dataset);
    end
    
    % change if on different system
    preheader = '/Volumes/PWFA_5big';
    header = [preheader '/nas/nas-li20-pm00/'];
    
    % check buffer before searching
    bufferpath = 'buffer/BUFFER.dat';
    fid = fopen(bufferpath, 'rt');
    buffer = textscan(fid, '%s %s');
    fclose(fid);
    bfindex = find(ismember(buffer{1}, dataset));
    if ~numel(bfindex)
        
        % find dataset folder by system search
        output = '';
        [~, output] = system(['find ' header 'E* -mindepth 3 -maxdepth 3 -type d -name "E???_' dataset '"']);
        output = strtrim(output);
        
        if numel(preheader)
            output = strrep(output,preheader,'');
        end
        
        % save in buffer
        if ~strcmpi(output,'') && ~numel(strfind(output,'find'))
            fid = fopen(bufferpath, 'a');
            fprintf(fid, [dataset ' ' output '\n']);        
            fclose(fid);
        end    
    else
        output = buffer{2}{bfindex(1)};
    end

    % should something be displayed?
    displayIt = ~exist('quiet','var') || ( exist('quiet','var') && ~quiet );

    % load data if dataset exists
    if numel(output) > 0
        [path, folder] = fileparts(output);
        filename = [preheader path '/' folder '/' folder '.mat'];
        load(filename);
        
        % display dataset information
        if displayIt && ~strcmp(filename, '')
            disp([data.raw.metadata.param.save_name(1:5) dataset ', ' data.raw.metadata.param.save_name(12:21) ', comment : "' data.raw.metadata.param.comt_str '"']);
            disp(['Logged pressure [torr] : ' num2str(data.raw.metadata.E200_state.VGCM_LI20_M3202_PMONRAW.dat) ', Logged mean laser power [mJ] : ' num2str(mean(data.raw.scalars.PMTR_LA20_10_PWR.dat))   ]);
            US_toroid = mean(data.raw.scalars.GADC0_LI20_EX01_CALC_CH3_.dat);
            DS_toroid = mean(data.raw.scalars.GADC0_LI20_EX01_CALC_CH2_.dat);
            disp(['Logged mean US charge : ' num2str(US_toroid, '%0.2e') ', DS charge : ' num2str(DS_toroid, '%0.2e') ', DS-US : ' num2str(DS_toroid - US_toroid, '%0.2e') ]);
            if  isfield(data.raw.metadata.param ,'fcnHandle')
                disp(['Scan of "' func2str(data.raw.metadata.param.fcnHandle) '", from ' num2str(data.raw.metadata.param.Control_PV_start) ', to ' num2str(data.raw.metadata.param.Control_PV_end) '.']);
            else
                disp(['Not a scan']);
            end    
            disp(['Beam rate: ' num2str(data.raw.metadata.E200_state.EVNT_SYS1_1_BEAMRATE.dat) ' Hz']);
            fprintf('Cameras saved : ');
            for name = data.raw.metadata.param.names'
                fprintf([name{1} ', '], 'Interpreter', 'None');
            end
            disp(' ');
        end
    % no dataset found    
    else
        data = 0;
        filename = '';
        preheader = '';
        % display confirmation of massive failure
        if displayIt
            disp('No dataset found.');
        end
    end
end




