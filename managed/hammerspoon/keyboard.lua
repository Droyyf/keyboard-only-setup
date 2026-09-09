-- Keyboard-only enhancement layer. Loaded by init.lua with require("keyboard").
-- Hyper is Caps Lock after the Raycast remap: cmd+alt+ctrl+shift.

local hyper = { "cmd", "alt", "ctrl", "shift" }
local MODE_FILE = "/Users/droy-/.config/keyboard-mode"
local MODE_HELPER = "/Users/droy-/.config/skhd/set-keyboard-mode.py"
local YABAI = "/Users/droy-/dev/yabai-macos27/bin/yabai"

local function readMode()
  local file = io.open(MODE_FILE, "r")
  if file then
    local mode = file:read("*l")
    file:close()
    if mode == "dual" or mode == "left" then return mode end
  end
  return "dual"
end

local currentMode = readMode()
local menubar = nil
local defaultHintChars = hs.hints.hintChars
local defaultHintStyle = hs.hints.style

local function modeLabel(mode)
  return mode == "left" and "LEFT HAND" or "DUAL HAND"
end

local function commandSucceeded(command)
  local ok, _, success, _, code = pcall(hs.execute, command)
  if not ok then return false end
  -- hs.execute returns output, success, terminationType, returnCode.
  return success == true or code == 0
end

local function showAlert(message, seconds)
  hs.alert.show(message, nil, nil, seconds or 1.2)
end

-- --------------------------------------------------------------------------
-- Transient keyboard layers. They only bind unmodified letters while a layer
-- is active, so ordinary text input is never globally captured.
-- --------------------------------------------------------------------------
local activeLayer = nil
local layerKeys = {}
local layerTimer = nil
local layerCanvas = nil
local referenceCanvas = nil
local referenceKeys = {}
local referenceVisible = false
local gridHide = nil
local snapTarget = nil
local layerRequest = 0

local function hideLayerOverlay()
  if layerCanvas then layerCanvas:hide() end
end

local function clearLayerKeys()
  for _, hotkey in ipairs(layerKeys) do
    if hotkey.delete then hotkey:delete() else hotkey:disable() end
  end
  layerKeys = {}
end

local function closeLayer()
  layerRequest = layerRequest + 1
  if layerTimer then layerTimer:stop() end
  layerTimer = nil
  clearLayerKeys()
  hideLayerOverlay()
  snapTarget = nil
  activeLayer = nil
end

local function closeReference()
  for _, hotkey in ipairs(referenceKeys) do
    if hotkey.delete then hotkey:delete() else hotkey:disable() end
  end
  referenceKeys = {}
  if referenceCanvas then referenceCanvas:hide() end
  referenceVisible = false
end

local function layerOverlay(title, subtitle, text)
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not screen then return end
  local frame = screen:frame()
  local overlayWidth = math.max(344, math.min(620, frame.w - 48))
  local overlayHeight = math.min(frame.h - 48, 258)
  local panelX = math.max(24, math.floor((frame.w - overlayWidth) / 2))
  local panelY = math.max(24, math.floor((frame.h - overlayHeight) / 2))
  local dark = not hs.host or not hs.host.interfaceStyle or hs.host.interfaceStyle() ~= "Light"
  local background = dark and { red = 0.10, green = 0.11, blue = 0.14, alpha = 0.97 }
    or { red = 0.96, green = 0.97, blue = 0.99, alpha = 0.98 }
  local primary = dark and { red = 0.97, green = 0.98, blue = 1.0, alpha = 1 }
    or { red = 0.08, green = 0.09, blue = 0.12, alpha = 1 }
  local secondary = dark and { red = 0.72, green = 0.76, blue = 0.83, alpha = 1 }
    or { red = 0.31, green = 0.35, blue = 0.42, alpha = 1 }
  if not layerCanvas then
    layerCanvas = hs.canvas.new(frame)
    layerCanvas:level("overlay")
    layerCanvas:clickActivating(false)
  else
    layerCanvas:frame(frame)
  end
  layerCanvas:replaceElements({
    {
      type = "rectangle", action = "fill",
      frame = { x = panelX, y = panelY, w = overlayWidth, h = overlayHeight },
      fillColor = background,
      roundedRectRadii = { xRadius = 14, yRadius = 14 },
    },
    {
      type = "rectangle", action = "fill",
      frame = { x = panelX + 22, y = panelY + 22, w = 4, h = 42 },
      fillColor = { red = 0.30, green = 0.60, blue = 1.0, alpha = 1 },
      roundedRectRadii = { xRadius = 2, yRadius = 2 },
    },
    {
      type = "text", text = title,
      frame = { x = panelX + 42, y = panelY + 18, w = overlayWidth - 150, h = 26 },
      textSize = 18, textColor = primary,
      textFont = ".AppleSystemUIFont",
    },
    {
      type = "text", text = subtitle,
      frame = { x = panelX + 42, y = panelY + 44, w = overlayWidth - 150, h = 22 },
      textSize = 13, textColor = secondary,
      textFont = ".AppleSystemUIFont",
    },
    {
      type = "text", text = "ESC  Close",
      frame = { x = panelX + overlayWidth - 108, y = panelY + 24, w = 84, h = 22 },
      textSize = 12, textColor = secondary,
      textFont = ".AppleSystemUIFont",
    },
    {
      type = "text", text = text,
      frame = { x = panelX + 28, y = panelY + 88, w = overlayWidth - 56, h = overlayHeight - 106 },
      textSize = 15, textColor = primary,
      textFont = ".AppleSystemUIFont",
    },
  })
  layerCanvas:show()
