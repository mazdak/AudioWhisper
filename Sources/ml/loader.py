"""Model loading and caching utilities for Parakeet MLX and mlx-lm."""

from __future__ import annotations

import os
from typing import Any, Dict, Tuple

# Keep HF from grabbing a token implicitly; don't force offline globally here.
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")

MODEL_CACHE: Dict[Tuple[str, str], Any] = {}
HF_ENV_KEYS = ("HF_HUB_OFFLINE", "TRANSFORMERS_OFFLINE")


def _set_offline_env() -> Dict[str, str]:
    """Enable offline flags, returning previous values for restoration."""
    previous = {k: os.environ.get(k) for k in HF_ENV_KEYS}
    os.environ["HF_HUB_OFFLINE"] = "1"
    os.environ["TRANSFORMERS_OFFLINE"] = "1"
    return previous


def _restore_env(previous: Dict[str, str]) -> None:
    """Restore HF offline flags to their prior state."""
    for key, value in previous.items():
        if value is None:
            os.environ.pop(key, None)
        else:
            os.environ[key] = value


def load_parakeet_model(repo: str):
    cache_key = ("parakeet", repo)
    if cache_key in MODEL_CACHE:
        return MODEL_CACHE[cache_key]

    try:
        from parakeet_mlx import from_pretrained
    except Exception as exc:
        raise RuntimeError(f"parakeet-mlx import failed: {exc}") from exc

    previous = _set_offline_env()
    try:
        model = from_pretrained(repo)
    except Exception as exc:
        _restore_env(previous)
        raise RuntimeError(f"Model not available offline: {exc}") from exc
    _restore_env(previous)

    MODEL_CACHE[cache_key] = model
    return model


def load_correction_model(repo: str):
    cache_key = ("mlx", repo)
    if cache_key in MODEL_CACHE:
        return MODEL_CACHE[cache_key]

    try:
        from mlx_lm import load
    except Exception as exc:
        raise RuntimeError(f"mlx-lm import failed: {exc}") from exc

    previous = _set_offline_env()
    try:
        model, tokenizer = load(repo)
    except Exception as exc:
        _restore_env(previous)
        raise RuntimeError(
            "MLX model not available offline. Please open Settings to download it."
        ) from exc
    _restore_env(previous)

    MODEL_CACHE[cache_key] = (model, tokenizer)
    return MODEL_CACHE[cache_key]

