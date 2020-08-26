#!/usr/bin/env bash
# Copyright 2020 Reykjavik University (Author: Judy Fong - judyfong@ru.is)
# Apache 2.0

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
cd ../

echo "Retrieve the md-eval file to check the accuracy of the diarization"
if [ ! -d "../dscore" ]; then
  cd ../
  git clone https://github.com/nryant/dscore dscore
  cd v4
fi
ln -sfn ../dscore/scorelib/md-eval-22.pl md-eval.pl

echo Done
