%hApplyFrequencyDomainChannel Apply frequency domain channel to resource grid 
% [RXGRID, H, OFFSET] = 
% hApplyFrequencyDomainChannel(CARRIER,PATHGAINS,PATHFILTERS,SAMPLETIMES,TXGRID,OFFSET) 
% applies a frequency domain channel to the resource grid TXGRID, returning 
% the received resource grid RXGRID, perfect channel estimate H and the  
% channel filter delay OFFSET. CARRIER is the carrier configuration.
% PATHGAINS is the path gains obtained from the channel. PATHFILTERS is the 
% path filters obtained from the channel. SAMPLETIMES is the sample times 
% obtained from the channel. OFFSET is an optional input of the channel 
% filter delay. If provided, it is used instead of calculating the perfect 
% timing estimate.

% Copyright 2023 The MathWorks, Inc.

function [rxGrid, H, offset] = hApplyFrequencyDomainChannel(carrier,pathGains,pathFilters,sampleTimes,txGrid,offset)

    if nargin == 5
        offset = nrPerfectTimingEstimate(pathGains,pathFilters);
    end
    
    H = nrPerfectChannelEstimate(carrier,pathGains,pathFilters,offset,sampleTimes);
    H = H(:,1:size(txGrid,2),:,:);
    rxGrid = applyChannelMatrices(txGrid,H);
    
end

function out = applyChannelMatrices(in,H)
     
    out = sum(H.*permute(in,[1 2 4 3]),4);

end