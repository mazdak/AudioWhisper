"""
Recording window UI for AudioWhisper Linux.
Provides a floating window for audio recording with visual feedback.
"""

import gi
gi.require_version('Gtk', '4.0')
gi.require_version('Adw', '1')
from gi.repository import Gtk, Adw, GLib, Gdk

class RecordingWindow(Gtk.ApplicationWindow):
    """Floating recording window with audio level visualization."""
    
    def __init__(self, app):
        super().__init__(application=app)
        self.app = app
        self.is_recording = False
        
        # Window setup
        self.set_title("AudioWhisper Recording")
        self.set_default_size(280, 160)
        self.set_resizable(False)
        self.set_decorated(False)  # Remove window decorations
        
        # Make window floating
        self.set_modal(True)
        self.set_transient_for(None)
        
        # Set up CSS for styling
        self._setup_css()
        
        # Build UI
        self._build_ui()
        
        # Connect keyboard shortcuts
        self._setup_shortcuts()
    
    def _setup_css(self):
        """Apply custom CSS styling."""
        css = """
        .recording-window {
            background-color: rgba(30, 30, 30, 0.95);
            border-radius: 12px;
            padding: 20px;
        }
        
        .record-button {
            background-color: #007AFF;
            color: white;
            border-radius: 50%;
            min-width: 80px;
            min-height: 80px;
            font-size: 24px;
        }
        
        .record-button:hover {
            background-color: #0051D5;
        }
        
        .record-button.recording {
            background-color: #FF3B30;
        }
        
        .record-button.recording:hover {
            background-color: #D70015;
        }
        
        .status-label {
            color: #FFFFFF;
            font-size: 14px;
            font-weight: 500;
        }
        
        .instructions-label {
            color: #999999;
            font-size: 12px;
        }
        
        .level-bar {
            min-height: 6px;
            border-radius: 3px;
            background-color: #333333;
        }
        
        .level-bar trough {
            background-color: #333333;
            border-radius: 3px;
        }
        
        .level-bar block.filled {
            background-color: #34C759;
            border-radius: 3px;
        }
        """
        
        css_provider = Gtk.CssProvider()
        css_provider.load_from_data(css.encode())
        Gtk.StyleContext.add_provider_for_display(
            Gdk.Display.get_default(),
            css_provider,
            Gtk.STYLE_PROVIDER_PRIORITY_APPLICATION
        )
    
    def _build_ui(self):
        """Build the window UI."""
        # Main container
        main_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=20)
        main_box.set_css_classes(['recording-window'])
        self.set_child(main_box)
        
        # Status and level container
        status_box = Gtk.Box(orientation=Gtk.Orientation.VERTICAL, spacing=10)
        main_box.append(status_box)
        
        # Status label
        self.status_label = Gtk.Label(label="Ready to record")
        self.status_label.set_css_classes(['status-label'])
        status_box.append(self.status_label)
        
        # Audio level bar
        self.level_bar = Gtk.LevelBar()
        self.level_bar.set_min_value(0.0)
        self.level_bar.set_max_value(1.0)
        self.level_bar.set_value(0.0)
        self.level_bar.set_css_classes(['level-bar'])
        self.level_bar.set_hexpand(True)
        status_box.append(self.level_bar)
        
        # Record button
        self.record_button = Gtk.Button()
        self.record_button.set_css_classes(['record-button'])
        self.record_button.set_halign(Gtk.Align.CENTER)
        
        # Microphone icon
        self.button_icon = Gtk.Image.new_from_icon_name('audio-input-microphone-symbolic')
        self.button_icon.set_pixel_size(32)
        self.record_button.set_child(self.button_icon)
        
        self.record_button.connect('clicked', self._on_record_clicked)
        main_box.append(self.record_button)
        
        # Instructions label
        self.instructions_label = Gtk.Label(
            label="Press Space to record • Escape to close"
        )
        self.instructions_label.set_css_classes(['instructions-label'])
        main_box.append(self.instructions_label)
    
    def _setup_shortcuts(self):
        """Set up keyboard shortcuts."""
        # Space key for recording
        space_action = Gtk.ShortcutAction.new_action("win.toggle-recording")
        space_trigger = Gtk.ShortcutTrigger.parse_string("space")
        space_shortcut = Gtk.Shortcut.new(space_trigger, space_action)
        
        # Escape key to close
        escape_action = Gtk.ShortcutAction.new_action("win.close")
        escape_trigger = Gtk.ShortcutTrigger.parse_string("Escape")
        escape_shortcut = Gtk.Shortcut.new(escape_trigger, escape_action)
        
        # Add shortcuts to controller
        controller = Gtk.ShortcutController()
        controller.add_shortcut(space_shortcut)
        controller.add_shortcut(escape_shortcut)
        self.add_controller(controller)
        
        # Create actions
        toggle_action = Gtk.SimpleAction.new("toggle-recording", None)
        toggle_action.connect("activate", lambda *_: self._on_record_clicked(None))
        self.add_action(toggle_action)
        
        close_action = Gtk.SimpleAction.new("close", None)
        close_action.connect("activate", lambda *_: self.close())
        self.add_action(close_action)
    
    def _on_record_clicked(self, button):
        """Handle record button click."""
        if not self.is_recording:
            self.start_recording()
        else:
            self.stop_recording()
    
    def start_recording(self):
        """Start audio recording."""
        self.is_recording = True
        self.record_button.add_css_class('recording')
        self.button_icon.set_from_icon_name('media-playback-stop-symbolic')
        self.status_label.set_text("Recording...")
        self.instructions_label.set_text("Press Space to stop • Escape to cancel")
        
        # Notify app to start recording
        self.app.start_recording()
    
    def stop_recording(self):
        """Stop audio recording."""
        self.is_recording = False
        self.record_button.remove_css_class('recording')
        self.button_icon.set_from_icon_name('audio-input-microphone-symbolic')
        self.status_label.set_text("Processing audio...")
        self.instructions_label.set_text("Please wait...")
        
        # Disable controls during processing
        self.record_button.set_sensitive(False)
        
        # Notify app to stop recording
        self.app.stop_recording()
    
    def update_audio_level(self, level: float):
        """Update audio level visualization."""
        self.level_bar.set_value(level)
    
    def show_success(self, message: str = "Text copied to clipboard"):
        """Show success state."""
        self.status_label.set_text(message)
        self.instructions_label.set_text("Window will close automatically")
        
        # Close window after delay
        GLib.timeout_add(1500, self.close)
    
    def show_error(self, error: str):
        """Show error state."""
        self.status_label.set_text("Error occurred")
        self.instructions_label.set_text(error)
        self.record_button.set_sensitive(True)
        self.record_button.remove_css_class('recording')
        self.button_icon.set_from_icon_name('audio-input-microphone-symbolic')
        self.is_recording = False
    
    def reset(self):
        """Reset window to initial state."""
        self.is_recording = False
        self.record_button.remove_css_class('recording')
        self.record_button.set_sensitive(True)
        self.button_icon.set_from_icon_name('audio-input-microphone-symbolic')
        self.status_label.set_text("Ready to record")
        self.instructions_label.set_text("Press Space to record • Escape to close")
        self.level_bar.set_value(0.0)