.PHONY: test test-r test-python test-typescript test-julia test-rust \
        docs docs-r docs-python docs-typescript docs-julia docs-rust

# ── Tests ──────────────────────────────────────────────────────────────────────

test-r:
	@echo "==> R"
	cd r && Rscript -e "devtools::test(stop_on_failure = TRUE)"

test-python:
	@echo "==> Python"
	cd python/rtemis_a3 && uv run pytest

test-typescript:
	@echo "==> TypeScript"
	cd typescript && pnpm test

test-julia:
	@echo "==> Julia"
	cd julia/RtemisA3 && julia --project=. -e "using Pkg; Pkg.test()"

test-rust:
	@echo "==> Rust"
	cd rust && cargo test

test:
	@r=0; p=0; ts=0; jl=0; rs=0; \
	$(MAKE) test-r          || r=1; \
	$(MAKE) test-python     || p=1; \
	$(MAKE) test-julia      || jl=1; \
	$(MAKE) test-typescript || ts=1; \
	$(MAKE) test-rust       || rs=1; \
	echo ""; \
	echo "── Test Summary ──────────────────────────────────────"; \
	[ $$r  -eq 0 ] && echo "  R:          passed" || echo "  R:          FAILED"; \
	[ $$p  -eq 0 ] && echo "  Python:     passed" || echo "  Python:     FAILED"; \
	[ $$jl -eq 0 ] && echo "  Julia:      passed" || echo "  Julia:      FAILED"; \
	[ $$ts -eq 0 ] && echo "  TypeScript: passed" || echo "  TypeScript: FAILED"; \
	[ $$rs -eq 0 ] && echo "  Rust:       passed" || echo "  Rust:       FAILED"; \
	echo "─────────────────────────────────────────────────────"; \
	[ $$((r+p+ts+jl+rs)) -eq 0 ]

# ── Docs ───────────────────────────────────────────────────────────────────────

docs-r:
	@echo "==> R"
	cd r && Rscript -e "devtools::document()"

docs-python:
	@echo "==> Python"
	cd python && bash build-docs.sh

docs-julia:
	@echo "==> Julia"
	cd julia && bash build-docs.sh

docs-typescript:
	@echo "==> TypeScript"
	cd typescript && pnpm build

docs-rust:
	@echo "==> Rust"
	cd rust && bash build-docs.sh

docs:
	@r=0; p=0; ts=0; jl=0; rs=0; \
	$(MAKE) docs-r          || r=1; \
	$(MAKE) docs-python     || p=1; \
	$(MAKE) docs-julia      || jl=1; \
	$(MAKE) docs-typescript || ts=1; \
	$(MAKE) docs-rust       || rs=1; \
	echo ""; \
	echo "── Docs Summary ──────────────────────────────────────"; \
	[ $$r  -eq 0 ] && echo "  R:          done" || echo "  R:          FAILED"; \
	[ $$p  -eq 0 ] && echo "  Python:     done" || echo "  Python:     FAILED"; \
	[ $$jl -eq 0 ] && echo "  Julia:      done" || echo "  Julia:      FAILED"; \
	[ $$ts -eq 0 ] && echo "  TypeScript: done" || echo "  TypeScript: FAILED"; \
	[ $$rs -eq 0 ] && echo "  Rust:       done" || echo "  Rust:       FAILED"; \
	echo "─────────────────────────────────────────────────────"; \
	[ $$((r+p+ts+jl+rs)) -eq 0 ]
