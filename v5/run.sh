#!/usr/bin/env bash
# Copyright   2020 Reykjavik University (Author: Judy Fong - judyfong@ru.is)
# Apache 2.0
#
# See ../README.txt for more info on data required.
# Results (diarization error rate) are inline in comments below.
#SBATCH --output=logs/run_%J.out
#SBATCH --nodelist=terra
#SBATCH -c 5

. ./cmd.sh
. ./path.sh
set -e
mfccdir=`pwd`/mfcc
vaddir=`pwd`/mfcc

musan_root=/data/musan
rirs_root=RIRS_NOISES
ruvdi_root=data/corpus/
althingi_root=Althingi_Parliamentary_Speeches
num_jobs=5
stage=4
nnet_dir=exp/xvector_nnet_1a/
num_components=1024 # the number of UBM components (used for VB resegmentation)
ivector_dim=400 # also used for VB resegmentation
ivec_dir=exp/extractor_c${num_components}_i${ivector_dim}

if [ $stage -le 0 ]; then
  # Use only althingi train data 
  local/make_althingi.sh $althingi_root train data
  # TODO: then also add malromur2017, voxceleb, hlbs data for training
  # local/make_malromur2017.sh
  # local/make_hlbs.sh
  # local/make_voxceleb.sh
  # utils/combine_data.sh data/train data/althingi data/malromur2017 data/hlbs data/voxceleb

  # Prepare the Ruv-di data as ruv-di1 and ruv-di2 like the callhome_diarization recipes
  local/make_ruvdi.sh $ruvdi_root data

  utils/combine_data.sh data/train data/althingi_train
fi

# Prepare features
if [ $stage -le 1 ]; then
  # Make MFCCs for each dataset
  for name in train ruvdi1 ruvdi2; do
    steps/make_mfcc.sh --write-utt2num-frames true \
      --mfcc-config conf/mfcc.conf --nj ${num_jobs} --cmd "$train_cmd --max-jobs-run 20" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
  done

  # Compute the energy-based VAD
  for name in train ruvdi1 ruvdi2; do
    sid/compute_vad_decision.sh --nj ${num_jobs} --cmd "$train_cmd" \
      data/$name exp/make_vad $vaddir
    utils/fix_data_dir.sh data/$name
  done

  # This writes features to disk after adding deltas and applying the sliding window CMN.
  # Although this is somewhat wasteful in terms of disk space, for diarization
  # it ends up being preferable to performing the CMN in memory.  If the CMN
  # were performed in memory it would need to be performed after the subsegmentation,
  # which leads to poorer results.
  # TODO: make storage option for terra.hir.is for local/nnet3/xvector/
  # like how clsp.jhu.edu does
  for name in train ruvdi1 ruvdi2; do
    local/nnet3/xvector/prepare_feats.sh --nj ${num_jobs} --cmd "$train_cmd" \
      data/$name data/${name}_cmn exp/${name}_cmn
    if [ -f data/$name/vad.scp ]; then
      cp data/$name/vad.scp data/${name}_cmn/
    fi
    if [ -f data/$name/segments ]; then
      cp data/$name/segments data/${name}_cmn/
    fi
    utils/fix_data_dir.sh data/${name}_cmn
  done

  for name in train ruvdi1 ruvdi2; do
    echo "0.01" > data/${name}_cmn/frame_shift
  done
  # Create segments to extract x-vectors from for PLDA training data.
  # The segments are created using an energy-based speech activity
  # detection (SAD) system, but this is not necessary.  You can replace
  # this with segments computed from your favorite SAD.
  diarization/vad_to_segments.sh --nj ${num_jobs} --cmd "$train_cmd" \
      data/train_cmn data/train_cmn_segmented
fi

