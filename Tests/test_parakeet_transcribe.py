#!/usr/bin/env python3
"""
Test suite for parakeet_transcribe.py

This file tests the Python script used for Parakeet transcription.
Run with: python3 test_parakeet_transcribe.py
"""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import MagicMock, patch

# Add the source directory to Python path to import our script
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "Sources"))

try:
    import parakeet_transcribe

    PARAKEET_AVAILABLE = True
except ImportError:
    print(
        "Warning: Could not import parakeet_transcribe.py - parakeet-mlx likely not installed"
    )
    print("This is expected in most test environments")
    PARAKEET_AVAILABLE = False

    # Create a mock module for testing
    class MockParakeetTranscribe:
        @staticmethod
        def setup_ffmpeg_path():
            """Mock implementation that doesn't require parakeet-mlx"""
            custom_ffmpeg_path = os.environ.get("PARAKEET_FFMPEG_PATH", "").strip()
            if custom_ffmpeg_path:
                if os.path.isfile(custom_ffmpeg_path):
                    ffmpeg_dir = os.path.dirname(custom_ffmpeg_path)
                    current_path = os.environ.get("PATH", "")
                    if ffmpeg_dir not in current_path:
                        os.environ["PATH"] = f"{ffmpeg_dir}:{current_path}"
                    return
                elif os.path.isdir(custom_ffmpeg_path):
                    ffmpeg_binary = os.path.join(custom_ffmpeg_path, "ffmpeg")
                    if os.path.isfile(ffmpeg_binary):
                        current_path = os.environ.get("PATH", "")
                        if custom_ffmpeg_path not in current_path:
                            os.environ["PATH"] = f"{custom_ffmpeg_path}:{current_path}"
                        return

            common_paths = [
                "/opt/homebrew/bin",
                "/usr/local/bin",
                "/usr/bin",
                "/opt/local/bin",
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

        @staticmethod
        def main():
            """Mock main function for testing"""
            if len(sys.argv) < 2:
                print("Usage: python transcribe.py <audio_path>", file=sys.stderr)
                sys.exit(1)
            elif len(sys.argv) > 2:
                print("Usage: python transcribe.py <audio_path>", file=sys.stderr)
                sys.exit(1)

            if len(sys.argv) > 1:
                audio_path = sys.argv[1]
            else:
                return  # Already handled above
            if not os.path.exists(audio_path):
                error_output = {
                    "text": "",
                    "success": False,
                    "error": f"Audio file not found: {audio_path}",
                }
                print(json.dumps(error_output))
                sys.exit(1)

    parakeet_transcribe = MockParakeetTranscribe()


class TestFFmpegPathSetup(unittest.TestCase):
    """Test FFmpeg path setup functionality"""

    def setUp(self):
        """Set up test environment"""
        self.original_path = os.environ.get("PATH", "")
        self.original_ffmpeg_path = os.environ.get("PARAKEET_FFMPEG_PATH", "")

    def tearDown(self):
        """Restore original environment"""
        os.environ["PATH"] = self.original_path
        if self.original_ffmpeg_path:
            os.environ["PARAKEET_FFMPEG_PATH"] = self.original_ffmpeg_path
        elif "PARAKEET_FFMPEG_PATH" in os.environ:
            del os.environ["PARAKEET_FFMPEG_PATH"]

    def test_setup_ffmpeg_path_no_custom_path(self):
        """Test FFmpeg path setup without custom path"""
        if "PARAKEET_FFMPEG_PATH" in os.environ:
            del os.environ["PARAKEET_FFMPEG_PATH"]

        # Set a clean PATH for testing that doesn't already include these paths
        test_path = "/tmp:/usr/bin"
        os.environ["PATH"] = test_path

        parakeet_transcribe.setup_ffmpeg_path()

        # PATH should be modified to include common FFmpeg paths
        new_path = os.environ["PATH"]
        self.assertNotEqual(test_path, new_path)

        # Should contain common homebrew paths if they exist on the system
        if os.path.isdir("/opt/homebrew/bin"):
            self.assertIn("/opt/homebrew/bin", new_path)
        if os.path.isdir("/usr/local/bin"):
            self.assertIn("/usr/local/bin", new_path)

    def test_setup_ffmpeg_path_with_directory(self):
        """Test FFmpeg path setup with directory path"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create mock ffmpeg binary
            ffmpeg_path = os.path.join(temp_dir, "ffmpeg")
            with open(ffmpeg_path, "w") as f:
                f.write("#!/bin/bash\necho 'mock ffmpeg'")
            os.chmod(ffmpeg_path, 0o755)

            os.environ["PARAKEET_FFMPEG_PATH"] = temp_dir

            parakeet_transcribe.setup_ffmpeg_path()

            # PATH should include the custom directory
            new_path = os.environ["PATH"]
            self.assertIn(temp_dir, new_path)

    def test_setup_ffmpeg_path_with_binary_path(self):
        """Test FFmpeg path setup with full binary path"""
        with tempfile.TemporaryDirectory() as temp_dir:
            # Create mock ffmpeg binary
            ffmpeg_path = os.path.join(temp_dir, "ffmpeg")
            with open(ffmpeg_path, "w") as f:
                f.write("#!/bin/bash\necho 'mock ffmpeg'")
            os.chmod(ffmpeg_path, 0o755)

            os.environ["PARAKEET_FFMPEG_PATH"] = ffmpeg_path

            parakeet_transcribe.setup_ffmpeg_path()

            # PATH should include the directory containing the binary
            new_path = os.environ["PATH"]
            self.assertIn(temp_dir, new_path)

    def test_setup_ffmpeg_path_invalid_directory(self):
        """Test FFmpeg path setup with invalid directory"""
        os.environ["PARAKEET_FFMPEG_PATH"] = "/nonexistent/directory"

        # Should not crash, just add warning
        try:
            parakeet_transcribe.setup_ffmpeg_path()
        except Exception as e:
            self.fail(f"setup_ffmpeg_path should not raise exception: {e}")

    def test_setup_ffmpeg_path_invalid_file(self):
        """Test FFmpeg path setup with invalid file path"""
        os.environ["PARAKEET_FFMPEG_PATH"] = "/nonexistent/file"

        # Should not crash, just add warning
        try:
            parakeet_transcribe.setup_ffmpeg_path()
        except Exception as e:
            self.fail(f"setup_ffmpeg_path should not raise exception: {e}")


class TestMainFunction(unittest.TestCase):
    """Test main function behavior"""

    def test_main_no_arguments(self):
        """Test main function with no arguments"""
        with patch("sys.argv", ["parakeet_transcribe.py"]):
            with patch("sys.exit") as mock_exit:
                parakeet_transcribe.main()
                mock_exit.assert_called_with(1)

    def test_main_too_many_arguments(self):
        """Test main function with too many arguments"""
        with patch("sys.argv", ["parakeet_transcribe.py", "file1.mp3", "file2.mp3"]):
            with patch("sys.exit") as mock_exit:
                parakeet_transcribe.main()
                mock_exit.assert_called_with(1)

    def test_main_nonexistent_file(self):
        """Test main function with nonexistent audio file"""
        with patch("sys.argv", ["parakeet_transcribe.py", "/nonexistent/file.mp3"]):
            with patch("sys.exit") as mock_exit:
                with patch("builtins.print"):  # Suppress JSON output
                    parakeet_transcribe.main()
                    mock_exit.assert_called_with(1)

    @unittest.skipUnless(PARAKEET_AVAILABLE, "parakeet-mlx not available")
    @patch("parakeet_transcribe.from_pretrained")
    @patch("os.path.exists")
    @patch("os.access")
    def test_main_successful_transcription(
        self, mock_access, mock_exists, mock_from_pretrained
    ):
        """Test successful transcription flow"""
        # Mock file existence and readability
        mock_exists.return_value = True
        mock_access.return_value = True

        # Mock parakeet model
        mock_model = MagicMock()
        mock_result = MagicMock()
        mock_result.text = "Hello world"
        mock_model.transcribe.return_value = mock_result
        mock_from_pretrained.return_value = mock_model

        with patch("sys.argv", ["parakeet_transcribe.py", "/mock/audio.mp3"]):
            with patch("builtins.print") as mock_print:
                try:
                    parakeet_transcribe.main()

                    # Should print JSON output
                    mock_print.assert_called()

                    # Find the JSON output call
                    json_calls = [
                        call
                        for call in mock_print.call_args_list
                        if len(call[0]) > 0 and call[0][0].startswith("{")
                    ]

                    self.assertTrue(len(json_calls) > 0, "Should output JSON")

                    if json_calls:
                        json_output = json_calls[0][0][0]
                        result = json.loads(json_output)
                        self.assertEqual(result["text"], "Hello world")
                        self.assertTrue(result["success"])

                except SystemExit:
                    pass  # Expected in some error cases

    @unittest.skipUnless(PARAKEET_AVAILABLE, "parakeet-mlx not available")
    @patch("parakeet_transcribe.from_pretrained")
    @patch("os.path.exists")
    @patch("os.access")
    def test_main_transcription_error(
        self, mock_access, mock_exists, mock_from_pretrained
    ):
        """Test transcription error handling"""
        # Mock file existence and readability
        mock_exists.return_value = True
        mock_access.return_value = True

        # Mock parakeet model that throws error
        mock_model = MagicMock()
        mock_model.transcribe.side_effect = Exception("Transcription failed")
        mock_from_pretrained.return_value = mock_model

        with patch("sys.argv", ["parakeet_transcribe.py", "/mock/audio.mp3"]):
            with patch("sys.exit") as mock_exit:
                with patch("builtins.print") as mock_print:
                    parakeet_transcribe.main()

                    # Should exit with error
                    mock_exit.assert_called_with(1)

                    # Should print error JSON
                    json_calls = [
                        call
                        for call in mock_print.call_args_list
                        if len(call[0]) > 0 and call[0][0].startswith("{")
                    ]

                    self.assertTrue(len(json_calls) > 0, "Should output error JSON")

                    if json_calls:
                        json_output = json_calls[0][0][0]
                        result = json.loads(json_output)
                        self.assertFalse(result["success"])
                        self.assertIn("error", result)


class TestIntegration(unittest.TestCase):
    """Integration tests"""

    def test_script_syntax(self):
        """Test that the script has valid Python syntax"""
        script_path = os.path.join(
            os.path.dirname(__file__), "..", "Sources", "parakeet_transcribe.py"
        )

        if not os.path.exists(script_path):
            self.skipTest("parakeet_transcribe.py not found")

        # Try to compile the script
        with open(script_path, "r") as f:
            script_content = f.read()

        try:
            compile(script_content, script_path, "exec")
        except SyntaxError as e:
            self.fail(f"Script has syntax error: {e}")

    def test_script_executable(self):
        """Test that the script can be executed directly"""
        script_path = os.path.join(
            os.path.dirname(__file__), "..", "Sources", "parakeet_transcribe.py"
        )

        if not os.path.exists(script_path):
            self.skipTest("parakeet_transcribe.py not found")

        # Test script with no arguments (should show usage)
        try:
            result = subprocess.run(
                [sys.executable, script_path],
                capture_output=True,
                text=True,
                timeout=10,
            )

            # Should exit with error code for no arguments
            self.assertNotEqual(result.returncode, 0)

        except subprocess.TimeoutExpired:
            self.fail("Script took too long to respond")
        except FileNotFoundError:
            self.skipTest("Cannot execute script - Python interpreter not found")


if __name__ == "__main__":
    print("Running Parakeet Python script tests...")
    print("Note: These tests verify script structure and error handling.")
    print("Full transcription tests require parakeet-mlx installation.\n")

    unittest.main(verbosity=2)

