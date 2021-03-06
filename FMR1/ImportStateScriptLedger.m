%% Import data from text file
% Script for importing data from the following text file:
%
%    filename: F:\JayAndAudrey\log01-13-2020(15_36_00)AH6_3.stateScriptLog
%
% Auto-generated by MATLAB on 14-Jan-2020 10:20:42

%% Setup the Import Options and import the data
opts = delimitedTextImportOptions("NumVariables", 2);

% Specify range and delimiter
opts.DataLines = [2, Inf];
opts.Delimiter = "#";

% Specify column names and types
opts.VariableNames = ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"];
opts.VariableTypes = ["string", "string"];

% Specify file level properties
opts.ExtraColumnsRule = "ignore";
opts.EmptyLineRule = "read";

% Specify variable properties
opts = setvaropts(opts, ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"], "WhitespaceRule", "preserve");
opts = setvaropts(opts, ["VarName1", "W_Maze_variant_reward_middleRewardHeavy_use8sc"], "EmptyFieldRule", "auto");

%%

% Import the data
%myfilenames={'F:\JayAndAudrey\log01-13-2020(15_36_00)AH6_3.stateScriptLog'};
% or use dir

mydir=uigetdir;
%%

filelist = dir(fullfile(mydir, '**\*.*'));  %get list of files and folders in any subfolder
filelist = filelist(~[filelist.isdir]);

% now get the rat and date
for i=1:length(filelist)
    filelist(i).rundate=filelist(i).folder(find(filelist(i).folder=='\',1,'last')+1:end);
    filelist(i).ratname=filelist(i).name(strfind(filelist(i).name,'AH'):...
        find(filelist(i).name=='_',1,'last')-1);
    filelist(i).sessnum=filelist(i).name(find(filelist(i).name=='_',1,'last')+1:...
        strfind(filelist(i).name,'.')-1);
    filelist(i).datenum=datenum(filelist(i).rundate);
end

% now sort, first by session, then by date then by rat, this will make rat
% the top sorting category


% we can interchange tables and structs easily
ratinfo=sortrows(struct2table(filelist),{'ratname','datenum','sessnum'});

% now for ease here im going to put it into a struct
ratinfo=table2struct(ratinfo);

verbose=0;
%%
for i=1:length(ratinfo)
    fprintf(' \n \n');
    fprintf('Running  %s %s sess %s \n',ratinfo(i).rundate, ratinfo(i).ratname, num2str(ratinfo(i).sessnum));
    DataFile = readtable(fullfile(ratinfo(i).folder,ratinfo(i).name), opts);
    % Convert to output type
    DataTips = table2cell(DataFile);
    numIdx = cellfun(@(x) ~isempty(x{1}), DataTips(:,1));
    DataTips = DataTips(numIdx,1);
    
    % convert to char and split out
    DataTips2=cellfun(@(a) char(a{1}), DataTips, 'UniformOutput',false);
    DataAll=cellfun(@(a) a(1:find(a==' ',1,'first')), DataTips2,'UniformOutput',false);
    DataAll(:,2)=cellfun(@(a) a(find(a==' ',1,'first')+1:end), DataTips2,'UniformOutput',false);
    
    ledger=DataAll;
    [myevents,eventlist] = parseTrodesEvents(ledger);
    
    
    % now turn into real time
    
    % it looks like any event in which the next start is less than 1 seconds
    % from the last poke
    shortlag=2; % guess that the short lag is like 2 seconds

    % so every event that has a past event thats really recent, kill it,
    eventlags=diff(linearize(myevents(:,1:2)')); % get time lags between events
    returnevents=[1; diff(myevents(:,3))==0]; % add a zero (lets consider the first event as a return, its a freebie
    eventlags=[shortlag+1; eventlags(2:2:length(eventlags))]; % this is list of last end to this start
    shortlag=min(eventlags(returnevents==0)); % get min time for a real run
    realevents=myevents(eventlags>shortlag & ~returnevents,:); % kill all returns shorter than that
    realevents(:,5)=[nan; realevents(1:end-1,3)]; % this will underestimate returns
    
    armtrans=realevents(realevents(:,3)~=realevents(:,5),:); % basically whennever the animal switched arms
    if verbose
        % make a huge plot here
        % on left y maybe a moving average of total success rate
        figure;
        plot(movsum(armtrans(:,4),5)/5,'k');
        hold on;
        % show # rewards
       % yyaxis left;
        % now rewards per each side
        plot(cumsum(armtrans(:,4)==1 & armtrans(:,3)~=2)./cumsum(armtrans(:,3)~=2),'r'); % %%of center reawrds
        plot(cumsum(armtrans(:,4)==1 & armtrans(:,3)==2)./cumsum(armtrans(:,3)==2),'b'); % %%of center reawrds
        % how to calculate a 5 trial moving average of the events? prob nan
        % out middles? and then fill in after?
        
        
        plot((cumsum(armtrans(:,3)==3)-cumsum(armtrans(:,3)==1))./(1:size(armtrans,1))','k'); % side preference
        legend({'Performance','Side performance','Center Performance','Side preference'});

    end
    myevents(:,end+1)=i; armtrans(:,end+1)=i;
    ratinfo(i).samples=myevents;
    ratinfo(i).armvisits=armtrans;

    fprintf(' All rewards are %d, All visits are %d, Arm transitions are %.f%% of all %.2f second runs \n',...
        sum(realevents(:,4)==1), size(realevents,1), nanmean(realevents(:,3)~=realevents(:,5))*100,shortlag); % basically when the diff==0

    % when he leaves a side arm
    fprintf('NOT including return visits, %.f%% of %d Inbound visits \n',...
      nanmean(armtrans(armtrans(:,5)~=2,4)==1)*100, sum(armtrans(:,5)~=2));

    % when he leaves the center arm
    fprintf('NOT including return visits, %.f%% of %d Outbound visits \n',...
      nanmean(armtrans(armtrans(:,5)==2,4)==1)*100, sum(armtrans(:,5)==2));

end

%% and ask the date that the animals switched
switchdate='18-Feb-2020'; % for ah 1 and 2
%switchdate='22-Jan-2020'; % for ah3 and 6
 

for i=1:length(ratinfo)
    ratinfo(i).tasknum=(datenum(ratinfo(i).rundate)>=datenum(switchdate))+1;
end

%% and now we test these sessions

[rats,~,ratinds]=unique({ratinfo.ratname});
[tasks,~,taskinds]=unique(cell2mat({ratinfo.tasknum}));
for i=1:length(rats)
    for tk=1:max(tasks)
        
    fprintf('running rat %s \n',rats{i});
    alldays=cell2mat({ratinfo(ratinds==i & taskinds==tk).armvisits}');
    alldays(:,end+1)=1:size(alldays,1);
    sidevisits=alldays(alldays(:,5)==2,:); % leaving center
    centervisits=alldays(alldays(:,5)~=2,:); % e.g. him leaving the sides
    rightvisits=alldays(alldays(:,3)==1,:);
    leftvisits=alldays(alldays(:,3)==2,:);
    [~,~,alldays(:,6)]=unique(alldays(:,6)); % reorder the days
   
%     figure;
%     plot(centervisits(:,7),SmoothMat2(movsum(centervisits(:,4),10)/10,[1 30],3),'--.');
%     hold on;
%     plot(sidevisits(:,7),SmoothMat2(movsum(sidevisits(:,4),10)/10,[1 30],3),'--.');
%     plot([0 max([length(centervisits) max(sidevisits(:,7))])],[.5 .5],'r');
%     legend('Inbound performance','Outbound performance');
%     title(sprintf('10 trial moving average, %s ',rats{i}));
    %  now the statespace model
    figure;    sp=subplot(2,1,1); 
    [bmode,b05,b95,pmatrix,wintr] = CalcStateSpacePerformance(centervisits(:,4)', 0.5);

    % plot mode, confidence bounds, chance, and session marker
    plot(sp(1),centervisits(:,7)',bmode(1:end-1)); hold on; plot(sp(1),centervisits(:,7),b05(1:end-1),'r--');
    plot(sp(1),centervisits(:,7),b95(1:end-1),'r--'); plot(sp(1),[0 max(centervisits(:,7))],[.5 .5],'c');
    plot(sp(1),find(mod(alldays(:,6),2)==1),0.1*ones(sum(mod(alldays(:,6),2)==1),1),'b.');
    title(sprintf('%s learned task %d center at %d',rats{i},tk,centervisits(find(pmatrix<.025,1,'first'),7)));
    xlabel('trial'); ylabel('perf');
    sp(2)=subplot(2,1,2); 
    [bmode,b05,b95,pmatrix,wintr] = CalcStateSpacePerformance(sidevisits(:,4)', 0.5);
    plot(sp(2),sidevisits(:,7),bmode(1:end-1)); hold on; plot(sp(2),sidevisits(:,7),b05(1:end-1),'r--');
    plot(sp(2),sidevisits(:,7),b95(1:end-1),'r--'); plot(sp(2),[0 max(sidevisits(:,7))],[.5 .5],'c');
    plot(sp(2),find(mod(alldays(:,6),2)==1),0.1*ones(sum(mod(alldays(:,6),2)==1),1),'b.');
    title(sprintf('%s learned task %d side at %d',rats{i}, tk, sidevisits(find(pmatrix<.025,1,'first'),7)));
    xlabel('trial'); ylabel('perf');
    end
end
    
    
    

