#! /bin/bash
# Author: Judy Fong - Reykjavik University
# made this by  cutting down the callhome_diarization v2 script
#SBATCH --nodelist=terra
#SBATCH -o logs/run-log.sout

stage=0
unsupervised=1

experiment=1
num_jobs=2

traindir=data/test$experiment
data_dir=data/test$experiment
mfccdir=${data_dir}/mfccs/
model_dir=models
nnet_dir=nnet_dir
exp_cmn_dir=exp/test$experiment/cmvn
data_cmn_dir=${data_dir}/cmvn
xvectors_dir=exp/test$experiment/xvectors
segmented_dir=${data_dir}/segmented
vaddir=${data_dir}/vad
mkdir -p $data_cmn_dir
mkdir -p $exp_cmn_dir
mkdir -p $model_dir

threshold=0.5

. ./cmd.sh
. ./path.sh
set -e

if [ ! -d "$model_dir/0006_callhome_diarization_v2_1a" ]; then
  echo -e "\nDownload pretrained models"
  wget --no-check-certificate -P $model_dir/ \
    http://kaldi-asr.org/models/6/0006_callhome_diarization_v2_1a.tar.gz
  tar -xvf $model_dir/0006_callhome_diarization_v2_1a.tar.gz -C $model_dir/
  #symbolically link nnet_dir to the exp dir within the callhome_diarization model archive
  ln -sfn "${model_dir}/0006_callhome_diarization_v2_1a/exp" nnet_dir
  ln -sfn "${model_dir}/0006_callhome_diarization_v2_1a/conf/" conf
fi

if [ -f $traindir/segments ]; then
    echo -e "Presegmented data exists so using that"
    if [ $stage -le 0 ]; then
        #train dir has wav.scp, segments file, and/or reco2num_spk, creating utt2spk
        awk '{print $1, $2}' $traindir/segments > $traindir/utt2spk
        srun utils/utt2spk_to_spk2utt.pl $traindir/utt2spk > $traindir/spk2utt
        #uncomment only if you have one audio file with 3 speakers
        #cat $traindir/segments | awk '{ print $2 " 3"}' | sort -u > $traindir/reco2num_spk

        #use fix_data_dir.sh
        utils/fix_data_dir.sh $traindir
        utils/validate_data_dir.sh --no-feats --no-text $traindir
    fi
    if [ $stage -le 1 ]; then
        echo -e "\nMake mfccs"
        mkdir -p exp/make_mfcc
        mkdir -p $mfccdir
        cp $data_dir/spk2utt exp/make_mfcc/spk2utt
        cp $data_dir/wav.scp exp/make_mfcc/wav.scp
    
        steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj ${num_jobs} \
         --cmd "$train_cmd" --write-utt2num-frames true \
         --write-utt2dur false \
         $data_dir exp/make_mfcc $mfccdir

        #use fix_data_dir.sh
        utils/fix_data_dir.sh $traindir
        utils/validate_data_dir.sh --no-feats --no-text $traindir
    fi
    if [ $stage -le 2 ]; then
        echo -e "\nPerform Cepstral mean and variance normalization(CMVN)"
        local/nnet3/xvector/prepare_feats.sh --nj ${num_jobs} --cmd \
         "$train_cmd" $data_dir $data_cmn_dir $exp_cmn_dir
    
        cp $data_dir/segments $data_cmn_dir/
        utils/fix_data_dir.sh $data_cmn_dir
        cp -r $data_cmn_dir $segmented_dir
    fi
