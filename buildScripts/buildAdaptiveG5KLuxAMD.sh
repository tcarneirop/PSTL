#!/bin/bash

# 1. DEFINIÇÃO DE VARIÁVEIS (Tudo apontado para o ROCm 7.2.0)
export ROCM_PATH=/opt/rocm-7.2.0
export LLVM_ROOT=$ROCM_PATH/llvm
export ACPP_INSTALL_DIR=$HOME/acpp
export CC=$LLVM_ROOT/bin/clang
export CXX=$LLVM_ROOT/bin/clang++

# 4. Define paths
export ACPP_INSTALL_DIR=$HOME/acpp
export ROCM_PATH=/opt/rocm-6.3.3
# On newer LLVM, headers are often in a versioned subdirectory
export OMP_HEADERS=$LLVM_ROOT/lib/clang/18/include
export PSTL_HOME=$HOME/PSTL
# 5. Prepare Build Directory
# Clean start to prevent cache contamination from version 19
cd $HOME/AdaptiveCpp/
rm -rf build
mkdir -p build && cd build

cmake .. \
  -DCMAKE_INSTALL_PREFIX=$ACPP_INSTALL_DIR \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_C_COMPILER=$CC \
  -DLLVM_DIR=$LLVM_ROOT/lib/cmake/llvm \
  -DACPP_EXPERIMENTAL_LLVM=ON \
  -DWITH_ROCM_BACKEND=ON \
  -DROCM_PATH=$ROCM_PATH \
  -DHIPRTC_LIBRARY=$ROCM_PATH/lib/libhiprtc.so \
  -DWITH_CUDA_BACKEND=OFF

# 4. COMPILAÇÃO
make -j$(nproc) install


cd $PSTL_HOME

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
