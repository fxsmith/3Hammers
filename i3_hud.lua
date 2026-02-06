local hs = hs
local canvas = hs.canvas
local screen = hs.screen

-- Configuration
local LABEL_WIDTH_CHARS = 14
local FONT_NAME = "Menlo"
local FONT_SIZE = 16
local BAR_HEIGHT = 26 -- Increased for 16pt font
local CHAR_WIDTH = 10.0 -- Adjusted for 16pt Menlo
local ITEM_PADDING = 12 -- Slightly more padding for larger text
local ITEM_MARGIN = 3   -- px gap between tabs

-- Colors
local COLOR_ACTIVE_BG = { hex = "#007AFF", alpha = 1.0 }
local COLOR_ACTIVE_TXT = { white = 1.0 }
local COLOR_INACTIVE_BG = { hex = "#000000", alpha = 0.8 } -- Dark background for contrast
local COLOR_INACTIVE_TXT = { white = 0.6 } -- Gray text

-- State
local tracked_windows = {}
local hud_canvas = nil

-- Filters
local global_filter = hs.window.filter.new():setDefaultFilter{}
global_filter:setSortOrder(hs.window.filter.sortByCreated)

local space_filter = hs.window.filter.new():setCurrentSpace(true):setDefaultFilter{}

-- -----------------------------------------------------------------------
-- Logic
-- -----------------------------------------------------------------------

local function should_exclude_window(win)
    if not win then return true end
    local app = win:application()
    if not app then return true end
    
    local app_name = app:name()
    local win_frame = win:frame()

    -- Safety check for frame
    if not win_frame then return false end
    
    -- RULE: Zoom "Start Sharing" or mini control windows
    -- Adjust dimensions as needed. Often these are small floating panels.
    if (app_name == "zoom.us" or app_name == "Zoom") and (win_frame.w < 400 or win_frame.h < 200) then
        return true
    end

    return false
end

local function track_window(win)
    if not win then return end
    if should_exclude_window(win) then return end

    local id = win:id()
    local found = false
    for _, tracked_id in ipairs(tracked_windows) do
        if tracked_id == id then found = true; break end
    end
    if not found then table.insert(tracked_windows, id) end
end

local function untrack_window(win)
    if not win then return end
    local id = win:id()
    for i, tracked_id in ipairs(tracked_windows) do
        if tracked_id == id then table.remove(tracked_windows, i); break end
    end
end

local function truncate_and_pad(text, width)
    if not text then text = "" end
    text = text:gsub("\n", ""):gsub("\t", " ")
    local text_len = utf8.len(text) or #text

    if text_len > width then
        local result = ""
        local count = 0
        for p, c in utf8.codes(text) do
            count = count + 1
            if count > (width - 3) then break end
            result = result .. utf8.char(c)
        end
        return result .. "..."
    else
        local padding = width - text_len
        local left_pad = math.floor(padding / 2)
        local right_pad = padding - left_pad
        return string.rep(" ", left_pad) .. text .. string.rep(" ", right_pad)
    end
end

-- -----------------------------------------------------------------------
-- UI Rendering (Canvas)
-- -----------------------------------------------------------------------

local function init_canvas()
    if hud_canvas then hud_canvas:delete() end
    -- Initial generic rect, will be moved in update
    hud_canvas = canvas.new({x=0, y=0, w=100, h=BAR_HEIGHT})
    -- Level: Status (above normal windows, same level as menu bar items)
    hud_canvas:level(canvas.windowLevels.status)
    hud_canvas:behavior(canvas.windowBehaviors.canJoinAllSpaces)
    hud_canvas:show()
end

