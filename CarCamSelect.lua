---@ext:basic

local BTN_F0 = const(ui.ButtonFlags.PressedOnClick)
local BTN_FA = const(bit.bor(ui.ButtonFlags.Active, ui.ButtonFlags.PressedOnClick))
local BTN_FN = const(function(active) return active and BTN_FA or BTN_F0 end)

local sim = ac.getSim()

local controlsConfig = ac.INIConfig.controlsConfig()
local controlsBindings = {}

local function bindingInfoGen(section)
  local pieces = section:split(';')
  if #pieces > 1 then
    local r = {}
    for _, v in ipairs(pieces) do
      local p = string.split(v, ':', 2, true)
      local i = bindingInfoGen(p[2])
      if string.regfind(i, '^(?:Not |Keyboard:|Gamepad:)') then i = i:sub(1, 1):lower() .. i:sub(2) end
      r[#r + 1] = p[1] .. ': ' .. i:replace('\n', '\n\t')
    end
    return table.concat(r, '\n')
  end

  local entries = {}
  local baseSection = section
  section = string.reggsub(section, '\\W+', '')

  if baseSection:endsWith('$') then
    return 'Keyboard: ' .. baseSection:sub(1, #baseSection - 1)
  end
  if section:startsWith('_') or sim.inputMode == ac.UserInputMode.Keyboard or controlsConfig:get('ADVANCED', 'COMBINE_WITH_KEYBOARD_CONTROL', true) then
    local k = controlsConfig:get(section, 'KEY', -1)
    if k > 0 then
      local modifiers = table.map(controlsConfig:get(section, 'KEY_MODIFICATOR', nil) or {}, function(v)
        if v == '' then return nil end
        if tonumber(v) == 16 then return 'Shift' end
        if tonumber(v) == 17 then return 'Ctrl' end
        if tonumber(v) == 18 then return 'Alt' end
        return '<' .. v .. '>'
      end)
      if #modifiers == 0 and baseSection:endsWith('!') then
        table.insert(modifiers, 'Ctrl')
      end

      local m
      for n, v in pairs(ac.KeyIndex) do
        if v == k then
          m = n
          break
        end
      end

      table.insert(modifiers, m or string.char(k))
      entries[#entries + 1] = 'Keyboard: ' .. table.concat(modifiers, '+')
    end
  end

  if sim.inputMode == ac.UserInputMode.Gamepad then
    local x = controlsConfig:get(section, 'XBOXBUTTON', '')
    if x ~= '' and (tonumber(x) or 1) > 0 then
      entries[#entries + 1] = 'Gamepad: ' .. x
    end
  end

  local j = controlsConfig:get(section, 'JOY', -1)
  if j >= 0 then
    local n = controlsConfig:get('CONTROLLERS', 'CON' .. j, 'Unknown device')
    local d = controlsConfig:get(section, 'BUTTON', -1)
    if d >= 0 and (tonumber(x) or 1) > 0 then
      -- if #n > 28 then n = n:sub(1, 27)..'…' end
      local m = controlsConfig:get(section, 'BUTTON_MODIFICATOR', -1)
      if m >= 0 then
        entries[#entries + 1] = n .. ': buttons #' .. (m + 1) .. '+' .. (d + 1)
      else
        entries[#entries + 1] = n .. ': button #' .. (d + 1)
      end
    else
      local p = controlsConfig:get(section, '__CM_POV', -1)
      if p >= 0 then
        local dir = { [0] = '←', [1] = '↑', [2] = '→', [3] = '↓' }
        entries[#entries + 1] = n .. ': D-pad #' .. (p + 1) ..
            (dir[controlsConfig:get(section, '__CM_POV_DIR', -1)] or '')
      end
    end
  end

  if #entries == 0 then
    return 'Not bound to anything'
  else
    return table.concat(entries, '\n')
  end
end

local function bindingInfo(section)
  return table.getOrCreate(controlsBindings, section, bindingInfoGen, section)
end

local function bindingInfoTooltip(section, prefix)
  if ui.itemHovered() then
    ui.tooltip(function()
      if prefix then
        ui.pushFont(ui.Font.Main)
        ui.textWrapped(prefix, 500)
        ui.popFont()
        ui.offsetCursorY(4)
      end
      ui.pushFont(ui.Font.Small)
      ui.textWrapped(bindingInfo(section), 500)
      ui.popFont()
    end)
  end
end

local controls = ac.overrideCarControls()

local btnAutofill = vec2(-0.1, 0)

local lastCarCamera = ac.CameraMode.Cockpit

local function selectNextDriveableCamera()
  if sim.cameraMode == ac.CameraMode.Cockpit then
    ac.setCurrentCamera(ac.CameraMode.Drivable)
    ac.setCurrentDrivableCamera(ac.DrivableCamera.Chase)
  elseif sim.cameraMode ~= ac.CameraMode.Drivable or sim.driveableCameraMode == ac.DrivableCamera.Dash then
    ac.setCurrentCamera(ac.CameraMode.Cockpit)
  else
    ac.setCurrentDrivableCamera((sim.driveableCameraMode + 1) % 5)
  end
end

local function blockView()
  ui.pushStyleVar(ui.StyleVar.FramePadding, vec2(0, 4))
  local w2 = (ui.availableSpaceX() - 4) / 2

  ui.setNextItemIcon(ui.Icons.VideoCamera)
  if ui.button('Camera', vec2(w2, 0), BTN_F0) then
    if controls:active() then
      controls.changeCamera = true
    else
      selectNextDriveableCamera()
    end
  end
  bindingInfoTooltip('F1$', 'Switch to the next driving camera')

  if sim.cameraMode == ac.CameraMode.Cockpit or sim.cameraMode == ac.CameraMode.Drivable then
    lastCarCamera = sim.cameraMode
  else
    ui.pushDisabled()
  end
  if sim.cameraMode ~= ac.CameraMode.Cockpit and sim.cameraMode ~= ac.CameraMode.Drivable then
    ui.popDisabled()
  end
  ui.sameLine(0, 4)
  if ui.button('Free', vec2(w2, 0), BTN_FN(sim.cameraMode == ac.CameraMode.Free)) then
    if sim.cameraMode == ac.CameraMode.Free then
      ac.setCurrentCamera(lastCarCamera)
    else
      ac.setCurrentCamera(ac.CameraMode.Free)
    end
  end
  bindingInfoTooltip('F7 (if enabled in AC system settings)$',
    'Enable free camera (use right mouse button to look around, arrows to move the camera, hold Control and Shift to alter camera speed)')
  if ui.button('Orbit', vec2(w2, 0), BTN_FN(sim.cameraMode == ac.CameraMode.OnBoardFree)) then
    if sim.cameraMode == ac.CameraMode.OnBoardFree then
      ac.setCurrentCamera(lastCarCamera)
    else
      ac.setCurrentCamera(ac.CameraMode.OnBoardFree)
    end
  end
  bindingInfoTooltip('F5$', 'Fixed camera moving relative to the car')
  ui.sameLine(0, 4)
  if ui.button('Heli', vec2(w2, 0), BTN_FN(sim.cameraMode == ac.CameraMode.Helicopter)) then
    if sim.cameraMode == ac.CameraMode.Helicopter then
      ac.setCurrentCamera(lastCarCamera)
    else
      ac.setCurrentCamera(ac.CameraMode.Helicopter)
    end
  end
  bindingInfoTooltip('top down "helicopter" view$', 'Helicopter Camera')

  if sim.isVRConnected then
    ui.button('Reset VR', btnAutofill)
    if ui.itemActive() then ac.resetVRPose() end
    bindingInfoTooltip('Ctrl+Space$', 'Reset VR orientation')
  end
  if ui.button('Track', vec2(w2, 0), BTN_FN(sim.cameraMode == ac.CameraMode.Track)) then
    if sim.cameraMode == ac.CameraMode.Track then
      ac.setCurrentCamera(lastCarCamera)
    else
      ac.setCurrentCamera(ac.CameraMode.Track)
    end
  end
  bindingInfoTooltip('you have to use the keybind F3 to change camera sets$', 'Focus Track Camera')
  ui.sameLine(0, 4)
  if ui.button('Car', vec2(w2, 0), BTN_FN(sim.cameraMode == ac.CameraMode.Car)) then
    if sim.cameraMode == ac.CameraMode.Car then
      ac.setCurrentCarCamera((sim.carCameraIndex + 1) % 6)
    else
      ac.setCurrentCamera(ac.CameraMode.Car)
    end
  end
  bindingInfoTooltip('F6$', 'A few custom preconfigured cameras positioned relative to the car')

  ui.popStyleVar()
end

local function blockCars()
  local w3 = (ui.availableSpaceX() - 8) / 3
  local w4 = (sim.carsCount * 18)
  local w6 = (sim.carsCount * 18) / 2

  ui.pushFont(ui.Font.Small)
  ui.pushStyleVar(ui.StyleVar.FramePadding, vec2(0, 4))
  if ui.button('Previous', vec2(w3, 0), BTN_F0) then
    ac.trySimKeyPressCommand('Previous Car')
  end
  bindingInfoTooltip('PREVIOUS_CAR!', 'Focus on the previous car in the list')
  ui.sameLine(0, 4)
  if ui.button('Own', vec2(w3, 0), BTN_F0) then
    ac.trySimKeyPressCommand('Player Car')
  end
  bindingInfoTooltip('PLAYER_CAR!', 'Focus on your car')
  ui.sameLine(0, 4)
  if ui.button('Next', vec2(w3, 0), BTN_F0) then
    ac.trySimKeyPressCommand('Next Car')
  end
  bindingInfoTooltip('NEXT_CAR!', 'Focus on the next car in the list')
  ui.popFont()
  ui.popStyleVar()

  if sim.carsCount < 48 then
    ui.childWindow('cars', vec2(-0.1, w4), function()
      for i = 0, sim.carsCount - 1 do
        ui.pushID(i)
        ui.pushStyleColor(ui.StyleColor.Text, ac.DriverTags(ac.getDriverName(i)).color)
        if ui.selectable(string.format(' %d. %s', i + 1, ac.getDriverName(i)), sim.focusedCar == i) then
          ac.focusCar(i)
        end
        ui.popID()
        ui.popStyleColor()
      end
    end)
  else
    ui.childWindow('cars', vec2(-0.1, w6), function()
      for i = 0, sim.carsCount - 1 do
        ui.pushID(i)
        ui.pushStyleColor(ui.StyleColor.Text, ac.DriverTags(ac.getDriverName(i)).color)
        if ui.selectable(string.format(' %d. %s', i + 1, ac.getDriverName(i)), sim.focusedCar == i) then
          ac.focusCar(i)
        end
        ui.popID()
        ui.popStyleColor()
      end
    end)
  end
end

local function blockReplay()
  if ui.button('Previous lap', btnAutofill, BTN_F0) then
    ac.trySimKeyPressCommand('Previous Lap')
  end
  bindingInfoTooltip('PREVIOUS_LAP!', 'Rewind to the previous lap')
  if ui.button('Next lap', btnAutofill, BTN_F0) then
    ac.trySimKeyPressCommand('Next Lap')
  end
  bindingInfoTooltip('NEXT_LAP!', 'Rewind to the next lap')
end

function script.windowMain(dt)
  if sim.carsCount > 1 then
    ui.offsetCursorY(12)
    ui.header('Cars')
    blockCars()
  end

  if ui.availableSpaceY() > 16 then
    ui.offsetCursorY(12)
    ui.header('Camera')
    blockView()
  end

  if ui.availableSpaceY() > 16 then
    if sim.isReplayActive then
      ui.offsetCursorY(12)
      ui.header('Replay')
      blockReplay()
    end
  end

  if not ui.windowResizing() then
    local h = ui.getCursorY() + 16
    ac.setWindowSizeConstraints('main', vec2(200, h), vec2(200, h))
  else
    ac.setWindowSizeConstraints('main', vec2(200, 80), vec2(200, 900))
  end
end
