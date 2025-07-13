#!/usr/bin/env python3
"""
AudioWhisper Linux - Main Application
A lightweight audio transcription app for Linux with Wayland/Hyprland support.
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
gi.require_version('AppIndicator3', '0.1')
from gi.repository import Gtk, Adw, GLib, Gio, AppIndicator3

import os
import sys
import asyncio
import threading
import subprocess
from pathlib import Path

# Import our modules
from config import Config
from audio_recorder import AudioRecorder
from transcription_service import TranscriptionService
from recording_window import RecordingWindow
from hyprland_integration import HyprlandIntegration

class AudioWhisperApp(Adw.Application):
    """Main application class for AudioWhisper Linux."""
    
    def __init__(self):
        super().__init__(
            application_id='org.audiowhisper.linux',
            flags=Gio.ApplicationFlags.FLAGS_NONE
        )
        
        # Initialize components
        self.config = Config()
        self.audio_recorder = AudioRecorder(
            sample_rate=self.config.get('audio.sample_rate', 16000),
            channels=self.config.get('audio.channels', 1),
            chunk_size=self.config.get('audio.chunk_size', 1024)
        )
        self.transcription_service = TranscriptionService(self.config)
        self.hyprland = HyprlandIntegration()
        
        # UI components
        self.recording_window = None
        self.settings_window = None
        self.indicator = None
        
        # State
        self.is_recording = False
        self.processing = False
        
        # Setup audio level callback
        self.audio_recorder.set_level_callback(self._on_audio_level_update)
        
        # Setup async event loop in thread
        self.loop = asyncio.new_event_loop()
        self.async_thread = threading.Thread(target=self._run_async_loop, daemon=True)
        self.async_thread.start()
    
    def _run_async_loop(self):
        """Run async event loop in separate thread."""
        asyncio.set_event_loop(self.loop)
        self.loop.run_forever()
    
    def do_startup(self):
        """Application startup."""
        Adw.Application.do_startup(self)
        
        # Create actions
        self._create_actions()
        
        # Setup system tray
        self._setup_tray()
        
        # Setup global hotkey
        self._setup_hotkey()
        
        # Setup Hyprland window rules
        if self.hyprland.is_available():
            self.hyprland.create_window_rules("audiowhisper")
        
        # Setup command listener (fallback for hotkey)
        self._setup_command_listener()
    
    def do_activate(self):
        """Application activation."""
        # Show recording window if immediate recording is enabled
        if self.config.get('general.immediate_recording', False):
            self.show_recording_window()
    
    def _create_actions(self):
        """Create application actions."""
        # Toggle recording action
        toggle_action = Gio.SimpleAction.new("toggle-recording", None)
        toggle_action.connect("activate", lambda *_: self.toggle_recording_window())
        self.add_action(toggle_action)
        
        # Settings action
        settings_action = Gio.SimpleAction.new("settings", None)
        settings_action.connect("activate", lambda *_: self.show_settings())
        self.add_action(settings_action)
        
        # Quit action
        quit_action = Gio.SimpleAction.new("quit", None)
        quit_action.connect("activate", lambda *_: self.quit())
        self.add_action(quit_action)
    
    def _setup_tray(self):
        """Setup system tray indicator."""
        if not self.config.get('general.show_tray_icon', True):
            return
            
        self.indicator = AppIndicator3.Indicator.new(
            "audiowhisper",
            "audio-input-microphone-symbolic",
            AppIndicator3.IndicatorCategory.APPLICATION_STATUS
        )
        
        self.indicator.set_status(AppIndicator3.IndicatorStatus.ACTIVE)
        self.indicator.set_menu(self._create_tray_menu())
    
    def _create_tray_menu(self) -> Gtk.Menu:
        """Create tray menu."""
        menu = Gtk.Menu()
        
        # Record item
        record_item = Gtk.MenuItem(label="Record")
        record_item.connect("activate", lambda _: self.toggle_recording_window())
        menu.append(record_item)
        
        menu.append(Gtk.SeparatorMenuItem())
        
        # Settings item
        settings_item = Gtk.MenuItem(label="Settings")
        settings_item.connect("activate", lambda _: self.show_settings())
        menu.append(settings_item)
        
        # About item
        about_item = Gtk.MenuItem(label="About")
        about_item.connect("activate", lambda _: self.show_about())
        menu.append(about_item)
        
        menu.append(Gtk.SeparatorMenuItem())
        
        # Quit item
        quit_item = Gtk.MenuItem(label="Quit")
        quit_item.connect("activate", lambda _: self.quit())
        menu.append(quit_item)
        
        menu.show_all()
        return menu
    
    def _setup_hotkey(self):
        """Setup global hotkey."""
        if self.hyprland.is_available():
            keybind = self.config.get('hotkeys.toggle_recording', 'SUPER SHIFT, space')
            self.hyprland.setup_global_hotkey(keybind, self.toggle_recording_window)
    
    def _setup_command_listener(self):
        """Setup named pipe for command communication."""
        pipe_path = Path("/tmp/audiowhisper_commands")
        
        # Create pipe if it doesn't exist
        if pipe_path.exists():
            pipe_path.unlink()
            
        os.mkfifo(str(pipe_path))
        
        # Start listener thread
        threading.Thread(target=self._listen_for_commands, daemon=True).start()
    
    def _listen_for_commands(self):
        """Listen for commands on named pipe."""
        pipe_path = Path("/tmp/audiowhisper_commands")
        
        while True:
            try:
                with open(pipe_path, 'r') as pipe:
                    command = pipe.read().strip()
                    if command == "toggle_recording":
                        GLib.idle_add(self.toggle_recording_window)
            except Exception:
                pass
    
    def toggle_recording_window(self):
        """Toggle the recording window."""
        if self.recording_window and self.recording_window.get_visible():
            self.recording_window.close()
        else:
            self.show_recording_window()
    
    def show_recording_window(self):
        """Show the recording window."""
        if not self.recording_window:
            self.recording_window = RecordingWindow(self)
            self.recording_window.set_application(self)
        
        # Save current window focus
        if self.hyprland.is_available():
            asyncio.run_coroutine_threadsafe(
                self.hyprland.save_active_window(),
                self.loop
            )
        
        self.recording_window.present()
        self.recording_window.reset()
    
    def show_settings(self):
        """Show settings window."""
        # TODO: Implement settings window
        print("Settings window not yet implemented")
    
    def show_about(self):
        """Show about dialog."""
        about = Adw.AboutWindow(
            application_name="AudioWhisper",
            application_icon="audio-input-microphone-symbolic",
            developer_name="AudioWhisper Developers",
            version="1.0.0",
            copyright="© 2024 AudioWhisper Developers",
            license_type=Gtk.License.MIT_X11,
            website="https://github.com/yourusername/audiowhisper-linux",
            issue_url="https://github.com/yourusername/audiowhisper-linux/issues"
        )
        
        about.set_transient_for(self.get_active_window())
        about.present()
    
    def start_recording(self):
        """Start audio recording."""
        if self.is_recording:
            return
            
        self.is_recording = True
        success = self.audio_recorder.start_recording()
        
        if not success:
            self.recording_window.show_error("Failed to start recording")
            self.is_recording = False
    
    def stop_recording(self):
        """Stop recording and process audio."""
        if not self.is_recording:
            return
            
        self.is_recording = False
        audio_file = self.audio_recorder.stop_recording()
        
        if audio_file:
            # Process in async thread
            asyncio.run_coroutine_threadsafe(
                self._process_recording(audio_file),
                self.loop
            )
        else:
            self.recording_window.show_error("No audio recorded")
    
    async def _process_recording(self, audio_file: Path):
        """Process recorded audio asynchronously."""
        try:
            # Transcribe audio
            text = await self.transcription_service.transcribe(audio_file)
            
            # Copy to clipboard
            GLib.idle_add(self._copy_to_clipboard, text)
            
            # Show success
            GLib.idle_add(self.recording_window.show_success)
            
            # Restore previous window focus
            if self.hyprland.is_available():
                await asyncio.sleep(1.5)  # Wait for success message
                await self.hyprland.restore_previous_window()
            
            # Clean up audio file
            audio_file.unlink()
            
        except Exception as e:
            GLib.idle_add(self.recording_window.show_error, str(e))
    
    def _copy_to_clipboard(self, text: str):
        """Copy text to clipboard using wl-copy."""
        try:
            subprocess.run(['wl-copy'], input=text.encode(), check=True)
        except subprocess.CalledProcessError:
            # Fallback to xclip if available
            try:
                subprocess.run(['xclip', '-selection', 'clipboard'], 
                             input=text.encode(), check=True)
            except:
                print("Failed to copy to clipboard")
    
    def _on_audio_level_update(self, level: float):
        """Handle audio level updates."""
        if self.recording_window and self.is_recording:
            GLib.idle_add(self.recording_window.update_audio_level, level)
    
    def do_shutdown(self):
        """Application shutdown."""
        Adw.Application.do_shutdown(self)
        
        # Clean up
        self.audio_recorder.cleanup()
        
        # Stop async loop
        self.loop.call_soon_threadsafe(self.loop.stop)
        
        # Remove Hyprland hotkey
        if self.hyprland.is_available():
            self.hyprland.remove_global_hotkey()
        
        # Remove command pipe
        pipe_path = Path("/tmp/audiowhisper_commands")
        if pipe_path.exists():
            pipe_path.unlink()

def main():
    """Main entry point."""
    app = AudioWhisperApp()
    return app.run(sys.argv)

if __name__ == "__main__":
    main()