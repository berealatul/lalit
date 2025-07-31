%   CDML = hSRSCDMLengths(SRS) returns the CDM lengths for the SRS
%   configuration SRS.
%
%   See also nrSRSConfig, nrSRS, nrSRSIndices.

%   Copyright 2019-2023 The MathWorks, Inc.

function cdmLengths = hSRSCDMLengths(srs)

    % TS 38.211 Section 6.4.1.4.2, definition of N_ap_bar
    if (srs.EnableEightPortTDM)
        N_ap_bar = 4;
    else
        N_ap_bar = srs.NumSRSPorts;
    end

    % TS 38.211 Section 6.4.1.4.3, position in comb per port
    halfPorts = (N_ap_bar==8 && srs.KTC==4) || ...
        (N_ap_bar==8 && srs.KTC==2 && srs.CyclicShift>=4) || ...
        (N_ap_bar==4 && srs.KTC==8) || ...
        (N_ap_bar==4 && srs.KTC==4 && srs.CyclicShift>=6) || ...
        (N_ap_bar==4 && srs.KTC==2 && srs.CyclicShift>=4);
    if halfPorts
        divfd = 2;
    elseif (N_ap_bar==8 && srs.KTC==8)
        divfd = 4;
    else
        divfd = 1;
    end

    F = N_ap_bar / divfd;

    cdmLengths = [F 1];

end