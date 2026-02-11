#!/bin/bash
#===============================================================================
# smart_build.sh: Incremental SuiteSparse build helper
#===============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

hash_stdin_md5() {
    if command -v md5sum >/dev/null 2>&1; then
        md5sum | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q
    elif command -v openssl >/dev/null 2>&1; then
        openssl md5 | awk '{print $2}'
    else
        echo "Error: no MD5 tool available (need md5sum, md5, or openssl)" >&2
        return 1
    fi
}

hash_file_md5() {
    local file="$1"
    if command -v md5sum >/dev/null 2>&1; then
        md5sum "${file}" | awk '{print $1}'
    elif command -v md5 >/dev/null 2>&1; then
        md5 -q "${file}"
    elif command -v openssl >/dev/null 2>&1; then
        openssl md5 "${file}" | awk '{print $2}'
    else
        echo "Error: no MD5 tool available (need md5sum, md5, or openssl)" >&2
        return 1
    fi
}

cpu_jobs_default() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || echo 1
    else
        echo 1
    fi
}

iso_timestamp() {
    date +"%Y-%m-%dT%H:%M:%S%z"
}

# Configuration
# Prefer fast storage location if available
if [ -z "${BUILD_DIR:-}" ]; then
    MOBILE_BUILD_DIR="/mnt/mobile/tmp/SuiteSparse"
    if [ -d "/mnt/mobile/tmp" ] && [ -w "/mnt/mobile/tmp" ]; then
        BUILD_DIR="${MOBILE_BUILD_DIR}"
        mkdir -p "${BUILD_DIR}" 2>/dev/null || BUILD_DIR="build"
    else
        BUILD_DIR="build"
    fi
fi
STATE_FILE="${BUILD_DIR}/.build_state"
FORCE_BUILD=0
VERBOSE=0
CHECK_ONLY=0

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -f|--force)
            FORCE_BUILD=1
            shift
            ;;
        -v|--verbose)
            VERBOSE=1
            shift
            ;;
        --check)
            CHECK_ONLY=1
            shift
            ;;
        -c|--clean)
            echo -e "${YELLOW}Cleaning build directory...${NC}"
            rm -rf "${BUILD_DIR}"
            exit 0
            ;;
        -h|--help)
            echo "Smart Build System for SuiteSparse"
            echo ""
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  -f, --force     Force rebuild (clean outputs, then rebuild)"
            echo "  -v, --verbose   Show detailed output"
            echo "      --check     Exit 0 if build is up to date, 1 otherwise"
            echo "  -c, --clean     Clean build directory and exit"
            echo "  -h, --help      Show this help message"
            echo ""
            echo "Environment Variables:"
            echo "  BUILD_DIR       Build directory (default: build)"
            echo "  BLA_VENDOR      BLAS vendor (OpenBLAS, Intel10_64lp, FLAME, etc.)"
            echo "  CMAKE_OPTIONS   Additional options passed to CMake configure"
            echo "  JOBS            Parallel build jobs (default: auto-detected)"
            echo ""
            echo "Performance Tips:"
            echo "  - Install ccache to reuse compiled objects across BLAS builds"
            echo "  - Use fast storage when available"
            exit 0
            ;;
        *)
            echo -e "${RED}Unknown option: $1${NC}"
            echo "Use -h for help"
            exit 1
            ;;
    esac
done

# Function to calculate checksum of CMake input files
calculate_cmake_checksum() {
    local files=()
    while IFS= read -r file; do
        files+=("${file}")
    done < <(find . -type f \( -name "CMakeLists.txt" -o -name "*.cmake" \) \
        -not -path "./${BUILD_DIR}/*" \
        -not -path "./.git/*" \
        -not -path "./build_*/*" \
        2>/dev/null | sort)

    {
        for file in "${files[@]}"; do
            printf "%s:%s\n" "${file}" "$(hash_file_md5 "${file}")"
        done
    } | hash_stdin_md5
}

# Function to fingerprint config options that affect the generated build graph
calculate_config_fingerprint() {
    {
        echo "BLA_VENDOR=${BLA_VENDOR:-auto}"
        echo "CMAKE_OPTIONS=${CMAKE_OPTIONS:-}"
        echo "CMAKE_BUILD_TYPE=Release"
        echo "BUILD_DIR=${BUILD_DIR}"
    } | hash_stdin_md5
}

