#!/usr/bin/env -S uv run python
"""
analyze_results.py: Generate visual comparison of BLAS benchmark results
"""

import sys
import csv
from collections import defaultdict

def load_results(filename):
    """Load benchmark results from CSV"""
    data = defaultdict(dict)
    try:
        with open(filename, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                blas = row['BLAS']
                test = row['Test']
                time = float(row['Time_sec'])
                data[blas][test] = time
    except FileNotFoundError:
        print(f"Error: Results file '{filename}' not found")
        sys.exit(1)
    except Exception as e:
        print(f"Error reading results: {e}")
        sys.exit(1)

    return data

def create_bar_chart(data, test_name):
    """Create ASCII bar chart for a test"""
    if not any(test_name in tests for tests in data.values()):
        return

    times = {blas: tests.get(test_name, 0) for blas, tests in data.items() if test_name in tests}
    if not times:
        return

    max_time = max(times.values())
    min_time = min(times.values())

    print(f"\n{test_name}")
    print("=" * 60)

    # Sort by time (fastest first)
    sorted_times = sorted(times.items(), key=lambda x: x[1])

    for i, (blas, time) in enumerate(sorted_times):
        # Calculate bar length (max 40 chars)
        bar_length = int((time / max_time) * 40) if max_time > 0 else 0
        bar = "█" * bar_length

        # Relative speed
        relative = time / min_time if min_time > 0 else 1.0

        # Color coding
        if i == 0:
            marker = "🥇"  # Gold
        elif i == 1:
            marker = "🥈"  # Silver
        elif i == 2:
            marker = "🥉"  # Bronze
        else:
            marker = "  "

        print(f"{marker} {blas:15s} {bar:40s} {time:7.3f}s  ({relative:.2f}x)")

    print()

def main():
    if len(sys.argv) < 2:
        print("Usage: uv run python analyze_results.py <results_file.txt>")
        print("\nExample:")
        print("  uv run python analyze_results.py benchmark_results_20250209_120000.txt")
        sys.exit(1)

    results_file = sys.argv[1]

    print("=" * 60)
    print("SuiteSparse BLAS Performance Analysis")
    print("=" * 60)

    data = load_results(results_file)

    if not data:
        print("No benchmark data found in results file")
        sys.exit(1)

    # Get all test names
    all_tests = set()
    for tests in data.values():
        all_tests.update(tests.keys())

    # Remove non-timing tests
    timing_tests = [t for t in sorted(all_tests) if not t.startswith('Memory')]

    # Create bar charts for each test
    for test in timing_tests:
        create_bar_chart(data, test)

    # Overall winner
    print("\n" + "=" * 60)
    print("OVERALL COMPARISON")
    print("=" * 60)

    overall_avg = {}
    for blas, tests in data.items():
        timing_values = [t for k, t in tests.items() if not k.startswith('Memory')]
        if timing_values:
            overall_avg[blas] = sum(timing_values) / len(timing_values)

    if overall_avg:
        sorted_avg = sorted(overall_avg.items(), key=lambda x: x[1])
        fastest = sorted_avg[0][0]
        fastest_time = sorted_avg[0][1]

        print("\nAverage performance (all tests):")
        for i, (blas, avg_time) in enumerate(sorted_avg):
            relative = avg_time / fastest_time
            stars = "★" * (4 - i) if i < 4 else ""
            print(f"  {i+1}. {blas:15s}  {avg_time:7.3f}s avg  ({relative:.2f}x)  {stars}")

        print(f"\n🏆 Fastest overall: {fastest}")
        print(f"   Average time: {fastest_time:.3f}s")

        # Recommendation based on CPU
        print("\n" + "=" * 60)
        print("RECOMMENDATION")
        print("=" * 60)
        print(f"\nFor production use with SuiteSparse, we recommend:")
        print(f"  → {fastest}")
        print()

        if fastest == "OpenBLAS":
            print("OpenBLAS is mature, widely used, and provides excellent")
            print("performance across different CPU architectures.")
        elif fastest == "BLIS":
            print("BLIS is highly optimized for AMD CPUs and shows")
            print("superior performance on Ryzen processors.")
        elif fastest == "Intel MKL":
            print("Intel MKL provides strong performance even on non-Intel CPUs")
            print("due to its mature optimization and wide hardware support.")

        print("\nTo use this BLAS permanently:")
        print(f"  cd build_{fastest.lower()}")
        print(f"  sudo cmake --install .")

if __name__ == "__main__":
    main()
