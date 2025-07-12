#!/usr/bin/env python3
import sys
import json
import os
from parakeet_mlx import from_pretrained

def main():
    # Get audio file path from command-line arg
    if len(sys.argv) != 2:
        print("Usage: python transcribe.py <audio_path>", file=sys.stderr)
        sys.exit(1)
    
    audio_path = sys.argv[1]
    
    # Log to stderr so it doesn't interfere with JSON output
    print(f"Loading audio from: {audio_path}", file=sys.stderr)
    
    try:
        # Load model (downloads on first run; using 0.6B for speed)
        print("Loading Parakeet model (this may download ~600MB on first run)...", file=sys.stderr)
        model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v2")
        print("Model loaded successfully", file=sys.stderr)
        
        # Transcribe (handles punctuation, capitalization)
        print("Starting transcription...", file=sys.stderr)
        result = model.transcribe(audio_path)
        print("Transcription complete", file=sys.stderr)
        
        # Output as JSON for better error handling and future extensibility
        output = {
            "text": result.text,
            "success": True
        }
        print(json.dumps(output))
        
    except Exception as e:
        # Output error as JSON
        error_output = {
            "text": "",
            "success": False,
            "error": str(e)
        }
        print(json.dumps(error_output))
        sys.exit(1)

if __name__ == "__main__":
    main()