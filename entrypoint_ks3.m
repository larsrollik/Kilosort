% MATLAB entrypoint to kilosort3.0
%
% Expect variables:
%	overwrite = 0;
%	binary_file_dir = '';
%	output_folder = '';
%	temp_dir = '';
%	ks_dir = '';

% Redefine to cause exception if not exist
overwrite = overwrite;
ks_dir = ks_dir;
rootH = temp_dir;
rootZ = binary_file_dir;
rootY = output_folder;

spikesorting_results = fullfile(rootY, 'phy');
spikesorting_wh = fullfile(rootY, 'tmp');
spikesorting_tmp = fullfile(rootY, 'tmp');
mkdir(spikesorting_tmp)
mkdir(spikesorting_wh)
mkdir(spikesorting_results)

%%
pathToYourConfigFile = fullfile(ks_dir, 'configFiles');
config_file_name = 'configFile384_npx_3B2.m';
chanMapFile = 'neuropixPhase3B2_kilosortChanMap.mat'

%% general stuff
ops.trange    = [0 Inf]; % time range to sort
ops.NchanTOT  = 384; % total number of channels in your recording

run(fullfile(pathToYourConfigFile, 'configFile384.m'))
ops.fproc   = fullfile(rootH, 'temp_wh.dat'); % proc file on a fast SSD
ops.chanMap = fullfile(pathToYourConfigFile, chanMapFile);
%% this block runs all the steps of the algorithm
fprintf('Looking for data inside %s \n', rootZ)

% main parameter changes from Kilosort2 to v2.5
ops.sig        = 20;  % spatial smoothness constant for registration
ops.fshigh     = 300; % high-pass more aggresively
ops.nblocks    = 5; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option.

% main parameter changes from Kilosort2.5 to v3.0
ops.Th       = [9 9];

% is there a channel map file in this folder?
fs = dir(fullfile(rootZ, 'chan*.mat'));
if ~isempty(fs)
    ops.chanMap = fullfile(rootZ, fs(1).name);
end

% find the binary file
fs          = [dir(fullfile(rootZ, '*.bin')) dir(fullfile(rootZ, '*.dat'))];
ops.fbinary = fullfile(rootZ, fs(1).name);

disp('Preprocessing & datashift.')
rez                = preprocessDataSub(ops);
rez                = datashift2(rez, 1);

disp('Extracting spikes.')
[rez, st3, tF]     = extract_spikes(rez);

disp('Saving intermediate.')
save(fullfile(spikesorting_tmp, 'rez.mat'), 'rez')
save(fullfile(spikesorting_tmp, 'st3.mat'), 'st3')
save(fullfile(spikesorting_tmp, 'tF.mat'), 'tF')
save(fullfile(spikesorting_tmp, 'ops.mat'), 'ops')

disp('Learning.')
rez                = template_learning(rez, tF, st3);

disp('Sorting.')
[rez, st3, tF]     = trackAndSort(rez);

disp('Clustering.')
rez                = final_clustering(rez, tF, st3);

disp('Merging.')
rez                = find_merges(rez, 1);

disp('Saving.')
rezToPhy2(rez, spikesorting_results);

%% Backup whitening matrix
copyfile(fullfile(rootH, 'temp_wh.dat'), spikesorting_wh)

%% END
