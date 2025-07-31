%hMultiDLReceive Downlink receiver for MU-MIMO
%   [TBS,CRC,EQSYMBOLS,NVAR] = hMultiDLReceive(CARRIER,PDSCHs,RX,ALG)
%   performs downlink reception for a multi-user set of received waveforms,
%   returning multi-user sets of transport block sizes, TBS, cyclic
%   redundancy check values, CRC, equalized symbols EQSYMBOLS, and noise
%   variance estimates NVAR. CARRIER is the carrier configuration. PDSCHs
%   is a multi-user set of PDSCH configurations. RX is a multi-user set of
%   received waveforms. ALG is a structure containing algorithmic options.

% Copyright 2021-2024 The MathWorks, Inc.

function [TBS,CRC,eqSymbols,nVar] = hMultiDLReceive(carrier,PDSCHs,rx,alg)

    numUEs = numel(rx);
    TBS = cell(1,numUEs);
    CRC = cell(1,numUEs);
    eqSymbols = cell(1,numUEs);

    % For each UE
    for ue = 1:numUEs

        % Extract the configuration for this UE
        pdsch = PDSCHs(ue).Config;
        pdschExt = PDSCHs(ue).Extension;

        % Perform OFDM demodulation (for ChannelFiltering = true)
        rxGrid = rx(ue).rxGrid;
        offset = rx(ue).ChannelFilterDelay;
        if (isempty(rxGrid))
            rxWaveform = rx(ue).rxWaveform;
            rxWaveform = rxWaveform(1+offset:end,:);
            rxGrid = nrOFDMDemodulate(carrier,rxWaveform);
        end

        % Perform channel and noise estimation
        if (alg.PerfectChannelEstimator)

            H = nrPerfectChannelEstimate(carrier,rx(ue).pathGains,rx(ue).pathFilters,offset,rx(ue).sampleTimes);
            nVarUE = rx(ue).noisePower;

        else

            % Create DM-RS symbols and indices
            dmrsIndices = nrPDSCHDMRSIndices(carrier,pdsch);
            dmrsSymbols = nrPDSCHDMRS(carrier,pdsch);
            
            [H,nVarUE] = hSubbandChannelEstimate(carrier,rxGrid,dmrsIndices,dmrsSymbols,pdschExt.PRGBundleSize,'CDMLengths',[2 2]);

            % Average noise estimate across PRGs and layers
            nVarUE = mean(nVarUE,'all');

        end

        % Create PDSCH indices and extract allocated PDSCH REs in the
        % received grid and channel estimation
        [pdschIndices,indicesInfo] = nrPDSCHIndices(carrier,pdsch);
        [pdschRx,pdschH,~,pdschHIndices] = nrExtractResources(pdschIndices,rxGrid,H);

        % If perfect channel estimation is configured, the channel
        % estimates must be precoded so that they are w.r.t. layers rather
        % than transmit antennas
        if (alg.PerfectChannelEstimator)
            pdschH = nrPDSCHPrecode(carrier,pdschH,pdschHIndices,permute(pdschExt.W,[2 1 3]));
        end

        % Perform equalization
        [eqSymbols{ue},csi] = nrEqualizeMMSE(pdschRx,pdschH,nVarUE);

        % Perform PDSCH demodulation
        [cws,rxSymbols] = nrPDSCHDecode(carrier,pdsch,eqSymbols{ue},nVarUE);

        % Apply CSI to demodulated codewords
        csi = nrLayerDemap(csi);
        for c = 1:pdsch.NumCodewords
            Qm = length(cws{c}) / length(rxSymbols{c});
            csi{c} = repmat(csi{c}.',Qm,1);
            cws{c} = cws{c} .* csi{c}(:);
        end

        % Perform DL-SCH decoding
        decodeDLSCH = nrDLSCHDecoder();
        decodeDLSCH.TargetCodeRate = pdschExt.TargetCodeRate;
        decodeDLSCH.LDPCDecodingAlgorithm = 'Normalized min-sum';
        decodeDLSCH.MaximumLDPCIterationCount = 6;
        TBS{ue} = nrTBS(pdsch.Modulation,pdsch.NumLayers,numel(pdsch.PRBSet),indicesInfo.NREPerPRB,pdschExt.TargetCodeRate,pdschExt.XOverhead);
        decodeDLSCH.TransportBlockLength = TBS{ue};
        RV = 0;
        [~,CRC{ue}] = decodeDLSCH(cws,pdsch.Modulation,pdsch.NumLayers,RV);

    end

    % Note that although this function supports practical channel / noise
    % estimation for PDSCH reception, the noise variance returned for each
    % UE is the true noise variance recorded in the received waveform
    % information. This is because the noise variance returned here may be
    % used in place of a CSI report, which would use a wideband CSI-RS.
    % This would result in a more accurate noise estimate than that
    % achievable using the PDSCH DM-RS with a limited PRB allocation
    nVar = {rx.noisePower};

end