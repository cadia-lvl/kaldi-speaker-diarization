#! /bin/bash
# Author: Judy Fong - Reykjavik University
# made this by following: https://towardsdatascience.com/speaker-diarization-with-kaldi-e30301b05cc8
# and bits of kaldi's data prep page
#SBATCH --nodelist=terra
#SBATCH -o log-run.sout

stage=0

traindir=data/train
data_dir=data/train
mfccdir=data/mfccs/
nnet_dir=nnet_dir
exp_cmn_dir=exp/cmvn
data_cmn_dir=data/cmvn
xvectors_dir=exp/xvectors
mkdir -p $data_cmn_dir
mkdir -p $exp_cmn_dir

threshold=0.5

. ./cmd.sh
. ./path.sh

if [ $stage -le 0 ]; then
    #have wav.scp, segments file, utt2spk
    
    awk -F'[- ]' '{print $1 "-" $2, $1}' $traindir/segments > $traindir/utt2spk
    
    srun utils/utt2spk_to_spk2utt.pl $traindir/utt2spk > $traindir/spk2utt
    
    utils/validate_data_dir.sh --no-feats $traindir
    
    #use fix_data_dir.sh
    utils/fix_data_dir.sh $traindir

fi

if [ $stage -le 1 ]; then
    echo -e "\nMake mfccs"
    mkdir -p exp/make_mfcc
    mkdir -p $mfccdir
    cp $data_dir/spk2utt exp/make_mfcc/spk2utt
    cp $data_dir/wav.scp exp/make_mfcc/wav.scp

    steps/make_mfcc.sh --mfcc-config conf/mfcc.conf --nj 10 \
     --cmd "$train_cmd" --write-utt2num-frames true \
     --write-utt2dur false \
     $data_dir exp/make_mfcc $mfccdir

fi
if [ $stage -le 2 ]; then
    echo -e "\nPerform Cepstral mean and variance normalization(CMVN)"

    local/nnet3/xvector/prepare_feats.sh --nj 10 --cmd \
     "$train_cmd" $data_dir $data_cmn_dir $exp_cmn_dir

    cp $data_dir/segments $data_cmn_dir/
    utils/fix_data_dir.sh $data_cmn_dir
fi
if [ $stage -le 3 ]; then
    echo -e "\nExtract Embeddings/X-Vectors"
    cp $data_dir/feats.scp $data_cmn_dir/
    mkdir -p $xvectors_dir

    #NOTE nj is 1 because currently only giving it one speaker
    #each speaker can be split into at most 1 job
    #so jobs needs to be <= num_speakers
    diarization/nnet3/xvector/extract_xvectors.sh --cmd \
     "$train_cmd --mem 5G" \
     --nj 10 --window 1.5 --period 0.75 --apply-cmn false \
     --min-segment 0.5 $nnet_dir/xvector_nnet_1a \
    $data_cmn_dir $xvectors_dir
    
fi
if [ $stage -le 4 ]; then
    echo -e "\nScore x-vectors with PLDA to check similarity"
    mkdir -p $xvectors_dir/plda_scores

   diarization/nnet3/xvector/score_plda.sh \
    --cmd "$train_cmd --mem 4G" \
    --target-energy 0.9 --nj 20 $nnet_dir/xvectors_sre_combined/ \
    $xvectors_dir $xvectors_dir/plda_scores 
fi
if [ $stage -le 5 ]; then
    echo -e "\nUnsupervised AHC clustering"
    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 20 \
     --threshold $threshold \
     $xvectors_dir/plda_scores \
     $xvectors_dir/plda_scores_unsupervised_speakers

fi
#TODO doesn't work because the reco2num_spk does not match, it actually wants utt2num_spk
#if [ $stage -le 6 ]; then
#    echo -e "\nsupervised AHC clustering"
#    diarization/cluster.sh --cmd "$train_cmd --mem 4G" --nj 20 \
#     --reco2num-spk $data_dir/reco2num_spk \
#     $xvectors_dir/plda_scores \
#     $xvectors_dir/plda_scores_supervised_speakers
#
#fi
if [ $stage -le 7 ]; then
    
    #s_num_spk=$(cat ${xvectors_dir}/plda_scores_supervised_speakers/rttm | awk '{ print $8 }' | sort -ru | head -1)
    un_num_spk=$(cat ${xvectors_dir}/plda_scores_unsupervised_speakers/rttm | awk '{ print $8 }' | sort -ru | head -1)
    #echo -e "\nThe estimated number of supervised speakers is $s_num_spk"
    echo -e "\nThe estimated number of unsupervised speakers is $un_num_spk"
fi


echo -e "\nThe run file has finished."
