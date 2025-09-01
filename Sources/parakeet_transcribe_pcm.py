#!/usr/bin/env python3
"""
Parakeet transcription script that accepts pre-processed raw PCM data.
This eliminates the need for FFmpeg or audio processing in Python.
"""

import sys
import json
import os

# Set environment to force offline operation
os.environ['HF_HUB_OFFLINE'] = '1'
os.environ['TRANSFORMERS_OFFLINE'] = '1'
os.environ['HF_HUB_DISABLE_IMPLICIT_TOKEN'] = '1'

try:
    import numpy as np
except ImportError as e:
    print(f"❌ numpy import failed: {e}", file=sys.stderr)
    sys.exit(1)

try:
    import mlx.core as mx
except ImportError as e:
    print(f"❌ mlx.core import failed: {e}", file=sys.stderr)
    sys.exit(1)

try:
    from parakeet_mlx import from_pretrained
    from parakeet_mlx.audio import get_logmel
except ImportError as e:
    print(f"❌ parakeet_mlx import failed: {e}", file=sys.stderr)
    print("Make sure parakeet-mlx is installed in this Python environment", file=sys.stderr)
    sys.exit(1)


def load_raw_pcm(pcm_file_path, sample_rate=16000):
    """Load pre-processed raw float32 PCM data"""
    try:
        # Read raw float32 data from file
        audio_data = np.fromfile(pcm_file_path, dtype=np.float32)
        return audio_data
    except Exception as e:
        print(f"Error loading PCM data: {e}", file=sys.stderr)
        raise


def main():
    if len(sys.argv) != 2:
        print("Usage: python parakeet_transcribe_pcm.py <pcm_file_path>", file=sys.stderr)
        print("Expected input: Raw float32 PCM data at 16kHz, mono", file=sys.stderr)
        sys.exit(1)

    pcm_file_path = sys.argv[1]

    try:
        # Load Parakeet model (should be cached locally after ensureParakeetModel)
        # Try offline loading first to avoid network timeouts
        try:
            model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v2", local_files_only=True)
        except Exception as offline_error:
            print(f"Offline loading failed: {offline_error}", file=sys.stderr)
            print("Falling back to online loading (this may take time)...", file=sys.stderr)
            model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v2")

        # Check if PCM file exists
        import os
        if not os.path.exists(pcm_file_path):
            raise FileNotFoundError(f"PCM file not found: {pcm_file_path}")

        if not os.access(pcm_file_path, os.R_OK):
            raise PermissionError(f"Cannot read PCM file: {pcm_file_path}")

        # Load the pre-processed PCM data
        audio_data = load_raw_pcm(pcm_file_path, sample_rate=16000)
        
        # Convert numpy array to MLX array (parakeet-mlx's format)
        audio_mlx = mx.array(audio_data.astype(np.float32))
        
        # Convert directly to log-mel spectrogram (bypassing load_audio entirely)
        mel = get_logmel(audio_mlx, model.preprocessor_config)
        
        # Generate transcription from mel spectrogram
        result = model.generate(mel)

        # Extract text from result - handle list of AlignedResult objects
        if isinstance(result, list) and len(result) > 0:
            # model.generate() returns a list of AlignedResult objects
            text = result[0].text if hasattr(result[0], 'text') else str(result[0])
        elif hasattr(result, "text"):
            text = result.text
        elif hasattr(result, "texts") and len(result.texts) > 0:
            text = result.texts[0]
        elif isinstance(result, dict) and "text" in result:
            text = result["text"]
        elif isinstance(result, dict) and "texts" in result and len(result["texts"]) > 0:
            text = result["texts"][0]
        else:
            raise AttributeError(f"Cannot extract text from result: {result}")
        
        text = text if text else ""

        # Output as JSON
        output = {"text": text, "success": True}
        print(json.dumps(output))

    except Exception as e:
        # Output error as JSON
        error_output = {"text": "", "success": False, "error": str(e)}
        print(json.dumps(error_output))
        sys.exit(1)


if __name__ == "__main__":
    main()