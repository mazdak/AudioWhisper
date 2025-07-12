#!/usr/bin/env python3
import sys
import json
import os
from parakeet_mlx import from_pretrained


# Add common FFmpeg paths to environment (for app bundle execution)
def setup_ffmpeg_path():
    """Add common FFmpeg installation paths to PATH environment variable"""
    # Check if a custom FFmpeg path is provided
    custom_ffmpeg_path = os.environ.get("PARAKEET_FFMPEG_PATH", "").strip()
    if custom_ffmpeg_path:
        # Handle both directory and full binary path
        if os.path.isfile(custom_ffmpeg_path):
            # Full path to ffmpeg binary provided (e.g., /opt/homebrew/bin/ffmpeg)
            ffmpeg_dir = os.path.dirname(custom_ffmpeg_path)
            current_path = os.environ.get("PATH", "")
            if ffmpeg_dir not in current_path:
                os.environ["PATH"] = f"{ffmpeg_dir}:{current_path}"
                print(
                    f"Using custom FFmpeg binary: {custom_ffmpeg_path}", file=sys.stderr
                )
            return
        elif os.path.isdir(custom_ffmpeg_path):
            # Directory path provided (e.g., /opt/homebrew/bin)
            ffmpeg_binary = os.path.join(custom_ffmpeg_path, "ffmpeg")
            if os.path.isfile(ffmpeg_binary):
                current_path = os.environ.get("PATH", "")
                if custom_ffmpeg_path not in current_path:
                    os.environ["PATH"] = f"{custom_ffmpeg_path}:{current_path}"
                    print(
                        f"Using FFmpeg from directory: {ffmpeg_binary}", file=sys.stderr
                    )
                return
            else:
                print(
                    f"Warning: FFmpeg not found in specified directory: {custom_ffmpeg_path}",
                    file=sys.stderr,
                )
                print(f"Expected: {ffmpeg_binary}", file=sys.stderr)
        else:
            print(
                f"Warning: Invalid FFmpeg path specified: {custom_ffmpeg_path}",
                file=sys.stderr,
            )
            print(
                "Path should be either directory containing ffmpeg or full path to ffmpeg binary",
                file=sys.stderr,
            )

    # Fall back to common installation paths
    common_paths = [
        "/opt/homebrew/bin",  # Homebrew on Apple Silicon
        "/usr/local/bin",  # Homebrew on Intel
        "/usr/bin",  # System installation
        "/opt/local/bin",  # MacPorts
    ]

    current_path = os.environ.get("PATH", "")
    additional_paths = [
        path
        for path in common_paths
        if os.path.isdir(path) and path not in current_path
    ]

    if additional_paths:
        new_path = ":".join(additional_paths + [current_path])
        os.environ["PATH"] = new_path


def main():
    # Setup FFmpeg PATH before anything else
    setup_ffmpeg_path()

    # Validate that FFmpeg is now available
    import shutil

    if not shutil.which("ffmpeg"):
        print("Error: FFmpeg is not available in PATH after setup", file=sys.stderr)
        print("Please install FFmpeg: brew install ffmpeg", file=sys.stderr)
        print("Or specify a custom path in AudioWhisper settings", file=sys.stderr)

    # Get audio file path from command-line arg
    if len(sys.argv) != 2:
        print("Usage: python transcribe.py <audio_path>", file=sys.stderr)
        sys.exit(1)

    audio_path = sys.argv[1]

    # Log to stderr so it doesn't interfere with JSON output
    print(f"Loading audio from: {audio_path}", file=sys.stderr)

    try:
        # Load model (downloads on first run; using 0.6B for speed)
        print(
            "Loading Parakeet model (this may download ~600MB on first run)...",
            file=sys.stderr,
        )
        model = from_pretrained("mlx-community/parakeet-tdt-0.6b-v2")
        print("Model loaded successfully", file=sys.stderr)

        # Transcribe (handles punctuation, capitalization)
        print("Starting transcription...", file=sys.stderr)

        # Check if audio file exists and is readable
        if not os.path.exists(audio_path):
            raise FileNotFoundError(f"Audio file not found: {audio_path}")

        if not os.access(audio_path, os.R_OK):
            raise PermissionError(f"Cannot read audio file: {audio_path}")

        try:
            result = model.transcribe(audio_path)
            print("Transcription complete", file=sys.stderr)

            # Check if result has the expected structure
            if not hasattr(result, "text"):
                raise AttributeError("Transcription result missing 'text' attribute")

            text = result.text if result.text else ""

        except Exception as transcribe_error:
            print(f"Transcription error: {transcribe_error}", file=sys.stderr)
            raise transcribe_error

        # Output as JSON for better error handling and future extensibility
        output = {"text": text, "success": True}
        print(json.dumps(output))

    except Exception as e:
        # Output error as JSON
        error_output = {"text": "", "success": False, "error": str(e)}
        print(json.dumps(error_output))
        sys.exit(1)


if __name__ == "__main__":
    main()

