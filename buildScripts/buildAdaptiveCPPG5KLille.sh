
#!/bin/bash

export ACPP_ADAPTIVITY_LEVEL=2

unset ROCM_PATH
unset HIP_PATH

# 1. Load the newer CMake and GCC 13
# We keep these for a modern C++ standard library (libstdc++)
ml cmake/3.23.3_gcc-10.4.0
ml gcc/13.2.0_gcc-10.4.0
ml cuda/11.4.0_gcc-10.4.0
# 2. Install LLVM 18 Toolchain via manual repo injection
# This bypasses the default Debian Bullseye repos which are too old.
echo "Setting up LLVM 18 repositories..."
wget -O - https://apt.llvm.org/llvm-snapshot.gpg.key | sudo-g5k apt-key add -
echo "deb http://apt.llvm.org/bullseye/ llvm-toolchain-bullseye-18 main" | sudo-g5k tee /etc/apt/sources.list.d/llvm18.list

echo "Installing LLVM 18 and development headers..."
sudo-g5k apt update
sudo-g5k apt install -y clang-18 lld-18 libclang-18-dev libomp-18-dev clang-tools-18

# 3. SET COMPILER VARIABLES
# Switching to the verified LLVM 18 paths
export LLVM_ROOT=/usr/lib/llvm-18
export CC=$LLVM_ROOT/bin/clang
export CXX=$LLVM_ROOT/bin/clang++

# 4. Define paths

# On newer LLVM, headers are often in a versioned subdirectory
export OMP_HEADERS=$LLVM_ROOT/lib/clang/18/include
export ACPP_INSTALL_DIR=$HOME/adaptivecpp_install
#5. Prepare Build Directory
# Clean start to prevent cache contamination from version 19
cd $HOME/AdaptiveCpp/
rm -rf build
mkdir -p build && cd build

# 6. The Full CMake Command
echo "Configuring AdaptiveCpp with Clang-18..."
cmake .. \
  -DCMAKE_INSTALL_PREFIX=$HOME/adaptivecpp_install \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_CXX_COMPILER=$CXX \
  -DCMAKE_C_COMPILER=$CC \
  -DLLVM_DIR=$LLVM_ROOT/lib/cmake/llvm \
  -DCLANG_EXECUTABLE_PATH=$CXX \
  -DCLANG_INCLUDE_PATH=$LLVM_ROOT/lib/clang/18 \
  -DACPP_LLD_PATH=$LLVM_ROOT/bin/ld.lld \
  -DACPP_EXPERIMENTAL_LLVM=ON \
  -DWITH_ROCM_BACKEND=OFF \
  -DCMAKE_IGNORE_PATH="/opt/rocm;/opt/rocm/lib/cmake" \
  -DHIP_PATH=OFF \
  -DROCM_PATH=OFF \
  -DOpenMP_CXX_FLAGS="-fopenmp" \
  -DOpenMP_CXX_LIB_NAMES="omp" \
  -DOpenMP_omp_LIBRARY=$LLVM_ROOT/lib/libomp.so \
  -DOpenMP_CXX_INCLUDE_DIR="$OMP_HEADERS" \
  -DOpenMP_C_FLAGS="-fopenmp" \
  -DOpenMP_C_LIB_NAMES="omp" \
  -DOpenMP_C_INCLUDE_DIR="$OMP_HEADERS" \
  -DWITH_CUDA_BACKEND=ON

# 7. Build and Install
echo "Starting build with $(nproc) cores..."
make -j$(nproc) install

cd $HOME/adaptivecpp_install
export PATH=$HOME/adaptivecpp_install/bin:$PATH
export LD_LIBRARY_PATH=$HOME/adaptivecpp_install/lib:$LD_LIBRARY_PATH

GPU_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -n 1 | sed 's/\.//g')


# 1. Attempt to detect GPU
if command -v nvidia-smi &> /dev/null; then
    RAW_ARCH=$(nvidia-smi --query-gpu=compute_cap --format=csv,noheader,nounits | head -n 1)
    GPU_ARCH=$(echo $RAW_ARCH | sed 's/\.//g')
    TARGET="cuda:sm_$GPU_ARCH"
else
    echo "No GPU detected, defaulting to generic/host"
    TARGET="generic"
fi

echo "Compiling for target: $TARGET"
echo "Detected GPU architecture: sm_$GPU_ARCH"
#Detected GPU architecture: sm_60

#acpp -O3 -DIMPROVED --acpp-targets="cuda:sm_60" --acpp-stdpar  queensSTL.cpp -o queensGPUSTL
#$ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1102' -O3 -std=c++20 -ffast-math -DIMPROVED test_stdpar.cpp -o test_stdpar -ltbb


echo "------------------------------------------------"
echo "Build complete! AdaptiveCpp installed to: $ACPP_INSTALL_DIR"
echo "To test: $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='cuda:sm_${GPU_ARCH}' -O3 -STD=c++20 -ffast-math tes.cpp -o test -ltbb"
echo "------------------------------------------------"


