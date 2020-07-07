#!/usr/bin/env bash
# Copyright 2020 Reykjavik University (Judy Fong - judyfong@ru.is)
# Apache 2.0.
#
# This script prepares one of the althingi data sets (train, dev, or eval) for
# diarization training.
# the new directory must have wav.scp and utt2spk


if [ $# -ne 3 ]; then
  echo "Usage: $0 <althingi-speech> <althingi-category> <out-data-dir>"
  echo "e.g.: $0 /mnt/data/althingi train data/"
  exit 1;
fi

set -e

data_type=$2
data_dir=$3
audio_src_dir=$1/data/audio
# example of path to train directory: data/malfong/train
text_src_dir=$1/data/malfong/${data_type}

tmp_dir=$data_dir/althingi_${data_type}/.tmp/
mkdir -p $tmp_dir

# reco.list is used to make wav.scp
awk '{ print $2 }' < $text_src_dir/segments | sort -u > $tmp_dir/reco.list
# make diarization specific utt2spk from the first two columns of segments
awk '{ print $2, $2 }' < $text_src_dir/segments | sort -u > $data_dir/althingi_${data_type}/utt2spk

# Create wav.scp file
count=0
missing=0
while IFS=$'-' read spk reco; do
  path=$(find $audio_src_dir/ -name "$reco.mp3")
  if [ -z "${path// }" ]; then
    >&2 echo "$0: Missing MP3 file for $reco"
    missing=$((missing+1))
  else
    echo "$spk-$reco sox -tmp3 - -c1 -esigned -r16000 -G -twav - < $path |"
  fi
  count=$((count+1))
done < $tmp_dir/reco.list > $data_dir/althingi_${data_type}/wav.scp 

if [ $missing -gt 0 ]; then
  echo "$0: Missing $missing out of $count recordings"
fi

utils/fix_data_dir.sh $data_dir/althingi_${data_type}

rm -rf $tmp_dir 2> /dev/null
