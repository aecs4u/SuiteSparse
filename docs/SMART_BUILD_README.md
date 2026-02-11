# Smart Build System for SuiteSparse

Intelligent incremental build system that only rebuilds when source code has actually changed.

## Overview

The Smart Build System tracks source file modifications using cryptographic checksums and skips unnecessary rebuilds, significantly improving development workflow efficiency.

### Features

- ✅ **Automatic Change Detection** - Tracks all source files, headers, and CMake files
- ✅ **Checksum-Based Verification** - Uses MD5 hashes for reliable change detection
- ✅ **Zero Configuration** - Works out of the box with standard `make` commands
- ✅ **BLAS Integration** - Supports OpenBLAS, Intel MKL, and BLIS builds
- ✅ **Webapp Support** - Launch visualization server with random port assignment
- ✅ **CMake Native** - Integrated at CMake configuration level
- ✅ **Incremental Builds** - Standard make incremental compilation still works

## Quick Start

```bash
# Build only if sources changed (default)
make

# Force full rebuild
make force

# Check if build is current
make check

# View build status
make status
```

## Usage Examples

### Basic Building

```bash
# Smart build (default) - only rebuilds if sources changed
make

# Equivalent to:
./smart_build.sh
```

If no source files have changed:
```
✓ No source changes detected. Build is up to date.
To force rebuild, use: ./smart_build.sh --force
```

### Force Rebuild

```bash
# Force complete rebuild regardless of changes
make force

# Or with explicit flag
FORCE_BUILD=ON make
```

### BLAS-Specific Builds

```bash
# Build with OpenBLAS (recommended for AMD CPUs)
make openblas

# Build with Intel MKL
make mkl

# Build with BLIS
make blis
```

Each BLAS vendor gets its own build directory (`build_openblas`, `build_mkl`, `build_blis`) with independent smart build tracking.

### Webapp Visualization

```bash
# Launch benchmark visualization webapp (random port)
make webapp

# Output:
# ==========================================
# Launching BLAS Benchmark Webapp
# ==========================================
# Starting webapp on port 45123...
# ✓ Webapp started successfully
#   URL: http://localhost:45123
#   PID: 123456
#   Log: /tmp/suitesparse_webapp.log

# Check webapp status
make webapp-status

# Stop webapp
make webapp-stop
```

The webapp automatically selects a random available port to avoid conflicts.

### Benchmarking

```bash
# Run BLAS performance comparison (builds OpenBLAS and MKL)
make benchmark

# Analyze latest results
make analyze

# Launch webapp to visualize
make webapp
```

## How It Works

### Change Detection Algorithm

1. **Collect Sources**: Recursively finds all `.c`, `.cpp`, `.h`, `.hpp`, and `CMakeLists.txt` files
2. **Calculate Checksum**: For each file, combines filepath + timestamp + MD5 hash
3. **Compare**: Compares combined checksum against stored state
4. **Decision**: Skip build if checksums match, rebuild if different

### State Tracking

Build state is stored in:
- `build/.build_state` - Human-readable build metadata
- `build/.smart_build/build_state.txt` - CMake-native state file
- `build/.smart_build/source_list.txt` - List of tracked files

### Build State File Format

```
BUILD_DATE=2026-02-10T07:47:57+01:00
SOURCE_CHECKSUM=ed4c69e430c1e01997dbf1af7a294737
CMAKE_VERSION=3.28.3
BUILD_TYPE=Release
BLAS_VENDOR=OpenBLAS
SOURCE_DIR=/path/to/SuiteSparse
BINARY_DIR=/path/to/SuiteSparse/build
```

## Architecture

### Two-Level Implementation

#### 1. Shell Script (`smart_build.sh`)
- Fastest for standalone use
- Direct filesystem operations
- Portable bash script
- Used by Makefile targets

#### 2. CMake Module (`cmake/SmartBuild.cmake`)
- Native CMake integration
- Included in CMakeLists.txt
- Provides CMake variables and targets
- Used for advanced workflows

### Integration Points

```cmake
# In CMakeLists.txt (optional):
include(cmake/SmartBuild.cmake)

# Check if build needed:
if(SMART_BUILD_SKIP_BUILD)
    message("Skipping build - no changes")
    return()
endif()
```

## Advanced Usage

### Build Directory Location

The build system automatically uses fast storage if available:

**Automatic Detection:**
- Checks for `/mnt/mobile/tmp/SuiteSparse/` (fast storage)
- Falls back to `build/` in source directory if not available
- You'll see: `Using fast storage: /mnt/mobile/tmp/SuiteSparse` when active

