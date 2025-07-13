"""
Hyprland integration for AudioWhisper Linux.
Handles global hotkeys and window management for Wayland/Hyprland.
"""

import os
import json
import subprocess
import asyncio
from pathlib import Path
from typing import Optional, Callable

class HyprlandIntegration:
    """Manages Hyprland-specific features like global hotkeys."""
    
    def __init__(self):
        self.socket_path = self._get_socket_path()
        self.hotkey_callback = None
        self.previous_window_class = None
        
    def _get_socket_path(self) -> Optional[str]:
        """Get Hyprland IPC socket path."""
        # Check environment variable
        instance_sig = os.environ.get('HYPRLAND_INSTANCE_SIGNATURE')
        if not instance_sig:
            return None
            
        # Socket path is typically at /tmp/hypr/{instance}/.socket.sock
        socket_path = f"/tmp/hypr/{instance_sig}/.socket.sock"
        if os.path.exists(socket_path):
            return socket_path
            
        # Alternative location
        runtime_dir = os.environ.get('XDG_RUNTIME_DIR', '/run/user/1000')
        socket_path = f"{runtime_dir}/hypr/{instance_sig}/.socket.sock"
        if os.path.exists(socket_path):
            return socket_path
            
        return None
    
    def is_available(self) -> bool:
        """Check if Hyprland is available."""
        return self.socket_path is not None and os.path.exists(self.socket_path)
    
    async def send_command(self, command: str) -> str:
        """Send command to Hyprland via IPC."""
        if not self.is_available():
            raise Exception("Hyprland not available")
            
        try:
            # Use hyprctl for commands
            result = await asyncio.create_subprocess_exec(
                'hyprctl', 'dispatch', command,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await result.communicate()
            
            if result.returncode != 0:
                raise Exception(f"Hyprland command failed: {stderr.decode()}")
                
            return stdout.decode()
            
        except Exception as e:
            raise Exception(f"Failed to send Hyprland command: {str(e)}")
    
    async def get_active_window(self) -> Optional[dict]:
        """Get information about the currently active window."""
        try:
            result = await asyncio.create_subprocess_exec(
                'hyprctl', 'activewindow', '-j',
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.PIPE
            )
            stdout, stderr = await result.communicate()
            
            if result.returncode == 0:
                return json.loads(stdout.decode())
            
        except Exception:
            pass
            
        return None
    
    def setup_global_hotkey(self, keybind: str, callback: Callable):
        """Set up global hotkey using Hyprland config."""
        self.hotkey_callback = callback
        
        # Create a script that will be called by Hyprland
        script_path = Path.home() / '.config' / 'audiowhisper' / 'hotkey_handler.sh'
        script_path.parent.mkdir(parents=True, exist_ok=True)
        
        script_content = f"""#!/bin/bash
# AudioWhisper hotkey handler
# This script is called by Hyprland when the hotkey is pressed

# Send signal to AudioWhisper via D-Bus or named pipe
if command -v gdbus >/dev/null 2>&1; then
    gdbus call --session \\
        --dest org.audiowhisper.linux \\
        --object-path /org/audiowhisper/linux \\
        --method org.audiowhisper.linux.ToggleRecording
else
    # Fallback: use a named pipe
    echo "toggle_recording" > /tmp/audiowhisper_commands 2>/dev/null || true
fi
"""
        
        script_path.write_text(script_content)
        script_path.chmod(0o755)
        
        # Add keybind to Hyprland config
        config_line = f'bind = {keybind}, exec, {script_path}'
        self._add_to_hyprland_config(config_line)
        
        # Reload Hyprland config
        subprocess.run(['hyprctl', 'reload'], capture_output=True)
    
    def _add_to_hyprland_config(self, line: str):
        """Add a line to Hyprland config if not already present."""
        config_path = Path.home() / '.config' / 'hypr' / 'hyprland.conf'
        
        if not config_path.exists():
            print("Warning: Hyprland config not found")
            return
            
        # Read existing config
        content = config_path.read_text()
        
        # Check if our section exists
        marker = "# AudioWhisper keybinds"
        if marker not in content:
            # Add our section at the end
            content += f"\n\n{marker}\n{line}\n"
        else:
            # Check if this specific bind already exists
            if line not in content:
                # Add after marker
                lines = content.split('\n')
                for i, l in enumerate(lines):
                    if l.strip() == marker:
                        lines.insert(i + 1, line)
                        break
                content = '\n'.join(lines)
        
        # Write back
        config_path.write_text(content)
    
    def remove_global_hotkey(self):
        """Remove global hotkey from Hyprland config."""
        config_path = Path.home() / '.config' / 'hypr' / 'hyprland.conf'
        
        if not config_path.exists():
            return
            
        # Read config
        content = config_path.read_text()
        lines = content.split('\n')
        
        # Remove AudioWhisper section
        new_lines = []
        skip = False
        for line in lines:
            if line.strip() == "# AudioWhisper keybinds":
                skip = True
                continue
            elif skip and line.strip() and not line.startswith('bind ='):
                skip = False
            
            if not skip:
                new_lines.append(line)
        
        # Write back
        config_path.write_text('\n'.join(new_lines))
        
        # Reload config
        subprocess.run(['hyprctl', 'reload'], capture_output=True)
    
    async def save_active_window(self):
        """Save information about the currently active window."""
        window_info = await self.get_active_window()
        if window_info:
            self.previous_window_class = window_info.get('class')
    
    async def restore_previous_window(self):
        """Restore focus to the previously active window."""
        if not self.previous_window_class:
            return
            
        # Focus window by class
        await self.send_command(f'focuswindow class:{self.previous_window_class}')
        self.previous_window_class = None
    
    def create_window_rules(self, window_class: str = "audiowhisper"):
        """Create Hyprland window rules for AudioWhisper windows."""
        rules = [
            f'windowrule = float, class:^({window_class})$',
            f'windowrule = center, class:^({window_class})$',
            f'windowrule = pin, class:^({window_class})$',
            f'windowrule = noborder, class:^({window_class})$',
            f'windowrule = noshadow, class:^({window_class})$',
            f'windowrule = noblur, class:^({window_class})$',
            f'windowrule = stayfocused, class:^({window_class})$',
        ]
        
        for rule in rules:
            self._add_window_rule(rule)
        
        # Reload config
        subprocess.run(['hyprctl', 'reload'], capture_output=True)
    
    def _add_window_rule(self, rule: str):
        """Add a window rule to Hyprland config."""
        config_path = Path.home() / '.config' / 'hypr' / 'hyprland.conf'
        
        if not config_path.exists():
            return
            
        content = config_path.read_text()
        
        # Check if rule already exists
        if rule in content:
            return
            
        # Add to window rules section or create one
        marker = "# AudioWhisper window rules"
        if marker not in content:
            content += f"\n\n{marker}\n{rule}\n"
        else:
            lines = content.split('\n')
            for i, line in enumerate(lines):
                if line.strip() == marker:
                    lines.insert(i + 1, rule)
                    break
            content = '\n'.join(lines)
        
        config_path.write_text(content)