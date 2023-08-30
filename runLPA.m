%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Experiment: Exploration of static vs dynamic scenes   %
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%
% Based on UVO code by Olga Shurygina & Richard Schweitzer
% 2022 by Jasper McLaughlin & Nicolas Roth 
%
% Attention test - 2AFC questions after randomly assigned trials
%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%



clear all;
clear mex;
clear functions;

addpath('Functions/','Data/', 'Edf/', 'Stimuli/', 'QandA/');

home;
expStart=tic;
rng('shuffle'); % randomize random
global data setting visual scr keys design %#ok<*NUSED>

setting.exptname = 'LPA'; % p for pilot!
setting.TEST    = 0;        % test in dummy mode? 0=with eyelink; 1=mouse as eye; 2=no gaze position checking of any sort
setting.Pixx    = 2;        % ViewPixx screen [1], ProPixx+Datapixx [2], any pc [0]
% setting.Lang    = 2;   % Language of written instructions is an input question
setting.First   = 1;        % start from the first block or from block number [1-8]
setting.session = 1; %%
% video options
% setting.path_to_videos = 'C:\Users\jaspe\OneDrive\Documents\GitHub\LPA_study\Stimuli\';
% setting.path_to_videos = '/home/nico/project_code/LPA_study/Stimuli/'; %Nico
setting.path_to_videos = '/home/darklab-user/Documents/Projects/nico/LPA_study/Stimuli/';
setting.video_perc_of_screen = 0.8; % define the size of the video relative to the screen
% eyelink options
setting.calib_perc_of_screen = 0.7; % define the eccentricity of the calibration dots
setting.tracking_filter_mode = '1 1';
setting.eyelink_sampling_frequency = 1000;


try
    %% query subject code and trial balance
    newFile = 0;
    sca
    
    while ~newFile
        
        % in test mode, don't ask for inputs!
        if  setting.TEST > 0
            setting.vpcode_init = strcat(sprintf(strcat(setting.exptname,'%s'), 'tst_'), num2str(setting.First) );
            setting.vpcode = strcat('Data/', setting.vpcode_init);
            setting.Lang = 1;
            setting.matFile = sprintf('%s.mat', setting.vpcode);
            setting.matFile_sav = sprintf('%s_sav.mat', setting.vpcode);
            setting.datFile = sprintf('%s.dat', setting.vpcode);
            newFile = 1;
 
        else
            assert(setting.Pixx == 2, 'Use ProPixx+Datapixx if not in Test!');
            if setting.First ~= 1
                blocktest = input('>>>> You are starting NOT from the first block, is that intended? [y / n]? ','s');
                assert(blocktest=='y', 'Start new from the correct block!')
            end
            % ask for participant ID
            vpcode_init = getVpCode(setting.exptname);

            % this should be the experiment code LPA + ID + _ + block_start
            setting.vpcode_init = strcat(vpcode_init, '_', num2str(setting.First) );
            assert(length(setting.vpcode_init)==7, 'Something wrong with vpcode!');

            setting.vpcode = strcat('Data/', setting.vpcode_init);

            % ask for language
            setting.Lang = getLanguage(setting.vpcode_init);
            assert(setting.Lang==1 | setting.Lang==2, 'ERROR: Language must be 1 or 2!');

            % create data file
            setting.matFile = sprintf('%s.mat', setting.vpcode);
            setting.matFile_sav = sprintf('%s_sav.mat', setting.vpcode);
            setting.datFile = sprintf('%s.dat', setting.vpcode);
            if exist(setting.matFile, 'file')
                o = input('>>>> This file exists already. Should I overwrite it [y / n]? ','s');
                if strcmp(o,'y')
                    newFile = 1;
                end
            else
                newFile = 1;
            end
        end
    end
    disp(['Will write mat file: ', setting.matFile]);
    
    if setting.TEST > 0
        prepVideos(setting.vpcode)
        setting.eye_used = 0;
    else
        %% generate trial order
        if ~exist(sprintf('%s%s',setting.vpcode(1:end - 2), '_trialinfo.mat'), 'file')
            generate = input('>>>> Generate trial order? [y / n]? ','s');
            %If it's not the first take the fileorder from already generated file
            if strcmp(generate,'y')
                prepVideos(setting.vpcode)
            end
        end


        %% read participant's DOMINANT EYE
        % for fixation controls we need an eye to track. Normally one would use the
        % dominant eye for that, which can be specified here.
        % LEFT_EYE (0) and RIGHT_EYE (1) can be used to index eye data in the sample;
        % if the value is BINOCULAR (2) or unknown (-1) then we use the LEFT_EYE.
        % Query the dominant eye
        setting.eye_used = getEyeDom(setting.vpcode_init);
        assert(setting.eye_used==0 | setting.eye_used==1, 'ERROR: Dominant eye must be 0 or 1!');
         
    end
    
    %% get response keys
    getKeyAssignment;
    % disable keyboard
    % ListenChar(2);
    
    
    %% prepare screens and stimuli
    prepScreen;
    %path = pwd
    
    %% prepare design
    design = genDesign(setting.vpcode, setting.session);
    % initialize the resulting data structure
    data = [];
    
    %% setup eye tracker
    el = [];
    setting.eyelink_time_between_samples = 1/setting.eyelink_sampling_frequency;
    setting.is_recording = 0;
    if setting.TEST == 0
        disp([num2str(GetSecs) ' Eyelink will be set up.']);
        %
        [el, err] = initEyelink(setting.vpcode_init);
        if err==el.TERMINATE_KEY
            return
        end
        
%         % a first calibration? Can also be done when starting a new block.
%         data.first_calib_result = doCalibration(el);
        disp([num2str(GetSecs) ' Eyelink initialized.']);
    end
    
    %% run trials
    % @Olga, I made one important change, namely that all results data is
    % saved in the global structure 'data'. This has the advantage that
    % we have access to all the trial data if an error in runTrials should
    % occur and reddUp can access and save everything, also in case of
    % an error. 
    runTrials(setting.matFile, el);
    
    data.expDur = toc(expStart);
    
    %% shut down everything
    reddUp;
    disp([num2str(GetSecs) ' Experiment done. It took ', num2str(round(data.expDur/60, 2)), ' mins.']);
    
catch me
    rethrow(me);
    reddUp; %#ok<UNRCH>
end
