#!/bin/bash

# Definições estritas para ROCm 7.2.0
export ROCM_PATH=/opt/rocm-7.2.0
export LLVM_ROOT=$ROCM_PATH/llvm
export ACPP_INSTALL_DIR=$HOME/acpp

# Limpeza para evitar qualquer contaminação de caminhos antigos
rm -rf $HOME/acpp
rm -rf $HOME/AdaptiveCpp/build
mkdir -p $HOME/AdaptiveCpp/build && cd $HOME/AdaptiveCpp/build

# Compilação forçada com o plugin de runtime ativado
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$ACPP_INSTALL_DIR \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=$LLVM_ROOT/bin/clang++ \
  -DCMAKE_C_COMPILER=$LLVM_ROOT/bin/clang \
  -DLLVM_DIR=$LLVM_ROOT/lib/cmake/llvm \
  -DCLANG_RESOURCE_DIR=$LLVM_ROOT/lib/clang/22 \
  -DACPP_EXPERIMENTAL_LLVM=ON \
  -DWITH_ROCM_BACKEND=ON \
  -DWITH_CPU_BACKEND=ON \
  -DACPP_BUILD_CLANG_RT=ON \
  -DROCM_PATH=$ROCM_PATH \
  -DHIPRTC_LIBRARY=$ROCM_PATH/lib/libhiprtc.so \
  -DWITH_CUDA_BACKEND=OFF \
  -DCMAKE_VERBOSE_MAKEFILE=ON

# Executa o make e captura a saída
make -j$(nproc) install > build.log 2>&1



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