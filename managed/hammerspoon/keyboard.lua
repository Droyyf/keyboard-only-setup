-- Keyboard-only enhancement layer. Loaded by init.lua with require("keyboard").
-- Hyper is Caps Lock after the Raycast remap: cmd+alt+ctrl+shift.

local hyper = { "cmd", "alt", "ctrl", "shift" }
local home = os.getenv("HOME") or ""
local MODE_FILE = home .. "/.config/keyboard-mode"
local MODE_HELPER = home .. "/.config/skhd/set-keyboard-mode.py"
local WINDOW_HELPER = home .. "/.config/skhd/win-dir.sh"
local YABAI_HELPER = home .. "/.config/skhd/yabai-run.sh"

local function firstExisting(paths)
  for _, path in ipairs(paths) do
    if hs.fs and hs.fs.attributes and hs.fs.attributes(path) then
      return path
    end
  end
  return paths[1]
end

local YABAI = firstExisting({
  home .. "/.local/src/yabai-macos27/bin/yabai",
  home .. "/dev/yabai-macos27/bin/yabai",
})

local function readMode()
  local file = io.open(MODE_FILE, "r")
  if file then
    local mode = file:read("*l")
    file:close()
    if mode == "dual" or mode == "left" then return mode end
  end
  return "left"
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

local function screenFrame(screen)
  local raw = screen and screen:frame()
  if not raw then return nil end
  return { x = raw.x or 0, y = raw.y or 0, w = raw.w or 0, h = raw.h or 0 }
end

local function hudColors()
  local dark = true
  pcall(function()
    if hs.host and hs.host.interfaceStyle then
      dark = hs.host.interfaceStyle() ~= "Light"
    end
  end)
  if dark then
    return {
      background = { red = 0.10, green = 0.11, blue = 0.14, alpha = 0.97 },
      primary = { red = 0.97, green = 0.98, blue = 1.0, alpha = 1 },
      secondary = { red = 0.72, green = 0.76, blue = 0.83, alpha = 1 },
      accent = { red = 0.29, green = 0.69, blue = 0.58, alpha = 1 },
      border = { red = 0.78, green = 0.83, blue = 0.89, alpha = 0.20 },
    }
  end
  return {
    background = { red = 0.96, green = 0.97, blue = 0.99, alpha = 0.98 },
    primary = { red = 0.08, green = 0.09, blue = 0.12, alpha = 1 },
    secondary = { red = 0.31, green = 0.35, blue = 0.42, alpha = 1 },
    accent = { red = 0.10, green = 0.47, blue = 0.39, alpha = 1 },
    border = { red = 0.12, green = 0.16, blue = 0.22, alpha = 0.16 },
  }
end

local function hudLevel(name)
  local levels = hs.canvas and hs.canvas.windowLevels
  if type(levels) == "table" then
    if name and levels[name] then return levels[name] end
    return levels.overlay or levels.floating or levels.screenSaver
  end
  return 102
end

local function configureHudCanvas(canvas, frame, levelName)
  pcall(function() canvas:frame(frame) end)
  pcall(function() canvas:level(hudLevel(levelName)) end)
  pcall(function()
    local behaviors = hs.canvas.windowBehaviors
    if type(behaviors) ~= "table" then return end
    local value = 0
    if behaviors.canJoinAllSpaces then value = value + behaviors.canJoinAllSpaces end
    if behaviors.stationary then value = value + behaviors.stationary end
    if value ~= 0 then canvas:behavior(value) end
  end)
  pcall(function() canvas:clickActivating(false) end)
  pcall(function() canvas:alpha(1) end)
  return canvas
end

local function newHudCanvas(frame, levelName)
  local canvas = hs.canvas.new(frame)
  return configureHudCanvas(canvas, frame, levelName)
end

-- --------------------------------------------------------------------------
-- Transient keyboard layers. They only bind unmodified letters while a layer
-- is active, so ordinary text input is never globally captured.
-- --------------------------------------------------------------------------
local activeLayer = nil
local layerKeys = {}
local layerTimer = nil
local layerCanvas = nil
local layerAlert = nil
local bindGeneration = 0
local transientLocked = false
local referenceCanvas = nil
local referenceKeys = {}
local referenceVisible = false
local gridHide = nil
local snapTarget = nil

