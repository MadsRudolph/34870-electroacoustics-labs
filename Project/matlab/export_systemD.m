function export_systemD()
% export_systemD()
%
% Writes everything the LTspice models need into Project/data:
%   Zi_mid.txt, Zi_tw.txt                      input impedances (passive branch loads)
%   TF_woof.txt, TF_mid.txt, TF_tw.txt         p/V on axis, d = -1.15 m for all three
%   TF30_woof.txt, TF30_mid.txt, TF30_tw.txt   the same at 30 deg
% with the source and label names already made unique per unit
% (BiZin_mid, Vspkr_mid, BvTF_mid, Pout_mid, ...), so the files can be .inc'ed
% side by side in one schematic.
%
% Also writes plain CSV copies (f, Re, Im) of the same data for scripts that
% cannot read .mat files: csv/Z_<tag>.csv (every Lab D impedance),
% csv/NF_<tag>.csv (near field) and csv/TF_on_<unit>.csv, csv/TF_off30_<unit>.csv
% (Lab E p/V, raw, without the distance compensation).
%
% Run from Project/matlab:  matlab -batch export_systemD

here = fileparts(mfilename('fullpath'));
addpath(fullfile(here, 'course'));
S = load_systemD;
out = fullfile(fileparts(here), 'data');
old = cd(out);
cleanup = onCleanup(@() cd(old));

d = -1.15;                                   % same distance for every unit (Lab E reference report)
units = {'woofer', 'woof'; 'midrange', 'mid'; 'tweeter', 'tw'};

for k = 2:3                                  % only the passive branch needs Zi
    name = ['Zi_' units{k, 2}];
    Matlab2LTspice(S.Zi.(units{k, 1}).f, S.Zi.(units{k, 1}).Z, name, 0);
    rename([name '.txt'], units{k, 2});
end
for k = 1:3
    for a = {'on', 'TF'; 'off30', 'TF30'}'
        name = [a{2} '_' units{k, 2}];
        Matlab2LTspice(S.TF.f, S.TF.(a{1}).(units{k, 1}), name, 1, d);
        rename([name '.txt'], units{k, 2}, a{2});
    end
end
close all

% --- CSV for the box model
if ~exist('csv', 'dir'), mkdir csv, end
for t = fieldnames(S.Zi)'
    writecsv(fullfile('csv', ['Z_' t{1} '.csv']), S.Zi.(t{1}).f, S.Zi.(t{1}).Z);
end
for t = fieldnames(S.NF)'
    writecsv(fullfile('csv', ['NF_' t{1} '.csv']), S.NF.(t{1}).f, S.NF.(t{1}).H);
end
for k = 1:3                                  % raw p/V, no distance compensation
    writecsv(fullfile('csv', ['TF_on_' units{k, 1} '.csv']), S.TF.f, S.TF.on.(units{k, 1}));
    writecsv(fullfile('csv', ['TF_off30_' units{k, 1} '.csv']), S.TF.f, S.TF.off30.(units{k, 1}));
end
end


function rename(file, u, prefix)
% Make the generator and node names in the first line unique per unit.
if nargin < 3, prefix = ''; end
txt = fileread(file);
nl = find(txt == newline, 1);
first = txt(1:nl - 1);
src = ['_' u];
if strcmp(prefix, 'TF30'), src = ['30_' u]; end
first = regexprep(first, '^(\w+)', ['$1' src]);           % BvTF -> BvTF_mid / BvTF30_mid
first = strrep(first, 'Vspkr', ['Vspkr_' u]);
first = strrep(first, 'Pout', ['Pout' src]);              % Pout_mid / Pout30_mid
fid = fopen(file, 'w');
fprintf(fid, '%s', [first txt(nl:end)]);
fclose(fid);
end


function writecsv(file, f, Z)
fid = fopen(file, 'w');
fprintf(fid, 'f,re,im\n');
fprintf(fid, '%.6g,%.10g,%.10g\n', [f(:) real(Z(:)) imag(Z(:))].');
fclose(fid);
end