**Benefits of Fast Storage:**
- ⚡ Faster compilation (especially on HDD systems with SSD mobile mount)
- 🗑️ Easy cleanup (won't clutter source directory)
- 💾 Saves space on main drive

**Custom Build Directory:**
```bash
# Override auto-detection
BUILD_DIR=my_build make

# Or:
BUILD_DIR=my_build ./smart_build.sh

# Force use of local directory
BUILD_DIR=build make
```

### Parallel Build Jobs

```bash
# Use specific number of jobs
JOBS=16 make

# Auto-detect (default)
make
```

### Custom BLAS Vendor

```bash
# Build with specific BLAS
BLA_VENDOR=Intel10_64lp make

# Or set in environment
export BLA_VENDOR=OpenBLAS
make
```

### Verbose Build

```bash
# Show all compilation commands
./smart_build.sh --verbose --force
```

### Clean Builds

```bash
# Clean current build directory
make clean

# Clean all build directories (build, build_openblas, build_mkl, etc.)
make distclean
```

## Configuration Options

### CMake Options

```bash
# Disable smart build checking
cmake -B build -DSMART_BUILD_ENABLED=OFF

# Force rebuild
cmake -B build -DFORCE_BUILD=ON

# Custom build type
cmake -B build -DCMAKE_BUILD_TYPE=Debug
```

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `BUILD_DIR` | Build directory path | `/mnt/mobile/tmp/SuiteSparse` if available, else `build` |
| `BLA_VENDOR` | BLAS library vendor | auto-detect |
| `JOBS` | Parallel build jobs | `nproc` |
| `CMAKE_OPTIONS` | Additional CMake flags | (empty) |

**Note:** The build system automatically detects and uses `/mnt/mobile/tmp/SuiteSparse/` for faster builds if the directory exists and is writable.

## Makefile Targets Reference

### Build Targets
- `make` or `make build` - Smart build (default)
- `make force` - Force full rebuild
- `make clean` - Clean build directory
- `make distclean` - Clean all build directories

### Installation
- `make install` - System install (requires sudo)
- `make local` - Install to `~/.local`

### Testing
- `make test` - Run all tests
- `make check` - Verify build is current
- `make status` - Show build status

### BLAS Builds
- `make openblas` - Build with OpenBLAS
- `make mkl` - Build with Intel MKL
- `make blis` - Build with BLIS

### Webapp
- `make webapp` - Launch visualization server
- `make webapp-status` - Check if running
- `make webapp-stop` - Stop server

### Benchmarking
- `make benchmark` - Run BLAS comparison
- `make analyze` - Analyze latest results

### Help
- `make help` - Show all targets

## Troubleshooting

### Build Always Rebuilds

**Problem**: Every `make` triggers a full rebuild

**Solution**:
```bash
# Check build state
make status

# Verify checksum tracking
ls -la build/.build_state

# Force clean rebuild
make clean && make
```

### Webapp Won't Start

**Problem**: `make webapp` fails

**Solution**:
```bash
# Check log file
cat /tmp/suitesparse_webapp.log

# Verify uv is installed
uv --version

# Try manual start
cd webapp
uv run --with fastapi --with uvicorn python main.py
```

### Stale Build State

**Problem**: Changes not detected

**Solution**:
```bash
# Remove state and rebuild
rm -f build/.build_state
make force
```

## Performance Impact

### Overhead

- **State Check**: ~0.1-0.5 seconds for large codebases
- **Checksum Calculation**: ~0.2-1.0 seconds depending on file count
- **Total Overhead**: < 2 seconds (negligible compared to build time)

### Benefits

- **Skip Unnecessary Builds**: 0 seconds (instant)
- **Save Developer Time**: Minutes to hours per day
- **CI/CD Efficiency**: Faster pipelines with cached builds

## Comparison with Standard Make

| Feature | Standard Make | Smart Build |
|---------|--------------|-------------|
| Incremental compilation | ✅ Yes | ✅ Yes |
| Skip no-op rebuilds | ❌ No | ✅ Yes |
| Change detection | File timestamps | Checksums |
| False positives | Common | Rare |
| Cross-directory tracking | Limited | Full |
| Configuration changes | Not tracked | Tracked |

## Best Practices

1. **Use Default `make`** - Let smart build decide when to rebuild
2. **Force Only When Needed** - Use `make force` sparingly
3. **Check Status** - Run `make status` to understand build state
4. **Clean Periodically** - Use `make clean` if issues arise
5. **BLAS Builds** - Keep separate build directories for different BLAS vendors

## Integration with CI/CD

```yaml
# GitHub Actions example
- name: Build SuiteSparse (Smart)
  run: make

- name: Force rebuild on schedule
  if: github.event_name == 'schedule'
  run: make force

- name: Cache build state
  uses: actions/cache@v3
  with:
    path: build/.build_state
    key: suitesparse-${{ hashFiles('**/*.c', '**/*.h') }}
```

## License

Smart Build System additions: Copyright (c) 2026
Original SuiteSparse: Copyright (c) 2023, Timothy A. Davis
SPDX-License-Identifier: Apache-2.0

## See Also

- `./smart_build.sh --help` - Shell script options
- `make help` - Makefile targets
- `BENCHMARK_README.md` - Benchmarking guide
- `webapp/README.md` - Webapp documentation
