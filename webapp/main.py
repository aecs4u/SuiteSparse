"""
SuiteSparse BLAS Benchmark Results Viewer
FastAPI webapp to visualize and compare BLAS performance
"""

from fastapi import FastAPI, Request
from fastapi.responses import HTMLResponse, JSONResponse
from fastapi.staticfiles import StaticFiles
from fastapi.templating import Jinja2Templates
from pathlib import Path
import sys
import csv
from typing import Dict, List, Optional
from collections import defaultdict
import glob
from datetime import datetime

# Add scripts directory to path for database import
sys.path.insert(0, str(Path(__file__).resolve().parent.parent / "scripts"))
try:
    from benchmark_db import BenchmarkDB
    DB_AVAILABLE = True
except ImportError:
    DB_AVAILABLE = False
    print("Warning: benchmark_db module not found, using CSV fallback")

app = FastAPI(
    title="SuiteSparse BLAS Benchmark Viewer",
    description="Interactive visualization of BLAS performance comparisons",
    version="1.0.0"
)

# Setup paths
BASE_DIR = Path(__file__).resolve().parent
RESULTS_DIR = BASE_DIR.parent / "benchmarks" / "results"
STATIC_DIR = BASE_DIR / "static"
TEMPLATES_DIR = BASE_DIR / "templates"
DB_PATH = str(RESULTS_DIR / "suitesparse_benchmarks.sqlite")

# Mount static files and templates
app.mount("/static", StaticFiles(directory=str(STATIC_DIR)), name="static")
templates = Jinja2Templates(directory=str(TEMPLATES_DIR))


def get_db() -> Optional[BenchmarkDB]:
    """Get database connection if available"""
    if DB_AVAILABLE and Path(DB_PATH).exists():
        return BenchmarkDB(DB_PATH)
    return None


def load_from_database() -> List[Dict]:
    """Load benchmark results from SQLite database"""
    db = get_db()
    if not db:
        return []

    try:
        runs = db.get_all_runs()
        results = []

        for run in runs:
            run_results = db.get_run_results(run['id'])
            memory_rows = db.get_run_memory(run['id'])

            # Convert to CSV-like format for compatibility
            data = []
            for result in run_results:
                data.append({
                    'BLAS': result['blas_vendor'],
                    'Test': result['test_name'],
                    'Time_sec': str(result['time_sec'])
                })

            memory_data = {
                row['blas_vendor']: row['memory_mb']
                for row in memory_rows
                if row.get('memory_mb') is not None
            }

            results.append({
                'filename': f"Run {run['id']} ({run['timestamp'][:10]})",
                'timestamp': run['timestamp'][:19] if 'T' in run['timestamp'] else run['timestamp'],
                'data': data,
                'memory': memory_data,
                'run_id': run['id'],
                'cpu_model': run['cpu_model'],
                'cpu_cores': run['cpu_cores'],
                'cpu_vendor': run['cpu_vendor'],
                'hostname': run.get('hostname'),
                'kernel': run.get('kernel'),
                'memory_gb': run.get('memory_gb'),
                'cpu_governor': run.get('cpu_governor'),
                'threads': run.get('threads')
            })

        return results
    finally:
        if db:
            db.close()


def load_benchmark_results() -> List[Dict]:
    """Load benchmark results from database (preferred) or CSV files (fallback)"""
    # Try database first
    if DB_AVAILABLE:
        db_results = load_from_database()
        if db_results:
            return db_results

    # Fallback to CSV files
    results = []
    pattern = str(RESULTS_DIR / "benchmark_results_*.txt")

    for filepath in sorted(glob.glob(pattern), reverse=True):
        try:
            with open(filepath, 'r') as f:
                reader = csv.DictReader(f)
                timing_data: List[Dict] = []
                memory_data: Dict[str, float] = {}

                for row in reader:
                    blas = row.get('BLAS', 'Unknown')
                    test = row.get('Test', 'Unknown')
                    value = row.get('Time_sec', '')

                    # Keep legacy memory rows outside timing charts
                    if test == 'Memory_MB' or test.endswith('_MB'):
                        try:
                            memory_data[blas] = float(value)
                        except (TypeError, ValueError):
                            pass
                        continue

                    timing_data.append({
                        'BLAS': blas,
                        'Test': test,
                        'Time_sec': value
                    })

                if timing_data or memory_data:
                    results.append({
                        'filename': Path(filepath).name,
                        'timestamp': extract_timestamp(Path(filepath).name),
                        'data': timing_data,
                        'memory': memory_data,
                        'path': filepath
                    })
        except Exception as e:
            print(f"Error loading {filepath}: {e}")

    return results


