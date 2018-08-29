#!/bin/bash

#================================================
#================================================

# This file is part of QBFRelay.
#
# Copyright 2018 
# Florian Lonsing, Vienna University of Technology, Austria.
#
# QBFRelay is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at
# your option) any later version.
#
# QBFRelay is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
# General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with QBFRelay.  If not, see <http://www.gnu.org/licenses/>.

#================================================
#================================================

#================================================
# THE FOLLOWING PATHS MAY HAVE TO BE ADAPTED 
#================================================

# Path to tool binaries
BINDIR=.
# Path to tmp-file directory
TMPBASEDIR=/tmp

#================================================
#================================================

# The following limits (times are in seconds, space limit in MB) are
# used for every preprocessor that is called in the loop.
SPACELIMIT=32000
CPUTIMELIMIT=300

# if 'CPUTIMELIMITSET' is true, then 'CPUTIMELIMIT' will be used for
# every tool.
CPUTIMELIMITSET=0

# individual time limits for tools A, B, Q, D 
CPUTIMELIMITA=300
CPUTIMELIMITB=300
CPUTIMELIMITQ=300
CPUTIMELIMITD=300

# number of rounds to carry out
MAXROUNDS=3

# ordering of preprocessor calls specified as a string of capital letters.
# The following convention applies:
#  "A" is QxBF
#  "B" is Bloqqer
#  "D" is HQSpre
#  "Q" is QRATPre+
#
ORDERING="AQBD"

COMPLETION=0
PRINTFINAL=0
PRINTHASH=0

PRINTFINALFILE=/dev/stdout

echo "Parsing command line options." 1>&2

