# Web Visualization Quick Start

View your BLAS benchmark results in an interactive web dashboard!

## 🚀 Quick Start (3 Steps)

### 1. Run Benchmarks
```bash
./benchmark_blas.sh
# Wait 20-30 minutes for completion
```

### 2. Start Web Server
```bash
cd webapp
./run_server.sh
```

### 3. Open Browser
Navigate to: **http://localhost:8000**

---

## 📸 What You'll See

### Dashboard Features:
- **📊 Interactive Charts** - Click and hover for details
- **🏆 Winner Badge** - See which BLAS is fastest
- **📈 Multiple Views** - Absolute times, speedup, summary
- **🔄 Test Selection** - Switch between AMD, CHOLMOD, UMFPACK tests
- **📱 Responsive** - Works on phone, tablet, desktop

### Screenshot Preview:
```
┌─────────────────────────────────────────────────────┐
│ 🚀 SuiteSparse BLAS Benchmark Viewer               │
│                                                      │
│ ┌───────┐  ┌───────┐  ┌───────────────────┐       │
│ │   3   │  │ Today │  │ OpenBLAS 🏆       │       │
│ │ Runs  │  │       │  │ Fastest           │       │
│ └───────┘  └───────┘  └───────────────────┘       │
│                                                      │
│ Performance Comparison by Test                      │
│ [AMD_simple ▼]                                      │
│ ┌────────────────────────────────────────┐         │
│ │    █████████████ OpenBLAS              │         │
│ │    ████████████████ BLIS                │         │
│ │    ███████████████████ Intel MKL       │         │
│ └────────────────────────────────────────┘         │
└─────────────────────────────────────────────────────┘
```

---

## 🎯 Usage Examples

### View Latest Results
1. Open http://localhost:8000
2. Automatically loads latest benchmark
3. Scroll through different chart views

### Compare Tests
1. Use dropdown to select test (AMD_simple, CHOLMOD_quick, etc.)
2. Chart updates immediately
3. See relative performance differences

### API Access (Advanced)
```bash
# Get latest results as JSON
curl http://localhost:8000/api/latest

# List all benchmark runs
curl http://localhost:8000/api/results

# Get specific run
curl http://localhost:8000/api/results/benchmark_results_20250209_120000.txt
```

---

## 🔧 Configuration

### Change Port
Edit `webapp/run_server.sh`, line 31:
```bash
exec uv run uvicorn main:app --host 0.0.0.0 --port 9000 --reload
```

### External Access
To allow access from other machines on your network:
```bash
# Server is already configured for 0.0.0.0 (all interfaces)
# Just open firewall port 8000

# Find your IP
ip addr show | grep "inet " | grep -v 127.0.0.1

# Access from other machine:
# http://YOUR_IP:8000
```

---

## 📊 Chart Explanations

### Chart 1: Performance Comparison by Test
- **Lower bars = Faster** (time in seconds)
- Select different tests from dropdown
- Hover for exact times

### Chart 2: Relative Speedup
- **Baseline**: Slowest = 100%
- **Higher = Better** (faster than baseline)
- Shows all tests at once

### Chart 3: All Tests Summary
- Side-by-side comparison
- Grouped by BLAS implementation
- Quick overview of all results

---

## 🐛 Troubleshooting

### "No benchmark data available"
```bash
# Run benchmark first
cd /mnt/developer/git/aecs4u.it/SuiteSparse
./benchmark_blas.sh
```

### "Port 8000 already in use"
```bash
# Find what's using the port
lsof -i :8000

# Kill it
kill -9 <PID>

# Or use different port (edit run_server.sh)
```

### "uv not found"
```bash
# Install uv
curl -LsSf https://astral.sh/uv/install.sh | sh
source ~/.bashrc
```

### Charts not displaying
- Check browser console (F12) for errors
- Refresh page (Ctrl+R)
- Try different browser
- Ensure JavaScript is enabled

---

## 📁 File Structure

```
SuiteSparse/
├── benchmark_blas.sh               # Generate results
├── benchmark_results_*.txt         # Data files (CSV)
└── webapp/
    ├── main.py                     # FastAPI backend
    ├── run_server.sh              # Startup script
    ├── templates/index.html       # Dashboard UI
    └── README.md                   # Detailed docs
```

---

## 💡 Pro Tips

1. **Keep Server Running**: Leave terminal open while browsing
2. **Auto-Refresh**: Currently manual - refresh browser for new data
3. **Multiple Windows**: Open multiple browser tabs for comparison
4. **Mobile View**: Access from phone using your local IP
5. **Screenshots**: Use browser tools to capture charts

---

## 🎓 Learn More

- **Full docs**: See `webapp/README.md`
- **API details**: http://localhost:8000/docs (auto-generated)
- **Benchmark guide**: See `BENCHMARK_README.md`

---

## 🚦 Quick Commands Reference

```bash
# Start server
cd webapp && ./run_server.sh

# Stop server
Ctrl+C

# Check if running
curl http://localhost:8000/health

# View in browser
xdg-open http://localhost:8000  # Linux
open http://localhost:8000       # Mac
```

---

**Ready to visualize your benchmarks!** 🎉

Start with: `cd webapp && ./run_server.sh`
