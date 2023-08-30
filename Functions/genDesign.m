 function design = genDesign(vpcode, session)
%GENDESIGN for one particular session 
% to do: we don't need blocks
global setting visual scr keys
load(sprintf('%s%s', vpcode(1:end-2), '_trialinfo.mat')); 

design.nBlocks = length(pinfo.session(session).block);                % number of blocks per session
design.iti = 0.200;                 % inter-trial interval [s] 
design.tiB = length(pinfo.session(session).block(setting.First).trial);                    % number of trials in block
design.blocksToDo = setting.First:design.nBlocks;
%design.nQuest = 40;                 % total number of questions
% 
% fileList = dir('Videos/*.mp4');     % read all the mp4 files from a folder
% 
% fileList = fileList(arrayfun(@(x) ~isequal(x.name(1:2), '._'), fileList)); % removes the hidden macOS system-files
% 
% fileNames = string({(fileList(1:length(fileList)).name)}');
% trials = randperm(length(fileNames));
% design.fileNames = fileNames(trials);
% idx = randperm(length(fileNames));
% design.questions = idx(1:design.nQuest);

%% Errors to fix:
% For some reason answers to questions in previous blocks get saved for
% coming blocks. Not sure if it's an issue. 

counter = 1;
for b = 1:length(design.blocksToDo)
    t = 0;
    for tiB = 1:design.tiB
        t = t+1;
        trial(t).fileName = pinfo.session(session).block(design.blocksToDo(b)).trial(t).fid;
        trial(t).video = pinfo.session(session).block(design.blocksToDo(b)).trial(t).video; %% added
        trial(t).ask = pinfo.session(session).block(design.blocksToDo(b)).trial(t).askQ;
        if trial(t).ask ==1
            trial(t).question = pinfo.session(session).block(design.blocksToDo(b)).trial(t).question;
            % trial(t).answers =  pinfo.session(session).block(design.blocksToDo(b)).trial(t).answers;
            trial(t).correct = pinfo.session(session).block(design.blocksToDo(b)).trial(t).correct;
            trial(t).ans1 = pinfo.session(session).block(design.blocksToDo(b)).trial(t).answer1;
            trial(t).ans2 = pinfo.session(session).block(design.blocksToDo(b)).trial(t).answer2;
        else
            trial(t).question = 'dont ask';
            % trial(t).answers = 0;
            trial(t).correct = 0;
            trial(t).ans1 = 0;
            trial(t).ans2 = 0;
        end
        % this is an iteration counter, which will be increased if trial is repeated:
        trial(t).nr_iteration = 1;
        
        counter = counter+1;
    end
    design.b(b).trial(1:t) = trial;
end

save(sprintf('%s.mat', vpcode),'design','visual','scr','keys','setting');


end

