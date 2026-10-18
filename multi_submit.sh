#!/bin/bash
#export OMP_PROC_BIND=spread,close
#export BLIS_NUM_THREADS=1
#read -p "Do you want to clear previous data? (y/n)" yn
#case $yn in
#    [yY] ) echo "Removing data";rm -r output-*; rm -r data-cliff-stability; break;;
#    [nN] ) break;;
#esac
set -e
module load aocc/5.0.0
module load aocl/5.0.0
sbcl --dynamic-space-size 16000 --load "build.lisp" --quit

export VISC=FALSE
export HEIGHT=400
export REFINE=0.25
export SLOPE=0.00
export FLOATATION=0.9
export NAME=PAPER
for h in 0 0.25 0.5 0.75 1.0
do
    export NOTCH=$h
    ./worker --dynamic-space-size 4GB > ./logs/log_$h.txt &
done

