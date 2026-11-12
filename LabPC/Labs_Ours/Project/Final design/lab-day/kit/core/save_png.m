function save_png(h, file, res)
% SAVE_PNG  PNG of a figure/axes/tab; exportgraphics where it exists (R2020a+), else print.
if nargin < 3, res = 110; end
try
    exportgraphics(h, file, 'Resolution', res);
catch
    f = ancestor(h, 'figure');
    print(f, file, '-dpng', sprintf('-r%d', res));
end
end
