local f = io.open(os.getenv("HOME") .. "/.hammerspoon/init_debug.log", "a"); if f then f:write("Init loaded at " .. os.date() .. "\n"); f:close(); end
-- ============================================================
-- Core Helper: Focus ONLY the newly created window
-- ============================================================
local function focusNewWindow(appName, actionFn)
  local app = hs.application.get(appName)
  local oldWinIds = {}
  if app then
    for _, w in ipairs(app:allWindows()) do
      oldWinIds[w:id()] = true
    end
  end

  -- Perform the action (launch or keystroke)
  actionFn(app)

  -- Poll for new window
  hs.timer.doAfter(0.1, function()
    local attempts = 0
    local function check()
      attempts = attempts + 1
      local targetApp = hs.application.get(appName)
      if not targetApp then
        if attempts < 30 then hs.timer.doAfter(0.1, check) end
        return
      end

      for _, w in ipairs(targetApp:allWindows()) do
        if not oldWinIds[w:id()] then
          -- Found new window! Focus ONLY this window.
          w:focus() 
          return
        end
      end
      
      -- Keep looking for 3 seconds
      if attempts < 30 then
        hs.timer.doAfter(0.1, check)
      else
        -- Fallback: if no new window detected, activate the app
        -- (This ensures we at least see the app if something went wrong)
        if targetApp then targetApp:activate() end
      end
    end
    check()
  end)
end

local function launchOrNewWindow(appName, keyMods, keyChar, openPath)
  focusNewWindow(appName, function(app)
    if not app then
      hs.application.open(openPath or appName, 0, false)
    else
      hs.eventtap.keyStroke(keyMods, keyChar, 0, app)
    end
  end)
end

local function newKittyHere()
    launchOrNewWindow("kitty", {"cmd"}, "n", "/Applications/kitty.app")
end

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "t", newKittyHere)

-- ============================================================
-- Helpers
-- ============================================================

local function shellquote(s)
  return "'" .. tostring(s):gsub("'", "'\\''") .. "'"
end

local function commandExists(cmd)
  local ok = os.execute("command -v " .. shellquote(cmd) .. " >/dev/null 2>&1")
  return ok == true or ok == 0
end

local function pickEmacsBin()
  -- Prefer emacs from common Homebrew locations, else PATH.
  local candidates = {
    "/opt/homebrew/bin/emacs",
    "/usr/local/bin/emacs",
    "emacs",
  }
  for _, c in ipairs(candidates) do
    if c == "emacs" then
      if commandExists("emacs") then return "emacs" end
    else
      if hs.fs.attributes(c) then return c end
    end
  end
  return nil
end

local function pickEmacsClientBin()
  local candidates = {
    "/opt/homebrew/bin/emacsclient",
    "/usr/local/bin/emacsclient",
    "emacsclient",
  }
  for _, c in ipairs(candidates) do
    if c == "emacsclient" then
      if commandExists("emacsclient") then return "emacsclient" end
    else
      if hs.fs.attributes(c) then return c end
    end
  end
  return nil
end

local EMACS = pickEmacsBin()
local EMACSCLIENT = pickEmacsClientBin()

local function runAsync(cmd)
  -- Run through user's shell so PATH and login env are available.
  hs.task.new("/bin/zsh", nil, { "-lc", cmd }):start()
end

-- ============================================================
-- Space Management
-- ============================================================

local function switchToSpaceN(n)
  -- Map numbers to their keyboard characters (1-9, and 0 for 10)
  local key = tostring(n)
  if n == 10 then key = "0" end
  
  -- Simulate the native Mission Control shortcut for smooth animation.
  -- Note: "Switch to Desktop N" must be enabled in System Settings.
  hs.eventtap.keyStroke({"ctrl"}, key, 0)
  
  -- Use debounced update to avoid blocking during space transition
  if _G.hud and _G.hud.debouncedUpdate then
    _G.hud.debouncedUpdate()
  end
end

local function switchSpaceStep(step)
  -- Use native "Move left/right a space" shortcuts for smooth animation.
  -- Note: These must be enabled in System Settings.
  local key = (step > 0) and "right" or "left"
  hs.eventtap.keyStroke({"ctrl"}, key, 0)
  
  if _G.hud and _G.hud.debouncedUpdate then
    _G.hud.debouncedUpdate()
  end
