# SuiteSparse BLAS Benchmark Suite

Quick guide to comparing Intel MKL, OpenBLAS, and BLIS performance.

## Files Created

| File | Purpose |
|------|---------|
| `scripts/build_mkl.sh` | Build SuiteSparse with Intel MKL |
| `scripts/build_openblas.sh` | Build SuiteSparse with OpenBLAS |
| `scripts/build_blis.sh` | Build SuiteSparse with BLIS |
| `scripts/benchmark_blas.sh` | Run complete benchmark suite |
| `scripts/benchmark_db.py` | SQLite database management for results |
| `scripts/analyze_results.py` | Generate visual comparison report |
| `webapp/main.py` | FastAPI webapp for interactive visualization |
| `benchmarks/results/benchmark.db` | SQLite database (auto-created) |

## Quick Start

### Option 1: Full Automated Benchmark (Recommended)

```bash
# Run complete benchmark (builds all, tests all, compares)
./benchmark_blas.sh

# The script will:
# - Build with MKL, OpenBLAS, and BLIS
# - Run performance tests on each
# - Generate results file
# - Show recommendations
```

**Time estimate**: 20-30 minutes (mostly compilation)

### Option 2: Manual Step-by-Step

```bash
# 1. Build with each BLAS
./build_mkl.sh        # ~5 min
./build_openblas.sh   # ~5 min
./build_blis.sh       # ~5 min (installs BLIS if needed)

# 2. Run benchmarks manually
cd build_mkl
ctest -R AMD_simple
ctest -R CHOLMOD -L quick
cd ..

cd build_openblas
ctest -R AMD_simple
ctest -R CHOLMOD -L quick
cd ..

cd build_blis
ctest -R AMD_simple
ctest -R CHOLMOD -L quick
cd ..

# 3. Compare results visually
# (benchmark_blas.sh does this automatically)
```

## Understanding Results

The benchmark tests multiple operations:

| Test | What It Measures | BLAS Usage |
|------|------------------|------------|
| `AMD_simple` | Sparse matrix ordering | Low (integer ops) |
| `CHOLMOD_quick` | Cholesky factorization | High (BLAS Level 3) |
| `UMFPACK_quick` | LU factorization | High (BLAS Level 3) |
| `GraphBLAS_quick` | Matrix operations | Medium (custom kernels) |

**BLAS Level 3 operations** (matrix-matrix multiply) show the biggest performance differences.

## Analyzing Results

After running `benchmark_blas.sh`, results are automatically saved to:
- **SQLite database**: `benchmarks/results/benchmark.db` (primary storage)
- **CSV file**: `benchmarks/results/benchmark_results_YYYYMMDD_HHMMSS.txt` (backup)

### Database Operations

```bash
# List all benchmark runs
make db-list

# Show results for a specific run
make db-show RUN_ID=1

# Export run to CSV
make db-export RUN_ID=1 OUTPUT=results.csv

# Compare BLAS implementations for a specific test
make db-compare TEST=AMD_simple

# Or use the Python script directly
uv run python scripts/benchmark_db.py list
uv run python scripts/benchmark_db.py show 1
uv run python scripts/benchmark_db.py compare AMD_simple
```

### Visual Analysis

```bash
# Analyze latest CSV file
uv run python analyze_results.py benchmark_results_YYYYMMDD_HHMMSS.txt
```

Example output:
```
CHOLMOD_quick
============================================================
🥇 OpenBLAS        ████████████████████████████████  2.341s  (1.00x)
🥈 BLIS            ██████████████████████████████████  2.489s  (1.06x)
🥉 Intel MKL       ████████████████████████████████████  2.756s  (1.18x)

🏆 Fastest overall: OpenBLAS
```

### Web Visualization

Launch the interactive web dashboard:

```bash
make webapp

# The webapp will:
# - Read from SQLite database (preferred)
# - Fall back to CSV files if database unavailable
# - Show historical trends and comparisons
# - Display CPU information for each run
```

## Installation After Benchmarking

Once you've identified the fastest BLAS:

```bash
# Option A: Install from specific build
cd build_openblas  # or build_mkl, build_blis
sudo cmake --install .

# Option B: Rebuild from scratch with best BLAS
rm -rf build/
./build_openblas.sh  # or build_mkl.sh, build_blis.sh
cd build_openblas
sudo cmake --install .
```

## Troubleshooting

### Intel MKL build fails
```bash
# Verify oneAPI installation
ls /opt/intel/oneapi/mkl/latest

# Re-source environment
source /opt/intel/oneapi/setvars.sh
./build_mkl.sh
```

### OpenBLAS not found
```bash
sudo apt install libopenblas-dev
./build_openblas.sh
```

### BLIS not found
```bash
sudo apt install libblis-dev libblis-openmp-dev
./build_blis.sh
```

### Tests fail to run
```bash
# Check build succeeded
ls build_openblas/AMD/libamd.so

# Verify BLAS linkage
ldd build_openblas/AMD/libamd.so | grep blas
```

## Expected Performance (AMD Ryzen)

Based on typical benchmarks for AMD Ryzen 5000 series:

| BLAS | Expected Performance | Notes |
|------|---------------------|-------|
| **OpenBLAS** | ⭐⭐⭐⭐⭐ | Usually fastest on Ryzen |
| **BLIS** | ⭐⭐⭐⭐⭐ | Can beat OpenBLAS on AMD |
| **Intel MKL** | ⭐⭐⭐⭐ | Good, but not AMD-optimized |

**Actual results will vary** based on your specific workload.

## Clean Up

```bash
# Remove all benchmark builds
rm -rf build_mkl/ build_openblas/ build_blis/

# Remove logs
rm -f build_*.log benchmark_results_*.txt
```

## Additional Information

- **Build time**: ~5-7 minutes per BLAS implementation (first build)
- **Test time**: ~2-3 minutes per BLAS implementation
- **Disk space**: ~3-4 GB for all three builds
- **CPU usage**: 100% during compilation (parallel build)

## Performance Tips

### Speed Up Multiple BLAS Builds

When building with multiple BLAS vendors, most source files are recompiled identically. To avoid redundant compilation, install **ccache**:

```bash
# Install ccache
sudo apt install ccache

# Verify it's working
ccache -s

# Now builds will reuse compiled objects
make benchmark  # First BLAS ~5 min, subsequent ~2 min each
```

**Benefits:**
- ✓ First BLAS build: ~5-7 minutes (normal)
- ✓ Second BLAS build: ~1-2 minutes (reuses 90%+ of objects)
- ✓ Third BLAS build: ~1-2 minutes (reuses 90%+ of objects)
- ✓ Automatic - no configuration needed

The build system automatically detects and uses ccache if installed.

For more information on SuiteSparse improvements, see the main README.md.
