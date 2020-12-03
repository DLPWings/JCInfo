--[[ 
MIT License

Copyright (c) [2020] [Juan de la Parra - DLP Wings]

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE. ]]





-- Config
local fuelAlarm = 30 --Default 30%
local fuelAlarmRepeat = 10000 --milliseconds
local alternatingDelay = 3000 --Delay for alternating values display

-- App variables
local sensorId = 0
local demoMode = false
local alternateRPM = true
local alternateEGT = true
local alternateBattV = true
local alternateBatt = true
local demoModeCtrl

local resetReminder
local resetReminderFile
local resetDone = false

local booleanSelect = {"Yes", "No"}


--Timers
local lastTime=0
local alternating=0
--Alarm
local fuelAlarmFile
local fuelAlarmPlayed = false
local alarmVoice = true
local fuelAlarmArmed = false
local lastAlarm = 0
--Telemetry Variables
local RPMValue = 0
local EGTValue = 0
local ECUVValue = 0
--local PumpValue = 0
local EcuBattValue = 0
local FuelValue = 0
--local SpeedValue = 0
local StatusCode = 0
local MessageCode = 0



collectgarbage()

--Form functions
local function sensorChanged(value)
    if(value and value >=0) then
        sensorId=sensorsAvailable[value].id
    else
        sensorId = 0
    end
    system.pSave("SensorId",sensorId)
end

local function fuelAlarmChanged(value)
    fuelAlarm = value
    system.pSave("FuelAlarm",value)
end

local function fuelAlarmRepeatChanged(value)
    fuelAlarmRepeat = value*1000
    system.pSave("FuelAlarmRepeat",fuelAlarmRepeat)
end



local function fuelAlarmFileChanged(value)
	fuelAlarmFile=value
	system.pSave("FuelAlarmFile",value)
end

local function resetReminderFileChanged(value)
	resetReminderFile=value
	system.pSave("ResetReminderFile",value)
end

local function alarmVoiceValueChanged(value)
    alarmVoice = value
    system.pSave("AlarmVoice",alarmVoice)
end

local function resetReminderChanged(value)
    resetReminder = value
    system.pSave("ResetReminder",resetReminder)
end

local function alternatingDelayChanged(value)
    alternatingDelay = value*100
    system.pSave("AlternatingDelay",alternatingDelay)
end

local function demoModeChanged(value)
    demoMode = not value
    form.setValue(demoModeCtrl,demoMode)
    if demoMode then system.pSave("DemoMode",1) else system.pSave("DemoMode",0) end
end

local function alternateRPMChanged(value)
    alternateRPM = value
    system.pSave("AlternateRPM",alternateRPM)
end

local function alternateEGTChanged(value)
    alternateEGT = value
    system.pSave("AlternateEGT",alternateEGT)
end

local function alternateBattVChanged(value)
    alternateBattV = value
    system.pSave("AlternateBattV",alternateBattV)
end

local function alternateBattChanged(value)
    alternateBatt = value
    system.pSave("AlternateBatt",alternateBatt)
end

local function comma_value(amount)
    local formatted = amount
    local k
    while true do  
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k==0) then
            break
        end
    end
    return formatted
end

local function decodeStatus(statusID)

    if statusID == 10 then     return "Stop"
    elseif statusID == 20 then return "Glow Test"
    elseif statusID == 30 then return "Starter Test"
    elseif statusID == 31 then return "Prime Fuel"
    elseif statusID == 32 then return "Prime Burner"
    elseif statusID == 40 then return "Manual Cooling"
    elseif statusID == 41 then return "Auto Cooling"
    elseif statusID == 51 then return "Igniter Heat"
    elseif statusID == 52 then return "Ignition"
    elseif statusID == 53 then return "Preheat"
    elseif statusID == 54 then return "Switchover"
    elseif statusID == 55 then return "To Idle"
    elseif statusID == 56 then return "Running"
    elseif statusID == 62 then return "Stop Error"
    else                       return "No Data"
    end
end

