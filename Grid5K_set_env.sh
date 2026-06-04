cat << 'EOF' > ~/setup_env.sh
#!/bin/bash

# 1. Load Grid5000 Modules
ml cmake/3.23.3_gcc-10.4.0
ml gcc/13.2.0_gcc-10.4.0

# 2. Define Paths
export LLVM_ROOT=/usr/lib/llvm-18
export ACPP_DIR=$HOME/acpp
export ROCM_PATH=/opt/rocm-6.3.3

# 3. Update Environment Paths
export PATH=$LLVM_ROOT/bin:$ACPP_DIR/bin:$PATH
export LD_LIBRARY_PATH=$LLVM_ROOT/lib:$ACPP_DIR/lib:$ROCM_PATH/lib:$LD_LIBRARY_PATH

# 4. Set Compiler Defaults for AdaptiveCpp
export CC=$LLVM_ROOT/bin/clang
export CXX=$LLVM_ROOT/bin/clang++

# 5. Helper Function: Check GPU architecture
# Usage: get_gpu_arch
get_gpu_arch() {
    local arch=$(/opt/rocm/bin/rocminfo | grep -om1 "gfx90[6a]")
    if [ -z "$arch" ]; then
        echo "unknown"
    else
        echo "$arch"
    fi
}

compile_bench() {
    local TARGET_ARCH=$(get_gpu_arch)
    echo "Compiling for GPU ($TARGET_ARCH) AND CPU (OpenMP)..."
    # Adicionamos ;omp para habilitar o backend de CPU paralelo
    acpp -O3 --acpp-stdpar --acpp-targets="hip:$TARGET_ARCH;omp" "$1" -o "${1%.*}"
}

# 6. Helper Function: Compile your code
# Usage: compile_stdpar test.cpp
compile_stdpar() {
    local TARGET_ARCH=$(get_gpu_arch)
    if [ "$TARGET_ARCH" == "unknown" ]; then
        echo "Error: No AMD GPU detected!"
        return 1
    fi
    echo "Compiling for $TARGET_ARCH..."
    acpp -O3 --acpp-stdpar --acpp-targets="hip:$TARGET_ARCH" "$1" -o "${1%.*}"
}

echo "------------------------------------------------"
echo "AdaptiveCpp (LLVM 18) Environment Loaded"
echo "Detected GPU: $(get_gpu_arch)"
echo "Use 'compile_stdpar filename.cpp' to build."
echo "------------------------------------------------"
EOF