end

-- Bind Ctrl + 1-9 to switch to spaces 1-9
-- for i = 1, 9 do
--   hs.hotkey.bind({"ctrl"}, tostring(i), function()
--     switchToSpaceN(i)
--   end)
-- end
-- Bind Ctrl + 0 to switch to space 10
-- hs.hotkey.bind({"ctrl"}, "0", function()
--   switchToSpaceN(10)
-- end)

-- Bind Ctrl + Alt (Option) + Left/Right to switch previous/next space
hs.hotkey.bind({"ctrl", "alt"}, "left", function()
  switchSpaceStep(-1)
end, nil, function()
  switchSpaceStep(-1)
end)
hs.hotkey.bind({"ctrl", "alt"}, "right", function()
  switchSpaceStep(1)
end, nil, function()
  switchSpaceStep(1)
end)

-- ============================================================
-- Emacs daemon: start at login (idempotent)
-- ============================================================

local function isEmacsDaemonUp()
  if not EMACSCLIENT then return false end
  -- This returns nonzero if no server.
  local ok = os.execute(EMACSCLIENT .. " -e " .. shellquote("(progn t)") .. " >/dev/null 2>&1")
  return ok == true or ok == 0
end

local function startEmacsDaemon()
  if not EMACS then
    hs.notify.new({ title = "Hammerspoon", informativeText = "Cannot find emacs binary (brew install emacs?)" }):send()
    return
  end

  if isEmacsDaemonUp() then
    return
  end

  -- Start daemon; --fg-daemon is reliable and avoids double-fork weirdness.
  runAsync(shellquote(EMACS) .. " --fg-daemon >/tmp/emacs-daemon.log 2>&1 &")
end

-- Kick off daemon shortly after Hammerspoon loads (at login)
hs.timer.doAfter(2.0, startEmacsDaemon)

-- Optional: also re-check every few minutes (comment out if you dislike this)
-- hs.timer.doEvery(300, startEmacsDaemon)

-- ============================================================
-- Hotkey: Emacs client (new frame in current Space)
-- ============================================================

local function emacsClientHere()
  startEmacsDaemon()
  if not EMACSCLIENT then
    hs.notify.new({ title = "Hammerspoon", informativeText = "Cannot find emacsclient binary" }):send()
    return
  end
  
  focusNewWindow("Emacs", function(app)
    -- -c: create frame; -n: don't wait; -a "": don't auto-start GUI app
    runAsync(shellquote(EMACSCLIENT) .. " -c -n -a ''")
  end)
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "M", emacsClientHere)

-- ============================================================
-- Hotkey: Chrome fresh window in current Space
-- ============================================================

local function chromeNewWindowHere()
  launchOrNewWindow("com.google.Chrome", { "cmd" }, "n", "/Applications/Google Chrome.app")
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "G", chromeNewWindowHere)

-- ============================================================
-- Hotkey: Chromium fresh window in current Space
-- ============================================================

local function chromiumNewWindowHere()
  launchOrNewWindow("Google Chrome Canary", { "cmd" }, "n")
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "C", chromiumNewWindowHere)

-- ============================================================
-- Hotkey: Brave fresh window in current Space
-- ============================================================

local function braveNewWindowHere()
  launchOrNewWindow("Brave Browser", { "cmd" }, "n")
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "B", braveNewWindowHere)


-- = :==========================================================
-- Hotkey: Voicetrans CLI
-- ============================================================

local function voicetransCli()
  -- Using Kitty to run the command and exit.
  local cmd = "cd /Users/fredsmit/personal/dev/voicetrans && ./venv/bin/python3 voicetrans_cli.py && exit"
  hs.task.new("/Applications/kitty.app/Contents/MacOS/kitty", nil, { "-e", "zsh", "-lc", cmd }):start()
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "D", voicetransCli)


-- ============================================================
-- (Optional) Hotkey: restart Emacs daemon (useful during config changes)
-- ============================================================

local function restartEmacsDaemon()
  if EMACSCLIENT then
    runAsync(shellquote(EMACSCLIENT) .. " -e " .. shellquote("(kill-emacs)") .. " >/dev/null 2>&1 || true")
  end
  hs.timer.doAfter(0.5, startEmacsDaemon)