local function update_hud()
    if not hud_canvas then init_canvas() end

    -- 1. Sync windows
    local windows_on_space = space_filter:getWindows()
    local on_space_map = {}
    for _, w in ipairs(windows_on_space) do
        if not should_exclude_window(w) then
            on_space_map[w:id()] = w
            track_window(w) -- Ensure tracked
        end
    end

    local focused_win = hs.window.focusedWindow()
    local focused_id = focused_win and focused_win:id() or nil

    -- 2. Build Element List
    local elements = {}
    
    local visible_count = 0
    local visible_ids = {}

    for _, id in ipairs(tracked_windows) do
        if on_space_map[id] then
            visible_count = visible_count + 1
            table.insert(visible_ids, id)
        end
    end

    -- 3. Calculate Geometry (Full Screen Width)
    local main_screen = hs.screen.mainScreen()
    local screen_frame = main_screen:fullFrame()
    
    -- If no windows, we treat it as 1 slot for the empty message
    local slot_count = visible_count > 0 and visible_count or 1
    
    -- Calculate width per item, subtracting margins
    -- Total Margins = (slot_count + 1) * ITEM_MARGIN
    -- Available Width = ScreenWidth - Total Margins
    local total_margins = (slot_count + 1) * ITEM_MARGIN
    local available_width = screen_frame.w - total_margins
    local item_width = available_width / slot_count
    
    -- Canvas covers the full top strip
    hud_canvas:frame({
        x = screen_frame.x,
        y = screen_frame.y,
        w = screen_frame.w,
        h = BAR_HEIGHT
    })

    -- 4. Draw Elements
    local current_x = ITEM_MARGIN -- Start with a margin

    if #visible_ids == 0 then
        -- Empty State
        elements[#elements+1] = {
            type = "text",
            text = "[ — ]",
            textSize = FONT_SIZE,
            textFont = FONT_NAME,
            textColor = COLOR_INACTIVE_TXT,
            textAlignment = "center",
            frame = { x = current_x, y = 3, w = item_width, h = BAR_HEIGHT }
        }
    else
        for _, id in ipairs(visible_ids) do
            local win = on_space_map[id]
            local is_active = (id == focused_id)
            
            -- Background Pill
            elements[#elements+1] = {
                type = "rectangle",
                action = "fill",
                fillColor = is_active and COLOR_ACTIVE_BG or COLOR_INACTIVE_BG,
                roundedRectRadii = { xRadius = 4, yRadius = 4 },
                frame = { x = current_x, y = 2, w = item_width, h = BAR_HEIGHT - 4 }
            }

            -- Text
            local app_name = win:application():name()
            local app_initial = app_name:sub(1,3):upper()
            local title = win:title()
            if not title or title == "" then title = app_name end
            
            local display_title = app_initial .. ":" .. title
            -- Dynamic truncation logic based on approximate character capacity
            -- Est. chars = item_width / CHAR_WIDTH
            -- We subtract a bit for safety padding
            local max_chars = math.floor((item_width - (ITEM_PADDING * 2)) / CHAR_WIDTH)
            if max_chars < 5 then max_chars = 5 end -- minimum sanity
            
            local label_text = truncate_and_pad(display_title, max_chars)

            elements[#elements+1] = {
                type = "text",
                text = label_text,
                textSize = FONT_SIZE,
                textFont = is_active and FONT_NAME.."-Bold" or FONT_NAME,
                textColor = is_active and COLOR_ACTIVE_TXT or COLOR_INACTIVE_TXT,
                textAlignment = "center",
                -- Offset Y adjusted for 16pt font in 26px bar
                frame = { x = current_x, y = 3, w = item_width, h = BAR_HEIGHT } 
            }

            current_x = current_x + item_width + ITEM_MARGIN
        end
    end

    hud_canvas:replaceElements(elements)
end

-- -----------------------------------------------------------------------
-- Watchers
-- -----------------------------------------------------------------------

global_filter:subscribe(hs.window.filter.windowCreated, function(win)
    track_window(win)
    hs.timer.doAfter(0.05, update_hud) 
end)

global_filter:subscribe(hs.window.filter.windowDestroyed, function(win)
    untrack_window(win)
    update_hud()
end)

hs.window.filter.default:subscribe(hs.window.filter.windowFocused, function()
    update_hud()
end)

local space_watcher = hs.spaces.watcher.new(function()
    hs.timer.doAfter(0.1, update_hud)
end)
space_watcher:start()

-- Monitor screen resolution changes to re-center
local screen_watcher = hs.screen.watcher.new(function()
    update_hud()
end)
screen_watcher:start()

-- -----------------------------------------------------------------------
-- Navigation (Unchanged logic)
-- -----------------------------------------------------------------------

local function switch_window(direction)
    local windows_on_space = space_filter:getWindows()
    if #windows_on_space == 0 then return end
    
    local on_space_map = {}
    for _, w in ipairs(windows_on_space) do
        on_space_map[w:id()] = w
    end

    local ordered_current_space = {}
    for _, id in ipairs(tracked_windows) do
        if on_space_map[id] then
            table.insert(ordered_current_space, on_space_map[id])
        end
    end
    
    if #ordered_current_space == 0 then return end

    local focused_win = hs.window.focusedWindow()
    local current_idx = 0
    if focused_win then
        for i, w in ipairs(ordered_current_space) do
            if w:id() == focused_win:id() then
                current_idx = i
                break
            end
        end
    end

    local next_idx = current_idx
    if direction == "next" then
        next_idx = current_idx + 1
    elseif direction == "prev" then
        next_idx = current_idx - 1
    end

    if next_idx > #ordered_current_space then next_idx = 1 end
    if next_idx < 1 then next_idx = #ordered_current_space end
    
    if current_idx == 0 then
        if direction == "next" then next_idx = 1 else next_idx = #ordered_current_space end
    end

    local target = ordered_current_space[next_idx]
    if target then target:focus() end
end

-- -----------------------------------------------------------------------
-- Bindings
-- -----------------------------------------------------------------------

local function toggle_hud()
    if hud_canvas:isShowing() then
        hud_canvas:hide()
    else
        hud_canvas:show()
        update_hud()
    end
end

hs.hotkey.bind({"ctrl"}, "left", function() switch_window("prev") end)
hs.hotkey.bind({"ctrl"}, "right", function() switch_window("next") end)
hs.hotkey.bind({"alt", "cmd"}, "return", toggle_hud)

-- Init
init_canvas()
for _, w in ipairs(global_filter:getWindows()) do
    track_window(w)
end
update_hud()

return {
    switchWindow = switch_window,
    update = update_hud
}