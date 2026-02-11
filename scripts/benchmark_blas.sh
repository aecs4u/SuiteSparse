#!/bin/bash
#===============================================================================
# benchmark_blas.sh: Comprehensive BLAS performance comparison for SuiteSparse
#===============================================================================

set -euo pipefail

# Force C locale for numeric formatting
export LC_NUMERIC=C

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
RESULTS_DIR="${ROOT_DIR}/benchmarks/results"
DB_SCRIPT="${SCRIPT_DIR}/benchmark_db.py"

mkdir -p "${RESULTS_DIR}"
TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
RESULTS_FILE="${RESULTS_DIR}/benchmark_results_${TIMESTAMP}.txt"
MEMORY_FILE="${RESULTS_DIR}/benchmark_memory_${TIMESTAMP}.txt"

cpu_cores() {
    if command -v nproc >/dev/null 2>&1; then
        nproc
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.ncpu 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

cpu_model() {
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | awk -F: '/Model name/{gsub(/^ +/,"",$2); print $2; exit}'
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n machdep.cpu.brand_string 2>/dev/null || uname -m
    else
        uname -m
    fi
}

cpu_vendor() {
    if command -v lscpu >/dev/null 2>&1; then
        lscpu | awk -F: '/Vendor ID/{gsub(/^ +/,"",$2); print $2; exit}'
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n machdep.cpu.vendor 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

hostname_info() {
    hostname 2>/dev/null || echo "unknown"
}

kernel_info() {
    uname -sr 2>/dev/null || echo "unknown"
}

mem_total_gb() {
    if [ -f /proc/meminfo ]; then
        awk '/MemTotal:/ { printf "%.2f", $2 / 1024.0 / 1024.0; exit }' /proc/meminfo 2>/dev/null || echo "unknown"
    elif command -v sysctl >/dev/null 2>&1; then
        sysctl -n hw.memsize 2>/dev/null | awk '{ printf "%.2f", $1 / 1024.0 / 1024.0 / 1024.0 }' || echo "unknown"
    else
        echo "unknown"
    fi
}

cpu_governor() {
    if [ -f /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor ]; then
        cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo "unknown"
    else
        echo "unknown"
    fi
}

threads_info() {
    echo "${OMP_NUM_THREADS:-1}"
}

show_linkage() {
    local library="$1"
    if command -v ldd >/dev/null 2>&1; then
        ldd "${library}" 2>/dev/null | grep -Ei "blas|mkl|blis|openblas" || true
    elif command -v otool >/dev/null 2>&1; then
        otool -L "${library}" 2>/dev/null | grep -Ei "blas|mkl|blis|openblas" || true
    else
        echo "  (linkage inspection unavailable on this platform)"
    fi
}

now_seconds() {
    if command -v python3 >/dev/null 2>&1; then
        python3 -c 'import time; print(f"{time.time():.6f}")'
    else
        date +%s
    fi
}

measure_time() {
    local start end
    start="$(now_seconds)"
    "$@" >/dev/null 2>&1
    end="$(now_seconds)"
    awk -v s="${start}" -v e="${end}" 'BEGIN {printf "%.6f", e - s}'
}

run_graphblas_test() {
    if command -v timeout >/dev/null 2>&1; then
        timeout 60 ctest -R GraphBLAS -L quick --output-on-failure
    elif command -v gtimeout >/dev/null 2>&1; then
        gtimeout 60 ctest -R GraphBLAS -L quick --output-on-failure
    else
        ctest -R GraphBLAS -L quick --output-on-failure
    fi
}

append_timing() {
    local blas="$1"
    local test_name="$2"
    local value="$3"
    printf '%s,%s,%s\n' "${blas}" "${test_name}" "${value}" >> "${RESULTS_FILE}"
}

append_memory() {
    local blas="$1"
    local value="$2"
    printf '%s,%s\n' "${blas}" "${value}" >> "${MEMORY_FILE}"
}

record_memory_usage() {
    local build_name="$1"
    local mem_kb=""

    if [ -r /proc/$$/status ]; then
        mem_kb="$(awk '/VmPeak/{print $2; exit}' /proc/$$/status)"
    elif command -v ps >/dev/null 2>&1; then
        mem_kb="$(ps -o rss= -p $$ 2>/dev/null | awk '{print $1}')"
    fi

    if [[ -n "${mem_kb}" && "${mem_kb}" =~ ^[0-9]+$ ]]; then
        local mem_mb
        mem_mb="$(awk -v kb="${mem_kb}" 'BEGIN {printf "%.1f", kb / 1024}')"
        echo "${mem_mb} MB"
        append_memory "${build_name}" "${mem_mb}"
    else
        echo "N/A"
    fi
}

benchmark_build() {
    local build_name="$1"
    local build_dir="$2"

    echo -e "${YELLOW}=========================================="
    echo "Testing: ${build_name}"
    echo -e "==========================================${NC}"

    if [ ! -d "${build_dir}" ]; then
        echo -e "${RED}✗ Build directory not found: ${build_dir}${NC}"
        return 1
    fi

    pushd "${build_dir}" >/dev/null

    # Check BLAS linkage
    echo "BLAS libraries linked:"
    if [ -f AMD/libamd.so ]; then
        linked_output="$(show_linkage AMD/libamd.so)"
        if [ -n "${linked_output}" ]; then
            echo "${linked_output}" | sed 's/^/  /'
        else
            echo "  (none detected)"
        fi
    else
        echo "  AMD/libamd.so not found"
    fi
    echo ""

    echo -n "  AMD simple test...                "
    amd_time="$(measure_time ctest -R AMD_simple --output-on-failure)"
    printf "%8.3f sec\n" "${amd_time}"
    append_timing "${build_name}" "AMD_simple" "${amd_time}"

    if [ -f CHOLMOD/libcholmod.so ]; then
        echo -n "  CHOLMOD test...                   "
        cholmod_time="$(measure_time ctest -R CHOLMOD -L quick --output-on-failure)"
        printf "%8.3f sec\n" "${cholmod_time}"
        append_timing "${build_name}" "CHOLMOD_quick" "${cholmod_time}"
    fi

    if [ -f UMFPACK/libumfpack.so ]; then
        echo -n "  UMFPACK test...                   "
        umfpack_time="$(measure_time ctest -R UMFPACK -L quick --output-on-failure)"
        printf "%8.3f sec\n" "${umfpack_time}"
        append_timing "${build_name}" "UMFPACK_quick" "${umfpack_time}"
    fi

    if [ -f GraphBLAS/libgraphblas.so ]; then
        echo -n "  GraphBLAS matrix ops...           "
        if gb_time="$(measure_time run_graphblas_test)"; then
            printf "%8.3f sec\n" "${gb_time}"
            append_timing "${build_name}" "GraphBLAS_quick" "${gb_time}"
        else
            echo "timeout/fail"
        fi
    fi

    echo -n "  Peak memory usage...              "
    record_memory_usage "${build_name}"

    echo ""
    popd >/dev/null
}

build_vendor() {
    local label="$1"
    local script_path="$2"
    local log_path="$3"

    echo "Building with ${label}..."
    if "${script_path}" >"${log_path}" 2>&1; then
        echo -e "${GREEN}✓ ${label} build successful${NC}"
    else
        echo -e "${YELLOW}⚠ ${label} build failed (see ${log_path})${NC}"
    fi
    echo ""
}

CPU_MODEL="$(cpu_model)"
CPU_CORES="$(cpu_cores)"
CPU_VENDOR="$(cpu_vendor)"
HOSTNAME_INFO="$(hostname_info)"
KERNEL_INFO="$(kernel_info)"
MEM_TOTAL_GB="$(mem_total_gb)"
CPU_GOVERNOR="$(cpu_governor)"
THREADS="$(threads_info)"

echo -e "${BLUE}=========================================="
echo "SuiteSparse BLAS Benchmark Suite"
echo "=========================================="
echo -e "Host: ${GREEN}${HOSTNAME_INFO}${NC}"
echo -e "Kernel: ${GREEN}${KERNEL_INFO}${NC}"
echo -e "CPU: ${GREEN}${CPU_MODEL}${NC}"
echo -e "Vendor: ${GREEN}${CPU_VENDOR}${NC}"
echo -e "Cores: ${GREEN}${CPU_CORES}${NC}"
echo -e "Memory: ${GREEN}${MEM_TOTAL_GB} GB${NC}"
echo -e "CPU Governor: ${GREEN}${CPU_GOVERNOR}${NC}"
echo -e "Threads: ${GREEN}${THREADS}${NC}"
echo -e "Date: $(date)"
echo -e "==========================================${NC}"
echo ""

echo "Results will be saved to: ${RESULTS_FILE}"
echo "Memory data will be saved to: ${MEMORY_FILE}"
echo ""

printf 'BLAS,Test,Time_sec\n' > "${RESULTS_FILE}"
printf 'BLAS,Memory_MB\n' > "${MEMORY_FILE}"

echo -e "${GREEN}=========================================="
echo "Building all BLAS implementations..."
echo -e "==========================================${NC}"
echo ""

build_vendor "Intel MKL" "${SCRIPT_DIR}/build_mkl.sh" "${ROOT_DIR}/build_mkl.log"
build_vendor "OpenBLAS" "${SCRIPT_DIR}/build_openblas.sh" "${ROOT_DIR}/build_openblas.log"
build_vendor "BLIS" "${SCRIPT_DIR}/build_blis.sh" "${ROOT_DIR}/build_blis.log"

echo -e "${BLUE}Running warmup iteration...${NC}"
if [ -d "${ROOT_DIR}/build_openblas" ]; then
    pushd "${ROOT_DIR}/build_openblas" >/dev/null
    ctest -R AMD_simple --output-on-failure >/dev/null 2>&1 || true
    popd >/dev/null
fi
echo ""

echo -e "${GREEN}=========================================="
echo "Running Performance Benchmarks"
echo -e "==========================================${NC}"
echo ""

benchmark_build "Intel MKL" "${ROOT_DIR}/build_mkl" || true
benchmark_build "OpenBLAS" "${ROOT_DIR}/build_openblas" || true
benchmark_build "BLIS" "${ROOT_DIR}/build_blis" || true

echo -e "${BLUE}=========================================="
echo "Benchmark Results Summary"
echo -e "==========================================${NC}"
echo ""

if [ -f "${RESULTS_FILE}" ]; then
    echo "Detailed results: ${RESULTS_FILE}"
    echo ""

    for test in AMD_simple CHOLMOD_quick UMFPACK_quick GraphBLAS_quick; do
        echo -e "${YELLOW}${test}:${NC}"
        rows="$(grep ",${test}," "${RESULTS_FILE}" 2>/dev/null || true)"
        if [ -z "${rows}" ]; then
            echo "  (no results)"
        else
            while IFS=',' read -r blas test_name time; do
                printf "  %-15s %8.3f sec\n" "${blas}" "${time}"
            done <<< "${rows}"
        fi
        echo ""
    done

    echo -e "${YELLOW}Relative Performance (lower is better):${NC}"
    for test in AMD_simple CHOLMOD_quick UMFPACK_quick; do
        fastest="$(grep ",${test}," "${RESULTS_FILE}" 2>/dev/null | cut -d',' -f3 | sort -n | head -1 || true)"
        if [ -n "${fastest}" ]; then
            echo "  ${test} (baseline: ${fastest}s):"
            while IFS=',' read -r blas test_name time; do
                relative="$(awk -v t="${time}" -v f="${fastest}" 'BEGIN {printf "%.2f", t / f}')"
                printf "    %-15s %5.2fx\n" "${blas}" "${relative}"
            done < <(grep ",${test}," "${RESULTS_FILE}")
        fi
    done

    echo ""
    echo -e "${GREEN}=========================================="
    echo "Recommendation for current CPU"
    echo -e "==========================================${NC}"

    fastest_overall="$(awk -F',' '
        NR > 1 && ($2 == "AMD_simple" || $2 == "CHOLMOD_quick") {
            sum[$1] += $3; count[$1] += 1;
        }
        END {
            best_name = ""; best = 1e300;
            for (name in sum) {
                avg = sum[name] / count[name];
                if (avg < best) {
                    best = avg;
                    best_name = name;
                }
            }
            if (best_name != "") {
                print best_name;
            }
        }
    ' "${RESULTS_FILE}")"

    if [ -n "${fastest_overall}" ]; then
        echo -e "${GREEN}✓ Recommended: ${fastest_overall}${NC}"
    fi
else
    echo -e "${RED}✗ No results file found${NC}"
fi

echo ""
echo -e "${BLUE}=========================================="
echo "Benchmark Complete!"
echo -e "==========================================${NC}"
echo ""
echo "Build logs saved:"
echo "  - ${ROOT_DIR}/build_mkl.log"
echo "  - ${ROOT_DIR}/build_openblas.log"
echo "  - ${ROOT_DIR}/build_blis.log"
echo ""
echo "Results saved to: ${RESULTS_FILE}"
echo "Memory saved to: ${MEMORY_FILE}"
echo ""

echo -e "${BLUE}Saving results to database...${NC}"
if [ -f "${DB_SCRIPT}" ]; then
    if uv run python "${DB_SCRIPT}" import "${RESULTS_FILE}" \
        --memory-csv "${MEMORY_FILE}" \
        --cpu-model "${CPU_MODEL}" \
        --cpu-cores "${CPU_CORES}" \
        --cpu-vendor "${CPU_VENDOR}" \
        --hostname "${HOSTNAME_INFO}" \
        --kernel "${KERNEL_INFO}" \
        --memory-gb "${MEM_TOTAL_GB}" \
        --cpu-governor "${CPU_GOVERNOR}" \
        --threads "${THREADS}"; then
        echo -e "${GREEN}✓ Results saved to database${NC}"
        echo ""
        echo "View all runs: uv run python scripts/benchmark_db.py list"
    else
        echo -e "${YELLOW}⚠ Could not save to database (CSV files preserved)${NC}"
    fi
else
    echo -e "${YELLOW}⚠ Database script not found (CSV files preserved)${NC}"
fi
