-- Run without touching the live Hammerspoon configuration:
--   hs -c 'dofile("tests/test_keyboard.lua")'

local THIS = debug.getinfo(1, "S").source:gsub("^@", "")
if THIS:sub(1, 1) ~= "/" then
  local cwd = (hs.fs and hs.fs.currentDir and hs.fs.currentDir()) or "."
  THIS = cwd .. "/" .. THIS
end
local ROOT = THIS:match("(.+)/tests/test_keyboard.lua$")
assert(ROOT, "cannot locate repository root from " .. THIS)
local KEYBOARD = ROOT .. "/managed/hammerspoon/keyboard.lua"
local HYPER = { "alt", "cmd", "ctrl", "shift" }
local KEY = {
  a = 0, s = 1, d = 2, f = 3, h = 4, g = 5, z = 6, x = 7, c = 8, v = 9,
  b = 11, q = 12, w = 13, e = 14, r = 15, y = 16, t = 17, n = 45, m = 46,
  ["1"] = 18, ["2"] = 19, ["3"] = 20, ["4"] = 21, ["5"] = 23, ["["] = 33, ["]"] = 30, ["`"] = 50,
  escape = 53, up = 126, down = 125, left = 123, right = 124, tab = 48,
  space = 49, ["return"] = 36, ["/"] = 44,
}
local DOWN = "keyDown"
local UP = "keyUp"
local FLAGS = "flagsChanged"
local HYPER_FLAGS = { cmd = true, alt = true, ctrl = true, shift = true }
local NO_FLAGS = {}

local failures = 0
local testsRun = 0

local function fail(message)
  failures = failures + 1
  print("FAIL: " .. message)
end

local function assertTrue(value, message)
  if not value then fail(message or "expected true") end
end

