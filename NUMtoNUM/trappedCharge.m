function [ trapped ] = trappedCharge( usFarToroid, dsToroid )

    % ONLY FOR _FAR_ UPSTREAM TOROID

    if mean(dsToroid) > 1.5e10 % full charge
        slope = 1.166283439855080;
        intercept = -1.786733834067767e+09;
    else % half charge
        slope = 1.085090794003136;
        intercept = -3.428684309637228e+08;
    end
    
    % TODO: include what to do for jaw scans
    % slope = 1.091919676651400;
    % intercept = -4.190266422666143e+08;
    
    trapped = dsToroid - (slope*usFarToroid + intercept);

end

