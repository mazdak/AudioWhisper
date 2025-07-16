#!/usr/bin/env python3
"""
Test script for AudioWhisper Semantic Correction features.
Tests all semantic correction modes: Off, Local (MLX), and Cloud (OpenAI/Gemini).
"""

import subprocess
import os
import time

# Configuration – can be overridden via env
# AW_PYTHON: absolute path to Python interpreter to use
# Defaults to the app-managed venv Python
PYTHON_PATH = os.environ.get(
    "AW_PYTHON",
    os.path.expanduser(
        "~/Library/Application Support/AudioWhisper/python_project/.venv/bin/python3"
    ),
)

# Test sentences with intentional errors
TEST_SENTENCES = [
    "hey can you pick up some milk on your way home oh and don't forget the bred were out",
    "in quantum mechanics the schrodinger equation describes how the quantum state of a physical system changes with thyme",
    "i had a really long day at work today you know meetings back to back and then the boss wanted reports done by end of day but i managed to finish everything just in time barely",
    "the algorithm for binary search requires the array to be sorted in ass ending order",
    "whats the weather like tomorrow i think its supposed to rain but im not sure maybe i should check the app again",
    "during the mitosis phase cells divide into too daughter cells with identical genetic material",
    "i love going for runs in the park its so peaceful except when there are too many people then its crowded and not fun anymore but early mornings are best",
    "please schedule a meeting for next weak with the development team to discuss the new feature rollout",
    "artificial intelligence is advancing rapidly with models like gpt for capable of generating human like text",
    "my car broke down on the highway it was scary but luckily a tow truck came quick now its in the shop getting fixed hope its not too expensive",
    "in machine learning overfitting occurs when a model learns the training data to well including noise",
    "can you believe its already friday time flies weekend plans include relaxing and maybe watching some movies or perhaps going out if the weather is nice",
    "the periodic table organizes elements based on their atomic number which is the number of protons in the nucleolus",
    "i need to buy groceries apples bananas cereal and some veggies like carrots and broccolli",
    "The quik brown fox jumps ovr the lasy dog",
    "I havnt seen him in a wile but hes doing grate",
    "There going to the store to by some grocerys",
    "Its a beautifull day outside and the wether is perfekt",
    "She recieved the pakage yesterday but didnt open it yet",
]


# ANSI color codes for pretty output
class Colors:
    HEADER = "\033[95m"
    BLUE = "\033[94m"
    CYAN = "\033[96m"
    GREEN = "\033[92m"
    YELLOW = "\033[93m"
    RED = "\033[91m"
    ENDC = "\033[0m"
    BOLD = "\033[1m"


def print_header(text):
    print(f"\n{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{text}{Colors.ENDC}")
    print(f"{Colors.HEADER}{Colors.BOLD}{'=' * 60}{Colors.ENDC}")


def print_test(name, status, message=""):
    if status == "success":
        symbol = "✅"
        color = Colors.GREEN
    elif status == "warning":
        symbol = "⚠️"
        color = Colors.YELLOW
    elif status == "error":
        symbol = "❌"
        color = Colors.RED
    else:
        symbol = "ℹ️"
        color = Colors.CYAN

    print(f"{symbol} {color}{name}{Colors.ENDC}:\n{message}")


def test_mlx_correction(text, model_repo="mlx-community/Qwen2.5-1.5B-Instruct-4bit"):
    """Test MLX semantic correction."""
    print(f"\n{Colors.CYAN}Testing MLX Model: {model_repo}{Colors.ENDC}")

    # Use percent-formatting to avoid f-string brace conflicts inside embedded Python code
    script = """
import sys
import json

text = %r

try:
    from mlx_lm import load, generate
    
    # Load model (will use cached version if already downloaded)
    print("Loading model...", file=sys.stderr)
    model, tokenizer = load(%r)
    # Build a chat-style prompt when available (Gemma 2 / Llama / Qwen IT models)
    user_msg = "Fix any spelling or grammar errors in the following text. Only output the corrected text, nothing else." + "\\n\\n" + text
    try:
        prompt = tokenizer.apply_chat_template(
            [{"role": "user", "content": user_msg}],
            tokenize=False,
            add_generation_prompt=True,
        )
    except Exception:
        # Fallback: plain instruction
        prompt = (
            "You are a helpful assistant that corrects spelling and grammar." +
            "\\n" +
            "Only output the corrected text, nothing else." +
            "\\n\\n" + text
        )

    # Generate correction with conservative sampling and EOS handling to avoid repetition
    print("Generating correction...", file=sys.stderr)
    try:
        response = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=256,
            temp=0.2,
            top_p=0.9,
        )
    except TypeError:
        # Fallback if signature changes
        response = generate(
            model,
            tokenizer,
            prompt=prompt,
            max_tokens=256,
        )

    # If the model echoed part of the prompt, trim it
    if isinstance(response, str) and response.startswith(prompt):
        response = response[len(prompt):]

    # Final cleanup: strip quotes / code fences
    if isinstance(response, str):
        response = response.strip().strip('"').strip("'").strip()
    print(response)
    
except ImportError as e:
    print(f"ERROR: mlx-lm not installed - {e}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR: {e}", file=sys.stderr)
    sys.exit(1)
""" % (text, model_repo)

    try:
        start_time = time.time()
        result = subprocess.run(
            [PYTHON_PATH, "-c", script],
            capture_output=True,
            text=True,
            timeout=120,  # Increased timeout for MLX models
        )
        elapsed = time.time() - start_time

        if result.returncode == 0:
            correction = result.stdout.strip()
            # Clean up the response - sometimes models add extra text
            lines = correction.split("\n")
            # Take the first non-empty line as the correction
            for line in lines:
                if (
                    line.strip()
                    and not line.startswith("Fix")
                    and not line.startswith("Corrected")
                ):
                    correction = line.strip()
                    break

            print_test("MLX Correction", "success", f"Completed in {elapsed:.1f}s")
            return correction
        else:
            print_test("MLX Correction", "error", result.stderr.strip())
            return None
    except subprocess.TimeoutExpired:
        print_test("MLX Correction", "error", "Timed out after 120s")
        return None
    except Exception as e:
        print_test("MLX Correction", "error", str(e))
        return None


