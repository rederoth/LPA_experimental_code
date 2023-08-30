% check for eye/mouse sample

% always check for new eye link or mouse data
if setting.TEST == 0 % check eyelink
    if Eyelink('NewFloatSampleAvailable') > 0 % check whether there is a new sample available
        % get the sample in the form of an event structure
        tframe = tframe + 1;
        [td.x(tframe), td.y(tframe), td.t(tframe), td.t_eye(tframe), ~] = ...
            getCoord(el, setting, scr.main);
        current_fix = [td.x(tframe), td.y(tframe), td.t(tframe)];
        got_new_sample = 1;
    else
        got_new_sample = 0;
    end
else % check mouse to simulate gaze samples
    if (tframe == 0) || (GetSecs - td.t(tframe) > 1/500) % simulating a sampling rate of 500 Hz
        tframe = tframe + 1;
        [td.x(tframe), td.y(tframe), td.t(tframe)] = getCoord(el, setting, scr.main);
        current_fix = [td.x(tframe), td.y(tframe), td.t(tframe)];
        got_new_sample = 1;
    else
        got_new_sample = 0;
    end
end