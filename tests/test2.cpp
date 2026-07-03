#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <cmath> // For std::sin and std::pow

int main() {
    // 128 million elements (~1GB of doubles)
    const size_t N = 1ULL << 27;
    std::cout << "Targeting " << N << " elements..." << std::endl;

    // Use doubles for high-intensity math
    std::vector<double> data(N, 1.0);

    // --- 1. THE WARMUP ---
    // We run the kernel once to "cook" it (JIT, memory, clocks)
    std::for_each(std::execution::par_unseq, data.begin(), data.begin() + 1024, [](double& x) {
        x = std::sin(std::pow(x, 1.5));
    });
    std::cout << "Warmup complete. Hardware is ready." << std::endl;

    // --- 2. GPU BENCHMARK ---
    auto start = std::chrono::high_resolution_clock::now();

    std::for_each(std::execution::par_unseq, data.begin(), data.end(), [](double& x) {
        // High-intensity math chain
        // GPUs love transcendental functions like sin/cos/exp
        double val = x;
        for(int i = 0; i < 5; ++i) {
            val = std::sin(val) + std::pow(val, 0.5);
        }
        x = val;
    });

    // Ensure the GPU is finished by accessing the last element
    double sync_check = data[N - 1];

    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end - start;

    std::cout << "GPU Execution Time: " << diff.count() << " seconds" << std::endl;
    std::cout << "Throughput: " << (N / diff.count()) / 1e6 << " million elements/sec" << std::endl;

    return 0;
}

