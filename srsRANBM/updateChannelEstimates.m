function csi = updateChannelEstimates(csi,carrier,SRS,H)
% Update record of channel estimates obtained via SRS, with condition number check.

    for ue_idx = 1:numel(SRS)
        ue = SRS(ue_idx);
        
        H_ue_new = H{ue_idx};
        
        % Get the indices of the valid channel estimates
        idx_new = find(all(~isnan(H_ue_new),[3 4]));

        if isempty(idx_new)
            continue; % No new channel estimate, so skip
        end

        % Extract the relevant part of the new channel estimate
        H_new_active = H_ue_new(idx_new,:,:,:);

        % Get the old channel estimate for the same indices
        H_old_active = csi(ue).H(idx_new,:,:,:);

        % Handle the initial case where the old CSI is all NaNs
        if all(isnan(H_old_active(:)))
            cond_old = Inf;
        else
            % Calculate condition number for the old channel estimate
            % We take the condition number of each sub-matrix and average them.
            cond_old_vals = arrayfun(@(i) cond(squeeze(H_old_active(i,:,:,:))), 1:size(H_old_active,1));
            cond_old = mean(cond_old_vals);
        end

        % Calculate condition number for the new channel estimate
        cond_new_vals = arrayfun(@(i) cond(squeeze(H_new_active(i,:,:,:))), 1:size(H_new_active,1));
        cond_new = mean(cond_new_vals);

        % Update CSI if new channel is better (lower condition number)
        if cond_new < cond_old
            csi(ue).H(idx_new,:,:,:) = H_new_active;
            csi(ue).NSlot(idx_new) = carrier.NSlot;
            disp(['UE ' num2str(ue) ': CSI updated (new cond=' num2str(cond_new) ' < old cond=' num2str(cond_old) ')']);
        else
            disp(['UE ' num2str(ue) ': CSI not updated (new cond=' num2str(cond_new) ' >= old cond=' num2str(cond_old) ')']);
        end
    end

end