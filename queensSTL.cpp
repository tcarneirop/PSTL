#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <numeric>
#include <iomanip>


////////////  $ACPP_INSTALL_DIR/bin/acpp --acpp-stdpar --acpp-targets='hip:gfx1102' -O3 -ffast-math -DIMPROVED queensSTL.cpp -o test -ltbb

#define MAX_SIZE 24
#define _EMPTY_ -1

// Cross-compiler support for restricted pointers
#if defined(__GNUC__) || defined(__clang__) || defined(__acpp__)
    #define RESTRICT __restrict__
#else
    #define RESTRICT
#endif

typedef struct queen_root {
    unsigned int control;
    int8_t board[12]; 
} QueenRoot;

// Timing helper
double rtclock() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch());
    return duration.count() * 1e-6;
}

// Device-side legality check optimized for GPU SIMD/Warp execution
inline bool GPU_queens_stillLegal(const char * RESTRICT board, const int r) {
    bool safe = true;
    const char base = board[r];
    for (int i = 0, rev_i = r - 1, offset = 1; i < r; ++i, --rev_i, offset++) {
        safe &= !((board[i] == base) | ((board[rev_i] == base - offset) | (board[rev_i] == base + offset)));
    }
    return safe;
}


// Core enumeration logic used inside the parallel STL loop
//#ifdef __acpp__
//[[acpp::flatten]]
//#endif
void queens_subtree_enumeration(int N, int initial_depth, unsigned int idx,
                                const QueenRoot* RESTRICT root_prefixes,
                                unsigned long long* RESTRICT tree_sizes,
                                unsigned long long* RESTRICT sols) {
    unsigned int flag = 0;
    char board[MAX_SIZE]; 
    unsigned long long qtd_sols_thread = 0ULL;
    unsigned long long tree_size = 0ULL;

    for (int i = 0; i < N; ++i) board[i] = _EMPTY_;

    flag = root_prefixes[idx].control;
    for (int i = 0; i < initial_depth; ++i)
        board[i] = (char)root_prefixes[idx].board[i];

    int depth = initial_depth;

    do {
        board[depth]++;
        const int mask = 1 << board[depth];

        if (board[depth] == N) {
            board[depth] = _EMPTY_;
            depth--;
            flag &= ~(1 << board[depth]);
        } else if (!(flag & mask) && GPU_queens_stillLegal(board, depth)) {
            ++tree_size;
            flag |= mask;
            depth++;
            if (depth == N) {
                ++qtd_sols_thread;
                depth--;
                flag &= ~mask;
            }
        }
    } while (depth >= initial_depth);

    sols[idx] = qtd_sols_thread;
    tree_sizes[idx] = tree_size;
}



// Sequential sub-problem generation on the CPU
unsigned long long BP_queens_prefixes(int size, int initialDepth,
                                      unsigned long long *tree_size, 
                                      std::vector<QueenRoot>& root_prefixes) {
    unsigned int flag = 0;
    char board[MAX_SIZE];
    unsigned long long local_tree = 0ULL;
    unsigned long long num_sol = 0;

    #ifdef IMPROVED
    unsigned int break_cond = (size / 2) + (size & 1);
    #endif

    for (int i = 0; i < size; ++i) board[i] = -1;
    int depth = 0;

    do {
        board[depth]++;
        int bit_test = (1 << board[depth]);

        if (board[depth] == size) {
            board[depth] = _EMPTY_;
        } else if (!(flag & bit_test) && GPU_queens_stillLegal(board, depth)) {

            #ifdef IMPROVED
            if(depth == 1){
                if(size & 1){
                    if (board[0] == (int)break_cond-1 && board[1] > board[0]) break;
                } else {
                    if (board[0] == (int)break_cond) break;
                }
            }
            #endif

            flag |= (1ULL << board[depth]);
            depth++;
            ++local_tree;
            if (depth == initialDepth) {
                root_prefixes[num_sol].control = flag;
                for (int i = 0; i < initialDepth; ++i) root_prefixes[num_sol].board[i] = board[i];
                num_sol++;
            } else continue;
        } else continue;

        depth--;
        flag &= ~(1ULL << board[depth]);
    } while (depth >= 0);

    *tree_size = local_tree;
    return num_sol;
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
    std::vector<QueenRoot> root_prefixes(10000000); 
    
    std::cout << "### N-Queens Parallel STL | N: " << size << " | Depth: " << initialDepth;
    #ifdef IMPROVED
    std::cout << " | MODE: IMPROVED (Symmetry)";
    #else
    std::cout << " | MODE: FULL SEARCH";
    #endif
    std::cout << std::endl;

    // 1. Host-side Prefix Generation
    unsigned long long n_explorers = BP_queens_prefixes(size, initialDepth, &initial_tree_size, root_prefixes);
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
        queens_subtree_enumeration(size, initialDepth, idx, d_prefixes, d_trees, d_sols);
    });
    // 5. Reduction and Symmetry Multiplier
    unsigned long long total_sols = std::accumulate(solutions.begin(), solutions.end(), 0ULL);
    unsigned long long total_gpu_tree = std::accumulate(tree_sizes.begin(), tree_sizes.end(), 0ULL);
    double end_time = rtclock();

    #ifdef IMPROVED
    total_sols *= 2;
    #endif
    std::cout << "------------------------------------------" << std::endl;
    std::cout << "Initial tree nodes: " << initial_tree_size << std::endl;
    std::cout << "GPU tree nodes:     " << total_gpu_tree << std::endl;
    std::cout << "Solutions found:    " << total_sols << std::endl;
    std::cout << "Elapsed total:      " << std::fixed << std::setprecision(3) << (end_time - start_time) << "s" << std::endl;

    return 0;
}

