clear;
close;
clc;

plotAudioTask = true;
plotFrameTask = true;
plotSleepMsTask = true;


##fid = fopen('log.txt', 'r');
fid = fopen('~/.config/retroarch/logs/retroarch.log', 'r');
log = char(fread(fid, 'uchar')');
fid = fclose(fid);

# Cut off menu etc, leave only last RA instance in log file
retroarchInstances = regexp(log, '\[INFO\] RetroArch \d+\.\d+\.\d+');
targetInstance = retroarchInstances(length(retroarchInstances));
log = log(targetInstance:length(log));

sampleRate = str2double(cell2mat(regexp(log,
				'\[INFO\] \[Audio\]: Set audio input rate to: (\d+\.\d*) Hz.','tokens')));
bufferSize = str2double(cell2mat(regexp(log,
				'\[INFO\] \[ALSA\]: Buffer size: (\d+) frames','tokens')));

audioDrvSmpBatchCall = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: audio_driver_sample_batch\(\) called @ T=(\d+)',
						'tokens')))';
audioDrvSmpBatchReturn = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: audio_driver_sample_batch\(\) return @ T=(\d+)',
						'tokens')))';
# TODO audio single-sample call/return
videoDrvFrameCall = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: video_driver_frame\(\) called @ T=(\d+)',
						'tokens')))';
videoDrvFrameReturn = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: video_driver_frame\(\) return @ T=(\d+)',
						'tokens')))';
retroSleepMsCall = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: retro_sleep\(sleep_ms\) called @ T=(\d+)',
						'tokens')))';
retroSleepMsReturn = ...
				str2double(cell2mat(regexp(
						log,
						'\[INFO\] \[main\]: retro_sleep\(sleep_ms\) return @ T=(\d+)',
						'tokens')))';
# TODO other sleep calls/returns
audioBuffer = ...
				str2double(cell2mat(regexp(
								log,
								'\[INFO\] \[ALSA\]: (-?\d+) frames available, (-?\d+) frames delay @ T=(\d+)',
								'tokens')'));
audioBuffer = circshift(audioBuffer, [0, 1]);
# Detect xruns etc--set buffer fill to 0
audioBuffer(find(audioBuffer(:,2) < 0), 2) = 0;
audioBuffer(find(audioBuffer(:,2) > 1.5 * bufferSize), 2) = 0;
audioBuffer(find(audioBuffer(:,3) < 0), 3) = bufferSize;
audioBuffer(find(audioBuffer(:,3) > 1.5 * bufferSize), 3) = bufferSize;

epipe = ...
				str2double(cell2mat(regexp(
						log,
						'\[ERROR\] \[ALSA\]: snd_pcm_wait\(\) error -32 \(EPIPE\) @ T=(\d+)',
						'tokens')'));
# TODO other errors


t_i = min([
				audioDrvSmpBatchCall,
				audioDrvSmpBatchReturn,
				videoDrvFrameCall,
				videoDrvFrameReturn,
				retroSleepMsCall,
				retroSleepMsReturn,
				audioBuffer(:,1)]);
t_f = max([
				audioDrvSmpBatchCall,
				audioDrvSmpBatchReturn,
				videoDrvFrameCall,
				videoDrvFrameReturn,
				retroSleepMsCall,
				retroSleepMsReturn,
				audioBuffer(:,1)]);

### First event occurs at t=0
##audioDrvSmpBatchCall = (audioDrvSmpBatchCall - t0);
##audioDrvSmpBatchReturn = (audioDrvSmpBatchReturn - t0);
##videoDrvFrameCall = (videoDrvFrameCall - t0);
##videoDrvFrameReturn = (videoDrvFrameReturn - t0);
##retroSleepMsCall = (retroSleepMsCall - t0);
##retroSleepMsReturn = (retroSleepMsReturn - t0);
##audioBuffer(:,1) = (audioBuffer(:,1) - t0);
##epipe = (epipe - t0);

figure();
hold on;

printf("Plot audio buffer levels...\n");
plot(audioBuffer(:,1), audioBuffer(:,3), '.-b');

% Vertical lines for EPIPE errors
printf("Plot EPIPE errors...\n");
plot(
				[epipe';          epipe'],
				[linspace(0,0,length(epipe)); linspace(bufferSize,bufferSize,length(epipe))],
				'r--',
				'linewidth', 2);

% Blue boxes for audio task
if (plotAudioTask)
		printf("Plot audio task...\n");
		for i = 1:length(audioDrvSmpBatchCall)
				r = rectangle(
								'Position',
										[audioDrvSmpBatchCall(i),
										0,
										audioDrvSmpBatchReturn(i) - audioDrvSmpBatchCall(i),
										bufferSize],
								'FaceColor', [0.5, 0.5, 1]);
				set( get(r, 'children'), 'facealpha', 0.25);
				set( get(r, 'children'), 'edgealpha', 0);
		end
endif

% Red boxes for frame task
if (plotFrameTask)
		printf("Plot frame task...\n");
		for i = 1:length(videoDrvFrameCall)
				r = rectangle(
								'Position',
										[videoDrvFrameCall(i),
										0,
										videoDrvFrameReturn(i) - videoDrvFrameCall(i),
										bufferSize],
								'FaceColor', [1, 0.5, 0.5]);
				set( get(r, 'children'), 'facealpha', 0.25);
				set( get(r, 'children'), 'edgealpha', 0);
		end
endif

% Gray boxes for sleep task
if (plotSleepMsTask)
		printf("Plot sleep task...\n");
		for i = 1:length(retroSleepMsCall)
				r = rectangle(
								'Position',
										[retroSleepMsCall(i),
										0,
										retroSleepMsReturn(i) - retroSleepMsCall(i),
										bufferSize],
								'FaceColor', [0.5, 0.5, 0.5]);
				set( get(r, 'children'), 'facealpha', 0.25);
				set( get(r, 'children'), 'edgealpha', 0);
		end
endif

ylim([0, bufferSize]);
xlim([t_i, t_f])
xlabel('Time (us)');
ylabel('Audio buffer fill (frames)');
##set(gca, 'xminortick', 'on');
##set(gca, 'xminortickvalues', xLims(1):1:xLims(2));
printf("Done!\n");