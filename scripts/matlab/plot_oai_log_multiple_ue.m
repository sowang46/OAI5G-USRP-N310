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

%% Load
load('../0127_mac.mat')
timestamp = sn*0.5*0.001;
tp = double(rbSize.*nrOfSymbols.*12).*(mcs2rate(MCS)')*oh_coeff;
rnti = cellstr(rnti);
ue_list = unique(rnti);

%% Separate data with RNTI
per_ue_data = struct('rnti', {}, 'sn', {}, 'fn', {}, 'rbSize', {}, 'nrOfSymbols', {}, 'MCS', {});
for ii = 1:length(ue_list)
    % Song: Matlab string processing is stupid!
    per_ue_data(ii).rnti = ue_list(ii);
    ind = cell2mat(cellfun(@(x) strcmp(x, ue_list(ii)), rnti, 'UniformOutput', false));
    per_ue_data(ii).sn = sn(ind);
    per_ue_data(ii).fn = fn(ind);
    per_ue_data(ii).rbSize = rbSize(ind);
    per_ue_data(ii).nrOfSymbols = nrOfSymbols(ind);
    per_ue_data(ii).MCS = MCS(ind);
end

%% Combine multiple 
sn_c = unique(sn);  % c for combined
rbSize_c = zeros(length(sn_c), 1);
nrOfSymbols_c = zeros(length(sn_c), 1);
for ii = 1:length(sn)
    rbSize_c(sn_c==sn(ii)) = rbSize_c(sn_c==sn(ii))+rbSize(ii);
    nrOfSymbols_c(sn_c==sn(ii)) = nrOfSymbols_c(sn_c==sn(ii)) + nrOfSymbols(ii);
end

%% Plot
figure()
subplot(511)
