#!/bin/bash

. path.sh

echo Setting up symlinks
ln -sfn $KALDI_ROOT/egs/wsj/s5/steps steps
ln -sfn $KALDI_ROOT/egs/wsj/s5/utils utils
ln -sfn $KALDI_ROOT/egs/callhome_diarization/v1/diarization diarization
ln -sfn $KALDI_ROOT/egs/callhome_diarization/v1/local/ local
ln -sfn $KALDI_ROOT/egs/sre08/v1/sid/ sid

echo "Make logs dir"
mkdir -p logs

echo Done