# Reverbing does not work with recordingids with multiple utteranceids.
# In this section, we augment the training data with reverberation,
# noise, music, and babble, and combine it with the clean data.
# The combined list will be used to train the xvector DNN then the PLDA model.
if [ $stage -le 2 ]; then
  frame_shift=0.01
  awk -v frame_shift=$frame_shift '{print $1, $2*frame_shift;}' data/train/utt2num_frames > data/train/reco2dur

  if [ ! -d "RIRS_NOISES" ]; then
    # Download the package that includes the real RIRs, simulated RIRs, isotropic noises and point-source noises
    wget --no-check-certificate http://www.openslr.org/resources/28/rirs_noises.zip
    unzip rirs_noises.zip
  fi

  # Make a version with reverberated speech
  rvb_opts=()
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/smallroom/rir_list")
  rvb_opts+=(--rir-set-parameters "0.5, RIRS_NOISES/simulated_rirs/mediumroom/rir_list")

  # Make a reverberated version of the training data.  Note that we don't add any
  # additive noise here.
  steps/data/reverberate_data_dir.py \
    "${rvb_opts[@]}" \
    --speech-rvb-probability 1 \
    --pointsource-noise-addition-probability 0 \
    --isotropic-noise-addition-probability 0 \
    --num-replications 1 \
    --source-sampling-rate 16000 \
    data/train data/train_reverb
  cp data/train/vad.scp data/train_reverb/
  utils/copy_data_dir.sh --utt-suffix "-reverb" data/train_reverb data/train_reverb.new
  rm -rf data/train_reverb
  mv data/train_reverb.new data/train_reverb

  # Prepare the MUSAN corpus, which consists of music, speech, and noise
  # suitable for augmentation.
  steps/data/make_musan.sh --sampling-rate 16000 $musan_root data

  # Get the duration of the MUSAN recordings.  This will be used by the
  # script augment_data_dir.py.
  for name in speech noise music; do
    utils/data/get_utt2dur.sh data/musan_${name}
    mv data/musan_${name}/utt2dur data/musan_${name}/reco2dur
  done

  # Augment with musan_noise
  steps/data/augment_data_dir.py --utt-suffix "noise" --fg-interval 1 --fg-snrs "15:10:5:0" --fg-noise-dir "data/musan_noise" data/train data/train_noise
  # Augment with musan_music
  steps/data/augment_data_dir.py --utt-suffix "music" --bg-snrs "15:10:8:5" --num-bg-noises "1" --bg-noise-dir "data/musan_music" data/train data/train_music
  # Augment with musan_speech
  steps/data/augment_data_dir.py --utt-suffix "babble" --bg-snrs "20:17:15:13" --num-bg-noises "3:4:5:6:7" --bg-noise-dir "data/musan_speech" data/train data/train_babble

  # Combine reverb, noise, music, and babble into one directory.
  utils/combine_data.sh data/train_aug data/train_reverb data/train_noise data/train_music data/train_babble

  # Take a random subset of the augmentations (12k is somewhat larger than twice
  # the size of the train list)
  utils/subset_data_dir.sh data/train_aug 12000 data/train_aug_12k
  utils/fix_data_dir.sh data/train_aug_12k

  # Make filterbanks for the augmented data.  Note that we do not compute a new
  # vad.scp file here.  Instead, we use the vad.scp from the clean version of
  # the list.
  steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 40 --cmd "$train_cmd" \
    data/train_aug_12k exp/make_mfcc $mfccdir

  # Combine the clean and augmented SWBD+SRE list.  This is now roughly
  # double the size of the original clean list.
  utils/combine_data.sh data/train_combined data/train_aug_12k data/train
fi

