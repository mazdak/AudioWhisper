"""Parakeet transcription helpers."""

from __future__ import annotations

import os
import re
import uuid
from typing import Any, Dict, List, Tuple

from .loader import load_parakeet_model

DEFAULT_PARAKEET_REPO = "mlx-community/parakeet-tdt-0.6b-v3"
DEFAULT_SAMPLE_RATE = 16_000
_STREAM_SESSIONS: Dict[str, "_ParakeetStreamSession"] = {}


def _env_float(name: str, fallback: float) -> float:
    raw = os.environ.get(name)
    if raw is None:
        return fallback
    try:
        value = float(raw)
    except ValueError:
        return fallback
    return value if value > 0 else fallback


def _iter_chunk_ranges(
    total_samples: int, chunk_samples: int, overlap_samples: int
) -> List[Tuple[int, int]]:
    if total_samples <= 0:
        return []
    safe_chunk = max(chunk_samples, 1)
    safe_overlap = overlap_samples
    if safe_overlap >= safe_chunk:
        safe_overlap = safe_chunk // 4
    safe_overlap = max(safe_overlap, 0)
    step = max(safe_chunk - safe_overlap, 1)

    ranges: List[Tuple[int, int]] = []
    start = 0
    while start < total_samples:
        end = min(start + safe_chunk, total_samples)
        ranges.append((start, end))
        if end >= total_samples:
            break
        start += step
    return ranges


def _normalize_overlap_word(word: str) -> str:
    return re.sub(r"[^\w]+", "", word, flags=re.UNICODE).lower()


def _merge_text_with_overlap(base_text: str, next_text: str, max_overlap_words: int = 12) -> str:
    base_words_raw = base_text.strip().split()
    next_words_raw = next_text.strip().split()

    if not base_words_raw:
        return " ".join(next_words_raw)
    if not next_words_raw:
        return " ".join(base_words_raw)

    base_words_norm = [_normalize_overlap_word(word) for word in base_words_raw]
    next_words_norm = [_normalize_overlap_word(word) for word in next_words_raw]

    max_overlap = min(max_overlap_words, len(base_words_raw), len(next_words_raw))
    overlap = 0
    for size in range(max_overlap, 0, -1):
        if base_words_norm[-size:] == next_words_norm[:size]:
            overlap = size
            break

    if overlap > 0:
        merged_words = base_words_raw + next_words_raw[overlap:]
    else:
        merged_words = base_words_raw + next_words_raw

    return " ".join(merged_words)


def _transcribe_chunk(model: Any, audio_chunk: Any, mx: Any, get_logmel: Any) -> str:
    if audio_chunk.size == 0:
        return ""
    audio_mlx = mx.array(audio_chunk.astype("float32", copy=False))
    mel = get_logmel(audio_mlx, model.preprocessor_config)
    result = model.generate(mel)
    return extract_parakeet_text(result).strip()


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


def _load_runtime(repo: str) -> Tuple[Any, Any, Any, Any, int, int, int, int]:
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
    sample_rate = int(getattr(model.preprocessor_config, "sample_rate", DEFAULT_SAMPLE_RATE))
    if sample_rate <= 0:
        sample_rate = DEFAULT_SAMPLE_RATE

    chunk_seconds = _env_float("AW_PARAKEET_CHUNK_SECONDS", 15.0)
    overlap_seconds = _env_float("AW_PARAKEET_CHUNK_OVERLAP_SECONDS", 1.0)
    threshold_seconds = _env_float("AW_PARAKEET_CHUNKING_THRESHOLD_SECONDS", 20.0)

    chunk_samples = int(chunk_seconds * sample_rate)
    overlap_samples = int(overlap_seconds * sample_rate)
    threshold_samples = int(threshold_seconds * sample_rate)
    return model, np, mx, get_logmel, sample_rate, chunk_samples, overlap_samples, threshold_samples


def _transcribe_with_chunking(
    audio_data: Any,
    model: Any,
    mx: Any,
    get_logmel: Any,
    chunk_samples: int,
    overlap_samples: int,
    threshold_samples: int,
) -> str:
    if audio_data.size == 0:
        return ""

    if chunk_samples > 0 and audio_data.size >= max(chunk_samples, threshold_samples):
        merged_text = ""
        for start, end in _iter_chunk_ranges(
            total_samples=int(audio_data.size),
            chunk_samples=chunk_samples,
            overlap_samples=overlap_samples,
        ):
            chunk_text = _transcribe_chunk(model, audio_data[start:end], mx, get_logmel)
            if not chunk_text:
                continue
            if not merged_text:
                merged_text = chunk_text
            else:
                merged_text = _merge_text_with_overlap(merged_text, chunk_text)
        return merged_text.strip()

    return _transcribe_chunk(model, audio_data, mx, get_logmel)


