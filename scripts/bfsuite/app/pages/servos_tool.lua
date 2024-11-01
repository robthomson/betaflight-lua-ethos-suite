local labels = {}
local fields = {}

local inFocus = false
local triggerOverRide = false
local triggerOverRideAll = false
local triggerCenterChange = false
local currentServoCenter
local lastSetServoCenter
local lastServoChangeTime = os.clock()
local servoIndex = bfsuite.currentServoIndex - 1
local isSaving = false
local enableWakeup = false

local servoTable
local servoCount
local configs = {}

local function servoCenterFocusAllOn(self)

    bfsuite.app.audio.playServoOverideEnable = true

    for i = 0, #configs do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        bfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)
        bfsuite.bg.msp.mspQueue:add(message)
    end
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusAllOff(self)

    for i = 0, #configs do
        local message = {
            command = 193, -- MSP_SET_SERVO_OVERRIDE
            payload = {i}
        }
        bfsuite.bg.msp.mspHelper.writeU16(message.payload, 2001)
        bfsuite.bg.msp.mspQueue:add(message)
    end
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusOff(self)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = {servoIndex}
    }
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, 2001)
    bfsuite.bg.msp.mspQueue:add(message)
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
end

local function servoCenterFocusOn(self)
    local message = {
        command = 193, -- MSP_SET_SERVO_OVERRIDE
        payload = {servoIndex}
    }
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)
    bfsuite.bg.msp.mspQueue:add(message)
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
    bfsuite.app.triggers.closeProgressLoader = true
end

local function saveServoSettings(self)

    local servoCenter = math.floor(configs[servoIndex]['mid'])
    local servoMin = math.floor(configs[servoIndex]['min'])
    local servoMax = math.floor(configs[servoIndex]['max'])
    local servoScaleNeg = math.floor(configs[servoIndex]['scaleNeg'])
    local servoScalePos = math.floor(configs[servoIndex]['scalePos'])
    local servoRate = math.floor(configs[servoIndex]['rate'])
    local servoSpeed = math.floor(configs[servoIndex]['speed'])
    local servoFlags = math.floor(configs[servoIndex]['flags'])
    local servoReverse = math.floor(configs[servoIndex]['reverse'])
    local servoGeometry = math.floor(configs[servoIndex]['geometry'])

    if servoReverse == 0 and servoGeometry == 0 then
        servoFlags = 0
    elseif servoReverse == 1 and servoGeometry == 0 then
        servoFlags = 1
    elseif servoReverse == 0 and servoGeometry == 1 then
        servoFlags = 2
    elseif servoReverse == 1 and servoGeometry == 1 then
        servoFlags = 3
    end

    local message = {
        command = 212, -- MSP_SET_SERVO_CONFIGURATION
        payload = {}
    }
    bfsuite.bg.msp.mspHelper.writeU8(message.payload, servoIndex)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoCenter)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoMin)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoMax)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoScaleNeg)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoScalePos)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoRate)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoSpeed)
    bfsuite.bg.msp.mspHelper.writeU16(message.payload, servoFlags)

    if bfsuite.config.mspTxRxDebug == true or bfsuite.config.logEnable == true then
        local logData = "{" .. bfsuite.utils.joinTableItems(message.payload, ", ") .. "}"

        bfsuite.utils.log(logData)

        if bfsuite.config.mspTxRxDebug == true then print(logData) end

    end
    bfsuite.bg.msp.mspQueue:add(message)

    -- write change to epprom
    local mspEepromWrite = {command = 250, simulatorResponse = {}}
    bfsuite.bg.msp.mspQueue:add(mspEepromWrite)

end

local function onSaveMenuProgress()
    bfsuite.app.ui.progressDisplay("Saving", "Saving data...")
    saveServoSettings()
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
end