def test_openai_correction(text, api_key):
    """Test OpenAI semantic correction."""
    print(f"\n{Colors.CYAN}Testing OpenAI gpt-5-nano{Colors.ENDC}")

    if not api_key:
        print_test("OpenAI Correction", "warning", "No API key provided")
        return None

    script = f'''
import sys
import json
import urllib.request
import urllib.error

text = """{text}"""
api_key = "{api_key}"

try:
    url = "https://api.openai.com/v1/chat/completions"
    
    headers = {{
        "Authorization": f"Bearer {{api_key}}",
        "Content-Type": "application/json"
    }}
    
    data = {{
        "model": "gpt-5-nano",
        "messages": [
            {{"role": "system", "content": "You are a helpful assistant that corrects spelling and grammar errors. Only output the corrected text, nothing else."}},
            {{"role": "user", "content": f"Fix any errors in this text: {{text}}"}}
        ],
        "max_completion_tokens": 8192  # Standardized limit
        # Note: gpt-5-nano doesn't support temperature adjustment
    }}
    
    req = urllib.request.Request(
        url, 
        data=json.dumps(data).encode('utf-8'),
        headers=headers
    )
    
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        correction = result['choices'][0]['message']['content'].strip()
        print(correction)
        
except urllib.error.HTTPError as e:
    error_body = e.read().decode('utf-8')
    print(f"ERROR: HTTP {{e.code}} - {{e.reason}} - {{error_body}}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR: {{e}}", file=sys.stderr)
    sys.exit(1)
'''

    try:
        start_time = time.time()
        result = subprocess.run(
            [PYTHON_PATH, "-c", script], capture_output=True, text=True, timeout=30
        )
        elapsed = time.time() - start_time

        if result.returncode == 0:
            correction = result.stdout.strip()
            print_test("OpenAI Correction", "success", f"Completed in {elapsed:.1f}s")
            return correction
        else:
            print_test("OpenAI Correction", "error", result.stderr.strip())
            return None
    except Exception as e:
        print_test("OpenAI Correction", "error", str(e))
        return None


def test_gemini_correction(text, api_key):
    """Test Google Gemini semantic correction."""
    print(f"\n{Colors.CYAN}Testing Google Gemini Flash Lite{Colors.ENDC}")

    if not api_key:
        print_test("Gemini Correction", "warning", "No API key provided")
        return None

    script = f'''
import sys
import json
import urllib.request
import urllib.error

text = """{text}"""
api_key = "{api_key}"

try:
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash-lite:generateContent?key={{api_key}}"
    
    data = {{
        "contents": [{{
            "parts": [{{
                "text": f"Fix any spelling or grammar errors in the following text. Only output the corrected text, nothing else: {{text}}"
            }}]
        }}],
        "generationConfig": {{
            "temperature": 0.3,
            "maxOutputTokens": 8192  # Standardized limit
        }}
    }}
    
    req = urllib.request.Request(
        url, 
        data=json.dumps(data).encode('utf-8'),
        headers={{"Content-Type": "application/json"}}
    )
    
    with urllib.request.urlopen(req) as response:
        result = json.loads(response.read().decode('utf-8'))
        # Handle different response structures
        if 'candidates' in result and result['candidates']:
            candidate = result['candidates'][0]
            if 'content' in candidate:
                if 'parts' in candidate['content']:
                    correction = candidate['content']['parts'][0]['text'].strip()
                else:
                    correction = candidate['content'].get('text', '').strip()
            else:
                correction = candidate.get('text', '').strip()
        else:
            correction = "No response generated"
        print(correction)
        
except urllib.error.HTTPError as e:
    error_body = e.read().decode('utf-8')
    print(f"ERROR: HTTP {{e.code}} - {{e.reason}} - {{error_body}}", file=sys.stderr)
    sys.exit(1)
except Exception as e:
    print(f"ERROR: {{e}}", file=sys.stderr)
    sys.exit(1)
'''

    try:
        start_time = time.time()
        result = subprocess.run(
            [PYTHON_PATH, "-c", script], capture_output=True, text=True, timeout=30
        )
        elapsed = time.time() - start_time

        if result.returncode == 0:
            correction = result.stdout.strip()
            print_test("Gemini Correction", "success", f"Completed in {elapsed:.1f}s")
            return correction
        else:
            print_test("Gemini Correction", "error", result.stderr.strip())
            return None
    except Exception as e:
        print_test("Gemini Correction", "error", str(e))
        return None


