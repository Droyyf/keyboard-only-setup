-- Keyboard-only enhancement layer. Loaded by init.lua with require("keyboard").
-- Hyper is Caps Lock after the Raycast remap: cmd+alt+ctrl+shift.
--
-- Design:
--   * Data-driven registry: every layer HUD, the Action Hub, and the complete
--     reference are generated from one registry per mode. Changing a shortcut
--     entry updates every HUD automatically; HUD code is never hand-edited.
--   * Hyper-held HUD: visual menus are visible only while Hyper (Caps Lock)
--     is held. A keyDown eventtap routes plain keys to the open menu while
--     Hyper is down, so actions execute with the pressed Hyper key itself —
--     no extra Shift/Fn chords and no releasing Caps Lock first. Releasing
--     Hyper closes every menu. The mouse grid follows the same rule.
--   * Pickers that need typed input after the release (running-app switcher,
--     window hints) intentionally stay open; they dismiss themselves.

local hyper = { "cmd", "alt", "ctrl", "shift" }
local home = os.getenv("HOME") or ""
local MODE_FILE = home .. "/.config/keyboard-mode"
local MODE_HELPER = home .. "/.config/skhd/set-keyboard-mode.py"
local WINDOW_HELPER = home .. "/.config/skhd/win-dir.sh"
local DISPLAY_CYCLE_HELPER = home .. "/.config/skhd/cycle-window-display.sh"
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
local defaultHintChars = hs.hints.hintChars
local menubar = nil

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

local function logWorkflowError(message)
  if hs.printf then
    hs.printf("%s", message)
  else
    print(message)
  end
end

local function screenFrame(screen)
  local raw = screen and screen:frame()
  if not raw then return nil end
  return { x = raw.x or 0, y = raw.y or 0, w = raw.w or 0, h = raw.h or 0 }
end

-- ---------------------------------------------------------------------------
-- HUD look: flat, smooth, translucent panels that follow the system
-- appearance and the macOS accent colour, for both hand modes.
-- ---------------------------------------------------------------------------
local ACCENT_PRESETS = {
  [-1] = { red = 0.55, green = 0.55, blue = 0.58 },          -- graphite
  [0] = { red = 1.0, green = 0.27, blue = 0.23 },            -- red
  [1] = { red = 1.0, green = 0.55, blue = 0.15 },            -- orange
  [2] = { red = 1.0, green = 0.80, blue = 0.10 },            -- yellow
  [3] = { red = 0.30, green = 0.80, blue = 0.35 },           -- green
  [4] = { red = 0.10, green = 0.50, blue = 1.0 },            -- blue
  [5] = { red = 0.70, green = 0.40, blue = 0.95 },           -- purple
  [6] = { red = 1.0, green = 0.45, blue = 0.70 },            -- pink
}
local cachedAccent = nil

local function systemAccent()
  if cachedAccent then return cachedAccent end
  local accent = ACCENT_PRESETS[4]
  pcall(function()
    local value = hs.execute("defaults read -g AppleAccentColor 2>/dev/null"):gsub("%s+", "")
    local number = tonumber(value)
    if number then accent = ACCENT_PRESETS[number] or accent end
  end)
  cachedAccent = accent
  return accent
end

local function systemDark()
  local dark = true
  pcall(function()
    if hs.host and hs.host.interfaceStyle then
      dark = hs.host.interfaceStyle() ~= "Light"
    end
  end)
  return dark
end

local function hudColors()
  local accent = systemAccent()
  if systemDark() then
    return {
      dark = true,
      panel = { red = 0, green = 0, blue = 0, alpha = 1 },
      primary = { red = 0.97, green = 0.98, blue = 1.0, alpha = 1 },
      secondary = { red = 0.74, green = 0.77, blue = 0.83, alpha = 1 },
      accent = accent,
      accentFaint = { red = accent.red, green = accent.green, blue = accent.blue, alpha = 0.16 },
      selection = { red = 0.14, green = 0.14, blue = 0.16, alpha = 1 },
      gridOverlay = { red = 0, green = 0, blue = 0, alpha = 0.22 },
    }
  end
  return {
    dark = false,
    panel = { red = 0.98, green = 0.96, blue = 0.91, alpha = 1 },
    primary = { red = 0.10, green = 0.11, blue = 0.14, alpha = 1 },
    secondary = { red = 0.34, green = 0.37, blue = 0.44, alpha = 1 },
    accent = accent,
    accentFaint = { red = accent.red, green = accent.green, blue = accent.blue, alpha = 0.14 },
    selection = { red = 0.90, green = 0.87, blue = 0.80, alpha = 1 },
    gridOverlay = { red = 0.98, green = 0.96, blue = 0.91, alpha = 0.22 },
  }
end

-- ---------------------------------------------------------------------------
-- Key codes. The HUD router maps raw key codes to names so layer keys can be
-- consumed while Hyper is held (a plain hs.hotkey cannot fire then).
-- ---------------------------------------------------------------------------
local KEY_CODES = {
  ["a"] = 0, ["s"] = 1, ["d"] = 2, ["f"] = 3, ["h"] = 4, ["g"] = 5, ["z"] = 6,
  ["x"] = 7, ["c"] = 8, ["v"] = 9, ["b"] = 11, ["q"] = 12, ["w"] = 13,
  ["e"] = 14, ["r"] = 15, ["y"] = 16, ["t"] = 17, ["o"] = 31, ["u"] = 32,
  ["i"] = 34, ["p"] = 35, ["l"] = 37, ["j"] = 38, ["k"] = 40, ["n"] = 45,
  ["m"] = 46,
  ["1"] = 18, ["2"] = 19, ["3"] = 20, ["4"] = 21, ["6"] = 22, ["5"] = 23,
  ["="] = 24, ["9"] = 25, ["7"] = 26, ["-"] = 27, ["8"] = 28, ["0"] = 29,
  ["]"] = 30, ["["] = 33, ["'"] = 39, [";"] = 41, ["\\"] = 42, [","] = 43,
  ["/"] = 44, ["."] = 47, ["`"] = 50,
  tab = 48, space = 49, escape = 53, ["return"] = 36, delete = 51,
  forwarddelete = 117, up = 126, down = 125, left = 123, right = 124,
  pageup = 116, pagedown = 121, ["end"] = 119, home = 115,
}
local KEY_NAMES = {}
for name, code in pairs(KEY_CODES) do KEY_NAMES[code] = name end

local KEY_DISPLAY = {
  escape = "ESC", space = "SPACE", tab = "TAB", delete = "⌫",
  forwarddelete = "DEL", ["return"] = "RET", pageup = "PGUP",
  pagedown = "PGDN", ["end"] = "END", home = "HOME",
}

local function keyDisplay(name)
  if KEY_DISPLAY[name] then return KEY_DISPLAY[name] end
  if #name == 1 then return name:upper() end
  return name:upper()
end

local function hyperIsDown(flags)
  return flags ~= nil and flags.cmd == true and flags.alt == true
    and flags.ctrl == true and flags.shift == true
end

-- ---------------------------------------------------------------------------
-- HUD state. One shared lifecycle for layers, the reference, and the grid.
-- ---------------------------------------------------------------------------
local activeLayer = nil          -- { id = ..., def = ..., keys = { [key] = fn } }
local layerState = {}            -- per-layer toggles (move/resize/send/select)
local referenceVisible = false
local referencePage = 1
local referencePageCount = 1
local hintsVisible = false
local hintWindowIDs = nil
local gridState = nil            -- assigned by the mouse-grid section below
local layerCanvas = nil
local referenceCanvas = nil
local layerCanvasFrame = nil
local referenceCanvasFrame = nil
local layerDisplayContext = nil
local referenceDisplayContext = nil
local hudMetrics = {
  layerCanvasCreated = 0, layerCanvasReused = 0,
  referenceCanvasCreated = 0, referenceCanvasReused = 0,
  layerRedraws = 0, referenceRedraws = 0,
  actionErrors = 0, renderErrors = 0,
}
local hudTimer = nil
local directHotkeys = {}         -- Carbon fallback bindings; callbacks are guarded while a HUD is open
local directActions = {}         -- eventtap-owned first-key dispatch by key name
local hudSwitchActions = {}      -- top-level HUD identifiers available inside every open HUD
local hyperDown = false
local snapTarget = nil
local gridHide = nil             -- assigned by the mouse-grid section below
local gridKey = nil              -- assigned by the mouse-grid section below
local closeAllHuds = nil         -- defined below; used by timer and eventtap
local renderReference = nil      -- defined after the registry-backed layout helpers
local refreshLayer = nil         -- redraws keyboard selection inside an open layer
local closeWindowHints = nil     -- defined with the window-hints action
local openAppSwitcher = nil      -- defined after the generic layer opener
local authorizeWindowFollow = nil -- defined by the intent-gated follow section
local authorizeHintSelection = nil
local HUD_CANVAS_LEVEL = (hs.canvas and hs.canvas.windowLevels
  and (hs.canvas.windowLevels.assistiveTechHigh or hs.canvas.windowLevels.screenSaver)) or 1500

