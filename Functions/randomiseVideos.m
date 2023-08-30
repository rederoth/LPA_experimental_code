function fileNames = randomiseVideos(vpcode)

fileList = dir('Videos/*.mp4');     %
fileList = fileList(arrayfun(@(x) ~isequal(x.name(1:2), '._'), fileList)); % removes the hidden macOS system-files
fileNames = string({(fileList(1:length(fileList)).name)}');
trials = randperm(length(fileNames));
fileNames = fileNames(trials);
names(1).session = fileNames(1:190);
names(2).session = fileNames(191:380);
save(sprintf('%s%s.mat',vpcode, 'fnames'),'names');



end