end

local function resetLayerTimeout()
  if layerTimer then layerTimer:stop() end
  layerTimer = hs.timer.doAfter(15, closeLayer)
end

local function bindLayer(modifiers, key, action, repeats)
  local function run()
    if not activeLayer then return end
    resetLayerTimeout()
    action()
  end
  table.insert(layerKeys, hs.hotkey.bind(modifiers or {}, key, run, nil, repeats and run or nil))
end

local function enterLayer(name, title, subtitle, help)
  if gridHide then gridHide() end
  closeLayer()
  activeLayer = { name = name }
  layerOverlay(title, subtitle, help)
  bindLayer({}, "escape", closeLayer)
  resetLayerTimeout()
end

local function modifiersStillDown()
  local modifiers = hs.eventtap.checkKeyboardModifiers()
  return modifiers.cmd or modifiers.alt or modifiers.ctrl or modifiers.shift
end

-- Starting after the initiating Hyper chord is released prevents its final
-- key-up event from becoming ordinary text or a layer action.
local function afterModifiersRelease(start)
  layerRequest = layerRequest + 1
  local request = layerRequest
  local tries = 0
  local function attempt()
    if request ~= layerRequest then return end
    if modifiersStillDown() and tries < 80 then
      tries = tries + 1
      hs.timer.doAfter(0.025, attempt)
      return
    end
    if modifiersStillDown() then return end
    start()
  end
  hs.timer.doAfter(0.01, attempt)
end

-- --------------------------------------------------------------------------
-- Mouse grid. Canvas elements are screen-frame local; mouse points remain
-- absolute screen coordinates. This fixes the old double-offset rendering.
-- --------------------------------------------------------------------------
local GRID_COLS, GRID_ROWS = 12, 8
local gridCanvas = nil
local gridState = nil
local gridKeys = {}

local function gridPoint()
  local state = gridState
  local cellWidth = state.frame.w / GRID_COLS
  local cellHeight = state.frame.h / GRID_ROWS
  local x = state.frame.x + (state.cx - 1) * cellWidth
  local y = state.frame.y + (state.cy - 1) * cellHeight
  if state.fine then
    local fineWidth, fineHeight = cellWidth / GRID_COLS, cellHeight / GRID_ROWS
    return {
      x = x + (state.scx - 0.5) * fineWidth,
      y = y + (state.scy - 0.5) * fineHeight,
    }
  end
  return { x = x + cellWidth / 2, y = y + cellHeight / 2 }
end

local function gridRender()
  local state = gridState
  if not state or not gridCanvas then return end
  local cellWidth = state.frame.w / GRID_COLS
  local cellHeight = state.frame.h / GRID_ROWS
  local localX = (state.cx - 1) * cellWidth
  local localY = (state.cy - 1) * cellHeight
  local elements = {
    {
      type = "rectangle", action = "fillStroke",
      frame = { x = localX, y = localY, w = cellWidth, h = cellHeight },
      fillColor = { red = 1, green = 0.25, blue = 0.25, alpha = 0.10 },
      strokeColor = { red = 1, green = 0.25, blue = 0.25, alpha = 0.90 },
      strokeWidth = 2,
    },
  }

  if state.fine then
    local fineWidth, fineHeight = cellWidth / GRID_COLS, cellHeight / GRID_ROWS
    table.insert(elements, {
      type = "rectangle", action = "fillStroke",
      frame = {
        x = localX + (state.scx - 1) * fineWidth,
        y = localY + (state.scy - 1) * fineHeight,
        w = fineWidth, h = fineHeight,
      },
      fillColor = { red = 1, green = 0.25, blue = 0.25, alpha = 0.25 },
      strokeColor = { red = 1, green = 0.9, blue = 0.2, alpha = 1 },
      strokeWidth = 2,
    })
  else
    local columns = "abcdefghijkl"
    for column = 1, GRID_COLS do
      for row = 1, GRID_ROWS do
        table.insert(elements, {
          type = "text", text = columns:sub(column, column) .. row,
          frame = {
            x = (column - 1) * cellWidth,
            y = (row - 1) * cellHeight + cellHeight / 2 - 7,
            w = cellWidth, h = 14,
          },
          textSize = 10,
          textColor = { white = 0.95, alpha = 0.85 },
          textAlignment = "center",
        })
      end
    end
  end
  gridCanvas:replaceElements(elements)
end

gridHide = function()
  for _, hotkey in ipairs(gridKeys) do
    if hotkey.delete then hotkey:delete() else hotkey:disable() end
  end
  gridKeys = {}
  gridState = nil
  if gridCanvas then gridCanvas:hide() end
