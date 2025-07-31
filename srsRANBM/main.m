clc; clear all; close all;

numUEs = 4;         % Total number of UEs served by the base station
numFrames = 1;      % Total number of frames to simulate
SNRdBDL = 23;       % Downlink SNR in dB
SNRdBUL = 18;       % Uplink SNR in dB

carrier = nrCarrierConfig;
carrier.NSizeGrid = 64;
carrier.SubcarrierSpacing = 30;

tddPattern = ["D","D","D","D","D","D","D","S","U","U"]; 


disp("Cyclic slot pattern:")

disp("Slot " + string((0:length(tddPattern)-1)') + ": " + tddPattern(:))

specialSlot = [6 4 4]; % [D/l G U/l]

if(sum(specialSlot)~=carrier.SymbolsPerSlot)
    error(['specialSlot must contain ' num2str(carrier.SymbolsPerSlot) ' symbols.']);
end

% The antenna array size is a vector [M N P], 
% where M is the number of rows,
% N is the number of columns and
% P is the number of polarizations in the antenna array.
bsAntSize = [4 8 2];

numGroups = 6;

% Assign each UE a spatial group
g = (1:numGroups).*ones(ceil(numUEs/numGroups),1);
groups = g(1:numUEs);

% Reset random generator for reproducibility
rng('default');

% Number of layers for each UE
numLayers = pow2(randi([0 2],[1 numUEs]));%ones(1,numUEs);

% Number of rows, columns and polarizations in rectangular array for each UE
ueAntSizes = 1 + (numLayers.' > [4 2 1]);

SRSs = hMultiUserSRS(tddPattern,specialSlot,carrier,numLayers);

PDSCHs = hMultiUserPDSCH(numLayers);

alg = struct; % This is alg
alg.PrecodingMethod = 'ZF';

alg.ScheduledLayers = 8;

alg.PerfectChannelEstimator = false;

delayProfile = 'CDL-A';
delaySpread = 100e-9;
maximumDopplerShift = 50;
channels = hMultiUserChannels(delayProfile,delaySpread,maximumDopplerShift,bsAntSize,ueAntSizes,groups);
[numRF,channels,alg] = setupJSDM(alg,groups,numUEs,channels,bsAntSize);

% Set up record of data transfer and CSI
dataState = setupDataTransfer(carrier,numFrames,numLayers);
csi = setupCSI(carrier,bsAntSize,ueAntSizes);

diagnosticsOn = true;

% For each slot
for nSlot = 0:(carrier.SlotsPerFrame*numFrames)-1

    % Update the slot number
    carrier.NSlot = nSlot;

    % Display slot number and type (if diagnostics are enabled)
    if (diagnosticsOn)
        disp("Slot " + string(carrier.NSlot) + ": " + tddPattern(mod(carrier.NSlot,numel(tddPattern))+1));
    end

    % Schedule UEs for data transmission
    [schedule,PDSCHs,B] = hMultiUserSelection(csi,tddPattern,specialSlot,carrier,PDSCHs,bsAntSize,alg);
    
    % PDSCH transmissions for all UEs scheduled for data
    [txDL,txSymbols,singleLayerTBS] = hMultiDLTransmit(carrier,PDSCHs(schedule.PDSCH),numRF,B); %ofdm of pdsch is done here
    
    % SRS transmissions for all UEs scheduled for SRS
    [txUL,schedule.SRS] = hMultiULTransmit(carrier,SRSs);  %ofdm of srs is done here
    
    % Apply fading channels
    [channels,rxDL,rxUL] = hApplyMultiUserChannels(tddPattern,specialSlot,carrier,schedule,channels,txDL,txUL);
    
    % Apply AWGN
    rxDL = hApplyMultiUserAWGN(carrier,rxDL,SNRdBDL,CombineWaveforms=false);
    rxUL = hApplyMultiUserAWGN(carrier,rxUL,SNRdBUL,CombineWaveforms=true);
    
    % For all UEs scheduled for SRS, estimate the channel and record it
    H = hMultiULReceive(carrier,SRSs(schedule.SRS),rxUL,alg);
    csi = updateChannelEstimates(csi,carrier,schedule.SRS,H);
    
    % For all UEs scheduled for data, perform PDSCH reception and record the results
    [TBS,CRC,eqSymbols,nVar] = hMultiDLReceive(carrier,PDSCHs(schedule.PDSCH),rxDL,alg);
    dataState = updateDataTransfer(dataState,carrier,singleLayerTBS,schedule.PDSCH,TBS,CRC);

    % For all UEs scheduled for data, update noise estimates
    csi = updateNoiseEstimates(csi,carrier,schedule.PDSCH,nVar);

    % Display scheduled SRSs and PDSCHs, PDSCH EVM, and DL-SCH CRC (if diagnostics are enabled)
    if (diagnosticsOn)
        displayDiagnostics(schedule,PDSCHs,txSymbols,eqSymbols,CRC,groups);
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
