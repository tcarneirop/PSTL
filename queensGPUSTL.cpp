#include <iostream>
#include <vector>
#include <algorithm>
#include <execution>
#include <chrono>
#include <numeric>
#include <iomanip>

#define MAX_SIZE 20
#define _EMPTY_ -1

// Enable symmetry optimization
#define IMPROVED 

#if defined(__GNUC__) || defined(__clang__) || defined(__acpp__)
    #define RESTRICT __restrict__
#else
    #define RESTRICT
#endif

typedef struct queen_root {
    unsigned int control;
    int8_t board[12]; 
} QueenRoot;

double rtclock() {
    auto now = std::chrono::high_resolution_clock::now();
    auto duration = std::chrono::duration_cast<std::chrono::microseconds>(now.time_since_epoch());
    return duration.count() * 1e-6;
}

inline bool GPU_queens_stillLegal(const char * RESTRICT board, const int r) {
    bool safe = true;
    const char base = board[r];
    for (int i = 0, rev_i = r - 1, offset = 1; i < r; ++i, --rev_i, offset++) {
        safe &= !((board[i] == base) | ((board[rev_i] == base - offset) | (board[rev_i] == base + offset)));
    }
    return safe;
}

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

inline bool MCstillLegal(const char *board, const int r) {
    int ld, rd;
    for (int i = 0; i < r; ++i)
        if (board[i] == board[r]) return false;
    ld = board[r];
    rd = board[r];
    for (int i = r - 1; i >= 0; --i) {
        --ld; ++rd;
        if (board[i] == ld || board[i] == rd) return false;
    }
    return true;
}

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
        } else if (MCstillLegal(board, depth) && !(flag & bit_test)) {
            
            #ifdef IMPROVED
            // Symmetry optimization: only explore half of the first row
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

    unsigned long long initial_tree_size = 0ULL;
    std::vector<QueenRoot> root_prefixes(300000); 
    
    std::cout << "### N-Queens STL Parallel | N: " << size << " | Depth: " << initialDepth;
    #ifdef IMPROVED
    std::cout << " | MODE: IMPROVED (Symmetry)";
    #endif
    std::cout << std::endl;

    double start_time = rtclock();

    unsigned long long n_explorers = BP_queens_prefixes(size, initialDepth, &initial_tree_size, root_prefixes);
    root_prefixes.resize(n_explorers);

    std::vector<unsigned long long> tree_sizes(n_explorers, 0);
    std::vector<unsigned long long> solutions(n_explorers, 0);
    std::vector<unsigned int> indices(n_explorers);
    std::iota(indices.begin(), indices.end(), 0);

    const QueenRoot* RESTRICT d_prefixes = root_prefixes.data();
    unsigned long long* RESTRICT d_trees = tree_sizes.data();
    unsigned long long* RESTRICT d_sols = solutions.data();

    std::for_each(std::execution::par_unseq, indices.begin(), indices.end(), [=](unsigned int idx) {
        queens_subtree_enumeration(size, initialDepth, idx, d_prefixes, d_trees, d_sols);
    });

    unsigned long long total_sols = std::accumulate(solutions.begin(), solutions.end(), 0ULL);
    unsigned long long total_gpu_tree = std::accumulate(tree_sizes.begin(), tree_sizes.end(), 0ULL);

    #ifdef IMPROVED
    total_sols *= 2;
    #endif

    double end_time = rtclock();

    std::cout << "------------------------------------------" << std::endl;
    std::cout << "Solutions found:   " << total_sols << std::endl;
    std::cout << "Elapsed total:     " << std::fixed << std::setprecision(3) << (end_time - start_time) << "s" << std::endl;

    return 0;
}
