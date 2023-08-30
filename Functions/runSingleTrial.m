function td = runSingleTrial(el, td)
%RUNSINGLETRIAL Summary of this function goes here
%   Detailed explanation goes here
% our refresh rate 100 frames per second (whether the new texture is
% available or not)
% every flip send a message to the eyeLink

% by Richard Schweitzer


% Nico TODOs
%   - are all messages sent / is everything synced with the eyelink?
%   - is there a problem due to assuming all videos have 120 frames?
%   - check that loading of video is fast enough on lab setup!
%   - error using screen in second block?!? --> video giraffe
%   - problem due to scaling?





global scr setting visual keys

disp([num2str(GetSecs), ' Start trialCntr=', num2str(td.trialCntr)]);

identicalSecs = 5;

%% prepare triggers
% if we're on the Datapixx, then we want to send triggers, which we set up
% here. 
% from: http://www.vpixx.com/manuals/psychtoolbox/html/DigitalIODemo4.html
if setting.Pixx == 2
    if ~Datapixx('IsReady')
        Datapixx('Open');
    end
    % stop all running schedules (there shouldn't be any)
    Datapixx('StopAllSchedules');
    Datapixx('RegWrRd');    % Synchronize DATAPixx registers to local register cache
    % and set all bits to low
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
    % Define the trigger value. The eyelink has 8 bits on digital input
    % that are on pins 2-9. On the Datapixx we have 24 bits of digital
    % output. To achieve a certain trigger value on the Eyelink, the
    % following heuristic can be used: dOut = 2^(triggerVal*2)
    triggerVal = 1;
    % prepare the trigger sequence here:
    doutWave = [2^(triggerVal*2), 0, 0]; % one high, two low
    bufferAddress = 8e6;
    Datapixx('WriteDoutBuffer', doutWave, bufferAddress);
    Datapixx('RegWrRd');
    % define the schedule, but set it later, as "multiple calls to 
    % StartDoutSchedule each require their own call to SetDoutSchedule"
    samplesPerTrigger = size(doutWave,2);
    sampleDur = 0.002; % in ms
    % done.
    disp([num2str(GetSecs), ' Prepared triggers']);
end

%% Make sure td is same structure even if not checked for video
td.moviename = sprintf('%s%s', setting.path_to_videos, td.fileName); %current movie file name gets passed on here
td.video_file_exists = NaN;
td.moviedata = [NaN, NaN, NaN, NaN, NaN, NaN, NaN, NaN];
td.all_tex = NaN(2, 5);
td.frame_dur = NaN;


%% check and prepare image

% currently movie name is passed to trial, convert to image name!
if td.video ==1
    td.imagename = sprintf('%s%s.png', setting.path_to_videos, td.fileName(1:end-6)); %% fileName(1:end-6)
else
    td.imagename = sprintf('%s%s.png', setting.path_to_videos, td.fileName(1:end-4)); %% fileName(1:end-6)
end    
disp([num2str(GetSecs), ' Reading: ', td.imagename]); 
% open the image, initialize
if exist(td.imagename, 'file') % check whether the file exists
    td.image_file_exists = 1;
    im = imread(td.imagename);
    imageTexture = Screen('MakeTexture', scr.main, im, 0, 2);
    [height, width, ~] = size(im);
    % use only 80% of screen for better data quality!
    % same factor for all videos, since format is identical
    td.video_scale_factor = setting.video_perc_of_screen; 
    td.v_width = round(width * td.video_scale_factor);
    td.v_height = round(height * td.video_scale_factor);

    % where should the image / video be drawn?
    td.video_dest_rect = [round(scr.centerX-td.v_width/2), round(scr.centerY-td.v_height/2), ...
        round(scr.centerX-td.v_width/2)+td.v_width, round(scr.centerY-td.v_height/2)+td.v_height];
    % fixation control position within the boundaries of the movie rectangle
    td.fix_pos = [randi([td.video_dest_rect(1), td.video_dest_rect(3)], 1), ...
        randi([td.video_dest_rect(2), td.video_dest_rect(4)], 1)];

    if td.video == 0
        td.n_frames = 1;
        td.n_flips = td.n_frames+1;
    else
        td.n_frames = 120; % image + fixed #frames in video 
        td.n_flips = td.n_frames + 1; 
        % there must be TWO more flip than frames, as there must be a blank screen at the end
    end

else
    td.image_file_exists = 0;
    disp([td.imagename, ' - image file does not exist!']);
    warning([td.imagename, ' - image file does not exist!']);
    % still allocate the structure elements, so that we don't get mismatch
    % errors:
    td.video_scale_factor = NaN;
    td.v_width = NaN;
    td.v_height = NaN;
    td.video_dest_rect = [NaN, NaN, NaN, NaN];
    td.fix_pos = [NaN, NaN];
    %
    td.frame_dur = NaN;
    td.n_frames = 1;
    td.n_flips = td.n_frames+1; 

end

%% prepare Eyelink
if setting.TEST == 0 && td.image_file_exists == 1
    % clean operator screen
    Eyelink('command','clear_screen');
    if Eyelink('isconnected')==el.notconnected		% cancel if eyeLink is not connected
        return
    end
    % This supplies a title at the bottom of the eyetracker display
    Eyelink('command', 'record_status_message ''Block %d , Trial %d , TrialCntr %d''', ...
            td.block, td.trial, td.trialCntr);
    % This supplies a screen for the experimenter.........
    % clear tracker display 
    Eyelink('Command', 'clear_screen %d', 0);
    % fixRect
    Eyelink('command','draw_box %d %d %d %d 15', ...
        round(td.fix_pos(1)-visual.fixCkRad), round(td.fix_pos(2)-visual.fixCkRad), ...
        round(td.fix_pos(1)+visual.fixCkRad), round(td.fix_pos(2)+visual.fixCkRad));
    % videoRect
    Eyelink('command','draw_box %d %d %d %d 15', ...
        td.video_dest_rect(1), td.video_dest_rect(2), td.video_dest_rect(3), td.video_dest_rect(4));
    % this marks the start of the trial
    Eyelink('message', 'BLOCK %d', td.block);
    Eyelink('message', 'TRIAL_in_BLOCK %d', td.trial);
    Eyelink('message', 'TRIAL_Start %d', td.trialCntr); % this message is crucial for parsing of the edf file!!!
    % start recording, if this still needs to be done (e.g., after calib)
    if ~setting.is_recording
        while ~setting.is_recording
            if ~setting.is_recording
                Eyelink('startrecording');	% start recording
                WaitSecs(1);
                err=Eyelink('checkrecording'); 	% check recording status
                if err==0
                    setting.is_recording = 1;
                    Eyelink('message', 'RECORD_START');
                else
                    setting.is_recording = 0;	
                    Eyelink('message', 'RECORD_FAILURE');
                end
            end
        end
    end
end

%% fixation control
% important: here we allow a shortcut to end the experiment
td.do_escape = 0; % 1: the experiment will be terminated (triggered by a keypress during fixation control)
% pre-allocate fixation control variables
td.fixReq = td.image_file_exists == 1; % is set to 0 once fixation is passed
td.fixaOn = NaN;  % time when fixation dot is presented
td.fixStart = NaN; % time when fixation starts
td.fixBrokenCntr = 0; % is increased each time the fixation is broken
td.fixBrokenTime = NaN; % last time when fixation was broken
td.fixEnd = NaN; % time when fixation control is successful
td.x = NaN(1,1000000);       % x coord
td.y = NaN(1,1000000);       % y coord of Eye link
td.t = NaN(1,1000000);       % eye link timestamp (when retrieved)
td.t_eye = NaN(1,1000000);   % eye link timestamp
% ... and a few control variables
firstInsideFixLoc = 0; % is set to 1 when the fixation is within range
tframe = 0; % iterator for number of eyelink samples retrieved, updated in check_for_sample (BAD!)
current_fix = [NaN NaN];  % the current fixation [x, y]

% draw the fixation target to buffer, provided the IMAGE exists
if td.image_file_exists == 1 && td.do_escape == 0 % setting.TEST < 2 && 
    
    % draw fixation to buffer
    drawFixation(visual.fixCkCol, [td.fix_pos, td.fix_pos]);
    td.fixaOn = Screen('Flip', scr.main); % flip upon next refresh
    if setting.TEST == 0
        Eyelink('message', 'EVENT_fixaOn');
    end
    disp([num2str(td.fixaOn), ' Fixation on.']);
    
    % now run as long as the subject needs to complete fixation control
    while td.fixReq == 1 && td.do_escape == 0
        
        % always check for new eye link or mouse data
        check_for_sample; % BAD! (but also used later...)
        
        % have we got a new sample? then check whether it's within range
        if got_new_sample
            % check whether the eye is currently in the fixation rect
            if isDotWithinCircle(current_fix, td.fix_pos, visual.fixCkRad) % fixation is in fixation circle
                if firstInsideFixLoc == 0 % fixation is in the rect for the first time, or has been broken before
                    firstInsideFixLoc = 1;
                    td.fixStart = GetSecs;
                    if setting.TEST == 0
                        Eyelink('message', 'EVENT_fixStart');
                    end
                else % fixation has been in the rect before
                    % have we spent enough time (specified by fixDur) fixating,
                    % so that we can turn on the cue?
                    if GetSecs >= (td.fixStart + visual.fixDurReq) % fixation passed
                        td.fixEnd = GetSecs;
                        if setting.TEST == 0
                            Eyelink('message', 'EVENT_fixEnd');
                        end
                        disp([num2str(GetSecs), ' Fixation successful.']);
                        td.fixReq = 0;   % fixation not required anymore -> show the saccade cue
                    end
                end
            else % fixation is no longer in the circle
                if firstInsideFixLoc == 1 % the eye has been in the circle before
                    % participant has fixated but then broken the fixation
                    td.fixBrokenTime = GetSecs;
                    if setting.TEST == 0
                        Eyelink('message', 'EVENT_fixBroken');
                    end
                    % increase the fixBrockenCntr
                    td.fixBrokenCntr = td.fixBrokenCntr + 1;
                    % reset variables, because fixation was broken
                    firstInsideFixLoc = 0; % fixation is not in the rect anymore
                end
            end
        end
        
        % BREAK OUT OF THE LOOP and request a calibration IF fixation is still
        % required and the fixation is not in the target area ...
        if td.fixReq == 1 && firstInsideFixLoc == 0
            % 1. td.fixBrokenCntr has exceeded fixBrokenMax.
            if td.fixBrokenCntr >= visual.fixBrokenMax
                disp([num2str(GetSecs), ' fixBrokenMax reached --> exiting Trial ', num2str(td.trialCntr)]);
                break
                % 2. a participant spends maxTimeWithoutFix after dot onset or after
                % last broken fixation without fixating the initial target
            elseif (isnan(td.fixBrokenTime) && GetSecs-td.fixaOn > visual.maxTimeWithoutFix) || ...
                    (~isnan(td.fixBrokenTime) && GetSecs-td.fixBrokenTime > visual.maxTimeWithoutFix)
                disp([num2str(GetSecs), ' maxTimeWithoutFix reached --> exiting Trial ', num2str(td.trialCntr)]);
                break
            end
        end
        
        % IMPORTANT: check whether the escape key was pressed
        [EscapeKeyPressed, t_EscapeKeyPressed] = checkTarPress(keys.EscapeFromExp);
        if EscapeKeyPressed == 1
            td.do_escape = 1;
            disp([num2str(t_EscapeKeyPressed), ' ESCAPE KEY has been pressed! Terminating now...']);
        end
        
    end % of fixation
    
% elseif setting.TEST == 2 && td.image_file_exists == 1 && td.do_escape == 0
%     % make sure that if in test, we can continue without passing the
%     % fixation control...
%     td.fixReq = 0;
end % of image exists


%% run presentation of stimulus
% pre-allocate the vector where we save the frames and their timing
td.t_flip_first = NaN;
td.t_all_frames = NaN(5, td.n_flips + 1); % one bigger for image?!
td.t_flip_last = NaN;
td.t_flip_image = NaN;
td.t_flip_first_video = NaN;
td.t_flip_secondim = NaN;
td.t_flip_secondimend = NaN;

% only present the image if it exists and the fixation was passed ! (and
% there was no escape key pressed during fixation)
if td.fixReq == 0 && td.image_file_exists == 1 && td.do_escape == 0
    
    % before we start, do a reference flip that removes the fixation dot
    td.t_flip_first = Screen('Flip', scr.main);
    if setting.TEST == 0
        Eyelink('message', 'EVENT_fixaOff');
    end
    t_flip = td.t_flip_first;
    disp([num2str(td.t_flip_first), ' Fixation off']);
    
    % now show image for 5secs!
    % Make the image into a texture
    % move before 
    % Draw the image to the screen
    Screen('DrawTexture', scr.main, imageTexture, [],  td.video_dest_rect);
    Screen('DrawingFinished', scr.main); 
    % Prepare the trigger sequence which we will later synchronize with
    % the refresh:
    if setting.Pixx == 2
        Datapixx('SetDoutSchedule', 0, [sampleDur, 3], samplesPerTrigger, ...
            bufferAddress, samplesPerTrigger);
        Datapixx('StartDoutSchedule');
        
        % UVO: wait and collect samples for each frame; after that:
        Datapixx('RegWrVideoSync'); % Write the registry upon next refresh
    end

    td.t_flip_image = Screen('Flip', scr.main);
    % send eyelink message to communicate that the flip has just happened
    if setting.TEST == 0
        Eyelink('message', 'EVENT_image');
        Eyelink('message', 'EVENT_imageFlip_%s', num2str(t_flip));
    end


    % if we are in a video block, prepare video while image is shown
    % then play as soon as it is loaded and 5secs are over
    if td.video == 1 && td.do_escape == 0
        % open the movie
        if exist(td.moviename, 'file') % check whether the file exists
            td.video_file_exists = 1;
            t_reading_start = GetSecs;
            disp([num2str(t_reading_start), ' Reading: ', td.moviename]); 
            % read the video file
            v = VideoReader(td.moviename);
            all_frames = read(v, [1, 120]); %used to be 1, v.NumFrames % a 4-dim vector: width x height x rgb x frame_nr
            % save movie info
            td.moviedata = [v.Duration, v.FrameRate, v.Width, v.Height, v.NumFrames, v.BitsPerPixel, ...
                td.v_width, td.v_height];
            disp([num2str(GetSecs), ' moviedata: ', num2str(td.moviedata)]);
            % movie is prepared now
            t_reading_end = GetSecs;
            disp([num2str(GetSecs), ' Reading took ', num2str(round(t_reading_end-t_reading_start, 3)), ' secs.']);

            % we'll try to pre-load the textures of the movie
            disp([num2str(GetSecs), ' Pre-loading ', num2str(size(all_frames, 4)), ' frames now...']);
            t_preload_start = GetSecs;
            % all_frames_double = double(all_frames)./255;
            td.all_tex = NaN(2, size(all_frames, 4));
            for preload_i = 1:size(all_frames, 4)
                tex = Screen('MakeTexture', scr.main, ...
                    all_frames(:,:,:,preload_i), ... % provided that scene_image is type double
                    0, 2); % optimAngle=0, specialFlag=2, floatprecision=2 TODO: check special flag 4
                td.all_tex(1, preload_i) = tex;
                td.all_tex(2, preload_i) = preload_i;
            end
            t_preload_end = GetSecs;
            disp([num2str(GetSecs), ' Pre-loading took ', num2str(round(t_preload_end-t_preload_start, 3)), ' secs.']);

            % how many flips with what duration will we perform?
            td.frame_dur = 1/v.FrameRate;

        else % file does NOT exist, this should not happen!
            disp([num2str(GetSecs), td.moviename, ' DOES NOT EXIST!.']);
            td.video_file_exists = 0;
            warning([td.moviename, ' - video file does not exist!']);
        end
        
        % now: play the video!
        % Initial flip should be timed exactly after 5 sec, might be longer
        % depending on loading time...
        % MAYBE: instead of presSec --> (waitframes - 0.5) * ifi
        % Draw the image to the screen
        Screen('DrawTexture', scr.main, imageTexture, [],  td.video_dest_rect);
        Screen('DrawingFinished', scr.main); 
        td.t_flip_first_video  = Screen('Flip', scr.main, td.t_flip_image + identicalSecs - scr.fd*1/10); %  - scr.fd*5/6
        if setting.TEST == 0
            Eyelink('message', 'EVENT_imageEnd_videoStart');
        end
        disp([num2str(GetSecs), ' Image presentation time: ', num2str(round(td.t_flip_first_video- td.t_flip_image, 3)) ' secs.']);
    
        % Playback loop: Runs until last frame of movie disappears
        for frame_i = 1:td.n_flips

            % Draw the new texture immediately to screen, but only if there is
            % a movie frame left:
            if frame_i <= td.n_frames % Jasper: && frame_i > 1
                Screen('DrawTexture', scr.main, td.all_tex(1, frame_i), [], td.video_dest_rect);
                Screen('DrawingFinished', scr.main); 
            end

            % Prepare the trigger sequence which we will later synchronize with
            % the refresh:
            if setting.Pixx == 2
                Datapixx('SetDoutSchedule', 0, [sampleDur, 3], samplesPerTrigger, ...
                    bufferAddress, samplesPerTrigger);
                Datapixx('StartDoutSchedule');
            end

            % Wait and collect samples until we get close to the flip deadline
            t_flip_deadline = t_flip + td.frame_dur - scr.fd*5/6;
            while GetSecs < t_flip_deadline
                check_for_sample; % check for a sample
                WaitSecs(setting.eyelink_time_between_samples/4); % and wait
            end

            % once we get close to the deadline, synchronize with next refresh 
            % to fire the trigger. RegWrVideoSync will always react to the next
            % refresh, whether we perform a flip or not, that's why we waited for
            % the crucial refresh (i.e., when we perform the flip) to draw close.
            if setting.Pixx == 2
                Datapixx('RegWrVideoSync'); % Write the registry upon next refresh
                % Note that if RegWrRdVideoSync were used, then the command
                % would wait until the flip occurs (because it can only read
                % from the register when the refresh has occurred). 
            end

            % Update display upon next refresh:
            t_flip = Screen('Flip', scr.main, t_flip_deadline);

            % send eyelink message to communicate that the flip has just happened
            if setting.TEST == 0
                Eyelink('message', 'EVENT_videoFrame_%d', frame_i);
%                 if frame_i == 1 % the very first flip - video starts here
%                     Eyelink('message', 'EVENT_imageEnd_videoStart');
                if frame_i > td.n_frames
                    Eyelink('message', 'EVENT_videoEnd');
                end
                Eyelink('message', 'EVENT_videoFlip_%s', num2str(t_flip));
            end
    %         disp([num2str(t_flip), ' frame_i=', num2str(frame_i)]); % uncomment, this is expensive

            % update the frame counter
            if frame_i <= td.n_frames % movie frames
                td.t_all_frames(:, frame_i) = [frame_i; td.all_tex(2, frame_i); td.all_tex(1, frame_i); ...
                    t_flip; t_flip-td.t_flip_first];
            else % black screen after last movie frame
                td.t_flip_last = t_flip;
                td.t_all_frames(:, frame_i) = [frame_i; NaN; NaN; ...
                    td.t_flip_last; td.t_flip_last-td.t_flip_first];
            end
        end
    disp([num2str(td.t_flip_last), ' Movie played']);
    
    else
        Screen('DrawTexture', scr.main, imageTexture, [],  td.video_dest_rect);
        Screen('DrawingFinished', scr.main); 
        td.t_flip_secondim = Screen('Flip', scr.main, td.t_flip_image + identicalSecs - scr.fd*1/10);
        % send eyelink message to communicate that the flip has just happened
        if setting.TEST == 0
            Eyelink('message', 'EVENT_imageEnd_imageStart');
            Eyelink('message', 'EVENT_imageFlip_%s', num2str(td.t_flip_secondim));
            % Eyelink('message', 'EVENT_imageFlip_%s', num2str(t_flip_secondim));
        end
        disp([num2str(GetSecs), ' Image presentation time: ', num2str(round(td.t_flip_secondim - td.t_flip_image, 3)) ' secs.']);
        td.t_flip_secondimend = Screen('Flip', scr.main, td.t_flip_secondim + identicalSecs - scr.fd*1/10);
        if setting.TEST == 0
            Eyelink('message', 'EVENT_secondImageEnd');
        end
        disp([num2str(GetSecs), ' Second image presentation time: ', num2str(round(td.t_flip_secondimend - td.t_flip_secondim, 3)) ' secs.']);        

    end % end of running through movie frames
    
end


%% post-processing
% find out how much time passed between flips
td.t_all_frames = [td.t_all_frames; [td.t_all_frames(4,1)-td.t_flip_first, diff(td.t_all_frames(4,:))]];
% determine whether any frame was dropped:
if ~isnan(td.t_flip_first) && ~isnan(td.t_flip_last) && ~isnan(td.frame_dur)
    td.dropped = any(td.t_all_frames(6,:) > td.frame_dur + scr.fd/2);
else
    td.dropped = NaN;
end
% prune the collected-samples vectors
if tframe==0 % this could occur if there is a problem with eye tracking or the video is not existent
    tframe = 1;
end
td.x = td.x(1:tframe);       % x coord
td.y = td.y(1:tframe);       % y coord of Eye link
td.t = td.t(1:tframe);       % eye link timestamp
td.t_eye = td.t_eye(1:tframe);   % eye link timestamp

% Close all frame textures:
%Screen('Close', td.all_tex(1, ~isnan(td.all_tex(1, :))));
% better: close all individually TODO: check!
Screen('Close')

% close all trigger sequences
if setting.Pixx == 2
    Datapixx('StopAllSchedules');
    Datapixx('RegWrRd');
    Datapixx('SetDoutValues', 0);
    Datapixx('RegWrRd');
end

% final wait
WaitSecs(scr.fd);

if setting.TEST == 0 % send message that the trial has ended
    Eyelink('message', 'TRIAL_End %d', td.trialCntr); % this message is crucial for parsing of the edf file!!!
end
disp([num2str(GetSecs), ' End trialCntr=', num2str(td.trialCntr)]);



end

