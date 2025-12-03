#!/usr/bin/env python3
import os, json, traceback, sys

def emit(status, message):
    print(json.dumps({"status": status, "message": message}), flush=True)

def main():
    os.environ['HF_HUB_DISABLE_IMPLICIT_TOKEN'] = '1'
    # Default to v3 multilingual model if not specified
    repo = sys.argv[1] if len(sys.argv) > 1 else "mlx-community/parakeet-tdt-0.6b-v3"
    try:
        emit("checking", "Importing parakeet-mlx…")
        from parakeet_mlx import from_pretrained

        # Try offline first
        os.environ['HF_HUB_OFFLINE'] = '1'
        os.environ['TRANSFORMERS_OFFLINE'] = '1'
        try:
            emit("loading", "Trying offline cache…")
            _ = from_pretrained(repo)
            emit("complete", "Model ready (offline)")
        except Exception as e:
            # Fallback online
            os.environ.pop('HF_HUB_OFFLINE', None)
            os.environ.pop('TRANSFORMERS_OFFLINE', None)
            emit("downloading", "Offline unavailable: {}. Downloading…".format(str(e)))
            _ = from_pretrained(repo)
            emit("complete", "Model downloaded and ready")
    except ImportError as e:
        emit("error", "parakeet-mlx not installed: {}. Use Install Dependencies.".format(str(e)))
        return 1
    except Exception as e:
        emit("error", "Error: {}\n{}".format(str(e), traceback.format_exc()))
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

