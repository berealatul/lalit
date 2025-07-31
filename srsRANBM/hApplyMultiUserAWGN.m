%hApplyMultiUserAWGN Apply AWGN for MU-MIMO
%   OUT = hApplyMultiUserAWGN(CARRIER,IN,SNRdB) applies AWGN to a
%   multi-user set of received waveforms, returning a multi-user set of
%   noisy waveforms, OUT. CARRIER is the carrier configuration. IN is a
%   multi-user set of received waveforms. SNRdB is the signal-to-noise
%   ratio in dB. For an explanation of the SNR definition that this
%   function uses, see <docid:5g_ug#mw_37cef3ca-2f4b-433d-8d68-117a881ca5fd
%   SNR Definition used in Link Simulations>
%
%   An optional name-value pair CombineWaveforms = false,true provides
%   control over whether or not input signals are combined (i.e. summed)
%   prior to applying AWGN. CombineWaveforms = true is appropriate for base
%   station reception, where all transmitted (UE) waveforms are detected by
%   the base station antennas and then noise is added to those antennas.
%   CombineWaveforms = false is appropriate for UE reception, where noise
%   is separately added to the UE antennas for each UE.
%
%   This function supports applying AWGN in the time domain for channels
%   configured with ChannelFiltering = true, and applying AWGN in the
%   frequency domain for channels configured with ChannelFiltering = false.

% Copyright 2021-2023 The MathWorks, Inc.

function rx = hApplyMultiUserAWGN(carrier,rx,SNRdB,varargin)

    % Parse the 'CombineWaveforms' option
    persistent ip;
    if (isempty(ip))
        ip = inputParser;
        addParameter(ip,'CombineWaveforms',false);
    end
    parse(ip,varargin{:});
    opts = ip.Results;

    % Combine waveforms if appropriate
    nUEs = numel(rx);
    if (nUEs>0 && opts.CombineWaveforms)
        sumWaveform = rx(1).rxWaveform;
        sumGrid = rx(1).rxGrid;
        for ue = 2:nUEs
            sumWaveform = sumWaveform + rx(ue).rxWaveform;
            sumGrid = sumGrid + rx(ue).rxGrid;
        end
        for ue = 1:nUEs
            rx(ue).rxWaveform = sumWaveform;
            rx(ue).rxGrid = sumGrid;
        end
    end

    % For each UE
    for ue = 1:nUEs

        % Establish dimensionality from either:
        % the received waveform (for ChannelFiltering = true)
        % or
        % the received grid (for ChannelFiltering = false)
        ofdmInfo = rx(ue).ofdmInfo;
        if (~isempty(rx(ue).rxWaveform))
            [T,Nr] = size(rx(ue).rxWaveform);
        else
            L = carrier.SymbolsPerSlot;
            T = sum(ofdmInfo.SymbolLengths(mod(carrier.NSlot,carrier.SlotsPerSubframe)*L + (1:L)));
            T = T + rx(ue).ChannelFilterDelay;
            Nr = size(rx(ue).rxGrid,3);
        end

        % Linear SNR
        SNR = 10^(SNRdB/10);

        % Create noise, either for the first UE if CombineWaveforms =
        % true, or for every UE if CombineWaveforms = false
        if (ue==1 || ~opts.CombineWaveforms)
            if (~isempty(rx(ue).rxWaveform))
                N0time = 1 / sqrt(Nr*ofdmInfo.Nfft*SNR); % noise spectral density in the time domain
                noise = N0time * randn([T Nr],'like',rx(ue).rxWaveform);
            else
                N0freq = 1 / sqrt(Nr*SNR); % noise spectral density in the freq domain
                noiseGrid = N0freq * randn(size(rx(ue).rxGrid),'like',rx(ue).rxGrid);
            end
        end

        % Add noise to either the received waveform or received grid
        % (depending on whether ChannelFiltering is true or false)
        if (~isempty(rx(ue).rxWaveform))
            rx(ue).rxWaveform = rx(ue).rxWaveform + noise;
        else
            rx(ue).rxGrid = rx(ue).rxGrid + noiseGrid;
        end

        % Record grid noise power, used for perfect channel estimation
        rx(ue).noisePower = 1 / (Nr*SNR);

    end

end
