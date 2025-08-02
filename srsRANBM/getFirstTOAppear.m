function idx = getFirstToAppear(tddPattern, str1, str2)
%GETFIRSTTOAPPEAR Returns the index of string that appears first in the array
%   idx = getFirstToAppear(tddPattern, str1, str2)
%   tddPattern : array of strings (e.g., ["D","S","U"])
%   str1, str2 : strings to compare (e.g., "S", "U")
%   result     : the string that appears first
%   idx        : the index where it first appears

    idx1 = find(strcmp(tddPattern, str1), 1);
    idx2 = find(strcmp(tddPattern, str2), 1);

    if isempty(idx1), idx1 = inf; end
    if isempty(idx2), idx2 = inf; end

    if idx1 < idx2
        result = str1;
        idx = idx1;
    else
        result = str2;
        idx = idx2;
    end

    fprintf("First to appear: %s at index %d\n", result, idx);

end
