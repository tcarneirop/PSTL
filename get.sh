#!/bin/bash


echo
echo "=========================================="
echo " Summary"
echo "=========================================="

for ((size=15; size<=20; size++)); do
{
    echo
    echo "Board size: ${size}"
    printf "%s\t%-10s\t%-10s\t%-10s\n" "Size" "Depth" "Block" "Time(s)"

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
