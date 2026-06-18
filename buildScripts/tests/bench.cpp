#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <cstdint>

// Simple function to format time
void print_time(const std::string& label, std::chrono::duration<double, std::milli> duration) {
    std::cout << label << ": " << duration.count() << " ms" << std::endl;
}

int main() {
    const size_t N = 1ULL << 27; // 134 Million elements (~1GB)
    std::cout << "Benchmarking on " << N << " uint64_t elements (" 
              << (N * sizeof(uint64_t)) / (1024 * 1024) << " MB)..." << std::endl;

    std::vector<uint64_t> data_cpu(N, 1);
    std::vector<uint64_t> data_gpu(N, 1);

    // --- 1. Sequential CPU Baseline ---
    auto start_cpu = std::chrono::high_resolution_clock::now();
    
    std::for_each(std::execution::seq, data_cpu.begin(), data_cpu.end(), [](uint64_t& val) {
        val = (val * 3) + 7;
    });

    auto end_cpu = std::chrono::high_resolution_clock::now();
    print_time("Sequential CPU Time", end_cpu - start_cpu);


    // --- 2. Parallel GPU Offload ---
    // Warm-up (to avoid measuring JIT compilation overhead)
    std::for_each(std::execution::par_unseq, data_gpu.begin(), data_gpu.end(), [](uint64_t& val) {
        val = (val * 3) + 7;
    });

    auto start_gpu = std::chrono::high_resolution_clock::now();
    
    std::for_each(std::execution::par_unseq, data_gpu.begin(), data_gpu.end(), [](uint64_t& val) {
        val = (val * 3) + 7;
    });

    // CRITICAL: AdaptiveCpp's SyncElision might wait automatically, 
    // but for benchmarking, we need to ensure the GPU is truly idle.
    // In StdPar, we do this by accessing a value (forcing a sync) 
    // or adding an empty loop that depends on the data.
    uint64_t sync_val = data_gpu[0]; 

    auto end_gpu = std::chrono::high_resolution_clock::now();
    print_time("Parallel GPU Time  ", end_gpu - start_gpu);

    return 0;
}