local function decodeMessage(messageID)

    if messageID == 1 then     return "Ignition Error"
    elseif messageID == 2 then return "Preheat Error"
    elseif messageID == 3 then return "Switchover Error"
    elseif messageID == 4 then return "Starter Motor Error"
    elseif messageID == 5 then return "To Idle Error"
    elseif messageID == 6 then return "Acceleration Error"
    elseif messageID == 7 then return "Igniter Bad"
    elseif messageID == 8 then return "Min Pump Ok"
    elseif messageID == 9 then return "Max Pump Ok"
    elseif messageID == 10 then return "Low RX Battery"
    elseif messageID == 11 then return "Low ECU Battery"
    elseif messageID == 12 then return "No RX"
    elseif messageID == 13 then return "Trim Down"
    elseif messageID == 14 then return "Trim Up"
    elseif messageID == 15 then return "Failsafe"
    elseif messageID == 16 then return "Full"
    elseif messageID == 17 then return "RX Setup Error"
    elseif messageID == 18 then return "Temp Sensor Error"
    elseif messageID == 19 then return "Turbine Comm Error"
    elseif messageID == 20 then return "Max Temp"
    elseif messageID == 21 then return "Max Amperes"
    elseif messageID == 22 then return "Low RPM"
    elseif messageID == 23 then return "RPM Sensor Error"
    elseif messageID == 24 then return "Max Pump"
    else                        return "No Data"
    end
end

