function prepStim
%
% 2008 by Martin Rolfs

global visual scr


visual.black = BlackIndex(scr.main);
visual.white = WhiteIndex(scr.main);

visual.bgColor = visual.black+visual.white/2;       % background color
visual.fgColor = visual.black;                      % foreground color
visual.inColor = visual.white-visual.bgColor;       % increment for full contrast

visual.ppd     = dva2pix(1,scr);   % pixel per degree

visual.scrCenter = [scr.centerX scr.centerY scr.centerX scr.centerY];

visual.fixCkRad = 1.5*visual.ppd; % fixation check radius 
visual.fixCkCol = [0  0  0];    % fixation check color %[255  0  0]

% boundary radius (enveloping landmarks)
visual.boundRad = sqrt(2.5^2 + 2.5^2)*visual.ppd; %2.5

visual.fNyquist = 0.5; %What is it for?

% get priority of window activities to maximum
scr.maxPriorityLevel = MaxPriority(scr.main);
