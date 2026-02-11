#-------------------------------------------------------------------------------
# Makefile for all SuiteSparse packages
#-------------------------------------------------------------------------------

# Copyright (c) 2023, Timothy A. Davis, All Rights Reserved.
# Just this particular file is under the Apache-2.0 license; each package has
# its own license.
# SPDX-License-Identifier: Apache-2.0

# edit this variable to pass options to cmake:
export CMAKE_OPTIONS ?=

# edit this variable to control parallel make:
export JOBS ?= 8

# do not modify this variable
export SUITESPARSE = $(CURDIR)

#-------------------------------------------------------------------------------

# Compile the default rules for each package.

# Note that CSparse is compiled but not installed by "make install";
# CXSparse is installed instead.

# default: "make install" will install all libraries in /usr/local/lib
# and include files in /usr/local/include.  Not installed in SuiteSparse/lib.
default: library

# compile; "sudo make install" will install only in /usr/local
# (or whatever your CMAKE_INSTALL_PREFIX is)
library:
	( cd modules/SuiteSparse_config && $(MAKE) )
	( cd modules/AMD && $(MAKE) )
	( cd modules/COLAMD && $(MAKE) )
	( cd modules/SPEX && $(MAKE) )
	( cd modules/Mongoose && $(MAKE) )
	( cd modules/BTF && $(MAKE) )
	( cd modules/CAMD && $(MAKE) )
	( cd modules/CCOLAMD && $(MAKE) )
	( cd modules/CHOLMOD && $(MAKE) )
	( cd modules/CSparse && $(MAKE) )
	( cd modules/CXSparse && $(MAKE) )
	( cd modules/LDL && $(MAKE) )
	( cd modules/KLU && $(MAKE) )
	( cd modules/UMFPACK && $(MAKE) )
	( cd modules/ParU && $(MAKE) )
	( cd modules/RBio && $(MAKE) )
	( cd modules/SPQR && $(MAKE) )
	( cd modules/GraphBLAS && $(MAKE) )
	( cd modules/LAGraph && $(MAKE) )

# compile; "make install" only in SuiteSparse/lib and SuiteSparse/include
local:
	( cd modules/SuiteSparse_config && $(MAKE) local )
	( cd modules/AMD && $(MAKE) local )
	( cd modules/COLAMD && $(MAKE) local )
	( cd modules/SPEX && $(MAKE) local )
	( cd modules/Mongoose && $(MAKE) local )
	( cd modules/BTF && $(MAKE) local )
	( cd modules/CAMD && $(MAKE) local )
	( cd modules/CCOLAMD && $(MAKE) local )
	( cd modules/CHOLMOD && $(MAKE) local )
	( cd modules/CSparse && $(MAKE) )  
	( cd modules/CXSparse && $(MAKE) local )
	( cd modules/LDL && $(MAKE) local )
	( cd modules/KLU && $(MAKE) local )
	( cd modules/UMFPACK && $(MAKE) local )
	( cd modules/ParU && $(MAKE) local )
	( cd modules/RBio && $(MAKE) local )
	( cd modules/SPQR && $(MAKE) local )
	( cd modules/GraphBLAS && $(MAKE) local )
	( cd modules/LAGraph && $(MAKE) local )

# compile; "sudo make install" will install only in /usr/local
# (or whatever your CMAKE_INSTALL_PREFIX is)
global:
	( cd modules/SuiteSparse_config && $(MAKE) global )
	( cd modules/AMD && $(MAKE) global )
	( cd modules/COLAMD && $(MAKE) global )
	( cd modules/SPEX && $(MAKE) global )
	( cd modules/Mongoose && $(MAKE) global )
	( cd modules/BTF && $(MAKE) global )
	( cd modules/CAMD && $(MAKE) global )
	( cd modules/CCOLAMD && $(MAKE) global )
	( cd modules/CHOLMOD && $(MAKE) global )
	( cd modules/CSparse && $(MAKE) )  
	( cd modules/CXSparse && $(MAKE) global )
	( cd modules/LDL && $(MAKE) global )
	( cd modules/KLU && $(MAKE) global )
	( cd modules/UMFPACK && $(MAKE) global )
	( cd modules/ParU && $(MAKE) global )
	( cd modules/RBio && $(MAKE) global )
	( cd modules/SPQR && $(MAKE) global )
	( cd modules/GraphBLAS && $(MAKE) global )
	( cd modules/LAGraph && $(MAKE) global )

