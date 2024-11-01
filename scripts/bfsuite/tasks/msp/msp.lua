--[[

 * Copyright (C) Betaflight Project
 *
 *
 * License GPLv3: https://www.gnu.org/licenses/gpl-3.0.en.html
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License version 3 as
 * published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 
 * Note.  Some icons have been sourced from https://www.flaticon.com/
 * 

]]--

--
-- background processing of msp traffic
--
local arg = {...}
local config = arg[1]
local compile = arg[2]

msp = {}

msp.activeProtocol = nil
msp.onConnectChecksInit = true

local protocol = assert(compile.loadScript(config.suiteDir .. "tasks/msp/protocols.lua"))()

msp.sensor = sport.getSensor({primId = 0x32})
msp.mspQueue = mspQueue
if bfsuite.rssiSensor then bfsuite.sensor:module(bfsuite.rssiSensor:module()) end
msp.mspQueue = mspQueue

-- set active protocol to use
msp.protocol = protocol.getProtocol()

-- preload all transport methods
msp.protocolTransports = {}
for i, v in pairs(protocol.getTransports()) do msp.protocolTransports[i] = assert(compile.loadScript(config.suiteDir .. v))() end

-- set active transport table to use
local transport = msp.protocolTransports[msp.protocol.mspProtocol]
msp.protocol.mspRead = transport.mspRead
msp.protocol.mspSend = transport.mspSend
msp.protocol.mspWrite = transport.mspWrite
msp.protocol.mspPoll = transport.mspPoll

msp.mspQueue = assert(compile.loadScript(config.suiteDir .. "tasks/msp/mspQueue.lua"))()
msp.mspQueue.maxRetries = msp.protocol.maxRetries
msp.mspHelper = assert(compile.loadScript(config.suiteDir .. "tasks/msp/mspHelper.lua"))()
assert(compile.loadScript(config.suiteDir .. "tasks/msp/common.lua"))()