def extract_timestamp(filename: str) -> str:
    """Extract timestamp from filename like benchmark_results_20250209_120000.txt"""
    try:
        # Extract YYYYMMDD_HHMMSS
        parts = filename.replace('benchmark_results_', '').replace('.txt', '').split('_')
        if len(parts) >= 2:
            date_str = parts[0]  # YYYYMMDD
            time_str = parts[1]  # HHMMSS
            dt = datetime.strptime(f"{date_str}{time_str}", "%Y%m%d%H%M%S")
            return dt.strftime("%Y-%m-%d %H:%M:%S")
    except:
        pass
    return filename


def parse_results(data: List[Dict]) -> Dict:
    """Parse benchmark data into structured format for visualization"""
    # Group by BLAS implementation
    by_blas = defaultdict(dict)
    tests = set()

    for row in data:
        blas = row.get('BLAS', 'Unknown')
        test = row.get('Test', 'Unknown')
        if test == 'Memory_MB' or test.endswith('_MB'):
            continue
        try:
            time = float(row.get('Time_sec', 0))
        except (TypeError, ValueError):
            continue

        tests.add(test)
        by_blas[blas][test] = time

    return {
        'blas_implementations': list(by_blas.keys()),
        'tests': sorted(list(tests)),
        'data': dict(by_blas)
    }


def calculate_speedup(data: Dict) -> Dict:
    """Calculate relative speedup (baseline = slowest)"""
    speedup = {}

    for test in data['tests']:
        times = []
        for blas in data['blas_implementations']:
            if test in data['data'][blas]:
                times.append((blas, data['data'][blas][test]))

        if times:
            # Use slowest as baseline (100%)
            slowest_time = max(t[1] for t in times)
            speedup[test] = {
                blas: (slowest_time / time) * 100
                for blas, time in times
            }

    return speedup


@app.get("/", response_class=HTMLResponse)
async def root(request: Request):
    """Landing page with overview and statistics"""
    return templates.TemplateResponse(
        "home.html",
        {"request": request}
    )


@app.get("/results", response_class=HTMLResponse)
async def results_page(request: Request):
    """Benchmark results visualization page"""
    results = load_benchmark_results()

    return templates.TemplateResponse(
        "results.html",
        {
            "request": request,
            "results_count": len(results),
            "latest_result": results[0] if results else None
        }
    )


@app.get("/modules", response_class=HTMLResponse)
async def modules_page(request: Request):
    """SuiteSparse modules information page"""
    return templates.TemplateResponse(
        "modules.html",
        {"request": request}
    )


@app.get("/benchmarks", response_class=HTMLResponse)
async def benchmarks_page(request: Request):
    """Benchmark tests listing page"""
    return templates.TemplateResponse(
        "benchmarks.html",
        {"request": request}
    )


@app.get("/c23-migration", response_class=HTMLResponse)
async def c23_migration_page(request: Request):
    """C23 modernization guide and migration information"""
    return templates.TemplateResponse(
        "c23_migration.html",
        {"request": request}
    )


@app.get("/benchmarks/{benchmark_code}", response_class=HTMLResponse)
async def benchmark_detail_page(request: Request, benchmark_code: str):
    """Detailed view of a specific benchmark with execution history"""
    return templates.TemplateResponse(
        "benchmark_detail.html",
        {
            "request": request,
            "benchmark_code": benchmark_code
        }
    )


@app.get("/results/{result_code:path}", response_class=HTMLResponse)
async def result_detail_page(request: Request, result_code: str):
    """Detailed view of a specific benchmark run execution"""
    return templates.TemplateResponse(
        "result_detail.html",
        {
            "request": request,
            "result_code": result_code
        }
    )


@app.get("/runs", response_class=HTMLResponse)
async def runs_page(request: Request):
    """Benchmark runs history page"""
    return templates.TemplateResponse(
        "runs.html",
        {"request": request}
    )