local function initSettingsForm(formID)

    local sensorsAvailable = {}
    local available = system.getSensors();
    local list={}

    local curIndex=-1
    local descr = ""
    for index,sensor in ipairs(available) do 
        if(sensor.param == 0) then
            list[#list+1] = sensor.label
            sensorsAvailable[#sensorsAvailable+1] = sensor
            if(sensor.id==sensorId ) then
                curIndex=#sensorsAvailable
            end 
        end 
    end

    -- sensor select
    form.addRow(2)
    form.addLabel({label="Select sensor",width=120})
    form.addSelectbox (list, curIndex,true,sensorChanged,{width=190})

     --Fuel Warning
    form.addSpacer(100,10)
    form.addLabel({label="Alarms",font=FONT_BOLD})  
    form.addRow(3)
    form.addLabel({label="Fuel warning  [%]", width=130})
    form.addLabel({label="(0=Disabled)", width=80, font=FONT_MINI})
    form.addIntbox(fuelAlarm,0,99,30,0,1,fuelAlarmChanged) 
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(fuelAlarmFile or "",fuelAlarmFileChanged)
    form.addRow(2)
    form.addLabel({label="    Repeat every [s]", width=190})
    form.addIntbox(fuelAlarmRepeat/1000,0,60,10,0,1,fuelAlarmRepeatChanged,{width=120})
    form.addRow(2)
    form.addLabel({label="    Announce value by voice", width=240})
    form.addSelectbox (booleanSelect, alarmVoice,false,alarmVoiceValueChanged)
    form.addRow(2)
    form.addLabel({label="Fuel consumption reset reminder", width=240})
    form.addSelectbox (booleanSelect, resetReminder,false,resetReminderChanged)
    form.addRow(2)
    form.addLabel({label="    File",width=190})
    form.addAudioFilebox(resetReminderFile or "",resetReminderFileChanged)    

    form.addSpacer(100,10)
    form.addLabel({label="Alternating display",font=FONT_BOLD})
    
    form.addRow(2)
    form.addLabel({label="Show RPM", width=190})
    form.addSelectbox (booleanSelect, alternateRPM,false,alternateRPMChanged)

    form.addRow(2)
    form.addLabel({label="Show EGT [°C]", width=190})
    form.addSelectbox (booleanSelect, alternateEGT,false,alternateEGTChanged)
    
    form.addRow(2)
    form.addLabel({label="Show ECU batt [V]", width=190})
    form.addSelectbox (booleanSelect, alternateBattV,false,alternateBattVChanged)

    form.addRow(2)    
    form.addLabel({label="Show ECU batt [%]", width=190})
    form.addSelectbox (booleanSelect, alternateBatt,false,alternateBattChanged)
    
    form.addRow(2)
    form.addLabel({label="Change display every [s]", width=190})
    form.addIntbox(alternatingDelay/100,10,100,30,1,1,alternatingDelayChanged,{width=120})

    --Demo Mode
    form.addSpacer(100,10)
    form.addRow(2)
    form.addLabel({label="Demo mode enabled", width=274})
    demoModeCtrl = form.addCheckbox(demoMode,demoModeChanged)
    
    
    collectgarbage()
end

local function printSmallDisplay(width, height)
    lcd.drawText(2,8,decodeStatus(StatusCode),FONT_BOLD)
    lcd.drawText(2,30,decodeMessage(MessageCode),FONT_NORMAL)
    --lcd.drawImage(1,51,":graph")
end

local function printDoubleDisplay(width, height)
    
    if demoMode then
        FuelValue = 100*((system.getInputs( "P5" ) + 1.0)/2)
        RPMValue = math.floor((((system.getInputs( "P6" ) + 1.0)/2)*130) * 1000)
        EGTValue = 800*((system.getInputs( "P7" ) + 1.0)/2)
        EcuBattValue = 100*((system.getInputs( "P8" ) + 1.0)/2)
        ECUVValue = 10.2*((system.getInputs( "P8" ) + 1.0)/2)
        --SpeedValue = 500*((system.getInputs( "P2" ) + 1.0)/2)
        --PumpValue = 3700*((system.getInputs( "P1" ) + 1.0)/2)         
        StatusCode = system.getInputs( "SB" )
        if StatusCode == 1 then 
            StatusCode = 56 
            MessageCode = 8
        end
        if StatusCode == -1 then 
            StatusCode = 10 
            MessageCode = 13
        end
    end

    if(StatusCode == 56 and FuelValue > fuelAlarm) then fuelAlarmArmed = true end
    if(StatusCode == 10) then 
        fuelAlarmArmed = false 
        fuelAlarmPlayed = false
        resetDone = false
    end  

    if(StatusCode == 56 and resetReminder == 1) then
        if (resetDone == false and FuelValue < 95) then
            system.messageBox("Reset fuel consumption!",5)
            if resetReminderFile ~= "" then system.playFile(resetReminderFile,AUDIO_QUEUE) end
            resetDone = true
        else
            resetDone = true
        end
    end

    --Fuel gauge  
    local fuelLbl = string.format("%d", FuelValue)
    if FuelValue == -1 then
        fuelLbl = "0"
    end

    
    lcd.drawText(148 - lcd.getTextWidth(FONT_MAXI,fuelLbl),5 ,fuelLbl,FONT_MAXI)
    lcd.drawText(148 - lcd.getTextWidth(FONT_MINI,"FUEL %"),0,"FUEL %",FONT_MINI)

    --Status / Message 
    lcd.drawText(2,35,decodeStatus(StatusCode),FONT_BOLD)
    lcd.drawText(2,52,decodeMessage(MessageCode),FONT_MINI)

    --Alternating values
    local lbl
    if alternating == 1 then
        lbl = comma_value(math.floor(RPMValue))
        lcd.drawText(2,0,"RPM",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 2 then
        lbl = string.format("%d°C",math.floor(EGTValue))
        lcd.drawText(2,0,"EGT",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 3 then
        lbl = string.format("%.2f V", ECUVValue)
        lcd.drawText(2,0,"ECU Batt",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if alternating == 4 then
        lbl = string.format("%d%%",EcuBattValue)
        lcd.drawText(2,0,"ECU Batt",FONT_MINI)
        lcd.drawText(2,10,lbl,FONT_BIG)
    end
    if (fuelAlarm ~= 0 and FuelValue ~= -1) then 
        if(fuelAlarmArmed and FuelValue <= fuelAlarm) then
            if fuelAlarmRepeat == 0 and fuelAlarmPlayed then 
                --Prevent further repetitions
            elseif system.getTimeCounter() - lastAlarm > fuelAlarmRepeat then
                if fuelAlarmFile ~= "" then system.playFile(fuelAlarmFile,AUDIO_QUEUE) end
                if alarmVoice then system.playNumber(FuelValue,0,"%") end
                system.messageBox("Warning: LOW FUEL",3)
                lastAlarm = system.getTimeCounter()
                fuelAlarmPlayed = true
            end
        end
    end
    
    collectgarbage()
end

local function init()
    -- sensor id
    sensorId = system.pLoad("SensorId",0)
    
    if sensorId == 0 then
        local available = system.getSensors()
        for index,sensor in ipairs(available) do
            if((sensor.id & 0xFFFF) == 0xA40C and (sensor.id & 0xFF0000) ~= 0) then -- Fill default sensor ID
                sensorId = sensor.id
                break
            end 
        end
    end

    --Load Settings
    fuelAlarm = system.pLoad("FuelAlarm",30)
    fuelAlarmFile = system.pLoad("FuelAlarmFile","")
    fuelAlarmRepeat = system.pLoad("FuelAlarmRepeat",10000)
    demoMode = system.pLoad("DemoMode",0)
    if demoMode == 0 then demoMode = false else demoMode = true end

    alternateRPM = system.pLoad("AlternateRPM",1)
    alternateEGT = system.pLoad("AlternateEGT",1)
    alternateBattV = system.pLoad("AlternateBattV",1)
    alternateBatt = system.pLoad("AlternateBatt",1)
    alarmVoice = system.pLoad("AlarmVoice", 1)
    resetReminder = system.pLoad("ResetReminder",1)
    resetReminderFile = system.pLoad("ResetReminderFile","")

    alternatingDelay = system.pLoad("AlternatingDelay",3000)

    system.registerTelemetry( 1, "Jet Central Status", 2, printSmallDisplay)
    system.registerTelemetry( 2, "Jet Central MFD", 2, printDoubleDisplay)

    system.registerForm(1,MENU_TELEMETRY,"Jet Central",initSettingsForm,nil,nil)
    collectgarbage()
end
  
local function loop()
    local sensor
    local newTime = system.getTimeCounter()

    -- RPM
    sensor = system.getSensorByID(sensorId,1)
    if( sensor and sensor.valid ) then RPMValue = sensor.value else RPMValue = 0 end

    -- EGT
    sensor = system.getSensorByID(sensorId,2)
    if( sensor and sensor.valid ) then EGTValue = sensor.value else EGTValue = 0 end

    -- EcuV
    sensor = system.getSensorByID(sensorId,3)
    if( sensor and sensor.valid ) then ECUVValue = sensor.value else ECUVValue = 0 end

    -- EcuBatt
    sensor = system.getSensorByID(sensorId,5)
    if( sensor and sensor.valid ) then EcuBattValue = sensor.value else EcuBattValue = 0 end

    -- Fuel
    sensor = system.getSensorByID(sensorId,6)
    if( sensor and sensor.valid ) then FuelValue = sensor.value else FuelValue = -1 end

    -- Status
    sensor = system.getSensorByID(sensorId,8)
    if( sensor and sensor.valid ) then StatusCode = sensor.value else StatusCode = 0 end

    -- Message
    sensor = system.getSensorByID(sensorId,9)
    if( sensor and sensor.valid ) then MessageCode = sensor.value else MessageCode = 0 end
 
    if newTime-lastTime > alternatingDelay then
        lastTime = newTime
        alternating = alternating +14
        if alternating > 4 then alternating = 0 end

        if alternating == 1 and alternateRPM == 2 then alternating = 2 end
        if alternating == 2 and alternateEGT == 2 then alternating = 3 end
        if alternating == 3 and alternateBattV == 2 then alternating = 4 end
        if alternating == 4 and alternateBatt == 2 then alternating = 0 end
        if alternating == 0 and alternateRPM == 1 then alternating = 1 end
        if alternating == 0 and alternateEGT == 1 then alternating = 2 end
        if alternating == 0 and alternateBattV == 1 then alternating = 3 end
        if alternating == 0 and alternateBatt ==1 then alternating = 4 end
    end
    
    collectgarbage()
end
return {init=init, loop=loop, author="DLPWings", version="1.12",name="Jet Central Info"}