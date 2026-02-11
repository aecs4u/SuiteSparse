#!/bin/bash
#===============================================================================
# build_blis.sh: Build SuiteSparse with BLIS (incremental)
#===============================================================================

set -e

echo "=========================================="
echo "Building SuiteSparse with BLIS"
echo "=========================================="

show_linkage() {
    local library="$1"
    if command -v ldd >/dev/null 2>&1; then
        ldd "${library}" 2>/dev/null | grep -Ei "blis|blas" || true
    elif command -v otool >/dev/null 2>&1; then
        otool -L "${library}" 2>/dev/null | grep -Ei "blis|blas" || true
    else
        echo "  (linkage inspection unavailable on this platform)"
    fi
}

COMMON_CMAKE_OPTIONS="-DSUITESPARSE_USE_OPENMP=ON -DSUITESPARSE_DEMOS=ON -DBUILD_TESTING=ON -DBUILD_STATIC_LIBS=OFF -DBUILD_SHARED_LIBS=ON -DLAPACK_LIBRARIES=/usr/lib/x86_64-linux-gnu/lapack/liblapack.so"
if [ -n "${CMAKE_OPTIONS:-}" ]; then
    CMAKE_OPTIONS="${CMAKE_OPTIONS} ${COMMON_CMAKE_OPTIONS}"
else
    CMAKE_OPTIONS="${COMMON_CMAKE_OPTIONS}"
fi

echo ""
echo "Running incremental smart build with BLIS..."
# BLIS uses the FLAME vendor name in FindBLAS.
CMAKE_OPTIONS="${CMAKE_OPTIONS}" BLA_VENDOR=FLAME BUILD_DIR=build_blis ./smart_build.sh "$@"

# Verify BLAS linkage
echo ""
echo "Verifying BLIS linkage..."
if [ -f build_blis/AMD/libamd.so ]; then
    linked_output="$(show_linkage build_blis/AMD/libamd.so)"
    if echo "${linked_output}" | grep -qi blis; then
        echo "✓ Successfully linked against BLIS:"
        echo "${linked_output}" | sed 's/^/  /'
    else
        echo "⚠ BLIS not detected in AMD linkage output"
        if [ -n "${linked_output}" ]; then
            echo "${linked_output}" | sed 's/^/  /'
        fi
    fi
else
    echo "⚠ Could not find build_blis/AMD/libamd.so for linkage verification"
fi

echo ""
echo "=========================================="
echo "✓ BLIS build complete: build_blis/"
echo "=========================================="

# Install libraries with blis suffix
echo ""
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
"${SCRIPT_DIR}/install_libs.sh" build_blis blis lib