local function hideLayerOverlay()
  if layerAlert then
    pcall(hs.alert.closeSpecific, layerAlert)
    layerAlert = nil
  end
  if layerCanvas then
    pcall(function() layerCanvas:hide() end)
    pcall(function() layerCanvas:delete() end)
    layerCanvas = nil
  end
end

local function clearLayerKeys()
  for _, hotkey in ipairs(layerKeys) do
    if hotkey.delete then hotkey:delete() else hotkey:disable() end
  end
  layerKeys = {}
end

local function closeLayer()
  bindGeneration = bindGeneration + 1
  if layerTimer then layerTimer:stop() end
  layerTimer = nil
  clearLayerKeys()
  hideLayerOverlay()
  snapTarget = nil
  activeLayer = nil
end

local function guardTransients()
  transientLocked = true
  hs.timer.doAfter(0.8, function() transientLocked = false end)
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
  hideLayerOverlay()
  local colors = hudColors()
  local message
  if hs.styledtext and hs.styledtext.new then
    local function styled(value, attributes)
      return hs.styledtext.new(value, attributes)
    end
    message = styled((title or "Layer") .. "\n", {
      font = { name = ".AppleSystemUIFont", size = 22 }, color = colors.primary,
    }) .. styled((subtitle or "") .. "\n\n", {
      font = { name = ".AppleSystemUIFont", size = 13 }, color = colors.secondary,
    }) .. styled(text or "", {
      font = { name = "SF Mono", size = 14 }, color = colors.primary,
    }) .. styled("\n\nESC  Dismiss", {
      font = { name = "SF Mono", size = 12 }, color = colors.accent,
    })
  else
    message = table.concat({ title or "Layer", subtitle or "", "", text or "", "", "ESC  Dismiss" }, "\n")
  end
  layerAlert = hs.alert.show(message, {
    strokeWidth = 1,
    strokeColor = colors.border,
    fillColor = colors.background,
    radius = 20,
    atScreenEdge = 0,
    fadeInDuration = 0.10,
    fadeOutDuration = 0.16,
    padding = 32,
  }, "until-closed")
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
  if activeLayer and activeLayer.name == name then
    resetLayerTimeout()
    return
  end
  if gridHide then gridHide() end
  closeLayer()
  activeLayer = { name = name }
  guardTransients()
  layerOverlay(title, subtitle, help)
  -- Raycast Hyper is Caps Lock. Binding Escape while Hyper is still down makes
  -- the Caps Lock key-up dismiss the HUD on the first press.
  local gen = bindGeneration
  hs.timer.doAfter(0.25, function()
    if gen ~= bindGeneration or not activeLayer then return end
    bindLayer({}, "escape", closeLayer)
  end)
  resetLayerTimeout()
end

-- Start on the next run-loop tick so the HUD is not created inside the Hyper
-- key callback. Do not poll modifier state: Raycast Hyper can stay "down".
local function afterModifiersRelease(start)
  hs.timer.doAfter(0, start)
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
  closeReference()
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
  if transientLocked then return end
  gridHide()
  closeLayer()
  closeReference()
end

-- --------------------------------------------------------------------------
-- Window-follow. Owned here so a fresh install does not depend on personal
-- init.lua. Hyper+End in an older init.lua is still synthesized so both
-- copies stay in sync until that block is removed.
-- --------------------------------------------------------------------------
local followEnabled = true
local lastCloseTime = 0
local CLOSE_GRACE_PERIOD = 0.5
local pullTimer = nil
local closeWatcher = nil
local appWatcher = nil

local function pullWindowToCurrentScreen()
  if hs.timer.secondsSinceEpoch() - lastCloseTime < CLOSE_GRACE_PERIOD then return end
  local app = hs.application.frontmostApplication()
  if not app then return end
  local win = app:focusedWindow() or app:mainWindow()
  if not win or not win:isStandard() or win:isFullScreen() then return end
  local currentScreen = hs.mouse.getCurrentScreen()
  if currentScreen and win:screen() ~= currentScreen then
    win:moveToScreen(currentScreen)
  end
end

local function toggleWindowFollow()
  followEnabled = not followEnabled
  showAlert(followEnabled and "Window-follow: ON" or "Window-follow: OFF")
