function [numRF,channels,algParameters] = setupJSDM(algParameters,groups,numUEs,channels,bsAntSize)
% Modify parameters if JSDM is chosen as the precoding method

    if any(strcmp(algParameters.PrecodingMethod,{'JSDM-JGP','JSDM-PGP'}))
        algParameters.groups = groups;
        numGroups = max(groups);
        if numGroups < 2
            error('Specify more than one group for JSDM');
        end

        % The channel helper file allows for frequency-domain channel
        % estimation, but is not compatible for JSDM due to the effective
        % channel estimation. Set perfect channel estimation to false.
        algParameters.PerfectChannelEstimator = false;
        
        % Enable channel filtering for JSDM
        for u = 1:numUEs
            channels(u).channel.ChannelFiltering = true;
        end

        % One RF chain per layer
        numRF = algParameters.ScheduledLayers;
    else
        % One RF chain per antenna
        numRF = bsAntSize;
    end

end