end

-- hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "R", restartEmacsDaemon)

-- ============================================================
-- Window Cycling & Reordering (HUD-synced)
-- ============================================================

-- Bind to Cmd+Alt+Left/Right to cycle through windows on the current space
-- (Using Cmd+Alt because Cmd+Left/Right are standard text navigation keys)
hs.hotkey.bind({"cmd", "alt"}, "left", function() 
    if _G.hud and _G.hud.switchWindow then
        _G.hud.switchWindow("prev")
    end
end)
hs.hotkey.bind({"cmd", "alt"}, "right", function() 
    if _G.hud and _G.hud.switchWindow then
        _G.hud.switchWindow("next")
    end
end)

-- Bind to Ctrl+Cmd+Alt+Left/Right to reorder windows
hs.hotkey.bind({"ctrl", "cmd", "alt"}, "left", function()
    if _G.hud and _G.hud.moveWindow then
        _G.hud.moveWindow("left")
    end
end)
hs.hotkey.bind({"ctrl", "cmd", "alt"}, "right", function()
    if _G.hud and _G.hud.moveWindow then
        _G.hud.moveWindow("right")
    end
end)

hs.hotkey.bind({"cmd", "alt"}, "0", function()
    if _G.hud and _G.hud.update then
        _G.hud.update()
    end
end)

-- ============================================================
-- Window Management (Maximize / Fullscreen)
-- ============================================================

-- Cmd+Alt+Up: Maximize window (fill screen, keep menubar/dock visible)
hs.hotkey.bind({"cmd", "alt"}, "up", function()
  local win = hs.window.focusedWindow()
  if win then win:maximize() end
end)

-- Cmd+Ctrl+Alt+Up: Enter native macOS Fullscreen
hs.hotkey.bind({"cmd", "ctrl", "alt"}, "up", function()
  local win = hs.window.focusedWindow()
  if win then win:setFullScreen(true) end
end)

-- Cmd+Ctrl+Alt+Down: Exit native macOS Fullscreen
hs.hotkey.bind({"cmd", "ctrl", "alt"}, "down", function()
  local win = hs.window.focusedWindow()
  if win then win:setFullScreen(false) end
end)

-- ============================================================
-- Hotkey: VS Code fresh window in current Space
-- ============================================================

local function vscodeNewWindowHere()
  launchOrNewWindow("Code", { "cmd", "shift" }, "n", "/Users/fredsmit/programs/Visual Studio Code.app")
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "V", vscodeNewWindowHere)

-- ============================================================
-- Hotkey: nvim in fresh kitty window in current Space
-- ============================================================

local function nvimNewWindowHere()
  local cmd = "nvim"
  hs.task.new("/Applications/kitty.app/Contents/MacOS/kitty", nil, { "-e", "zsh", "-lc", cmd }):start()
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "N", nvimNewWindowHere)

-- ============================================================
-- Window Switcher (Alt-Tab replacement)
-- ============================================================

-- Create a customized switcher
local switcher = hs.window.switcher.new(
    hs.window.filter.new():setCurrentSpace(true):setDefaultFilter({visible=true}),
    {
        showTitles = true,
        thumbnailSize = 384,
        selectedThumbnailSize = 0,
        showSelectedTitle = true,
        backgroundColor = {0, 0, 0, 0.8},
        highlightColor = {0.3, 0.3, 0.3, 0.8},
    }
)

-- Bind to Ctrl+Cmd+Up (Open / Next)
hs.hotkey.bind({"ctrl", "cmd"}, "up", function()
    switcher:next()
end)

-- Bind Left/Right arrows for navigation while holding Ctrl+Cmd
hs.hotkey.bind({"ctrl", "cmd"}, "right", function()
    switcher:next()
end)

hs.hotkey.bind({"ctrl", "cmd"}, "left", function()
    switcher:previous()
end)

-- ============================================================
-- Toggle Menubar Visibility
-- ============================================================
hs.hotkey.bind({"ctrl"}, "tab", function()
    hs.osascript.applescript('tell application "System Events" to set autohide menu bar of dock preferences to not autohide menu bar of dock preferences')
end)




-- Keep these in global scope so they aren't garbage collected
_G.vpn = require("vpn")
require("hs.ipc")
_G.hud = require("i3_hud")
