function displayDiagnostics(schedule,PDSCHs,txSymbols,eqSymbols,CRC,groups)
% Display diagnostic information

    dispfn = @(x,y)disp([sprintf('%5s: ',x) sprintf('%2d ',y)]);

    if (~isempty(schedule.PDSCH))

        numUEs = numel(schedule.PDSCH);
        maxLayers = 4;
        EVM = NaN(maxLayers,numUEs);
        NPRB = zeros(1,numUEs);

        for i = 1:numUEs

            ue = schedule.PDSCH(i);
            pdsch = PDSCHs(ue).Config;
            NPRB(i) = numel(pdsch.PRBSet);
            evm = comm.EVM;
            EVM(1:pdsch.NumLayers,i) = evm(txSymbols{i},eqSymbols{i});

        end

        dispfn('Group',groups(schedule.PDSCH));
        dispfn('PDSCH',schedule.PDSCH);
        dispfn('NPRB',NPRB);

        evmlabel = '  EVM: ';
        for i = 1:maxLayers
            if (i>1)
                evmlabel(:) = ' ';
            end
            if (~all(isnan(EVM(i,:))))
                disp([evmlabel strrep(sprintf('%2d ',round(EVM(i,:))),'NaN','  ')]);
            end
        end

        dispfn('CRC',[CRC{:}]);

    end

    if (~isempty(schedule.SRS))

        disp('SRS transmission');

    end

end