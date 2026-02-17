# Hammerspoon Configuration Commands

This document lists the currently active hotkeys defined in your `init.lua`.

## App Launchers / New Window
These commands launch the application if not running, or create a new window on the *current* space if it is already running. They are designed to bring **only** the new window to the foreground, leaving other windows of the same app in the background.

| Hotkey | Description |
| :--- | :--- |
| **Ctrl + Alt + Cmd + T** | **Ghostty**: Open new window here |
| **Ctrl + Alt + Cmd + M** | **Emacs**: Open new client frame here (auto-starts daemon) |
| **Ctrl + Alt + Cmd + G** | **Google Chrome**: Open new window here |
| **Ctrl + Alt + Cmd + C** | **Chrome Canary**: Open new window here |
| **Ctrl + Alt + Cmd + B** | **Brave Browser**: Open new window here |
| **Ctrl + Alt + Cmd + V** | **VS Code**: Open new window here |

## Window Navigation (Current Space Only)
Cycle through open windows on the current desktop space.

| Hotkey | Description |
| :--- | :--- |
| **Cmd + Alt + Left** | Cycle to **previous** window |
| **Cmd + Alt + Right** | Cycle to **next** window |
| **Cmd + Alt + 0** | Rebuild window cycle filter |
| **Ctrl + Cmd + Up** | **Window Switcher**: Show large thumbnails |
| **Ctrl + Cmd + Right** | **Window Switcher**: Next window (hold Ctrl+Cmd) |
| **Ctrl + Cmd + Left** | **Window Switcher**: Previous window (hold Ctrl+Cmd) |

## Window Management
Resize or change the state of the currently focused window.

| Hotkey | Description |
| :--- | :--- |
| **Cmd + Alt + Up** | **Maximize**: Fill screen (keep Dock/Menubar visible) |
| **Cmd + Ctrl + Alt + Up** | **Enter Fullscreen**: Native macOS fullscreen mode |
| **Cmd + Ctrl + Alt + Down** | **Exit Fullscreen**: Leave native macOS fullscreen mode |

## System Toggles

| Hotkey | Description |
| :--- | :--- |
| **Ctrl + Tab** | Toggle automatic hiding of the macOS menu bar |

---
*Note: Hammerspoon usually reloads automatically when `init.lua` is saved. If hotkeys do not work, try manually reloading the configuration.*
