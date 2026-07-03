#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <numeric>
#include <iomanip>


////////////  $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1102' -O3 -ffast-math -DIMPROVED queensSTL.cpp -o test -ltbb


// Cross-compiler support for restricted pointers
#if defined(__GNUC__) || defined(__clang__) || defined(__acpp__)
    #define RESTRICT __restrict__
#else
    #define RESTRICT
#endif



#include "../ChOp/NQueens/headers/queens_subproblem.hpp"
#include "../ChOp/NQueens/headers/queens_CPU_GPU_subproblem_eval.hpp"
#include "../ChOp/NQueens/headers/queens_sub_gen.hpp"
#include "../ChOp/NQueens/headers/queens_default_enumeration.hpp"


// Timing helper
double rtclock() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch());
    return duration.count() * 1e-6;
}



int main(int argc, char *argv[]) {


    if (argc < 3) {
        std::cout << "Usage: " << argv[0] << " <size> <initial depth>" << std::endl;
        return 1;
    }


    const int size = std::atoi(argv[1]);
    const int initialDepth = std::atoi(argv[2]);

    if (size > MAX_SIZE) {
        std::cerr << "Error: N exceeds MAX_SIZE (" << MAX_SIZE << ")" << std::endl;
        return 1;
    }

    unsigned long long initial_tree_size = 0ULL;
    std::vector<QueenRoot> root_prefixes(75580635); 
    
    std::cout << "### N-Queens Parallel STL | N: " << size << " | Depth: " << initialDepth;
    #ifdef IMPROVED
    std::cout << " | MODE: IMPROVED (Symmetry)";
    #else
    std::cout << " | MODE: FULL SEARCH";
    #endif
    std::cout << std::endl;

    // 1. Host-side Prefix Generation
    unsigned long long n_explorers = queens_subproblem_generation((char)size, initialDepth ,&initial_tree_size, root_prefixes.data());
    
    root_prefixes.resize(n_explorers);

    // 2. Prepare Infrastructure
    std::vector<unsigned long long> tree_sizes(n_explorers, 0);
    std::vector<unsigned long long> solutions(n_explorers, 0);
    std::vector<unsigned int> indices(n_explorers);
    std::iota(indices.begin(), indices.end(), 0);

    const QueenRoot* RESTRICT d_prefixes = root_prefixes.data();
    unsigned long long* RESTRICT d_trees = tree_sizes.data();
    unsigned long long* RESTRICT d_sols = solutions.data();

    // --- NEW: MEMORY WARMUP / PREFETCH ---
    // Forces USM migration to GPU HBM before the clock starts
    std::for_each(std::execution::par_unseq, indices.begin(), indices.end(), [=](unsigned int idx) {
        volatile unsigned int t = d_prefixes[idx].control;
        d_sols[idx] = 0;
    });

    // Start Timer AFTER warmup
    double start_time = rtclock();

    // 4. Parallel Execution
    std::for_each(std::execution::par_unseq, indices.begin(), indices.end(), [=](unsigned int idx) {
        queens_default_subtree_enumeration(idx, size, n_explorers,initialDepth, d_prefixes,d_trees, d_sols);

    });

    // 5. Reduction and Symmetry Multiplier
    unsigned long long qtd_sols_global = std::accumulate(solutions.begin(), solutions.end(), 0ULL);
    unsigned long long total_gpu_tree = std::accumulate(tree_sizes.begin(), tree_sizes.end(), 0ULL);

    double end_time = rtclock();

    #ifdef IMPROVED
    qtd_sols_global *= 2;
    #endif
    std::cout << "------------------------------------------" << std::endl;
    std::cout << "Initial tree nodes: " << initial_tree_size << std::endl;
    std::cout << "GPU tree nodes:     " << total_gpu_tree << std::endl;
    std::cout << "Solutions found:    " << qtd_sols_global << std::endl;
    std::cout << "Elapsed total:      " << std::fixed << std::setprecision(3) << (end_time - start_time) << "s" << std::endl;

    #ifdef CHECKSOLS
    if(qtd_sols_global == check_sols_number[size-1])
        printf("\n####### SUCCESS - CORRECT NUMBER OF SOLS. FOR SIZE %d\n", size);
    else
        printf("########## ERROR -- INCORRECT NUMBER FOS SOLS. FOR SIZE %d: %llu vs. %llu (correct)\n", size, qtd_sols_global,check_sols_number[size-1]);
    #endif

    return 0;
}

