function [question, answers] = getQandA(tbl, tid)

question = tbl{tid,11}{1}(1:find(tbl{tid,11}{1} == '?'));

answers = upper(tbl{tid,11}{1}(find(tbl{tid,11}{1} == '[')+1:end-1));



%[q, a] = [question, answers];
end