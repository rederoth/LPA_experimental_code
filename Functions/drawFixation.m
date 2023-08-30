function drawFixation(col,loc)
%
% 2010 by Martin Rolfs

global scr visual

pu = round(visual.ppd*0.085);
Screen(scr.main, 'FillOval', col, loc+[-pu -pu pu pu]);
Screen(scr.main, 'FrameOval', col, loc+3*[-pu -pu pu pu], pu);

