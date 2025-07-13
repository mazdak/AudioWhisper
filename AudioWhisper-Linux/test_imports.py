#!/usr/bin/env python3
"""
Test script to verify all modules can be imported.
Run this to check if dependencies are properly installed.
"""

import sys
from pathlib import Path

# Add src to path
sys.path.insert(0, str(Path(__file__).parent / 'src'))

def test_imports():
    """Test importing all modules."""
    modules = [
        ('config', 'Configuration module'),
        ('audio_recorder', 'Audio recording module'),
        ('transcription_service', 'Transcription services'),
        ('recording_window', 'GTK4 UI components'),
        ('hyprland_integration', 'Hyprland integration'),
        ('main', 'Main application')
    ]
    
    print("Testing module imports...\n")
    
    success_count = 0
    for module_name, description in modules:
        try:
            __import__(module_name)
            print(f"✅ {module_name}: {description}")
            success_count += 1
        except ImportError as e:
            print(f"❌ {module_name}: {e}")
        except Exception as e:
            print(f"⚠️  {module_name}: {type(e).__name__}: {e}")
    
    print(f"\n{success_count}/{len(modules)} modules imported successfully")
    
    if success_count < len(modules):
        print("\nSome imports failed. Make sure to:")
        print("1. Install system dependencies (run ./install.sh)")
        print("2. Activate virtual environment: source venv/bin/activate")
        print("3. Install Python packages: pip install -r requirements.txt")
        return 1
    
    return 0

if __name__ == "__main__":
    sys.exit(test_imports())