end

local function startWindowFollow()
  if not (hs.window and hs.window.filter and hs.application and hs.application.watcher) then
    return
  end
  closeWatcher = hs.window.filter.new()
  closeWatcher:subscribe(hs.window.filter.windowDestroyed, function()
    lastCloseTime = hs.timer.secondsSinceEpoch()
  end)
  appWatcher = hs.application.watcher.new(function(_, eventType)
    if not followEnabled then return end
    if eventType == hs.application.watcher.terminated then
      lastCloseTime = hs.timer.secondsSinceEpoch()
      return
    end
    if eventType == hs.application.watcher.activated then
      if pullTimer then
        pullTimer:stop()
        pullTimer = nil
      end
      pullTimer = hs.timer.doAfter(0.15, function()
        pcall(pullWindowToCurrentScreen)
      end)
    end
  end)
  appWatcher:start()
end

-- --------------------------------------------------------------------------
-- Existing application and layout actions.
-- --------------------------------------------------------------------------
local appChooser = nil
local appChoices = {}
local appControlKeys = {}

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
  closeTransient()
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
      local choice = appChooser.selectedRowContents and appChooser:selectedRowContents()
      appChooser:hide()
      activateAppChoice(choice)
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

local function moveFocusedWindowToDisplay(direction)
  if not commandSucceeded(YABAI .. " -m window --display " .. direction) then
    showAlert("Window display move failed")
  end
end

local function runWindowHelper(operation, direction)
  if not commandSucceeded(WINDOW_HELPER .. " " .. operation .. " " .. direction) then
    showAlert("Window " .. operation .. " failed")
  end
end

local function runYabaiCommand(arguments, failureMessage)
  if not commandSucceeded(YABAI .. " " .. arguments) then showAlert(failureMessage) end
end

local function moveSpaceToOtherDisplay()
  if not commandSucceeded(YABAI_HELPER .. " --script move-space-to-other-display.sh") then
    showAlert("Space display move failed")
  end
end

local function toggleYabaiLayout()
  if not commandSucceeded(YABAI_HELPER .. " --script toggle-yabai-layout.sh") then
    showAlert("Layout toggle failed")
  end
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
  enterLayer("snap", "Snap & System", "Window placement and system controls", "A/S/W/D   Place window\nQ/E/Z/C   Quarter window\nF/R       Maximize / center\nShift+F/R Next / previous display\nT spaces   B window-follow\nV hide app G minimize\n1 Mission Control   2 hidden files")
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
  bindLayer({ "shift" }, "f", function() oneShot(function() moveFocusedWindowToDisplay("next") end) end)
  bindLayer({ "shift" }, "r", function() oneShot(function() moveFocusedWindowToDisplay("prev") end) end)
  bindLayer({}, "t", enterSpaceLayer)
  bindLayer({}, "b", function()
    oneShot(function()
      toggleWindowFollow()
      hs.eventtap.keyStroke(hyper, "end", 0)
    end)
  end)
  bindLayer({}, "v", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "h", 0) end) end)
  bindLayer({}, "g", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "m", 0) end) end)
  bindLayer({}, "1", function() oneShot(function() hs.eventtap.keyStroke({ "ctrl" }, "up", 0) end) end)
  bindLayer({}, "2", function()
    oneShot(function()
      hs.application.launchOrFocus("Finder")
      hs.timer.doAfter(0.15, function()
        hs.eventtap.keyStroke({ "cmd", "shift" }, ".", 0)
      end)
    end)
  end)
end

