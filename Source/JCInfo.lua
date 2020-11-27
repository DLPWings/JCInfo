--[[ MIT License

Copyright (c) [2020] [Juan de la Parra - DLP ]

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
local alternateRPMCtrl
local alternateEGTCtrl
local alternateBattVCtrl
local alternateBattCtrl


--Timers
local lastTime=0
local alternating=0
--Alarm
local fuelAlarmFile
local fuelAlarmPlayed = false
local alarmVoiceValue = true
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

local function alarmVoiceValueChanged(value)
    alarmVoiceValue = not value
    form.setValue(alarmVoiceValueCtrl,alarmVoiceValue)
    if alarmVoiceValue then system.pSave("AlarmVoiceValue",1) else system.pSave("AlarmVoiceValue",0) end
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
    alternateRPM = not value
    form.setValue(alternateRPMCtrl,alternateRPM)
    if alternateRPM then system.pSave("AlternateRPM",1) else system.pSave("AlternateRPM",0) end
end

local function alternateEGTChanged(value)
    alternateEGT = not value
    form.setValue(alternateEGTCtrl,alternateEGT)
    if alternateEGT then system.pSave("AlternateEGT",1) else system.pSave("AlternateEGT",0) end
end

local function alternateBattVChanged(value)
    alternateBattV = not value
    form.setValue(alternateBattVCtrl,alternateBattV)
    if alternateBattV then system.pSave("AlternateBattV",1) else system.pSave("AlternateBattV",0) end
end

local function alternateBattChanged(value)
    alternateBatt = not value
    form.setValue(alternateBattCtrl,alternateBatt)
    if alternateBatt then system.pSave("AlternateBatt",1) else system.pSave("AlternateBatt",0) end
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
    --form.addSpacer(100,10)
    --form.addLabel({label="Jet Central Sensor",font=FONT_BOLD})
    -- sensor select
    form.addRow(2)
    form.addLabel({label="Select sensor",width=120})
    form.addSelectbox (list, curIndex,true,sensorChanged,{width=190})

     --Fuel Warning
    form.addSpacer(100,10)    
    form.addRow(2)
    form.addLabel({label="Fuel warning  [%]", width=190})
    form.addIntbox(fuelAlarm,0,99,30,0,1,fuelAlarmChanged,{width=120}) 
    form.addRow(2)
    form.addLabel({label="File",width=190})
    form.addAudioFilebox(fuelAlarmFile or "",fuelAlarmFileChanged,{width=120})
    form.addRow(2)
    form.addLabel({label="Repeat every [s]", width=190})
    form.addIntbox(fuelAlarmRepeat/1000,0,60,10,0,1,fuelAlarmRepeatChanged,{width=120})
    form.addRow(2)
    form.addLabel({label="Announce value by voice", width=274})
    alarmVoiceValueCtrl = form.addCheckbox(alarmVoiceValue,alarmVoiceValueChanged)    

    form.addSpacer(100,10)
    form.addLabel({label="Alternating display",font=FONT_BOLD})
    form.addRow(2)
    form.addLabel({label="Delay [s]", width=190})
    form.addIntbox(alternatingDelay/100,10,100,30,1,1,alternatingDelayChanged,{width=120})    
    form.addRow(2)
    form.addLabel({label="RPM", width=274})
    alternateRPMCtrl = form.addCheckbox(alternateRPM,alternateRPMChanged)
    form.addRow(2)
    form.addLabel({label="EGT", width=274})
    alternateEGTCtrl = form.addCheckbox(alternateEGT,alternateEGTChanged)
    form.addRow(2)
    form.addLabel({label="ECU batt [V]", width=274})
    alternateBattVCtrl = form.addCheckbox(alternateBattV,alternateBattVChanged)
    form.addRow(2)    
    form.addLabel({label="ECU batt [%]", width=274})
    alternateBattCtrl = form.addCheckbox(alternateBatt,alternateBattChanged)

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
    lcd.drawImage(1,51,":graph")
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
    end  

    --Fuel gauge  
    local fuelLbl = string.format("%d", FuelValue)
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

    if(fuelAlarmArmed and FuelValue <= fuelAlarm) then
        if fuelAlarmRepeat == 0 and fuelAlarmPlayed then 
            --Prevent further repetitions
        elseif system.getTimeCounter() - lastAlarm > fuelAlarmRepeat then
            system.playFile(fuelAlarmFile,AUDIO_QUEUE)
            if alarmVoiceValue then system.playNumber(FuelValue,0,"%") end
            system.messageBox("Warning: LOW FUEL",3)
            lastAlarm = system.getTimeCounter()
            fuelAlarmPlayed = true
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
            if((sensor.id & 0xFFFF) == 41996 ) then -- Fill default sensor ID
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
    if alternateRPM == 0 then alternateRPM = false else alternateRPM = true end      
    alternateEGT = system.pLoad("AlternateEGT",1)
    if alternateEGT == 0 then alternateEGT = false else alternateEGT = true end  
    alternateBattV = system.pLoad("AlternateBattV",1)
    if alternateBattV == 0 then alternateBattV = false else alternateBattV = true end    
    alternateBatt = system.pLoad("AlternateBatt",1)
    if alternateBatt == 0 then alternateBatt = false else alternateBatt = true end
    alarmVoiceValue = system.pLoad("AlarmVoiceValue", 1)
    if alarmVoiceValue == 0 then alarmVoiceValue = false else alarmVoiceValue = true end

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

    -- Pump
    --sensor = system.getSensorByID(sensorId,4)
    --if( sensor and sensor.valid ) then PumpValue = sensor.value else PumpValue = 0 end

    -- EcuBatt
    sensor = system.getSensorByID(sensorId,5)
    if( sensor and sensor.valid ) then EcuBattValue = sensor.value else EcuBattValue = 0 end

    -- Fuel
    sensor = system.getSensorByID(sensorId,6)
    if( sensor and sensor.valid ) then FuelValue = sensor.value else FuelValue = 0 end

    -- Speed
    --sensor = system.getSensorByID(sensorId,7)
    --if( sensor and sensor.valid ) then SpeedValue = sensor.value else SpeedValue = 0 end

    -- Status
    sensor = system.getSensorByID(sensorId,8)
    if( sensor and sensor.valid ) then StatusCode = sensor.value else StatusCode = 0 end

    -- Message
    sensor = system.getSensorByID(sensorId,9)
    if( sensor and sensor.valid ) then MessageCode = sensor.value else MessageCode = 0 end
 
    if newTime-lastTime > alternatingDelay then
        lastTime = newTime
        alternating = alternating +1
        if alternating > 4 then alternating = 0 end

        if alternating == 1 and not alternateRPM then alternating = 2 end
        if alternating == 2 and not alternateEGT then alternating = 3 end
        if alternating == 3 and not alternateBattV then alternating = 4 end
        if alternating == 4 and not alternateBatt then alternating = 0 end
        if alternating == 0 and alternateRPM then alternating = 1 end
        if alternating == 0 and alternateEGT then alternating = 2 end
        if alternating == 0 and alternateBattV then alternating = 3 end
        if alternating == 0 and alternateBatt then alternating = 4 end
    end
    
    collectgarbage()
end
return {init=init, loop=loop, author="DLPWings", version="1.00",name="Jet Central Info"}
