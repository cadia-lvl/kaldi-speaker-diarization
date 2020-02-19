# kaldi-speaker-diarization

This repository has speaker diarization recipes which work by copying them to the kaldi egs folder

## Recipe towardsdatascience - v1/

This recipe is based on [the speaker diarization guide at towardsdatascience.com](https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8) and [david's kaldi comment](https://github.com/kaldi-asr/kaldi/issues/2523#issuecomment-408935477). It also creates the data directory according to the data-prep instructions on the kaldi website.

The models within [the nnet_dir variable within run.sh](http://kaldi-asr.org/models/m3) are from the kaldi website. nnet_dir symbolicly links to the exp directory within the m3 archive.

The recipe assumes you already have a data/train dir with audio files, wav.scp, and segments.
It uses the files within data/train to create the remaining files needed for speaker diarization. The recipe scores through AHC to cluster speakers in an unsupervised manner.

## Recipe dihard_2018 - v2/

This recipe is based on the dihard_2018 v1 recipe but only uses the voxceleb1 dataset. This uses ivectors.
