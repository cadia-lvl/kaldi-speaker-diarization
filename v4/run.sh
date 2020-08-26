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

ruvdi_root=data/corpus
num_jobs=3
num_components=2048
ivector_dim=400
ivec_dir=exp/extractor_c${num_components}_i${ivector_dim}


stage=0

if [ $stage -le 0 ]; then
  # Now prepare the Ruv-di data: train 70i%, dev 15%, and eval 15%.  
  local/make_ruvdi.sh $ruvdi_root data

  utils/combine_data.sh data/train data/ruvdi1
  utils/combine_data.sh data/ruvdi_dev data/ruvdi2
  cp data/ruvdi2/reco2num_spk data/ruvdi_dev/
  cp data/ruvdi2/rttm data/ruvdi_dev/
  utils/combine_data.sh data/ruvdi_eval data/ruvdi3
  cp data/ruvdi3/reco2num_spk data/ruvdi_eval/
  cp data/ruvdi3/rttm data/ruvdi_eval/
fi

if [ $stage -le 1 ]; then
  # Make MFCCs for each dataset
  for name in train ruvdi_dev ruvdi_eval; do
    steps/make_mfcc.sh --write-utt2num-frames true \
      --mfcc-config conf/mfcc.conf --nj ${num_jobs} --cmd "$train_cmd --max-jobs-run 20" \
      data/${name} exp/make_mfcc $mfccdir
    utils/fix_data_dir.sh data/${name}
  done
fi
if [ $stage -le 2 ]; then

  # Compute the energy-based VAD
  for name in train ruvdi_dev ruvdi_eval; do
    sid/compute_vad_decision.sh --nj ${num_jobs} --cmd "$train_cmd" \
      data/$name exp/make_vad $vaddir
    utils/fix_data_dir.sh data/$name
  done

  # This writes features to disk after adding deltas and applying the sliding window CMN.
  # Although this is somewhat wasteful in terms of disk space, for diarization
  # it ends up being preferable to performing the CMN in memory.  If the CMN
  # were performed in memory it would need to be performed after the subsegmentation,
  # which leads to poorer results.
  for name in train ruvdi_dev ruvdi_eval; do
    local/prepare_feats.sh --nj ${num_jobs} --cmd "$train_cmd" \
      data/$name data/${name}_cmn exp/${name}_cmn
    if [ -f data/$name/vad.scp ]; then
      cp data/$name/vad.scp data/${name}_cmn/
    fi
    if [ -f data/$name/segments ]; then
      cp data/$name/segments data/${name}_cmn/
    fi
    utils/fix_data_dir.sh data/${name}_cmn
  done

  echo "0.01" > data/train_cmn/frame_shift
  # Create segments to extract i-vectors from for PLDA training data.
  # The segments are created using an energy-based speech activity
  # detection (SAD) system, but this is not necessary.  You can replace
  # this with segments computed from your favorite SAD.
  for name in train; do
    diarization/vad_to_segments.sh --nj ${num_jobs} --cmd "$train_cmd" \
        data/${name}_cmn data/${name}_cmn_segmented
  done
fi

if [ $stage -le 3 ]; then
  # Train the UBM on Ruv-di train data
  # UBM - Universal Background Model
  sid/train_diag_ubm.sh --cmd "$train_cmd --mem 4G" \
    --nj ${num_jobs} --num-threads 8 \
    data/train $num_components \
    exp/diag_ubm

  sid/train_full_ubm.sh --cmd "$train_cmd --mem 25G" \
    --nj ${num_jobs} --remove-low-count-gaussians false \
    data/train \
    exp/diag_ubm exp/full_ubm
fi

