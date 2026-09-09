-- Run without touching the live Hammerspoon configuration:
--   hs -c 'dofile("/Users/droy-/.cline/data/workspaces/chat/keyboard-only-setup/tests/test_keyboard.lua")'

local KEYBOARD = "/Users/droy-/.hammerspoon/keyboard.lua"
local HYPER = { "alt", "cmd", "ctrl", "shift" }

local function fail(message)
  error(message, 2)
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

local function newFake(mode, helperSucceeds)
  local fake = {
    alerts = {},
    bindings = {},
    canvases = {},
    commands = {},
    keyStrokes = {},
    launches = {},
    bundleLaunches = {},
    reloads = 0,
    runningApplicationsByName = {},
    scrolls = 0,
    modifiers = {},
    helperSucceeds = helperSucceeds,
    mode = mode,
  }

  local function timer()
    return { stop = function() end, start = function() end }
  end

  local hs = {
    configdir = "/tmp/keyboard-test",
    hotkey = {}, timer = {}, alert = {}, application = {}, image = {}, hints = {},
    mouse = {}, screen = { watcher = {} }, canvas = {}, eventtap = { event = {} }, audiodevice = {},
    brightness = {}, json = {}, fs = {}, osascript = {}, spaces = { watcher = {} },
    window = {}, menubar = {}, geometry = {},
  }
  fake.hs = hs

  function hs.hotkey.bind(mods, key, pressed, released, repeated)
    local binding = {
      mods = sorted(mods), key = key, pressed = pressed, released = released,
      repeated = repeated, disabled = false,
    }
    function binding:disable() self.disabled = true end
    function binding:delete() self.disabled = true; self.deleted = true end
    function binding:enable() self.disabled = false end
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
  function hs.alert.show(message) table.insert(fake.alerts, message) end
  function hs.application.runningApplications() return {} end
  function hs.application.frontmostApplication() return nil end
  function hs.application.launchOrFocus(name) table.insert(fake.launches, name) end
  function hs.application.launchOrFocusByBundleID(bundleID) table.insert(fake.bundleLaunches, bundleID) end
  function hs.application.get(name) return fake.runningApplicationsByName[name] end
  function hs.application.applicationForPID() return nil end
  function hs.image.imageFromAppBundle() return nil end
  function hs.hints.windowHints() fake.hintChars = hs.hints.hintChars; fake.hintStyle = hs.hints.style end
  function hs.mouse.getCurrentScreen() return fake.screen end
  function hs.screen.mainScreen() return fake.screen end
  fake.screen = { frame = function() return { x = 100, y = 50, w = 1200, h = 800 } end }
  function hs.screen.watcher.new() return timer() end
  function hs.canvas.new(frame)
    local canvas = { frameValue = frame, elements = {}, visible = false }
    function canvas:level() return self end
    function canvas:clickActivating() return self end
    function canvas:frame(value) if value then self.frameValue = value end return self.frameValue end
    function canvas:show() self.visible = true end
    function canvas:hide() self.visible = false end
    function canvas:replaceElements(elements) self.elements = elements end
    table.insert(fake.canvases, canvas)
    return canvas
  end
  function hs.eventtap.checkKeyboardModifiers() return fake.modifiers end
  function hs.eventtap.keyStroke(mods, key) table.insert(fake.keyStrokes, { mods = sorted(mods), key = key }) end
  function hs.eventtap.leftClick() end
  function hs.eventtap.rightClick() end
  function hs.eventtap.event.newScrollEvent()
    return { post = function() fake.scrolls = fake.scrolls + 1 end }
  end
  function hs.timer.doEvery() return timer() end
  function hs.timer.doAfter(delay, callback)
    if delay < 0.1 then callback() end
    return timer()
  end
  function hs.timer.usleep() end
  function hs.timer.secondsSinceEpoch() return 1 end
  function hs.audiodevice.defaultOutputDevice()
    return { volume = function() return 50 end, setVolume = function() end }
  end
  function hs.brightness.get() return 50 end
  function hs.brightness.set() return true end
  function hs.json.write() end
  function hs.json.read() return {} end
  function hs.fs.attributes() return nil end
  function hs.osascript.applescript() return true, "" end
  function hs.spaces.watcher.new() return timer() end
  function hs.window.allWindows() return {} end
  function hs.window.focusedWindow() return fake.focusedWindow end
  function hs.menubar.new()
    return { setTitle = function() end, setMenu = function() end }
  end
  function hs.geometry.rect(x, y, w, h) return { x = x, y = y, w = w, h = h } end

  local realOpen = io.open
  local fakeIo = {}
  function fakeIo.open(path, access)
    if path == "/Users/droy-/.config/keyboard-mode" and access == "r" then
      if not fake.mode then return nil end
      return { read = function() return fake.mode end, close = function() end }
    end
    if path == "/Users/droy-/.config/keyboard-mode" and access == "w" then
      return { write = function(_, value) fake.mode = value end, close = function() end }
    end
    return realOpen(path, access)
  end

  local env = setmetatable({ hs = hs, io = fakeIo }, { __index = _G })
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
end

