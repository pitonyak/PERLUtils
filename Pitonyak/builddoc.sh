#!/bin/bash

source_dir=.
dest_dir=.
pod_ext=.pod.html

for f in $source_dir/*
do
    if [[ ${f: -3} == ".pl" || ${f: -3} == ".pm" ]] 
    then
        destname=${f}${pod_ext}
        echo Do something with $f here for $destname.
        pod2html --infile "$f" --outfile "$destname"
    fi
done
rm *.tmp