else
    if [ $stage -le 0 ]; then
        #there is a wav.scp file, utt2spk, and reco2num_spk
        srun utils/utt2spk_to_spk2utt.pl $traindir/utt2spk > $traindir/spk2utt

        utils/fix_data_dir.sh $data_dir
    fi
    if [ $stage -le 1 ]; then
        echo -e "\nMake mfccs"
        mkdir -p exp/make_mfcc
        mkdir -p $mfccdir
        cp $data_dir/spk2utt exp/make_mfcc/spk2utt
        cp $data_dir/wav.scp exp/make_mfcc/wav.scp
    
        steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj ${num_jobs} \
         --cmd "$train_cmd" --write-utt2num-frames true \
         --write-utt2dur false \
         $data_dir exp/make_mfcc $mfccdir
        utils/fix_data_dir.sh $data_dir
    
        sid/compute_vad_decision.sh --nj ${num_jobs} --cmd "$train_cmd" \
            $data_dir exp/make_vad $vaddir
        utils/fix_data_dir.sh $data_dir
    fi
    if [ $stage -le 2 ]; then
        echo -e "\nPerform Cepstral mean and variance normalization(CMVN)"

        local/nnet3/xvector/prepare_feats.sh --nj ${num_jobs} --cmd \
         "$train_cmd" $data_dir $data_cmn_dir $exp_cmn_dir
        if [ -f $data_dir/vad.scp ]; then
          cp $data_dir/vad.scp $data_cmn_dir
        fi
        if [ -f $data_dir/segments ]; then
          cp $data_dir/segments $data_cmn_dir
        fi
        utils/fix_data_dir.sh $data_cmn_dir

        echo -e "\nCreate segments from energy based VAD"
        echo "0.01" > $data_cmn_dir/frame_shift
        diarization/vad_to_segments.sh --nj ${num_jobs} --cmd "$train_cmd" \
            $data_cmn_dir $segmented_dir
    fi
fi

if [ $stage -le 3 ]; then
    echo -e "\nExtract Embeddings/X-Vectors"
    cp $data_dir/feats.scp $data_cmn_dir/
    mkdir -p $xvectors_dir

    # NOTE each speaker can be split into at most 1 job
    # so jobs(nj) needs to be <= num_speakers
    diarization/nnet3/xvector/extract_xvectors.sh --cmd \
     "$train_cmd --mem 5G" \
     --nj ${num_jobs} --window 1.5 --period 0.75 --apply-cmn false \
     --min-segment 0.5 $nnet_dir/xvector_nnet_1a \
    $segmented_dir $xvectors_dir
    
fi
if [ $stage -le 4 ]; then
    echo -e "\nScore x-vectors with PLDA to check similarity"
    mkdir -p $xvectors_dir/plda_scores

   diarization/nnet3/xvector/score_plda.sh \
    --cmd "$train_cmd --mem 4G" --cleanup true \
    --target-energy 0.9 --nj ${num_jobs} $nnet_dir/xvector_nnet_1a/xvectors_callhome2 \
    $xvectors_dir $xvectors_dir/plda_scores 
fi
if [[ $stage -le 5 && $unsupervised -eq 1 ]]; then
    echo -e "\nUnsupervised AHC clustering"
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj ${num_jobs} \
     --threshold $threshold --rttm-channel 1 --cleanup true \
     $xvectors_dir/plda_scores \
     $xvectors_dir/plda_scores_unsupervised_speakers

    un_num_spk=$(cat ${xvectors_dir}/plda_scores_unsupervised_speakers/rttm | awk '{ print $8 }' | sort -ru | wc | awk '{ print $1 }')
    echo -e "\nThe unsupervised speakers estimate is $un_num_spk"
fi

if [ $stage -le 6 ]; then
    if [ -f $data_dir/reco2num_spk ]; then
        echo -e "\nsupervised AHC clustering"
        diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj ${num_jobs} \
         --reco2num-spk $data_dir/reco2num_spk --rttm-channel 1 --cleanup true \
         $xvectors_dir/plda_scores \
         $xvectors_dir/plda_scores_supervised_speakers

        s_num_spk=$(cat ${xvectors_dir}/plda_scores_supervised_speakers/rttm | awk '{ print $8 }' | sort -ru | wc | awk '{ print $1 }')
        echo -e "\nThe supervised speakers estimate is $s_num_spk"
    fi

fi

echo -e "\nThe run file has finished."