local function activeBindingCount(fake, mods)
  local count = 0
  local requested = sorted(mods)
  for _, candidate in ipairs(fake.bindings) do
    if candidate.mods == requested and not candidate.disabled then count = count + 1 end
  end
  return count
end

local function run(name, fn)
  local ok, err = pcall(fn)
  if not ok then
    io.stderr:write("FAIL " .. name .. ": " .. tostring(err) .. "\n")
    error(err, 0)
  end
  print("PASS " .. name)
end

run("Hyper+G reaches the top-level grid and paints canvas-local coordinates", function()
  local fake = newFake("dual", true)
  assertTrue(type(fake.api.gridShow) == "function", "gridShow must be exported and top-level")
  binding(fake, HYPER, "g").pressed()
  assertEqual(fake.canvases[1].elements[1].frame.x, 500, "grid rectangle must be local to its canvas")
  assertEqual(fake.canvases[1].elements[1].frame.y, 300, "grid rectangle must be local to its canvas")
end)

run("left mode exposes every relocated Hammerspoon action", function()
  local fake = newFake("left", true)
  for _, key in ipairs({ "5", "4", "`", "escape", "q", "z", "1", "2", "x", "3" }) do
    binding(fake, HYPER, key)
  end
  for _, key in ipairs({ "w", "a", "s", "d" }) do binding(fake, { "alt", "ctrl" }, key) end
  binding(fake, HYPER, "g").pressed()
  for _, key in ipairs({ "a", "s", "w", "d", "g", "c", "f", "x" }) do binding(fake, {}, key) end
end)

run("both modes expose the complete app map and workflow reference", function()
  for _, mode in ipairs({ "dual", "left" }) do
    local fake = newFake(mode, true)
    for _, key in ipairs({ "a", "c", "f", "t" }) do binding(fake, HYPER, key) end
    binding(fake, HYPER, "/")
    binding(fake, HYPER, "`")
  end
end)

