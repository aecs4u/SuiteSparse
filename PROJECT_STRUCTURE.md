# SuiteSparse Project Structure

This document describes the enhanced directory structure for SuiteSparse with smart build system and BLAS benchmarking tools.

## Directory Layout

```
SuiteSparse/
├── modules/                # Core SuiteSparse module libraries
│   ├── AMD/                # Approximate Minimum Degree ordering
│   ├── BTF/                # Block Triangular Form
│   ├── CAMD/               # Constrained AMD
│   ├── CCOLAMD/            # Constrained Column AMD
│   ├── CHOLMOD/            # Sparse Cholesky factorization
│   ├── COLAMD/             # Column AMD
│   ├── CSparse/            # Simple sparse matrix package
│   ├── CXSparse/           # Extended CSparse
│   ├── GraphBLAS/          # Graph algorithms in linear algebra
│   ├── KLU/                # Sparse LU factorization
│   ├── LAGraph/            # Graph algorithms library
│   ├── LDL/                # Simple LDL factorization
│   ├── Mongoose/           # Graph partitioning
│   ├── ParU/               # Parallel unsymmetric LU
│   ├── RBio/               # Rutherford Boeing I/O
│   ├── SPEX/               # Exact sparse linear algebra
│   ├── SPQR/               # Sparse QR factorization
│   ├── SuiteSparse_config/ # Configuration module
│   └── UMFPACK/            # Unsymmetric multifrontal LU
│
├── scripts/                # Build and benchmark scripts
│   ├── build_openblas.sh   # Build with OpenBLAS
│   ├── build_mkl.sh        # Build with Intel MKL
│   ├── build_blis.sh       # Build with BLIS
│   ├── benchmark_blas.sh   # BLAS performance comparison
│   └── analyze_results.py  # Results analysis tool
│
├── benchmarks/             # Benchmark infrastructure
│   └── results/            # Benchmark result files
│       ├── *.txt           # CSV format results
│       └── benchmark.db    # SQLite database (primary storage)
│
├── webapp/                 # Visualization web application
│   ├── main.py             # FastAPI server
│   ├── templates/          # HTML templates
│   │   └── index.html      # Dashboard
│   └── static/             # Static assets
│
├── docs/                   # Documentation
│   ├── BENCHMARK_README.md # Benchmarking guide
│   └── SMART_BUILD_README.md # Build system guide
│
├── matlab/                 # MATLAB demo files
│   ├── SuiteSparse_demo.m  # Main demo
│   ├── SuiteSparse_test.m  # Test suite
│   └── SuiteSparse_*.m     # Other MATLAB files
│
├── cmake/                  # CMake modules
│   ├── SmartBuild.cmake    # Smart build detection
│   └── SmartBuildSave.cmake # Build state management
│
├── build/                  # Default build directory (gitignored)
├── build_openblas/         # OpenBLAS build (gitignored)
├── build_mkl/              # Intel MKL build (gitignored)
├── build_blis/             # BLIS build (gitignored)
├── lib/                    # Installed libraries with BLAS vendor suffix
│
├── smart_build.sh          # Main smart build script
├── Makefile                # Enhanced Makefile
├── CMakeLists.txt          # Root CMake configuration
└── .gitignore              # Git ignore patterns
```

## Key Files

### Build System
- **`smart_build.sh`** - Intelligent incremental build script
- **`Makefile`** - Enhanced with BLAS builds and webapp support
- **`cmake/SmartBuild.cmake`** - CMake-native smart build module

### Benchmarking
- **`scripts/benchmark_blas.sh`** - Automated BLAS performance testing
- **`scripts/benchmark_db.py`** - SQLite database management for benchmark results
- **`scripts/analyze_results.py`** - Statistical analysis and visualization
- **`scripts/build_*.sh`** - BLAS-specific build scripts

### Visualization
- **`webapp/main.py`** - FastAPI web server for interactive results
- **`webapp/templates/index.html`** - Dashboard UI

### Documentation
- **`docs/SMART_BUILD_README.md`** - Complete build system guide
- **`docs/BENCHMARK_README.md`** - Benchmarking workflow guide
- **`PROJECT_STRUCTURE.md`** (this file) - Directory layout

## Build Directories

Build artifacts are stored in separate directories:

| Directory | Purpose | BLAS |
|-----------|---------|------|
| `build/` | Default build | Auto-detected or Intel MKL |
| `build_openblas/` | OpenBLAS build | OpenBLAS |
| `build_mkl/` | Intel MKL build | Intel MKL |
| `build_blis/` | BLIS build | BLIS |
| `/mnt/mobile/tmp/SuiteSparse/` | Fast storage (auto-detected) | Auto |

All build directories are gitignored.

## File Patterns

### Ignored Files (in .gitignore)
- `build*/` - All build directories
- `benchmarks/results/*.txt` - Benchmark results
- `__pycache__/` - Python cache
- `webapp/.webapp.pid` - Webapp process ID
- `*.o`, `*.so`, `*.a` - Compiled objects
- `.build_state`, `.smart_build/` - Build state tracking

### Important Files
- `CMakeLists.txt` - Package configuration
- `*.c`, `*.h` - Source files
- `*.cmake` - CMake modules

## Usage Examples

### Building
```bash
# Smart build (uses fast storage if available)
make

# Build with specific BLAS
make openblas
make mkl
make blis

# Install libraries with unique names
make install-libs                # Install from default build/
make install-libs-openblas       # Install OpenBLAS build
make install-libs-mkl            # Install Intel MKL build
make install-libs-blis           # Install BLIS build
make install-libs-all            # Install all available builds
```

### Library Installation

Libraries are installed to `lib/` with BLAS vendor suffixes to prevent different builds from overwriting each other:

```bash
lib/libamd_openblas.so.3.3.4    # OpenBLAS build
lib/libamd_mkl.so.3.3.4         # Intel MKL build
lib/libamd_blis.so.3.3.4        # BLIS build
lib/libamd_default.so.3.3.4     # Default build
```

The install script automatically creates proper symlinks for versioned libraries.

### Benchmarking
```bash
# Run comparison (automatically saves to database)
make benchmark

# Analyze results
make analyze

# View in browser (default port 9001)
make webapp

# Use custom port
PORT=8080 make webapp

# Database operations
make db-list                          # List all runs
make db-show RUN_ID=1                 # Show specific run
make db-export RUN_ID=1 OUTPUT=out.csv # Export to CSV
make db-compare TEST=AMD_simple       # Compare BLAS for test
```

### Development
```bash
# Check if rebuild needed
make check

# Force clean rebuild
make force

# Clean all
make distclean
```

## Adding New Files

When adding new files to the project:

1. **Scripts** → Place in `scripts/`
2. **Documentation** → Place in `docs/`
3. **Benchmarks** → Results go to `benchmarks/results/`
4. **Webapp assets** → Static files in `webapp/static/`
5. **CMake modules** → Place in `cmake/`

Update `.gitignore` for any new generated files.

## Clean Project State

To return to a clean state:

```bash
# Remove all build artifacts
make distclean

# Remove benchmark results
rm -rf benchmarks/results/*.txt

# Remove webapp cache
rm -rf webapp/__pycache__

# Clean Python cache
find . -type d -name __pycache__ -exec rm -rf {} +
```

## See Also

- [Smart Build Guide](docs/SMART_BUILD_README.md)
- [Benchmark Guide](docs/BENCHMARK_README.md)
- [Main README](README.md)
