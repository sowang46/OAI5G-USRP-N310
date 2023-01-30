clear;clc
close all

mcs2rate = [2*120;      % 38.214 - Table 5.1.3.1-2
            2*193;
            2*308;
            2*449;
            2*602;
            4*378;
            4*434;
            4*490;
            4*553;
            4*616;
            4*658;
            6*466;
            6*517;
            6*567;
            6*616;
            6*666;
            6*719;
            6*772;
            6*822;
            6*873;
            8*682.5;
            8*711;
            8*754;
            8*797;
            8*841;
            8*885;
            8*916.5;
            8*948]/1024;
oh_coeff = 1-0.14;

load('../0118_debug_log_1_mac.mat')
timestamp = sn*0.5*0.001;
tp = double(rbSize.*nrOfSymbols.*12).*(mcs2rate(MCS)')*oh_coeff;

figure()
subplot(511)
plot(timestamp, MCS, 'LineWidth', 2)
ylim([0 Inf])
xlabel('Time (s)')
ylabel('MCS')
set(gca, 'FontSize', 12)
grid on

subplot(512)
plot(timestamp, smoothdata(rbSize, 'movmedian',100), 'LineWidth', 2)
ylim([0 110])
xlabel('Time (s)')
ylabel('# PRBs')
set(gca, 'FontSize', 12)
grid on

subplot(515)
bar(sn, nrOfSymbols);
ylim([0 15])
xlim([100230 100270])
xlabel('Slot')
ylabel('# Symbols used for DL')
set(gca, 'FontSize', 12)
grid on

subplot(513)
plot(timestamp, smoothdata(tp/0.5/0.001/1e6, 'movmedian',100), 'LineWidth', 2)
xlabel('Time (s)')
ylabel('PRB tp (Mbps)')
set(gca, 'FontSize', 12)
grid on

load('../0118_debug_log_1_rlc.mat')
timestamp = sn*0.5*0.001;

subplot(514)
plot(timestamp, size/1e6*8, 'LineWidth', 2)
xlabel('Time (s)')
ylabel('RLC buffer size (bits)')
set(gca, 'FontSize', 12)
grid on

