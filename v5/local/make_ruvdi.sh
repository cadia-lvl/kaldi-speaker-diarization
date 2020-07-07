#!/usr/bin/env bash
# Copyright 2020 Reykjavik University (Judy Fong - judyfong@ru.is)
# Apache 2.0.
#
# This script prepares the Ruv-di src. It will split the corpus into 2 sets,
# which will work as the dev and eval sets for each other.

if [ $# -ne 2 ]; then
  echo "Usage: $0 <ruvdi-speech> <out-data-dir>"
  echo "e.g.: $0 /mnt/data/ruvdi data/"
  exit 1;
fi

src_dir=$1
data_dir=$2

tmp_dir=$data_dir/ruvdi/.tmp/
mkdir -p $tmp_dir

# Figure out the number of speakers per recording through the recording to
# speaker number to speaker label file
awk -F, '{ print $1 }' $src_dir/reco2spk_num2spk_label.csv | sort | uniq \
  -c | awk -F' ' '{ print $2, $1 }'> $tmp_dir/reco2num_spk
cp $tmp_dir/reco2num_spk $data_dir/ruvdi/

# The list of 23 recordings
awk '{print $1}' $tmp_dir/reco2num_spk > $tmp_dir/reco.list

# Create wav.scp file
count=0
missing=0
while read reco; do
  path=$(find $src_dir/wav/ -name "$reco.wav")
  if [ -z "${path// }" ]; then
    >&2 echo "$0: Missing WAV file for $reco"
    missing=$((missing+1))
  else
    echo "$reco sox -twav - -c1 -esigned -r16000 -G -twav - < $path |"
  fi
  count=$((count+1))
done < $tmp_dir/reco.list > $data_dir/ruvdi/wav.scp

if [ $missing -gt 0 ]; then
  echo "$0: Missing $missing out of $count recordings"
fi

cat $src_dir/segments/* > $tmp_dir/segments
cp $tmp_dir/segments $data_dir/ruvdi/
awk '{print $1, $2}' $data_dir/ruvdi/segments > $data_dir/ruvdi/utt2spk
utils/utt2spk_to_spk2utt.pl $data_dir/ruvdi/utt2spk > $data_dir/ruvdi/spk2utt
cp $tmp_dir/reco2num_spk $data_dir/ruvdi/
cat $src_dir/rttm/* > $data_dir/ruvdi/full_ref.rttm

utils/validate_data_dir.sh --no-text --no-feats $data_dir/ruvdi
utils/fix_data_dir.sh $data_dir/ruvdi

utils/copy_data_dir.sh $data_dir/ruvdi $data_dir/ruvdi1
utils/copy_data_dir.sh $data_dir/ruvdi $data_dir/ruvdi2

utils/shuffle_list.pl $data_dir/ruvdi/wav.scp | head -n 12 \
  | utils/filter_scp.pl - $data_dir/ruvdi/wav.scp \
  > $data_dir/ruvdi1/wav.scp
utils/fix_data_dir.sh $data_dir/ruvdi1
utils/filter_scp.pl --exclude $data_dir/ruvdi1/wav.scp \
  $data_dir/ruvdi/wav.scp > $data_dir/ruvdi2/wav.scp
utils/fix_data_dir.sh $data_dir/ruvdi2

for dataset in ruvdi1 ruvdi2; do
  utils/filter_scp.pl $data_dir/$dataset/wav.scp $data_dir/ruvdi/reco2num_spk \
    > $data_dir/$dataset/reco2num_spk
  utils/filter_scp.pl -f 2 $data_dir/$dataset/wav.scp \
    $data_dir/ruvdi/full_ref.rttm > $data_dir/$dataset/rttm
done

rm $data_dir/ruvdi/segments || exit 1;
awk '{print $1, $1}' $data_dir/ruvdi/wav.scp > $data_dir/ruvdi/utt2spk
utils/utt2spk_to_spk2utt.pl $data_dir/ruvdi/utt2spk > $data_dir/ruvdi/spk2utt
utils/fix_data_dir.sh $data_dir/ruvdi

rm -rf $tmp_dir 2> /dev/null
