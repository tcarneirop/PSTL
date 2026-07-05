#!/bin/bash

source buildScripts/buildAdaptiveG5KLuxAMD.sh
cd $PSTL_HOME
make clean
make acpp-amd


echo
echo "=========================================="
echo " Running AMD AdaptiveCPP PSTL tests"
echo "=========================================="
echo

# ------------------------------------------------------------
# Execute the experiments
# ------------------------------------------------------------

for ((size=15; size<=20; size++)); do
    for ((depth=5; depth<=8; depth++)); do
        for blocksize in 64 128 256; do

            outfile="amd_STL_${size}_${depth}_${blocksize}"

            echo "Experiment: size=${size} depth=${depth} blocksize=${blocksize}"

           HIP_VISIBLE_DEVICES=0 ./queens_stdpar_amd \
              "$size" "$depth" "$blocksize" \
             > "results/$outfile"

    done
 done
done

# ------------------------------------------------------------
# Print summary
# ------------------------------------------------------------

echo
echo "=========================================="
echo " Summary"
echo "=========================================="

for ((size=15; size<=20; size++)); do
{
    echo
    echo "Board size: ${size}"
    printf "%-8s\t%-10s\t%-10s\n" "Depth" "Block" "Time(s)"
    printf "%-8s %-10s %-10s\n" "-----" "----------" "-------"

    for ((depth=5; depth<=8; depth++)); do
        for blocksize in 64 128 256; do

            outfile="results/amd_STL_${size}_${depth}_${blocksize}"

            elapsed=$(awk '/Elapsed total:/ {print $3}' "$outfile")

        printf "%d\t%d\t%d\t%s\n" \
            "$size" \
            "$depth" \
    	    "$blocksize" \
	    "$elapsed"

        done
    done
} >> report
done
