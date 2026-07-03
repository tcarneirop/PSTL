# User-configurable compilers
ACPP ?= $(ACPP_INSTALL_DIR)/bin/acpp
NVC  ?= nvc++

SRC    := queensSTL.cpp
TARGET := queens_stdpar

TEST_SRC    := tests/test_gpu_cpu.cpp
TEST_TARGET := test_stdpar

COMMON_FLAGS := \
    -O3 \
    -std=c++20 \
    -ffast-math \
    -DIMPROVED \
    -DCHECKSOLS

LIBS := -ltbb

# ----------------------------------------------------------------------
# AdaptiveCpp
# ----------------------------------------------------------------------

AMD_ARCH := $(shell rocm_agent_enumerator | grep -v gfx000 | sort -u | head -1)

ACPP_FLAGS := \
    --acpp-stdpar \
    $(COMMON_FLAGS)

.PHONY: acpp-amd acpp-nvidia nvc clean

acpp-amd:
	$(ACPP) $(ACPP_FLAGS) \
	    --acpp-targets=hip:$(AMD_ARCH) \
	    $(SRC) -o $(TARGET)_amd $(LIBS)

acpp-nvidia:
	$(ACPP) $(ACPP_FLAGS) \
	    $(if $(CUDA_ARCH),--acpp-targets=cuda:$(CUDA_ARCH),) \
	    $(SRC) -o $(TARGET)_cuda $(LIBS)


# ----------------------------------------------------------------------
# AdaptiveCpp TESTS
# ----------------------------------------------------------------------
acpp-tests-amd:
	$(ACPP) $(ACPP_FLAGS) \
	    --acpp-targets=hip:$(AMD_ARCH) \
	    $(TEST_SRC) -o $(TEST_TARGET)_amd $(LIBS)

acpp-tests-nvidia:
	$(ACPP) $(ACPP_FLAGS) \
	    $(if $(CUDA_ARCH),--acpp-targets=cuda:$(CUDA_ARCH),) \
	    $(TEST_SRC) -o $(TEST_TARGET)_cuda $(LIBS)


# ----------------------------------------------------------------------
# NVIDIA HPC SDK
# ----------------------------------------------------------------------

NVC_FLAGS := \
    -std=c++20 \
    -stdpar=gpu \
    -O3 \
    -fast \
    -DIMPROVED \
    -DCHECKSOLS \
    $(if $(CUDA_ARCH),-gpu=$(CUDA_ARCH),)

nvc:
	$(NVC) $(NVC_FLAGS) \
	    $(SRC) -o $(TARGET)_nvc

clean:
	rm -f $(TARGET)_amd $(TARGET)_cuda $(TARGET)_nvc