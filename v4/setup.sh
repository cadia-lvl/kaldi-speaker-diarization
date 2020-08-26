#!/bin/bash

. path.sh

echo Setting up symlinks
ln -sfn $KALDI_ROOT/egs/wsj/s5/steps steps
ln -sfn $KALDI_ROOT/egs/wsj/s5/utils utils
ln -sfn $KALDI_ROOT/egs/callhome_diarization/v1/diarization diarization
ln -sfn $KALDI_ROOT/egs/sre08/v1/sid/ sid

echo "Make logs dir"
mkdir -p logs
mkdir -p data
mkdir -p exp
mkdir -p mfcc
mkdir -p local
cd local
ln -sfn $KALDI_ROOT/egs/dihard_2018/v1/local/prepare_feats.sh prepare_feats.sh

echo Done
