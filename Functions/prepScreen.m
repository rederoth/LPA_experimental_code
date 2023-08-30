function prepScreen
%
% 2017 by Martin Rolfs

global setting scr visual

if setting.TEST==2
    Screen('Preference', 'SkipSyncTests', 2);
end

scr.subDist = 1800;          % subject distance (mm)
scr.refRate = 120;          % refresh rate (Hz)
scr.xres    = 1920;         % x resolution (px)
scr.yres    = 1080;         % y resolution (px)
scr.width   = 1500;        % width  of screen (mm) 
scr.height  = 840;        % height of screen (mm)
scr.colDept = 8;           % color depth per channel
scr.nLums   = 2^scr.colDept;% number of possible luminance values
% Mario Kleiner: You should usually not specify such a bit depth, the system knows what it is doing.

% Use normalized luminance values to range of [0 1]
scr.normalizedLums = true;


% minimal setup:
PsychDefaultSetup(2);

% If there are multiple displays guess that one without the menu bar is the
% best choice.  Display 0 has the menu bar.
scr.allScreens = Screen('Screens');
scr.expScreen  = max(scr.allScreens);
% get the color indeces
scr.black = BlackIndex(scr.expScreen);
scr.white = WhiteIndex(scr.expScreen);
scr.gray = GrayIndex(scr.expScreen);
% background and foreground colors
scr.bgColor = scr.black;
scr.fgColor = scr.white;

%%%%% Based on Olga's code, gamma correction!
BackupCluts()
x=1:1:256;
gamma = 2.2;
ourCal = [(x/256.).^gamma; (x/256.).^gamma; (x/256.).^gamma]';
Screen('LoadNormalizedGammaTable', scr.expScreen, ourCal); % [, loadOnNextFlip][, physicalDisplay][, ignoreErrors]);
%%%%% end of gamma correction


% Open screen, minimal version
[scr.main,scr.rect] = PsychImaging('OpenWindow',scr.expScreen, scr.bgColor, [0 0 scr.xres scr.yres]);
%[scr.main,scr.rect] = PsychImaging('OpenWindow',scr.expScreen, scr.bgColor, [50 50 scr.xres*0.75 scr.yres*0.75]);


%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prep stimulus properties %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% determine th main window's center
[scr.centerX, scr.centerY] = WindowCenter(scr.main);
scr.scrCenter = [scr.centerX scr.centerY scr.centerX scr.centerY];

% translate visual angles to degrees (pixels per degree of visual angle)
visual.ppd     = dva2pix(1,scr);
% fixation and boundary radius for online check of gaze position
visual.fixDurReq = 0.4; % in seconds
visual.fixBrokenMax = 50;  % times you can break a fixation before a calibration is requested
visual.maxTimeWithoutFix = 2; % in seconds, time you have until you first fixate
visual.fixCkRad = 2*visual.ppd;
visual.fixCkCol = [1  0  0];
visual.boundRad = sqrt(2.5^2 + 2.5^2)*visual.ppd; 
% nyquist frequency
visual.fNyquist = 0.5;

% get flip duration in seconds (inverse of frame rate)
scr.fd = Screen('GetFlipInterval', scr.main);
fprintf(1,'\n\nScreen runs at %.1f Hz.\n\n',1/scr.fd);

% Fonts
% for some reason the linux machine matlab can't handle nomral fonts....you
% have to pick one from a big list that is output when there's an error
% because you tried to select the wrong font. 
Screen('TextFont', scr.main,'-adobe-helvetica-medium-o-normal--25-180-100-100-p-130-iso8859-1');
Screen('TextSize', scr.main, 40);

% % Enable alpha blending for proper combination of the gaussian aperture
% % with the drifting sine grating (NOT NEEDED HERE):
% Screen('BlendFunction', scr.main, GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, [1 1 1 1]);

% set priority of window activities to maximum
scr.maxPriorityLevel = MaxPriority(scr.main);

% Give the display a moment to recover from the change of display mode when
% opening a window. It takes some monitors and LCD scan converters a few seconds to resync.
if setting.TEST == 0
    HideCursor;
end
WaitSecs(2);