local function onSaveMenu()
    local buttons = {
        {
            label = "                OK                ",
            action = function()
                bfsuite.app.audio.playSaving = true
                isSaving = true

                return true
            end
        }, {
            label = "CANCEL",
            action = function()
                return true
            end
        }
    }
    local theTitle = "Save settings"
    local theMsg = "Save current page to flight controller?"

    form.openDialog({
        width = nil,
        title = theTitle,
        message = theMsg,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

    bfsuite.app.triggers.triggerSave = false
end

local function onNavMenu(self)

    bfsuite.app.ui.progressDisplay()
    bfsuite.app.ui.openPage(bfsuite.app.lastIdx, bfsuite.app.lastTitle, "servos.lua", bfsuite.config.servoOverride)

end

local function wakeup(self)

    if enableWakeup == true then

        if isSaving == true then
            onSaveMenuProgress()
            isSaving = false
        end

        -- filter changes to servo center - essentially preventing queue getting flooded        
        if bfsuite.config.servoOverride == true then

            currentServoCenter = configs[servoIndex]['mid']

            local now = os.clock()
            local settleTime = 0.85
            if ((now - lastServoChangeTime) >= settleTime) and bfsuite.bg.msp.mspQueue:isProcessed() then
                if currentServoCenter ~= lastSetServoCenter then
                    lastSetServoCenter = currentServoCenter
                    lastServoChangeTime = now
                    self.saveServoSettings(self)
                end
            end

        end
    end

    if triggerOverRide == true then
        triggerOverRide = false

        if bfsuite.config.servoOverride == false then
            bfsuite.app.audio.playServoOverideEnable = true
            bfsuite.app.ui.progressDisplay("Servo override", "Enabling servo override...")
            bfsuite.app.Page.servoCenterFocusAllOn(self)
            bfsuite.config.servoOverride = true

            bfsuite.app.formFields[3]:enable(false)
            bfsuite.app.formFields[4]:enable(false)
            bfsuite.app.formFields[5]:enable(false)
            bfsuite.app.formFields[6]:enable(false)
            bfsuite.app.formFields[7]:enable(false)
            bfsuite.app.formFields[8]:enable(false)
            bfsuite.app.formFields[9]:enable(false)
            bfsuite.app.formFields[10]:enable(false)
            bfsuite.app.formNavigationFields['save']:enable(false)

        else

            bfsuite.app.audio.playServoOverideDisable = true
            bfsuite.app.ui.progressDisplay("Servo override", "Disabling servo override...")
            bfsuite.app.Page.servoCenterFocusAllOff(self)
            bfsuite.config.servoOverride = false

            bfsuite.app.formFields[3]:enable(true)
            bfsuite.app.formFields[4]:enable(true)
            bfsuite.app.formFields[5]:enable(true)
            bfsuite.app.formFields[6]:enable(true)
            bfsuite.app.formFields[7]:enable(true)
            bfsuite.app.formFields[8]:enable(true)
            bfsuite.app.formFields[9]:enable(true)
            bfsuite.app.formFields[10]:enable(true)
            bfsuite.app.formNavigationFields['save']:enable(true)
        end
    end

end

local function getServoConfigurations(callback, callbackParam)
    local message = {
        command = 120, -- MSP_SERVO_CONFIGURATIONS
        processReply = function(self, buf)
            servoCount = bfsuite.bg.msp.mspHelper.readU8(buf)

            -- update master one in case changed
            bfsuite.config.servoCount = servoCount

            -- print("Servo count "..tostring(servoCount))
            for i = 0, servoCount - 1 do
                local config = {}

                config.name = servoTable[servoIndex + 1]['title']
                config.mid = bfsuite.bg.msp.mspHelper.readU16(buf)
                config.min = bfsuite.bg.msp.mspHelper.readS16(buf)
                config.max = bfsuite.bg.msp.mspHelper.readS16(buf)
                config.scaleNeg = bfsuite.bg.msp.mspHelper.readU16(buf)
                config.scalePos = bfsuite.bg.msp.mspHelper.readU16(buf)
                config.rate = bfsuite.bg.msp.mspHelper.readU16(buf)
                config.speed = bfsuite.bg.msp.mspHelper.readU16(buf)
                config.flags = bfsuite.bg.msp.mspHelper.readU16(buf)

                if config.flags == 1 or config.flags == 3 then
                    config.reverse = 1
                else
                    config.reverse = 0
                end

                if config.flags == 2 or config.flags == 3 then
                    config.geometry = 1
                else
                    config.geometry = 0
                end

                configs[i] = config

            end
            callback(callbackParam)
        end,
        -- 2 servos
        -- simulatorResponse = {
        --        2,
        --        220, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0,
        --        221, 5, 68, 253, 188, 2, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
        -- }
        -- 4 servos
        simulatorResponse = {
            4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0,
            120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
        }
    }
    bfsuite.bg.msp.mspQueue:add(message)
end

local function getServoConfigurationsEnd(callbackParam)
    bfsuite.app.triggers.isReady = true
    bfsuite.app.triggers.closeProgressLoader = true
    enableWakeup = true
end

local function openPage(idx, title, script, extra1)

    if extra1 ~= nil then
        servoTable = extra1
        bfsuite.servoTableLast = servoTable
    else
        if bfsuite.servoTableLast ~= nil then servoTable = bfsuite.servoTableLast end
    end

    configs = {}
    configs[servoIndex] = {}
    configs[servoIndex]['name'] = servoTable[servoIndex + 1]['title']
    configs[servoIndex]['mid'] = 0
    configs[servoIndex]['min'] = 0
    configs[servoIndex]['max'] = 0
    configs[servoIndex]['scaleNeg'] = 0
    configs[servoIndex]['scalePos'] = 0
    configs[servoIndex]['rate'] = 0
    configs[servoIndex]['speed'] = 0
    configs[servoIndex]['flags'] = 0
    configs[servoIndex]['geometry'] = 0
    configs[servoIndex]['reverse'] = 0

    bfsuite.app.formLines = {}

    bfsuite.app.lastIdx = idx
    bfsuite.app.lastTitle = title
    bfsuite.app.lastScript = script

    form.clear()

    if bfsuite.app.Page.pageTitle ~= nil then
        bfsuite.app.ui.fieldHeader(bfsuite.app.Page.pageTitle .. " / " .. bfsuite.utils.titleCase(configs[servoIndex]['name']))
    else
        bfsuite.app.ui.fieldHeader(title .. " / " .. bfsuite.utils.titleCase(configs[servoIndex]['name']))
    end

    if bfsuite.app.Page.headerLine ~= nil then
        local headerLine = form.addLine("")
        local headerLineText = form.addStaticText(headerLine, {x = 0, y = bfsuite.app.radio.linePaddingTop, w = bfsuite.config.lcdWidth, h = bfsuite.app.radio.navbuttonHeight},
                                                  bfsuite.app.Page.headerLine)
    end

    if bfsuite.config.servoOverride == true then bfsuite.app.formNavigationFields['save']:enable(false) end

    if configs[servoIndex]['mid'] ~= nil then

        local idx = 2
        local minValue = 50
        local maxValue = 2250
        local defaultValue = 1500
        local suffix = nil
        local helpTxt = bfsuite.app.fieldHelpTxt['servoMid']['t']

        bfsuite.app.formLines[idx] = form.addLine("Center")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['mid']
        end, function(value)
            configs[servoIndex]['mid'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
    end

    if configs[servoIndex]['min'] ~= nil then
        local idx = 3
        local minValue = -1000
        local maxValue = 1000
        local defaultValue = -700
        local suffix = nil
        bfsuite.app.formLines[idx] = form.addLine("Minimum")
        local helpTxt = bfsuite.app.fieldHelpTxt['servoMin']['t']
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['min']
        end, function(value)
            configs[servoIndex]['min'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['max'] ~= nil then
        local idx = 4
        local minValue = -1000
        local maxValue = 1000
        local defaultValue = 700
        local suffix = nil
        local helpTxt = bfsuite.app.fieldHelpTxt['servoMax']['t']
        bfsuite.app.formLines[idx] = form.addLine("Maximum")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['max']
        end, function(value)
            configs[servoIndex]['max'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['scaleNeg'] ~= nil then
        local idx = 5
        local minValue = 100
        local maxValue = 1000
        local defaultValue = 500
        local suffix = nil
        local helpTxt = bfsuite.app.fieldHelpTxt['servoScaleNeg']['t']
        bfsuite.app.formLines[idx] = form.addLine("Scale negative")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['scaleNeg']
        end, function(value)
            configs[servoIndex]['scaleNeg'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['scalePos'] ~= nil then
        local idx = 6
        local minValue = 100
        local maxValue = 1000
        local defaultValue = 500
        local suffix = nil
        local helpTxt = bfsuite.app.fieldHelpTxt['servoScalePos']['t']
        bfsuite.app.formLines[idx] = form.addLine("Scale positive")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['scalePos']
        end, function(value)
            configs[servoIndex]['scalePos'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['rate'] ~= nil then
        local idx = 7
        local minValue = 50
        local maxValue = 5000
        local defaultValue = 333
        local suffix = "Hz"
        local helpTxt = bfsuite.app.fieldHelpTxt['servoRate']['t']
        bfsuite.app.formLines[idx] = form.addLine("Rate")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['rate']
        end, function(value)
            configs[servoIndex]['rate'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['speed'] ~= nil then
        local idx = 8
        local minValue = 0
        local maxValue = 60000
        local defaultValue = 0
        local suffix = "ms"
        local helpTxt = bfsuite.app.fieldHelpTxt['servoSpeed']['t']
        bfsuite.app.formLines[idx] = form.addLine("Speed")
        bfsuite.app.formFields[idx] = form.addNumberField(bfsuite.app.formLines[idx], nil, minValue, maxValue, function()
            return configs[servoIndex]['speed']
        end, function(value)
            configs[servoIndex]['speed'] = value
        end)
        if suffix ~= nil then bfsuite.app.formFields[idx]:suffix(suffix) end
        if defaultValue ~= nil then bfsuite.app.formFields[idx]:default(defaultValue) end
        if helpTxt ~= nil then bfsuite.app.formFields[idx]:help(helpTxt) end
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['flags'] ~= nil then
        local idx = 9
        local minValue = 0
        local maxValue = 1000
        local table = {"NO", "YES"}
        local tableIdxInc = -1
        local value
        bfsuite.app.formLines[idx] = form.addLine("Reverse")
        bfsuite.app.formFields[idx] = form.addChoiceField(bfsuite.app.formLines[idx], nil, bfsuite.utils.convertPageValueTable(table, tableIdxInc), function()
            return configs[servoIndex]['reverse']
        end, function(value)
            configs[servoIndex]['reverse'] = value
        end)
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    if configs[servoIndex]['flags'] ~= nil then
        local idx = 10
        local minValue = 0
        local maxValue = 1000
        local table = {"NO", "YES"}
        local tableIdxInc = -1
        local value
        bfsuite.app.formLines[idx] = form.addLine("Geometry")
        bfsuite.app.formFields[idx] = form.addChoiceField(bfsuite.app.formLines[idx], nil, bfsuite.utils.convertPageValueTable(table, tableIdxInc), function()
            return configs[servoIndex]['geometry']
        end, function(value)
            configs[servoIndex]['geometry'] = value
        end)
        if bfsuite.config.servoOverride == true then bfsuite.app.formFields[idx]:enable(false) end
    end

    getServoConfigurations(getServoConfigurationsEnd)

end

local function event(widget, category, value, x, y)

    if value == KEY_ENTER_LONG then
        onSaveMenu()
        system.killEvents(KEY_ENTER_LONG)
        return true
    end

    if category == 5 or value == 35 then
        bfsuite.app.ui.openPage(pidx, "Servos", "servos.lua", bfsuite.config.servoOverride)
        return true
    end

    return false
end

local function onToolMenu(self)

    local buttons
    if bfsuite.config.servoOverride == false then
        buttons = {
            {
                label = "                OK                ",
                action = function()

                    -- we cant launch the loader here to se rely on the modules
                    -- wakeup function to do this
                    triggerOverRide = true
                    triggerOverRideAll = true
                    return true
                end
            }, {
                label = "CANCEL",
                action = function()
                    return true
                end
            }
        }
    else
        buttons = {
            {
                label = "                OK                ",
                action = function()

                    -- we cant launch the loader here to se rely on the modules
                    -- wakeup function to do this
                    triggerOverRide = true
                    return true
                end
            }, {
                label = "CANCEL",
                action = function()
                    return true
                end
            }
        }
    end
    local message
    local title
    if bfsuite.config.servoOverride == false then
        title = "Enable servo override"
        message = "Servo override allows you to 'trim' your servo center point in real time."
    else
        title = "Disable servo override"
        message = "Return control of the servos to the flight controller."
    end

    form.openDialog({
        width = nil,
        title = title,
        message = message,
        buttons = buttons,
        wakeup = function()
        end,
        paint = function()
        end,
        options = TEXT_LEFT
    })

end

return {
    title = "Servos",
    reboot = false,
    event = event,
    setValues = setValues,
    servoChanged = servoChanged,
    servoCenterFocusOn = servoCenterFocusOn,
    servoCenterFocusOff = servoCenterFocusOff,
    servoCenterFocusAllOn = servoCenterFocusAllOn,
    servoCenterFocusAllOff = servoCenterFocusAllOff,
    saveServoSettings = saveServoSettings,
    onToolMenu = onToolMenu,
    wakeup = wakeup,
    openPage = openPage,
    onNavMenu = onNavMenu,
    onSaveMenu = onSaveMenu,
    pageTitle = "Servos",
    navButtons = {menu = true, save = true, reload = true, tool = true, help = true}

}
