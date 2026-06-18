#include <iostream>
#include <vector>
#include <numeric>
#include <algorithm>
#include <cmath>
#include <sys/time.h>
#include <sycl/sycl.hpp>

#define _EMPTY_ -1


// $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1102' -O3 -std=c++20 -ffast-math -DIMPROVED test_sycl.hip -o nqueens_sycl

// Struct to hold the prefix subproblem data
struct QueenRoot {
    unsigned int control;
    int8_t board[12]; 
};

// High-resolution host timer
double rtclock() {
    struct timezone Tzp;
    struct timeval Tp;
    if (gettimeofday(&Tp, &Tzp) != 0) std::cout << "Error return from gettimeofday\n";
    return (Tp.tv_sec + Tp.tv_usec * 1.0e-6);
}

// Prefix handler on host
inline void prefixesHandleSol(QueenRoot *root_prefixes, unsigned int flag,
                             const char *board, int initialDepth, int num_sol) {
    root_prefixes[num_sol].control = flag;
    for(int i = 0; i < initialDepth; ++i)
        root_prefixes[num_sol].board[i] = board[i];
}


// Device-compliant safety check for the main search
inline bool GPU_queens_stillLegal(const char *board, const int r) {
    bool safe = true;
    int i, rev_i, offset;
    const char base = board[r];
    for (i = 0, rev_i = r - 1, offset = 1; i < r; ++i, --rev_i, offset++)
        safe &= !((board[i] == base) | ((board[rev_i] == base - offset) | (board[rev_i] == base + offset)));
    return safe;
}

// Core DFS Subtree Enumeration Function
void queens_subtree_enumeration(int N, int initial_depth, unsigned int idx,
                                const QueenRoot* root_prefixes,
                                unsigned long long* vector_of_tree_size,
                                unsigned long long* sols) {
    unsigned int flag = 0;
    char board[32];
    int N_l = N;
    int i, depth;
    unsigned long long qtd_sols_thread = 0ULL;
    int depthGlobal = initial_depth;
    unsigned long long int tree_size = 0ULL;

    for (i = 0; i < N_l; ++i) {
        board[i] = _EMPTY_;
    }

    flag = root_prefixes[idx].control;

    for (i = 0; i < depthGlobal; ++i)
        board[i] = root_prefixes[idx].board[i];

    depth = depthGlobal;

    do {
        board[depth]++;
        const int mask = 1 << board[depth];

        if (board[depth] == N_l) {
            board[depth] = _EMPTY_;
            depth--;
            flag &= ~(1 << board[depth]);
        } else if (!(flag & mask) && GPU_queens_stillLegal(board, depth)) {
            ++tree_size;
            flag |= mask;
            depth++;

            if (depth == N_l) { 
                ++qtd_sols_thread;
                depth--;
                flag &= ~mask;
            }
        }
    } while (depth >= depthGlobal);

    sols[idx] = qtd_sols_thread;
    vector_of_tree_size[idx] = tree_size;
}

// Initial prefix generation on CPU
unsigned long long int BP_queens_prefixes(int size, int initialDepth,
    unsigned long long *tree_size, QueenRoot *root_prefixes) {

    unsigned int flag = 0;
    int bit_test = 0;
    char board[32]; 
    int i, depth; 
    unsigned long long int local_tree = 0ULL;
    unsigned long long int num_sol = 0;

    #ifdef IMPROVED
    unsigned int break_cond = (size / 2) + (size & 1);
    #endif 

    for (i = 0; i < size; ++i) { 
        board[i] = -1;
    }

    depth = 0;

    do {
        board[depth]++;
        bit_test = 0;
        bit_test |= (1 << board[depth]);

        if (board[depth] == size) {
            board[depth] = _EMPTY_;
        } else if (!(flag & bit_test) && GPU_queens_stillLegal(board, depth)) {

            #ifdef IMPROVED
            if (depth == 1) {
                if (size & 1) {
                    if (board[0] == break_cond - 1 && board[1] > board[0]) 
                        break;
                } else {
                    if (board[0] == break_cond)
                        break;
                }
            }
            #endif 

            flag |= (1ULL << board[depth]);
            depth++;
            ++local_tree;
            
            if (depth == initialDepth) { 
                prefixesHandleSol(root_prefixes, flag, board, initialDepth, num_sol);
                num_sol++;
            } else continue;
        } else continue;

        depth--;
        flag &= ~(1ULL << board[depth]);

    } while(depth >= 0);

    *tree_size = local_tree;
    return num_sol;
}

int main(int argc, char *argv[]) {
    #ifdef IMPROVED
    std::cout << "### IMPROVED SEARCH - Avoiding mirrored solutions\n";
    #endif

    if (argc != 4) {
        std::cout << "Usage: " << argv[0] << " <size> <initial depth> <block size>\n";
        return 1;
    }

    const int size = atoi(argv[1]);  
    const int initialDepth = atoi(argv[2]); 
    const int block_size = atoi(argv[3]); // Accepted for script interface consistency
    
    unsigned long long initial_tree_size = 0ULL;
    unsigned long long qtd_sols_global = 0ULL;
    unsigned long long gpu_tree_size = 0ULL;
    unsigned int nMaxPrefixes = 75580635;

    std::cout << "\n### Queens size: " << size << ", Initial depth: " << initialDepth << ", Block size: " << block_size << "\n";

    // Standard allocations implicitly intercepted as Unified Shared Memory via --acpp-stdpar
    std::vector<QueenRoot> root_prefixes(nMaxPrefixes);
    std::vector<unsigned long long> tree_sizes(nMaxPrefixes, 0);
    std::vector<unsigned long long> solutions(nMaxPrefixes, 0);

    // Instantiate modern execution queue targeting the active GPU accelerator
    sycl::queue q{sycl::gpu_selector_v};
    std::cout << "Running on device: " << q.get_device().get_info<sycl::info::device::name>() << "\n";

    double initial_time = rtclock();

    // 1. Generate subproblems on Host
    unsigned long long n_explorers = BP_queens_prefixes(size, initialDepth, &initial_tree_size, root_prefixes.data());

    // Extract underlying raw USM interfaces for direct GPU execution
    const QueenRoot* d_prefixes = root_prefixes.data();
    unsigned long long* d_trees = tree_sizes.data();
    unsigned long long* d_sols = solutions.data();

    // 2. High-Performance Parallel Offload
    q.parallel_for(sycl::range<1>{n_explorers}, [=](sycl::id<1> item) {
        unsigned int idx = item[0];
        queens_subtree_enumeration(size, initialDepth, idx, d_prefixes, d_trees, d_sols);
    }).wait(); // Explicit execution fence boundary

    double final_time = rtclock();

    qtd_sols_global = std::accumulate(d_sols, d_sols + n_explorers, 0ULL);
    gpu_tree_size   = std::accumulate(d_trees, d_trees + n_explorers, 0ULL);


    #ifdef IMPROVED
    qtd_sols_global *= 2;
    #endif

    std::cout << "\nInitial tree size: " << initial_tree_size;
    std::cout << "\nGPU Tree size: " << gpu_tree_size 
              << "\nTotal tree size: " << (initial_tree_size + gpu_tree_size) 
              << "\nNumber of solutions found: " << qtd_sols_global << ".\n";
    std::cout << "\nElapsed total: " << (final_time - initial_time) << "\n";

    return 0;
}
