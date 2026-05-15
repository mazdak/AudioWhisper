# ADR 0002: Embedded Python (uv-managed) for MLX/Parakeet

**Status:** Accepted
**Date:** 2026-05-14

## Context

Parakeet-MLX and the local MLX semantic-correction model are only published as Python packages (`parakeet-mlx`, `mlx-lm`). There is no first-party Swift binding.

Options considered:
1. Require users to install Python + pip-install deps themselves.
2. Bundle a Python interpreter inside the app.
3. Use `uv` to bootstrap a Python venv on first launch from a bundled binary.

## Decision

Bundle the `uv` binary inside the app at `Sources/Resources/bin/uv`. On first use, `UvBootstrap.swift` creates a venv at `~/Library/Application Support/AudioWhisper/venv/` and installs deps from the committed `Sources/Resources/uv.lock`.

## Consequences

- **Reproducibility:** Locked dep versions; same env on every machine.
- **First-launch latency:** ~30s for first MLX/Parakeet use while venv warms.
- **Disk cost:** ~500 MB-1.5 GB depending on which models are pulled.
- **Supply-chain surface:** the bundled `uv` binary must be verified (SHA-256 stamped at build time — see audit item E2).
- **Security:** subprocesses launched via Foundation `Process` with argument arrays (no shell), JSON-RPC over pipes (no network).
