-- create 16 servos in disabled state
local servoTable = {}
servoTable = {}
servoTable['sections'] = {}

local triggerOverRide = false
local triggerOverRideAll = false
local lastServoCountTime = os.clock()

local function buildServoTable()

    for i = 1, bfsuite.config.servoCount do
        servoTable[i] = {}
        servoTable[i] = {}
        servoTable[i]['title'] = "SERVO " .. i
        servoTable[i]['image'] = "servo" .. i .. ".png"
        servoTable[i]['disabled'] = true
    end

    for i = 1, bfsuite.config.servoCount do
        -- enable actual number of servos
        servoTable[i]['disabled'] = false

        if bfsuite.config.swashMode == 0 then
            -- we do nothing as we cannot determine any servo names
        elseif bfsuite.config.swashMode == 1 then
            -- servo mode is direct - only servo for sure we know name of is tail
            if bfsuite.config.tailMode == 0 then
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
                servoTable[4]['section'] = 1
            end
        elseif bfsuite.config.swashMode == 2 or bfsuite.config.swashMode == 3 or bfsuite.config.swashMode == 4 then
            -- servo mode is cppm - 
            servoTable[1]['title'] = "CYC. PITCH"
            servoTable[1]['image'] = "cpitch.png"

            servoTable[2]['title'] = "CYC. LEFT"
            servoTable[2]['image'] = "cleft.png"

            servoTable[3]['title'] = "CYC. RIGHT"
            servoTable[3]['image'] = "cright.png"

            if bfsuite.config.tailMode == 0 then
                -- this is because when swiching models this may or may not have
                -- been created.
                if servoTable[4] == nil then servoTable[4] = {} end
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
            else
                -- servoTable[4]['disabled'] = true
            end
        elseif bfsuite.config.swashMode == 5 or bfsuite.config.swashMode == 6 then
            -- servo mode is fpm 90
            -- servoTable[3]['disabled'] = true 
            if bfsuite.config.tailMode == 0 then
                servoTable[4]['title'] = "TAIL"
                servoTable[4]['image'] = "tail.png"
            else
                -- servoTable[4]['disabled'] = true                
            end
        end
    end
end

local function swashMixerType()
    local txt
    if bfsuite.config.swashMode == 0 then
        txt = "NONE"
    elseif bfsuite.config.swashMode == 1 then
        txt = "DIRECT"
    elseif bfsuite.config.swashMode == 2 then
        txt = "CPPM 120°"
    elseif bfsuite.config.swashMode == 3 then
        txt = "CPPM 135°"
    elseif bfsuite.config.swashMode == 4 then
        txt = "CPPM 140°"
    elseif bfsuite.config.swashMode == 5 then
        txt = "FPPM 90° L"
    elseif bfsuite.config.swashMode == 6 then
        txt = "FPPM 90° R"
    else
        txt = "UNKNOWN"
    end

    return txt
end