# Now we prepare the features to generate examples for xvector training.
if [ $stage -le 3 ]; then
  # This script applies CMN and removes nonspeech frames.  Note that this is somewhat
  # wasteful, as it roughly doubles the amount of training data on disk.  After
  # creating training examples, this can be removed.
  local/nnet3/xvector/prepare_feats_for_egs.sh --nj 40 --cmd "$train_cmd" \
    data/train_combined data/train_combined_cmn_no_sil exp/train_combined_cmn_no_sil
  utils/fix_data_dir.sh data/train_combined_cmn_no_sil

  # Now, we need to remove features that are too short after removing silence
  # frames.  We want atleast 5s (500 frames) per utterance.
  min_len=500
  mv data/train_combined_cmn_no_sil/utt2num_frames data/train_combined_cmn_no_sil/utt2num_frames.bak
  awk -v min_len=${min_len} '$2 > min_len {print $1, $2}' data/train_combined_cmn_no_sil/utt2num_frames.bak > data/train_combined_cmn_no_sil/utt2num_frames
  utils/filter_scp.pl data/train_combined_cmn_no_sil/utt2num_frames data/train_combined_cmn_no_sil/utt2spk > data/train_combined_cmn_no_sil/utt2spk.new
  mv data/train_combined_cmn_no_sil/utt2spk.new data/train_combined_cmn_no_sil/utt2spk
  utils/fix_data_dir.sh data/train_combined_cmn_no_sil

  ## TODO: We also want several utterances per speaker. Now we'll throw out speakers
  ## with fewer than 8 utterances.
  #min_num_utts=8
  #awk '{print $1, NF-1}' data/train_combined_cmn_no_sil/spk2utt > data/train_combined_cmn_no_sil/spk2num
  #awk -v min_num_utts=${min_num_utts} '$2 >= min_num_utts {print $1, $2}' \
  #  data/train_combined_cmn_no_sil/spk2num | utils/filter_scp.pl - data/train_combined_cmn_no_sil/spk2utt \
  #  > data/train_combined_cmn_no_sil/spk2utt.new
  #mv data/train_combined_cmn_no_sil/spk2utt.new data/train_combined_cmn_no_sil/spk2utt
  #utils/spk2utt_to_utt2spk.pl data/train_combined_cmn_no_sil/spk2utt > data/train_combined_cmn_no_sil/utt2spk

  utils/filter_scp.pl data/train_combined_cmn_no_sil/utt2spk data/train_combined_cmn_no_sil/utt2num_frames > data/train_combined_cmn_no_sil/utt2num_frames.new
  mv data/train_combined_cmn_no_sil/utt2num_frames.new data/train_combined_cmn_no_sil/utt2num_frames

  # Now we're ready to create training examples.
  utils/fix_data_dir.sh data/train_combined_cmn_no_sil
fi

# run_xvector_1a.sh contains stages 4-6
local/nnet3/xvector/tuning/run_xvector_1a.sh --stage $stage --train-stage -1 \
  --data data/train_combined_cmn_no_sil --nnet-dir $nnet_dir \
  --egs-dir $nnet_dir/egs

# Extract x-vectors
if [ $stage -le 7 ]; then
  echo -e "Extract x-vectors for the two partitions of ruv-di."
  diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 5G" \
    --nj 40 --window 1.5 --period 0.75 --apply-cmn false \
    --min-segment 0.5 $nnet_dir \
    data/ruvdi1_cmn $nnet_dir/xvectors_ruvdi1

  diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 5G" \
    --nj 40 --window 1.5 --period 0.75 --apply-cmn false \
    --min-segment 0.5 $nnet_dir \
    data/ruvdi2_cmn $nnet_dir/xvectors_ruvdi2

  # Reduce the amount of training data for the PLDA,
  utils/subset_data_dir.sh data/train_cmn_segmented 128000 data/train_cmn_segmented_128k
  # Extract x-vectors for the train subset, which is our PLDA training
  # data.  A long period is used here so that we don't compute too
  # many x-vectors for each recording.
  diarization/nnet3/xvector/extract_xvectors.sh --cmd "$train_cmd --mem 10G" \
    --nj 40 --window 3.0 --period 10.0 --min-segment 1.5 --apply-cmn false \
    --hard-min true $nnet_dir \
    data/train_cmn_segmented_128k $nnet_dir/xvectors_train_segmented_128k
fi
