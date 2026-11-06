#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <cmath>
#include <iomanip>

template<typename Policy>
void benchmark(std::string name, std::vector<double>& d, Policy policy, size_t n) {
    auto start = std::chrono::high_resolution_clock::now();
    std::for_each(policy, d.begin(), d.end(), [](double& x) {
        double val = x;
        // Aumentamos a carga para garantir que a GPU mostre seu valor
        for(int i = 0; i < 5; ++i) {
            val = std::sin(val) + std::pow(val, 0.5);
        }
        x = val;
    });

    // Sincronização: acessamos o último elemento para forçar o término
    volatile double sync = d[n-1];
    auto end = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> diff = end - start;
    std::cout << std::left << std::setw(25) << name << ": " 
              << std::fixed << std::setprecision(5) << diff.count() << " s | "
              << (n / diff.count()) / 1e6 << " M/s" << std::endl;
}

int main() {
    const size_t N = 1ULL << 27;
    std::cout << "Benchmarking: GPU vs CPU (134M elements)" << std::endl;

    std::vector<double> data(N, 1.0);

    // 1. Warmup (GPU)
    std::for_each(std::execution::par_unseq, data.begin(), data.begin() + 1024, [](double& x) {
        x = std::sin(std::pow(x, 1.5));
    });

    // 2. GPU Test
    benchmark("(par_unseq)", data, std::execution::par_unseq, N);

    // 3. CPU Parallel Test (Multi-core)
    // Nota: O AdaptiveCpp pode usar OpenMP aqui se compilado para isso
    std::fill(data.begin(), data.end(), 1.0); // Reset data
    benchmark("CPU Parallel (par)", data, std::execution::par, N);

    // 4. CPU Sequential Test
    // Vamos usar apenas 1/10 dos dados para não demorar demais
    const size_t N_small = N / 10;
    std::fill(data.begin(), data.end(), 1.0);
    benchmark("CPU Sequential (seq)*", data, std::execution::seq, N_small);
    
    return 0;
}
