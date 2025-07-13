"""
Audio recording module for AudioWhisper Linux.
Handles audio capture, level monitoring, and file management.
"""

import os
import wave
import threading
import numpy as np
import pyaudio
import tempfile
from pathlib import Path
from typing import Callable, Optional, Tuple
from datetime import datetime

class AudioRecorder:
    """Manages audio recording with real-time level monitoring."""
    
    def __init__(self, 
                 sample_rate: int = 16000,
                 channels: int = 1,
                 chunk_size: int = 1024):
        self.sample_rate = sample_rate
        self.channels = channels
        self.chunk_size = chunk_size
        self.format = pyaudio.paInt16
        
        self.audio = pyaudio.PyAudio()
        self.stream = None
        self.recording_thread = None
        self.is_recording = False
        self.audio_level = 0.0
        self.level_callback = None
        self.frames = []
        self.current_file = None
        
    def set_level_callback(self, callback: Callable[[float], None]):
        """Set callback for audio level updates."""
        self.level_callback = callback
    
    def get_input_devices(self) -> list:
        """Get list of available input devices."""
        devices = []
        for i in range(self.audio.get_device_count()):
            info = self.audio.get_device_info_by_index(i)
            if info['maxInputChannels'] > 0:
                devices.append({
                    'index': i,
                    'name': info['name'],
                    'channels': info['maxInputChannels']
                })
        return devices
    
    def start_recording(self, device_index: Optional[int] = None) -> bool:
        """Start audio recording."""
        if self.is_recording:
            return False
        
        try:
            # Create temporary file for recording
            timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
            self.current_file = Path(tempfile.mkdtemp()) / f"recording_{timestamp}.wav"
            
            # Open audio stream
            self.stream = self.audio.open(
                format=self.format,
                channels=self.channels,
                rate=self.sample_rate,
                input=True,
                input_device_index=device_index,
                frames_per_buffer=self.chunk_size,
                stream_callback=self._audio_callback
            )
            
            self.frames = []
            self.is_recording = True
            self.stream.start_stream()
            
            return True
            
        except Exception as e:
            print(f"Error starting recording: {e}")
            return False
    
    def _audio_callback(self, in_data, frame_count, time_info, status):
        """Callback for audio stream processing."""
        if self.is_recording:
            self.frames.append(in_data)
            
            # Calculate audio level
            audio_data = np.frombuffer(in_data, dtype=np.int16)
            if len(audio_data) > 0:
                # RMS calculation
                rms = np.sqrt(np.mean(audio_data.astype(np.float32)**2))
                # Normalize to 0-1 range
                level = min(1.0, rms / 32768.0)
                self.audio_level = level
                
                if self.level_callback:
                    self.level_callback(level)
        
        return (in_data, pyaudio.paContinue)
    
    def stop_recording(self) -> Optional[Path]:
        """Stop recording and save to file."""
        if not self.is_recording:
            return None
        
        self.is_recording = False
        
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
        
        # Save recording to file
        if self.frames and self.current_file:
            self._save_recording()
            return self.current_file
        
        return None
    
    def _save_recording(self):
        """Save recorded frames to WAV file."""
        with wave.open(str(self.current_file), 'wb') as wf:
            wf.setnchannels(self.channels)
            wf.setsampwidth(self.audio.get_sample_size(self.format))
            wf.setframerate(self.sample_rate)
            wf.writeframes(b''.join(self.frames))
    
    def cancel_recording(self):
        """Cancel recording without saving."""
        self.is_recording = False
        
        if self.stream:
            self.stream.stop_stream()
            self.stream.close()
            self.stream = None
        
        self.frames = []
        
        # Delete temporary file if it exists
        if self.current_file and self.current_file.exists():
            self.current_file.unlink()
            self.current_file = None
    
    def get_recording_duration(self) -> float:
        """Get current recording duration in seconds."""
        if not self.frames:
            return 0.0
        
        bytes_per_sample = self.audio.get_sample_size(self.format)
        total_bytes = len(self.frames) * self.chunk_size * bytes_per_sample
        duration = total_bytes / (self.sample_rate * self.channels * bytes_per_sample)
        return duration
    
    def cleanup(self):
        """Clean up resources."""
        if self.is_recording:
            self.cancel_recording()
        
        self.audio.terminate()
    
    def __del__(self):
        """Destructor to ensure cleanup."""
        self.cleanup()