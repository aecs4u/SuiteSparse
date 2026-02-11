#!/usr/bin/env python3
"""
benchmark_db.py: SQLite database management for SuiteSparse BLAS benchmarks

Provides functions to:
- Initialize database schema
- Insert benchmark runs and results
- Query historical data
- Export to CSV for compatibility
"""

import sqlite3
import sys
from pathlib import Path
from datetime import datetime
from typing import Optional, List, Dict, Tuple
import csv


class BenchmarkDB:
    """Manage SQLite database for benchmark results"""

    def __init__(self, db_path: Optional[str] = None):
        """Initialize database connection

        Args:
            db_path: Path to SQLite database file. If None, uses default location.
        """
        if db_path is None:
            # Default location: benchmarks/results/suitesparse_benchmarks.sqlite
            script_dir = Path(__file__).parent
            results_dir = script_dir.parent / "benchmarks" / "results"
            results_dir.mkdir(parents=True, exist_ok=True)
            db_path = str(results_dir / "suitesparse_benchmarks.sqlite")

        self.db_path = db_path
        self.conn = sqlite3.connect(db_path)
        self.conn.row_factory = sqlite3.Row  # Allow dict-like access
        self._init_schema()

    def _init_schema(self):
        """Create database tables if they don't exist"""
        cursor = self.conn.cursor()

        # Table for benchmark runs (metadata)
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS benchmark_runs (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                timestamp TEXT NOT NULL,
                cpu_model TEXT NOT NULL,
                cpu_cores INTEGER NOT NULL,
                cpu_vendor TEXT NOT NULL,
                hostname TEXT,
                kernel TEXT,
                memory_gb TEXT,
                cpu_governor TEXT,
                threads INTEGER,
                script_version TEXT DEFAULT '1.0',
                notes TEXT
            )
        """)

        # Add new columns if they don't exist (for existing databases)
        try:
            cursor.execute("ALTER TABLE benchmark_runs ADD COLUMN hostname TEXT")
        except:
            pass
        try:
            cursor.execute("ALTER TABLE benchmark_runs ADD COLUMN kernel TEXT")
        except:
            pass
        try:
            cursor.execute("ALTER TABLE benchmark_runs ADD COLUMN memory_gb TEXT")
        except:
            pass
        try:
            cursor.execute("ALTER TABLE benchmark_runs ADD COLUMN cpu_governor TEXT")
        except:
            pass
        try:
            cursor.execute("ALTER TABLE benchmark_runs ADD COLUMN threads INTEGER")
        except:
            pass

        # Table for individual test results
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS benchmark_results (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id INTEGER NOT NULL,
                blas_vendor TEXT NOT NULL,
                test_name TEXT NOT NULL,
                time_sec REAL,
                memory_mb REAL,
                FOREIGN KEY (run_id) REFERENCES benchmark_runs(id)
            )
        """)

        # Table for memory metrics, stored separately from timing tests
        cursor.execute("""
            CREATE TABLE IF NOT EXISTS benchmark_memory (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                run_id INTEGER NOT NULL,
                blas_vendor TEXT NOT NULL,
                memory_mb REAL NOT NULL,
                FOREIGN KEY (run_id) REFERENCES benchmark_runs(id)
            )
        """)

        # Indexes for fast queries
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_results_run_id
            ON benchmark_results(run_id)
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_results_blas
            ON benchmark_results(blas_vendor)
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_results_test
            ON benchmark_results(test_name)
        """)
        cursor.execute("""
            CREATE INDEX IF NOT EXISTS idx_memory_run_id
            ON benchmark_memory(run_id)
        """)

        self.conn.commit()

    def add_benchmark_run(
        self,
        cpu_model: str,
        cpu_cores: int,
        cpu_vendor: str,
        timestamp: Optional[str] = None,
        notes: Optional[str] = None,
        hostname: Optional[str] = None,
        kernel: Optional[str] = None,
        memory_gb: Optional[str] = None,
        cpu_governor: Optional[str] = None,
        threads: Optional[int] = None
    ) -> int:
        """Add a new benchmark run

        Args:
            cpu_model: CPU model name
            cpu_cores: Number of CPU cores
            cpu_vendor: CPU vendor (Intel, AMD, etc.)
            timestamp: ISO format timestamp (default: now)
            notes: Optional notes about this run
            hostname: System hostname
            kernel: Kernel version (e.g., from uname -sr)
            memory_gb: Total system memory in GB
            cpu_governor: CPU frequency governor
            threads: Number of threads used

        Returns:
            run_id: ID of the inserted run
        """
        if timestamp is None:
            timestamp = datetime.now().isoformat()

        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO benchmark_runs
            (timestamp, cpu_model, cpu_cores, cpu_vendor, hostname, kernel, memory_gb, cpu_governor, threads, notes)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        """, (timestamp, cpu_model, cpu_cores, cpu_vendor, hostname, kernel, memory_gb, cpu_governor, threads, notes))

        self.conn.commit()
        return cursor.lastrowid

    def add_result(
        self,
        run_id: int,
        blas_vendor: str,
        test_name: str,
        time_sec: Optional[float] = None,
        memory_mb: Optional[float] = None
    ):
        """Add a benchmark result

        Args:
            run_id: ID of the benchmark run
            blas_vendor: BLAS implementation name
            test_name: Test name
            time_sec: Execution time in seconds
            memory_mb: Memory usage in MB
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO benchmark_results
            (run_id, blas_vendor, test_name, time_sec, memory_mb)
            VALUES (?, ?, ?, ?, ?)
        """, (run_id, blas_vendor, test_name, time_sec, memory_mb))

        self.conn.commit()

    def add_memory_result(
        self,
        run_id: int,
        blas_vendor: str,
        memory_mb: float
    ):
        """Add a memory measurement for a benchmark run."""
        cursor = self.conn.cursor()
        cursor.execute("""
            INSERT INTO benchmark_memory (run_id, blas_vendor, memory_mb)
            VALUES (?, ?, ?)
        """, (run_id, blas_vendor, memory_mb))
        self.conn.commit()

    def import_csv(
        self,
        csv_path: str,
        cpu_model: str,
        cpu_cores: int,
        cpu_vendor: str,
        notes: Optional[str] = None,
        memory_csv: Optional[str] = None,
        hostname: Optional[str] = None,
        kernel: Optional[str] = None,
        memory_gb: Optional[str] = None,
        cpu_governor: Optional[str] = None,
        threads: Optional[int] = None
    ) -> int:
        """Import results from CSV file

        Args:
            csv_path: Path to CSV file
            cpu_model: CPU model name
            cpu_cores: Number of CPU cores
            cpu_vendor: CPU vendor
            notes: Optional notes
            memory_csv: Optional memory CSV file
            hostname: System hostname
            kernel: Kernel version
            memory_gb: Total system memory
            cpu_governor: CPU governor
            threads: Number of threads

        Returns:
            run_id: ID of the imported run
        """
        # Extract timestamp from filename if possible
        csv_file = Path(csv_path)
        timestamp = None
        if "benchmark_results_" in csv_file.name:
            try:
                # Extract from filename: benchmark_results_20260210_074457.txt
                date_str = csv_file.stem.split("_")[-2:]
                timestamp = datetime.strptime(
                    f"{date_str[0]}_{date_str[1]}",
                    "%Y%m%d_%H%M%S"
                ).isoformat()
            except:
                pass

        # Create run
        run_id = self.add_benchmark_run(
            cpu_model, cpu_cores, cpu_vendor, timestamp, notes,
            hostname, kernel, memory_gb, cpu_governor, threads
        )

        # Read timing CSV and import results
        with open(csv_path, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                blas = row['BLAS']
                test = row['Test']
                time_val = row['Time_sec']

                # Ignore legacy memory pseudo-tests in timing imports
                if test.endswith('_MB') or test == 'Memory_MB':
                    continue

                try:
                    self.add_result(
                        run_id, blas, test,
                        time_sec=float(time_val),
                        memory_mb=None
                    )
                except (TypeError, ValueError):
                    continue

        if memory_csv:
            self.import_memory_csv(run_id, memory_csv)

        return run_id

    def import_memory_csv(self, run_id: int, memory_csv: str):
        """Import memory metrics from BLAS,Memory_MB CSV format."""
        with open(memory_csv, 'r') as f:
            reader = csv.DictReader(f)
            for row in reader:
                blas = row.get('BLAS')
                mem = row.get('Memory_MB')
                if not blas or mem is None:
                    continue
                try:
                    self.add_memory_result(run_id, blas, float(mem))
                except (TypeError, ValueError):
                    continue

    def get_all_runs(self) -> List[Dict]:
        """Get all benchmark runs

        Returns:
            List of run dictionaries
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT * FROM benchmark_runs
            ORDER BY timestamp DESC
        """)
        return [dict(row) for row in cursor.fetchall()]

    def get_run_results(self, run_id: int) -> List[Dict]:
        """Get all results for a specific run

        Args:
            run_id: Benchmark run ID

        Returns:
            List of result dictionaries
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT * FROM benchmark_results
            WHERE run_id = ?
              AND time_sec IS NOT NULL
              AND test_name NOT LIKE '%_MB'
            ORDER BY blas_vendor, test_name
        """, (run_id,))
        return [dict(row) for row in cursor.fetchall()]

    def get_run_memory(self, run_id: int) -> List[Dict]:
        """Get memory results for a specific run.

        Supports both the new benchmark_memory table and legacy rows stored
        in benchmark_results as Memory_MB pseudo-tests.
        """
        cursor = self.conn.cursor()

        cursor.execute("""
            SELECT blas_vendor, memory_mb
            FROM benchmark_memory
            WHERE run_id = ?
            ORDER BY blas_vendor
        """, (run_id,))
        memory_rows = [dict(row) for row in cursor.fetchall()]
        if memory_rows:
            return memory_rows

        cursor.execute("""
            SELECT blas_vendor, memory_mb
            FROM benchmark_results
            WHERE run_id = ?
              AND memory_mb IS NOT NULL
              AND test_name LIKE '%_MB'
            ORDER BY blas_vendor
        """, (run_id,))
        return [dict(row) for row in cursor.fetchall()]

    def get_latest_run(self) -> Optional[Dict]:
        """Get the most recent benchmark run

        Returns:
            Run dictionary or None
        """
        runs = self.get_all_runs()
        return runs[0] if runs else None

    def compare_blas(
        self,
        test_name: str,
        limit: int = 10
    ) -> List[Dict]:
        """Compare BLAS implementations for a specific test

        Args:
            test_name: Name of the test
            limit: Maximum number of recent runs to include

        Returns:
            List of comparison data
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                br.run_id,
                br.blas_vendor,
                br.test_name,
                br.time_sec,
                br.memory_mb,
                run.timestamp,
                run.cpu_model
            FROM benchmark_results br
            JOIN benchmark_runs run ON br.run_id = run.id
            WHERE br.test_name = ?
              AND br.time_sec IS NOT NULL
            ORDER BY run.timestamp DESC, br.time_sec ASC
            LIMIT ?
        """, (test_name, limit * 10))  # Get more rows, filter later

        return [dict(row) for row in cursor.fetchall()]

    def get_statistics(self, test_name: str, blas_vendor: str) -> Dict:
        """Get statistics for a specific test and BLAS vendor

        Args:
            test_name: Name of the test
            blas_vendor: BLAS implementation name

        Returns:
            Dictionary with min, max, avg, count
        """
        cursor = self.conn.cursor()
        cursor.execute("""
            SELECT
                MIN(time_sec) as min_time,
                MAX(time_sec) as max_time,
                AVG(time_sec) as avg_time,
                COUNT(*) as count
            FROM benchmark_results
            WHERE test_name = ? AND blas_vendor = ? AND time_sec IS NOT NULL
        """, (test_name, blas_vendor))

        row = cursor.fetchone()
        return dict(row) if row else {}

    def export_to_csv(self, run_id: int, output_path: str):
        """Export a benchmark run to CSV format

        Args:
            run_id: Benchmark run ID
            output_path: Output CSV file path
        """
        results = self.get_run_results(run_id)

        with open(output_path, 'w', newline='') as f:
            writer = csv.writer(f)
            writer.writerow(['BLAS', 'Test', 'Time_sec'])

            for result in results:
                blas = result['blas_vendor']
                test = result['test_name']
                # Use time_sec if available, otherwise memory_mb
                value = result['time_sec'] if result['time_sec'] is not None else result['memory_mb']
                writer.writerow([blas, test, value])

    def close(self):
        """Close database connection"""
        self.conn.close()


