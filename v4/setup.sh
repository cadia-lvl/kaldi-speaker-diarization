#!/bin/bash

. path.sh

echo Setting up symlinks
ln -sfn ../../wsj/s5/steps steps
ln -sfn ../../wsj/s5/utils utils
ln -sfn ../../callhome_diarization/v1/diarization diarization
ln -sfn ../../sre08/v1/sid/ sid

echo "Make logs dir"
mkdir -p logs
mkdir data
mkdir exp
mkdir mfcc
mkdir -p local
cd local
ln -sfn ../../../dihard_2018/v1/local/prepare_feats.sh prepare_feats.sh

echo Done