local function enterDualSnapLayer()
  enterLayer("dual-snap", "Snap & System", "Window placement and system controls", "H/J/K/L   Place window\nU/I/O/P   Quarter window\n;/'       Maximize / center\nShift+F/R Next / previous display\nT spaces   B window-follow\nV hide app G minimize\n1 Mission Control   2 hidden files")
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
  bindLayer({ "shift" }, "f", function() oneShot(function() moveFocusedWindowToDisplay("next") end) end)
  bindLayer({ "shift" }, "r", function() oneShot(function() moveFocusedWindowToDisplay("prev") end) end)
  bindLayer({}, "t", enterSpaceLayer)
  bindLayer({}, "b", function()
    oneShot(function()
      toggleWindowFollow()
      hs.eventtap.keyStroke(hyper, "end", 0)
    end)
  end)
  bindLayer({}, "v", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "h", 0) end) end)
  bindLayer({}, "g", function() oneShot(function() hs.eventtap.keyStroke({ "cmd" }, "m", 0) end) end)
  bindLayer({}, "1", function() oneShot(function() hs.eventtap.keyStroke({ "ctrl" }, "up", 0) end) end)
  bindLayer({}, "2", function()
    oneShot(function()
      hs.application.launchOrFocus("Finder")
      hs.timer.doAfter(0.15, function()
        hs.eventtap.keyStroke({ "cmd", "shift" }, ".", 0)
      end)
    end)
  end)
end

local function persistentKey(sourceKey, targetKey, modifiers)
  bindLayer({}, sourceKey, function() hs.eventtap.keyStroke(modifiers or {}, targetKey, 0) end, true)
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

local showCheatsheet

-- --------------------------------------------------------------------------
-- Action Hub. Hyper+/ opens this route to every workflow action; the direct
-- shortcuts below remain the fast path. Each leaf calls its established owner
-- (Hammerspoon, yabai, or the skhd helper) instead of replaying a hotkey.
-- --------------------------------------------------------------------------
local function enterAppsActions()
  local menuKey = currentMode == "left" and "5" or "m"
  local nextWindowKey = currentMode == "left" and "4" or "n"
  enterLayer("workflow-apps", "Apps", "Launch, restore, minimize, and search", "A Arc   C ChatGPT   F Finder   T kitty\nR running apps   Space Raycast   V clipboard\n" .. menuKey:upper() .. " menu search   " .. nextWindowKey:upper() .. " next app window\nE window hints   G mouse grid   Q Shortcat")
  for key, applicationSpec in pairs(launchTable) do
    bindLayer({}, key, function() oneShot(function() focusOrLaunchApplication(applicationSpec) end) end)
  end
  bindLayer({}, "r", function() oneShot(openAppSwitcher) end)
  bindLayer({}, "space", function() oneShot(function() hs.execute("open 'raycast://'") end) end)
  bindLayer({}, "v", function() oneShot(function() hs.execute("open 'raycast://extensions/raycast/clipboard-history'") end) end)
  bindLayer({}, menuKey, function() oneShot(function()
    hs.execute("open 'raycast://extensions/raycast/menu-bar/search-menu-bar'")
  end) end)
  bindLayer({}, nextWindowKey, function() oneShot(cycleCurrentAppWindow) end)
  bindLayer({}, "e", function() oneShot(showHints) end)
  bindLayer({}, "g", function() oneShot(gridShow) end)
  bindLayer({}, "q", function() oneShot(function() hs.eventtap.keyStroke({ "cmd", "shift" }, "space", 0) end) end)
end

local function enterWindowActions()
  local directions = currentMode == "left"
    and { a = "west", s = "south", w = "north", d = "east" }
    or { h = "west", j = "south", k = "north", l = "east" }
  local directionKeys = currentMode == "left" and "A/S/W/D" or "H/J/K/L"
  enterLayer("workflow-windows", "Windows", "Focus, move, resize, snap, and move between displays", directionKeys .. " focus   Shift+" .. directionKeys .. " move/swap\nFn+" .. directionKeys .. " resize   Q next window\nF fullscreen   R float   Shift+F/R next/previous display\nZ/V next/previous Space   X Space to other display\nT float/BSP layout   B snap and system")
  for key, direction in pairs(directions) do
    bindLayer({}, key, function() oneShot(function() runWindowHelper("focus", direction) end) end)
    bindLayer({ "shift" }, key, function() oneShot(function() runWindowHelper("move", direction) end) end)
    bindLayer({ "fn" }, key, function() oneShot(function() runWindowHelper("resize", direction) end) end)
  end
  bindLayer({}, "q", function() oneShot(function() runYabaiCommand("-m window --focus next", "Window focus failed") end) end)
  bindLayer({}, "f", function() oneShot(function() runYabaiCommand("-m window --toggle zoom-fullscreen", "Window fullscreen failed") end) end)
  bindLayer({}, "r", function() oneShot(function() runYabaiCommand("-m window --toggle float", "Window float toggle failed") end) end)
  bindLayer({ "shift" }, "f", function() oneShot(function() moveFocusedWindowToDisplay("next") end) end)
  bindLayer({ "shift" }, "r", function() oneShot(function() moveFocusedWindowToDisplay("prev") end) end)
  bindLayer({}, "z", function() oneShot(function() runYabaiCommand("-m space --focus next", "Space command failed") end) end)
  bindLayer({}, "v", function() oneShot(function() runYabaiCommand("-m space --focus prev", "Space command failed") end) end)
  bindLayer({}, "x", function() oneShot(moveSpaceToOtherDisplay) end)
  bindLayer({}, "t", function() oneShot(toggleYabaiLayout) end)
  bindLayer({}, "b", function()
    if currentMode == "left" then enterSnapLayer() else enterDualSnapLayer() end
  end)
