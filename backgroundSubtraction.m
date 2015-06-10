function [ background ] = backgroundSubtraction( hasBackground, structs, preheader, cameras)

    N = numel(cameras);
    background = cell(N,1);
    if hasBackground 
        for i = 1:N
            % load background image
            bg = load([preheader structs{i}.background_dat{1}]);
            
            % flip images and decide whether to subtract
            subtract = false;
            if strcmpi(cameras{i}, 'IP2A') || strcmp(cameras{i},'CMOS_FAR')
                bg.img = fliplr(bg.img);
                subtract = true;
            elseif numel(strfind(cameras{i}, 'CMOS')) % subtract if CMOS
                subtract = true;
            end
            
            % do subtraction
            if subtract
                multiplier = 2;
                background(i) = { multiplier * bg.img };
            end
        end
    end

end

