#!/usr/bin/env bash
# Copyright 2020 Reykjavik University (Author: Judy Fong - judyfong@ru.is)
# Apache 2.0
#
# Retrieve the md-eval file to check the accuracy of the diarization
cd ../
git clone https://github.com/nryant/dscore dscore
cd v5
ln -sfn ../dscore/scorelib/md-eval-22.pl md-eval.pl
