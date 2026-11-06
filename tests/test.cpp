#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <cstdint>

int main() {
    // 1. Setup a large enough vector to make GPU offload worthwhile (~500MB)
    const size_t N = 1ULL << 26; 
    std::vector<uint64_t> data(N, 1);

    std::cout << "Starting computation on " << N << " elements..." << std::endl;

    // 2. The parallel operation
    // AdaptiveCpp will intercept 'par_unseq' and move this to the GPU
    std::for_each(std::execution::par_unseq, data.begin(), data.end(), [](uint64_t& val) {
        val = (val * 2) + 42;
    });

    // 3. Verification
    bool success = true;
    for (size_t i = 0; i < 100; ++i) { // Check first 100 elements
        if (data[i] != 44) {
            success = false;
            break;
        }
    }

    if (success) {
        std::cout << "SUCCESS: GPU/Parallel execution completed correctly!" << std::endl;
        std::cout << "\tCORRECT value at index 0: " << data[0] << " (Expected 44)" << std::endl;
    } else {
        std::cerr << "FAILURE: Data does not match expected results." << std::endl;
        return 1;
    }

    return 0;
}
