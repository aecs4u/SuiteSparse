#!/bin/bash
#===============================================================================
# install_libs.sh: Install SuiteSparse libraries with BLAS vendor suffix
#===============================================================================
# Usage: ./install_libs.sh <build_dir> <blas_suffix> [lib_dir]
#
# Example:
#   ./install_libs.sh build_openblas openblas lib
#   ./install_libs.sh build_mkl mkl lib
#   ./install_libs.sh build_blis blis lib
#===============================================================================

set -e

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <build_dir> <blas_suffix> [lib_dir]"
    echo ""
    echo "Example:"
    echo "  $0 build_openblas openblas lib"
    echo "  $0 build_mkl mkl lib"
    exit 1
fi

BUILD_DIR="$1"
BLAS_SUFFIX="$2"
LIB_DIR="${3:-lib}"

# Get the project root directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

BUILD_PATH="${PROJECT_ROOT}/${BUILD_DIR}"
LIB_PATH="${PROJECT_ROOT}/${LIB_DIR}"

if [ ! -d "${BUILD_PATH}" ]; then
    echo "Error: Build directory not found: ${BUILD_PATH}"
    exit 1
fi

# Create lib directory if it doesn't exist
mkdir -p "${LIB_PATH}"

echo "=========================================="
echo "Installing SuiteSparse libraries"
echo "  Build dir: ${BUILD_DIR}"
echo "  BLAS suffix: ${BLAS_SUFFIX}"
echo "  Target dir: ${LIB_DIR}"
echo "=========================================="

# Function to copy and rename a library
install_lib() {
    local src="$1"
    local basename="$(basename "${src}")"

    # Extract library name and extension
    # Handle patterns like: libamd.so, libamd.so.3, libamd.so.3.3.2, libamd.dylib, libamd.a
    if [[ "${basename}" =~ ^(lib[^.]+)\.(.*)$ ]]; then
        local libname="${BASH_REMATCH[1]}"
        local ext="${BASH_REMATCH[2]}"

        # Add BLAS suffix before extension
        local dst_name="${libname}_${BLAS_SUFFIX}.${ext}"
        local dst="${LIB_PATH}/${dst_name}"

        # Copy the library
        cp -f "${src}" "${dst}"
        echo "  ✓ ${basename} → ${dst_name}"

        # Handle symlinks for versioned .so files
        if [[ "${ext}" == so* ]] && [[ "${ext}" =~ ^so\.([0-9]+)\.([0-9]+)\.([0-9]+)$ ]]; then
            local major="${BASH_REMATCH[1]}"
            local minor="${BASH_REMATCH[2]}"

            # Create symlinks: libname_suffix.so.X.Y -> libname_suffix.so.X.Y.Z
            local link_name="${libname}_${BLAS_SUFFIX}.so.${major}.${minor}"
            (cd "${LIB_PATH}" && ln -sf "${dst_name}" "${link_name}")
            echo "    → ${link_name} (symlink)"

            # Create symlinks: libname_suffix.so.X -> libname_suffix.so.X.Y.Z
            link_name="${libname}_${BLAS_SUFFIX}.so.${major}"
            (cd "${LIB_PATH}" && ln -sf "${dst_name}" "${link_name}")
            echo "    → ${link_name} (symlink)"

            # Create symlinks: libname_suffix.so -> libname_suffix.so.X.Y.Z
            link_name="${libname}_${BLAS_SUFFIX}.so"
            (cd "${LIB_PATH}" && ln -sf "${dst_name}" "${link_name}")
            echo "    → ${link_name} (symlink)"
        elif [[ "${ext}" == "so" ]]; then
            # For unversioned .so files, no additional symlinks needed
            :
        elif [[ "${ext}" =~ ^dylib ]]; then
            # For macOS .dylib files, create a symlink without version
            local link_name="${libname}_${BLAS_SUFFIX}.dylib"
            if [ "${dst_name}" != "${link_name}" ]; then
                (cd "${LIB_PATH}" && ln -sf "${dst_name}" "${link_name}")
                echo "    → ${link_name} (symlink)"
            fi
        fi
    fi
}

# Count libraries installed
count=0

# Find all shared libraries in the build directory
echo ""
echo "Searching for libraries in ${BUILD_DIR}..."

# Search for .so files (Linux)
while IFS= read -r -d '' lib; do
    install_lib "${lib}"
    count=$((count + 1))
done < <(find "${BUILD_PATH}" -type f -name "lib*.so*" -print0 2>/dev/null || true)

# Search for .dylib files (macOS)
while IFS= read -r -d '' lib; do
    install_lib "${lib}"
    count=$((count + 1))
done < <(find "${BUILD_PATH}" -type f -name "lib*.dylib*" -print0 2>/dev/null || true)

# Search for .a files (static libraries) if BUILD_STATIC_LIBS was ON
while IFS= read -r -d '' lib; do
    install_lib "${lib}"
    count=$((count + 1))
done < <(find "${BUILD_PATH}" -type f -name "lib*.a" -print0 2>/dev/null || true)

echo ""
echo "=========================================="
echo "✓ Installed ${count} libraries to ${LIB_DIR}/"
echo "=========================================="

# Show a sample of installed libraries
echo ""
echo "Sample of installed libraries:"
ls -lh "${LIB_PATH}" | grep "_${BLAS_SUFFIX}\." | head -10 || true
