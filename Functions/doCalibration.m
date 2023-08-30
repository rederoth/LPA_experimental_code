function calibresult = doCalibration(el)

global setting


if setting.TEST == 0
    disp([num2str(GetSecs) ' Performing Calibration now.']);
    calibresult = EyelinkDoTrackerSetup(el);
    if calibresult==el.TERMINATE_KEY
        return
    end
    % remember that we're not automatically recording after calibration
    setting.is_recording = 0;
end
