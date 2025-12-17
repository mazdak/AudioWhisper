"""Parakeet transcription helpers."""

from __future__ import annotations

import os
from typing import Any, Dict

from .loader import load_parakeet_model

DEFAULT_PARAKEET_REPO = "mlx-community/parakeet-tdt-0.6b-v3"


def extract_parakeet_text(result: Any) -> str:
    if isinstance(result, list) and result:
        first_item = result[0]
        if hasattr(first_item, "text"):
            return first_item.text or ""
        return str(first_item)

    if hasattr(result, "text"):
        return result.text or ""
    if hasattr(result, "texts") and getattr(result, "texts"):
        return result.texts[0] or ""

    if isinstance(result, dict):
        if "text" in result:
            return result.get("text", "") or ""
        if "texts" in result and result.get("texts"):
            return result["texts"][0] or ""

    raise AttributeError(f"Cannot extract text from result: {result}")


def transcribe(repo: str, pcm_path: str) -> Dict[str, Any]:
    if not os.path.exists(pcm_path):
        raise FileNotFoundError(f"PCM file not found: {pcm_path}")
    if not os.access(pcm_path, os.R_OK):
        raise PermissionError(f"Cannot read PCM file: {pcm_path}")

    try:
        import numpy as np
    except ImportError as exc:
        raise RuntimeError(f"numpy import failed: {exc}") from exc

    try:
        import mlx.core as mx
    except ImportError as exc:
        raise RuntimeError(f"mlx.core import failed: {exc}") from exc

    try:
        from parakeet_mlx.audio import get_logmel
    except ImportError as exc:
        raise RuntimeError(f"parakeet_mlx.audio import failed: {exc}") from exc

    model = load_parakeet_model(repo)
    audio_data = np.fromfile(pcm_path, dtype=np.float32)

    audio_mlx = mx.array(audio_data.astype(np.float32))
    mel = get_logmel(audio_mlx, model.preprocessor_config)
    result = model.generate(mel)

    text = extract_parakeet_text(result)
    return {"success": True, "text": text}