end

local function gridShow()
  gridHide() -- Every invocation owns exactly one set of unmodified bindings.
  closeLayer()
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not screen then
    showAlert("Mouse grid unavailable")
    return
  end
  local frame = screen:frame()
  gridState = {
    frame = frame,
    cx = math.ceil(GRID_COLS / 2), cy = math.ceil(GRID_ROWS / 2),
    scx = math.ceil(GRID_COLS / 2), scy = math.ceil(GRID_ROWS / 2),
    fine = false,
  }
  if not gridCanvas then
    gridCanvas = hs.canvas.new(frame)
    gridCanvas:level("overlay")
    gridCanvas:clickActivating(false)
  else
    gridCanvas:frame(frame)
  end
  gridCanvas:show()
  gridRender()

  local function bind(key, action, repeats)
    table.insert(gridKeys, hs.hotkey.bind({}, key, action, nil, repeats and action or nil))
  end
  local function move(dx, dy)
    local state = gridState
    state.cx = math.max(1, math.min(GRID_COLS, state.cx + dx))
    state.cy = math.max(1, math.min(GRID_ROWS, state.cy + dy))
    gridRender()
  end
  local function fineMove(dx, dy)
    if not gridState.fine then return move(dx, dy) end
    local state = gridState
    state.scx = math.max(1, math.min(GRID_COLS, state.scx + dx))
    state.scy = math.max(1, math.min(GRID_ROWS, state.scy + dy))
    gridRender()
  end

  local movement = currentMode == "left"
    and { a = { -1, 0 }, s = { 0, 1 }, w = { 0, -1 }, d = { 1, 0 } }
    or { h = { -1, 0 }, j = { 0, 1 }, k = { 0, -1 }, l = { 1, 0 } }
  for key, delta in pairs(movement) do
    bind(key, function() fineMove(delta[1], delta[2]) end, true)
  end
  bind("g", function() gridState.fine = not gridState.fine; gridRender() end)
  bind("escape", gridHide)
  bind("c", function() hs.eventtap.leftClick(gridPoint()); gridHide() end)
  bind(currentMode == "left" and "f" or "d", function()
    local point = gridPoint()
    hs.eventtap.leftClick(point)
    hs.timer.usleep(120000)
    hs.eventtap.leftClick(point)
    gridHide()
  end)
  bind("x", function() hs.eventtap.rightClick(gridPoint()); gridHide() end)
end

local function closeTransient()
  gridHide()
  closeLayer()
end

-- --------------------------------------------------------------------------
-- Existing application and layout actions.
-- --------------------------------------------------------------------------
local appChooser = nil
local appChoices = {}
local appControlKeys = {}
local appSelection = 1

local function clearAppControls()
  for _, hotkey in ipairs(appControlKeys) do
    if hotkey.delete then hotkey:delete() else hotkey:disable() end
  end
  appControlKeys = {}
end

local function activateAppChoice(choice)
  if not choice then return end
  local app = hs.application.applicationForPID(choice.pid)
  if app then app:activate() end
end

local function updateAppSelection(delta)
  local row = appChooser:selectedRow() or 1
  pcall(function() appChooser:selectedRow(math.max(1, row + delta)) end)
end

local function openAppSwitcher()
  if not appChooser then
    appChooser = hs.chooser.new(function(choice)
      activateAppChoice(choice)
    end)
    appChooser:width(26)
    appChooser:hideCallback(clearAppControls)
  end
  appChoices = {}
  for _, app in ipairs(hs.application.runningApplications()) do
    if app:kind() >= 0 and app:name() and #app:name() > 0 then
      table.insert(appChoices, {
        text = app:name(), subText = app:bundleID() or "", pid = app:pid(),
        image = hs.image.imageFromAppBundle(app:bundleID()),
      })
    end
  end
  table.sort(appChoices, function(a, b) return a.text:lower() < b.text:lower() end)
  appChooser:choices(appChoices)
  appChooser:placeholderText("Switch to running app…")
  appChooser:show()
  if currentMode == "left" then
    clearAppControls()
    table.insert(appControlKeys, hs.hotkey.bind({ "ctrl" }, "w", function() updateAppSelection(-1) end))
    table.insert(appControlKeys, hs.hotkey.bind({ "ctrl" }, "s", function() updateAppSelection(1) end))
    table.insert(appControlKeys, hs.hotkey.bind({ "ctrl" }, "e", function()
      appChooser:select()
    end))
  end
end

