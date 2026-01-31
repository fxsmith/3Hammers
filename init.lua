local function newGhosttyHere()
    local app = hs.application.get("Ghostty")

    if not app then
        -- Launch without macOS jumping Spaces
        hs.application.open("Ghostty", 0, true)
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
end

hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "M", emacsClientHere)

-- ============================================================
-- Hotkey: Chrome fresh window in current Space
-- ============================================================

local function chromeNewWindowHere()
  local app = hs.application.get("Google Chrome")
  if not app then
    -- Launch without forcing space switch
    hs.application.open("Google Chrome", 0, true)
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
-- (Optional) Hotkey: restart Emacs daemon (useful during config changes)
-- ============================================================

local function restartEmacsDaemon()
  if EMACSCLIENT then
    runAsync(shellquote(EMACSCLIENT) .. " -e " .. shellquote("(kill-emacs)") .. " >/dev/null 2>&1 || true")
  end
  hs.timer.doAfter(0.5, startEmacsDaemon)
end

-- hs.hotkey.bind({ "ctrl", "alt", "cmd" }, "R", restartEmacsDaemon)