local function openPage(pidx, title, script)

    bfsuite.bg.msp.protocol.mspIntervalOveride = nil


    bfsuite.app.triggers.isReady = false
    bfsuite.app.uiState = bfsuite.app.uiStatus.pages

    form.clear()

    bfsuite.app.lastIdx = idx
    bfsuite.app.lastTitle = title
    bfsuite.app.lastScript = script

    -- size of buttons
    if bfsuite.config.iconSize == nil or bfsuite.config.iconSize == "" then
        bfsuite.config.iconSize = 1
    else
        bfsuite.config.iconSize = tonumber(bfsuite.config.iconSize)
    end

    local w, h = bfsuite.utils.getWindowSize()
    local windowWidth = w
    local windowHeight = h
    local padding = bfsuite.app.radio.buttonPadding

    local sc
    local panel

    buttonW = 100
    local x = windowWidth - buttonW - 10

    bfsuite.app.ui.fieldHeader("Servos")

    local buttonW
    local buttonH
    local padding
    local numPerRow

    -- TEXT ICONS
    -- TEXT ICONS
    if bfsuite.config.iconSize == 0 then
        padding = bfsuite.app.radio.buttonPaddingSmall
        buttonW = (bfsuite.config.lcdWidth - padding) / bfsuite.app.radio.buttonsPerRow - padding
        buttonH = bfsuite.app.radio.navbuttonHeight
        numPerRow = bfsuite.app.radio.buttonsPerRow
    end
    -- SMALL ICONS
    if bfsuite.config.iconSize == 1 then

        padding = bfsuite.app.radio.buttonPaddingSmall
        buttonW = bfsuite.app.radio.buttonWidthSmall
        buttonH = bfsuite.app.radio.buttonHeightSmall
        numPerRow = bfsuite.app.radio.buttonsPerRowSmall
    end
    -- LARGE ICONS
    if bfsuite.config.iconSize == 2 then

        padding = bfsuite.app.radio.buttonPadding
        buttonW = bfsuite.app.radio.buttonWidth
        buttonH = bfsuite.app.radio.buttonHeight
        numPerRow = bfsuite.app.radio.buttonsPerRow
    end

    local lc = 0
    local bx = 0

    if bfsuite.app.gfx_buttons["servos"] == nil then bfsuite.app.gfx_buttons["servos"] = {} end
    if bfsuite.app.menuLastSelected["servos"] == nil then bfsuite.app.menuLastSelected["servos"] = 1 end

    if bfsuite.app.gfx_buttons["servos"] == nil then bfsuite.app.gfx_buttons["servos"] = {} end
    if bfsuite.app.menuLastSelected["servos"] == nil then bfsuite.app.menuLastSelected["servos"] = 1 end

    for pidx, pvalue in ipairs(servoTable) do

        if pvalue.disabled ~= true then

            if pvalue.section == "swash" and lc == 0 then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = bfsuite.app.radio.linePaddingTop, w = bfsuite.config.lcdWidth, h = bfsuite.app.radio.navbuttonHeight},
                                                          headerLineText())
            end

            if pvalue.section == "tail" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = bfsuite.app.radio.linePaddingTop, w = bfsuite.config.lcdWidth, h = bfsuite.app.radio.navbuttonHeight}, "TAIL")
            end

            if pvalue.section == "other" then
                local headerLine = form.addLine("")
                local headerLineText = form.addStaticText(headerLine, {x = 0, y = bfsuite.app.radio.linePaddingTop, w = bfsuite.config.lcdWidth, h = bfsuite.app.radio.navbuttonHeight}, "TAIL")
            end

            if lc == 0 then
                if bfsuite.config.iconSize == 0 then y = form.height() + bfsuite.app.radio.buttonPaddingSmall end
                if bfsuite.config.iconSize == 1 then y = form.height() + bfsuite.app.radio.buttonPaddingSmall end
                if bfsuite.config.iconSize == 2 then y = form.height() + bfsuite.app.radio.buttonPadding end
            end

            if lc >= 0 then bx = (buttonW + padding) * lc end

            if bfsuite.config.iconSize ~= 0 then
                if bfsuite.app.gfx_buttons["servos"][pidx] == nil then
                    bfsuite.app.gfx_buttons["servos"][pidx] = lcd.loadMask(bfsuite.config.suiteDir .. "app/gfx/servos/" .. pvalue.image)
                end
            else
                bfsuite.app.gfx_buttons["servos"][pidx] = nil
            end

            bfsuite.app.formFields[pidx] = form.addButton(nil, {x = bx, y = y, w = buttonW, h = buttonH}, {
                text = pvalue.title,
                icon = bfsuite.app.gfx_buttons["servos"][pidx],
                options = FONT_S,
                paint = function()
                end,
                press = function()
                    bfsuite.app.menuLastSelected["servos"] = pidx
                    bfsuite.currentServoIndex = pidx
                    bfsuite.app.ui.progressDisplay()
                    bfsuite.app.ui.openPage(pidx, pvalue.title, "servos_tool.lua", servoTable)
                end
            })

            if pvalue.disabled == true then bfsuite.app.formFields[pidx]:enable(false) end

            if bfsuite.app.menuLastSelected["servos"] == pidx then bfsuite.app.formFields[pidx]:focus() end

            lc = lc + 1

            if lc == numPerRow then lc = 0 end
        end
    end

    bfsuite.app.triggers.closeProgressLoader = true

    return