read_state_value() {
    local key="$1"
    grep "^${key}=" "${STATE_FILE}" 2>/dev/null | head -1 | cut -d'=' -f2-
}

get_generator() {
    if [ -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        grep "^CMAKE_GENERATOR:INTERNAL=" "${BUILD_DIR}/CMakeCache.txt" | cut -d'=' -f2-
    fi
}

# Return:
#   0 -> build graph is up to date
#   1 -> build graph has pending work
#   2 -> unknown, caller should fall back to normal build invocation
build_is_up_to_date() {
    local generator
    generator=$(get_generator)

    case "${generator}" in
        "Unix Makefiles")
            local rc=0
            cmake --build "${BUILD_DIR}" -- -q >/dev/null 2>&1 || rc=$?
            if [ ${rc} -eq 0 ]; then
                return 0
            fi
            if [ ${rc} -eq 1 ]; then
                return 1
            fi
            return 2
            ;;
        "Ninja")
            if ! command -v ninja >/dev/null 2>&1; then
                return 2
            fi
            local preview
            preview=$(ninja -C "${BUILD_DIR}" -n all 2>/dev/null || true)
            if echo "${preview}" | grep -qi "no work to do"; then
                return 0
            fi
            return 1
            ;;
        *)
            return 2
            ;;
    esac
}

show_pending_actions() {
    local generator
    generator=$(get_generator)
    local preview=""

    case "${generator}" in
        "Unix Makefiles")
            preview=$(cmake --build "${BUILD_DIR}" -- -n 2>/dev/null || true)
            ;;
        "Ninja")
            if command -v ninja >/dev/null 2>&1; then
                preview=$(ninja -C "${BUILD_DIR}" -n all 2>/dev/null || true)
            fi
            ;;
    esac

    if [ -n "${preview}" ]; then
        local compile_count link_count
        compile_count=$(echo "${preview}" | grep -cE '(^|[[:space:]])-c([[:space:]]|$)' || true)
        link_count=$(echo "${preview}" | grep -cE '(-shared|[[:space:]]-o[[:space:]][^[:space:]]+\.(so|a|dylib|dll)|(^|[[:space:]])ar[[:space:]])' || true)
        echo -e "${BLUE}Pending steps:${NC} compile=${compile_count}, link=${link_count}"
    fi
}

