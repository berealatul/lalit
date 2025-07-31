clc; clear all; close all;

% Simulation Parameters
numUEs = 4;        % Total number of UEs served by the base station
numFrames = 4;     % Total number of frames to simulate
SNRdBDL = 23;      % Downlink SNR in dB
SNRdBUL = 18;      % Uplink SNR in dB

% Carrier and TDD Pattern
carrier = nrCarrierConfig;
carrier.NSizeGrid = 64;
carrier.SubcarrierSpacing = 30;
numPRB = carrier.NSizeGrid; % 64 PRBs

tddPattern = ["D","D","D","D","D","D","D","S","U","U"]; 

disp("Cyclic slot pattern:");
disp("Slot " + string((0:length(tddPattern)-1)') + ": " + tddPattern(:));

specialSlot = [6 4 4];
if(sum(specialSlot)~=carrier.SymbolsPerSlot)
    error(['specialSlot must contain ' num2str(carrier.SymbolsPerSlot) ' symbols.']);
end

bsAntSize = [4 8 2 1 1]; % [Rows, Cols, Pol, VPanel, HPanel]
numGroups = 6;
g = (1:numGroups).*ones(ceil(numUEs/numGroups),1);
groups = g(1:numUEs);

rng('default'); % For reproducibility

% Number of layers for each UE
numLayers = pow2(randi([0 2],[1 numUEs]));

% Number of rows, columns, polarizations, vpanels, hpanels for each UE
ueAntSizes = repmat([4 1 1 1 1], numUEs, 1);

% SRS and PDSCH Configuration
SRSs = hMultiUserSRS(tddPattern, specialSlot, carrier, numLayers);
PDSCHs = hMultiUserPDSCH(numLayers, numPRB); % <-- Now with per-user PRB allocation

algParameters = struct;
algParameters.PrecodingMethod = 'RZF';
algParameters.ScheduledLayers = 8;
algParameters.PerfectChannelEstimator = false;

delayProfile = 'CDL-A';
delaySpread = 0;
maximumDopplerShift = 0;
channels = hMultiUserChannels(delayProfile, delaySpread, maximumDopplerShift, bsAntSize, ueAntSizes, groups);
[numRF, channels, algParameters] = setupJSDM(algParameters, groups, numUEs, channels, bsAntSize);

% Set up record of data transfer and CSI
dataState = setupDataTransfer(carrier, numFrames, numLayers);
csi = setupCSI(carrier, bsAntSize, ueAntSizes);

diagnosticsOn = true;

% --- SRS Antenna Switching Logic ---
srsCounter = 0; % Track SRS slot index
srsAntennaLog = nan(carrier.SlotsPerFrame*numFrames,1); % For logging

% For each slot
for nSlot = 0:(carrier.SlotsPerFrame*numFrames)-1

    % Update the slot number
    carrier.NSlot = nSlot;

    % Determine slot type
    slotType = tddPattern(mod(carrier.NSlot, numel(tddPattern)) + 1);

    % Display slot number and type (if diagnostics are enabled)
    if (diagnosticsOn)
        disp("Slot " + string(carrier.NSlot) + ": " + slotType);
    end

    % Schedule UEs for data transmission
    [schedule, PDSCHs, B] = hMultiUserSelection(csi, tddPattern, specialSlot, carrier, PDSCHs, bsAntSize, algParameters);

    % PDSCH transmissions for all UEs scheduled for data
    [txDL, txSymbols, singleLayerTBS] = hMultiDLTransmit(carrier, PDSCHs(schedule.PDSCH), numRF, B);

    % SRS transmissions for all UEs scheduled for SRS, with antenna switching
    if slotType == "S" || slotType == "U"
        srsCounter = srsCounter + 1;
        [txUL, schedule.SRS, activeAntennaIdx] = hMultiULTransmit(carrier, SRSs, srsCounter);
        srsAntennaLog(nSlot+1) = activeAntennaIdx; % Log antenna index
        fprintf('Slot %d: SRS Antenna Index Used = %d\n', nSlot, activeAntennaIdx);
    else
        [txUL, schedule.SRS, activeAntennaIdx] = hMultiULTransmit(carrier, SRSs, []);
        srsAntennaLog(nSlot+1) = NaN;
    end

    % --- Ensure activeAntennaIdx is a vector for scheduled SRS UEs ---
    if isempty(schedule.SRS)
        activeAntennaIdxUsed = [];
    elseif isscalar(activeAntennaIdx)
        activeAntennaIdxUsed = repmat(activeAntennaIdx, 1, numel(schedule.SRS));
    elseif numel(activeAntennaIdx) ~= numel(schedule.SRS)
        error('activeAntennaIdx must be a scalar or match the number of scheduled SRS UEs.');
    else
        activeAntennaIdxUsed = activeAntennaIdx;
    end

    % Apply fading channels
    [channels, rxDL, rxUL] = hApplyMultiUserChannels(tddPattern, specialSlot, carrier, schedule, channels, txDL, txUL);

    % Apply AWGN
    rxDL = hApplyMultiUserAWGN(carrier, rxDL, SNRdBDL, CombineWaveforms=false);
    rxUL = hApplyMultiUserAWGN(carrier, rxUL, SNRdBUL, CombineWaveforms=true);

    % For all UEs scheduled for SRS, estimate the channel and record it
    if ~isempty(schedule.SRS)
        H = hMultiULReceive(carrier, SRSs(schedule.SRS), rxUL, algParameters, activeAntennaIdxUsed);
        csi = updateChannelEstimates(csi, carrier, schedule.SRS, H, activeAntennaIdxUsed);
    end

    % For all UEs scheduled for data, perform PDSCH reception and record the results
    [TBS, CRC, eqSymbols, nVar] = hMultiDLReceive(carrier, PDSCHs(schedule.PDSCH), rxDL, algParameters);
    dataState = updateDataTransfer(dataState, carrier, singleLayerTBS, schedule.PDSCH, TBS, CRC);

    % For all UEs scheduled for data, update noise estimates
    csi = updateNoiseEstimates(csi, carrier, schedule.PDSCH, nVar);

    % Display scheduled SRSs and PDSCHs, PDSCH EVM, and DL-SCH CRC (if diagnostics are enabled)
    if (diagnosticsOn)
        displayDiagnostics(schedule, PDSCHs, txSymbols, eqSymbols, CRC, groups);
    end

end

results = summarizeResults(dataState);
disp(results);

totalThroughput = sum(results.("Throughput (bits)"));
dataRate = totalThroughput / (numFrames * 0.01) / 1e6;
disp(['Total throughput across all users: ' num2str(dataRate,'%0.3f') ' Mbps']);

disp(['Average BLER across all users: ' num2str(mean(results.BLER,'omitnan'),'%0.3f')]);

singleLayerThroughput = sum(dataState(1).SingleLayerTBS,'omitnan');
capacity = totalThroughput / singleLayerThroughput;
disp(['Capacity relative to a single-layer user: ' num2str(capacity,'%0.2f') 'x']);

% --- Optional: Display SRS Antenna Switching Log ---
disp('SRS Antenna Index Log (NaN means no SRS in that slot):');
disp(srsAntennaLog);
