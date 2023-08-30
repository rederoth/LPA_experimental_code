function prepScreen
%
% 2017 by Martin Rolfs

global setting scr visual

if setting.TEST
    Screen('Preference', 'SkipSyncTests', 1);
end

AssertOpenGL;

scr.subDist = 570;          % subject distance (mm)
scr.refRate = 120;          % refresh rate (Hz)
scr.xres    = 1920;         % x resolution (px)
scr.yres    = 1080;         % y resolution (px)
scr.width   = 520.0;        % width  of screen (mm) 
scr.height  = 290.0;        % height of screen (mm)
scr.colDept = 10;           % color depth per channel
scr.nLums   = 2^scr.colDept;% number of possible luminance values

% Use normalized luminance values to range of [0 1]
scr.normalizedLums = true;
scr.reco = [scr.xres*0.3 scr.yres*0.25 scr.xres*0.7 scr.yres*0.75];

% set calibration file for gamma correction
calibFile='ourCal.mat';

% If there are multiple displays guess that one without the menu bar is the
% best choice.  Dislay 0 has the menu bar.
scr.allScreens = Screen('Screens');
scr.expScreen  = max(scr.allScreens);

switch setting.Pixx
    case 1
        % Open the datapixx device (don't forget to close it in the end)
        PsychDataPixx('Open');
        Datapixx('StopAllSchedules');
        
        % Setup specific mode of the Datapixx
        PsychDataPixx('EnableVideoScanningBacklight');
        PsychImaging('PrepareConfiguration');
        PsychImaging('AddTask', 'General', 'UseFastOffscreenWindows');
        PsychImaging('AddTask', 'General', 'FloatingPoint32Bit');
        %PsychImaging('AddTask', 'General', 'EnableDataPixxM16OutputWithOverlay');
        PsychImaging('AddTask', 'General', 'NormalizedHighresColorRange');      %not in M16 demo, but recommended in VPixx Support email
end

% Announce that you want to use a lookup table for gamma correction
PsychImaging('AddTask', 'FinalFormatting','DisplayColorCorrection','LookupTable');

% Tell the screen to have luminance in the range 0-1
if scr.normalizedLums
    [scr.main,scr.rect] = PsychImaging('OpenWindow',scr.expScreen,ones(1,3)*0.5,[],scr.colDept,2,0,4);
    Screen('ColorRange', scr.main,1.0);
end


%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% prep stimulus properties %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% determine th main window's center
[scr.centerX, scr.centerY] = WindowCenter(scr.main);
visual.scrCenter = [scr.centerX scr.centerY scr.centerX scr.centerY];

% define basic stimulus properties
visual.black   = BlackIndex(scr.main);
visual.white   = WhiteIndex(scr.main);
visual.bgColor = (visual.black+visual.white)/2; % background color
visual.fgColor = visual.black;                  % foreground color
visual.inColor = visual.white-visual.bgColor;   % maximum increment

% translate visual angles to degrees (pixels per degree of visual angle)
visual.ppd     = dva2pix(1,scr);

% fixation and boundary radius for online check of gaze position
visual.fixCkRad = 1.5*visual.ppd;
visual.fixCkCol = [1  0  0];
visual.boundRad = sqrt(2.5^2 + 2.5^2)*visual.ppd; 

% nyquist frequency
visual.fNyquist = 0.5;

% load calibration file 
load(calibFile);
PsychColorCorrection('SetLookupTable',scr.main,ourCal.gammaTable);

% get heigth and width of screen [pix]
[scr.xres, scr.yres] = Screen('WindowSize', scr.main);

% get flip duration in seconds (inverse of frame rate)
scr.fd = Screen('GetFlipInterval',scr.main);
fprintf(1,'\n\nScreen runs at %.1f Hz.\n\n',1/scr.fd);

% Fonts
% for some reason the linux machine matlab can't handle nomral fonts....you
% have to pick one from a big list that is output when there's an error
% because you tried to select the wrong font. 
Screen('TextFont', scr.main,'-adobe-helvetica-medium-o-normal--25-180-100-100-p-130-iso8859-1');
Screen('TextSize', scr.main, 18);

% Enable alpha blending for proper combination of the gaussian aperture
% with the drifting sine grating:
Screen('BlendFunction',scr.main,GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA, [1 1 1 1]);

% set priority of window activities to maximum
scr.maxPriorityLevel = MaxPriority(scr.main);

% Give the display a moment to recover from the change of display mode when
% opening a window. It takes some monitors and LCD scan converters a few seconds to resync.
HideCursor;
WaitSecs(2);