local function anyHudOpen()
  return activeLayer ~= nil or referenceVisible or hintsVisible or gridState ~= nil
end

local function syncDirectHotkeys()
  -- Keep Carbon hotkeys registered for the full key-down/key-up transaction.
  -- Disabling the shortcut from inside its own pressed callback can cancel the
  -- first Raycast Hyper chord. bindDirect guards callbacks while a HUD owns
  -- subsequent keys, so registration itself does not need to change.
  for _, hotkey in ipairs(directHotkeys) do
    if hotkey.enable then hotkey:enable() end
  end
end

local function stopHudTimer()
  if hudTimer then hudTimer:stop() end
  hudTimer = nil
end

local function resetHudTimeout()
  stopHudTimer()
  hudTimer = hs.timer.doAfter(15, function()
    -- Safety net in case a Hyper release event is ever lost.
    closeAllHuds()
  end)
end

local function hideLayerOverlay()
  if layerCanvas then
    pcall(function() layerCanvas:hide() end)
  end
end

local function closeLayer()
  activeLayer = nil
  layerState = {}
  hideLayerOverlay()
  syncDirectHotkeys()
end

local function closeReference()
  referenceVisible = false
  referencePage = 1
  if referenceCanvas then
    pcall(function() referenceCanvas:hide() end)
  end
  syncDirectHotkeys()
end

closeAllHuds = function()
  stopHudTimer()
  if closeWindowHints then closeWindowHints() end
  if gridHide then gridHide() end
  closeReference()
  closeLayer()
end

local function runAction(action, label)
  local ok, err = xpcall(action, debug.traceback)
  if ok then return true end
  hudMetrics.actionErrors = hudMetrics.actionErrors + 1
  logWorkflowError("keyboard workflow action failed [" .. tostring(label or "unknown") .. "]: " .. tostring(err))
  showAlert("Shortcut failed: " .. tostring(label or "action"), 1.8)
  return false
end

local function routeHudKey(name)
  if referenceVisible then
    if name == "escape" or name == "`" then closeReference() end
    if name == "[" or name == "left" or name == "up" then
      referencePage = ((referencePage - 2) % referencePageCount) + 1
      if renderReference then renderReference() end
    elseif name == "]" or name == "right" or name == "down" or name == "tab" then
      referencePage = (referencePage % referencePageCount) + 1
      if renderReference then renderReference() end
    end
    return
  end
  if hintsVisible then
    if name == "escape" then
      closeWindowHints()
    elseif #name == 1 and name:match("%a") then
      if authorizeHintSelection then authorizeHintSelection() end
      local character = currentMode == "left" and name or name:upper()
      hs.hints.processChar(character)
    end
    return
  end
  if gridState then
    if name == "escape" then
      gridHide()
    elseif gridKey then
      gridKey(name)
    end
    return
  end
  if activeLayer then
    if name == "escape" then
      closeLayer()
      return
    end
    local count = #activeLayer.order
    local rows = math.ceil(count / 2)
    local selected = activeLayer.selected or 1
    local columnStart = selected <= rows and 1 or rows + 1
    local columnEnd = selected <= rows and rows or count
    if name == "up" then
      activeLayer.selected = selected == columnStart and columnEnd or selected - 1
      refreshLayer()
      return
    elseif name == "down" then
      activeLayer.selected = selected == columnEnd and columnStart or selected + 1
      refreshLayer()
      return
    elseif name == "left" then
      activeLayer.selected = selected <= rows and math.min(count, selected + rows) or selected - rows
      refreshLayer()
      return
    elseif name == "right" then
      activeLayer.selected = selected <= rows and math.min(count, selected + rows) or selected - rows
      refreshLayer()
      return
    elseif name == "tab" then
      activeLayer.selected = selected % count + 1
      refreshLayer()
      return
    elseif name == "return" then
      local selectedItem = activeLayer.order[selected]
      if selectedItem and selectedItem.action then runAction(selectedItem.action, selectedItem.label) end
      return
    end
    local item = nil
    for _, candidate in ipairs(activeLayer.order) do
      if candidate.key == name then item = candidate; break end
    end
    if item and item.action then runAction(item.action, item.label) end
  end
end

local function handleHudEvent(event)
  local types = hs.eventtap.event.types
  local eventType = event:getType()
  if eventType == types.flagsChanged then
    local down = hyperIsDown(event:getFlags())
    if down then
      hyperDown = true
    elseif hyperDown then
      hyperDown = false
      if anyHudOpen() then closeAllHuds() end
    end
    return false
  end
  local name = KEY_NAMES[event:getKeyCode()]
  if not name then return false end
  if eventType == types.keyUp then return anyHudOpen() end
  local flags = event:getFlags()
  if name == "tab" and flags.cmd and not flags.alt and not flags.ctrl and not flags.shift then
    if authorizeWindowFollow then authorizeWindowFollow(nil, nil, 3, nil, "command-tab") end
    return false
  end
  if hyperIsDown(flags) then
    hyperDown = true
    if anyHudOpen() then
      resetHudTimeout()
      local switchAction = hudSwitchActions[name]
      if switchAction then
        runAction(switchAction, "open HUD")
        return true
      end
      routeHudKey(name)
      return true
    end
    local action = directActions[name]
    if action then
      runAction(action.action, action.label)
      return true
    end
    return false
  end
  if anyHudOpen() then
    -- Modifier state was lost (the Raycast Hyper key can report a stuck-down
    -- state). Treat any unaccompanied key as a release so no HUD outlives the
    -- pressed Hyper key.
    closeAllHuds()
  end
  return false
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

local function newHudCanvas(frame)
  local canvas = hs.canvas.new(frame)
  return configureHudCanvas(canvas, frame, "assistiveTechHigh")
end

local REGISTRY = nil          -- built once at load, per hand mode
local directGroups = {}       -- ordered reference groups fed by bindDirect()

local function addDirectReference(key, label, group)
  for _, entry in ipairs(directGroups) do
    if entry.name == group then
      table.insert(entry.items, { key = key, label = label })
      return
    end
  end
  table.insert(directGroups, { name = group, items = { { key = key, label = label } } })
end

-- ---------------------------------------------------------------------------
-- Panel renderer shared by layer HUDs, the Action Hub, and the reference.
-- ---------------------------------------------------------------------------
local function panelElements(colors, x, y, w, h)
  local panel = {
    type = "rectangle", action = "strokeAndFill",
    frame = { x = x, y = y, w = w, h = h },
    fillColor = colors.panel,
    strokeColor = colors.dark
      and { white = 0.18, alpha = 1 }
      or { white = 0.80, alpha = 1 },
    strokeWidth = 1,
    roundedRectRadii = { xRadius = 20, yRadius = 20 },
  }
  return { panel }
end

local function showCanvas(canvas, elements)
  local ok, err = pcall(function() canvas:replaceElements(elements) end)
  if not ok then
    -- Drop decorative attributes rather than losing the whole HUD.
    for _, element in ipairs(elements) do
      element.shadow = nil
      element.textLineBreak = nil
    end
    ok, err = pcall(function() canvas:replaceElements(elements) end)
  end
  if not ok then
    hudMetrics.renderErrors = hudMetrics.renderErrors + 1
    logWorkflowError("keyboard workflow HUD rendering failed: " .. tostring(err))
    pcall(function() canvas:hide() end)
    showAlert("HUD rendering failed", 1.8)
    return false
  end
  canvas:show()
  return true
end

