# Templates

Templates for the various files which need to be prepared before creating diarization models. The rttm file is necessary for comparing oracle output with system output.

## segments
`<utterance-id> <recording-id> <start-time-in-seconds-and-milliseconds> <end-time-in-seconds-and-milliseconds>`

## utt2spk
`<utterance-id> <recording-id>`

## reco2num_spk
`<recording-id> <number-of-speakers>`

## wav.scp
`<recording-id> commands to use and alter the audio file <path-to-audio-file> |`

## rttm
`SPEAKER <recording-id> <channel> <start-time> <duration> <NA> <NA> <speaker-number> <NA> <NA>`

If the recording ID in utt2spk and reco2num_spk don't match then an error comes up during AHC. All the utterance IDs must be of the same length or it can cause errors in the rttm file. While the filename utt2spk implies it matches utterance ids to speaker ids, within diarization recipes it just matches utterance ids to recording ids. A better filename would be utt2reco but it's not since we're building on top of automatic speech recognition(ASR) tools.

## Examples

If you have a segments file then the files look somewhat like this:

**segments**
```
5004310T0_00001 5004310T0 0.100 0.220
5004310T0_00002 5004310T0 6.070 10.030
5004310T0_00003 5004310T0 10.030 13.900
```

**utt2spk**
```
5004310T0_00001 5004310T0
5004310T0_00002 5004310T0
5004310T0_00003 5004310T0
5011719T0_00001 5011719T0
```

**reco2num_spk**
```
5004310T0 21
5011719T0 4
```

**wav.scp**
```
5004310T0 sox -t wav - -c1 -esigned -r8000 -G -twav - < /data/audio/5004310T0.wav |
5011719T0 sox -t wav - -c1 -esigned -r8000 -G -twav - < /data/audio/5011719T0.wav |
```

**rttm**
```
SPEAKER 5004310T0 1   0.100   0.120 <NA> <NA> 18 <NA> <NA>
SPEAKER 5004310T0 1   6.070   6.585 <NA> <NA> 20 <NA> <NA>
SPEAKER 5004310T0 1  12.655   1.245 <NA> <NA> 17 <NA> <NA>
SPEAKER 5004310T0 1  13.900  16.160 <NA> <NA> 20 <NA> <NA>
```
--------------------------------------------------------------------------
If you don't have a segments file then the files look something like this:

**utt2spk**
```
5004310T0 5004310T0
5011719T0 5011719T0
```

**reco2num_spk**
```
5004310T0 21
5011719T0 4
```

**wav.scp**

```
5004310T0 sox -t wav - -c1 -esigned -r8000 -G -twav - < /data/audio/5004310T0.wav |
5011719T0 sox -t wav - -c1 -esigned -r8000 -G -twav - < /data/audio/5011719T0.wav |
```

**rttm**
```
SPEAKER 5004310T0 1   0.100   0.120 <NA> <NA> 18 <NA> <NA>
SPEAKER 5004310T0 1   6.070   6.585 <NA> <NA> 20 <NA> <NA>
SPEAKER 5004310T0 1  12.655   1.245 <NA> <NA> 17 <NA> <NA>
SPEAKER 5004310T0 1  13.900  16.160 <NA> <NA> 20 <NA> <NA>
```
