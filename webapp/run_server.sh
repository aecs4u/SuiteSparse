#!/bin/bash
#===============================================================================
# run_server.sh: Start the SuiteSparse BLAS Benchmark Viewer webapp
#===============================================================================

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd "$SCRIPT_DIR"

echo "=========================================="
echo "SuiteSparse BLAS Benchmark Viewer"
echo "=========================================="
echo ""

# Check if uv is available
if ! command -v uv &> /dev/null; then
    echo "Error: uv is not installed"
    echo "Install with: curl -LsSf https://astral.sh/uv/install.sh | sh"
    exit 1
fi

# Check if benchmark results exist
RESULTS_COUNT=$(ls ../benchmarks/results/benchmark_results_*.txt 2>/dev/null | wc -l)
DB_PRESENT=0
if [ -f ../benchmarks/results/benchmark.db ]; then
    DB_PRESENT=1
fi
if [ "$RESULTS_COUNT" -eq 0 ] && [ "$DB_PRESENT" -eq 0 ]; then
    echo "⚠️  Warning: No benchmark results found"
    echo "   Run '../scripts/benchmark_blas.sh' first to generate results"
    echo ""
fi

PORT="${PORT:-9001}"

echo "Starting server..."
echo "  Host: http://0.0.0.0:${PORT}"
echo "  Local: http://localhost:${PORT}"
echo "  Results found: $RESULTS_COUNT"
echo ""
echo "Press Ctrl+C to stop the server"
echo "=========================================="
echo ""

# Run with uv
exec uv run uvicorn main:app --host 0.0.0.0 --port "${PORT}" --reload
