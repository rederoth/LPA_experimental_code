function prepVideos(vpcode)
% add fileName as a number// 
global setting
nsessions = 1;
nblocks = 8; % should be 8
ntrialsInBlock = 20; % should be 20
nq = round((nblocks*ntrialsInBlock)/5); % results in 20% chance of question!
nscenes = 80; % should be 80

if mod(nscenes,ntrialsInBlock) ~= 0 
    error("Dimensions have to match");
end 
% Depending on participant id assign the questions

% Olgas block randomization:
%allbalancies = [1 2 3 4 5 1 2 3 4 5];
%whichb = str2double(vpcode(11))+1
%bId = allbalancies(whichb)
%qindex = (bId*nq-(nq-1): bId*nq)

% set random seed based on participant code
seedFromID = sum(double(vpcode(1:end-2))) + 2; %+ 42; % 42 since then tst starts with video
rng(seedFromID);
disp(['Random seed for ', vpcode(1:end-2), ' results in ', num2str(seedFromID)]);


alldata = readtable('QandA/LPA_stimuli_table_short_final.csv'); 

switch setting.Lang
    case 1
        quest = 5;
    case 2
        quest = 6;
end

fileNames = alldata{[1:nscenes],2}; 

%% Excel sheet layout
% Change excel sheet order. Write all video types for a scene and then
% continue e.g. watering_f,watering_s,watering_m,bench_f,bench_s ...
%% Selection mechanism for randomization
% Every video gets an ID
% Create matrix with nblocks * ntrials dimensions, so in our test case 3x5
% Now for the selection mechanism:
% We need to group for either images or videos. For videos we want a mix of
% still and moving videos. However, we do not want to have the same videos
% playing twice. The output of the function simply needs to be the randOrd
% array. 

%Generating order
%Random seed implementieren für participant code

% j = 1; 
% for i = 1: nscenes
%     images(i) = j;
%     %Necessary for random selection
%     stillOrMove = [j+1,j+2];
%     select = randi(2);
%     videos(i) = stillOrMove(select);
%     j = j + 3;
% end

images = 1:nscenes;
videos = 1+nscenes: 2*nscenes;

%Now we randomize the order of each array and put them together
randOrdImg = images(randperm(length(images))); 
randOrdVid = videos(randperm(length(videos)));
randOrd = [randOrdImg,randOrdVid];
%create matrix with blocks
randOrd = reshape(randOrd,[],nblocks);
%randomize blocks
randOrd = randOrd(:, randperm(size(randOrd, 2)));
% randOrd = reshape(randOrd(randperm(size(randOrd,1)),:),[],1);

%Reshape back to array
randOrd = reshape(randOrd,[],1);


%% Select questions
qindex = randsample(randOrd,nq);


%%
counter = 0;
for s = 1: nsessions
    for b = 1:nblocks 
        for t = 1:ntrialsInBlock
            counter = counter+1;
            % randomly select file, randOrd is designed such that in one block they all are >80/=<80
            randId = randOrd(counter); 
            if randId <= nscenes
                pinfo.session(s).block(b).trial(t).fid = sprintf('%s%s', fileNames{randId}, '.png');
                pinfo.session(s).block(b).trial(t).video = 0;     
            else
                randId = randId - nscenes; %% added because randId was previously inflated
                if randi(2) == 1
                    pinfo.session(s).block(b).trial(t).fid = sprintf('%s%s', fileNames{randId}, '_m.mp4');
                else
                    pinfo.session(s).block(b).trial(t).fid = sprintf('%s%s', fileNames{randId}, '_s.mp4');
                end
                pinfo.session(s).block(b).trial(t).video = 1;   
            end
            % pinfo.session(s).block(b).trial(t).fid = sprintf('%s',randOrd{counter});
            pinfo.session(s).block(b).trial(t).question = alldata{randId,quest}{1}(1:find(alldata{randId,quest}{1} == '?'));
            responses = alldata{randId, quest}{1}(find(alldata{randId,quest}{1} == '[')+1:end-1);
            pinfo.session(s).block(b).trial(t).correct = responses(isstrprop(responses,'upper'));
            responses = upper(responses);
            resp1 = responses(find(responses == '/')+1:end);
            resp2 = responses(1:find(responses == '/')-1);
            % randomly shuffle which answer is first
            if round(rand) == 0
                pinfo.session(s).block(b).trial(t).answer1 = resp1;
                pinfo.session(s).block(b).trial(t).answer2 = resp2;
            else
                pinfo.session(s).block(b).trial(t).answer1 = resp2;
                pinfo.session(s).block(b).trial(t).answer2 = resp1;
            end

            % pinfo.session(s).block(b).trial(t).answers = upper(responses);%(alldata{randId, quest}{1}(find(alldata{randId,quest}{1} == '[')+1:end-1));
                %here we will store only the upper case answer

            if ismember(randId, qindex)
                    pinfo.session(s).block(b).trial(t).askQ = 1;
            else
                    pinfo.session(s).block(b).trial(t).askQ = 0;
            end
        end
        
    end
    
end

save(sprintf('%s%s', vpcode(1:end-2), '_trialinfo.mat'), 'pinfo')

end



