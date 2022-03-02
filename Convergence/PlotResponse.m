% Plot convergence problem area
close all

% Scale factor 1.0

% Old convergence routine
data1  = load('data1\1.0\disp.out');
time1 = data1(:,1); % Psuedo time of analysis
disp1 = data1(:,2); % Node 3, dof 1
% New convergence routine
data2  = load('data2\1.0\disp.out');
time2 = data2(:,1); % Psuedo time of analysis
disp2 = data2(:,2); % Node 3, dof 1

figure
title('Scale factor = 1.0')
xlabel('Time (sec)')
ylabel('X Disp (in)')
hold on
plot(time2,disp2)
plot(time1,disp1)
plot(time1(end),disp1(end),'sk')
legend('Recursive Bisection','Original')

% Scale factor 5.0

% Old convergence routine
data1  = load('data1\5.0\disp.out');
time1 = data1(:,1); % Psuedo time of analysis
disp1 = data1(:,2); % Node 3, dof 1
% New convergence routine
data2  = load('data2\5.0\disp.out');
time2 = data2(:,1); % Psuedo time of analysis
disp2 = data2(:,2); % Node 3, dof 1

figure
title('Scale factor = 5.0')
xlabel('Time (sec)')
ylabel('X Disp (in)')
hold on
plot(time2,disp2)
plot(time1,disp1)
plot(time1(end),disp1(end),'sk')
legend('Recursive Bisection','Original')


% Scale factor 10.0

% Old convergence routine
data1  = load('data1\10.0\disp.out');
time1 = data1(:,1); % Psuedo time of analysis
disp1 = data1(:,2); % Node 3, dof 1
% New convergence routine
data2  = load('data2\10.0\disp.out');
time2 = data2(:,1); % Psuedo time of analysis
disp2 = data2(:,2); % Node 3, dof 1

figure
title('Scale factor = 10.0')
xlabel('Time (sec)')
ylabel('X Disp (in)')
hold on
plot(time2,disp2)
plot(time1,disp1)
plot(time1(end),disp1(end),'sk')
legend('Recursive Bisection','Original')


