$HOME/acpp/bin/acpp -O3 --acpp-stdpar --acpp-targets="hip:gfx90a" test.cpp -o test
#acpp -O3 --acpp-stdpar --acpp-targets="hip:gfx90a;omp" test.cpp -o test
#Architecture Matters: For Grid5000, always double-check the GPU model.
## -ltbb should be added if one receives the huge error
#MI50 nodes = gfx906

#MI210 nodes = gfx90a

#What each flag does:

#-O3: Enables maximum compiler optimizations for the best performance.

#--acpp-stdpar: The "magic" flag that tells the compiler to offload C++ Standard Library parallel algorithms (like std::for_each) to the GPU.

#--acpp-targets="hip:gfx90a": Tells the compiler to generate machine code specifically for the MI210 (AMD CDNA 2 architecture).

#2. How to determine the "Target" for other nodes
#Grid5000 has different AMD GPUs. If you move to a different cluster, you can determine the correct string to put after hip: by running:

#Bash

#/opt/rocm/bin/rocminfo | grep "Name:" | grep gfx
#If it says gfx906: Use --acpp-targets="hip:gfx906" (AMD MI50).

#If it says gfx90a: Use --acpp-targets="hip:gfx90a" (AMD MI210).
