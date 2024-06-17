# kaldi-speaker-diarization

This repository has speaker diarization recipes which work by git cloning them into the kaldi egs folder.
It is based off of this kaldi commit on Feb 5, 2020 : [321d3959dabf667ea73cc98881400614308ccbbb](https://github.com/kaldi-asr/kaldi/commit/321d3959dabf667ea73cc98881400614308ccbbb)

There are two types of recipes here: pre-trained (v1, v3, v5_decode) and train (v4 & v5) recipes.
The v5 pretrained models and their config files are available at repository.clarin.is: [https://repository.clarin.is/repository/xmlui/handle/20.500.12537/109](https://repository.clarin.is/repository/xmlui/handle/20.500.12537/109).
If you want the v4 pretrained models & their config files, please contact judy at lvl@judyyfong.xyz.

The DER is obtained using the [DIHARD 2018 script - md-eval-22.pl](https://github.com/nryant/dscore) which can also be installed and setup using kaldi/tools dependencies (sctk). All DERs within this README have no unscored collars and include overlapping speech.

# Data prep

A data folder, perhaps data/train, is required. The directory name varies by recipe. Within a wav.scp is needed which contains the path to the audio files. Audio files with a wav filetype is best but mp3s can be used if they're converted to single channel 8k wav. Audio files should have more than one speaker where the speech doesn't overlap too much.
Read [templates.md](https://github.com/cadia-lvl/kaldi-speaker-diarization/tree/master/templates.md) to make sure the required ids match up. It clears up some confusing filename conventions.

## Recipe towardsdatascience - v1/

This recipe is based on [the speaker diarization guide at towardsdatascience.com](https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8) and [david's kaldi comment](https://github.com/kaldi-asr/kaldi/issues/2523#issuecomment-408935477). It also creates the data directory according to the data-prep instructions on the kaldi website.

The [models](http://kaldi-asr.org/models/m3) used are from the kaldi website.

#### Minimum requirements
The recipe assumes you already have a data/train10 dir.

The directory needs these files to diarize an audio file:
* an audio file,
* wav.scp, and
* utt2spk.

#### Optional:
* reco2num_spk
* segments.
It uses the files within data/test to create the remaining files needed for speaker diarization. The recipe uses MFCCs, CMVN, x-vectors, PLDA, and scores through AHC to cluster speakers in an unsupervised/supervised manner.

It performs best on clear speech. A more robust SAD is needed, like chime6, if there is music or other noise.

DER
---------------------------------------------------------------
|                 | default threshold (0.5) | oracle speakers |
|-----------------|-------------------------|-----------------|
| Ruvdi w/SAD     |       97.70%            |     33.91%      |
| Ruvdi           |       94.74%            |     28.63%      |
---------------------------------------------------------------

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

This recipe is trained on the [Althingi Parliamentary Speech corpus on malfong.is](http://www.malfong.is/index.php?lang=en&pg=althingisraedur). The recipe uses the Icelandic Ruv-di corpus as two hold out sets. The Rúv-di corpus is currently not published yet. It uses MFCCS, xvectors, PLDA and AHC.
Run setup.sh beforehand to setup the necessary directories or symbolic links.

The v5 pretrained models and their config files are available at repository.clarin.is: [https://repository.clarin.is/repository/xmlui/handle/20.500.12537/109](https://repository.clarin.is/repository/xmlui/handle/20.500.12537/109).

DER
|             | default threshold | oracle speakers | tuned threshold |
|-------------|-------------------|-----------------|-----------------|
| Teenage     |        N/A        |                 |                 |
| Ruvdi       |        N/A        |    **22.58%**   |  26.27%         |
| Ruvdi eval  |        N/A        |      24.31%     |  23.37%(-0.05)  |
| ALL  eval   |        N/A        |                 |                 |

## Decoding Recipe Ruv-di xvectors - v5_decode/

This recipe uses the [pretained models](http://hdl.handle.net/20.500.12537/109) from ruv-di v5 and diarizes unseen audio files.

# References
```
 @misc{20.500.12537/109,
 title = {{R{\'U}V}-{DI} Speaker Diarization v5 models},
 author = {Fong, Judy Y and Gudnason, Jon},
 url = {http://hdl.handle.net/20.500.12537/109},
 note = {{CLARIN}-{IS}},
 copyright = {Creative Commons - Attribution 4.0 International ({CC} {BY} 4.0)},
 year = {2021} }
```
