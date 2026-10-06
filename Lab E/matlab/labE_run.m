%% Lab E: run the measurements from here
% Open this file in the MATLAB editor. Each measurement is its own section:
% edit the values in that section, click inside it and press
% "Run Section" (Ctrl+Enter). Every run is saved to ../data/labE_<tag>.mat
% straight away; a repeated tag gets _2, _3 ... so nothing is overwritten.
%
% Plug the UMIK into USB BEFORE starting MATLAB, or it is not found.
% Check after every run: no time signal above 1 (the function warns), and
% the UMIK curve well above the noise in the course routine's figure 21.

%% 0. Settings shared by every measurement: SET THESE FIRST
UmikSN = '708-0332';     % read the label on the UMIK; 0329, 0332 or 0335
try, cd(fileparts(matlab.desktop.editor.getActiveFilename)); end   % run from this folder

%% 0b. Check the copy works (no hardware): must print PASS
test_labE
% Pressing Run (F5) stops here, so it never fires all the measurements in a
% row. From here on use Run Section (Ctrl+Enter) on one section at a time.
return

%% 1a. 3" driver in its small box: 0 and 30 degrees
% Turn the metal bar the box sits on to change the angle.
angle_deg = 0;               % 0, then 30
tag  = sprintf('box_%d', angle_deg);
m = measure_labE(tag, 'baffle', angle_deg, 'UmikSN', UmikSN, 'note', 'small box');

%% 1b. Circular screen (black arrow up): 0 and 30 degrees
angle_deg = 0;               % 0, then 30
tag  = sprintf('circle_%d', angle_deg);
m = measure_labE(tag, 'baffle', angle_deg, 'UmikSN', UmikSN, 'note', 'circular screen');

%% 1c. IEC screen, driver in the upper part: 0, 15, 30 and 60 degrees
angle_deg = 0;               % 0, 15, 30, then 60
tag  = sprintf('iec_%d', angle_deg);
m = measure_labE(tag, 'baffle', angle_deg, 'UmikSN', UmikSN, 'note', 'IEC screen, asymmetric');

%% 2. Project system, woofer vent plugged: 0, 30 and 60 degrees
% One run measures all three units: start on the WOOFER, switch to the
% MIDRANGE during the first beeps and to the TWEETER during the second.
% Takes about 4 minutes. Do not move the microphone between the angles.
angle_deg = 0;               % 0, 30, then 60
tag  = sprintf('system_%d', angle_deg);
m = measure_labE(tag, 'system', angle_deg, 'UmikSN', UmikSN, ...
    'units', {'woofer', 'midrange', 'tweeter'}, 'note', 'vent plugged');

%% 3. Before you leave: fill in labE_dims.m
% Driver diameters, screen sizes, the driver position on the IEC screen,
% microphone distance and height, and how the two boxes were placed.
edit labE_dims