@app.get("/systems", response_class=HTMLResponse)
async def systems_page(request: Request):
    """Systems/hardware information page"""
    return templates.TemplateResponse(
        "systems.html",
        {"request": request}
    )


@app.get("/api/results")
async def api_results():
    """Get list of all benchmark results"""
    results = load_benchmark_results()
    return JSONResponse([
        {
            'filename': r['filename'],
            'timestamp': r['timestamp'],
            'num_tests': len(r['data']),
            'cpu_model': r.get('cpu_model'),
            'cpu_cores': r.get('cpu_cores'),
            'blas_vendors': sorted(list(set(row.get('BLAS') for row in r['data'] if row.get('BLAS'))))
        }
        for r in results
    ])


@app.get("/api/results/{filename:path}")
async def api_result_detail(filename: str):
    """Get detailed data for a specific benchmark result"""
    results = load_benchmark_results()

    for result in results:
        if result['filename'] == filename:
            parsed = parse_results(result['data'])
            speedup = calculate_speedup(parsed)

            return JSONResponse({
                'metadata': {
                    'filename': result['filename'],
                    'timestamp': result['timestamp'],
                    'memory': result.get('memory', {}),
                    'cpu_model': result.get('cpu_model'),
                    'cpu_cores': result.get('cpu_cores'),
                    'cpu_vendor': result.get('cpu_vendor'),
                    'hostname': result.get('hostname'),
                    'kernel': result.get('kernel'),
                    'memory_gb': result.get('memory_gb'),
                    'cpu_governor': result.get('cpu_governor'),
                    'threads': result.get('threads')
                },
                'results': parsed,
                'speedup': speedup
            })

    return JSONResponse({"error": "Result not found"}, status_code=404)


@app.get("/api/latest")
async def api_latest():
    """Get the most recent benchmark result"""
    results = load_benchmark_results()

    if not results:
        return JSONResponse({"error": "No results found"}, status_code=404)

    latest = results[0]
    parsed = parse_results(latest['data'])
    speedup = calculate_speedup(parsed)

    return JSONResponse({
        'metadata': {
            'filename': latest['filename'],
            'timestamp': latest['timestamp'],
            'memory': latest.get('memory', {})
        },
        'results': parsed,
        'speedup': speedup
    })


@app.get("/api/compare")
async def api_compare():
    """Compare all benchmark runs over time"""
    results = load_benchmark_results()

    if not results:
        return JSONResponse({"error": "No results found"}, status_code=404)

    comparison = {
        'timestamps': [],
        'blas_data': defaultdict(lambda: defaultdict(list))
    }

    for result in reversed(results):  # Chronological order
        comparison['timestamps'].append(result['timestamp'])

        for row in result['data']:
            blas = row.get('BLAS', 'Unknown')
            test = row.get('Test', 'Unknown')
            if test == 'Memory_MB' or test.endswith('_MB'):
                continue
            try:
                time = float(row.get('Time_sec', 0))
            except (TypeError, ValueError):
                continue

            comparison['blas_data'][blas][test].append(time)

    return JSONResponse(dict(comparison))


@app.get("/api/stats")
async def api_stats():
    """Get database statistics"""
    if not DB_AVAILABLE:
        return JSONResponse({"error": "Database not available"}, status_code=503)

    db = get_db()
    if not db:
        return JSONResponse({"error": "Database not initialized"}, status_code=404)

    try:
        runs = db.get_all_runs()

        # Collect unique BLAS vendors and tests
        blas_vendors = set()
        test_names = set()

        for run in runs:
            results = db.get_run_results(run['id'])
            for result in results:
                blas_vendors.add(result['blas_vendor'])
                test_names.add(result['test_name'])

        return JSONResponse({
            'total_runs': len(runs),
            'blas_vendors': sorted(list(blas_vendors)),
            'test_names': sorted(list(test_names)),
            'latest_run': runs[0] if runs else None
        })
    finally:
        if db:
            db.close()


