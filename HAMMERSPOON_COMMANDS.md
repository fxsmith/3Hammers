# Hammerspoon Configuration Commands

This document lists the currently active hotkeys defined in your `init.lua`.

## App Launchers / New Window
These commands launch the application if not running, or create a new window on the *current* space if it is already running. They are designed to bring **only** the new window to the foreground, leaving other windows of the same app in the background.

| Hotkey | Description |
| :--- | :--- |
| **Cmd + Ctrl + Alt + T** | **Ghostty**: Open new window here |
| **Cmd + Ctrl + Alt + M** | **Emacs**: Open new client frame here (auto-starts daemon) |
| **Cmd + Ctrl + Alt + C** | **Google Chrome**: Open new window here |
| **Cmd + Ctrl + Alt + B** | **Brave Browser**: Open new window here |
| **Cmd + Ctrl + Alt + V** | **VS Code**: Open new window here |

## Window Navigation (Current Space Only)
Cycle through open windows on the current desktop space.

| Hotkey | Description |
| :--- | :--- |
| **Cmd + Alt + Left** | Cycle to **previous** window |
| **Cmd + Alt + Right** | Cycle to **next** window |

## Window Management
Resize or change the state of the currently focused window.

| Hotkey | Description |
| :--- | :--- |
| **Cmd + Alt + Up** | **Maximize**: Fill screen (keep Dock/Menubar visible) |
| **Cmd + Ctrl + Alt + Up** | **Enter Fullscreen**: Native macOS fullscreen mode |
| **Cmd + Ctrl + Alt + Down** | **Exit Fullscreen**: Leave native macOS fullscreen mode |

---
*Note: Hammerspoon usually reloads automatically when `init.lua` is saved. If hotkeys do not work, try manually reloading the configuration.*