% Plot IDA results
% Written by Alex Baker, 2021
clear
close all
% Plot results
results = readtable('results.csv');
gmNames = unique(results.gm);
n = length(gmNames);
gmResults = cell(n,1); % initialize
for i=1:n
    % Split the results into separate tables
    gmResults{i} = results(strcmpi(results.gm,gmNames{i}),2:end);
    % Filter for successful runs
    gmResults{i} = gmResults{i}(gmResults{i}.code == 0,:);
end
% Plot displacement
figure
hold on
for i = 1:n
    plot([0; gmResults{i}.disp],[0; gmResults{i}.factor])
end
legend(gmNames,'Interpreter','none')
xlabel('Peak displacement (in)')
ylabel('Scale factor')
xlim([0,10])
% Plot base shear
figure
hold on
for i = 1:n
    plot([0; gmResults{i}.shear],[0; gmResults{i}.factor])
end
legend(gmNames,'Interpreter','none')
xlabel('Base shear (kip)')
ylabel('Scale factor')
xlim([0,100])
