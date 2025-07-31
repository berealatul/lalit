function csi = updateNoiseEstimates(csi,carrier,PDSCH,nVar)
% Update record of noise estimates obtained via downlink transmission
    
    for ue = PDSCH
        
        nVar_ue = nVar{ue==PDSCH};
        csi(ue).nVar(:) = nVar_ue;
        csi(ue).NSlot(:) = carrier.NSlot;
        
    end
    
end