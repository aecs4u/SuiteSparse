#!/bin/bash
#===============================================================================
# build_openblas.sh: Build SuiteSparse with OpenBLAS (incremental)
#===============================================================================

set -e

echo "=========================================="
echo "Building SuiteSparse with OpenBLAS"
echo "=========================================="

show_linkage() {
    local library="$1"
    if command -v ldd >/dev/null 2>&1; then
        ldd "${library}" 2>/dev/null | grep -Ei "openblas|blas" || true
    elif command -v otool >/dev/null 2>&1; then
        otool -L "${library}" 2>/dev/null | grep -Ei "openblas|blas" || true
    else
        echo "  (linkage inspection unavailable on this platform)"
    fi
}

COMMON_CMAKE_OPTIONS="-DSUITESPARSE_USE_OPENMP=ON -DSUITESPARSE_DEMOS=ON -DBUILD_TESTING=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_SHARED_LIBS=ON"
if [ -n "${CMAKE_OPTIONS:-}" ]; then
    CMAKE_OPTIONS="${CMAKE_OPTIONS} ${COMMON_CMAKE_OPTIONS}"
else
    CMAKE_OPTIONS="${COMMON_CMAKE_OPTIONS}"
fi

echo ""
echo "Running incremental smart build with OpenBLAS..."
CMAKE_OPTIONS="${CMAKE_OPTIONS}" BLA_VENDOR=OpenBLAS BUILD_DIR=build_openblas ./smart_build.sh "$@"

# Verify BLAS linkage
echo ""
echo "Verifying OpenBLAS linkage..."
if [ -f build_openblas/AMD/libamd.so ]; then
    linked_output="$(show_linkage build_openblas/AMD/libamd.so)"
    if echo "${linked_output}" | grep -qi openblas; then
        echo "✓ Successfully linked against OpenBLAS:"
        echo "${linked_output}" | sed 's/^/  /'
    else
        echo "⚠ OpenBLAS not detected in AMD linkage output"
        if [ -n "${linked_output}" ]; then
            echo "${linked_output}" | sed 's/^/  /'
        fi
    fi
else
    echo "⚠ Could not find build_openblas/AMD/libamd.so for linkage verification"
fi

echo ""
echo "=========================================="
echo "✓ OpenBLAS build complete: build_openblas/"
echo "=========================================="

# Install libraries with openblas suffix
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/install_libs.sh" build_openblas openblas lib
