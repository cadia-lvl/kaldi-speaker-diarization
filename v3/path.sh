#module load kaldi
#module load cuda/10.0
#module load mkl/2020.0
export KALDI_ROOT=${KALDI_ROOT:-`pwd`/../../..}
[ -f $KALDI_ROOT/tools/env.sh ] && . $KALDI_ROOT/tools/env.sh
export PATH=$PWD/utils/:$KALDI_ROOT/tools/openfst/bin:/opt/mitlm/bin:/opt/sequitur/bin:$PWD:$PATH
[ ! -f $KALDI_ROOT/tools/config/common_path.sh ] && echo >&2 "The standard file $KALDI_ROOT/tools/config/common_path.sh is not present -> Exit!" && exit 1
. $KALDI_ROOT/tools/config/common_path.sh

PYTHONPATH=$PYTHONPATH:/opt/sequitur/lib/python2.7/site-packages/
export PYTHONPATH