def compare_results(original, corrections):
    """Compare correction results."""
    print(f"\n{Colors.BOLD}Original:{Colors.ENDC} {original}")

    for name, corrected in corrections.items():
        if corrected:
            # Calculate simple similarity
            if corrected.lower() == original.lower():
                status = "No changes"
                color = Colors.YELLOW
            else:
                status = "Corrected"
                color = Colors.GREEN
            print(f"{color}{name:12} {status:12}{Colors.ENDC} {corrected}")


def main():
    print_header("AudioWhisper Semantic Correction Test Suite")

    # Get API keys from environment
    openai_key = os.environ.get("OPENAI_API_KEY", "")
    gemini_key = os.environ.get("GEMINI_API_KEY", "")

    if not openai_key:
        print(
            f"{Colors.YELLOW}ℹ️ Set OPENAI_API_KEY environment variable to test OpenAI{Colors.ENDC}"
        )
    if not gemini_key:
        print(
            f"{Colors.YELLOW}ℹ️ Set GEMINI_API_KEY environment variable to test Gemini{Colors.ENDC}"
        )

    # Test MLX models
    # Override with AW_MLX_MODELS (comma-separated repo list), e.g.:
    #   AW_MLX_MODELS="mlx-community/gemma-2-2b-it-4bit" python3 test_semantic_correction.py
    env_models = os.environ.get("AW_MLX_MODELS")
    if env_models:
        mlx_models = [m.strip() for m in env_models.split(",") if m.strip()]
    else:
        mlx_models = [
            # Defaults for local comparison
            "mlx-community/gemma-2-2b-it-4bit",
            "mlx-community/gemma-3n-E2B-3bit",
            # Uncomment to try more:
            # "mlx-community/Llama-3.2-3B-Instruct-4bit",
            # "mlx-community/Qwen3-4B-Instruct-2507-5bit",
        ]

    results_summary = {
        "mlx": {"success": 0, "failed": 0, "total_time": 0},
        "openai": {"success": 0, "failed": 0, "total_time": 0},
        "gemini": {"success": 0, "failed": 0, "total_time": 0},
    }

    for i, test_text in enumerate(TEST_SENTENCES, 1):
        print_header(f"Test {i}/{len(TEST_SENTENCES)}")

        corrections = {}

        # Test each MLX model
        for model in mlx_models:
            model_name = model.split("/")[-1]
            start = time.time()
            result = test_mlx_correction(test_text, model)
            elapsed = time.time() - start

            if result:
                corrections[f"MLX-{model_name[:15]}"] = result
                results_summary["mlx"]["success"] += 1
                results_summary["mlx"]["total_time"] += elapsed
            else:
                results_summary["mlx"]["failed"] += 1

        # Test OpenAI
        if openai_key:
            start = time.time()
            result = test_openai_correction(test_text, openai_key)
            elapsed = time.time() - start

            if result:
                corrections["OpenAI"] = result
                results_summary["openai"]["success"] += 1
                results_summary["openai"]["total_time"] += elapsed
            else:
                results_summary["openai"]["failed"] += 1

        # Test Gemini
        if gemini_key:
            start = time.time()
            result = test_gemini_correction(test_text, gemini_key)
            elapsed = time.time() - start

            if result:
                corrections["Gemini"] = result
                results_summary["gemini"]["success"] += 1
                results_summary["gemini"]["total_time"] += elapsed
            else:
                results_summary["gemini"]["failed"] += 1

        # Compare results
        compare_results(test_text, corrections)

    # Print summary
    print_header("Test Summary")

    for provider, stats in results_summary.items():
        if stats["success"] + stats["failed"] > 0:
            success_rate = (
                stats["success"] / (stats["success"] + stats["failed"])
            ) * 100
            avg_time = stats["total_time"] / max(stats["success"], 1)

            print(f"\n{Colors.BOLD}{provider.upper()}{Colors.ENDC}")
            print(
                f"  Success rate: {success_rate:.0f}% ({stats['success']}/{stats['success'] + stats['failed']})"
            )
            if stats["success"] > 0:
                print(f"  Average time: {avg_time:.1f}s")

    print(f"\n{Colors.GREEN}✅ Test suite completed!{Colors.ENDC}")


if __name__ == "__main__":
    main()