-- BACKGROUND checks
function msp.onConnectBgChecks()

    if msp.mspQueue ~= nil and msp.mspQueue:isProcessed() then

        if bfsuite.config.apiVersion == nil and msp.mspQueue:isProcessed() then

            local message = {
                command = 1, -- MIXER
                processReply = function(self, buf)
                    if #buf >= 3 then
                        local version = buf[2] + buf[3] / 100
                        bfsuite.config.apiVersion = version
                        bfsuite.utils.log("MSP Version: " .. bfsuite.config.apiVersion)
                    end
                end,
                simulatorResponse = {0, 12, 7}
            }
            msp.mspQueue:add(message)
        elseif bfsuite.config.clockSet == nil and msp.mspQueue:isProcessed() then

            bfsuite.utils.log("Sync clock: " .. os.clock())

            local message = {
                command = 246, -- MSP_SET_RTC
                payload = {},
                processReply = function(self, buf)
                    bfsuite.utils.log("RTC set.")

                    if #buf >= 0 then
                        bfsuite.config.clockSet = true
                        -- we do the beep later to avoid a double beep
                    end

                end,
                simulatorResponse = {}
            }

            -- generate message to send
            local now = os.time()
            -- format: seconds after the epoch / milliseconds
            for i = 1, 4 do
                bfsuite.bg.msp.mspHelper.writeU8(message.payload, now & 0xFF)
                now = now >> 8
            end
            bfsuite.bg.msp.mspHelper.writeU16(message.payload, 0)

            -- add msg to queue
            bfsuite.bg.msp.mspQueue:add(message)
        elseif bfsuite.config.clockSet == true and bfsuite.config.clockSetAlart ~= true then
            -- this is unsual but needed because the clock sync does not return anything usefull
            -- to confirm its done! 
            bfsuite.utils.playFileCommon("beep.wav")
            bfsuite.config.clockSetAlart = true
        elseif (bfsuite.config.tailMode == nil or bfsuite.config.swashMode == nil) and msp.mspQueue:isProcessed() then
            local message = {
                command = 42, -- MIXER
                processReply = function(self, buf)
                    if #buf >= 19 then

                        local tailMode = buf[2]
                        local swashMode = buf[6]
                        bfsuite.config.swashMode = swashMode
                        bfsuite.config.tailMode = tailMode
                        bfsuite.utils.log("Tail mode: " .. bfsuite.config.tailMode)
                        bfsuite.utils.log("Swash mode: " .. bfsuite.config.swashMode)
                    end
                end,
                simulatorResponse = {0, 1, 0, 0, 0, 2, 100, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0}
            }
            msp.mspQueue:add(message)
        elseif (bfsuite.config.activeProfile == nil or bfsuite.config.activeRateProfile == nil) then

            bfsuite.utils.getCurrentProfile()

        elseif (bfsuite.config.servoCount == nil) and msp.mspQueue:isProcessed() then
            local message = {
                command = 120, -- MSP_SERVO_CONFIGURATIONS
                processReply = function(self, buf)
                    if #buf >= 20 then
                        local servoCount = msp.mspHelper.readU8(buf)

                        -- update master one in case changed
                        bfsuite.config.servoCount = servoCount
                    end
                end,
                simulatorResponse = {
                    4, 180, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 160, 5, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0, 1, 0, 14, 6, 12, 254, 244, 1, 244, 1, 244, 1, 144, 0, 0, 0,
                    0, 0, 120, 5, 212, 254, 44, 1, 244, 1, 244, 1, 77, 1, 0, 0, 0, 0
                }
            }
            msp.mspQueue:add(message)

        elseif (bfsuite.config.servoOverride == nil) and msp.mspQueue:isProcessed() then
            local message = {
                command = 192, -- MSP_SERVO_OVERIDE
                processReply = function(self, buf)
                    if #buf >= 16 then

                        for i = 0, bfsuite.config.servoCount do
                            buf.offset = i
                            local servoOverride = msp.mspHelper.readU8(buf)
                            if servoOverride == 0 then
                                bfsuite.utils.log("Servo overide: true")
                                bfsuite.config.servoOverride = true
                            end
                        end
                        if bfsuite.config.servoOverride == nil then bfsuite.config.servoOverride = false end
                    end
                end,
                simulatorResponse = {209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7, 209, 7}
            }
            msp.mspQueue:add(message)

            -- do this at end of last one
            msp.onConnectChecksInit = false
        end
    end

end

function msp.resetState()
    bfsuite.config.servoOverride = nil
    bfsuite.config.servoCount = nil
    bfsuite.config.tailMode = nil
    bfsuite.config.apiVersion = nil
    bfsuite.config.clockSet = nil
    bfsuite.config.clockSetAlart = nil
end

function msp.wakeup()

    -- check what protocol is in use
    local telemetrySOURCE = system.getSource("Rx RSSI1")
    if telemetrySOURCE ~= nil then
        msp.activeProtocol = "crsf"
    else
        msp.activeProtocol = "smartPort"
    end

    if bfsuite.bg.wasOn == true then bfsuite.rssiSensorChanged = true end

    if bfsuite.rssiSensorChanged == true then

        bfsuite.utils.log("Switching protocol: " .. msp.activeProtocol)

        msp.protocol = protocol.getProtocol()

        -- set active transport table to use
        local transport = msp.protocolTransports[msp.protocol.mspProtocol]
        msp.protocol.mspRead = transport.mspRead
        msp.protocol.mspSend = transport.mspSend
        msp.protocol.mspWrite = transport.mspWrite
        msp.protocol.mspPoll = transport.mspPoll

        msp.resetState()
        msp.onConnectChecksInit = true
    end

    if bfsuite.rssiSensor ~= nil and bfsuite.bg.telemetry.active() == false then
        msp.resetState()
        msp.onConnectChecksInit = true
    end

    -- run the msp.checks

    local state

    if system:getVersion().simulation == true then
        state = true
    elseif bfsuite.rssiSensor then
        state = bfsuite.bg.telemetry.active()
    else
        state = false
    end

    if state == true then
        msp.mspQueue:processQueue()

        -- checks that run on each connection to the fbl
        if msp.onConnectChecksInit == true then msp.onConnectBgChecks() end
    else
        msp.mspQueue:clear()
    end
end

return msp