local function cycleCurrentAppWindow()
  local app = hs.application.frontmostApplication()
  if not app then return end
  local windows = {}
  for _, window in ipairs(app:allWindows()) do
    if window:isStandard() and not window:isMinimized() then table.insert(windows, window) end
  end
  if #windows < 2 then return end
  local current = app:focusedWindow()
  local nextWindow = windows[1]
  for index, window in ipairs(windows) do
    if current and window:id() == current:id() then
      nextWindow = windows[(index % #windows) + 1]
      break
    end
  end
  nextWindow:focus()
end

local launchTable = {
  a = { name = "Arc", bundleID = "company.thebrowser.Browser" },
  c = { name = "ChatGPT", bundleID = "com.openai.codex" },
  f = { name = "Finder", bundleID = "com.apple.finder" },
  t = { name = "kitty", bundleID = "net.kovidgoyal.kitty" },
}

local LAYOUT_FILE = hs.configdir .. "/window-layout.json"
local function saveLayout()
  local layout = {}
  for _, window in ipairs(hs.window.allWindows()) do
    if window:isStandard() and not window:isMinimized() then
      local app, frame = window:application(), window:frame()
      table.insert(layout, {
        app = app and (app:bundleID() or app:name()) or "", title = window:title(),
        frame = { x = frame.x, y = frame.y, w = frame.w, h = frame.h },
      })
    end
  end
  hs.json.write(layout, LAYOUT_FILE)
  showAlert("Layout saved — " .. #layout .. " windows")
end

local function loadLayout()
  if not hs.fs.attributes(LAYOUT_FILE) then
    showAlert("No layout snapshot saved yet")
    return
  end
  local ok, layout = pcall(hs.json.read, LAYOUT_FILE)
  if not ok or type(layout) ~= "table" or #layout == 0 then
    showAlert("Layout snapshot is unavailable")
    return
  end
  local restored = 0
  for _, entry in ipairs(layout) do
    if type(entry) == "table" and type(entry.frame) == "table" and entry.frame.x and entry.frame.w then
      local app = entry.app and hs.application.get(entry.app) or nil
      if not app and entry.app and entry.app:find("%.") then
        hs.application.launchOrFocusByBundleID(entry.app)
        hs.timer.usleep(400000)
        app = hs.application.get(entry.app)
      end
      if app then
        local target = nil
        for _, window in ipairs(app:allWindows()) do
          if window:isStandard() and window:title() == entry.title then target = window; break end
        end
        target = target or app:mainWindow()
        if target and target:isStandard() then
          local moved = pcall(function()
            target:setFrame(hs.geometry.rect(entry.frame.x, entry.frame.y, entry.frame.w, entry.frame.h))
          end)
          if moved then restored = restored + 1 end
        end
      end
    end
  end
  showAlert("Layout restored — " .. restored .. "/" .. #layout .. " windows")
end

local function changeVolume(delta)
  local device = hs.audiodevice.defaultOutputDevice()
  if not device then return end
  local value = math.max(0, math.min(100, (device:volume() or 0) + delta))
  device:setVolume(value)
  showAlert("Volume " .. math.floor(value) .. "%", 0.6)
end

local function changeBrightness(delta)
  local current = hs.brightness.get()
  if type(current) ~= "number" then
    showAlert("Brightness unavailable")
    return
  end
  local target = math.max(0, math.min(100, current + delta))
  local ok, result = pcall(hs.brightness.set, target)
  if not ok or result == false then
    showAlert("Brightness unavailable")
    return
  end
  -- hs.brightness.set returns a success boolean, never the new brightness.
  showAlert("Brightness " .. math.floor(target) .. "%", 0.6)
end

local function scrollBy(x, y)
  hs.eventtap.event.newScrollEvent({ x, y }, {}, "line"):post()
end

local function bindScroll(modifiers, key, x, y)
  local function action() scrollBy(x, y) end
  hs.hotkey.bind(modifiers, key, action, nil, action)
end

local function reloadConfigs()
  hs.execute("launchctl kickstart -k gui/$(id -u)/com.koekeishiya.skhd")
  hs.reload()
end

local function toggleDarkMode()
  local ok = hs.osascript.applescript(
    "tell application \"System Events\" to tell appearance preferences to set dark mode to (not dark mode)")
  if not ok then showAlert("Could not toggle dark mode") end
end

local function focusOrLaunchApplication(applicationSpec)
  local application = hs.application.get(applicationSpec.bundleID) or hs.application.get(applicationSpec.name)
  if not application then
    if not hs.application.launchOrFocusByBundleID(applicationSpec.bundleID) then
      hs.application.launchOrFocus(applicationSpec.name)
    end
    return
  end

  local window = application:focusedWindow() or application:mainWindow()
  if not window then
    for _, candidate in ipairs(application:allWindows() or {}) do
      if candidate:isStandard() then
        window = candidate
        break
      end
    end
  end

  local focusedWindow = hs.window.focusedWindow()
  local windowID = window and window:id()
  local focusedWindowID = focusedWindow and focusedWindow:id()
  if windowID and focusedWindowID and windowID == focusedWindowID then
    window:minimize()
    return
  end

  application:unhide()
  application:activate(true)
  if not window then return end

  if window:isMinimized() then window:unminimize() end
  window:raise()
  window:focus()
end

local function terminalAtFinderFolder()
  if hs.application.get("kitty") then
    focusOrLaunchApplication(launchTable.t)
    return
  end
  local ok, path = hs.osascript.applescript([[
tell application "Finder"
  set theFolder to (insertion location as alias)
  set thePath to POSIX path of theFolder
end tell
return thePath]])
  if not ok or not path or path == "" then showAlert("No Finder folder available"); return end
  path = tostring(path):gsub("%s+$", "")
  hs.execute("open -na kitty --args --directory " .. path:gsub("[%s'\"\\]", function(c) return "\\" .. c end))
end

local function showHints()
  if currentMode == "left" then
    hs.hints.hintChars = { "a", "s", "d", "f", "q", "w", "e", "r", "z", "x", "c", "v" }
    hs.hints.style = nil
  else
    hs.hints.hintChars = defaultHintChars
    hs.hints.style = defaultHintStyle
  end
  hs.hints.windowHints()
end

-- --------------------------------------------------------------------------
-- Mode-aware native floating-window snaps and left-hand application UI
-- navigation. Window hotkeys stay in this file so Raycast and yabai cannot
-- register a second owner for the same chord.
-- --------------------------------------------------------------------------
local SNAP_UNITS = {
  left = { x = 0, y = 0, w = 0.5, h = 1 },
  bottom = { x = 0, y = 0.5, w = 1, h = 0.5 },
  top = { x = 0, y = 0, w = 1, h = 0.5 },
  right = { x = 0.5, y = 0, w = 0.5, h = 1 },
  topLeft = { x = 0, y = 0, w = 0.5, h = 0.5 },
  topRight = { x = 0.5, y = 0, w = 0.5, h = 0.5 },
  bottomLeft = { x = 0, y = 0.5, w = 0.5, h = 0.5 },
  bottomRight = { x = 0.5, y = 0.5, w = 0.5, h = 0.5 },
  maximize = { x = 0, y = 0, w = 1, h = 1 },
  center = { x = 0.15, y = 0.10, w = 0.70, h = 0.80 },
}

local function snapFocusedWindow(unit)
  local window = snapTarget or hs.window.focusedWindow()
  if not window or not window:isStandard() then showAlert("No standard focused window to snap"); return end
  local ok = pcall(function() window:moveToUnit(unit) end)
  if not ok then showAlert("Window snap failed") end
end

local function focusSpace(number)
  if not commandSucceeded(YABAI .. " -m space --focus " .. number) then showAlert("Space command failed") end
end

local function sendAndFollowSpace(number)
  local command = YABAI .. " -m window --space " .. number .. " && " .. YABAI .. " -m space --focus " .. number
  if not commandSucceeded(command) then showAlert("Space command failed") end
end

local function oneShot(action)
  closeLayer()
  action()
end

local function enterSpaceLayer()
  enterLayer("spaces", "Spaces", "Focus a Space, or add Shift to move the focused window", "1  2  3  4  5\nQ  W  E  R  = Spaces 6–9")
  local keys = { "1", "2", "3", "4", "5", "q", "w", "e", "r" }
  for number, key in ipairs(keys) do
    bindLayer({}, key, function() oneShot(function() focusSpace(number) end) end)
    bindLayer({ "shift" }, key, function() oneShot(function() sendAndFollowSpace(number) end) end)
  end
end

local function enterSnapLayer()
  enterLayer("snap", "Snap and system", "Choose one action; the guide closes after the action", "A left   S bottom   W top   D right\nQ/E/Z/C quarters   F maximize   R center   T spaces\nB follow   V hide app   G minimize   1 Mission Control   2 hidden files")
  snapTarget = hs.window.focusedWindow()
  local units = {
    a = SNAP_UNITS.left, s = SNAP_UNITS.bottom, w = SNAP_UNITS.top, d = SNAP_UNITS.right,
    q = SNAP_UNITS.topLeft, e = SNAP_UNITS.topRight,
    z = SNAP_UNITS.bottomLeft, c = SNAP_UNITS.bottomRight,
    f = SNAP_UNITS.maximize, r = SNAP_UNITS.center,
  }
  for key, unit in pairs(units) do
    bindLayer({}, key, function() oneShot(function() snapFocusedWindow(unit) end) end)
  end
  bindLayer({}, "t", enterSpaceLayer)
  bindLayer({}, "b", function()
    oneShot(function() hs.eventtap.keyStroke(hyper, "end", 0) end)
  end)
  bindLayer({}, "v", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "h", 0) end) end)
  bindLayer({}, "g", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "m", 0) end) end)
  bindLayer({}, "1", function() oneShot(function() hs.eventtap.keyStroke({ "ctrl" }, "up", 0) end) end)
  bindLayer({}, "2", function() oneShot(function() hs.eventtap.keyStroke({ "cmd", "shift" }, ".", 0) end) end)
