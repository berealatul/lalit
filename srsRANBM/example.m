% Requires 5G Toolbox
clc;
close all;
clear all;
srs = nrSRSConfig('NumSRSSymbols',4,'KTC',4);
grid = nrSRSGrid(srs);
imshow(grid, 'InitialMagnification',1000);
colormap(parula); colorbar;