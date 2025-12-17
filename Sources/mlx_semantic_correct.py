#!/usr/bin/env python3
import sys
import json
import os

# Keep HF from grabbing a token implicitly; default to online unless cache exists
os.environ["HF_HUB_DISABLE_IMPLICIT_TOKEN"] = "1"
os.environ.setdefault("HF_HUB_DISABLE_PROGRESS_BARS", "1")


def main():
    try:
        from mlx_lm import load, generate
    except Exception as e:
        print(json.dumps({"success": False, "error": f"mlx-lm import failed: {e}"}))
        return 1

    if len(sys.argv) < 3:
        print(
            json.dumps(
                {
                    "success": False,
                    "error": "Usage: mlx_semantic_correct.py <model_repo> <input_text_file> [prompt_file]",
                }
            )
        )
        return 2

    model_repo = sys.argv[1]
    input_path = sys.argv[2]

    try:
        with open(input_path, "r", encoding="utf-8") as f:
            user_text = f.read().strip()
    except Exception as e:
        print(json.dumps({"success": False, "error": f"Failed to read input: {e}"}))
        return 3

    try:
        # Strictly offline here: downloads must be done in Settings
        prev_hf_offline = os.environ.get("HF_HUB_OFFLINE")
        prev_tr_offline = os.environ.get("TRANSFORMERS_OFFLINE")
        try:
            os.environ["HF_HUB_OFFLINE"] = "1"
            os.environ["TRANSFORMERS_OFFLINE"] = "1"
            model, tokenizer = load(model_repo)
        except Exception:
            # Restore env then fail clearly; UI should direct user to Settings to download
            if prev_hf_offline is None:
                os.environ.pop("HF_HUB_OFFLINE", None)
            else:
                os.environ["HF_HUB_OFFLINE"] = prev_hf_offline
            if prev_tr_offline is None:
                os.environ.pop("TRANSFORMERS_OFFLINE", None)
            else:
                os.environ["TRANSFORMERS_OFFLINE"] = prev_tr_offline
            return print(
                json.dumps(
                    {
                        "success": False,
                        "error": "MLX model not available offline. Please open Settings to download it.",
                    }
                )
            )
        # Load prompt from file if provided, else use default
        default_prompt = (
            "You are a speech-to-text post-processor. Your ONLY job is to clean up transcribed speech.\n\n"
            "Rules:\n"
            "- Fix spelling, grammar, and punctuation errors\n"
            "- Remove filler words (um, uh, like, you know, basically, actually)\n"
            "- Remove false starts and repeated words\n"
            "- Keep the original meaning and language\n"
            "- Do NOT add any preamble, explanation, or commentary\n"
            "- Do NOT format as a list or add structure that wasn't there\n"
            "- Output ONLY the corrected text, nothing else"
        )
        system_prompt = default_prompt
        if len(sys.argv) >= 4:
            try:
                with open(sys.argv[3], "r", encoding="utf-8") as pf:
                    loaded = pf.read().strip()
                    if loaded:
                        system_prompt = loaded
            except Exception:
                pass

        messages = [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": user_text},
        ]

        # Build chat prompt when supported; otherwise fall back to plain instruction
        try:
            prompt = tokenizer.apply_chat_template(
                messages, tokenize=False, add_generation_prompt=True
            )
        except Exception:
            prompt = f"{system_prompt}\n\n{user_text}"

        # Allow more tokens for thinking overhead
        max_tokens = max(128, min(4096, int(len(user_text.split()) * 4)))
        try:
            text = generate(
                model,
                tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                temp=0.2,
                top_p=0.9,
                verbose=False,
            )
        except TypeError:
            text = generate(
                model,
                tokenizer,
                prompt=prompt,
                max_tokens=max_tokens,
                verbose=False,
            )

        # Some models include the prompt; try to trim leading prompt if echoed
        if text.startswith(prompt):
            text = text[len(prompt) :]

        # Final cleanup - strip Qwen3 thinking blocks
        import re
        cleaned = re.sub(r"<think>.*?</think>", "", text, flags=re.DOTALL)
        # Strip incomplete <think> blocks (model truncated before closing tag)
        cleaned = re.sub(r"<think>.*", "", cleaned, flags=re.DOTALL)
        cleaned = cleaned.strip().strip('"').strip("'").strip()
        print(json.dumps({"success": True, "text": cleaned}))
        return 0
    except Exception as e:
        print(json.dumps({"success": False, "error": str(e)}))
        return 4


if __name__ == "__main__":
    sys.exit(main())