end

local function enterSystemActions()
  enterLayer("workflow-system", "System", "Audio, display, scrolling, and appearance", "Q/Z volume up/down   1/2 brightness down/up\nW/A/S/D scroll up/left/down/right\nB toggle dark appearance")
  bindLayer({}, "q", function() oneShot(function() changeVolume(5) end) end)
  bindLayer({}, "z", function() oneShot(function() changeVolume(-5) end) end)
  bindLayer({}, "1", function() oneShot(function() changeBrightness(-5) end) end)
  bindLayer({}, "2", function() oneShot(function() changeBrightness(5) end) end)
  bindLayer({}, "w", function() scrollBy(0, 4) end, true)
  bindLayer({}, "a", function() scrollBy(-4, 0) end, true)
  bindLayer({}, "s", function() scrollBy(0, -4) end, true)
  bindLayer({}, "d", function() scrollBy(4, 0) end, true)
  bindLayer({}, "b", function() oneShot(toggleDarkMode) end)
end

local function enterNavigationActions()
  if currentMode == "left" then
    enterNavigationLayer("navigation", { w = "up", a = "left", s = "down", d = "right" }, "W/A/S/D")
  else
    enterNavigationLayer("dual-navigation", { h = "left", j = "down", k = "up", l = "right" }, "H/J/K/L")
  end
end

local function enterUtilitiesActions()
  enterLayer("workflow-utilities", "Utilities", "Save, restore, switch modes, and recover", "S save layout   D restore layout   W kitty at Finder folder\nB toggle window-follow   Tab switch 2H/LH\nR reload configuration   ` complete reference")
  bindLayer({}, "s", function() oneShot(saveLayout) end)
  bindLayer({}, "d", function() oneShot(loadLayout) end)
  bindLayer({}, "w", function() oneShot(terminalAtFinderFolder) end)
  bindLayer({}, "b", function() oneShot(toggleWindowFollow) end)
  bindLayer({}, "tab", function() oneShot(toggleMode) end)
  bindLayer({}, "r", function() oneShot(reloadConfigs) end)
  bindLayer({}, "`", function() oneShot(showCheatsheet) end)
end

local function enterWorkflowHub()
  enterLayer("workflow", "Workflow actions", "Choose an area; direct shortcuts always remain available", "A apps          S windows\nW Spaces        D system\nF navigation    R utilities\n\n` complete reference")
  bindLayer({}, "a", enterAppsActions)
  bindLayer({}, "s", enterWindowActions)
  bindLayer({}, "w", enterSpaceLayer)
  bindLayer({}, "d", enterSystemActions)
  bindLayer({}, "f", enterNavigationActions)
  bindLayer({}, "r", enterUtilitiesActions)
  bindLayer({}, "`", function() oneShot(showCheatsheet) end)
end

local function openWorkflowHub()
  if activeLayer and activeLayer.name == "workflow" then
    closeLayer()
  else
    closeReference()
    afterModifiersRelease(enterWorkflowHub)
  end
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

