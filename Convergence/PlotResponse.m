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
plot(time2,disp2,'b-')
plot(time1,disp1,'r--','LineWidth',2)
plot(time1(end),disp1(end),'k*')
legend('Recursive Bisection','Original','Failure Point')
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
plot(time2,disp2,'b-')
plot(time1,disp1,'r--','LineWidth',2)
plot(time1(end),disp1(end),'k*')
legend('Recursive Bisection','Original','Failure Point')

figure
title('Detail @ Scale Factor = 5.0')
xlabel('Time (sec)')
ylabel('X Disp (in)')
hold on
plot(time2,disp2,'bo-')
plot(time1,disp1,'ro--','LineWidth',2)
plot(time1(end),disp1(end),'k*','MarkerSize',12)
legend('Recursive Bisection','Original','Failure Point')
xlim([3.85 3.91])
ylim([4 7.5])



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
plot(time2,disp2,'b-')
plot(time1,disp1,'r--','LineWidth',2)
plot(time1(end),disp1(end),'k*')
plot(time2(end),disp2(end),'k*')
legend('Recursive Bisection','Original','Failure Points')


figure
title('Detail @ Collapse (Scale Factor = 10.0)')
xlabel('Time (sec)')
ylabel('X Disp (in)')
hold on
plot(time2,disp2,'bo-')
plot(time2(end),disp2(end),'k*','MarkerSize',12)
legend('Recursive Bisection','Failure Point')

xlim([8.205 8.245])
ylim([-21 -12])


