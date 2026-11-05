#!/bin/bash

# 1. DEFINIÇÃO DE VARIÁVEIS (Tudo apontado para o ROCm 7.2.0)
export ROCM_PATH=/opt/rocm-7.2.0
export LLVM_ROOT=$ROCM_PATH/llvm
export ACPP_INSTALL_DIR=$HOME/acpp
export CC=$LLVM_ROOT/bin/clang
export CXX=$LLVM_ROOT/bin/clang++

# 2. LIMPEZA TOTAL
rm -rf $HOME/acpp
rm -rf $HOME/AdaptiveCpp/build

# 3. CONFIGURAÇÃO CMAKE (Estrita: Apenas LLVM do ROCm)
cd $HOME/AdaptiveCpp
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