def main():
    """Command-line interface for database operations"""
    import argparse

    parser = argparse.ArgumentParser(
        description='SuiteSparse BLAS Benchmark Database Manager'
    )
    subparsers = parser.add_subparsers(dest='command', help='Command to execute')

    # Import CSV command
    import_parser = subparsers.add_parser('import', help='Import CSV file')
    import_parser.add_argument('csv_file', help='Path to CSV file')
    import_parser.add_argument('--cpu-model', required=True, help='CPU model name')
    import_parser.add_argument('--cpu-cores', type=int, required=True, help='Number of CPU cores')
    import_parser.add_argument('--cpu-vendor', required=True, help='CPU vendor')
    import_parser.add_argument('--notes', help='Optional notes')
    import_parser.add_argument('--memory-csv', help='Optional BLAS memory CSV file')
    import_parser.add_argument('--hostname', help='System hostname')
    import_parser.add_argument('--kernel', help='Kernel version')
    import_parser.add_argument('--memory-gb', help='Total system memory in GB')
    import_parser.add_argument('--cpu-governor', help='CPU frequency governor')
    import_parser.add_argument('--threads', type=int, help='Number of threads used')
    import_parser.add_argument('--db', help='Database path')

    # List runs command
    list_parser = subparsers.add_parser('list', help='List all benchmark runs')
    list_parser.add_argument('--db', help='Database path')

    # Show run command
    show_parser = subparsers.add_parser('show', help='Show results for a run')
    show_parser.add_argument('run_id', type=int, help='Run ID')
    show_parser.add_argument('--db', help='Database path')

    # Export command
    export_parser = subparsers.add_parser('export', help='Export run to CSV')
    export_parser.add_argument('run_id', type=int, help='Run ID')
    export_parser.add_argument('output', help='Output CSV file')
    export_parser.add_argument('--db', help='Database path')

    # Compare command
    compare_parser = subparsers.add_parser('compare', help='Compare BLAS for a test')
    compare_parser.add_argument('test_name', help='Test name')
    compare_parser.add_argument('--limit', type=int, default=10, help='Number of runs')
    compare_parser.add_argument('--db', help='Database path')

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        return 1

    # Initialize database
    db = BenchmarkDB(args.db)

    try:
        if args.command == 'import':
            run_id = db.import_csv(
                args.csv_file,
                args.cpu_model,
                args.cpu_cores,
                args.cpu_vendor,
                args.notes,
                args.memory_csv,
                args.hostname,
                args.kernel,
                args.memory_gb,
                args.cpu_governor,
                args.threads
            )
            print(f"✓ Imported run ID: {run_id}")

        elif args.command == 'list':
            runs = db.get_all_runs()
            if not runs:
                print("No benchmark runs found")
            else:
                print(f"{'ID':<5} {'Timestamp':<20} {'CPU Model':<30} {'Cores':<6}")
                print("-" * 70)
                for run in runs:
                    timestamp = run['timestamp'][:19]  # Trim microseconds
                    print(f"{run['id']:<5} {timestamp:<20} {run['cpu_model']:<30} {run['cpu_cores']:<6}")

        elif args.command == 'show':
            results = db.get_run_results(args.run_id)
            if not results:
                print(f"No results found for run ID {args.run_id}")
            else:
                print(f"{'BLAS':<15} {'Test':<25} {'Time (sec)':<12} {'Memory (MB)':<12}")
                print("-" * 70)
                for result in results:
                    time_str = f"{result['time_sec']:.6f}" if result['time_sec'] is not None else "-"
                    mem_str = f"{result['memory_mb']:.1f}" if result['memory_mb'] is not None else "-"
                    print(f"{result['blas_vendor']:<15} {result['test_name']:<25} {time_str:<12} {mem_str:<12}")

                memory_rows = db.get_run_memory(args.run_id)
                if memory_rows:
                    print("\nMemory (separate metrics):")
                    print(f"{'BLAS':<15} {'Memory (MB)':<12}")
                    print("-" * 28)
                    for row in memory_rows:
                        mem_str = f"{row['memory_mb']:.1f}" if row['memory_mb'] is not None else "-"
                        print(f"{row['blas_vendor']:<15} {mem_str:<12}")

        elif args.command == 'export':
            db.export_to_csv(args.run_id, args.output)
            print(f"✓ Exported to {args.output}")

        elif args.command == 'compare':
            results = db.compare_blas(args.test_name, args.limit)
            if not results:
                print(f"No results found for test: {args.test_name}")
            else:
                print(f"{'Run ID':<8} {'BLAS':<15} {'Time (sec)':<12} {'Timestamp':<20}")
                print("-" * 60)
                for result in results:
                    timestamp = result['timestamp'][:19]
                    time_str = f"{result['time_sec']:.6f}" if result['time_sec'] is not None else "-"
                    print(f"{result['run_id']:<8} {result['blas_vendor']:<15} {time_str:<12} {timestamp:<20}")

    finally:
        db.close()

    return 0


if __name__ == '__main__':
    sys.exit(main())
