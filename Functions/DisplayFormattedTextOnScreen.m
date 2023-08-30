function flipped = DisplayFormattedTextOnScreen(str, scr, posx, posy, lines)
% This function displays some text on the screen.

% lines: how many lines of text (separated by \n)??

bounds = Screen(scr.main, 'TextBounds', str);

if nargin==2 % no arguments passed: Tamara's version
    bx  = 400 - bounds(3)/2;     % x position of the text start
    by  = 300 - bounds(4)/2;     % y position
elseif nargin==5 % position of the text
    bx = posx - bounds(3)/(2*lines);
    by = posy - bounds(4)/(2*lines);
else
    error('Function needs either 2 or 4 arguments!');
end


DrawFormattedText(scr.main, str, bx, by, scr.fgColor);
flipped = Screen('Flip', scr.main);

end