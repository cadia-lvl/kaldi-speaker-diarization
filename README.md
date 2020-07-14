# kaldi-speaker-diarization

This repository has speaker diarization recipes which work by copying them to the kaldi egs folder.
It is based off of this kaldi commit on Feb 5, 2020 : [321d3959dabf667ea73cc98881400614308ccbbb](https://github.com/kaldi-asr/kaldi/commit/321d3959dabf667ea73cc98881400614308ccbbb)

The DER is obtained using the [DIHARD 2018 script - md-eval-22.pl](https://github.com/nryant/dscore).

# Data prep

A data folder, perhaps data/train folder is required. Within is needed a wav.scp and the audio files should be in data. Audio files with a wav filetype is best but mp3s can be used if they're converted to wav during training.
[templates.md](https://github.com/cadia-lvl/kaldi-speaker-diarization/tree/master/templates.md)

## Recipe towardsdatascience - v1/

This recipe is based on [the speaker diarization guide at towardsdatascience.com](https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8) and [david's kaldi comment](https://github.com/kaldi-asr/kaldi/issues/2523#issuecomment-408935477). It also creates the data directory according to the data-prep instructions on the kaldi website.

The [models](http://kaldi-asr.org/models/m3) used are from the kaldi website.

The recipe assumes you already have a data/train dir with audio files, wav.scp, utt2spk, reco2num_spk, and/or segments.
It uses the files within data/test to create the remaining files needed for speaker diarization. The recipe uses MFCCs, CMVN, x-vectors, PLDA, and scores through AHC to cluster speakers in an unsupervised/supervised manner.

It performs best on clear speech. A more robust SAD is needed, like chime6, if there is music or other noise.

DER
---------------------------------------------------------------
|                 | default threshold (0.5) | oracle speakers |
|-----------------|-------------------------|-----------------|
| Ruvdi w/SAD     |       97.70%            |     33.91%      |
| Ruvdi           |       94.74%            |     28.63%      |
---------------------------------------------------------------

## Recipe dihard_2018 - v2/

This incomplete recipe is based on the dihard_2018 v1 recipe but only uses the voxceleb1 dataset. This uses ivectors, UBM, PLDA.

## Recipe callhome_diarizationv2 - v3/

This is the callhome_diarizationv2 recipe using the pretrained models on kaldi-asr.org. This is very similar to the v1 recipe but has much better results for separating voices from other signals.
Run setup.sh beforehand to setup the necessary directories or symbolic links.
`run.sh` expects data to be in data/test1/. It expects the following files: wav.scp, utt2spk(, segments, and reco2num_spk). The ones in parentheses are optional.

DER of each icelandic data we have (no unscored collars, includes overlapping data)
----------------------------------------------------------------------------
|            | default threshold (0.5) | oracle speakers | tuned threshold |
|------------|-------------------------|-----------------|-----------------|
| Teenage    |          71.72%         |     70.33%      |   100%(0.6)     |
| Ruvdiw/SAD |          31.77%         |     30.35%      |   N/A           |
| Ruvdi      |          29.89%         |     27.81%      |   N/A           |
| Ruvdi eval |          34.30%         |     30.45%      |   32.33%(0.6)   |
| ALL eval   |                         |                 |                 |
| ALL        |                         |                 |    N/A          |
----------------------------------------------------------------------------

## Recipe Ruv-di ivectors- v4/

This recipe is based on the Icelandic Ruv-di corpus. The corpus is currently not published yet. It uses MFCCs, i-Vectors, PLDA and AHC.
Run setup.sh beforehand to setup the necessary directories or symbolic links.

DER
-----------------------------------------------------------------------
|             | default threshold | oracle speakers | tuned threshold |
|-------------|-------------------|-----------------|-----------------|
| Teenage     |        N/A        |                 |                 |
| Ruvdi eval  |        N/A        |      43.78%     | 52.07%(-0.05)   |
| ALL  eval   |        N/A        |                 |                 |
-----------------------------------------------------------------------

## Recipe Ruv-di xvectors - v5/

This recipe is trained on the [Althingi Parliamentary Speech corpus on malfong.is](http://www.malfong.is/index.php?lang=en&pg=althingisraedur). The recipe uses the Icelandic Ruv-di corpus as two hold out sets. The corpus is currently not published yet. It uses MFCCS, xvectors, PLDA and AHC.
Run setup.sh beforehand to setup the necessary directories or symbolic links.

DER
|             | default threshold | oracle speakers | tuned threshold |
|-------------|-------------------|-----------------|-----------------|
| Teenage     |        N/A        |                 |                 |
| Ruvdi       |        N/A        |    **22.58%**   |   26.27%        |
| Ruvdi eval  |        N/A        |      24.31%     |   23.37%        |
| ALL  eval   |        N/A        |                 |                 |
