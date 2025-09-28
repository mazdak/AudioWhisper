#!/usr/bin/env python3
import os, sys, json, traceback

def emit(status, message):
    print(json.dumps({"status": status, "message": message}), flush=True)

def main():
    repo = sys.argv[1] if len(sys.argv) > 1 else ""
    if not repo:
        emit("error", "No repo specified")
        return 1
    os.environ['HF_HUB_DISABLE_IMPLICIT_TOKEN'] = '1'
    try:
        emit("checking", "Importing mlx-lm…")
        from mlx_lm import load

        # Try offline first
        os.environ['HF_HUB_OFFLINE'] = '1'
        os.environ['TRANSFORMERS_OFFLINE'] = '1'
        try:
            emit("loading", "Trying offline cache…")
            _m, _t = load(repo)
            emit("complete", "Model ready (offline)")
        except Exception as e:
            os.environ.pop('HF_HUB_OFFLINE', None)
            os.environ.pop('TRANSFORMERS_OFFLINE', None)
            emit("downloading", "Offline unavailable: {}. Downloading…".format(str(e)))
            _m, _t = load(repo)
            emit("complete", "Model downloaded and ready")
    except ImportError as e:
        emit("error", "mlx-lm not installed: {}. Use Install Dependencies.".format(str(e)))
        return 1
    except Exception as e:
        emit("error", "Error: {}\n{}".format(str(e), traceback.format_exc()))
        return 1
    return 0

if __name__ == "__main__":
    raise SystemExit(main())