end

local function enterDualSnapLayer()
  enterLayer("dual-snap", "Snap and system", "Two-hand map — choose one action; the guide closes after the action", "H left   J bottom   K top   L right\nU/I/O/P quarters   ; maximize   ' center   T spaces\nB follow   V hide app   G minimize   1 Mission Control   2 hidden files")
  snapTarget = hs.window.focusedWindow()
  local units = {
    h = SNAP_UNITS.left, j = SNAP_UNITS.bottom, k = SNAP_UNITS.top, l = SNAP_UNITS.right,
    u = SNAP_UNITS.topLeft, i = SNAP_UNITS.topRight,
    o = SNAP_UNITS.bottomLeft, p = SNAP_UNITS.bottomRight,
    [";"] = SNAP_UNITS.maximize, ["'"] = SNAP_UNITS.center,
  }
  for key, unit in pairs(units) do
    bindLayer({}, key, function() oneShot(function() snapFocusedWindow(unit) end) end)
  end
  bindLayer({}, "t", enterSpaceLayer)
  bindLayer({}, "b", function() oneShot(function() hs.eventtap.keyStroke(hyper, "end", 0) end) end)
  bindLayer({}, "v", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "h", 0) end) end)
  bindLayer({}, "g", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "m", 0) end) end)
  bindLayer({}, "1", function() oneShot(function() hs.eventtap.keyStroke({ "ctrl" }, "up", 0) end) end)
  bindLayer({}, "2", function() oneShot(function() hs.eventtap.keyStroke({ "cmd", "shift" }, ".", 0) end) end)