if [ $stage -le 4 ]; then
  # In this stage, we train the i-vector extractor on a subset of Ruv-di
  #
  # Note that there are well over 1 million utterances in our training set,
  # and it takes an extremely long time to train the extractor on all of this.
  # Also, most of those utterances are very short.  Short utterances are
  # harmful for training the i-vector extractor.  Therefore, to reduce the
  # training time and improve performance, we will only train on the 100k
  # longest utterances.
  # they trained on 100k, we're training on 900 so 60% of the data
  utils/subset_data_dir.sh \
    --utt-list <(sort -n -k 2 data/train/utt2num_frames | tail -n 900) \
    data/train data/train_900

  # Train the i-vector extractor.
  sid/train_ivector_extractor.sh --cmd "$train_cmd --mem 3G" \
    --ivector-dim $ivector_dim --num-iters 5 --nj 5 --num-processes 2\
    exp/full_ubm/final.ubm data/train_900 \
    $ivec_dir
fi

if [ $stage -le 5 ]; then
  # Fix and validate the subset
  utils/fix_data_dir.sh data/ruvdi_dev_cmn
  utils/validate_data_dir.sh --no-text data/ruvdi_dev_cmn

  # TODO Need to Extract i-vectors for evaluation set.
  # Extract i-vectors for Ruv-di development set.
  # We set apply-cmn false and apply-deltas false because we already add
  # deltas and apply cmn in stage 1.
  diarization/extract_ivectors.sh --cmd "$train_cmd --mem 20G" \
    --nj 3 --window 1.5 --period 0.75 --apply-cmn false --apply-deltas false \
    --min-segment 0.5 $ivec_dir \
    data/ruvdi_dev_cmn $ivec_dir/ivectors_dev

  diarization/extract_ivectors.sh --cmd "$train_cmd --mem 20G" \
    --nj 3 --window 1.5 --period 0.75 --apply-cmn false --apply-deltas false \
    --min-segment 0.5 $ivec_dir \
    data/ruvdi_eval_cmn $ivec_dir/ivectors_eval

  # Reduce the amount of training data for the PLDA training.
  utils/subset_data_dir.sh data/train_cmn_segmented 450 data/train_cmn_segmented_450

  # Fix and validate the subset
  utils/fix_data_dir.sh data/train_cmn_segmented_450
  utils/validate_data_dir.sh --no-text data/train_cmn_segmented_450

  # Extract i-vectors for Ruv-di train, which is our PLDA training
  # data.  A long period is used here so that we don't compute too
  # many i-vectors for each recording.
  diarization/extract_ivectors.sh --cmd "$train_cmd --mem 25G" \
    --nj ${num_jobs} --window 3.0 --period 10.0 --min-segment 1.5 --apply-cmn false --apply-deltas false \
    --hard-min true $ivec_dir \
    data/train_cmn_segmented_450 $ivec_dir/ivectors_train_segmented_450
fi

if [ $stage -le 6 ]; then
  echo -e "Train a PLDA model on Ruv-di train, using development set to whiten."
  "$train_cmd" $ivec_dir/ivectors_dev/log/plda.log \
    ivector-compute-plda ark:$ivec_dir/ivectors_train_segmented_450/spk2utt \
      "ark:ivector-subtract-global-mean \
      scp:$ivec_dir/ivectors_train_segmented_450/ivector.scp ark:- \
      | transform-vec $ivec_dir/ivectors_dev/transform.mat ark:- ark:- \
      | ivector-normalize-length ark:- ark:- |" \
    $ivec_dir/ivectors_dev/plda || exit 1;
fi

# Perform PLDA scoring
if [ $stage -le 7 ]; then
  # Perform PLDA scoring on all pairs of segments for each recording.
  diarization/score_plda.sh --cmd "$train_cmd --mem 4G" \
    --nj ${num_jobs} $ivec_dir/ivectors_dev $ivec_dir/ivectors_dev \
    $ivec_dir/ivectors_dev/plda_scores

  diarization/score_plda.sh --cmd "$train_cmd --mem 4G" \
    --nj ${num_jobs} $ivec_dir/ivectors_dev $ivec_dir/ivectors_eval \
    $ivec_dir/ivectors_eval/plda_scores
fi


