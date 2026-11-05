#!/bin/bash

sudo apt-get update
sudo apt-get install rocm-llvm-dev
sudo apt-get install rocm-llvm
# 1. Environment Setup
export ACPP_ADAPTIVITY_LEVEL=2
#!/bin/bash

# 1. Clean up everything first
cd $HOME/AdaptiveCpp/
rm -rf build
mkdir -p build && cd build

# 2. Run CMake with the "minimal" profile to bypass the libLLVM.so check
echo "Configuring AdaptiveCpp in minimal mode to bypass library check..."

cmake .. \
  -DCMAKE_C_COMPILER=/opt/rocm-7.2.0/llvm/bin/clang \
  -DCMAKE_CXX_COMPILER=/opt/rocm-7.2.0/llvm/bin/clang++ \
  -DCMAKE_INSTALL_PREFIX=$HOME/acpp \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_DIR=/opt/rocm-7.2.0/llvm/lib/cmake/llvm \
  -DACPP_COMPILER_FEATURE_PROFILE=minimal \
  -DACPP_EXPERIMENTAL_LLVM=ON \
  -DWITH_ROCM_BACKEND=ON \
  -DROCM_PATH=/opt/rocm-7.2.0 \
  -DHIPRTC_LIBRARY=/opt/rocm-7.2.0/lib/libhiprtc.so \
  -DWITH_CUDA_BACKEND=OFF

# 3. Build
echo "Starting build..."
make -j$(nproc) install

# 5. Build and Install
echo "Starting build with $(nproc) cores..."
make VERBOSE=1 -j$(nproc) install

cd ${HOME}/PSTL
echo "------------------------------------------------"
echo "Build complete! AdaptiveCpp installed to: $ACPP_INSTALL_DIR"
echo "To test: $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1032' test.cpp -ltbb"
echo " $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1102' -O3 -std=c++20 -ffast-math -DIMPROVED test_stdpar.cpp -o test_stdpar"
echo "------------------------------------------------"