local function assertEqual(actual, expected, message)
  if actual ~= expected then
    fail((message or "values differ") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
  end
end

local function sorted(mods)
  local result = {}
  for _, modifier in ipairs(mods or {}) do table.insert(result, modifier) end
  table.sort(result)
  return table.concat(result, "+")
end

local function run(name, fn)
  testsRun = testsRun + 1
  local ok, err = pcall(fn)
  if not ok then
    failures = failures + 1
    print("ERROR in '" .. name .. "': " .. tostring(err))
  end
end

local function newFake(mode, helperSucceeds, legacyWatchers)
  local fake = {
    alerts = {}, bindings = {}, canvases = {}, commands = {}, keyStrokes = {},
    launches = {}, bundleLaunches = {}, clicks = {}, scrolls = 0, reloads = 0,
    taps = {}, chooserShown = 0, hintCalls = {}, hintChars = nil, hintStyle = nil,
    volume = 50, muted = false, layoutWrites = 0, runningApplicationsByName = {},
    windows = {}, helperSucceeds = helperSucceeds, mode = mode, modifiers = {},
  }

  local function timer()
    return { stop = function() end, start = function() end }
  end

  local hs = {
    configdir = "/tmp/keyboard-test",
    hotkey = {}, timer = {}, alert = {}, application = {}, image = {}, hints = {},
    mouse = {}, screen = { watcher = {} }, canvas = {}, webview = {},
    eventtap = { event = {} }, audiodevice = {}, brightness = {},
    json = {}, fs = {}, osascript = {}, spaces = { watcher = {} },
    window = {}, menubar = {}, geometry = {}, chooser = {}, distributednotifications = {},
  }
  fake.hs = hs

  function hs.hotkey.bind(mods, key, pressed, released, repeated)
    local binding = {
      mods = sorted(mods), key = key, pressed = pressed, released = released,
      repeated = repeated, disabled = false,
    }
    function binding:disable() self.disabled = true end
    function binding:enable() self.disabled = false end
    function binding:delete() self.disabled = true; self.deleted = true end
    table.insert(fake.bindings, binding)
    return binding
  end

  function hs.execute(command)
    table.insert(fake.commands, command)
    if command:find("set%-keyboard%-mode%.py", 1, false) then
      return fake.helperSucceeds and "" or "helper failed", fake.helperSucceeds
    end
    return "", true
  end
  function hs.reload() fake.reloads = fake.reloads + 1 end
  function hs.alert.show(message)
    table.insert(fake.alerts, message)
    return #fake.alerts
  end
  function hs.alert.closeSpecific() end
  function hs.alert.closeAll() end
  function hs.application.runningApplications() return {} end
  function hs.application.frontmostApplication() return fake.frontmostApplication end
  function hs.application.launchOrFocus(name) table.insert(fake.launches, name) end
  function hs.application.launchOrFocusByBundleID(bundleID) table.insert(fake.bundleLaunches, bundleID) end
  function hs.application.get(name) return fake.runningApplicationsByName[name] end
  function hs.application.applicationForPID() return nil end
  function hs.image.imageFromAppBundle() return nil end
  function hs.hints.windowHints(windows)
    table.insert(fake.hintCalls, windows or {})
    fake.hintChars = hs.hints.hintChars
    fake.hintStyle = hs.hints.style
  end
  function hs.hints.processChar(character) fake.hintProcessed = character end
  function hs.hints.closeHints() fake.hintsClosed = (fake.hintsClosed or 0) + 1 end
  function hs.mouse.getCurrentScreen() return fake.screen end
  function hs.mouse.absolutePosition() return fake.pointer or { x = 200, y = 100 } end
  function hs.screen.mainScreen() return fake.screen end
  fake.screen = {
    frame = function() return { x = 100, y = 50, w = 1200, h = 800 } end,
    fullFrame = function() return { x = 100, y = 50, w = 1200, h = 800 } end,
  }
  fake.otherScreen = {
    frame = function() return { x = 1400, y = 50, w = 1200, h = 800 } end,
    fullFrame = function() return { x = 1400, y = 50, w = 1200, h = 800 } end,
  }
  function hs.screen.allScreens() return { fake.screen, fake.otherScreen } end
  function hs.screen.watcher.new(callback)
    fake.screenWatcher = callback
    return timer()
  end
  hs.canvas.windowLevels = { assistiveTechHigh = 1500, screenSaver = 1000, overlay = 900, floating = 100 }
  hs.canvas.windowBehaviors = { canJoinAllSpaces = 1, stationary = 2 }
  hs.webview.windowBehaviors = { canJoinAllSpaces = 1, stationary = 2, fullScreenAuxiliary = 4 }
  function hs.canvas.new(frame)
    local canvas = { frameValue = frame, elements = {}, visible = false }
    function canvas:level(value) if value then self.levelValue = value end return self.levelValue or self end
    function canvas:behavior() return self end
    function canvas:alpha() return self end
    function canvas:clickActivating() return self end
    function canvas:frame(value) if value then self.frameValue = value end return self.frameValue end
    function canvas:show() self.visible = true end
    function canvas:hide() self.visible = false end
    function canvas:isShowing() return self.visible end
    function canvas:delete() self.visible = false; self.deleted = true end
    function canvas:replaceElements(elements)
      for _, element in ipairs(elements) do
        if element.action == "fillStroke" then
          error("invalid Hammerspoon canvas action: fillStroke")
        end
      end
      self.elements = elements
    end
    table.insert(fake.canvases, canvas)
    return canvas
  end
  function hs.webview.new(frame)
    local webview = { frameValue = frame, visible = false }
    function webview:windowStyle() return self end
    function webview:transparent() return self end
    function webview:allowTextEntry() return self end
    function webview:closeOnEscape() return self end
    function webview:level(value) self.levelValue = value; return self end
    function webview:behavior(value) self.behaviorValue = value; return self end
    function webview:html(value) self.htmlValue = value; return self end
    function webview:show() self.visible = true; return self end
    function webview:sendToBack() self.sentToBack = true; return self end
    function webview:hide() self.visible = false; return self end
    function webview:isVisible() return self.visible end
    function webview:delete() self.visible = false; self.deleted = true end
    fake.webviews = fake.webviews or {}
    table.insert(fake.webviews, webview)
    return webview
  end
  function hs.eventtap.new(types, callback)
    local tap = { types = types, callback = callback, started = false }
    function tap:start() self.started = true end
    function tap:stop() self.started = false end
    table.insert(fake.taps, tap)
    return tap
  end

  function hs.eventtap.checkKeyboardModifiers() return fake.modifiers end
  function hs.eventtap.keyStroke(mods, key) table.insert(fake.keyStrokes, { mods = sorted(mods), key = key }) end
  function hs.eventtap.leftClick(point) table.insert(fake.clicks, { kind = "left", point = point }) end
  function hs.eventtap.rightClick(point) table.insert(fake.clicks, { kind = "right", point = point }) end
  function hs.eventtap.event.newScrollEvent()
    return { post = function() fake.scrolls = fake.scrolls + 1 end }
  end
  hs.eventtap.event.types = { keyDown = DOWN, keyUp = UP, flagsChanged = FLAGS }
  function hs.timer.doEvery() return timer() end
  function hs.timer.doAfter(delay, callback)
    if delay <= 0.25 then callback() end
    return timer()
  end
  function hs.timer.usleep() end
  function hs.timer.secondsSinceEpoch() return fake.now or 1 end
  function hs.audiodevice.defaultOutputDevice()
    return {
      volume = function() return fake.volume end,
      setVolume = function(_, value) fake.volume = value end,
      muted = function() return fake.muted end,
      setMuted = function(_, value) fake.muted = value end,
    }
  end
  function hs.json.write() fake.layoutWrites = fake.layoutWrites + 1 end
  function hs.json.read() return {} end
  function hs.json.decode() return nil end
  function hs.fs.attributes() return nil end
  function hs.osascript.applescript() fake.osascriptCalls = (fake.osascriptCalls or 0) + 1; return true, "" end
  function hs.spaces.watcher.new() return timer() end
  function hs.distributednotifications.new(callback, name)
    fake.appearanceCallback = callback
    fake.appearanceNotification = name
    return timer()
  end
  function hs.window.allWindows() return fake.windows end
  function hs.window.focusedWindow() return fake.focusedWindow end
  function hs.menubar.new()
    return { setTitle = function() end, setMenu = function() end }
  end
  function hs.geometry.rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end
  function hs.chooser.new(callback)
    local chooser = { callback = callback }
    function chooser:width() end
    function chooser:hideCallback(fn) self.hideCallback = fn end
    function chooser:choices() end
    function chooser:placeholderText() end
    function chooser:selectedRow() return 1 end
    function chooser:selectedRowContents() return nil end
    function chooser:show() fake.chooserShown = fake.chooserShown + 1 end
    function chooser:hide() end
    return chooser
  end
  hs.window.filter = {
    new = function() return { subscribe = function() end } end,
    windowDestroyed = "windowDestroyed",
  }
  hs.application.watcher = {
    new = function(callback)
      fake.appWatcherCallback = callback
      return { start = function() end }
    end,
    terminated = "terminated",
    activated = "activated",
  }

  local realOpen = io.open
  local fakeIo = {}
  function fakeIo.open(path, access)
    if type(path) == "string" and path:match("%.config/keyboard%-mode$") and access == "r" then
      if not fake.mode then return nil end
      return { read = function() return fake.mode end, close = function() end }
    end
    if type(path) == "string" and path:match("%.config/keyboard%-mode$") and access == "w" then
      return { write = function(_, value) fake.writtenMode = value end, close = function() end }
    end
    return realOpen(path, access)
  end

  local env = setmetatable({ hs = hs, io = fakeIo }, { __index = _G })
  if legacyWatchers then
    env.AppWatcher = legacyWatchers.app
    env.CloseWatcher = legacyWatchers.close
  end
  local chunk, loadError
  if _VERSION == "Lua 5.1" then
    chunk, loadError = loadfile(KEYBOARD)
    if chunk then setfenv(chunk, env) end
  else
    chunk, loadError = loadfile(KEYBOARD, "t", env)
  end
  assertTrue(chunk, loadError)
  local ok, moduleOrError = pcall(chunk)
  assertTrue(ok, moduleOrError)
  fake.api = moduleOrError
  return fake
end

local function binding(fake, mods, key)
  local requested = sorted(mods)
  for i = #fake.bindings, 1, -1 do
    local candidate = fake.bindings[i]
    if candidate.mods == requested and candidate.key == key and not candidate.disabled then return candidate end
  end
  fail("missing active binding " .. requested .. " " .. key)
  return nil
end

local function findBinding(fake, mods, key)
  local requested = sorted(mods)
  for _, candidate in ipairs(fake.bindings) do
    if candidate.mods == requested and candidate.key == key and not candidate.deleted then return candidate end
  end
  return nil
end

local function activeBindingCount(fake, mods)
  local count = 0
  local requested = sorted(mods)
  for _, candidate in ipairs(fake.bindings) do
    if candidate.mods == requested and not candidate.disabled then count = count + 1 end
  end
  return count
end

local function hudTap(fake)
  assertTrue(#fake.taps > 0, "the HUD event tap must be installed")
  return fake.taps[1]
end

local function tapKey(fake, keyCode, flags)
  return hudTap(fake).callback({
    getType = function() return DOWN end,
    getKeyCode = function() return keyCode end,
    getFlags = function() return flags end,
  })
end

local function tapFlags(fake, flags)
  return hudTap(fake).callback({
    getType = function() return FLAGS end,
    getKeyCode = function() return 58 end,
    getFlags = function() return flags end,
  })
end

local function releaseHyper(fake)
  tapFlags(fake, {})
end

local function followWindow(fake, id, application, screen)
  return {
    id = function() return id end,
    application = function() return application end,
    isStandard = function() return true end,
    isMinimized = function() return false end,
    isFullScreen = function() return false end,
    raise = function() end,
    focus = function() end,
    screen = function() return screen or fake.screen end,
    moveToScreen = function(_, target)
      fake.followMoves = (fake.followMoves or 0) + 1
      fake.followTarget = target
    end,
  }
end

local function followApplication(fake, name, bundleID, pid, window)
  local application = {
    name = function() return name end,
    bundleID = function() return bundleID end,
    pid = function() return pid end,
    focusedWindow = function() return window end,
    mainWindow = function() return window end,
    allWindows = function() return { window } end,
    unhide = function() end,
    activate = function() end,
  }
  return application
end

local function activateForFollow(fake, application)
  fake.frontmostApplication = application
  fake.appWatcherCallback(application:name(), fake.hs.application.watcher.activated, application)
end

local function openHub(fake)
  tapKey(fake, KEY["/"], HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "workflow", "Hyper+/ must open the Action Hub")
end

local function enterLayerViaHub(fake, key, expected)
  openHub(fake)
  tapKey(fake, KEY[key], HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, expected, "hub key " .. key .. " must open " .. expected)
end

-- ---------------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------------
run("module loads for both hand modes and reports the mode", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    assertEqual(fake.api.getMode(), mode, mode .. " mode must be read from the mode file")
    assertTrue(fake.api._menubar ~= nil, mode .. " mode must retain its menu bar indicator")
  end
end)

run("module stops legacy global window-follow watchers during an upgrade", function()
  local stopped = { app = 0, close = 0 }
  local fake = newFake("left", true, {
    app = { stop = function() stopped.app = stopped.app + 1 end },
    close = { stop = function() stopped.close = stopped.close + 1 end },
  })
  assertEqual(stopped.app, 1, "the old application watcher must be stopped")
  assertEqual(stopped.close, 1, "the old close watcher must be stopped")
  assertTrue(fake.api._appWatcher ~= nil, "the managed watcher must replace the stopped legacy watcher")
end)

run("unambiguous registry keys are promoted to direct shortcuts automatically", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    local automatic = fake.api.debugStatus().automaticDirectKeys
    assertTrue(#automatic > 0, mode .. " mode must expose at least one automatic direct shortcut")
    local sawY = false
    for _, key in ipairs(automatic) do
      if key == "y" then sawY = true end
      assertTrue(findBinding(fake, HYPER, key) ~= nil,
        mode .. " automatic key " .. key .. " must have a live direct binding")
    end
    assertTrue(sawY, mode .. " mode must promote the unique Shift+Tab action on Y")
    local hasN = false
    for _, key in ipairs(automatic) do if key == "n" then hasN = true end end
    assertEqual(hasN, mode == "left",
      "N must be promoted only in LH, where the 2H next-window owner is absent")
    binding(fake, HYPER, "y").pressed()
    local stroke = fake.keyStrokes[#fake.keyStrokes]
    assertEqual(stroke.key, "tab", "automatic Hyper+Y must execute Shift+Tab")
    assertEqual(stroke.mods, "shift", "automatic Hyper+Y must retain the layer action modifiers")
  end
end)

run("Hyper-held HUD lifecycle: open, route a key, close on release", function()
  local fake = newFake("left", true)
  openHub(fake)
  local consumed = tapKey(fake, KEY.a, HYPER_FLAGS)
  assertTrue(consumed == true, "keys routed to the HUD must be consumed")
  assertEqual(fake.api.debugStatus().layer, "apps", "holding Hyper, A must open the apps layer")
  releaseHyper(fake)
  assertEqual(fake.api.debugStatus().layer, nil, "releasing Hyper must close every HUD")
  local directArc = findBinding(fake, HYPER, "a")
  assertTrue(directArc and not directArc.disabled, "direct hotkeys must be re-enabled after release")
end)

run("the first eventtap key-down opens every HUD identifier", function()
  local hub = newFake("left", true)
  assertTrue(tapKey(hub, KEY["/"], HYPER_FLAGS), "the first Hyper+/ key-down must be consumed")
  assertEqual(hub.api.debugStatus().layer, "workflow", "the first Hyper+/ key-down must open the hub")

  local snap = newFake("left", true)
  assertTrue(tapKey(snap, KEY.x, HYPER_FLAGS), "the first Hyper+X key-down must be consumed")
  assertEqual(snap.api.debugStatus().layer, "snap", "the first Hyper+X key-down must open snap")

  local reference = newFake("left", true)
  assertTrue(tapKey(reference, KEY["`"], HYPER_FLAGS), "the first Hyper+backtick key-down must be consumed")
  assertTrue(reference.api.debugStatus().reference,
    "the first Hyper+backtick key-down must open the reference")
end)

run("top-level HUD identifiers switch menus without releasing Hyper", function()
  local fake = newFake("left", true)
  tapKey(fake, KEY.x, HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "snap", "Hyper+X must open snap")
  tapKey(fake, KEY["/"], HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "workflow", "Hyper+/ must replace snap with the hub")
  tapKey(fake, KEY["3"], HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "navigation", "Hyper+3 must replace the hub with navigation")
  tapKey(fake, KEY["`"], HYPER_FLAGS)
  assertTrue(fake.api.debugStatus().reference, "Hyper+backtick must replace navigation with the reference")
  tapKey(fake, KEY.x, HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "snap", "Hyper+X must replace the reference with snap")
  assertTrue(fake.api.debugStatus().hyper, "all menu switches must preserve the held Hyper session")
end)

run("HUD canvases open on the display containing the pointer", function()
  local fake = newFake("left", true)
  fake.pointer = { x = 1500, y = 100 }
  openHub(fake)
  local canvas = fake.canvases[#fake.canvases]
  assertEqual(canvas.frameValue.x, 1400, "the HUD canvas must use the pointer display origin")
  assertTrue(canvas.elements[1].frame.x < 1400,
    "HUD elements must use screen-local coordinates instead of adding the display origin twice")
end)

run("HUD redraws reuse the canvas and stay on their opening display", function()
  local fake = newFake("left", true)
  fake.pointer = { x = 1500, y = 100 }
  openHub(fake)
  local canvas = fake.canvases[#fake.canvases]
  fake.pointer = { x = 200, y = 100 }
  tapKey(fake, KEY.down, HYPER_FLAGS)
  local status = fake.api.debugStatus()
  assertEqual(#fake.canvases, 1, "selection redraw must reuse the existing HUD canvas")
  assertEqual(canvas.frameValue.x, 1400, "an open HUD must remain on its original display")
  assertEqual(status.hud.counters.layerCanvasCreated, 1, "one canvas must be created")
  assertEqual(status.hud.counters.layerCanvasReused, 1, "one redraw must reuse it")
end)

run("direct hotkeys stay registered and ignore callbacks while a HUD menu is open", function()
  local fake = newFake("left", true)
  local directArc = binding(fake, HYPER, "a")
  local launchesBefore = #fake.launches
  openHub(fake)
  assertTrue(not directArc.disabled,
    "the opening hotkey must stay registered until its physical key-up completes")
  directArc.pressed()
  assertEqual(#fake.launches, launchesBefore,
    "a registered direct hotkey must ignore callbacks while the HUD router owns keys")
  releaseHyper(fake)
  assertTrue(not directArc.disabled, "direct hotkeys must remain registered after the HUD closes")
end)

run("running-app switcher uses a held-Hyper layer instead of control shortcuts", function()
  local fake = newFake("left", true)
  local activated = false
  fake.hs.application.runningApplications = function()
    return {
      {
        kind = function() return 0 end,
        name = function() return "Example" end,
        activate = function() activated = true end,
      },
    }
  end
  binding(fake, HYPER, "r").pressed()
  assertEqual(fake.api.debugStatus().layer, "app-switcher", "Hyper+R must open the held-Hyper app layer")
  tapKey(fake, KEY.a, HYPER_FLAGS)
  assertTrue(activated, "the plain app key must activate its running app")
  assertEqual(fake.api.debugStatus().layer, nil, "app selection must close its visual layer")
end)

run("HUD panels use an opaque system-aware Canvas surface", function()
  local fake = newFake("left", true)
  openHub(fake)
  local canvas = fake.canvases[#fake.canvases]
  assertEqual(canvas.levelValue, 1500, "HUD text must render above system panels")
  assertEqual(canvas.elements[1].fillColor.alpha, 1, "the HUD panel must be fully opaque")
  assertEqual(canvas.elements[1].fillColor.red, 0, "dark mode must use AMOLED black")
  assertTrue(not fake.webviews or #fake.webviews == 0,
    "solid HUDs must not create a separate WebView backdrop")
  releaseHyper(fake)

  local light = newFake("left", true)
  light.hs.host = { interfaceStyle = function() return "Light" end }
  openHub(light)
  local lightPanel = light.canvases[#light.canvases].elements[1].fillColor
  assertEqual(lightPanel.alpha, 1, "light mode must remain fully opaque")
  assertTrue(lightPanel.red > lightPanel.blue,
    "light mode must use a warm creamy white instead of a cool system gray")
end)

run("an open HUD redraws when the macOS appearance changes", function()
  local fake = newFake("left", true)
  fake.hs.host = { interfaceStyle = function() return "Dark" end }
  openHub(fake)
  assertEqual(fake.canvases[#fake.canvases].elements[1].fillColor.red, 0,
    "the initially open HUD must use AMOLED black in dark mode")
  fake.hs.host.interfaceStyle = function() return "Light" end
  fake.appearanceCallback()
  local panel = fake.canvases[#fake.canvases].elements[1].fillColor
  assertTrue(panel.red > panel.blue, "the open HUD must redraw with creamy light colors")
  assertEqual(fake.appearanceNotification, "AppleInterfaceThemeChangedNotification",
    "the watcher must subscribe to the macOS appearance notification")
end)

run("arrow and Return navigation execute the selected HUD item while Hyper stays held", function()
  local fake = newFake("left", true)
  openHub(fake)
  tapKey(fake, KEY.down, HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "workflow", "moving selection must keep the HUD open")
  tapKey(fake, KEY["return"], HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "windows", "Return must execute the selected Windows entry")
  assertTrue(fake.api.debugStatus().hyper, "Hyper must remain held after navigating into another HUD")
end)

run("every layer opens from the hub with a Hyper-held key in both modes", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    enterLayerViaHub(fake, "s", "windows")
    releaseHyper(fake)
    enterLayerViaHub(fake, "w", "spaces")
    releaseHyper(fake)
    enterLayerViaHub(fake, "d", "system")
    releaseHyper(fake)
    enterLayerViaHub(fake, "f", mode == "left" and "navigation" or "dual-navigation")
    releaseHyper(fake)
    enterLayerViaHub(fake, "r", "utilities")
    releaseHyper(fake)
    enterLayerViaHub(fake, "a", "apps")
    releaseHyper(fake)
  end
end)

run("windows layer routes arrows without Shift and toggles move/resize", function()
  local fake = newFake("left", true)
  enterLayerViaHub(fake, "s", "windows")
  tapKey(fake, KEY.w, HYPER_FLAGS)
  assertTrue(fake.commands[#fake.commands]:find("focus north", 1, true),
    "plain arrow must focus while Hyper is held")
  tapKey(fake, KEY.m, HYPER_FLAGS)
  tapKey(fake, KEY.w, HYPER_FLAGS)
  assertTrue(fake.commands[#fake.commands]:find("move north", 1, true),
    "M must switch arrows to move/swap")
  tapKey(fake, KEY.e, HYPER_FLAGS)
  tapKey(fake, KEY.w, HYPER_FLAGS)
  assertTrue(fake.commands[#fake.commands]:find("resize north", 1, true),
    "E must switch arrows to resize")
  assertEqual(fake.api.debugStatus().layer, "windows", "actions must keep the layer open")
  releaseHyper(fake)
end)

run("the mode-local key invokes the shared looping display helper in every window layer", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local displayKey = mode == "left" and "4" or "n"
    local fake = newFake(mode, true)
    enterLayerViaHub(fake, "s", "windows")
    tapKey(fake, KEY[displayKey], HYPER_FLAGS)
    assertTrue(fake.commands[#fake.commands]:find("cycle%-window%-display%.sh", 1, false),
      mode .. " mode must move the focused window to the next display")
    releaseHyper(fake)

    fake = newFake(mode, true)
    binding(fake, HYPER, "x").pressed()
    assertEqual(fake.api.debugStatus().layer, mode == "left" and "snap" or "dual-snap",
      "Hyper+X must open the snap layer")
    tapKey(fake, KEY[displayKey], HYPER_FLAGS)
    assertTrue(fake.commands[#fake.commands]:find("cycle%-window%-display%.sh", 1, false),
      "snap layer must carry the same looping display shortcut")
    releaseHyper(fake)
  end
end)

run("brightness and previous-display shortcuts are gone", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    local staleKeys = mode == "left" and { "1", "2" } or { "left", "right" }
    for _, key in ipairs(staleKeys) do
      assertTrue(findBinding(fake, HYPER, key) == nil,
        "brightness must not be bound to Hyper+" .. key .. " in " .. mode .. " mode")
    end
    for _, candidate in ipairs(fake.bindings) do
      assertTrue(candidate.mods ~= "shift",
        "layer keys must not require Shift in " .. mode .. " mode")
    end
  end
end)

run("volume and mute stay; mute exists in both modes", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    local up = findBinding(fake, HYPER, mode == "left" and "q" or "up")
    local down = findBinding(fake, HYPER, mode == "left" and "z" or "down")
    local mute = findBinding(fake, HYPER, "m")
    assertTrue(up ~= nil, mode .. " mode must keep volume up")
    assertTrue(down ~= nil, mode .. " mode must keep volume down")
    assertTrue(mute ~= nil, mode .. " mode must bind mute on Hyper+M")
    up.pressed()
    assertEqual(fake.volume, 55, mode .. " volume up must raise volume")
    down.pressed()
    assertEqual(fake.volume, 50, mode .. " volume down must lower volume")
    mute.pressed()
    assertTrue(fake.muted, mode .. " mute must toggle the output device")
  end
end)

run("spaces layer focuses by default and sends after the S toggle", function()
  local fake = newFake("left", true)
  enterLayerViaHub(fake, "w", "spaces")
  tapKey(fake, KEY["1"], HYPER_FLAGS)
  assertTrue(fake.commands[#fake.commands]:find("space %-%-focus 1", 1, false),
    "numbers must focus Spaces by default")
  tapKey(fake, KEY.s, HYPER_FLAGS)
  tapKey(fake, KEY["2"], HYPER_FLAGS)
  assertTrue(fake.commands[#fake.commands]:find("window %-%-space 2", 1, false),
    "S must toggle numbers to send & follow")
  releaseHyper(fake)
end)

run("system layer scrolls with mode arrows and keeps dark mode", function()
  local fake = newFake("dual", true)
  enterLayerViaHub(fake, "d", "system")
  tapKey(fake, KEY.h, HYPER_FLAGS)
  assertEqual(fake.scrolls, 1, "dual arrows must scroll (H = left)")
  tapKey(fake, KEY.b, HYPER_FLAGS)
  assertEqual(fake.osascriptCalls or 0, 1, "dark mode must be reachable from the system layer")
  releaseHyper(fake)
end)

run("navigation layer routes arrows, select toggle, and browser controls", function()
  local fake = newFake("left", true)
  enterLayerViaHub(fake, "f", "navigation")
  tapKey(fake, KEY.w, HYPER_FLAGS)
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "up", "W must emit the up arrow")
  tapKey(fake, KEY.t, HYPER_FLAGS)
  tapKey(fake, KEY.w, HYPER_FLAGS)
  assertEqual(fake.keyStrokes[#fake.keyStrokes].mods, "shift", "T must make arrows select")
  tapKey(fake, KEY.e, HYPER_FLAGS)
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "return", "E must confirm")
  tapKey(fake, KEY["5"], HYPER_FLAGS)
  assertEqual(fake.keyStrokes[#fake.keyStrokes].mods, "cmd", "5 must close the browser tab")
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "w", "5 must emit Command+W")
  tapKey(fake, KEY.x, HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().layer, "snap",
    "the global X menu identifier must switch from navigation to snap")
  releaseHyper(fake)
end)

run("utilities layer saves layouts and the reference opens and closes", function()
  local fake = newFake("left", true)
  enterLayerViaHub(fake, "r", "utilities")
  tapKey(fake, KEY.s, HYPER_FLAGS)
  assertEqual(fake.layoutWrites, 1, "utilities S must save the window layout")
  releaseHyper(fake)

  binding(fake, HYPER, "`").pressed()
  assertTrue(fake.api.debugStatus().reference, "Hyper+backtick must show the reference")
  releaseHyper(fake)
  assertTrue(not fake.api.debugStatus().reference, "releasing Hyper must close the reference")
end)

run("complete reference pages through every generated shortcut section", function()
  local fake = newFake("left", true)
  binding(fake, HYPER, "`").pressed()
  local canvas = fake.canvases[#fake.canvases]
  local firstPage = canvas.elements[3].text
  assertTrue(firstPage:find("Page 1 of ", 1, true) ~= nil,
    "the generated reference must show its current page and page count")
  tapKey(fake, KEY["]"], HYPER_FLAGS)
  assertTrue(fake.api.debugStatus().reference, "page navigation must keep the reference open while Hyper is held")
  assertTrue(canvas.elements[3].text:find("Page 2 of ", 1, true) ~= nil,
    "the reference must continue onto the next page instead of dropping later sections")
  releaseHyper(fake)
end)

run("snap layer places the captured window without Shift", function()
  local fake = newFake("left", true)
  local moved = {}
  fake.focusedWindow = {
    isStandard = function() return true end,
    moveToUnit = function(_, unit) table.insert(moved, unit) end,
  }
  binding(fake, HYPER, "x").pressed()
  tapKey(fake, KEY.a, HYPER_FLAGS)
  assertEqual(moved[#moved] and moved[#moved].x, 0, "snap A must place the left half")
  assertEqual(moved[#moved] and moved[#moved].w, 0.5, "snap A must place the left half")
  releaseHyper(fake)
end)

run("dual mode keeps its direct Hyper snap map", function()
  local fake = newFake("dual", true)
  local moved = {}
  fake.focusedWindow = {
    isStandard = function() return true end,
    moveToUnit = function(_, unit) table.insert(moved, unit) end,
  }
  local expected = {
    h = { 0, 0, 0.5, 1 }, l = { 0.5, 0, 0.5, 1 },
    k = { 0, 0, 1, 0.5 }, j = { 0, 0.5, 1, 0.5 },
    u = { 0, 0, 0.5, 0.5 }, i = { 0.5, 0, 0.5, 0.5 },
    o = { 0, 0.5, 0.5, 0.5 }, p = { 0.5, 0.5, 0.5, 0.5 },
  }
  for key, wanted in pairs(expected) do
    binding(fake, HYPER, key).pressed()
    local actual = moved[#moved]
    assertTrue(actual ~= nil, "snap " .. key .. " must move the focused window")
    assertEqual(actual.x, wanted[1], "snap " .. key .. " x")
    assertEqual(actual.y, wanted[2], "snap " .. key .. " y")
    assertEqual(actual.w, wanted[3], "snap " .. key .. " width")
    assertEqual(actual.h, wanted[4], "snap " .. key .. " height")
  end
end)

run("mouse grid routes keys while Hyper is held and closes on release", function()
  local fake = newFake("left", true)
  fake.api.gridShow()
  assertTrue(fake.api.debugStatus().grid, "grid must open")
  tapKey(fake, KEY.a, HYPER_FLAGS)
  assertEqual(fake.api.debugStatus().grid, true, "grid movement keys must keep the grid open")
  tapKey(fake, KEY.c, HYPER_FLAGS)
  assertEqual(#fake.clicks, 1, "C must left-click the grid point")
  assertEqual(fake.api.debugStatus().grid, false, "clicking must close the grid")
  releaseHyper(fake)

  fake = newFake("dual", true)
  fake.api.gridShow()
  releaseHyper(fake)
  assertEqual(fake.api.debugStatus().grid, false, "releasing Hyper must close the grid")
end)

run("window hints only cover the display the pointer is on", function()
  local fake = newFake("left", true)
  fake.windows = {
    { isStandard = function() return true end, isMinimized = function() return false end,
      screen = function() return fake.screen end },
    { isStandard = function() return true end, isMinimized = function() return false end,
      screen = function() return fake.otherScreen end },
  }
  binding(fake, HYPER, "e").pressed()
  assertEqual(#fake.hintCalls, 1, "hints must be requested once")
  assertEqual(#fake.hintCalls[1], 1, "hints must be filtered to the pointer display")
  assertEqual(fake.hintStyle, "default", "hints must retain Hammerspoon's readable default placement")
  assertTrue(fake.api.debugStatus().hints, "hints must join the Hyper-held HUD lifecycle")
  tapKey(fake, KEY.a, HYPER_FLAGS)
  assertEqual(fake.hintProcessed, "a", "left-hand hint letters must route while Hyper is held")
  releaseHyper(fake)
  assertTrue(not fake.api.debugStatus().hints, "releasing Hyper must close window hints")
end)

run("app shortcut restores and focuses a running application", function()
  local fake = newFake("left", true)
  local calls = {}
  local window = {
    id = function() return 101 end,
    isMinimized = function() return true end,
    unminimize = function() table.insert(calls, "unminimize") end,
    raise = function() table.insert(calls, "raise") end,
    focus = function() table.insert(calls, "focus") end,
  }
  fake.runningApplicationsByName.Arc = {
    unhide = function() table.insert(calls, "unhide") end,
    activate = function(_, allWindows) table.insert(calls, "activate:" .. tostring(allWindows)) end,
    focusedWindow = function() return window end,
    mainWindow = function() return nil end,
    allWindows = function() return { window } end,
  }

  binding(fake, HYPER, "a").pressed()

  assertEqual(#fake.launches, 0, "running Arc must not receive a launch request")
  assertEqual(table.concat(calls, ","), "unhide,activate:true,unminimize,raise,focus",
    "existing window must be restored and focused")
end)

run("app shortcut launches an application only when it is not running", function()
  local fake = newFake("dual", true)
  binding(fake, HYPER, "t").pressed()
  assertEqual(#fake.bundleLaunches, 1, "absent kitty must receive one bundle launch request")
  assertEqual(fake.bundleLaunches[1], "net.kovidgoyal.kitty", "kitty must launch by stable bundle identifier")
end)

run("app shortcut launches ChatGPT by the installed Codex bundle identifier", function()
  local fake = newFake("left", true)
  binding(fake, HYPER, "c").pressed()
  assertEqual(fake.bundleLaunches[1], "com.openai.codex", "ChatGPT must not rely on a display name")
end)

run("window-follow ignores ordinary application activation", function()
  local fake = newFake("left", true)
  local window = followWindow(fake, 701, nil, fake.screen)
  local app = followApplication(fake, "Ordinary", "com.example.ordinary", 701, window)
  activateForFollow(fake, app)
  assertEqual(fake.followMoves or 0, 0,
    "Dock clicks, file opens, and unrelated activation must not pull a window")
end)

run("window-follow consumes one matching app-toggle activation", function()
  local fake = newFake("left", true)
  local window = followWindow(fake, 702, nil, fake.otherScreen)
  local app = followApplication(fake, "Arc", "company.thebrowser.Browser", 702, window)
  fake.runningApplicationsByName["company.thebrowser.Browser"] = app
  fake.runningApplicationsByName.Arc = app
  binding(fake, HYPER, "a").pressed()
  activateForFollow(fake, app)
  assertEqual(fake.followMoves, 1, "an app toggle must pull its selected window once")
  activateForFollow(fake, app)
  assertEqual(fake.followMoves, 1, "the app-toggle authorization must be single-use")
end)

run("window-follow keeps a launch authorization long enough for an app to open", function()
  local fake = newFake("left", true)
  local window = followWindow(fake, 708, nil, fake.otherScreen)
  local app = followApplication(fake, "ChatGPT", "com.openai.codex", 708, window)
  binding(fake, HYPER, "c").pressed()
  fake.now = 8
  activateForFollow(fake, app)
  assertEqual(fake.followMoves, 1, "a launched app must retain follow authorization while it starts")
end)

run("window-follow accepts switcher, Cmd+Tab, and window-hint intent only", function()
  local function makeTarget(fake, name, bundleID, id)
    local window = followWindow(fake, id, nil, fake.otherScreen)
    local app = followApplication(fake, name, bundleID, id, window)
    app.kind = function() return 0 end
    return app, window
  end

  local fake = newFake("left", true)
  local switched = makeTarget(fake, "Switcher", "com.example.switcher", 703)
  fake.hs.application.runningApplications = function() return { switched } end
  binding(fake, HYPER, "r").pressed()
  tapKey(fake, KEY.a, HYPER_FLAGS)
  activateForFollow(fake, switched)
  assertEqual(fake.followMoves, 1, "a running-app switcher selection must authorize follow")

  fake = newFake("left", true)
  local commandTabbed = makeTarget(fake, "CommandTab", "com.example.commandtab", 704)
  tapKey(fake, KEY.tab, { cmd = true })
  activateForFollow(fake, commandTabbed)
  assertEqual(fake.followMoves, 1, "Cmd+Tab must authorize the selected app activation")

  fake = newFake("left", true)
  local hinted, hintedWindow = makeTarget(fake, "Hinted", "com.example.hinted", 705)
  hintedWindow.screen = function() return fake.screen end
  fake.windows = { hintedWindow }
  binding(fake, HYPER, "e").pressed()
  hintedWindow.screen = function() return fake.otherScreen end
  tapKey(fake, KEY.a, HYPER_FLAGS)
  activateForFollow(fake, hinted)
  assertEqual(fake.followMoves, 1, "a Hyper+E hint selection must authorize its hinted window")
end)

run("window-follow intents expire and clear when their app terminates", function()
  local fake = newFake("left", true)
  local window = followWindow(fake, 706, nil, fake.otherScreen)
  local app = followApplication(fake, "Expiring", "com.example.expiring", 706, window)
  tapKey(fake, KEY.tab, { cmd = true })
  fake.now = 10
  activateForFollow(fake, app)
  assertEqual(fake.followMoves or 0, 0, "expired Cmd+Tab authorization must not pull")

  fake = newFake("left", true)
  window = followWindow(fake, 707, nil, fake.otherScreen)
  app = followApplication(fake, "Terminating", "com.example.terminating", 707, window)
  fake.runningApplicationsByName["company.thebrowser.Browser"] = app
  fake.runningApplicationsByName.Arc = app
  binding(fake, HYPER, "a").pressed()
  fake.now = 10
  fake.appWatcherCallback(app:name(), fake.hs.application.watcher.terminated, app)
  activateForFollow(fake, app)
  assertEqual(fake.followMoves or 0, 0, "termination must cancel that app's pending authorization")
end)

run("focused app shortcut minimizes its window in both modes", function()
  for _, mode in ipairs({ "dual", "left" }) do
    local fake = newFake(mode, true)
    local minimized = 0
    local window = {
      id = function() return 303 end,
      isMinimized = function() return false end,
      minimize = function() minimized = minimized + 1 end,
      raise = function() fail("focused window must not be raised") end,
      focus = function() fail("focused window must not be focused again") end,
    }
    fake.runningApplicationsByName.ChatGPT = {
      unhide = function() end,
      activate = function() end,
      focusedWindow = function() return window end,
      mainWindow = function() return window end,
      allWindows = function() return { window } end,
    }
    fake.focusedWindow = window

    binding(fake, HYPER, "c").pressed()

    assertEqual(minimized, 1, mode .. " mode must minimize the focused ChatGPT window")
    assertEqual(#fake.launches, 0, mode .. " mode must not launch focused ChatGPT")
  end
end)

run("mode switch reloads only after the transactional helper succeeds", function()
  local failed = newFake("left", false)
  assertTrue(not failed.api.setMode("dual"), "a failed helper must reject the mode switch")
  assertEqual(failed.api.getMode(), "left", "a failed helper must preserve the active mode")
  assertEqual(failed.reloads, 0, "a failed helper must not reload Hammerspoon")
  assertEqual(failed.writtenMode, nil, "Hammerspoon must never write the mode file itself")

  local fake = newFake("left", true)
  local reloadsBefore = fake.reloads
  binding(fake, HYPER, "tab").pressed()
  assertEqual(fake.api.getMode(), "dual", "a successful helper must switch the in-memory mode")
  local sawHelper = false
  for _, command in ipairs(fake.commands) do
    if command:find("set%-keyboard%-mode%.py dual", 1, false) then sawHelper = true end
  end
  assertTrue(sawHelper, "mode switch must run the keyboard-mode helper")
  assertTrue(fake.reloads > reloadsBefore, "mode switch must reload the configuration")
  assertEqual(fake.writtenMode, nil, "the helper owns persisted mode state")
end)

run("virtual Hyper modifiers do not block a layer trigger", function()
  local fake = newFake("left", true)
  fake.modifiers = { cmd = true, alt = true, ctrl = true, shift = true }
  binding(fake, HYPER, "x").pressed()
  assertEqual(fake.api.debugStatus().layer, "snap", "virtual modifiers must not prevent Hyper+X from opening")
  releaseHyper(fake)
end)

run("left hints use the requested alphabet", function()
  local fake = newFake("left", true)
  fake.windows = {
    { isStandard = function() return true end, isMinimized = function() return false end,
      screen = function() return fake.screen end },
  }
  binding(fake, HYPER, "e").pressed()
  assertEqual(table.concat(fake.hintChars, ""), "asdfqwerzxcv", "left hints must use the left-hand alphabet")
end)

print(testsRun - failures .. "/" .. testsRun .. " keyboard.lua mocked tests passed")
if failures > 0 then error(failures .. " keyboard test(s) failed") end
