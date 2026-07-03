#!/bin/bash

export ACPP_ADAPTIVITY_LEVEL=2

# 3. SET COMPILER VARIABLES
# Switching to the verified LLVM 18 paths
export PSTL_HOME=/home/carneiro/PSTL
export LLVM_ROOT=/usr/lib/llvm-18
export CC=$LLVM_ROOT/bin/clang
export CXX=$LLVM_ROOT/bin/clang++
export LD_LIBRARY_PATH=$LLVM_ROOT/lib:/opt/rocm-6.3.1/lib:$LD_LIBRARY_PATH

# 4. Define paths
export ACPP_INSTALL_DIR=$HOME/acpp
export ROCM_PATH=/opt/rocm-6.3.1
# On newer LLVM, headers are often in a versioned subdirectory
export OMP_HEADERS=$LLVM_ROOT/lib/clang/18/include

# 5. Prepare Build Directory
# Clean start to prevent cache contamination from version 19
cd $HOME/AdaptiveCpp/
rm -rf build
mkdir -p build && cd build

# 6. The Full CMake Command
echo "Configuring AdaptiveCpp with Clang-18..."
cmake .. \
  -DCMAKE_PREFIX_PATH="/usr/lib/cmake:/usr/share/cmake" \
  -DCMAKE_C_COMPILER=clang-18 \
  -DCMAKE_CXX_COMPILER=clang++-18 \
  -DCMAKE_INSTALL_PREFIX=$ACPP_INSTALL_DIR \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_C_COMPILER=$CC \
  -DLLVM_DIR=$LLVM_ROOT/lib/cmake/llvm \
  -DCLANG_EXECUTABLE_PATH=$CXX \
  -DCLANG_INCLUDE_PATH=$LLVM_ROOT/lib/clang/18 \
  -DACPP_LLD_PATH=$LLVM_ROOT/bin/ld.lld \
  -DACPP_EXPERIMENTAL_LLVM=ON \
  -DWITH_ROCM_BACKEND=ON \
  -DROCM_PATH=$ROCM_PATH \
  -DHIPRTC_LIBRARY=$ROCM_PATH/lib/libhiprtc.so \
  -DOpenMP_CXX_FLAGS="-fopenmp" \
  -DOpenMP_CXX_LIB_NAMES="omp" \
  -DOpenMP_omp_LIBRARY=$LLVM_ROOT/lib/libomp.so \
  -DOpenMP_CXX_INCLUDE_DIR="$OMP_HEADERS" \
  -DOpenMP_C_FLAGS="-fopenmp" \
  -DOpenMP_C_LIB_NAMES="omp" \
  -DOpenMP_C_INCLUDE_DIR="$OMP_HEADERS" \
  -DWITH_CUDA_BACKEND=OFF

# 7. Build and Install
echo "Starting build with $(nproc) cores..."
make VERBOSE=1 -j$(nproc) install

cd ${HOME}/PSTL

echo "------------------------------------------------"
echo "Build complete! AdaptiveCpp installed to: $ACPP_INSTALL_DIR"
echo "To test: $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip: $(rocm_agent_enumerator | grep -v gfx000 | sort -u | head -1)' tests/test.cpp -o test -ltbb"
echo " $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:$(rocm_agent_enumerator | grep -v gfx000 | sort -u | head -1)' -O3 -std=c++20 -ffast-math -DIMPROVED tests/test_stdpar.cpp -o test_stdpar -ltbb"
echo "------------------------------------------------"
echo "------------------------------------------------"
$ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets=hip:gfx1102 -O3 -std=c++20 -ffast-math -DIMPROVED tests/test_gpu_cpu.cpp -o test_stdpar -ltbb
echo "------------------------------------------------"
echo "--------        TESTING ...               ------"
./test_stdpar