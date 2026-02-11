# SuiteSparse Library Installation with BLAS Vendor Suffixes

This document describes the library installation system that allows multiple BLAS implementations to coexist in the `lib/` directory.

## Problem

When building SuiteSparse with different BLAS implementations (OpenBLAS, Intel MKL, BLIS), the resulting libraries would overwrite each other if copied to the same directory. This makes it difficult to:

1. Compare performance between different BLAS implementations
2. Maintain multiple builds on the same system
3. Switch between BLAS implementations without rebuilding

## Solution

The library installation system adds a BLAS vendor suffix to each library name, allowing multiple builds to coexist:

```
lib/libamd_openblas.so.3.3.4    # OpenBLAS build
lib/libamd_mkl.so.3.3.4         # Intel MKL build
lib/libamd_blis.so.3.3.4        # BLIS build
lib/libamd_default.so.3.3.4     # Default build
```

## Usage

### Automatic Installation

The build scripts automatically install libraries after building:

```bash
# Build with OpenBLAS and install libraries
./scripts/build_openblas.sh

# Build with Intel MKL and install libraries
./scripts/build_mkl.sh

# Build with BLIS and install libraries
./scripts/build_blis.sh
```

### Manual Installation

You can also manually install libraries from any build directory:

```bash
# Install from default build/ directory
make install-libs

# Install from specific BLAS build
make install-libs-openblas
make install-libs-mkl
make install-libs-blis

# Install from all available build directories
make install-libs-all
```

### Custom Installation

The `install_libs.sh` script can be used directly for custom installations:

```bash
# Install from a custom build directory with custom suffix
./scripts/install_libs.sh <build_dir> <blas_suffix> [lib_dir]

# Examples:
./scripts/install_libs.sh build_openblas openblas lib
./scripts/install_libs.sh build_custom custom lib
./scripts/install_libs.sh build myblas mylibs
```

## Installation Script Details

### Features

The `install_libs.sh` script:

1. **Finds all libraries** in the build directory (`.so`, `.dylib`, `.a`)
2. **Adds BLAS suffix** to library names before the extension
3. **Creates proper symlinks** for versioned shared libraries
4. **Handles multiple platforms** (Linux `.so`, macOS `.dylib`, static `.a`)
5. **Preserves version information** in the filename

### Symlink Creation

For versioned shared libraries like `libamd.so.3.3.4`, the script creates:

```
libamd_openblas.so.3.3.4         # Real file
libamd_openblas.so.3.3 -> libamd_openblas.so.3.3.4
libamd_openblas.so.3   -> libamd_openblas.so.3.3.4
libamd_openblas.so     -> libamd_openblas.so.3.3.4
```

This allows programs to link against any version of the library.

### Supported Library Types

- **Shared libraries (Linux)**: `.so`, `.so.X`, `.so.X.Y`, `.so.X.Y.Z`
- **Shared libraries (macOS)**: `.dylib`
- **Static libraries**: `.a`

## Example Workflow

### 1. Build Multiple BLAS Implementations

```bash
# Build with different BLAS implementations
make openblas       # Builds in build_openblas/
make mkl            # Builds in build_mkl/
make blis           # Builds in build_blis/
```

### 2. Libraries Are Automatically Installed

Each build script automatically calls `install_libs.sh` and installs to `lib/`:

```
lib/
├── libamd_openblas.so -> libamd_openblas.so.3.3.4
├── libamd_openblas.so.3 -> libamd_openblas.so.3.3.4
├── libamd_openblas.so.3.3 -> libamd_openblas.so.3.3.4
├── libamd_openblas.so.3.3.4
├── libamd_mkl.so -> libamd_mkl.so.3.3.4
├── libamd_mkl.so.3 -> libamd_mkl.so.3.3.4
├── libamd_mkl.so.3.3 -> libamd_mkl.so.3.3.4
├── libamd_mkl.so.3.3.4
├── libamd_blis.so -> libamd_blis.so.3.3.4
├── libamd_blis.so.3 -> libamd_blis.so.3.3.4
├── libamd_blis.so.3.3 -> libamd_blis.so.3.3.4
└── libamd_blis.so.3.3.4
```

### 3. Use Libraries

To use a specific BLAS implementation, link against the suffixed library:

```bash
# Link against OpenBLAS build
gcc myprogram.c -L./lib -lamd_openblas

# Link against Intel MKL build
gcc myprogram.c -L./lib -lamd_mkl

# Link against BLIS build
gcc myprogram.c -L./lib -lamd_blis
```

Or use `LD_LIBRARY_PATH`:

```bash
# Run with OpenBLAS libraries
LD_LIBRARY_PATH=./lib ./myprogram_openblas

# Run with Intel MKL libraries
LD_LIBRARY_PATH=./lib ./myprogram_mkl
```

## Directory Structure

```
SuiteSparse/
├── scripts/
│   ├── install_libs.sh          # Library installation script
│   ├── build_openblas.sh        # Builds and installs OpenBLAS
│   ├── build_mkl.sh             # Builds and installs Intel MKL
│   └── build_blis.sh            # Builds and installs BLIS
├── build/                       # Default build directory
├── build_openblas/              # OpenBLAS build directory
├── build_mkl/                   # Intel MKL build directory
├── build_blis/                  # BLIS build directory
└── lib/                         # Installed libraries with suffixes
    ├── *_openblas.so*
    ├── *_mkl.so*
    ├── *_blis.so*
    └── *_default.so*
```

## Makefile Targets

| Target | Description |
|--------|-------------|
| `make install-libs` | Install from `BUILD_DIR` (default: `build/`) with `BLAS_SUFFIX` (default: `default`) |
| `make install-libs-openblas` | Install from `build_openblas/` with `openblas` suffix |
| `make install-libs-mkl` | Install from `build_mkl/` with `mkl` suffix |
| `make install-libs-blis` | Install from `build_blis/` with `blis` suffix |
| `make install-libs-all` | Install from all available build directories |

## Environment Variables

- **BUILD_DIR**: Source build directory (default: `build`)
- **BLAS_SUFFIX**: Suffix to add to library names (default: `default`)

Example:

```bash
# Install from custom build with custom suffix
BUILD_DIR=my_build BLAS_SUFFIX=custom make install-libs
```

## Benefits

1. **Coexistence**: Multiple BLAS implementations can coexist in `lib/`
2. **Comparison**: Easy to compare performance between different BLAS
3. **No Rebuilding**: Switch between BLAS implementations without rebuilding
4. **Clarity**: Library names clearly indicate which BLAS they use
5. **Automation**: Build scripts automatically install libraries
6. **Flexibility**: Manual installation for custom scenarios

## See Also

- [Smart Build Guide](SMART_BUILD_README.md)
- [Benchmark Guide](BENCHMARK_README.md)
- [Project Structure](../PROJECT_STRUCTURE.md)