function showCheatsheet()
  if referenceVisible then
    closeReference()
    return
  end
  gridHide()
  closeLayer()
  local text, modeName
  if currentMode == "left" then
    modeName = "Left hand workflow"
    text = [[
APPS  A Arc   C ChatGPT   F Finder   T kitty   R running apps   Space Raycast
CORE  5 menu   E hints   4 next app window   V clipboard   G mouse grid   Tab mode
HUB  Hyper+/ executable actions   Hyper+` complete reference
LAYERS  X snap and system   X then T Spaces   3 navigation
WINDOWS  Option+A/S/W/D focus   Shift+Option+A/S/W/D move   Fn+A/S/W/D resize
DISPLAYS  X then Shift+F/R next/previous display
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
HUB  Hyper+/ executable actions   Hyper+` complete reference
LAYERS  X snap and system   X then T Spaces   3 navigation
WINDOWS  Option+H/J/K/L focus   Shift+Option+H/J/K/L move   Fn+H/J/K/L resize
DISPLAYS  X then Shift+F/R next/previous display
SNAP  Hyper+H/J/K/L halves   Hyper+U/I/O/P quarters   Hyper+; maximize   Hyper+' center
SPACES  Option+1–9 focus   Shift+Option+1–9 send   Option+Z/V cycle
SYSTEM  Hyper+arrows volume and brightness   Ctrl+Option+arrows scroll
OTHER  S/D layouts   B appearance   W Finder terminal   Esc reload
NAVIGATION  H/J/K/L arrows   Shift select   Q delete   E Return   R Tab
Shortcat: Command+Shift+Space, type a hint, then Return
]]
  end
  local screen = hs.mouse.getCurrentScreen() or hs.screen.mainScreen() or (hs.screen.primaryScreen and hs.screen.primaryScreen())
  local frame = screenFrame(screen)
  if not frame then return end
  local width = math.max(620, math.min(940, frame.w - 64))
  local height = math.max(480, math.min(660, frame.h - 64))
  local x = math.max(24, math.floor((frame.w - width) / 2))
  local y = math.max(24, math.floor((frame.h - height) / 2))
  local colors = hudColors()
  if referenceCanvas then
    pcall(function() referenceCanvas:delete() end)
    referenceCanvas = nil
  end
  referenceCanvas = newHudCanvas(frame)
  if not referenceCanvas then return end
  referenceCanvas:replaceElements({
    { type = "rectangle", action = "fill", frame = { x = x, y = y, w = width, h = height }, fillColor = colors.background, roundedRectRadii = { xRadius = 16, yRadius = 16 } },
    { type = "rectangle", action = "fill", frame = { x = x + 28, y = y + 28, w = 5, h = 50 }, fillColor = { red = 0.30, green = 0.60, blue = 1.0, alpha = 1 }, roundedRectRadii = { xRadius = 2, yRadius = 2 } },
    { type = "text", text = modeName, frame = { x = x + 50, y = y + 24, w = width - 190, h = 28 }, textSize = 21, textColor = colors.primary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = "Complete shortcut reference", frame = { x = x + 50, y = y + 51, w = width - 190, h = 22 }, textSize = 13, textColor = colors.secondary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = "Hyper+`  Close", frame = { x = x + width - 170, y = y + 35, w = 138, h = 20 }, textSize = 12, textColor = colors.secondary, textFont = ".AppleSystemUIFont" },
    { type = "text", text = text, frame = { x = x + 34, y = y + 108, w = width - 68, h = height - 142 }, textSize = 15, textColor = colors.primary, textFont = ".AppleSystemUIFont" },
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
hs.hotkey.bind(hyper, "/", openWorkflowHub)
hs.hotkey.bind(hyper, "escape", reloadConfigs)

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
  hs.hotkey.bind(hyper, "0", reloadConfigs)
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

configureMenubar()
startWindowFollow()

return {
  getMode = function() return currentMode end,
  setMode = setMode,
  showCheatsheet = showCheatsheet,
  openWorkflowHub = openWorkflowHub,
  gridShow = gridShow,
  gridHide = gridHide,
  openAppSwitcher = openAppSwitcher,
  toggleWindowFollow = toggleWindowFollow,
  debugStatus = function()
    return { mode = currentMode, layer = activeLayer and activeLayer.name or nil, grid = gridState ~= nil, follow = followEnabled }
  end,
  -- Retain watchers so they cannot be garbage-collected.
  _screenWatcher = screenWatcher,
  _appWatcher = appWatcher,
  _closeWatcher = closeWatcher,
}