# Cluster the PLDA scores using a stopping threshold.
if [ $stage -le 8 ]; then
  # First, we find the threshold that minimizes the DER on the Rúv-di development set.
  mkdir -p $ivec_dir/tuning
  echo "Tuning clustering threshold for Rúv-di development set"
  best_der=100
  best_threshold=0
  for dataset in ruvdi_dev ruvdi_eval; do
    utils/filter_scp.pl -f 2 data/$dataset/wav.scp \
      data/ruvdi/full_ref.rttm > data/$dataset/rttm
  done

  # The threshold is in terms of the log likelihood ratio provided by the
  # PLDA scores.  In a perfectly calibrated system, the threshold is 0.
  # In the following loop, we evaluate DER performance on Rúv-di development 
  # set using some reasonable thresholds for a well-calibrated system.
  for threshold in -0.5 -0.4 -0.3 -0.2 -0.1 -0.05 0 0.05 0.1 0.2 0.3 0.4 0.5; do
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 3 \
      --threshold $threshold --rttm-channel 1 $ivec_dir/ivectors_dev/plda_scores \
      $ivec_dir/ivectors_dev/plda_scores_t$threshold

    md-eval.pl -r data/ruvdi_dev/rttm \
     -s $ivec_dir/ivectors_dev/plda_scores_t$threshold/rttm \
     2> $ivec_dir/tuning/dev_t${threshold}.log \
     > $ivec_dir/tuning/dev_t${threshold}

    der=$(grep -oP 'DIARIZATION\ ERROR\ =\ \K[0-9]+([.][0-9]+)?' \
      $ivec_dir/tuning/dev_t${threshold})
    if [ $(perl -e "print ($der < $best_der ? 1 : 0);") -eq 1 ]; then
      best_der=$der
      echo "new $best_der"
      best_threshold=$threshold
      echo "new $best_threshold"
    fi
  done
  echo "$best_threshold" > $ivec_dir/tuning/dev_best

  diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 3 \
    --threshold $(cat $ivec_dir/tuning/dev_best) --rttm-channel 1 \
    $ivec_dir/ivectors_dev/plda_scores $ivec_dir/ivectors_dev/plda_scores

  # Cluster Rúv-di evaluation set using the best threshold found for the DIHARD 
  # 2018 development set. The Rúv-di development set is used as the validation 
  # set to tune the parameters. 
  diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 3 \
    --threshold $(cat $ivec_dir/tuning/dev_best) --rttm-channel 1 \
    $ivec_dir/ivectors_eval/plda_scores $ivec_dir/ivectors_eval/plda_scores

  mkdir -p $ivec_dir/results
  # Compute the DER on the Rúv-di evaluation set. We use the official metrics of   
  # the DIHARD challenge. The DER is calculated with no unscored collars and including  
  # overlapping speech.
  md-eval.pl -r data/ruvdi_eval/rttm \
    -s $ivec_dir/ivectors_eval/plda_scores/rttm 2> $ivec_dir/results/threshold.log \
    > $ivec_dir/results/DER_threshold.txt
  der=$(grep -oP 'DIARIZATION\ ERROR\ =\ \K[0-9]+([.][0-9]+)?' \
    $ivec_dir/results/DER_threshold.txt)
  # Using supervised calibration, DER: 28.51%
  echo "Using supervised calibration, DER: $der%"
fi

# Cluster the PLDA scores using the oracle number of speakers
if [ $stage -le 9 ]; then
  # In this section, we show how to do the clustering if the number of speakers
  # (and therefore, the number of clusters) per recording is known in advance.
  diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 3 \
    --reco2num-spk data/ruvdi_eval/reco2num_spk --rttm-channel 1 \
    $ivec_dir/ivectors_eval/plda_scores $ivec_dir/ivectors_eval/plda_scores_num_spk

  md-eval.pl -r data/ruvdi_eval/rttm \
    -s $ivec_dir/ivectors_eval/plda_scores_num_spk/rttm 2> $ivec_dir/results/num_spk.log \
    > $ivec_dir/results/DER_num_spk.txt
  der=$(grep -oP 'DIARIZATION\ ERROR\ =\ \K[0-9]+([.][0-9]+)?' \
    $ivec_dir/results/DER_num_spk.txt)
  # Using the oracle number of speakers, DER: 24.42%
  echo "Using the oracle number of speakers, DER: $der%"
fi
