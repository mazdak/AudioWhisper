"""
Configuration management for AudioWhisper Linux.
Handles settings storage, API keys, and user preferences.
"""

import os
import json
import toml
from pathlib import Path
from typing import Dict, Any, Optional
from cryptography.fernet import Fernet
import gi
gi.require_version('Secret', '1')
from gi.repository import Secret

class Config:
    """Manages application configuration with XDG compliance."""
    
    def __init__(self):
        self.config_dir = self._get_config_dir()
        self.config_file = self.config_dir / "config.toml"
        self.ensure_config_dir()
        self.config = self.load_config()
        
        # Initialize secret storage for API keys
        self.schema = Secret.Schema.new(
            "org.audiowhisper.linux",
            Secret.SchemaFlags.NONE,
            {
                "service": Secret.SchemaAttributeType.STRING,
                "account": Secret.SchemaAttributeType.STRING,
            }
        )
    
    def _get_config_dir(self) -> Path:
        """Get XDG-compliant config directory."""
        xdg_config = os.environ.get('XDG_CONFIG_HOME', 
                                   os.path.expanduser('~/.config'))
        return Path(xdg_config) / 'audiowhisper'
    
    def ensure_config_dir(self):
        """Create config directory if it doesn't exist."""
        self.config_dir.mkdir(parents=True, exist_ok=True)
    
    def load_config(self) -> Dict[str, Any]:
        """Load configuration from file."""
        if self.config_file.exists():
            with open(self.config_file, 'r') as f:
                return toml.load(f)
        else:
            return self.get_default_config()
    
    def save_config(self):
        """Save current configuration to file."""
        with open(self.config_file, 'w') as f:
            toml.dump(self.config, f)
    
    def get_default_config(self) -> Dict[str, Any]:
        """Return default configuration."""
        return {
            'general': {
                'start_at_login': False,
                'show_tray_icon': True,
                'play_sounds': True,
                'immediate_recording': False,
            },
            'hotkeys': {
                'toggle_recording': '<Super><Shift>space',
            },
            'transcription': {
                'provider': 'openai',  # openai, gemini, local, parakeet
                'openai_model': 'whisper-1',
                'local_model': 'base',
                'language': 'auto',
            },
            'audio': {
                'sample_rate': 16000,
                'channels': 1,
                'chunk_size': 1024,
            },
            'ui': {
                'theme': 'auto',  # auto, light, dark
                'window_opacity': 0.95,
            }
        }
    
    def get(self, key: str, default: Any = None) -> Any:
        """Get configuration value using dot notation."""
        keys = key.split('.')
        value = self.config
        for k in keys:
            if isinstance(value, dict) and k in value:
                value = value[k]
            else:
                return default
        return value
    
    def set(self, key: str, value: Any):
        """Set configuration value using dot notation."""
        keys = key.split('.')
        config = self.config
        for k in keys[:-1]:
            if k not in config:
                config[k] = {}
            config = config[k]
        config[keys[-1]] = value
        self.save_config()
    
    def get_api_key(self, provider: str) -> Optional[str]:
        """Retrieve API key from secure storage."""
        try:
            password = Secret.password_lookup_sync(
                self.schema,
                {"service": "audiowhisper", "account": provider},
                None
            )
            return password
        except Exception:
            return None
    
    def set_api_key(self, provider: str, api_key: str) -> bool:
        """Store API key in secure storage."""
        try:
            Secret.password_store_sync(
                self.schema,
                {"service": "audiowhisper", "account": provider},
                Secret.COLLECTION_DEFAULT,
                f"AudioWhisper {provider} API key",
                api_key,
                None
            )
            return True
        except Exception:
            return False
    
    def clear_api_key(self, provider: str) -> bool:
        """Remove API key from secure storage."""
        try:
            Secret.password_clear_sync(
                self.schema,
                {"service": "audiowhisper", "account": provider},
                None
            )
            return True
        except Exception:
            return False