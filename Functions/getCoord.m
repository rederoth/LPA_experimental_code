function [x, y, t_pc, t_eye, pa] = getCoord(el, setting, scr_main)
% this function gets the current coordinates from Eyelink or the mouse
% respectively


if setting.TEST ~= 0  % use the mouse instead of the eye tracker
    noise_for_mouse_factor = 2; % in pixels
	[x,y,~] = GetMouse( scr_main );         % get gaze position from mouse	
    x = x + noise_for_mouse_factor*(0.5 - rand);                     % give mouse some noise
    y = y + noise_for_mouse_factor*(0.5 - rand);
    t_pc = GetSecs;                   % we need time in millisecond range
    t_eye = round(t_pc*1000);
else
    % do we know which eye to track yet? One may choose between left or
    % right eye for gaze contingency. in the edf we can have both anyway.
    if setting.eye_used == 0 || setting.eye_used == 1 
        % get latest float sample
        evt = Eyelink('NewestFloatSample');
        t_pc = GetSecs;
        x   = evt.gx(setting.eye_used+1);
        y   = evt.gy(setting.eye_used+1);
        t_eye   = evt.time;
        pa  = evt.pa(setting.eye_used+1);
        
        % do we have valid data and is the pupil visible?
        if  x==el.MISSING_DATA || y==el.MISSING_DATA || pa==0
            x = NaN;
            y = NaN;
        end
        
    % if the eye is unknown, or the subject doesn't have any eye dominance, 
    % first find eye that's being tracked
    else 
        setting.eye_used = Eyelink('EyeAvailable'); % get eye that's tracked
        if setting.eye_used == el.BINOCULAR % if both eyes are tracked
            setting.eye_used = 0; % use the first eye as default
        end
    end % which eye to measure
%     disp([x y]);
end