@app.get("/api/benchmarks/{benchmark_code}/compare")
async def api_benchmark_compare(benchmark_code: str):
    """Get comparison data for a specific benchmark across all runs"""
    if not DB_AVAILABLE:
        return JSONResponse({"error": "Database not available"}, status_code=503)

    db = get_db()
    if not db:
        return JSONResponse({"error": "Database not initialized"}, status_code=404)

    try:
        # Use the compare_blas method from BenchmarkDB
        comparison_data = db.compare_blas(benchmark_code, limit=100)

        if not comparison_data:
            return JSONResponse({"error": f"No data found for benchmark: {benchmark_code}"}, status_code=404)

        return JSONResponse(comparison_data)
    finally:
        if db:
            db.close()


@app.get("/api/systems")
async def api_systems():
    """Get information about all systems that have run benchmarks"""
    if not DB_AVAILABLE:
        return JSONResponse({"error": "Database not available"}, status_code=503)

    db = get_db()
    if not db:
        return JSONResponse({"error": "Database not initialized"}, status_code=404)

    try:
        runs = db.get_all_runs()

        if not runs:
            return JSONResponse({"systems": [], "performance_by_system": []})

        # Group runs by system (cpu_model)
        systems_data = {}
        for run in runs:
            cpu_model = run['cpu_model']
            if cpu_model not in systems_data:
                systems_data[cpu_model] = {
                    'cpu_model': cpu_model,
                    'cpu_vendor': run['cpu_vendor'],
                    'cpu_cores': run['cpu_cores'],
                    'hostname': run.get('hostname'),
                    'kernel': run.get('kernel'),
                    'memory_gb': run.get('memory_gb'),
                    'cpu_governor': run.get('cpu_governor'),
                    'threads': run.get('threads'),
                    'total_runs': 0,
                    'latest_run': run['timestamp'],
                    'blas_vendors': set()
                }

            systems_data[cpu_model]['total_runs'] += 1

            # Update latest run if this one is newer or equal
            if run['timestamp'] >= systems_data[cpu_model]['latest_run']:
                systems_data[cpu_model]['latest_run'] = run['timestamp']

            # Update system info from any run that has the data (prefer non-null values)
            if run.get('hostname'):
                systems_data[cpu_model]['hostname'] = run.get('hostname')
            if run.get('kernel'):
                systems_data[cpu_model]['kernel'] = run.get('kernel')
            if run.get('memory_gb'):
                systems_data[cpu_model]['memory_gb'] = run.get('memory_gb')
            if run.get('cpu_governor'):
                systems_data[cpu_model]['cpu_governor'] = run.get('cpu_governor')
            if run.get('threads'):
                systems_data[cpu_model]['threads'] = run.get('threads')

            # Collect unique BLAS vendors tested on this system
            results = db.get_run_results(run['id'])
            for result in results:
                systems_data[cpu_model]['blas_vendors'].add(result['blas_vendor'])

        # Convert to list and sort by latest run
        systems_list = []
        for system in systems_data.values():
            system['blas_vendors'] = sorted(list(system['blas_vendors']))
            systems_list.append(system)

        systems_list.sort(key=lambda x: x['latest_run'], reverse=True)

        # Calculate average performance by system and BLAS vendor
        performance_data = []
        for system in systems_list:
            for blas in system['blas_vendors']:
                # Get all times for this system/BLAS combination
                times = []
                for run in runs:
                    if run['cpu_model'] == system['cpu_model']:
                        results = db.get_run_results(run['id'])
                        for result in results:
                            if result['blas_vendor'] == blas and result['time_sec'] is not None:
                                times.append(result['time_sec'])

                if times:
                    performance_data.append({
                        'cpu_model': system['cpu_model'],
                        'blas_vendor': blas,
                        'avg_time': sum(times) / len(times),
                        'min_time': min(times),
                        'max_time': max(times),
                        'num_samples': len(times)
                    })

        return JSONResponse({
            'systems': systems_list,
            'performance_by_system': performance_data
        })

    finally:
        if db:
            db.close()


@app.get("/health")
async def health():
    """Health check endpoint"""
    db_status = "available" if (DB_AVAILABLE and Path(DB_PATH).exists()) else "unavailable"
    return {
        "status": "healthy",
        "service": "SuiteSparse BLAS Benchmark Viewer",
        "database": db_status
    }


if __name__ == "__main__":
    import uvicorn
    import os

    # Default port is 9001, but can be overridden with PORT environment variable
    port = int(os.environ.get("PORT", 9001))
    uvicorn.run(app, host="0.0.0.0", port=port, reload=True)
