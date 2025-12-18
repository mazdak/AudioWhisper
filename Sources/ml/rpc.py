"""JSON-RPC stdin/stdout server for ML tasks."""

from __future__ import annotations

import json
import sys
from typing import Any, Dict

from .correction import correct
from .loader import load_correction_model, load_parakeet_model
from .parakeet import DEFAULT_PARAKEET_REPO, transcribe


def _respond(payload: Dict[str, Any]) -> None:
    sys.stdout.write(json.dumps(payload) + "\n")
    sys.stdout.flush()


def _handle_request(request: Dict[str, Any]) -> None:
    req_id = request.get("id")
    method = request.get("method")
    params = request.get("params") or {}

    try:
        if method == "ping":
            _respond({"jsonrpc": "2.0", "id": req_id, "result": {"pong": True}})
            return

        if method == "transcribe":
            repo = params.get("repo") or DEFAULT_PARAKEET_REPO
            pcm_path = params.get("pcm_path")
            if not pcm_path:
                raise ValueError("pcm_path is required for transcribe")
            result = transcribe(repo, pcm_path)
            _respond({"jsonrpc": "2.0", "id": req_id, "result": result})
            return

        if method == "correct":
            repo = params.get("repo")
            text = params.get("text")
            prompt = params.get("prompt")
            if not repo:
                raise ValueError("repo is required for correct")
            if text is None:
                raise ValueError("text is required for correct")
            result = correct(repo, text, prompt)
            _respond({"jsonrpc": "2.0", "id": req_id, "result": result})
            return

        if method == "warmup":
            warm_type = params.get("type")
            repo = params.get("repo")
            if not warm_type or not repo:
                raise ValueError("warmup requires 'type' and 'repo'")
            if warm_type == "parakeet":
                load_parakeet_model(repo)
            elif warm_type in ("mlx", "correction"):
                load_correction_model(repo)
            else:
                raise ValueError(f"Unknown warmup type: {warm_type}")
            _respond({"jsonrpc": "2.0", "id": req_id, "result": {"success": True}})
            return

        raise ValueError(f"Unknown method: {method}")
    except Exception as exc:
        error_payload = {
            "jsonrpc": "2.0",
            "id": req_id,
            "error": {"message": str(exc)},
        }
        _respond(error_payload)


def main() -> int:
    for line in sys.stdin:
        if not line.strip():
            continue
        try:
            request = json.loads(line)
        except json.JSONDecodeError as exc:
            _respond(
                {
                    "jsonrpc": "2.0",
                    "id": None,
                    "error": {"message": f"Invalid JSON: {exc}"},
                }
            )
            continue

        _handle_request(request)
    return 0

