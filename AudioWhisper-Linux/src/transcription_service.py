"""
Transcription service module for AudioWhisper Linux.
Supports OpenAI, Gemini, local Whisper, and Parakeet.
"""

import os
import asyncio
import subprocess
from pathlib import Path
from typing import Optional, Dict, Any
from abc import ABC, abstractmethod

import openai
import google.generativeai as genai
import whisper

class TranscriptionProvider(ABC):
    """Abstract base class for transcription providers."""
    
    @abstractmethod
    async def transcribe(self, audio_file: Path, **kwargs) -> str:
        """Transcribe audio file to text."""
        pass

class OpenAIProvider(TranscriptionProvider):
    """OpenAI Whisper API provider."""
    
    def __init__(self, api_key: str):
        self.client = openai.OpenAI(api_key=api_key)
    
    async def transcribe(self, audio_file: Path, **kwargs) -> str:
        """Transcribe using OpenAI Whisper API."""
        try:
            with open(audio_file, 'rb') as f:
                response = await asyncio.to_thread(
                    self.client.audio.transcriptions.create,
                    model="whisper-1",
                    file=f,
                    language=kwargs.get('language')
                )
            return response.text
        except Exception as e:
            raise Exception(f"OpenAI transcription failed: {str(e)}")

class GeminiProvider(TranscriptionProvider):
    """Google Gemini API provider."""
    
    def __init__(self, api_key: str):
        genai.configure(api_key=api_key)
        self.model = genai.GenerativeModel('gemini-1.5-flash')
    
    async def transcribe(self, audio_file: Path, **kwargs) -> str:
        """Transcribe using Google Gemini API."""
        try:
            # Upload the audio file
            uploaded_file = await asyncio.to_thread(
                genai.upload_file, 
                str(audio_file)
            )
            
            # Generate transcription
            prompt = "Transcribe this audio file to text. Only return the transcription, no other text."
            response = await asyncio.to_thread(
                self.model.generate_content,
                [prompt, uploaded_file]
            )
            
            # Clean up uploaded file
            await asyncio.to_thread(uploaded_file.delete)
            
            return response.text
        except Exception as e:
            raise Exception(f"Gemini transcription failed: {str(e)}")

class LocalWhisperProvider(TranscriptionProvider):
    """Local Whisper model provider using openai-whisper."""
    
    def __init__(self, model_name: str = "base"):
        self.model_name = model_name
        self.model = None
        self._load_model()
    
    def _load_model(self):
        """Load Whisper model."""
        try:
            self.model = whisper.load_model(self.model_name)
        except Exception as e:
            raise Exception(f"Failed to load Whisper model: {str(e)}")
    
    async def transcribe(self, audio_file: Path, **kwargs) -> str:
        """Transcribe using local Whisper model."""
        try:
            result = await asyncio.to_thread(
                self.model.transcribe,
                str(audio_file),
                language=kwargs.get('language'),
                fp16=False
            )
            return result['text'].strip()
        except Exception as e:
            raise Exception(f"Local Whisper transcription failed: {str(e)}")

class ParakeetProvider(TranscriptionProvider):
    """Parakeet MLX provider for fast local transcription."""
    
    def __init__(self, python_path: str = "/usr/bin/python3", 
                 ffmpeg_path: Optional[str] = None):
        self.python_path = python_path
        self.ffmpeg_path = ffmpeg_path or self._find_ffmpeg()
        self.script_path = Path(__file__).parent / "parakeet_transcribe.py"
        self._validate_setup()
    
    def _find_ffmpeg(self) -> str:
        """Find FFmpeg in common locations."""
        common_paths = [
            "/usr/bin/ffmpeg",
            "/usr/local/bin/ffmpeg",
            "/opt/homebrew/bin/ffmpeg",
        ]
        
        for path in common_paths:
            if os.path.exists(path):
                return path
        
        # Try which command
        try:
            result = subprocess.run(['which', 'ffmpeg'], 
                                  capture_output=True, text=True)
            if result.returncode == 0:
                return result.stdout.strip()
        except:
            pass
        
        return "ffmpeg"  # Fallback to PATH
    
    def _validate_setup(self):
        """Validate Parakeet setup."""
        # Check Python
        if not os.path.exists(self.python_path):
            raise Exception(f"Python not found at {self.python_path}")
        
        # Check parakeet-mlx installation
        try:
            subprocess.run(
                [self.python_path, '-c', 'import parakeet_mlx'],
                check=True, capture_output=True
            )
        except subprocess.CalledProcessError:
            raise Exception("parakeet-mlx not installed")
        
        # Check FFmpeg
        try:
            subprocess.run([self.ffmpeg_path, '-version'], 
                          check=True, capture_output=True)
        except:
            raise Exception(f"FFmpeg not found at {self.ffmpeg_path}")
    
    async def transcribe(self, audio_file: Path, **kwargs) -> str:
        """Transcribe using Parakeet MLX."""
        try:
            # Prepare environment
            env = os.environ.copy()
            if self.ffmpeg_path:
                env['FFMPEG_PATH'] = self.ffmpeg_path
            
            # Run transcription script
            result = await asyncio.create_subprocess_exec(
                self.python_path,
                str(self.script_path),
                str(audio_file),
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE,
                env=env
            )
            
            stdout, stderr = await result.communicate()
            
            if result.returncode != 0:
                raise Exception(f"Parakeet error: {stderr.decode()}")
            
            return stdout.decode().strip()
            
        except Exception as e:
            raise Exception(f"Parakeet transcription failed: {str(e)}")

class TranscriptionService:
    """Main transcription service managing all providers."""
    
    def __init__(self, config):
        self.config = config
        self.providers = {}
        self._init_providers()
    
    def _init_providers(self):
        """Initialize available providers."""
        # OpenAI
        openai_key = self.config.get_api_key('openai')
        if openai_key:
            self.providers['openai'] = OpenAIProvider(openai_key)
        
        # Gemini
        gemini_key = self.config.get_api_key('gemini')
        if gemini_key:
            self.providers['gemini'] = GeminiProvider(gemini_key)
        
        # Local Whisper (always available)
        try:
            model_name = self.config.get('transcription.local_model', 'base')
            self.providers['local'] = LocalWhisperProvider(model_name)
        except Exception as e:
            print(f"Failed to initialize local Whisper: {e}")
        
        # Parakeet
        try:
            python_path = self.config.get('transcription.python_path', '/usr/bin/python3')
            ffmpeg_path = self.config.get('transcription.ffmpeg_path')
            self.providers['parakeet'] = ParakeetProvider(python_path, ffmpeg_path)
        except Exception as e:
            print(f"Failed to initialize Parakeet: {e}")
    
    async def transcribe(self, audio_file: Path, 
                        provider: Optional[str] = None) -> str:
        """Transcribe audio file using specified or default provider."""
        # Use specified provider or get from config
        if not provider:
            provider = self.config.get('transcription.provider', 'openai')
        
        # Check if provider is available
        if provider not in self.providers:
            available = list(self.providers.keys())
            if not available:
                raise Exception("No transcription providers available")
            
            # Fallback to first available provider
            provider = available[0]
            print(f"Requested provider not available, using {provider}")
        
        # Get language setting
        language = self.config.get('transcription.language')
        if language == 'auto':
            language = None
        
        # Perform transcription
        return await self.providers[provider].transcribe(
            audio_file, 
            language=language
        )
    
    def get_available_providers(self) -> list:
        """Get list of available providers."""
        return list(self.providers.keys())
    
    def reload_providers(self):
        """Reload providers (e.g., after config change)."""
        self.providers.clear()
        self._init_providers()