while getopts "A:B:Q:D:t:s:r:o:cp:h" arg 
do
case $arg in
  t)
    echo "found parameter 't' (CPU time limit) with value $OPTARG" 1>&2
    CPUTIMELIMIT=$OPTARG
    CPUTIMELIMITSET=1
    ;;
  A)
    echo "found parameter 'A' (CPU time limit A) with value $OPTARG" 1>&2
    CPUTIMELIMITA=$OPTARG
    ;;
  B)
    echo "found parameter 'B' (CPU time limit B) with value $OPTARG" 1>&2
    CPUTIMELIMITB=$OPTARG
    ;;
  Q)
    echo "found parameter 'Q' (CPU time limit Q) with value $OPTARG" 1>&2
    CPUTIMELIMITQ=$OPTARG
    ;;
  D)
    echo "found parameter 'D' (CPU time limit D) with value $OPTARG" 1>&2
    CPUTIMELIMITD=$OPTARG
    ;;
  s)
    echo "found parameter 's' (space limit) with value $OPTARG" 1>&2
    SPACELIMIT=$OPTARG
    ;;
  r)
    echo "found parameter 'r' (rounds) with value $OPTARG" 1>&2
    MAXROUNDS=$OPTARG
    ;;
  o)
    echo "found parameter 'o' (ordering) with value $OPTARG" 1>&2
    if ((${#OPTARG} == 0))
    then
        echo "Expecting ordering string length of 1 or greater, exiting." 1>&2
        exit 1
    fi
    for ((i=0;i<${#OPTARG};i++))
    do
        if [ "${OPTARG:$i:1}" != "A" ] && [ "${OPTARG:$i:1}" != "B" ] && 
           [ "${OPTARG:$i:1}" != "C" ] && [ "${OPTARG:$i:1}" != "D" ] &&
	   [ "${OPTARG:$i:1}" != "Q" ]
        then
            echo "illegal ordering specification '${OPTARG:$i:1}' at index $i, exiting." 1>&2
            exit 1
        fi
    done
    ORDERING=$OPTARG
    ;;
  c)
    echo "found parameter 'c' (completion mode)" 1>&2
    COMPLETION=1
    ;;
  p)
    echo "found parameter 'p' (print formula) with value $OPTARG" 1>&2
    PRINTFINAL=1
    PRINTFINALFILE=$OPTARG
    ;;
  h)
    echo "found parameter 'h' (print hash values, may be expensive on huge formulas)" 1>&2
    PRINTHASH=1
    ;;
  ?)
    echo "unknown parameter, exiting." 1>&2
    exit 1
    ;;
esac
done

shift $(($OPTIND - 1)) 

#echo "Number of remaining arguments: $#" 1>&2

if (($# != 1))
then
echo "Expecting exactly one QDIMACS file as argument." 1>&2
exit 1
fi

if [ ! -f $1 ];
then
echo "Expecting a QDIMACS file as argument." 1>&2
exit 1
fi

FILE=$1

echo "QDIMACS file is: $FILE" 1>&2

BASENAME=`basename $FILE .qdimacs`

if ((CPUTIMELIMITSET))
then
    # time limit set by parameter '-t' overrides others
    CPUTIMELIMITA=$CPUTIMELIMIT
    CPUTIMELIMITB=$CPUTIMELIMIT
    CPUTIMELIMITQ=$CPUTIMELIMIT
    CPUTIMELIMITD=$CPUTIMELIMIT
fi

#================================================
#================================================

# --------------- START: helper functions --------------- 

function cleanup
{
  echo "Cleaning up temporary files." 1>&2
  rm -f $TMPINFILE
  rm -f $TMPOUTFILE
  rm -f $TMPSTDERR
  rm -f $TMPWATCH
  rm -f $TMPSCRATCH1
  rm -f $TMPSCRATCH2
}

function get_exit_code
{
  STATUS=`grep "Child status:" $TMPWATCH | wc -l | awk '{print $1}'` 
  if ((STATUS == 1))
  then
    EXIT=`grep "Child status:" $TMPWATCH | awk '{print $3}'` 
  else
    EXIT=1 
  fi
  return $EXIT
}

function check_status
{
  # expecting the name of a tool as single parameter.
  # if the preprocessor completed processing the instance then feed
  # its output to the next scheduled preprocessor. Otherwise, pass
  # on its (unchanged) input file.

  if ((SOLVED))
  then 
    return
  fi

  get_exit_code
  EXITCODE=$?

  if [ $EXITCODE == 0 ] 
  then
      echo "Status of $1 is ok, output file is used as input file for the next tool." 1>&2
      cp $TMPOUTFILE $TMPINFILE
  else
      echo "Status of $1 is NOT ok, the same input file is used for the next tool." 1>&2
  fi
}

function print_hash
{

if ((!PRINTHASH))
then
  return
fi

  # print a hash value of a formula (mainly used for debugging to see if
  # a file was modified by a preprocessor).
  # $1 is expected to be string "infile" or "outfile", and $2 is
  # '$TMPINFILE' or '$TMPOUTFILE', respectively.
  echo -n "$1 hash is: " 1>&2

# print hash of normalized formula; we did not do this in old code to avoid unnecessary work in depqbf
  $DEPQBF --pretty-print $2 > $TMPSCRATCH1
  # Select only clauses, strip comments, preamble, and prefix, sort the clauses and discard duplicates 
  grep -v "[cpae]" $TMPSCRATCH1 | sort | uniq > $TMPSCRATCH2
  # Compute hash value of sorted set of clauses
  openssl md5 $TMPSCRATCH2 | awk '{print $2}' 1>&2

}

# by convention, preprocessor 'A' is QxBF
function run_preprocessor_A
{
  echo "Running QxBF: " 1>&2

  print_hash "infile" $TMPINFILE

  $RUNSOLVER -w $TMPWATCH -M $SPACELIMIT -C $CPUTIMELIMITA $QXBF $TMPINFILE 1>$TMPOUTFILE 2>$TMPSTDERR
  get_exit_code
  RES=$?
  echo "QxBF exit code is: $RES" 1>&2

  if ((RES==10 || RES==20))
  then
      echo "Instance solved by QxBF in round $ROUNDS of $MAXROUNDS rounds, exiting." 1>&2
      SOLVED=1
  fi

  check_status "QxBF"
}

# by convention, preprocessor 'B' is Bloqqer
function run_preprocessor_B
{
  echo "Running Bloqqer: " 1>&2

  print_hash "infile" $TMPINFILE

  $RUNSOLVER -w $TMPWATCH -M $SPACELIMIT -C $CPUTIMELIMITB $BLOQQER $TMPINFILE 1>$TMPOUTFILE 2>$TMPSTDERR
  get_exit_code
  RES=$?
  echo "Bloqqer exit code is: $RES" 1>&2

  if ((RES==10 || RES==20))
  then
      echo "Instance solved by Bloqqer in round $ROUNDS of $MAXROUNDS rounds, exiting." 1>&2
      SOLVED=1
  fi

  check_status "Bloqqer"
}

# by convention, preprocessor 'D' is HQSpre
function run_preprocessor_D
{
  echo "Running HQSpre: " 1>&2
  print_hash "infile" $TMPINFILE

  $RUNSOLVER -w $TMPWATCH -M $SPACELIMIT -C $CPUTIMELIMITD ${HQSPRE} $TMPINFILE --outfile $TMPOUTFILE 2>$TMPSTDERR 1>/dev/null
  get_exit_code
  RES=$?
  echo "HQspre exit code is: $RES" 1>&2

  if ((RES==10 || RES==20))
  then
      echo "Instance solved by HQSpre in round $ROUNDS of $MAXROUNDS rounds." 1>&2
      SOLVED=1
  fi

  check_status "HQSpre"
}

# by convention, preprocessor 'Q' is QRATPre+
function run_preprocessor_Q
{
  echo "Running QRATPre+: " 1>&2
  print_hash "infile" $TMPINFILE

  # NOTE: we do NOTE enforce time limit via 'runsolver' but use SOFT
  # time limit in QRATPre+. This way, the tool aborts and prints the
  # formula with redundancies eliminated so far.
  $RUNSOLVER -w $TMPWATCH -M $SPACELIMIT ${QRATPREPLUS} --soft-time-limit=$CPUTIMELIMITQ $TMPINFILE 1>$TMPOUTFILE 2>$TMPSTDERR
  get_exit_code
  RES=$?
  echo "QRATPre+ exit code is: $RES" 1>&2

  if ((RES==10 || RES==20))
  then
      echo "Instance solved by QRATPre+ in round $ROUNDS of $MAXROUNDS rounds." 1>&2
      SOLVED=1
  fi

  check_status "QRATPre+"
}

# --------------- END: helper functions --------------- 

#================================================
#================================================

trap 'cleanup; exit 1' SIGHUP SIGINT SIGTERM

# NOTE: paths to tmp-dir must be adapted by
# setting '$TMPBASEDIR' above
TMPINFILE=$TMPBASEDIR/tmpin-$BASENAME-$$.qdimacs
TMPOUTFILE=$TMPBASEDIR/tmpout-$BASENAME-$$.qdimacs
TMPSTDERR=$TMPBASEDIR/tmpstderr-$BASENAME-$$.txt
TMPWATCH=$TMPBASEDIR/tmpwatch-$BASENAME-$$.txt
TMPSCRATCH1=$TMPBASEDIR/tmpscratch1-$BASENAME-$$.txt
TMPSCRATCH2=$TMPBASEDIR/tmpscratch2-$BASENAME-$$.txt

# NOTE: paths to binaries must be adapted by setting '$BINDIR' above
BLOQQER="$BINDIR/bloqqer"
HQSPRE="$BINDIR/hqspre --hidden 2 --univ_exp 2" 
QXBF="$BINDIR/qxbf"
RUNSOLVER="$BINDIR/runsolver"
DEPQBF="$BINDIR/depqbf"
QRATPREPLUS="$BINDIR/qratpre+ --print-formula"

RES=0
ROUNDS=1
SOLVED=0

#================================================
#================================================
#
# ACTUAL WORK STARTS HERE
#
#================================================
#================================================

cleanup;

# copy input file to temporary file
cp $FILE $TMPINFILE

if ((!COMPLETION))
then
  echo "Running at most $MAXROUNDS rounds, time limit $CPUTIMELIMIT, time limit A $CPUTIMELIMITA, time limit B $CPUTIMELIMITB, time limit Q $CPUTIMELIMITQ, time limit D $CPUTIMELIMITD, space limit $SPACELIMIT for each tool, ordering $ORDERING." 1>&2
else
  echo "Running at most $MAXROUNDS rounds until completion, time limit $CPUTIMELIMIT, time limit A $CPUTIMELIMITA, time limit B $CPUTIMELIMITB, time limit Q $CPUTIMELIMITQ, time limit D $CPUTIMELIMITD, space limit $SPACELIMIT for each tool, ordering $ORDERING." 1>&2
fi

# Flag to indicate whether a formula was modified during a round by
# any preprocessor. The condition on whether a modification occurred
# is based on the clause set of a formula. The ordering of literals in
# a clause and the ordering of clauses in a formula do not matter and
# are ignored for checking completion. We use the pretty-print
# function of DepQBF to sort the literals in a clause, the Linux
# 'sort' tool to sort the clauses, and the Linux tool 'uniq' to discard 
# duplicate clauses (some tools like QxBF may introduce duplicates). 
# DepQBF also applies universal
# reduction. However, through the rounds the preprocessors receive
# input formulas which were NOT touched by DepQBF. That is, DepQBF is
# applied only to normalize the formulas for the computation of hash
# values. We compute hash values on the sorted clause sets. The hash
# values are used to check if any change occurred during a
# round.
COMPLETE=0

for ((ROUNDS=1; (!COMPLETION || !COMPLETE) && ROUNDS<=MAXROUNDS && !SOLVED; ROUNDS++)); 
do

if ((COMPLETION))
then
  # Apply pretty-print function in DepQBF to sort literals in clauses
  $DEPQBF --pretty-print $TMPINFILE > $TMPSCRATCH1
  # Select only clauses, strip comments, preamble, and prefix, sort
  # the clauses, and discard duplicates
  grep -v "[cpae]" $TMPSCRATCH1 | sort | uniq > $TMPSCRATCH2
  # Compute hash value of sorted set of clauses
  OLDHASH=`openssl md5 $TMPSCRATCH2 | awk '{print $2}'`
fi

echo "" 1>&2
echo "Starting round $ROUNDS" 1>&2

for ((i=0;i<${#ORDERING} && !SOLVED;i++))
do
  echo "Found ordering specification '${ORDERING:$i:1}' at index $i." 1>&2
  case ${ORDERING:$i:1} in
    A)
# RUNNING QXBF
      run_preprocessor_A
      ;;
    B)
# RUNNING BLOQQER
      run_preprocessor_B
      ;;
    D)
# RUNNING HQSPRE
      run_preprocessor_D
      ;;
    Q)
# RUNNING QRATPre+
      run_preprocessor_Q
      ;;
    *)
      echo "illegal ordering specification '${ORDERING:$i:1}' at index $i, exiting." 1>&2
      exit 1
      ;;
  esac
done

echo "End of round $ROUNDS" 1>&2

if ((!SOLVED && COMPLETION))
then
  # Apply pretty-print function in DepQBF to sort literals in clauses
  $DEPQBF --pretty-print $TMPINFILE > $TMPSCRATCH1
  # Select only clauses, strip comments, preamble, and prefix, sort the clauses, and discard duplicates 
  grep -v "[cpae]" $TMPSCRATCH1 | sort | uniq > $TMPSCRATCH2
  # Compute hash value of sorted set of clauses
  NEWHASH=`openssl md5 $TMPSCRATCH2 | awk '{print $2}'`
  if [ "$OLDHASH" == "$NEWHASH" ]
  then
      # The formula which has been fed into the first preprocessor at
      # the beginning of the current round has the same clause set as
      # the formula resulting from the last preprocessor in the
      # current round. No progess is expected to be made in
      # forthcoming round, hence stop.
      echo "Completion detected after round $ROUNDS." 1>&2
      COMPLETE=1
  fi
fi

done

echo "End of rounds." 1>&2

if ((PRINTFINAL))
then
  if ((RES!=10 && RES!=20))
  then
    print_hash "infile" $TMPINFILE
    echo "Writing preprocessed file 'infile' to outfile." 1>&2
    cat $TMPINFILE > $PRINTFINALFILE
    RES=0
  fi
fi

cleanup;

# Normal termination, without having solved instance: exit 0
if ((RES!=10 && RES!=20))
then
    RES=0    
fi

echo "Exiting preprocessor script with exit code: $RES" 1>&2

exit $RES