end

local function getServoCount(callback, callbackParam)
    local message = {
        command = 120, -- MSP_SERVO_CONFIGURATIONS
        processReply = function(self, buf)
            local servoCount = bfsuite.bg.msp.mspHelper.readU8(buf)

            -- update master one in case changed
            bfsuite.config.servoCountNew = servoCount

            if callback then callback(callbackParam) end
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

local function openPageInit(pidx, title, script)

    if bfsuite.config.servoCount ~= nil then
        buildServoTable()
        openPage(pidx, title, script)
    else
        local message = {
            command = 120, -- MSP_SERVO_CONFIGURATIONS
            processReply = function(self, buf)
                if #buf >= 10 then
                    local servoCount = bfsuite.bg.msp.mspHelper.readU8(buf)

                    -- update master one in case changed
                    bfsuite.config.servoCount = servoCount
                end
            end,
            simulatorResponse = {
                4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 0, 0,
                120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
            }
        }
        bfsuite.bg.msp.mspQueue:add(message)

        local message = {
            command = 192, -- MSP_SERVO_OVERIDE
            processReply = function(self, buf)
                if #buf >= 10 then

                    for i = 0, bfsuite.config.servoCount do
                        buf.offset = i
                        local servoOverride = bfsuite.bg.msp.mspHelper.readU8(buf)
                        if servoOverride == 0 then
                            bfsuite.utils.log("Servo override: true")
                            bfsuite.config.servoOverride = true
                        end
                    end
                end
                if bfsuite.config.servoOverride == nil then bfsuite.config.servoOverride = false end
            end,
            simulatorResponse = {209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7}
        }
        bfsuite.bg.msp.mspQueue:add(message)

    end
end

local function event(widget, category, value, x, y)

    if category == 5 or value == 35 then
        bfsuite.app.Page.onNavMenu(self)
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

local function wakeup()
    if triggerOverRide == true then
        triggerOverRide = false

        if bfsuite.config.servoOverride == false then
            bfsuite.app.audio.playServoOverideEnable = true
            bfsuite.app.ui.progressDisplay("Servo override", "Enabling servo override...")
            bfsuite.app.Page.servoCenterFocusAllOn(self)
            bfsuite.config.servoOverride = true
        else
            bfsuite.app.audio.playServoOverideDisable = true
            bfsuite.app.ui.progressDisplay("Servo override", "Disabling servo override...")
            bfsuite.app.Page.servoCenterFocusAllOff(self)
            bfsuite.config.servoOverride = false
        end
    end

    local now = os.clock()
    if ((now - lastServoCountTime) >= 2) and bfsuite.bg.msp.mspQueue:isProcessed() then
        lastServoCountTime = now

        getServoCount()

        if bfsuite.config.servoCountNew ~= nil then if bfsuite.config.servoCountNew ~= bfsuite.config.servoCount then bfsuite.app.triggers.triggerReloadNoPrompt = true end end

    end

end

local function servoCenterFocusAllOn(self)

    bfsuite.app.audio.playServoOverideEnable = true

    for i = 0, #servoTable do
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

    for i = 0, #servoTable do
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

local function onNavMenu(self)

    if bfsuite.config.servoOverride == true or inFocus == true then
        bfsuite.app.audio.playServoOverideDisable = true
        bfsuite.config.servoOverride = false
        inFocus = false
        bfsuite.app.ui.progressDisplay("Servo override", "Disabling servo override...")
        bfsuite.app.Page.servoCenterFocusAllOff(self)
        bfsuite.app.triggers.closeProgressLoader = true
    end
    -- bfsuite.app.ui.progressDisplay()
    bfsuite.app.ui.openMainMenu()

end

return {
    title = "Servos",
    event = event,
    openPage = openPageInit,
    onToolMenu = onToolMenu,
    onNavMenu = onNavMenu,
    servoCenterFocusAllOn = servoCenterFocusAllOn,
    servoCenterFocusAllOff = servoCenterFocusAllOff,
    wakeup = wakeup,
    navButtons = {menu = true, save = false, reload = true, tool = true, help = true}
}
