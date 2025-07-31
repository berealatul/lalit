function csi = updateChannelEstimates(csi,carrier,SRS,H)
% Update record of channel estimates obtained via SRS

    for ue = SRS

        H_ue = H{ue==SRS};
        idx = find(all(~isnan(H_ue),[3 4]));
        csi(ue).H(idx,:,:,:) = H_ue(idx,:,:,:);
        csi(ue).NSlot(idx) = carrier.NSlot;




    end

end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% function csi = updateChannelEstimates(csi,carrier,SRS,H,activeAntennaIdx)
% % Update record of channel estimates obtained via SRS
% 
%     for k = 1:numel(SRS)
%         ue = SRS(k);
%         H_ue = H{k};
%         antIdx = activeAntennaIdx(k);
% 
%         % Defensive: assign only the correct antenna slice
%         if ndims(H_ue) == 4
%             csi(ue).H(:,:,:,antIdx) = H_ue(:,:,:,antIdx);
%         elseif ndims(H_ue) == 3
%             csi(ue).H(:,:,:,antIdx) = H_ue;
%         else
%             error('Unexpected dimensions for H_ue');
%         end
% 
%         % Update slot info as before
%         idx = find(all(~isnan(H_ue(:,:,:,min(end,antIdx))),[3])); % 3rd dim is subcarrier
%         csi(ue).NSlot(idx) = carrier.NSlot;
%     end
% end
