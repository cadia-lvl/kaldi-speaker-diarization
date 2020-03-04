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

If the recording ID in utt2spk and reco2num_spk don't match then an error comes up during AHC. All the utterance IDs must be of the same length or it can cause errors in the rttm file.
