function runTrials(datFile, el)
% RUNTRIALS Summary of this function goes here
%   Detailed explanation goes here

global design setting data scr keys visual

design.nt = length(design.b)*design.tiB;      % number of trials for the current session

% QUITE CRUCIAL: this is our global trialCntr (unique trial identifier)
trialCntr = 0;

% ALSO QUITE CRUCIAL: terminate if there was an escape key pressed
setting.do_escape = 0; % is set to 1 if the escape key was pressed in runSingleTrial

% run through blocks
for b = setting.First:length(design.b)
 %%       
    % maybe a first calibration to start the block?
    if setting.TEST == 0
        KbReleaseWait;
        data.b(b).block_calib_result = doCalibration(el);
    else
        data.b(b).block_calib_result = [];
    end
    %implement info whether current trial is images or videos here
    if design.b(b).trial(1).video == 0 && setting.do_escape == 0
        if setting.Lang == 1 % --> english, 2 is german...
            blockInfoText = sprintf('Block %d:\nIn this block, we only show images\nPlease indicate whether block %d is:\n\n[IMAGES / VIDEOS]', b,b);
        else
            blockInfoText = sprintf('Block %d:\nIn diesem Block  zeigen wir nur Bilder\nBitte bestätige, woraus Block %d besteht:\n\n[BILDER / VIDEOS]', b,b);
        end
        DisplayFormattedTextOnScreen(blockInfoText, scr, scr.centerX, scr.centerY, 4); %%
        resp = 0;
        while ~resp
            resp = checkTarPress(keys.resLeft);
        end
%         DisplayFormattedTextOnScreen(sprintf('Loading image...'),scr, scr.centerX, scr.centerY, 3);
    elseif design.b(b).trial(1).video == 1 && setting.do_escape == 0
        if setting.Lang == 1 % --> 1 is english, 2 is german...
            blockInfoText = sprintf('Block %d:\nIn this block, we only show videos\nPlease indicate whether block %d is:\n\n[IMAGES / VIDEOS]', b,b);
        else
            blockInfoText = sprintf('Block %d:\nIn diesem Block zeigen wir nur Videos\nBitte bestätige, woraus Block %d besteht:\n\n[BILDER / VIDEOS]', b, b);
        end
        DisplayFormattedTextOnScreen(blockInfoText, scr, scr.centerX, scr.centerY, 4); %%
        resp = 0;
        while ~resp
            resp = checkTarPress(keys.resRight);
        end
%         DisplayFormattedTextOnScreen(sprintf('Loading frozen video...'),scr, scr.centerX, scr.centerY, 3);
    else
        break
    end
   
    % now go through the trials in this block
    block_done = 0;
    trial = 0;
    while block_done == 0 && setting.do_escape == 0
        % get next trial, provided there is a next trial
        trial = trial + 1;
        if trial <= length(design.b(b).trial)
            t = design.b(b).trial(trial); % t is the structure of the upcoming trial
            block_done = 0;
        else
            block_done = 1;
        end
        
        % is the block done? If not, then run next trial
        if block_done == 0
            % increase trial counter
            trialCntr = trialCntr + 1;
            % save trial specifics and block number
            t_now = t;
            t_now.block = b;
            t_now.trial = trial;
            t_now.trialCntr = trialCntr;
            
            % RUN THE TRIAL
            KbReleaseWait; % Wait until the keyboard is released (from previous response)
            
            
%             if design.b(b).trial(1).video == 0 && setting.do_escape == 0
%                 td = runSingleTrialImage(el, t_now);
%             else design.b(b).trial(1).video == 1 && setting.do_escape == 0
                td = runSingleTrial(el,t_now);
%             end
            
            % first, check whether the escape key was pressed:
            if td.do_escape == 1
                setting.do_escape = 1;
            end
            
            % perform a calibration, if fixation control not passed
            if setting.do_escape == 0 && td.fixReq == 1 % calibration required
                if setting.TEST == 0
                    WaitSecs(0.2); % make sure we released the button
                    KbReleaseWait;
                    td.calib_result = doCalibration(el);
                else
                    td.calib_result = [];
                end
                % we have to repeat trial! -> append again at the end
                % of the block!
                t.nr_iteration = t.nr_iteration + 1;
                design.b(b).trial(length(design.b(b).trial)+1) = t;
            else % no calibration required
                td.calib_result = [];
            end
            
            % ask question if needed, save the answer and rt
            if setting.do_escape == 0 && setting.TEST == 0 && td.fixReq == 0
                Eyelink('message', 'QUESTION_available %d', td.ask);
            end
            % note that this can only happen if fixation control was passed
            if setting.do_escape == 0 && strcmp(td.question, 'dont ask') == 0 && td.fixReq == 0
                td.t_question_on = ...
                    DisplayFormattedTextOnScreen(sprintf('%s\n\n%s%s%s', td.question, td.ans1, '   /   ', td.ans2), ...
                    scr, scr.centerX, scr.centerY, 3);
                % inform the eyelink
                if setting.TEST == 0 % do we need to send messages about the displayed question?
                    Eyelink('message', 'QUESTION_on');
                    Eyelink('message', 'QUESTION_phrase %s', td.question);
                    Eyelink('message', 'QUESTION_ans1 %s', td.ans1);
                    Eyelink('message', 'QUESTION_ans2 %s', td.ans2);
                    Eyelink('message', 'QUESTION_correctanswer %s', td.correct);
                end
                resp = 0;
                while ~resp
                    [resp, tRes] = checkTarPress(keys.respButtons);
                end
                if setting.TEST == 0 % inform the eyelink about the response and the time it was given
                    Eyelink('message', 'RESPONSE %d', resp);
                end
                
                td.resp = resp; %resp = 1 -> b/leftArrow ; 2 -> n/rightArrow
                td.t_resp = tRes; % time of response
                td.rt = tRes - td.t_question_on; %this will give us the time of the key press re the onset of the question
                td.rt_lastflip = tRes - td.t_flip_last; %this will give us the time of the key press re last flip
            else
                td.t_question_on = NaN;
                td.resp = NaN;
                td.t_resp = NaN;
                td.rt = NaN;
                td.rt_lastflip = NaN;
            end
            
            % remove text from screen
            Screen('Flip', scr.main);
            
            % Finally, and add to global results structure
            data.b(b).trial(trial) = td;
            
            % The safety net. We save all the data after each trial, in
            % case something goes wrong (which has happened a bit)
            safety_start = GetSecs;
            save(setting.matFile_sav, 'data', 'design', 'visual', 'scr', 'keys', 'setting', ...
                '-nocompression');
            safety_duration = GetSecs - safety_start;
            
        end
        
    end % of while block_done == 0
    
    % show feedback wait for the keypress to start the next one
    if setting.do_escape == 0 % block ended in a regular manner
        if setting.Lang == 1 % --> english, 2 is german...
            blockInfoText = sprintf('Block %d is done.\nReady to continue?\n\n[SPACEBAR]',b);
        else
            blockInfoText = sprintf('Block %d ist geschafft.\nBereit zum Weitermachen?\n\n[LEERZEICHEN]',b);
        end
        DisplayFormattedTextOnScreen(sprintf(blockInfoText, scr, scr.centerX, scr.centerY, 3);
        keyPress = 0;
        while ~keyPress
            [keyPress, tRes] = checkTarPress(keys.nextTrial);
        end
    else % escape key was pressed, that is, the block was interrupted
        break
    end
    
end % of loop over blocks


end