end

local function persistentKey(sourceKey, targetKey, modifiers)
  bindLayer({}, sourceKey, function() hs.eventtap.keyStroke(modifiers or {}, targetKey, 0) end, true)
end

local function navigationOneShot(modifiers, key)
  bindLayer({}, key, function()
    oneShot(function() hs.eventtap.keyStroke(modifiers, key, 0) end)
  end)
end

local function enterNavigationLayer(name, arrows, directions)
  enterLayer(name, "Navigation", "Move, select, edit, and control browser tabs without leaving the keyboard", directions .. " arrows   Shift selects   Q backspace   E return\nR tab   Shift+R reverse tab   B/V previous/next tab\nG address   4 find   T new tab   X close tab   1/2 back/forward")
  for key, arrow in pairs(arrows) do
    bindLayer({}, key, function() hs.eventtap.keyStroke({}, arrow, 0) end, true)
    bindLayer({ "shift" }, key, function() hs.eventtap.keyStroke({ "shift" }, arrow, 0) end, true)
  end
  persistentKey("q", "delete")
  bindLayer({}, "e", function() oneShot(function() hs.eventtap.keyStroke({}, "return", 0) end) end)
  persistentKey("f", "forwarddelete")
  persistentKey("z", "pageup")
  persistentKey("c", "pagedown")
  bindLayer({}, "r", function() hs.eventtap.keyStroke({}, "tab", 0) end, true)
  bindLayer({ "shift" }, "r", function() hs.eventtap.keyStroke({ "shift" }, "tab", 0) end, true)
  for key, arrow in pairs(arrows) do
    bindLayer({ "ctrl" }, key, function() hs.eventtap.keyStroke({ "alt" }, arrow, 0) end, true)
    bindLayer({ "ctrl", "shift" }, key, function() hs.eventtap.keyStroke({ "alt", "shift" }, arrow, 0) end, true)
    bindLayer({ "cmd" }, key, function() hs.eventtap.keyStroke({ "cmd" }, arrow, 0) end, true)
    bindLayer({ "cmd", "shift" }, key, function() hs.eventtap.keyStroke({ "cmd", "shift" }, arrow, 0) end, true)
  end
  bindLayer({}, "b", function() hs.eventtap.keyStroke({ "ctrl", "shift" }, "tab", 0) end)
  bindLayer({}, "v", function() hs.eventtap.keyStroke({ "ctrl" }, "tab", 0) end)
  bindLayer({}, "g", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "l", 0) end) end)
  bindLayer({}, "4", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "f", 0) end) end)
  bindLayer({}, "t", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "t", 0) end) end)
  bindLayer({}, "x", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "w", 0) end) end)
  bindLayer({}, "1", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "[", 0) end) end)
  bindLayer({}, "2", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "]", 0) end) end)
end

local function updateMenubar()
  if not menubar then return end
  menubar:setTitle(currentMode == "left" and "LH" or "2H")
end

local function setMode(mode)
  if mode ~= "dual" and mode ~= "left" then
    showAlert("Unknown keyboard mode")
    return false
  end
  if not commandSucceeded(MODE_HELPER .. " " .. mode) then
    showAlert("Keyboard mode change failed")
    return false
  end
  currentMode = mode
  closeTransient()
  updateMenubar()
  showAlert("Mode: " .. modeLabel(mode))
  hs.reload()
  return true
end

local function toggleMode()
  return setMode(currentMode == "dual" and "left" or "dual")
end

local function configureMenubar()
  menubar = hs.menubar.new(true)
  if not menubar then return end
  menubar:setTitle(currentMode == "left" and "LH" or "2H")
  menubar:setMenu(function()
    return {
      { title = "Keyboard mode: " .. modeLabel(currentMode), disabled = true },
      { title = "Dual hand (2H)", checked = currentMode == "dual", fn = function() setMode("dual") end },
      { title = "Left hand (LH)", checked = currentMode == "left", fn = function() setMode("left") end },
    }
  end)
end