class _ParakeetStreamSession:
    def __init__(self, repo: str, pcm_path: str):
        if not os.path.exists(pcm_path):
            raise FileNotFoundError(f"PCM file not found: {pcm_path}")
        if not os.access(pcm_path, os.R_OK):
            raise PermissionError(f"Cannot read PCM file: {pcm_path}")

        (
            self.model,
            self.np,
            self.mx,
            self.get_logmel,
            _sample_rate,
            chunk_samples,
            overlap_samples,
            _threshold_samples,
        ) = _load_runtime(repo)

        self.pcm_path = pcm_path
        self.chunk_samples = max(chunk_samples, 1)
        self.overlap_samples = max(overlap_samples, 0)
        if self.overlap_samples >= self.chunk_samples:
            self.overlap_samples = self.chunk_samples // 4
        self.stride_samples = max(self.chunk_samples - self.overlap_samples, 1)

        self.read_offset_bytes = 0
        self.trailing_bytes = b""
        self.audio_bytes = bytearray()
        self.processed_until_samples = 0
        self.committed_text = ""

    @property
    def total_samples(self) -> int:
        return len(self.audio_bytes) // 4

    def _sync_from_file(self) -> None:
        with open(self.pcm_path, "rb") as handle:
            handle.seek(self.read_offset_bytes)
            incoming = handle.read()

        if not incoming:
            return

        self.read_offset_bytes += len(incoming)
        raw = self.trailing_bytes + incoming
        aligned_len = len(raw) - (len(raw) % 4)
        if aligned_len > 0:
            self.audio_bytes.extend(raw[:aligned_len])
        self.trailing_bytes = raw[aligned_len:]

    def _slice_samples(self, start: int, end: int) -> Any:
        clamped_start = max(start, 0)
        clamped_end = min(end, self.total_samples)
        if clamped_end <= clamped_start:
            return self.np.empty(0, dtype=self.np.float32)
        view = memoryview(self.audio_bytes)[clamped_start * 4 : clamped_end * 4]
        return self.np.frombuffer(view, dtype=self.np.float32)

    def _transcribe_range(self, start: int, end: int) -> str:
        samples = self._slice_samples(start, end)
        return _transcribe_chunk(self.model, samples, self.mx, self.get_logmel).strip()

    def _process_committed_windows(self) -> None:
        while self.processed_until_samples + self.chunk_samples <= self.total_samples:
            start = self.processed_until_samples
            end = start + self.chunk_samples
            chunk_text = self._transcribe_range(start, end)
            if chunk_text:
                if not self.committed_text:
                    self.committed_text = chunk_text
                else:
                    self.committed_text = _merge_text_with_overlap(self.committed_text, chunk_text)
            self.processed_until_samples += self.stride_samples

    def partial_text(self) -> str:
        self._sync_from_file()
        self._process_committed_windows()

        if self.total_samples <= 0:
            return ""
        if not self.committed_text:
            return self._transcribe_range(0, self.total_samples)

        tail_start = max(self.processed_until_samples - self.overlap_samples, 0)
        if tail_start >= self.total_samples:
            return self.committed_text.strip()

        tail_text = self._transcribe_range(tail_start, self.total_samples)
        if not tail_text:
            return self.committed_text.strip()
        return _merge_text_with_overlap(self.committed_text, tail_text).strip()

    def finalize_text(self) -> str:
        return self.partial_text()


def transcribe(repo: str, pcm_path: str) -> Dict[str, Any]:
    if not os.path.exists(pcm_path):
        raise FileNotFoundError(f"PCM file not found: {pcm_path}")
    if not os.access(pcm_path, os.R_OK):
        raise PermissionError(f"Cannot read PCM file: {pcm_path}")

    model, np, mx, get_logmel, _sample_rate, chunk_samples, overlap_samples, threshold_samples = _load_runtime(repo)
    audio_data = np.fromfile(pcm_path, dtype=np.float32)
    text = _transcribe_with_chunking(
        audio_data=audio_data,
        model=model,
        mx=mx,
        get_logmel=get_logmel,
        chunk_samples=chunk_samples,
        overlap_samples=overlap_samples,
        threshold_samples=threshold_samples,
    )
    return {"success": True, "text": text}


def parakeet_stream_start(repo: str, pcm_path: str) -> Dict[str, Any]:
    stream_id = str(uuid.uuid4())
    _STREAM_SESSIONS[stream_id] = _ParakeetStreamSession(repo=repo, pcm_path=pcm_path)
    return {"success": True, "stream_id": stream_id}


def parakeet_stream_update(stream_id: str) -> Dict[str, Any]:
    session = _STREAM_SESSIONS.get(stream_id)
    if session is None:
        raise ValueError(f"Unknown stream_id: {stream_id}")
    return {"success": True, "text": session.partial_text()}


def parakeet_stream_finalize(stream_id: str) -> Dict[str, Any]:
    session = _STREAM_SESSIONS.pop(stream_id, None)
    if session is None:
        raise ValueError(f"Unknown stream_id: {stream_id}")
    return {"success": True, "text": session.finalize_text()}


def parakeet_stream_abort(stream_id: str) -> Dict[str, Any]:
    _STREAM_SESSIONS.pop(stream_id, None)
    return {"success": True}