local function badgeWidth(label)
  return math.max(36, 18 + 11 * #label)
end

local function appendKeyRow(elements, colors, item, x, y, width, spacing, selected)
  local badge = keyDisplay(item.key)
  local bw = badgeWidth(badge)
  local rowH = spacing or 32
  local badgeH = math.min(24, rowH - 6)
  if selected then
    elements[#elements + 1] = {
      type = "rectangle", action = "strokeAndFill",
      frame = { x = x - 8, y = y - 2, w = width + 16, h = rowH - 2 },
      fillColor = colors.selection,
      strokeColor = colors.accent,
      strokeWidth = 2,
      roundedRectRadii = { xRadius = 8, yRadius = 8 },
    }
  end
  elements[#elements + 1] = {
    type = "rectangle", action = "fill",
    frame = { x = x, y = y, w = bw, h = badgeH },
    fillColor = colors.accentFaint,
    roundedRectRadii = { xRadius = 6, yRadius = 6 },
  }
  elements[#elements + 1] = {
    type = "text", text = badge,
    frame = { x = x, y = y, w = bw, h = badgeH },
    textSize = 12, textColor = colors.accent,
    textFont = ".AppleSystemUIFont", textAlignment = "center",
  }
  elements[#elements + 1] = {
    type = "text", text = selected and "› " .. item.label or item.label,
    frame = { x = x + bw + 12, y = y + (badgeH - 16) / 2, w = math.max(60, width - bw - 12), h = 18 },
    textSize = 13, textColor = colors.primary,
    textFont = ".AppleSystemUIFont", textLineBreak = "truncateTail",
  }
end

local function pointerDisplayContext()
  local screen = nil
  local point = hs.mouse.absolutePosition and hs.mouse.absolutePosition() or nil
  if point and hs.screen.allScreens then
    for _, candidate in ipairs(hs.screen.allScreens()) do
      local frame = candidate:fullFrame()
      if point.x >= frame.x and point.x < frame.x + frame.w
          and point.y >= frame.y and point.y < frame.y + frame.h then
        screen = candidate
        break
      end
    end
  end
  screen = screen or hs.mouse.getCurrentScreen()
    or (hs.screen.mainScreen and hs.screen.mainScreen())
  local frame = screenFrame(screen)
  return frame and { screen = screen, frame = frame } or nil
end

local function sameFrame(left, right)
  return left and right and left.x == right.x and left.y == right.y
    and left.w == right.w and left.h == right.h
end

local function canvasForContext(canvas, context, kind)
  local currentFrame = kind == "layer" and layerCanvasFrame or referenceCanvasFrame
  if canvas and sameFrame(currentFrame, context.frame) then
    hudMetrics[kind .. "CanvasReused"] = hudMetrics[kind .. "CanvasReused"] + 1
    return canvas
  end
  if canvas then
    pcall(function() canvas:hide() end)
    pcall(function() canvas:delete() end)
  end
  canvas = newHudCanvas(context.frame)
  if kind == "layer" then
    layerCanvasFrame = context.frame
  else
    referenceCanvasFrame = context.frame
  end
  hudMetrics[kind .. "CanvasCreated"] = hudMetrics[kind .. "CanvasCreated"] + 1
  return canvas
end

local function renderLayer()
  if not activeLayer then return end
  local def = activeLayer.def
  local colors = hudColors()
  local context = layerDisplayContext or pointerDisplayContext()
  local frame = context and context.frame
  if not frame then return end

  layerDisplayContext = context
  local width = math.max(1, math.min(640, frame.w - 24))
  local items = activeLayer.order
  local pad, titleH, subH, rowH, footerH = 18, 30, 26, 30, 30
  local maximumHeight = math.max(1, frame.h - 24)
  local maximumRows = math.max(1, math.floor((maximumHeight - pad - titleH - subH - footerH) / rowH))
  local pageSize = maximumRows * 2
  local pageCount = math.max(1, math.ceil(#items / pageSize))
  local page = math.max(1, math.min(pageCount, math.ceil((activeLayer.selected or 1) / pageSize)))
  local first, last = (page - 1) * pageSize + 1, math.min(#items, page * pageSize)
  local pageItems = {}
  for index = first, last do table.insert(pageItems, { item = items[index], index = index }) end
  local rows = math.max(1, math.ceil(#pageItems / 2))
  local height = math.min(maximumHeight, pad + titleH + subH + rows * rowH + footerH)
  local x = math.floor((frame.w - width) / 2)
  local y = math.floor((frame.h - height) / 2)

  layerCanvas = canvasForContext(layerCanvas, context, "layer")
  if not layerCanvas then return end

  local elements = panelElements(colors, x, y, width, height)
  elements[#elements + 1] = {
    type = "text", text = def.title,
    frame = { x = x + pad, y = y + pad - 8, w = width - 2 * pad, h = 26 },
    textSize = 20, textColor = colors.primary, textFont = ".AppleSystemUIFont",
  }
  local subtitle = type(def.subtitle) == "function" and def.subtitle() or def.subtitle
  elements[#elements + 1] = {
    type = "text", text = subtitle or "",
    frame = { x = x + pad, y = y + pad + 22, w = width - 2 * pad, h = 18 },
    textSize = 12, textColor = colors.secondary, textFont = ".AppleSystemUIFont",
    textLineBreak = "truncateTail",
  }
  local firstColumnRows = math.ceil(#pageItems / 2)
  local columnWidth = (width - 2 * pad - 28) / 2
  for pageIndex, entry in ipairs(pageItems) do
    local column = pageIndex <= firstColumnRows and 0 or 1
    local row = column == 0 and (pageIndex - 1) or (pageIndex - firstColumnRows - 1)
    appendKeyRow(elements, colors, entry.item,
      x + pad + column * (columnWidth + 28),
      y + pad + titleH + subH + row * rowH,
      columnWidth, rowH, entry.index == activeLayer.selected)
  end
  elements[#elements + 1] = {
    type = "text", text = "Page " .. page .. " of " .. pageCount .. "  ·  arrows or Tab select  ·  Return runs",
    frame = { x = x + pad, y = y + height - pad - 20, w = width - 2 * pad, h = 18 },
    textSize = 11, textColor = colors.secondary, textFont = ".AppleSystemUIFont",
  }
  if showCanvas(layerCanvas, elements) then
    hudMetrics.layerRedraws = hudMetrics.layerRedraws + 1
  end
end

refreshLayer = function()
  if activeLayer then renderLayer() end
end

-- Opens a registry layer synchronously. Layer keys are routed by the HUD
-- eventtap while Hyper is held, so the menu can appear inside the Hyper key
-- callback without waiting for modifiers to be released.
local function openLayer(def, initialState)
  if referenceVisible then closeReference() end
  if gridHide then gridHide() end
  closeLayer()
  activeLayer = { id = def.id, def = def, keys = {}, order = def.keys, selected = 1 }
  for _, item in ipairs(def.keys) do activeLayer.keys[item.key] = item.action end
  layerState = initialState or {}
  layerDisplayContext = pointerDisplayContext()
  if def.onOpen then pcall(def.onOpen) end
  hyperDown = true
  syncDirectHotkeys()
  renderLayer()
  resetHudTimeout()
end

-- This replaces Hammerspoon's chooser so switching a running app follows the
-- same hold-Hyper, plain-key interaction as every other visual menu.
openAppSwitcher = function(page)
  closeAllHuds()
  local apps = {}
  for _, app in ipairs(hs.application.runningApplications()) do
    if app:kind() >= 0 and app:name() and #app:name() > 0 then table.insert(apps, app) end
  end
  table.sort(apps, function(a, b) return a:name():lower() < b:name():lower() end)
  if #apps == 0 then
    showAlert("No running apps to switch to")
    return
  end

  local keys = currentMode == "left"
    and { "a", "s", "d", "f", "q", "w", "e", "r", "z", "x" }
    or { "a", "s", "d", "f", "g", "h", "j", "k", "l", "q" }
  local pageSize = #keys
  local pageCount = math.ceil(#apps / pageSize)
  page = math.max(1, math.min(page or 1, pageCount))
  local first = (page - 1) * pageSize + 1
  local def = {
    id = "app-switcher", title = "Running apps",
    subtitle = "Hold Caps Lock and choose an app  ·  page " .. page .. " of " .. pageCount,
    keys = {},
  }
  for offset, key in ipairs(keys) do
    local app = apps[first + offset - 1]
    if not app then break end
    table.insert(def.keys, {
      key = key, label = app:name(), action = function()
        closeLayer()
        if authorizeWindowFollow then authorizeWindowFollow(app, nil, 3, nil, "switcher") end
        pcall(function() app:activate() end)
      end,
    })
  end
  if page > 1 then
    table.insert(def.keys, { key = "[", label = "Previous app page", action = function() openAppSwitcher(page - 1) end })
  end
  if page < pageCount then
    table.insert(def.keys, { key = "]", label = "Next app page", action = function() openAppSwitcher(page + 1) end })
  end
  openLayer(def)
end

local function enterLayerById(id, initialState)
  if not REGISTRY then return end
  for _, def in ipairs(REGISTRY.layers) do
    if def.id == id then
      openLayer(def, initialState)
      return
    end
  end
end

local function referenceSections()
  local sections = {}
  for _, group in ipairs(directGroups) do
    table.insert(sections, { title = group.name, items = group.items })
  end
  if REGISTRY then
    for _, def in ipairs(REGISTRY.layers) do
      table.insert(sections, { title = def.title .. " layer", items = def.keys })
    end
  end
  return sections
end

local function referencePageLayout(width, height)
  local pad, gutter, sectionGap = math.max(12, math.min(30, math.floor(width * 0.06))), 18, 12
  local columns = width < 680 and 1 or (width < 960 and 2 or 3)
  local columnWidth = (width - pad * 2 - gutter * (columns - 1)) / columns
  local top = math.min(84, math.max(60, math.floor(height * 0.38)))
  local bottom = height - math.max(12, math.floor(height * 0.08))
  local pages = { {} }
  local page, column, rowY = 1, 0, top

  local function nextColumn()
    column, rowY = column + 1, top
    if column >= columns then
      page = page + 1
      pages[page] = {}
      column = 0
    end
  end
  for _, section in ipairs(referenceSections()) do
    local index = 1
    while index <= #section.items do
      local room = math.floor((bottom - rowY - 30) / 26)
      if room < 1 then
        nextColumn()
        room = math.max(1, math.floor((bottom - rowY - 30) / 26))
      end
      local last = math.min(#section.items, index + room - 1)
      local items = {}
      for itemIndex = index, last do table.insert(items, section.items[itemIndex]) end
      table.insert(pages[page], {
        section = { title = index == 1 and section.title or section.title .. " (cont.)", items = items },
        x = pad + column * (columnWidth + gutter), y = rowY, width = columnWidth,
      })
      rowY = rowY + 30 + #items * 26 + sectionGap
      index = last + 1
      if index <= #section.items then nextColumn() end
    end
  end
  return pages
end

renderReference = function()
  if not referenceVisible then return end
  local colors = hudColors()
  local context = referenceDisplayContext or pointerDisplayContext()
  local frame = context and context.frame
  if not frame then return end

  referenceDisplayContext = context
  local width = math.max(1, math.min(1060, frame.w - 24))
  local height = math.max(1, math.min(800, frame.h - 24))
  local x = math.floor((frame.w - width) / 2)
  local y = math.floor((frame.h - height) / 2)
  local pages = referencePageLayout(width, height)
  referencePageCount = #pages
  referencePage = math.max(1, math.min(referencePage, #pages))

  referenceCanvas = canvasForContext(referenceCanvas, context, "reference")
  if not referenceCanvas then return end

  local elements = panelElements(colors, x, y, width, height)
  local headerPad = math.max(12, math.min(30, math.floor(height * 0.08)))
  elements[#elements + 1] = {
    type = "text", text = "Complete shortcut reference — " .. modeLabel(currentMode),
    frame = { x = x + headerPad, y = y + headerPad, w = width - 2 * headerPad, h = 22 },
    textSize = height < 220 and 15 or 19, textColor = colors.primary, textFont = ".AppleSystemUIFont",
  }
  elements[#elements + 1] = {
    type = "text", text = "Page " .. referencePage .. " of " .. #pages .. "  ·  arrows, Tab, or [ / ] change page  ·  release Caps Lock to close",
    frame = { x = x + headerPad, y = y + headerPad + 22, w = width - 2 * headerPad, h = 18 },
    textSize = height < 220 and 10 or 12, textColor = colors.secondary, textFont = ".AppleSystemUIFont",
    textLineBreak = "truncateTail",
  }

  for _, placement in ipairs(pages[referencePage]) do
    local section = placement.section
    local columnX = x + placement.x
    local rowY = y + placement.y
    elements[#elements + 1] = {
      type = "text", text = string.upper(section.title),
      frame = { x = columnX, y = rowY, w = placement.width, h = 20 },
      textSize = 12, textColor = colors.accent, textFont = ".AppleSystemUIFont",
      textLineBreak = "truncateTail",
    }
    for index, item in ipairs(section.items) do
      appendKeyRow(elements, colors, item, columnX, rowY + 26 + (index - 1) * 26, placement.width, 26)
    end
  end
  if showCanvas(referenceCanvas, elements) then
    hudMetrics.referenceRedraws = hudMetrics.referenceRedraws + 1
  end
end

local function toggleReference()
  if referenceVisible then
    closeReference()
    return
  end
  closeLayer()
  if gridHide then gridHide() end
  hyperDown = true
  syncDirectHotkeys()
  referenceVisible = true
  referencePage = 1
  referenceDisplayContext = pointerDisplayContext()
  renderReference()
  resetHudTimeout()
end

local showCheatsheet = toggleReference

-- ---------------------------------------------------------------------------
-- Actions.
-- ---------------------------------------------------------------------------
local APP_SPECS = {
  a = { name = "Arc", bundleID = "company.thebrowser.Browser" },
  c = { name = "ChatGPT", bundleID = "com.openai.codex" },
  f = { name = "Finder", bundleID = "com.apple.finder" },
  t = { name = "kitty", bundleID = "net.kovidgoyal.kitty" },
}

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

-- One looping shortcut for both displays: the focused window always moves to
-- the next display in ring order, wrapping from the last back to the first.
local function moveFocusedWindowToNextDisplay()
  if not commandSucceeded(DISPLAY_CYCLE_HELPER) then
    showAlert("Window display move failed")
  end
end

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

local function scrollBy(x, y)
  hs.eventtap.event.newScrollEvent({ x, y }, {}, "line"):post()
end

local function changeVolume(delta)
  local device = hs.audiodevice.defaultOutputDevice()
  if not device then return end
  local value = math.max(0, math.min(100, (device:volume() or 0) + delta))
  device:setVolume(value)
  showAlert("Volume " .. math.floor(value) .. "%", 0.6)
end

local function toggleMute()
  local device = hs.audiodevice.defaultOutputDevice()
  if not device then return end
  local muted = not device:muted()
  device:setMuted(muted)
  showAlert(muted and "Muted" or "Unmuted", 0.6)
end

local function toggleDarkMode()
  local ok = hs.osascript.applescript(
    "tell application \"System Events\" to tell appearance preferences to set dark mode to (not dark mode)")
  if not ok then showAlert("Could not toggle dark mode") end
end

local function reloadConfigs()
  hs.execute("launchctl kickstart -k gui/$(id -u)/com.koekeishiya.skhd")
  hs.reload()
end

local function focusOrLaunchApplication(applicationSpec)
  local application = hs.application.get(applicationSpec.bundleID) or hs.application.get(applicationSpec.name)
  if not application then
    if authorizeWindowFollow then authorizeWindowFollow(nil, nil, 10, applicationSpec, "app-toggle") end
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

  if authorizeWindowFollow then authorizeWindowFollow(application, window, 3, applicationSpec, "app-toggle") end
  application:unhide()
  application:activate(true)
  if not window then return end

  if window:isMinimized() then window:unminimize() end
  window:raise()
  window:focus()
end

local function terminalAtFinderFolder()
  if hs.application.get("kitty") then
    focusOrLaunchApplication(APP_SPECS.t)
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
  local restored, remaining, total, finished = 0, 0, 0, false
  local function finish()
    if finished then return end
    finished = true
    showAlert("Layout restored — " .. restored .. "/" .. total .. " windows")
  end
  local function restoreEntry(entry)
    local app = entry.app and hs.application.get(entry.app) or nil
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
    remaining = remaining - 1
    if remaining == 0 then finish() end
  end
  local entries = {}
  for _, entry in ipairs(layout) do
    if type(entry) == "table" and type(entry.frame) == "table" and entry.frame.x and entry.frame.w then
      table.insert(entries, entry)
    end
  end
  remaining, total = #entries, #entries
  for _, entry in ipairs(entries) do
    local app = entry.app and hs.application.get(entry.app) or nil
    if not app and entry.app and entry.app:find("%.") then
      hs.application.launchOrFocusByBundleID(entry.app)
      hs.timer.doAfter(0.4, function() restoreEntry(entry) end)
    else
      restoreEntry(entry)
    end
  end
  if remaining == 0 then finish() end
end

-- Window hints stay inside the display the pointer is on, so hints never
-- scatter across screens. Their letters are routed while Hyper is held.
closeWindowHints = function()
  if not hintsVisible then return end
  hintsVisible = false
  hintWindowIDs = nil
  pcall(function() hs.hints.closeHints() end)
  -- hs.hints owns a private modal. Escape exits that modal after this handler
  -- has stopped consuming keys, without sending Escape to the focused app.
  pcall(function() hs.eventtap.keyStroke({}, "escape", 0) end)
  syncDirectHotkeys()
end

local function showHints()
  closeAllHuds()
  if currentMode == "left" then
    hs.hints.hintChars = { "a", "s", "d", "f", "q", "w", "e", "r", "z", "x", "c", "v" }
  else
    hs.hints.hintChars = defaultHintChars
  end
  hs.hints.style = "default"
  hs.hints.fontSize = 26
  local context = pointerDisplayContext()
  local screen = context and context.screen
  local windows = {}
  if screen then
    for _, window in ipairs(hs.window.allWindows()) do
      if window:isStandard() and not window:isMinimized() and window:screen() == screen then
        table.insert(windows, window)
      end
    end
  end
  if #windows == 0 then
    showAlert("No hintable windows on this display")
    return
  end
  hintWindowIDs = {}
  for _, window in ipairs(windows) do
    local ok, windowID = pcall(function() return window:id() end)
    if windowID then hintWindowIDs[windowID] = true end
  end
  hintsVisible = true
  hyperDown = true
  syncDirectHotkeys()
  hs.hints.windowHints(windows, function() closeWindowHints() end)
  resetHudTimeout()
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

-- ---------------------------------------------------------------------------
-- Window-follow.
-- ---------------------------------------------------------------------------
local followEnabled = true
local lastCloseTime = 0
local CLOSE_GRACE_PERIOD = 0.5
local FOLLOW_INTENT_TTL = 3
local followIntent = nil
local pullTimer = nil
local closeWatcher = nil
local appWatcher = nil

local function appValue(application, method)
  if not application or not application[method] then return nil end
  local ok, value = pcall(function() return application[method](application) end)
  return ok and value or nil
end

local function windowValue(window, method)
  if not window or not window[method] then return nil end
  local ok, value = pcall(function() return window[method](window) end)
  return ok and value or nil
end

local function clearFollowIntentFor(application, appName)
  if not followIntent then return end
  local bundleID = appValue(application, "bundleID")
  local pid = appValue(application, "pid")
  local name = appValue(application, "name") or appName
  if (followIntent.bundleID and followIntent.bundleID == bundleID)
    or (followIntent.pid and followIntent.pid == pid)
    or (followIntent.name and followIntent.name == name) then
    followIntent = nil
  end
end

-- A token is created only by an explicit workflow action. It expires quickly
-- and can move one matching app/window at most once.
authorizeWindowFollow = function(application, window, ttl, fallback, source)
  if pullTimer then
    pullTimer:stop()
    pullTimer = nil
  end
  local windowIDs = nil
  if window and type(window) == "table" and window.windowIDs then
    windowIDs = window.windowIDs
    window = nil
  end
  followIntent = {
    bundleID = appValue(application, "bundleID") or (fallback and fallback.bundleID),
    pid = appValue(application, "pid"),
    name = appValue(application, "name") or (fallback and fallback.name),
    windowID = windowValue(window, "id"),
    windowIDs = windowIDs,
    expiresAt = hs.timer.secondsSinceEpoch() + (ttl or FOLLOW_INTENT_TTL),
    source = source or "explicit-selection",
  }
end

local function followIntentMatches(application, window, ignoreWindow)
  if not followIntent then return false end
  if hs.timer.secondsSinceEpoch() > followIntent.expiresAt then
    followIntent = nil
    return false
  end
  local bundleID = appValue(application, "bundleID")
  local pid = appValue(application, "pid")
  local name = appValue(application, "name")
  local windowID = windowValue(window, "id")
  if followIntent.bundleID and followIntent.bundleID ~= bundleID then return false end
  if followIntent.pid and followIntent.pid ~= pid then return false end
  if followIntent.name and followIntent.name ~= name then return false end
  if not ignoreWindow then
    if followIntent.windowID and followIntent.windowID ~= windowID then return false end
    if followIntent.windowIDs and not followIntent.windowIDs[windowID] then return false end
  end
  return true
end

authorizeHintSelection = function()
  if not hintWindowIDs then return end
  authorizeWindowFollow(nil, { windowIDs = hintWindowIDs }, FOLLOW_INTENT_TTL, nil, "window-hint")
end

local function pullWindowToCurrentScreen(application, win)
  if hs.timer.secondsSinceEpoch() - lastCloseTime < CLOSE_GRACE_PERIOD then return end
  if not application then return end
  win = win or application:focusedWindow() or application:mainWindow()
  if not win or not win:isStandard() or win:isFullScreen() then return end
  local currentScreen = hs.mouse.getCurrentScreen()
  if currentScreen and win:screen() ~= currentScreen then
    win:moveToScreen(currentScreen)
  end
end

local function toggleWindowFollow()
  followEnabled = not followEnabled
  if not followEnabled then followIntent = nil end
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
  appWatcher = hs.application.watcher.new(function(appName, eventType, watchedApplication)
    if eventType == hs.application.watcher.terminated then
      lastCloseTime = hs.timer.secondsSinceEpoch()
      clearFollowIntentFor(watchedApplication, appName)
      return
    end
    if eventType == hs.application.watcher.activated and followEnabled then
      local application = watchedApplication or hs.application.frontmostApplication()
      local window = application and (application:focusedWindow() or application:mainWindow()) or nil
      if not followIntentMatches(application, window, true) then return end
      if pullTimer then
        pullTimer:stop()
        pullTimer = nil
      end
      pullTimer = hs.timer.doAfter(0.15, function()
        pullTimer = nil
        local currentApplication = hs.application.frontmostApplication() or application
        local currentWindow = currentApplication and (currentApplication:focusedWindow() or currentApplication:mainWindow()) or nil
        if followIntentMatches(currentApplication, currentWindow) then
          followIntent = nil
          pcall(pullWindowToCurrentScreen, currentApplication, currentWindow)
        end
      end)
    end
  end)
  appWatcher:start()
end

-- Older releases placed an unconditional watcher in init.lua. Stop those
-- globals during an upgrade so they cannot race this intent-gated watcher.
local function stopLegacyWindowFollow()
  for _, name in ipairs({ "AppWatcher", "CloseWatcher" }) do
    local watcher = name == "AppWatcher" and AppWatcher or CloseWatcher
    if watcher and watcher.stop then pcall(function() watcher:stop() end) end
    if name == "AppWatcher" then AppWatcher = nil else CloseWatcher = nil end
  end
end

-- ---------------------------------------------------------------------------
-- Mouse grid. Canvas elements are screen-frame local; mouse points remain
-- absolute screen coordinates. Grid keys are routed by the HUD eventtap while
-- Hyper is held, so the pointer can be driven with the Hyper key still down.
-- ---------------------------------------------------------------------------
local GRID_COLS, GRID_ROWS = 12, 8
local gridCanvas = nil

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
  local colors = hudColors()
  local localX = (state.cx - 1) * cellWidth
  local localY = (state.cy - 1) * cellHeight
  local elements = {
    {
      type = "rectangle", action = "fill",
      frame = { x = 0, y = 0, w = state.frame.w, h = state.frame.h },
      fillColor = colors.gridOverlay,
    },
    {
      type = "rectangle", action = "strokeAndFill",
      frame = { x = localX, y = localY, w = cellWidth, h = cellHeight },
      fillColor = { red = 1, green = 0.25, blue = 0.25, alpha = 0.10 },
      strokeColor = { red = 1, green = 0.25, blue = 0.25, alpha = 0.90 },
      strokeWidth = 2,
    },
  }

  if state.fine then
    local fineWidth, fineHeight = cellWidth / GRID_COLS, cellHeight / GRID_ROWS
    table.insert(elements, {
      type = "rectangle", action = "strokeAndFill",
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
          textColor = colors.secondary,
          textAlignment = "center",
        })
      end
    end
  end
  showCanvas(gridCanvas, elements)
end

gridHide = function()
  gridState = nil
  if gridCanvas then
    pcall(function() gridCanvas:hide() end)
    pcall(function() gridCanvas:delete() end)
    gridCanvas = nil
  end
  syncDirectHotkeys()
end

local function toggleGrid()
  if gridState then
    gridHide()
    return
  end
  closeAllHuds()
  local context = pointerDisplayContext()
  local raw = context and context.frame
  if not raw then return end
  -- Grid coordinates stay local to the screen frame; the canvas covers the
  -- whole screen so elements can use frame-local positions directly.
  gridCanvas = newHudCanvas(raw)
  if not gridCanvas then return end
  gridState = {
    frame = { x = 0, y = 0, w = raw.w, h = raw.h },
    cx = math.ceil(GRID_COLS / 2),
    cy = math.ceil(GRID_ROWS / 2),
    scx = math.ceil(GRID_COLS / 2),
    scy = math.ceil(GRID_ROWS / 2),
    fine = false,
  }
  hyperDown = true
  syncDirectHotkeys()
  gridRender()
  resetHudTimeout()
end

gridKey = function(name)
  local state = gridState
  if not state then return end
  local deltas = currentMode == "left"
    and { w = { 0, -1 }, a = { -1, 0 }, s = { 0, 1 }, d = { 1, 0 } }
    or { k = { 0, -1 }, h = { -1, 0 }, j = { 0, 1 }, l = { 1, 0 } }
  local delta = deltas[name]
  if delta then
    state.cx = math.max(1, math.min(GRID_COLS, state.cx + delta[1]))
    state.cy = math.max(1, math.min(GRID_ROWS, state.cy + delta[2]))
    gridRender()
    return
  end
  if name == "g" then
    state.fine = not state.fine
    gridRender()
  elseif name == "c" then
    hs.eventtap.leftClick(gridPoint())
    gridHide()
  elseif name == (currentMode == "left" and "f" or "d") then
    local point = gridPoint()
    hs.eventtap.leftClick(point)
    gridHide()
    hs.timer.doAfter(0.12, function() hs.eventtap.leftClick(point) end)
  elseif name == "x" then
    hs.eventtap.rightClick(gridPoint())
    gridHide()
  end
end

-- ---------------------------------------------------------------------------
-- Mode switching.
-- ---------------------------------------------------------------------------
local function setMode(mode)
  if mode ~= "left" and mode ~= "dual" then
    showAlert("Unknown keyboard mode")
    return false
  end
  if not commandSucceeded(MODE_HELPER .. " " .. mode) then
    showAlert("Keyboard mode change failed")
    return false
  end
  currentMode = mode
  closeAllHuds()
  showAlert("Mode: " .. modeLabel(mode))
  hs.reload()
  return true
end

local function toggleMode()
  setMode(currentMode == "left" and "dual" or "left")
end

-- ---------------------------------------------------------------------------
-- Shortcut registry. This is the single source of truth: direct bindings,
-- layer HUDs, the Action Hub, and the complete reference are all generated
-- from it, so editing an entry here updates every HUD automatically.
-- ---------------------------------------------------------------------------
local function arrowKeysFor(mode)
  if mode == "left" then
    return { up = "w", left = "a", down = "s", right = "d", names = "W/A/S/D" }
  end
  return { up = "k", left = "h", down = "j", right = "l", names = "H/J/K/L" }
end

local function buildRegistry(mode)
  local arrows = arrowKeysFor(mode)
  local nextWindowKey = mode == "left" and "4" or "n"
  local nextDisplayKey = mode == "left" and "4" or "n"
  local arrowWord = {
    [arrows.up] = "up", [arrows.left] = "left",
    [arrows.down] = "down", [arrows.right] = "right",
  }
  local arrowTarget = {
    [arrows.up] = "up", [arrows.left] = "left",
    [arrows.down] = "down", [arrows.right] = "right",
  }

  local function arrowWindowAction(direction)
    return function() runWindowHelper(layerState.op or "focus", direction) end
  end

  local function arrowScrollAction(delta)
    return function() scrollBy(delta[1], delta[2]) end
  end

  local function arrowKeyStrokeAction(arrow)
    return function()
      hs.eventtap.keyStroke(layerState.select and { "shift" } or {}, arrow, 0)
    end
  end

  local layers = {}

  table.insert(layers, {
    id = "workflow", title = "Action Hub",
    subtitle = "Hold Caps Lock, press a key — release Caps Lock to close",
    keys = {
      { key = "a", label = "Apps — launches, switchers, tools", action = function() enterLayerById("apps") end },
      { key = "s", label = "Windows — focus, move, resize, displays", action = function() enterLayerById("windows") end },
      { key = "w", label = "Spaces — focus or send", action = function() enterLayerById("spaces") end },
      { key = "d", label = "System — volume, scroll, appearance", action = function() enterLayerById("system") end },
      { key = "f", label = "Navigation — arrows, editing, tabs", action = function()
          enterLayerById(mode == "left" and "navigation" or "dual-navigation")
        end },
      { key = "r", label = "Utilities — layouts, mode, reload", action = function() enterLayerById("utilities") end },
      { key = "`", label = "Complete shortcut reference", action = toggleReference },
    },
  })

  table.insert(layers, {
    id = "apps", title = "Apps",
    subtitle = "App toggles never open a second window for a running app",
    keys = {
      { key = "a", label = "Arc", action = function() focusOrLaunchApplication(APP_SPECS.a) end },
      { key = "c", label = "ChatGPT", action = function() focusOrLaunchApplication(APP_SPECS.c) end },
      { key = "f", label = "Finder", action = function() focusOrLaunchApplication(APP_SPECS.f) end },
      { key = "t", label = "kitty", action = function() focusOrLaunchApplication(APP_SPECS.t) end },
      { key = "r", label = "Running-app switcher", action = openAppSwitcher },
      { key = "space", label = "Raycast", action = function() hs.execute("open 'raycast://'") end },
      { key = "v", label = "Clipboard history", action = function()
          hs.execute("open 'raycast://extensions/raycast/clipboard-history'")
        end },
      { key = "5", label = "Menu-bar search", action = function()
          hs.execute("open 'raycast://extensions/raycast/menu-bar/search-menu-bar'")
        end },
      { key = nextWindowKey, label = "Next window of current app", action = cycleCurrentAppWindow },
      { key = "e", label = "Window hints (this display)", action = showHints },
      { key = "g", label = "Mouse grid — move & click with the keyboard", action = toggleGrid },
      { key = "q", label = "Shortcat — search & click UI elements", action = function()
          hs.eventtap.keyStroke({ "cmd", "shift" }, "space", 0)
        end },
    },
  })

  table.insert(layers, {
    id = "windows", title = "Windows",
    subtitle = function()
      local op = layerState.op or "focus"
      if op == "move" then
        return "MOVE mode — arrows move/swap the window · press E to resize, M to focus"
      elseif op == "resize" then
        return "RESIZE mode — arrows resize the window · press M to move, E to focus"
      end
      return "FOCUS mode — arrows move focus · press M to move, E to resize"
    end,
    keys = {
      { key = arrows.up, label = "Window " .. arrowWord[arrows.up], action = arrowWindowAction("north") },
      { key = arrows.left, label = "Window " .. arrowWord[arrows.left], action = arrowWindowAction("west") },
      { key = arrows.down, label = "Window " .. arrowWord[arrows.down], action = arrowWindowAction("south") },
      { key = arrows.right, label = "Window " .. arrowWord[arrows.right], action = arrowWindowAction("east") },
      { key = "m", label = "Toggle move mode for arrows", action = function()
          layerState.op = layerState.op == "move" and "focus" or "move"
          refreshLayer()
        end },
      { key = "e", label = "Toggle resize mode for arrows", action = function()
          layerState.op = layerState.op == "resize" and "focus" or "resize"
          refreshLayer()
        end },
      { key = "q", label = "Next window of current app", action = cycleCurrentAppWindow },
      { key = "f", label = "Toggle fullscreen", action = function()
          runYabaiCommand("-m window --toggle zoom-fullscreen", "Window fullscreen failed")
        end },
      { key = "r", label = "Toggle float", action = function()
          runYabaiCommand("-m window --toggle float", "Window float toggle failed")
        end },
      { key = nextDisplayKey, label = "Move window to next display (loops)", action = moveFocusedWindowToNextDisplay },
      { key = "z", label = "Next Space", action = function()
          runYabaiCommand("-m space --focus next", "Space command failed")
        end },
      { key = "v", label = "Previous Space", action = function()
          runYabaiCommand("-m space --focus prev", "Space command failed")
        end },
      { key = "c", label = "Space to other display", action = moveSpaceToOtherDisplay },
      { key = "t", label = "Float ↔ BSP layout", action = toggleYabaiLayout },
      { key = "b", label = "Snap & system…", action = function()
          enterLayerById(mode == "left" and "snap" or "dual-snap")
        end },
    },
  })

  local spaceKeys = { "1", "2", "3", "4", "5", "q", "w", "e", "r" }
  local spaceEntries = {}
  for number, key in ipairs(spaceKeys) do
    table.insert(spaceEntries, {
      key = key, label = "Space " .. number,
      action = function()
        if layerState.send then sendAndFollowSpace(number) else focusSpace(number) end
      end,
    })
  end
  table.insert(spaceEntries, {
    key = "s", label = "Toggle send & follow for numbers",
    action = function()
      layerState.send = not layerState.send
      refreshLayer()
    end,
  })
  table.insert(layers, {
    id = "spaces", title = "Spaces",
    subtitle = function()
      if layerState.send then
        return "SEND & FOLLOW — numbers move the focused window · press S to focus only"
      end
      return "FOCUS — numbers switch Spaces · press S to send the focused window"
    end,
    keys = spaceEntries,
  })

  table.insert(layers, {
    id = "system", title = "System",
    subtitle = "Volume and mute · arrows scroll · B toggles dark appearance",
    keys = {
      { key = "q", label = "Volume up", action = function() changeVolume(5) end },
      { key = "z", label = "Volume down", action = function() changeVolume(-5) end },
      { key = "m", label = "Mute", action = toggleMute },
      { key = arrows.up, label = "Scroll up", action = arrowScrollAction({ 0, 4 }) },
      { key = arrows.left, label = "Scroll left", action = arrowScrollAction({ -4, 0 }) },
      { key = arrows.down, label = "Scroll down", action = arrowScrollAction({ 0, -4 }) },
      { key = arrows.right, label = "Scroll right", action = arrowScrollAction({ 4, 0 }) },
      { key = "b", label = "Toggle dark appearance", action = toggleDarkMode },
    },
  })

  local navigationEntries = {}
  for _, name in ipairs({ arrows.up, arrows.left, arrows.down, arrows.right }) do
    table.insert(navigationEntries, {
      key = name, label = "Arrow " .. arrowWord[name] .. " (selects while SELECT is on)",
      action = arrowKeyStrokeAction(arrowTarget[name]),
    })
  end
  local function strokeKey(modifiers, key)
    return function() hs.eventtap.keyStroke(modifiers, key, 0) end
  end
  table.insert(navigationEntries, {
    key = "t", label = "Toggle select mode for arrows",
    action = function()
      layerState.select = not layerState.select
      refreshLayer()
    end,
  })
  table.insert(navigationEntries, { key = "q", label = "Backspace", action = strokeKey({}, "delete") })
  table.insert(navigationEntries, { key = "f", label = "Forward delete", action = strokeKey({}, "forwarddelete") })
  table.insert(navigationEntries, { key = "e", label = "Return / confirm", action = strokeKey({}, "return") })
  table.insert(navigationEntries, { key = "r", label = "Tab", action = strokeKey({}, "tab") })
  table.insert(navigationEntries, { key = "y", label = "Shift+Tab", action = strokeKey({ "shift" }, "tab") })
  table.insert(navigationEntries, { key = "z", label = "Page up", action = strokeKey({}, "pageup") })
  table.insert(navigationEntries, { key = "c", label = "Page down", action = strokeKey({}, "pagedown") })
  table.insert(navigationEntries, { key = "g", label = "Browser address bar", action = strokeKey({ "cmd" }, "l") })
  table.insert(navigationEntries, { key = "4", label = "Find", action = strokeKey({ "cmd" }, "f") })
  table.insert(navigationEntries, { key = "b", label = "Previous browser tab", action = strokeKey({ "ctrl", "shift" }, "tab") })
  table.insert(navigationEntries, { key = "v", label = "Next browser tab", action = strokeKey({ "ctrl" }, "tab") })
  table.insert(navigationEntries, { key = "n", label = "New browser tab", action = strokeKey({ "cmd" }, "t") })
  table.insert(navigationEntries, { key = "5", label = "Close browser tab", action = strokeKey({ "cmd" }, "w") })
  table.insert(navigationEntries, { key = "1", label = "Browser back", action = strokeKey({ "cmd" }, "[") })
  table.insert(navigationEntries, { key = "2", label = "Browser forward", action = strokeKey({ "cmd" }, "]") })
  table.insert(layers, {
    id = mode == "left" and "navigation" or "dual-navigation",
    title = "Navigation",
    subtitle = function()
      if layerState.select then
        return "SELECT ON — arrows extend the selection · press T to stop selecting"
      end
      return "Press T to select with the arrows · release Caps Lock to close"
    end,
    keys = navigationEntries,
  })

  table.insert(layers, {
    id = "utilities", title = "Utilities",
    subtitle = "Layout snapshots, kitty folder, mode switch, reload",
    keys = {
      { key = "s", label = "Save window layout", action = saveLayout },
      { key = "d", label = "Restore window layout", action = loadLayout },
      { key = "w", label = "kitty at Finder folder / focus kitty", action = terminalAtFinderFolder },
      { key = "b", label = "Toggle window-follow", action = function()
          toggleWindowFollow()
        end },
      { key = "tab", label = "Switch LH / 2H mode", action = toggleMode },
      { key = "r", label = "Reload configuration", action = reloadConfigs },
      { key = "`", label = "Complete shortcut reference", action = toggleReference },
    },
  })

  local unitEntries = {}
  if mode == "left" then
    unitEntries = {
      { key = "a", label = "Left half", action = function() snapFocusedWindow(SNAP_UNITS.left) end },
      { key = "s", label = "Bottom half", action = function() snapFocusedWindow(SNAP_UNITS.bottom) end },
      { key = "w", label = "Top half", action = function() snapFocusedWindow(SNAP_UNITS.top) end },
      { key = "d", label = "Right half", action = function() snapFocusedWindow(SNAP_UNITS.right) end },
      { key = "q", label = "Top-left quarter", action = function() snapFocusedWindow(SNAP_UNITS.topLeft) end },
      { key = "e", label = "Top-right quarter", action = function() snapFocusedWindow(SNAP_UNITS.topRight) end },
      { key = "z", label = "Bottom-left quarter", action = function() snapFocusedWindow(SNAP_UNITS.bottomLeft) end },
      { key = "c", label = "Bottom-right quarter", action = function() snapFocusedWindow(SNAP_UNITS.bottomRight) end },
    }
  else
    unitEntries = {
      { key = "h", label = "Left half", action = function() snapFocusedWindow(SNAP_UNITS.left) end },
      { key = "j", label = "Bottom half", action = function() snapFocusedWindow(SNAP_UNITS.bottom) end },
      { key = "k", label = "Top half", action = function() snapFocusedWindow(SNAP_UNITS.top) end },
      { key = "l", label = "Right half", action = function() snapFocusedWindow(SNAP_UNITS.right) end },
      { key = "u", label = "Top-left quarter", action = function() snapFocusedWindow(SNAP_UNITS.topLeft) end },
      { key = "i", label = "Top-right quarter", action = function() snapFocusedWindow(SNAP_UNITS.topRight) end },
      { key = "o", label = "Bottom-left quarter", action = function() snapFocusedWindow(SNAP_UNITS.bottomLeft) end },
      { key = "p", label = "Bottom-right quarter", action = function() snapFocusedWindow(SNAP_UNITS.bottomRight) end },
      { key = ";", label = "Maximize", action = function() snapFocusedWindow(SNAP_UNITS.maximize) end },
      { key = "'", label = "Center", action = function() snapFocusedWindow(SNAP_UNITS.center) end },
    }
  end
  local snapEntries = {
    { key = "f", label = "Maximize", action = function() snapFocusedWindow(SNAP_UNITS.maximize) end },
    { key = "r", label = "Center", action = function() snapFocusedWindow(SNAP_UNITS.center) end },
    { key = nextDisplayKey, label = "Move window to next display (loops)", action = moveFocusedWindowToNextDisplay },
    { key = "t", label = "Spaces…", action = function() enterLayerById("spaces") end },
    { key = "b", label = "Toggle window-follow", action = function()
        toggleWindowFollow()
      end },
    { key = "v", label = "Hide app", action = strokeKey({ "cmd" }, "h") },
    { key = "g", label = "Minimize window", action = strokeKey({ "cmd" }, "m") },
    { key = "1", label = "Mission Control", action = strokeKey({ "ctrl" }, "up") },
    { key = "2", label = "Toggle hidden Finder files", action = function()
        hs.application.launchOrFocus("Finder")
        hs.timer.doAfter(0.15, function()
          hs.eventtap.keyStroke({ "cmd", "shift" }, ".", 0)
        end)
      end },
  }
  for _, entry in ipairs(unitEntries) do table.insert(snapEntries, entry) end
  table.insert(layers, {
    id = mode == "left" and "snap" or "dual-snap",
    title = "Snap & System",
    subtitle = "Window placement and system controls for the captured window",
    onOpen = function() snapTarget = hs.window.focusedWindow() end,
    keys = snapEntries,
  })

  return { layers = layers }
end

REGISTRY = buildRegistry(currentMode)

local function openWorkflowHub()
  if activeLayer and activeLayer.id == "workflow" then
    closeLayer()
  else
    enterLayerById("workflow")
  end
end

local function openSnapLayer()
  enterLayerById(currentMode == "left" and "snap" or "dual-snap")
end

local function openNavigationLayer()
  enterLayerById(currentMode == "left" and "navigation" or "dual-navigation")
end

hudSwitchActions["/"] = openWorkflowHub
hudSwitchActions.x = openSnapLayer
hudSwitchActions["3"] = openNavigationLayer
hudSwitchActions["`"] = toggleReference

-- ---------------------------------------------------------------------------
-- Direct Hyper bindings. Every binding is disabled while a HUD menu is open so
-- the HUD eventtap is the only router for plain keys at that time.
-- ---------------------------------------------------------------------------
local function bindDirect(key, action, label, group)
  directActions[key] = { action = action, label = label }
  local guardedAction = function()
    if anyHudOpen() then return end
    runAction(action, label)
  end
  table.insert(directHotkeys, hs.hotkey.bind(hyper, key, guardedAction))
  addDirectReference(key, label, group)
end

bindDirect("a", function() focusOrLaunchApplication(APP_SPECS.a) end, "Arc", "Apps")
bindDirect("c", function() focusOrLaunchApplication(APP_SPECS.c) end, "ChatGPT", "Apps")
bindDirect("f", function() focusOrLaunchApplication(APP_SPECS.f) end, "Finder", "Apps")
bindDirect("t", function() focusOrLaunchApplication(APP_SPECS.t) end, "kitty", "Apps")
bindDirect("x", openSnapLayer, "Snap & system layer", "Layers")
bindDirect("3", openNavigationLayer, "Navigation layer", "Layers")
bindDirect("/", openWorkflowHub, "Action Hub", "Layers")
bindDirect("`", toggleReference, "Complete shortcut reference", "Layers")

if currentMode == "left" then
  bindDirect("q", function() snapFocusedWindow(SNAP_UNITS.left) end, "Left half", "Direct window placement")
  bindDirect("w", function() snapFocusedWindow(SNAP_UNITS.maximize) end, "Maximize", "Direct window placement")
  bindDirect("e", function() snapFocusedWindow(SNAP_UNITS.right) end, "Right half", "Direct window placement")
else
  bindDirect("h", function() snapFocusedWindow(SNAP_UNITS.left) end, "Left half", "Direct window placement")
  bindDirect(";", function() snapFocusedWindow(SNAP_UNITS.maximize) end, "Maximize", "Direct window placement")
  bindDirect("l", function() snapFocusedWindow(SNAP_UNITS.right) end, "Right half", "Direct window placement")
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

-- ---------------------------------------------------------------------------
-- HUD eventtap. Installed after every function it routes to exists.
-- ---------------------------------------------------------------------------
local hudEventTap = hs.eventtap.new({
  hs.eventtap.event.types.keyDown,
  hs.eventtap.event.types.keyUp,
  hs.eventtap.event.types.flagsChanged,
}, handleHudEvent)
if hudEventTap then hudEventTap:start() end

-- Screen changes invalidate all absolute-grid and transient-HUD state.
local screenWatcher = nil
if hs.screen.watcher then
  screenWatcher = hs.screen.watcher.new(closeAllHuds)
  screenWatcher:start()
end

-- Redraw an open HUD immediately when macOS changes between light and dark
-- appearance. New HUDs also read hs.host.interfaceStyle() on every render.
local appearanceWatcher = nil
if hs.distributednotifications and hs.distributednotifications.new then
  local ok, watcher = pcall(hs.distributednotifications.new, function()
    cachedAccent = nil
    if activeLayer then
      renderLayer()
    elseif referenceVisible and renderReference then
      renderReference()
    elseif gridState then
      gridRender()
    end
  end, "AppleInterfaceThemeChangedNotification")
  if ok and watcher then
    appearanceWatcher = watcher
    appearanceWatcher:start()
  end
end

configureMenubar()
stopLegacyWindowFollow()
startWindowFollow()

-- HUD layer keys per hand mode, documented for registry/debug inspection.
-- HUDKEYS left: a c f t r space v 5 4 e g q w d s m z b tab escape x 3 / ` 1 2 n y u i o p h j k l ;
-- HUDKEYS dual: a c f t r space v 5 n e g q w d s m z b tab escape x 3 / ` 1 2 y 4 h j k l u i o p ; '

return {
  getMode = function() return currentMode end,
  setMode = setMode,
  showCheatsheet = showCheatsheet,
  openWorkflowHub = openWorkflowHub,
  gridShow = toggleGrid,
  gridHide = gridHide,
  openAppSwitcher = openAppSwitcher,
  toggleWindowFollow = toggleWindowFollow,
  debugStatus = function()
    local context = activeLayer and layerDisplayContext or (referenceVisible and referenceDisplayContext)
    local directKeys = {}
    for key in pairs(directActions) do table.insert(directKeys, key) end
    table.sort(directKeys)
    return {
      mode = currentMode,
      layer = activeLayer and activeLayer.id or nil,
      reference = referenceVisible,
      hints = hintsVisible,
      grid = gridState ~= nil,
      follow = followEnabled,
      hyper = hyperDown,
      directKeys = directKeys,
      hud = {
        layer = activeLayer and activeLayer.id or nil,
        referencePage = referenceVisible and referencePage or nil,
        display = context and {
          w = context.frame.w,
          h = context.frame.h,
        } or nil,
        counters = hudMetrics,
      },
      followPending = followIntent and {
        source = followIntent.source,
        expiresIn = math.max(0, followIntent.expiresAt - hs.timer.secondsSinceEpoch()),
      } or nil,
    }
  end,
  -- Retain watchers and the event tap so they cannot be garbage-collected.
  _screenWatcher = screenWatcher,
  _menubar = menubar,
  _appearanceWatcher = appearanceWatcher,
  _appWatcher = appWatcher,
  _closeWatcher = closeWatcher,
  _hudEventTap = hudEventTap,
}