local function showCheatsheet()
  if referenceVisible then
    closeReference()
    return
  end
  closeLayer()
  local text, modeName
  if currentMode == "left" then
    modeName = "Left hand workflow"
    text = [[
APPS  A Arc   C ChatGPT   F Finder   T kitty   R running apps   Space Raycast
CORE  5 menu   E hints   4 next app window   V clipboard   G mouse grid   Tab mode
LAYERS  X snap and system   X then T Spaces   3 navigation
WINDOWS  Option+A/S/W/D focus   Shift+Option+A/S/W/D move   Fn+A/S/W/D resize
SPACES  Option+1–5 focus   Shift+Option+1–5 send   Option+Z/X cycle
SYSTEM  Q/Z volume   1/2 brightness   Ctrl+Option+W/A/S/D scroll
OTHER  S/D layouts   B appearance   W Finder terminal   Esc reload
NAVIGATION  W/A/S/D arrows   Shift select   Q delete   E Return   R Tab
Shortcat: Command+Shift+Space, type a hint, then Return
]]
  else
    modeName = "Two-hand workflow"
    text = [[
APPS  A Arc   C ChatGPT   F Finder   T kitty   R running apps   Space Raycast
CORE  M menu   E hints   N next app window   V clipboard   G mouse grid   Tab mode
LAYERS  X snap and system   X then T Spaces   3 navigation
WINDOWS  Option+H/J/K/L focus   Shift+Option+H/J/K/L move   Fn+H/J/K/L resize
SNAP  Hyper+H/J/K/L halves   Hyper+U/I/O/P quarters   Hyper+; maximize   Hyper+' center
SPACES  Option+1–9 focus   Shift+Option+1–9 send   Option+Z/V cycle
SYSTEM  Hyper+arrows volume and brightness   Ctrl+Option+arrows scroll
OTHER  S/D layouts   B appearance   W Finder terminal   Esc reload
NAVIGATION  H/J/K/L arrows   Shift select   Q delete   E Return   R Tab
Shortcat: Command+Shift+Space, type a hint, then Return
]]
  end
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen()
  if not screen then return end
  local frame = screen:frame()
  local width = math.max(620, math.min(940, frame.w - 64))
  local height = math.max(480, math.min(660, frame.h - 64))
  local x = math.max(24, math.floor((frame.w - width) / 2))
  local y = math.max(24, math.floor((frame.h - height) / 2))
  local dark = not hs.host or not hs.host.interfaceStyle or hs.host.interfaceStyle() ~= "Light"
  local background = dark and { red = 0.10, green = 0.11, blue = 0.14, alpha = 0.98 }
    or { red = 0.96, green = 0.97, blue = 0.99, alpha = 0.99 }
  local primary = dark and { red = 0.97, green = 0.98, blue = 1.0, alpha = 1 }
    or { red = 0.08, green = 0.09, blue = 0.12, alpha = 1 }
  local secondary = dark and { red = 0.72, green = 0.76, blue = 0.83, alpha = 1 }
    or { red = 0.31, green = 0.35, blue = 0.42, alpha = 1 }
  if not referenceCanvas then
    referenceCanvas = hs.canvas.new(frame)
    referenceCanvas:level("overlay")
    referenceCanvas:clickActivating(false)
  else
    referenceCanvas:frame(frame)
  end
  referenceCanvas:replaceElements({
    { type = "rectangle", action = "fill", frame = { x = x, y = y, w = width, h = height }, fillColor = background, roundedRectRadii = { xRadius = 16, yRadius = 16 } },
    { type = "rectangle", action = "fill", frame = { x = x + 28, y = y + 28, w = 5, h = 50 }, fillColor = { red = 0.30, green = 0.60, blue = 1.0, alpha = 1 }, roundedRectRadii = { xRadius = 2, yRadius = 2 } },
    { type = "text", text = modeName, frame = { x = x + 50, y = y + 24, w = width - 190, h = 28 }, textSize = 21, textColor = primary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = "Complete shortcut reference", frame = { x = x + 50, y = y + 51, w = width - 190, h = 22 }, textSize = 13, textColor = secondary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = "Hyper+/ or Hyper+`  Close", frame = { x = x + width - 210, y = y + 35, w = 178, h = 20 }, textSize = 12, textColor = secondary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = text, frame = { x = x + 34, y = y + 108, w = width - 68, h = height - 142 }, textSize = 15, textColor = primary, textFont = ".AppleSystemUIFont" },
  })
  referenceCanvas:show()
  referenceVisible = true
  table.insert(referenceKeys, hs.hotkey.bind({}, "escape", closeReference))
end

-- Common action bindings.
for key, applicationSpec in pairs(launchTable) do
  hs.hotkey.bind(hyper, key, function() focusOrLaunchApplication(applicationSpec) end)
