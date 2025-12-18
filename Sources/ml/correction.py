"""mlx-lm semantic correction helpers."""

from __future__ import annotations

import re
from typing import Any, Dict, List, Optional

from .loader import load_correction_model

DEFAULT_CORRECTION_PROMPT = (
    "Clean up this speech transcription: fix typos, grammar, punctuation, and remove "
    "filler words (um, uh, like, you know). Keep the original language. Output only "
    "the corrected text."
)


def _safe_chat_template(
    tokenizer: Any,
    messages: List[Dict[str, str]],
    system_prompt: str,
    text: str,
) -> str:
    try:
        # Keep thinking enabled for better quality - we strip <think> tags from output
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=True,
        )
    except Exception:
        return f"{system_prompt}\n\n{text}"


def _safe_generate(
    model: Any,
    tokenizer: Any,
    chat_prompt: str,
    max_tokens: int,
) -> str:
    try:
        from mlx_lm import generate
    except Exception as exc:
        raise RuntimeError(f"mlx-lm import failed: {exc}") from exc

    try:
        return generate(
            model,
            tokenizer,
            prompt=chat_prompt,
            max_tokens=max_tokens,
            temp=0.2,
            top_p=0.9,
            verbose=False,
        )
    except TypeError:
        return generate(
            model,
            tokenizer,
            prompt=chat_prompt,
            max_tokens=max_tokens,
            verbose=False,
        )


def correct(repo: str, text: str, prompt: Optional[str]) -> Dict[str, Any]:
    model, tokenizer = load_correction_model(repo)

    system_prompt = (
        prompt.strip() if prompt and prompt.strip() else DEFAULT_CORRECTION_PROMPT
    )
    messages = [
        {"role": "system", "content": system_prompt},
        {"role": "user", "content": text},
    ]

    chat_prompt = _safe_chat_template(tokenizer, messages, system_prompt, text)
    # Allow more tokens for thinking overhead
    max_tokens = max(128, min(4096, int(len(text.split()) * 4)))

    generated = _safe_generate(model, tokenizer, chat_prompt, max_tokens)

    if generated.startswith(chat_prompt):
        generated = generated[len(chat_prompt) :]

    # Strip complete <think>...</think> blocks
    cleaned = re.sub(r"<think>.*?</think>", "", generated, flags=re.DOTALL)
    # Strip incomplete <think> blocks (model truncated before closing tag)
    cleaned = re.sub(r"<think>.*", "", cleaned, flags=re.DOTALL)
    cleaned = cleaned.strip().strip('"').strip("'").strip()
    
    # If result is empty (all thinking, no answer), retry with thinking disabled
    if not cleaned:
        try:
            chat_prompt_no_think = tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True, enable_thinking=False
            )
            generated = _safe_generate(model, tokenizer, chat_prompt_no_think, max_tokens)
            if generated.startswith(chat_prompt_no_think):
                generated = generated[len(chat_prompt_no_think):]
            cleaned = re.sub(r"<think>.*?</think>", "", generated, flags=re.DOTALL)
            cleaned = re.sub(r"<think>.*", "", cleaned, flags=re.DOTALL)
            cleaned = cleaned.strip().strip('"').strip("'").strip()
        except Exception:
            pass
    
    return {"success": True, "text": cleaned}