# Function to check if CMake needs to be run
needs_cmake() {
    if [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        return 0  # Need CMake
    fi

    if [ ! -f "${STATE_FILE}" ]; then
        return 0  # Need CMake
    fi

    # Check if CMake input files changed
    local current_cmake_checksum
    current_cmake_checksum=$(calculate_cmake_checksum)

    local stored_cmake_checksum
    stored_cmake_checksum=$(read_state_value "CMAKE_CHECKSUM")

    if [ "${current_cmake_checksum}" != "${stored_cmake_checksum}" ]; then
        return 0  # CMake files changed
    fi

    # Check if configuration-affecting options changed
    local current_fingerprint
    current_fingerprint=$(calculate_config_fingerprint)
    local stored_fingerprint
    stored_fingerprint=$(read_state_value "CONFIG_FINGERPRINT")

    if [ "${current_fingerprint}" != "${stored_fingerprint}" ]; then
        return 0  # Config options changed
    fi

    return 1  # No need for CMake
}

# Function to save build state
save_build_state() {
    local cmake_checksum=$1
    local config_fingerprint=$2

    mkdir -p "${BUILD_DIR}"
    cat > "${STATE_FILE}" <<STATE_EOF
# Build state file - DO NOT EDIT
BUILD_DATE=$(iso_timestamp)
CMAKE_CHECKSUM=${cmake_checksum}
CONFIG_FINGERPRINT=${config_fingerprint}
BLAS_VENDOR=${BLA_VENDOR:-auto}
CMAKE_OPTIONS=${CMAKE_OPTIONS:-}
BUILD_DIR=${BUILD_DIR}
STATE_EOF
}

# Enable ccache if available (reuses compiled objects across BLAS vendors)
if command -v ccache >/dev/null 2>&1; then
    export CMAKE_C_COMPILER_LAUNCHER=ccache
    export CMAKE_CXX_COMPILER_LAUNCHER=ccache
    CCACHE_STATUS="${GREEN}enabled${NC}"
else
    CCACHE_STATUS="${YELLOW}not available${NC}"
fi

# Main build logic
echo -e "${BLUE}=========================================="
echo "SuiteSparse Smart Build System"
echo -e "==========================================${NC}"
if [[ "${BUILD_DIR}" == /mnt/mobile/* ]]; then
    echo -e "${GREEN}Using fast storage:${NC} ${BUILD_DIR}"
else
    echo -e "Build directory: ${BUILD_DIR}"
fi
echo -e "Compiler cache: ${CCACHE_STATUS}"
echo ""

# Fast up-to-date check mode
if [ ${CHECK_ONLY} -eq 1 ]; then
    if [ ! -d "${BUILD_DIR}" ] || [ ! -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        exit 1
    fi
    if needs_cmake; then
        exit 1
    fi
    check_rc=0
    build_is_up_to_date || check_rc=$?
    if [ ${check_rc} -eq 0 ]; then
        exit 0
    fi
    exit 1
fi

# Check if we need to run CMake
if needs_cmake || [ ${FORCE_BUILD} -eq 1 ]; then
    echo -e "${YELLOW}Running CMake configuration...${NC}"

    CMAKE_OPTS="-DCMAKE_BUILD_TYPE=Release ${CMAKE_OPTIONS:-}"
    if [ -n "${BLA_VENDOR:-}" ]; then
        CMAKE_OPTS="${CMAKE_OPTS} -DBLA_VENDOR=${BLA_VENDOR}"
        echo -e "BLAS vendor: ${GREEN}${BLA_VENDOR}${NC}"
    fi

    cmake -B "${BUILD_DIR}" ${CMAKE_OPTS}

    # Save state after successful configure
    cmake_checksum=$(calculate_cmake_checksum)
    config_fingerprint=$(calculate_config_fingerprint)
    save_build_state "${cmake_checksum}" "${config_fingerprint}"

    echo -e "${GREEN}✓ CMake configuration complete${NC}"
    echo ""
fi

# Decide if build has pending compile/link work
BUILD_REQUIRED=1
if [ ${FORCE_BUILD} -eq 0 ]; then
    up_to_date_rc=0
    build_is_up_to_date || up_to_date_rc=$?
    if [ ${up_to_date_rc} -eq 0 ]; then
        BUILD_REQUIRED=0
    fi
fi

if [ ${BUILD_REQUIRED} -eq 1 ]; then
    if [ ${FORCE_BUILD} -eq 1 ] && [ -f "${BUILD_DIR}/CMakeCache.txt" ]; then
        echo -e "${YELLOW}Force rebuild requested. Cleaning previous outputs...${NC}"
        cmake --build "${BUILD_DIR}" --target clean >/dev/null 2>&1 || true
    fi

    echo -e "${YELLOW}Build graph has pending changes. Running compile/link steps...${NC}"
    show_pending_actions
    echo ""

    # Determine number of jobs
    JOBS="${JOBS:-$(cpu_jobs_default)}"

    # Build
    if [ ${VERBOSE} -eq 1 ]; then
        cmake --build "${BUILD_DIR}" --parallel "${JOBS}"
        BUILD_EXIT_CODE=$?
    else
        BUILD_LOG=$(mktemp)
        set +e
        cmake --build "${BUILD_DIR}" --parallel "${JOBS}" >"${BUILD_LOG}" 2>&1
        BUILD_EXIT_CODE=$?
        set -e
        grep -E "(Building|Linking|Built target|error|Error|warning:)" "${BUILD_LOG}" || true
        rm -f "${BUILD_LOG}"
    fi

    if [ ${BUILD_EXIT_CODE} -eq 0 ]; then
        # Refresh state timestamp and checksums
        cmake_checksum=$(calculate_cmake_checksum)
        config_fingerprint=$(calculate_config_fingerprint)
        save_build_state "${cmake_checksum}" "${config_fingerprint}"

        echo ""
        echo -e "${GREEN}=========================================="
        echo "✓ Build successful!"
        echo -e "==========================================${NC}"
    else
        echo ""
        echo -e "${RED}=========================================="
        echo "✗ Build failed!"
        echo -e "==========================================${NC}"
        exit ${BUILD_EXIT_CODE}
    fi
else
    echo -e "${GREEN}✓ No compile/link changes detected. Build is up to date.${NC}"
    echo ""
    echo "To force rebuild, use: $0 --force"
fi

# Show build info
if [ -f "${STATE_FILE}" ]; then
    echo ""
    echo -e "${BLUE}Build Information:${NC}"
    grep -v "^#" "${STATE_FILE}" | grep -v "^$" | sed 's/^/  /'
fi