end
hs.hotkey.bind(hyper, "space", function() hs.execute("open 'raycast://'") end)
hs.hotkey.bind(hyper, "r", openAppSwitcher)
hs.hotkey.bind(hyper, "e", showHints)
hs.hotkey.bind(hyper, "g", function() if gridState then gridHide() else gridShow() end end)
hs.hotkey.bind(hyper, "v", function() hs.execute("open 'raycast://extensions/raycast/clipboard-history'") end)
hs.hotkey.bind(hyper, "s", saveLayout)
hs.hotkey.bind(hyper, "d", loadLayout)
hs.hotkey.bind(hyper, "b", toggleDarkMode)
hs.hotkey.bind(hyper, "w", terminalAtFinderFolder)
hs.hotkey.bind(hyper, "tab", toggleMode)
hs.hotkey.bind(hyper, "`", showCheatsheet)
hs.hotkey.bind(hyper, "/", showCheatsheet)
hs.hotkey.bind(hyper, "escape", reloadConfigs)
hs.hotkey.bind(hyper, "0", reloadConfigs)

if currentMode == "left" then
  hs.hotkey.bind(hyper, "5", function() hs.execute("open 'raycast://extensions/raycast/menu-bar/search-menu-bar'") end)
  hs.hotkey.bind(hyper, "4", cycleCurrentAppWindow)
  hs.hotkey.bind(hyper, "q", function() changeVolume(5) end)
  hs.hotkey.bind(hyper, "z", function() changeVolume(-5) end)
  hs.hotkey.bind(hyper, "1", function() changeBrightness(-5) end)
  hs.hotkey.bind(hyper, "2", function() changeBrightness(5) end)
  bindScroll({ "ctrl", "alt" }, "w", 0, 4)
  bindScroll({ "ctrl", "alt" }, "s", 0, -4)
  bindScroll({ "ctrl", "alt" }, "a", -4, 0)
  bindScroll({ "ctrl", "alt" }, "d", 4, 0)
  hs.hotkey.bind(hyper, "x", function() afterModifiersRelease(enterSnapLayer) end)
  hs.hotkey.bind(hyper, "3", function()
    if activeLayer and activeLayer.name == "navigation" then
      closeLayer()
    else
      afterModifiersRelease(function()
        enterNavigationLayer("navigation", { w = "up", a = "left", s = "down", d = "right" }, "W/A/S/D")
      end)
    end
  end)
else
  hs.hotkey.bind(hyper, "m", function() hs.execute("open 'raycast://extensions/raycast/menu-bar/search-menu-bar'") end)
  hs.hotkey.bind(hyper, "n", cycleCurrentAppWindow)
  hs.hotkey.bind(hyper, "up", function() changeVolume(5) end)
  hs.hotkey.bind(hyper, "down", function() changeVolume(-5) end)
  hs.hotkey.bind(hyper, "left", function() changeBrightness(-5) end)
  hs.hotkey.bind(hyper, "right", function() changeBrightness(5) end)
  bindScroll({ "ctrl", "alt" }, "up", 0, 4)
  bindScroll({ "ctrl", "alt" }, "down", 0, -4)
  bindScroll({ "ctrl", "alt" }, "left", -4, 0)
  bindScroll({ "ctrl", "alt" }, "right", 4, 0)
  hs.hotkey.bind(hyper, "x", function() afterModifiersRelease(enterDualSnapLayer) end)
  hs.hotkey.bind(hyper, "3", function()
    if activeLayer and activeLayer.name == "dual-navigation" then
      closeLayer()
    else
      afterModifiersRelease(function()
        enterNavigationLayer("dual-navigation", { h = "left", j = "down", k = "up", l = "right" }, "H/J/K/L")
      end)
    end
  end)
  local dualSnapUnits = {
    h = SNAP_UNITS.left, j = SNAP_UNITS.bottom, k = SNAP_UNITS.top, l = SNAP_UNITS.right,
    u = SNAP_UNITS.topLeft, i = SNAP_UNITS.topRight,
    o = SNAP_UNITS.bottomLeft, p = SNAP_UNITS.bottomRight,
    [";"] = SNAP_UNITS.maximize, ["'"] = SNAP_UNITS.center,
  }
  for key, unit in pairs(dualSnapUnits) do
    hs.hotkey.bind(hyper, key, function() snapFocusedWindow(unit) end)
  end
end

-- Screen changes invalidate all absolute-grid and transient-layer state.
local screenWatcher = nil
if hs.screen.watcher then
  screenWatcher = hs.screen.watcher.new(closeTransient)
  screenWatcher:start()
end

-- Keep existing modest skhd-log maintenance without making it a keyboard hook.
local LOG_PATHS = { "/tmp/skhd_droy-.err.log", "/tmp/skhd_droy-.out.log" }
hs.timer.doEvery(1800, function()
  for _, path in ipairs(LOG_PATHS) do
    local attributes = hs.fs.attributes(path)
    if attributes and attributes.size and attributes.size > 100 * 1024 then
      local file = io.open(path, "w")
      if file then file:close() end
    end
  end
end)

configureMenubar()

return {
  getMode = function() return currentMode end,
  setMode = setMode,
  showCheatsheet = showCheatsheet,
  gridShow = gridShow,
  gridHide = gridHide,
  openAppSwitcher = openAppSwitcher,
  debugStatus = function()
    return { mode = currentMode, layer = activeLayer and activeLayer.name or nil, grid = gridState ~= nil }
  end,
  -- Retain the watcher so it cannot be garbage-collected.
  _screenWatcher = screenWatcher,
}