run("workflow reference toggles open and closed", function()
  local fake = newFake("left", true)
  fake.api.showCheatsheet()
  assertTrue(fake.canvases[#fake.canvases].visible, "workflow reference must open")
  fake.api.showCheatsheet()
  assertTrue(not fake.canvases[#fake.canvases].visible, "workflow reference must close on repeat")
end)

run("layer shortcuts open without depending on synthetic Hyper modifier state", function()
  for _, mode in ipairs({ "left", "dual" }) do
    local fake = newFake(mode, true)
    binding(fake, HYPER, "x").pressed()
    assertTrue(fake.api.debugStatus().layer ~= nil, "Hyper+X must open its layer in " .. mode)

    binding(fake, HYPER, "3").pressed()
    assertTrue(fake.api.debugStatus().layer ~= nil, "Hyper+3 must open navigation in " .. mode)
  end
end)

run("app shortcut restores and focuses an existing window without launching", function()
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

run("Finder-terminal shortcut focuses running kitty instead of opening another window", function()
  local fake = newFake("left", true)
  local focused = 0
  local window = {
    id = function() return 202 end,
    isMinimized = function() return false end,
    raise = function() end,
    focus = function() focused = focused + 1 end,
  }
  fake.runningApplicationsByName.kitty = {
    unhide = function() end,
    activate = function() end,
    focusedWindow = function() return window end,
    mainWindow = function() return nil end,
    allWindows = function() return { window } end,
  }

  binding(fake, HYPER, "w").pressed()

  assertEqual(focused, 1, "running kitty window must be focused")
  for _, command in ipairs(fake.commands) do
    assertTrue(not command:find("open %-na kitty"), "running kitty must not receive a new-window command")
  end
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

run("grid re-entry disables the old key layer and left grid uses WASD", function()
  local fake = newFake("left", true)
  fake.api.gridShow()
  local firstMovement = binding(fake, {}, "a")
  local firstLayer = activeBindingCount(fake, {})
  fake.api.gridShow()
  assertEqual(activeBindingCount(fake, {}), firstLayer, "reopening grid must not leave duplicate active bindings")
  assertTrue(firstMovement.deleted, "reopening grid must delete old transient handlers")
  local ok = pcall(function() binding(fake, {}, "h") end)
  assertTrue(not ok, "left grid must not use vim keys")
  fake.api.gridHide()
  assertEqual(activeBindingCount(fake, {}), 0, "grid hide must clean up its key layer")
end)

run("mode toggle reloads only after the helper succeeds", function()
  local failed = newFake("dual", false)
  assertTrue(not failed.api.setMode("left"), "failed helper must report failure")
  assertEqual(failed.api.getMode(), "dual", "failed helper must preserve mode")
  assertEqual(failed.reloads, 0, "failed helper must not reload")

  local succeeded = newFake("dual", true)
  assertTrue(succeeded.api.setMode("left"), "successful helper must report success")
  assertEqual(succeeded.api.getMode(), "left", "successful helper must update mode")
  assertEqual(succeeded.reloads, 1, "successful helper must reload")
end)

run("left navigation layer exits cleanly and scrolling has a repeat callback", function()
  local fake = newFake("left", true)
  binding(fake, HYPER, "g").pressed()
  assertTrue(fake.api.debugStatus().grid, "grid must be active before navigation opens")
  binding(fake, HYPER, "3").pressed()
  assertEqual(fake.api.debugStatus().layer, "navigation", "hyper+3 must enter navigation layer")
  assertTrue(not fake.api.debugStatus().grid, "navigation must clear the grid before registering raw keys")
  local backspace = binding(fake, {}, "q")
  assertTrue(type(backspace.repeated) == "function", "navigation backspace must repeat")
  backspace.pressed()
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "delete", "navigation Q must emit backspace, not Q")
  local up = binding(fake, {}, "w")
  assertTrue(type(up.repeated) == "function", "navigation arrows must repeat")
  up.repeated()
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "up", "navigation W must emit up arrow")
  binding(fake, {}, "e").pressed()
  assertEqual(fake.api.debugStatus().layer, nil, "navigation Return must exit before confirming")

  binding(fake, HYPER, "3").pressed()
  binding(fake, {}, "escape").pressed()
  assertEqual(fake.api.debugStatus().layer, nil, "escape must leave navigation layer")
  assertEqual(activeBindingCount(fake, {}), 0, "leaving layer must restore ordinary typing")

  local scroll = binding(fake, { "alt", "ctrl" }, "w")
  assertTrue(type(scroll.repeated) == "function", "scroll binding needs an explicit repeat callback")
  scroll.pressed()
  scroll.repeated()
  assertEqual(fake.scrolls, 2, "press and repeat must both scroll")
end)

run("left snap layer captures commands as one-shot target keys", function()
  local fake = newFake("left", true)
  binding(fake, HYPER, "x").pressed()
  assertEqual(fake.api.debugStatus().layer, "snap", "hyper+X must enter snap layer")
  binding(fake, {}, "v").pressed()
  assertEqual(fake.api.debugStatus().layer, nil, "snap commands must close their layer first")
  assertEqual(fake.keyStrokes[#fake.keyStrokes].mods, "cmd", "snap V must emit Command")
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "h", "snap V must hide the application")
end)

run("dual mode owns the complete direct snap map", function()
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
    [";"] = { 0, 0, 1, 1 }, ["'"] = { 0.15, 0.10, 0.70, 0.80 },
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

run("dual mode exposes a Hyper+X snap help layer", function()
  local fake = newFake("dual", true)
  binding(fake, HYPER, "x").pressed()
  assertEqual(fake.api.debugStatus().layer, "dual-snap", "Hyper+X must open the dual snap layer")
  binding(fake, {}, "h").pressed()
  assertEqual(fake.api.debugStatus().layer, nil, "dual snap selection must close its layer")
end)

run("dual mode exposes a Hyper+3 navigation help layer with HJKL arrows", function()
  local fake = newFake("dual", true)
  binding(fake, HYPER, "3").pressed()
  assertEqual(fake.api.debugStatus().layer, "dual-navigation", "Hyper+3 must open the dual navigation layer")
  binding(fake, {}, "h").pressed()
  assertEqual(fake.keyStrokes[#fake.keyStrokes].key, "left", "dual navigation H must emit left arrow")
  binding(fake, {}, "escape").pressed()
  assertEqual(fake.api.debugStatus().layer, nil, "escape must leave dual navigation")
end)

run("virtual Hyper modifiers do not block a layer trigger", function()
  local fake = newFake("left", true)
  fake.modifiers = { cmd = true, alt = true, ctrl = true, shift = true }
  binding(fake, HYPER, "x").pressed()
  assertEqual(fake.api.debugStatus().layer, "snap", "virtual modifiers must not prevent Hyper+X from opening")
  assertTrue(activeBindingCount(fake, {}) > 0, "the snap layer must bind its target keys")
end)

run("left hints use the requested alphabet and non-vimperator style", function()
  local fake = newFake("left", true)
  binding(fake, HYPER, "e").pressed()
  assertEqual(table.concat(fake.hintChars, ""), "asdfqwerzxcv", "left hints must use the left-hand alphabet")
  assertEqual(fake.hintStyle, nil, "left hints must not use vimperator style")
end)

print("keyboard.lua mocked tests passed")
