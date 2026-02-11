#!/bin/bash
#===============================================================================
# build_mkl.sh: Build SuiteSparse with Intel MKL (incremental)
#===============================================================================

set -e

echo "=========================================="
echo "Building SuiteSparse with Intel MKL"
echo "=========================================="

show_linkage() {
    local library="$1"
    if command -v ldd >/dev/null 2>&1; then
        ldd "${library}" 2>/dev/null | grep -Ei "mkl|blas" || true
    elif command -v otool >/dev/null 2>&1; then
        otool -L "${library}" 2>/dev/null | grep -Ei "mkl|blas" || true
    else
        echo "  (linkage inspection unavailable on this platform)"
    fi
}

# Discover Intel oneAPI/MKL environment
if [ -n "${MKLROOT:-}" ] && [ -d "${MKLROOT}" ]; then
    echo "✓ Using existing MKLROOT: ${MKLROOT}"
elif [ -f /opt/intel/oneapi/setvars.sh ]; then
    # shellcheck disable=SC1091
    source /opt/intel/oneapi/setvars.sh --force
    if [ -n "${MKLROOT:-}" ]; then
        echo "✓ Intel oneAPI environment loaded"
        echo "  MKLROOT: $MKLROOT"
    else
        echo "✗ Intel oneAPI loaded but MKLROOT is not set"
        exit 1
    fi
else
    echo "✗ Error: MKLROOT not set and /opt/intel/oneapi/setvars.sh not found"
    echo "  Set MKLROOT or source your Intel oneAPI environment, then retry."
    exit 1
fi

COMMON_CMAKE_OPTIONS="-DCMAKE_PREFIX_PATH=${MKLROOT} -DSUITESPARSE_USE_OPENMP=ON -DSUITESPARSE_DEMOS=ON -DBUILD_TESTING=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_SHARED_LIBS=ON"
if [ -n "${CMAKE_OPTIONS:-}" ]; then
    CMAKE_OPTIONS="${CMAKE_OPTIONS} ${COMMON_CMAKE_OPTIONS}"
else
    CMAKE_OPTIONS="${COMMON_CMAKE_OPTIONS}"
fi

echo ""
echo "Running incremental smart build with Intel MKL..."
CMAKE_OPTIONS="${CMAKE_OPTIONS}" BLA_VENDOR=Intel10_64lp BUILD_DIR=build_mkl ./smart_build.sh "$@"

# Verify BLAS linkage
echo ""
echo "Verifying MKL linkage..."
if [ -f build_mkl/AMD/libamd.so ]; then
    linked_output="$(show_linkage build_mkl/AMD/libamd.so)"
    if echo "${linked_output}" | grep -qi mkl; then
        echo "✓ Successfully linked against Intel MKL:"
        echo "${linked_output}" | sed 's/^/  /'
    else
        echo "⚠ MKL not detected in AMD linkage output"
        if [ -n "${linked_output}" ]; then
            echo "${linked_output}" | sed 's/^/  /'
        fi
    fi
else
    echo "⚠ Could not find build_mkl/AMD/libamd.so for linkage verification"
fi

echo ""
echo "=========================================="
echo "✓ MKL build complete: build_mkl/"
echo "=========================================="

# Install libraries with mkl suffix
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/install_libs.sh" build_mkl mkl lib
