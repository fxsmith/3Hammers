local function newGhosttyHere()
    local app = hs.application.get("Ghostty")

    if not app then
        -- Launch without macOS jumping Spaces
        hs.application.open("Ghostty", 0, false)
        hs.timer.doAfter(0.3, function()
            hs.eventtap.keyStroke({"cmd"}, "n")
        end)
    else
        -- Tell running app to make a new window in THIS Space
        app:activate(false) -- don't switch spaces
        hs.eventtap.keyStroke({"cmd"}, "n")
    end
end

hs.hotkey.bind({"ctrl", "alt", "cmd"}, "T", newGhosttyHere)

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
  -- -c: create frame; -n: don't wait; -a "": don't auto-start GUI app
  runAsync(shellquote(EMACSCLIENT) .. " -c -n -a ''")
  hs.timer.doAfter(0.1, function()
    local app = hs.application.get("Emacs")
    if app then app:activate(true) end
  end)
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "M", emacsClientHere)

-- ============================================================
-- Hotkey: Chrome fresh window in current Space
-- ============================================================

local function chromeNewWindowHere()
  local app = hs.application.get("Google Chrome")
  if not app then
    -- Launch without forcing space switch
    hs.application.open("Google Chrome", 0, false)
    hs.timer.doAfter(0.5, function()
      -- Requires Accessibility permission for Hammerspoon to send keystrokes
      hs.eventtap.keyStroke({ "cmd" }, "n", 0)
    end)
  else
    -- Don't jump spaces; then create a new window "here"
    app:activate(false)
    hs.eventtap.keyStroke({ "cmd" }, "n", 0)
  end
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "C", chromeNewWindowHere)

-- ============================================================
-- Hotkey: Brave fresh window in current Space
-- ============================================================

local function braveNewWindowHere()
  local app = hs.application.get("Brave Browser")
  if not app then
    -- Launch without forcing space switch
    hs.application.open("Brave Browser", 0, false)
    hs.timer.doAfter(0.5, function()
      hs.eventtap.keyStroke({ "cmd" }, "n", 0)
    end)
  else
    -- Don't jump spaces; then create a new window "here"
    app:activate(false)
    hs.eventtap.keyStroke({ "cmd" }, "n", 0)
  end
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "B", braveNewWindowHere)


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
-- Window Cycling
-- ============================================================

local cycleFilter = hs.window.filter.new():setCurrentSpace(true):setDefaultFilter{}
cycleFilter:setSortOrder(hs.window.filter.sortByCreated)

local function cycleWindows(step)
  local windows = cycleFilter:getWindows()
  local focused = hs.window.focusedWindow()
  local numWindows = #windows

  if numWindows == 0 then return end

  local currentIndex = 0
  if focused then
    for i, w in ipairs(windows) do
      if w:id() == focused:id() then
        currentIndex = i
        break
      end
    end
  end

  if currentIndex == 0 then
    windows[1]:focus()
    return
  end

  local newIndex = currentIndex + step
  if newIndex > numWindows then newIndex = 1 end
  if newIndex < 1 then newIndex = numWindows end

  windows[newIndex]:focus()
end

-- Bind to Cmd+Alt+Left/Right to cycle through windows on the current space
-- (Using Cmd+Alt because Cmd+Left/Right are standard text navigation keys)
hs.hotkey.bind({"cmd", "alt"}, "left", function() cycleWindows(-1) end)
hs.hotkey.bind({"cmd", "alt"}, "right", function() cycleWindows(1) end)

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
  local app = hs.application.get("Code")
  if not app then
    -- Launch without forcing space switch
    hs.application.open("/Users/fredsmit/programs/Visual Studio Code.app", 0, false)
    hs.timer.doAfter(0.5, function()
      hs.eventtap.keyStroke({ "cmd", "shift" }, "n", 0)
    end)
  else
    -- Don't jump spaces; then create a new window "here"
    app:activate(false)
    hs.eventtap.keyStroke({ "cmd", "shift" }, "n", 0)
  end
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "V", vscodeNewWindowHere)