# install all packages.  Location depends on prior "make", "make global" etc
install:
	( cd modules/SuiteSparse_config && $(MAKE) install )
	( cd modules/AMD && $(MAKE) install )
	( cd modules/COLAMD && $(MAKE) install )
	( cd modules/SPEX && $(MAKE) install )
	( cd modules/Mongoose  && $(MAKE) install )
	( cd modules/BTF && $(MAKE) install )
	( cd modules/CAMD && $(MAKE) install )
	( cd modules/CCOLAMD && $(MAKE) install )
	( cd modules/CHOLMOD && $(MAKE) install )
	( cd modules/CXSparse && $(MAKE) install ) 
	( cd modules/LDL && $(MAKE) install )
	( cd modules/KLU && $(MAKE) install )
	( cd modules/UMFPACK && $(MAKE) install )
	( cd modules/ParU && $(MAKE) install )
	( cd modules/RBio && $(MAKE) install )
	( cd modules/SPQR && $(MAKE) install )
	( cd modules/GraphBLAS && $(MAKE) install )
	( cd modules/LAGraph && $(MAKE) install )

# uninstall all packages
uninstall:
	( cd modules/SuiteSparse_config && $(MAKE) uninstall )
	( cd modules/AMD && $(MAKE) uninstall )
	( cd modules/COLAMD && $(MAKE) uninstall )
	( cd modules/SPEX && $(MAKE) uninstall )
	( cd modules/Mongoose  && $(MAKE) uninstall )
	( cd modules/CAMD && $(MAKE) uninstall )
	( cd modules/BTF && $(MAKE) uninstall )
	( cd modules/KLU && $(MAKE) uninstall )
	( cd modules/LDL && $(MAKE) uninstall )
	( cd modules/CCOLAMD && $(MAKE) uninstall )
	( cd modules/ParU && $(MAKE) uninstall )
	( cd modules/UMFPACK && $(MAKE) uninstall )
	( cd modules/CHOLMOD && $(MAKE) uninstall )
	( cd modules/CXSparse && $(MAKE) uninstall )
	( cd modules/RBio && $(MAKE) uninstall )
	( cd modules/SPQR && $(MAKE) uninstall )
	( cd modules/GraphBLAS && $(MAKE) uninstall )
	( cd modules/LAGraph && $(MAKE) uninstall )

# Remove all files not in the original distribution
distclean: purge

