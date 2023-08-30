function language = getLanguage(vpcode)

pause(0.5);

FlushEvents('keyDown');
% read language
language = input(['>>>> Question Language (1 = English, 2 = German) of "' vpcode '"\n --> '], 's');
% check whether Language is any of the allowed values
if strcmp(language, '1') || strcmp(language, '2')
    language = str2num(language);
else
    disp(['Language was not specified or is not 1 or 2. Thus using ' num2str(2) ' as Language.']);
    language = 2;
end