# Remove all files not in the original distribution
purge:
	- ( cd modules/SuiteSparse_config && $(MAKE) purge )
	- ( cd modules/AMD && $(MAKE) purge )
	- ( cd modules/COLAMD && $(MAKE) purge )
	- ( cd modules/SPEX && $(MAKE) purge )
	- ( cd modules/Mongoose  && $(MAKE) purge )
	- ( cd modules/CAMD && $(MAKE) purge )
	- ( cd modules/BTF && $(MAKE) purge )
	- ( cd modules/KLU && $(MAKE) purge )
	- ( cd modules/LDL && $(MAKE) purge )
	- ( cd modules/CCOLAMD && $(MAKE) purge )
	- ( cd modules/UMFPACK && $(MAKE) purge )
	- ( cd modules/CHOLMOD && $(MAKE) purge )
	- ( cd modules/CSparse && $(MAKE) purge )
	- ( cd modules/CXSparse && $(MAKE) purge )
	- ( cd modules/RBio && $(MAKE) purge )
	- ( cd modules/SPQR && $(MAKE) purge )
	- $(RM) MATLAB_Tools/*/*.mex* MATLAB_Tools/*/*/*.mex*
	- $(RM) MATLAB_Tools/*/*.o    MATLAB_Tools/*/*/*.o
	- $(RM) -r Example/build/*
	- ( cd modules/GraphBLAS && $(MAKE) purge )
	- ( cd modules/ParU && $(MAKE) purge )
	- ( cd modules/LAGraph && $(MAKE) purge )
	- $(RM) -r include/* bin/* lib/* build/*

clean: purge

# Run all demos
demos:
	- ( cd modules/SuiteSparse_config && $(MAKE) demos )
	- ( cd modules/AMD && $(MAKE) demos )
	- ( cd modules/COLAMD && $(MAKE) demos )
	- ( cd modules/SPEX && $(MAKE) demos )
	- ( cd modules/Mongoose && $(MAKE) demos )
	- ( cd modules/CAMD && $(MAKE) demos )
	- ( cd modules/BTF && $(MAKE) demos )
	- ( cd modules/KLU && $(MAKE) demos )
	- ( cd modules/LDL && $(MAKE) demos )
	- ( cd modules/CCOLAMD && $(MAKE) demos )
	- ( cd modules/UMFPACK && $(MAKE) demos )
	- ( cd modules/CHOLMOD && $(MAKE) demos )
	- ( cd modules/CSparse && $(MAKE) demos )
	- ( cd modules/CXSparse && $(MAKE) demos )
	- ( cd modules/RBio && $(MAKE) demos )
	- ( cd modules/SPQR && $(MAKE) demos )
	- ( cd modules/GraphBLAS && $(MAKE) demos )
	- ( cd modules/ParU && $(MAKE) demos )
	- ( cd modules/LAGraph && $(MAKE) demos )

# Create the PDF documentation
docs:
	( cd modules/GraphBLAS && $(MAKE) docs )
	( cd modules/AMD && $(MAKE) docs )
	( cd modules/CAMD && $(MAKE) docs )
	( cd modules/KLU && $(MAKE) docs )
	( cd modules/LDL && $(MAKE) docs )
	( cd modules/UMFPACK && $(MAKE) docs )
	( cd modules/CHOLMOD && $(MAKE) docs )
	( cd modules/ParU && $(MAKE) docs )
	( cd modules/SPQR && $(MAKE) docs )
	( cd modules/SPEX && $(MAKE) docs )
	( cd modules/Mongoose  && $(MAKE) docs )

# statement coverage (Linux only); this requires a lot of time.
cov: local install
	( cd modules/CXSparse && $(MAKE) cov )
	( cd modules/CSparse && $(MAKE) cov )
	( cd modules/CHOLMOD && $(MAKE) cov )
	( cd modules/KLU && $(MAKE) cov )
	( cd modules/SPQR && $(MAKE) cov )
	( cd modules/UMFPACK && $(MAKE) cov )
	( cd modules/SPEX && $(MAKE) cov )
	( cd modules/LAGraph && $(MAKE) cov )

gbmatlab:
	( cd modules/GraphBLAS/GraphBLAS && $(MAKE) )

gblocal:
	( cd modules/GraphBLAS/GraphBLAS && $(MAKE) local && $(MAKE) install )

debug:
	( cd modules/SuiteSparse_config && $(MAKE) debug )
	# ( cd modules/Mongoose && $(MAKE) debug )
	( cd modules/AMD && $(MAKE) debug )
	( cd modules/BTF && $(MAKE) debug )
	( cd modules/CAMD && $(MAKE) debug )
	( cd modules/CCOLAMD && $(MAKE) debug )
	( cd modules/COLAMD && $(MAKE) debug )
	( cd modules/CHOLMOD && $(MAKE) debug )
	( cd modules/CSparse && $(MAKE) debug )
	( cd modules/CXSparse && $(MAKE) debug )
	( cd modules/LDL && $(MAKE) debug )
	( cd modules/KLU && $(MAKE) debug )
	( cd modules/UMFPACK && $(MAKE) debug )
	( cd modules/ParU && $(MAKE) debug )
	( cd modules/RBio && $(MAKE) debug )
	( cd modules/SPQR && $(MAKE) debug )
	( cd modules/SPEX && $(MAKE) debug )
	( cd modules/GraphBLAS && $(MAKE) cdebug )
	( cd modules/LAGraph && $(MAKE) debug )

tests:
	( cd modules/Mongoose && $(MAKE) test )
	( cd modules/CHOLMOD && $(MAKE) test )
	( cd modules/LAGraph && $(MAKE) test )

test: tests


#-------------------------------------------------------------------------------
# Additive smart-build / benchmark / webapp helpers
# These do not replace legacy SuiteSparse make targets above.
#-------------------------------------------------------------------------------

WEBAPP_DIR ?= webapp
WEBAPP_LOG ?= /tmp/suitesparse_webapp.log
WEBAPP_PID_FILE ?= $(abspath $(if $(BUILD_DIR),$(BUILD_DIR),build)/.webapp.pid)

.PHONY: all build force smart-clean smart-status check smart-test smart-help \
	openblas mkl blis build-all-blas benchmark analyze db-list db-show db-export db-compare \
	webapp webapp-stop webapp-status \
	install-libs install-libs-openblas install-libs-mkl install-libs-blis install-libs-all

# Keep expected GNU make convention
all: library

# Smart incremental build helper
build:
	@./smart_build.sh

# Force smart rebuild
force:
	@./smart_build.sh --force

# Smart clean only (legacy clean/purge remain unchanged)
smart-clean:
	@./smart_build.sh --clean

# Smart build status
smart-status:
	@if [ -f "$${BUILD_DIR:-build}/.build_state" ]; then \
		printf "Build status (%s):\n" "$${BUILD_DIR:-build}"; \
		grep -v "^#" "$${BUILD_DIR:-build}/.build_state" | sed 's/^/  /'; \
	else \
		printf "No smart build state found in %s\n" "$${BUILD_DIR:-build}"; \
	fi

# Exit code matches smart_build.sh --check
check:
	@./smart_build.sh --check; rc=$$?; \
	if [ $$rc -eq 0 ]; then \
		printf "Build is up to date\n"; \
	else \
		printf "Build needs updating. Run 'make build'\n"; \
	fi; \
	exit $$rc

# Smart test convenience target
smart-test: build
	@cd "$${BUILD_DIR:-build}" && ctest --output-on-failure

# BLAS-specific smart builds
openblas:
	@./scripts/build_openblas.sh

mkl:
	@./scripts/build_mkl.sh

blis:
	@./scripts/build_blis.sh

# Build with all BLAS vendors
build-all-blas:
	@echo "=========================================="
	@echo "Building SuiteSparse with all BLAS vendors"
	@echo "=========================================="
	@echo ""
	@echo "1/3: Building with OpenBLAS..."
	@$(MAKE) openblas
	@echo ""
	@echo "2/3: Building with Intel MKL..."
	@$(MAKE) mkl || echo "⚠ MKL build failed (MKL may not be installed)"
	@echo ""
	@echo "3/3: Building with BLIS..."
	@$(MAKE) blis || echo "⚠ BLIS build failed (BLIS may not be installed)"
	@echo ""
	@echo "=========================================="
	@echo "✓ All BLAS builds complete!"
	@echo "=========================================="
	@echo ""
	@echo "Libraries installed in lib/ with vendor suffixes:"
	@ls -lh lib/ | grep -E "_(openblas|mkl|blis)\." | head -20 || true

# Benchmarking
benchmark:
	@./scripts/benchmark_blas.sh

analyze:
	@LATEST=$$(ls -t benchmarks/results/benchmark_results_*.txt 2>/dev/null | head -1); \
	if [ -n "$$LATEST" ]; then \
		uv run python scripts/analyze_results.py "$$LATEST"; \
	else \
		printf "No benchmark results found\n"; \
		exit 1; \
	fi

# Database management
db-list:
	@uv run python scripts/benchmark_db.py list

db-show:
	@if [ -z "$(RUN_ID)" ]; then \
		printf "Usage: make db-show RUN_ID=1\n"; \
		exit 1; \
	fi
	@uv run python scripts/benchmark_db.py show "$(RUN_ID)"

db-export:
	@if [ -z "$(RUN_ID)" ] || [ -z "$(OUTPUT)" ]; then \
		printf "Usage: make db-export RUN_ID=1 OUTPUT=results.csv\n"; \
		exit 1; \
	fi
	@uv run python scripts/benchmark_db.py export "$(RUN_ID)" "$(OUTPUT)"

db-compare:
	@if [ -z "$(TEST)" ]; then \
		printf "Usage: make db-compare TEST=AMD_simple\n"; \
		exit 1; \
	fi
	@uv run python scripts/benchmark_db.py compare "$(TEST)"

# Webapp controls
webapp:
	@mkdir -p "$(dir $(WEBAPP_PID_FILE))"
	@PORT=$${PORT:-9001}; \
	cd "$(WEBAPP_DIR)" && \
	nohup uv run uvicorn main:app --host 0.0.0.0 --port $$PORT > "$(WEBAPP_LOG)" 2>&1 & \
	WEBAPP_PID=$$!; \
	printf "%s:%s\n" "$$WEBAPP_PID" "$$PORT" > "$(WEBAPP_PID_FILE)"; \
	sleep 2; \
	if kill -0 $$WEBAPP_PID 2>/dev/null; then \
		printf "Webapp started: http://localhost:%s (pid %s)\n" "$$PORT" "$$WEBAPP_PID"; \
		printf "Log: %s\n" "$(WEBAPP_LOG)"; \
	else \
		printf "Failed to start webapp. Log: %s\n" "$(WEBAPP_LOG)"; \
		exit 1; \
	fi

webapp-stop:
	@if [ -f "$(WEBAPP_PID_FILE)" ]; then \
		PID=$$(cut -d: -f1 "$(WEBAPP_PID_FILE)"); \
		if kill -0 $$PID 2>/dev/null; then \
			kill $$PID && printf "Webapp stopped (pid %s)\n" "$$PID"; \
		else \
			printf "Webapp not running\n"; \
		fi; \
		rm -f "$(WEBAPP_PID_FILE)"; \
	else \
		printf "No webapp PID file found\n"; \
	fi

webapp-status:
	@if [ -f "$(WEBAPP_PID_FILE)" ]; then \
		PID=$$(cut -d: -f1 "$(WEBAPP_PID_FILE)"); \
		PORT=$$(cut -d: -f2 "$(WEBAPP_PID_FILE)"); \
		if kill -0 $$PID 2>/dev/null; then \
			printf "Webapp is running: pid=%s url=http://localhost:%s\n" "$$PID" "$$PORT"; \
		else \
			printf "Stale webapp PID file; removing it\n"; \
			rm -f "$(WEBAPP_PID_FILE)"; \
		fi; \
	else \
		printf "Webapp not started\n"; \
	fi

# Library installation with BLAS vendor suffix
install-libs:
	@if [ ! -d "$${BUILD_DIR:-build}" ]; then \
		printf "Error: Build directory %s not found. Run 'make build' first.\n" "$${BUILD_DIR:-build}"; \
		exit 1; \
	fi
	@BLAS_SUFFIX=$${BLAS_SUFFIX:-default}; \
	./scripts/install_libs.sh "$${BUILD_DIR:-build}" "$$BLAS_SUFFIX" lib

install-libs-openblas:
	@./scripts/install_libs.sh build_openblas openblas lib

install-libs-mkl:
	@./scripts/install_libs.sh build_mkl mkl lib

install-libs-blis:
	@./scripts/install_libs.sh build_blis blis lib

install-libs-all:
	@if [ -d build_openblas ]; then $(MAKE) install-libs-openblas; fi
	@if [ -d build_mkl ]; then $(MAKE) install-libs-mkl; fi
	@if [ -d build_blis ]; then $(MAKE) install-libs-blis; fi
	@if [ -d build ]; then BUILD_DIR=build BLAS_SUFFIX=default $(MAKE) install-libs; fi

smart-help:
	@printf "Smart targets:\n"
	@printf "  make build        # incremental smart build\n"
	@printf "  make force        # force smart rebuild\n"
	@printf "  make check        # check if build is current\n"
	@printf "  make smart-clean  # remove smart build dir\n"
	@printf "  make smart-test   # run ctest in smart build dir\n"
	@printf "  make benchmark    # run BLAS benchmark suite\n"
	@printf "  make webapp       # launch benchmark webapp\n"
	@printf "\n"
	@printf "BLAS-specific builds:\n"
	@printf "  make openblas     # build with OpenBLAS\n"
	@printf "  make mkl          # build with Intel MKL\n"
	@printf "  make blis         # build with BLIS\n"
	@printf "  make build-all-blas  # build with ALL BLAS vendors (OpenBLAS, MKL, BLIS)\n"
	@printf "\n"
	@printf "Library installation targets:\n"
	@printf "  make install-libs           # install from BUILD_DIR (default: build/) with BLAS_SUFFIX (default: default)\n"
	@printf "  make install-libs-openblas  # install from build_openblas/ with openblas suffix\n"
	@printf "  make install-libs-mkl       # install from build_mkl/ with mkl suffix\n"
	@printf "  make install-libs-blis      # install from build_blis/ with blis suffix\n"
	@printf "  make install-libs-all       # install from all available build directories\n"
	@printf "\n"
	@printf "Legacy SuiteSparse targets remain available (make, make local, make global, make install, make purge, ...).\n"
