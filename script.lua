-- Author: SIMPLE MARK
-- GitHub: https://github.com/THE-SIMPLE-MARK
-- Workshop: https://steamcommunity.com/id/thesimplemark/myworkshopfiles/?appid=573090
--
-- Developed using LifeBoatAPI - Stormworks Lua plugin for VSCode - https://code.visualstudio.com/download (search "Stormworks Lua with LifeboatAPI" extension)
--      By Nameous Changey (Please retain this notice at the top of the file as a courtesy; a lot of effort went into the creation of these tools.)

pairedData = {} -- Stores: [peerId] { vehicleId, pairType }
vehicleOwners = {} -- Stores: [vehicleId] peerId
vehiclesToBeChecked = {} -- Stores: [vehicleId] peerId
delays = {} -- Stores: [vehicleId] delay (number or false)
alarmNotif = {} --Stores: [vehicleId] bolean
globalVehicleData = {} --Stores [index] { vehicleId, posX, posY, posZ, mass, characterNo, voxelNo, vulnerable, surfaceOnFireCount }
globalPlayerData = {} --Stores [index] { objectId, hp, incapacitated, isAi, name }
globalPlayerSettings = {
    [0] = {
        ["weaponMode"] = false,
        ["weaponModeOffIterDone"] = false,
        ["hideHud"] = false
    }
} -- Stores: [peerId] { weaponMode, weaponModeOffIterDone, hideHud }
tilePresets = {
    "island_15",
    "island_43_multiplayer_base",
    "island_34_military",
    "island_25",
    "island_12",
    "test_tile",
    "island_24",
    "island_33_tile_33",
    "island_33_tile_32",
    "island_33_tile_end",
    "island_29_playerbase_submarine",
    "island_32_playerbase_heli",
    "island_30_playerbase_boat",
    "island_31_playerbase_combo",
    "oil_rig_playerbase",
    "arctic_island_playerbase",
    "arctic_tile_22",
    "arctic_tile_12_oilrig",
    "mega_island_2_6",
    "mega_island_12_5",
    "mega_island_9_8",
    "mega_island_15_2",
}
ticks = 0 -- tick counter
updateInterval = 10 -- the amount of ticks between each update

function onTick()
    ticks = ticks + 1
    --server.announce("[Stormband]", "PeerId: 0; weaponMode: " .. (globalPlayerSettings[0].weaponMode and "true" or "false") .. "; weaponModeOffIterDone: " .. (globalPlayerSettings[0].weaponModeOffIterDone and "true" or "false") .. "; hideHud: " .. (globalPlayerSettings[0].hideHud and "true" or "false"))

    -- get connected players
    playerList = server.getPlayers()

    -- decrease check delays by 1
    for i,v in pairs(delays) do
        delays[i] = v>0 and (v-1) or false
    end
    -- iterate through each vehicle to send notifications
    for vehicleId, peerId in pairs(vehiclesToBeChecked) do
        if (delays[vehicleId] == nil) then delays[vehicleId] = 60 end

        if (delays[vehicleId] == false) then
            local dialData, success = server.getVehicleDial(vehicleId, "sb-pairable")

            if (success and dialData.value ~= nil) then
                local value = dialData.value
                if (value ~= 0 and ( (value > 0 and value <= 6.1) or value == -1) ) then -- make sure the value is a valid sb-pairable type
                    server.notify(peerId, "New StormBand Compatible Vehicle Found", "Please refer to the instructions on its workshop page on how to pair.", 7)
                end
            end

            vehiclesToBeChecked[vehicleId] = nil
            delays[vehicleId] = nil
        end
    end
    -- tick limiter to counter the performance issues
    if (ticks % updateInterval == 0) then
        -- iterate through each vehicle in globalVehicleData and update its data
        for index, data in ipairs(globalVehicleData) do
            local vehicleId = data["vehicleId"]

            local vehicleData, success1 = server.getVehicleData(vehicleId)
            local surfaceOnFireCount, success2 = server.getVehicleFireCount(vehicleId)
            local vehicleMatrix, success3 = server.getVehiclePos(vehicleId)
            local vehicleName, success4 = server.getVehicleName(vehicleId)

            if (success1 and success2 and success3 and success4) then
                local posX, posY, posZ = matrix.position(vehicleMatrix)

                globalVehicleData[index] = {
                    vehicleId = vehicleId,
                    name = vehicleName,
                    posX = posX,
                    posY = posY,
                    posZ = posZ,
                    mass = vehicleData["mass"],
                    characterNo = tableLength(vehicleData["characters"]) / 3,
                    voxelNo = vehicleData["voxels"],
                    vulnerable = not vehicleData["invulnerable"] and 1 or 0,
                    surfaceOnFireCount = surfaceOnFireCount
                }
            end
        end
        -- iterate through each connected player and update their data in globalPlayerData
        for peerIndex, peerData in pairs(playerList) do
            local peerId = peerData.id
            local playerMatrix, success1 = server.getPlayerPos(peerId)
            local objectId, success2 = server.getPlayerCharacterID(peerId)
            if (success1 and success2) then
                local playerData = server.getCharacterData(objectId)

                globalPlayerData[peerId] = {
                    objectId = objectId,
                    hp = playerData.hp,
                    incapacitated = playerData.incapacitated,
                    isAi = playerData.ai,
                    name = playerData["name"],
                    isWeaponModeEnabled = playerData["weaponModeEnabled"]
                }
            end
        end
    end

    -- iterate through each peer and update their StormBand
    for peerIndex, peerData in pairs(playerList) do
        local peerId = peerData.id
        local hasStormBand = hasStormBand(peerId)
        local vehicleId = nil
        local hide = false

        -- only get the data if the pairedData table exists for the peer
        if (pairedData[peerId] ~= nil) then
            vehicleId = pairedData[peerId].vehicleId
        end
        if (globalPlayerSettings[peerId] ~= nil) then
            hide = globalPlayerSettings[peerId].hideHud
            weaponMode = globalPlayerSettings[peerId].weaponMode
        end

        -- check if vehicle is still spawned by getting its name
        local vehicleName, success1 = server.getVehicleName(vehicleId)

        local paired = pairedData[peerId] ~= nil

        if (hasStormBand and not hide) then
            server.setPopupScreen(peerId, 0, "", true, "[ StormBand ]", 0, 0.94)
        else
            server.setPopupScreen(peerId, 0, "", false, "[ StormBand ] ", 0, 0.94)
        end

        if (weaponMode) then
            server.setPopupScreen(peerId, 1, "", true, "[ Weapons ]\n[ Mode On ]", 0, 0.80)
        elseif (hasStormBand and not hide) then
            server.setPopupScreen(peerId, 1, "", true, "Paired with " .. vehicleName, 0, 0.80)
        end

        local vehicleMatrix = server.getVehiclePos(vehicleId)
        local playerMatrix, success4 = server.getPlayerPos(peerId)
        local distance = matrix.distance(playerMatrix, vehicleMatrix)

        if (hasStormBand and paired and not hide and success4) then
            local posX, posY, posZ = matrix.position(vehicleMatrix)

            if (distance < 1000) then server.setPopupScreen(0, 2, "", true, string.format("Vehicle location:\nX: %.1f\nY: %.1f\nDist: %.1fm", posX, posZ, distance), 0.90, -0.85)
            elseif (distance > 1000) then server.setPopupScreen(0, 2, "", true, string.format("Vehicle location:\nX: %.1f\nY: %.1f\nDist: %.1fkm", posX, posZ, distance/1000), 0.90, -0.85) end
        else
            server.setPopupScreen(peerId, 1, "", false, "", 0, 0.80)
            server.setPopupScreen(peerId, 2, "", false, "", 0.90, -0.85)
        end

        if (hasStormBand and paired) then
            -- check if the alarm has been triggered on the vehicle
            -- when triggered, send a notification and display a new UI element
            -- when the notification is sent, also add a value to the alarmNotif table to prevent sending the notification at each tick
            local alarmState, playerAm = getAlarmState(vehicleId)
            local storedAlarmNotif = alarmNotif[vehicleId]
            -- alarm is sounded for the first time, notify player, display UI element, add to table
            if (alarmState == true and storedAlarmNotif == nil and hasStormBand) then
                alarmNotif[vehicleId] = true
                server.notify(peerId, "Alarm Triggered", string.format("The alarm has been triggered on your vehicle, there are currently %.0f people near it.", playerAm), 6)
                if (not hide) then
                    server.setPopupScreen(peerId, 3, "", true, string.format("ALARM\nTRIGGERED\n-------------\nLifeforms Detected: %.0f", playerAm), 0.73, -0.85)
                else
                    server.setPopupScreen(peerId, 3, "", false, "", 0.73, -0.85)
                end
            -- alarm is sounded after the first time, update UI element
            elseif (alarmState == true and storedAlarmNotif == true and hasStormBand) then
                if (not hide) then
                    server.setPopupScreen(peerId, 3, "", true, string.format("ALARM\nTRIGGERED\n-------------\nLifeforms Detected: %.0f", playerAm), 0.73, -0.85)
                else
                    server.setPopupScreen(peerId, 3, "", false, "", 0.73, -0.85)
                end
            -- alarm is not sounded, delete the value from the table regardless of its state, hide UI element
            elseif (alarmState == false) then
                alarmNotif[vehicleId] = nil
                server.setPopupScreen(peerId, 3, "", false, "", 0.73, -0.85)
            -- just remove the UI element as a failsafe
            else
                server.setPopupScreen(peerId, 3, "", false, "", 0.73, -0.85)
            end

            -- tick limiter to counter the performance issues
            if (ticks % updateInterval == 0) then
                -- get and update all relevant data to keypads if requested
                local requestDialData, success0 = server.getVehicleDial(vehicleId, "sb-require-playerdata")
                if (success0 and requestDialData.value == 1) then
                    if (success1) then server.setVehicleKeypad(vehicleId, "sb-playerdata-peerid", peerId) end

                    local playerMatrix, success2 = server.getPlayerPos(peerId)
                    local playerX, playerY, playerZ = matrix.position(playerMatrix)
                    if (success2) then
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-posx", playerX)
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-posy", playerZ)
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-posz", playerY)
                    end

                    local lookX, lookY, lookZ, success3 = server.getPlayerLookDirection(peerId)
                    if (success3) then
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-lookx", lookX)
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-looky", lookZ)
                        server.setVehicleKeypad(vehicleId, "sb-playerdata-lookz", lookY)
                    end

                    playerObjectId, success4 = server.getPlayerCharacterID(peerId)
                    if (success4) then
                        local playerData = server.getCharacterData(playerObjectId)
                        if (playerData ~= nil) then
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-hp", playerData["hp"])
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-isincapacitated", playerData["incapacitated"] and 1 or 0)
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-isdead", playerData["dead"] and 1 or 0)
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-isinteractible", playerData["interactible"] and 1 or 0)

                            server.setVehicleKeypad(vehicleId, "sb-playerdata-id", playerList[peerIndex]["id"])
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-isadmin", playerList[peerIndex]["admin"] and 1 or 0)
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-isauth", playerList[peerIndex]["auth"] and 1 or 0)
                            server.setVehicleKeypad(vehicleId, "sb-playerdata-steamid", playerList[peerIndex]["steam_id"])
                        end
                    end
                end

                local requestDialData2, success5 = server.getVehicleDial(vehicleId, "sb-require-vehicledata")
                if (success5 and requestDialData2.value == 1) then
                    local vehicleData, success6 = server.getVehicleData(vehicleId)
                    if (success6) then
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-mass", vehicleData["mass"])
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-characterno", tableLength(vehicleData["characters"]) / 3)
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-voxelno", vehicleData["voxels"])
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-iseditable", vehicleData["editable"] and 1 or 0)
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-isvulnerable", not vehicleData["invulnerable"] and 1 or 0)
                    end

                    local fireCount, success2 = server.getVehicleFireCount(vehicleId)
                    if (success2) then
                        server.setVehicleKeypad(vehicleId, "sb-vehicledata-firecount", fireCount)
                    end
                end

                local requestDialData3, success6 = server.getVehicleDial(vehicleId, "sb-require-globalvehicledata")
                if (success6 and requestDialData3.value == 1) then
                    local requestedVehicle, success7 = server.getVehicleDial(vehicleId, "sb-globalvehicledata-requestid")
                    if (success7 and requestedVehicle.value > 0) then
                        if (globalVehicleData[requestedVehicle.value] ~= nil) then
                            local requestedVehicleVal = requestedVehicle.value
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-posx", globalVehicleData[requestedVehicleVal].posX)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-posy", globalVehicleData[requestedVehicleVal].posZ)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-posz", globalVehicleData[requestedVehicleVal].posY)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-mass", globalVehicleData[requestedVehicleVal].mass)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-characterno", globalVehicleData[requestedVehicleVal].characterNo)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-voxelno", globalVehicleData[requestedVehicleVal].voxelNo)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-isvulnerable", globalVehicleData[requestedVehicleVal].vulnerable)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-firecount", globalVehicleData[requestedVehicleVal].surfacesOnFire)
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-notfound", 0)
                        else
                            server.setVehicleKeypad(vehicleId, "sb-globalvehicledata-notfound", 1)
                        end
                    end
                end

                local requestDialData4, success8 = server.getVehicleDial(vehicleId, "sb-require-tiledata")
                if (success8 and requestDialData4.value == 1) then
                    local requestedTile, success9 = server.getVehicleDial(vehicleId, "sb-tiledata-requestid")
                    if (success9 and requestedTile.value > 0) then
                        local vehicleMatrix, success10 = server.getVehiclePos(vehicleId)
                        local tileMatrix, success11 = server.getTileTransform(vehicleMatrix, "data/tiles/" .. tilePresets[requestedTile.value] .. ".xml")
                        local tileData, success12 = server.getTile(tileMatrix)
                        if (success10 and success11 and success12) then
                            local tileX, tileY, tileZ = matrix.position(tileMatrix)

                            server.setVehicleKeypad(vehicleId, "sb-tiledata-posx", tileX)
                            server.setVehicleKeypad(vehicleId, "sb-tiledata-posy", tileZ)
                            server.setVehicleKeypad(vehicleId, "sb-tiledata-posz", tileY)
                            server.setVehicleKeypad(vehicleId, "sb-tiledata-seafloorheight", tileData["sea_floor"])
                            server.setVehicleKeypad(vehicleId, "sb-tiledata-cost", tileData["cost"])
                            server.setVehicleKeypad(vehicleId, "sb-tiledata-ispurchased", tileData["purchased"] and 1 or 0)
                        end
                    end
                end

                local requestDialData6, success14 = server.getVehicleDial(vehicleId, "sb-require-gamedata")
                if (success14 and requestDialData6.value == 1) then
                    local sysTimeDay, sysTimeMonth, sysTimeYear = server.getDate()
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-tutorialdone", server.getTutorial() and 1 or 0)
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-money", server.getCurrency())
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-researchpoints", server.getResearchPoints())
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-dayssurvived", server.getDateValue())
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-gamedate-day", sysTimeDay)
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-gamedate-month", sysTimeMonth)
                    server.setVehicleKeypad(vehicleId, "sb-gamedata-gamedate-year", sysTimeYear)
                end

                local requestDialData5, success13 = server.getVehicleDial(vehicleId, "sb-require-miscdata")
                if (success13 and requestDialData5.value == 1) then
                    server.setVehicleKeypad(vehicleId, "sb-miscdata-systime", server.getTimeMillisec())
                end

                -- weapon mode
                if (weaponMode and hasWeapon(peerId)) then
                    for peerIterId, data in pairs(globalPlayerData) do
                        if (peerIterId == peerId) then goto continue end
                        if (#data.name > 11) then
                            server.setPopup(peerId, peerIterId+10, "", true, "[ Player ]", 0, 0, 0, 1000, nil, data.objectId)
                        else
                            server.setPopup(peerId, peerIterId+10, "", true, "[".. data.name .."]", 0, 0, 0, 1000, nil, data.objectId)
                        end
                        ::continue::
                    end
                    for index, data in pairs(globalVehicleData) do
                        if (data.vehicleId == vehicleId) then goto continue end
                        local itrVehicleMatrix = matrix.translation(data.posX, data.posY, data.posZ)

                        if (not data.vulnerable == 1 and (#data.name > 11 or data.name == "autosave")) then
                            server.setPopup(peerId, index+43, "", true, string.format("[ Vehicle  ]\n[Invincible]\nDist:%.0fm\nChar No:%.0f", matrix.distance(playerMatrix, itrVehicleMatrix), data.characterNo), 0, 3, 0, 1000, data.vehicleId, nil)
                        elseif (data.vulnerable == 1 and (#data.name > 11 or data.name == "autosave")) then
                            server.setPopup(peerId, index+43, "", true, string.format("[ Vehicle ]\nDist:%.0fm\nChar No:%.0f", matrix.distance(playerMatrix, itrVehicleMatrix), data.characterNo), 0, 3, 0, 1000, data.vehicleId, nil)
                        else
                            server.setPopup(peerId, index+43, "", true, string.format("[ Vehicle ]\nDist:%.0fm\nChar No:%.0f", matrix.distance(playerMatrix, itrVehicleMatrix), data.characterNo), 0, 3, 0, 1000, data.vehicleId, nil)
                        end
                        ::continue::
                    end
                else
                    for i = 0, tableLength(globalPlayerData) do
                        server.removePopup(peerId, i+10)
                    end
                    for i = 0, tableLength(globalVehicleData) do
                        server.removePopup(peerId, i+43)
                    end
                    globalPlayerSettings[peerId].weaponModeOffIterDone = true -- this is used to prevent the weapon mode off loop from running multiple times
                end
            end
        end
    end
end

function onVehicleSpawn(vehicleId, peerId, x, y, z, cost)
    -- return if the vehicle was spawned by a script
    if peerId==-1 then return end
    -- don't check if the player doesn't have a StormBand
    if (not hasStormBand(peerId)) then return end

    -- add peerId to a table to check in the onVehicleLoad callback since that doesn't provide the peerId
    vehicleOwners[vehicleId] = peerId
end

function onVehicleLoad(vehicleId)
    local peerId = vehicleOwners[vehicleId]

    -- return if the vehicle was spawned before the addon was initated
    if peerId == nil then return end

    vehiclesToBeChecked[vehicleId] = peerId

    -- delete the table enetry
    vehicleOwners[vehicleId] = nil

    -- add vehicle to globalVehicleData table
    --Stores [vehicleId] { posX, posY, posZ, mass, characterNo, voxelNo, vulnerable, surfaceOnFireCount }
    local vehicleMatrix, success1 = server.getVehiclePos(vehicleId)
    local vehicleData, success2 = server.getVehicleData(vehicleId)

    if (success1 and success2) then
        local posX, posY, posZ = matrix.position(vehicleMatrix)
        -- using table.insert and table.remove to take care of gaps (needed so you won't come accross empty gaps when cycling through each detected vehicle on your vehicle)
        table.insert(globalVehicleData, {
            vehicleId = vehicleId,
            posX = posX,
            posY = posY,
            posZ = posZ,
            mass = vehicleData["mass"],
            characterNo = tableLength(vehicleData["characters"]) / 3,
            voxelNo = vehicleData["voxels"],
            vulnerable = not vehicleData["invulnerable"] and 1 or 0,
            surfaceOnFireCount = 0
        })
    end
end

function onVehicleDespawn(vehicleId, peerId)
    -- unpair the vehicle if it gets despawned
    -- search by the vehicleId in the pairedData
    for peerIdT, data in pairs(pairedData) do
        if (vehicleId == pairedData[peerIdT]["vehicleId"]) then
            if (pairedData[peerIdT] ~= nil) then
                pairedData[peerIdT] = nil
                server.setVehicleKeypad(vehicleId, "sb-ispaired", 0)
                server.notify(peerIdT, "Disconnected From Vehicle", "Your vehicle was despawned.", 6)
                break
            end
        end
    end

    -- iterate over each vehicle until the vehicle with the correct ID is found
    -- when/if found, remove from table
    for index, data in ipairs(globalVehicleData) do
        if (vehicleId == data["vehicleId"]) then
            table.remove(globalVehicleData, index)
            break
        end
    end
end

function onVehicleUnload(vehicleId)
    -- unpair the vehicle if it gets unloaded
    -- search by the vehicleId in the pairedData
    for peerIdT, data in pairs(pairedData) do
        if (vehicleId == pairedData[peerIdT]["vehicleId"]) then
            if (pairedData[peerIdT] ~= nil) then
                pairedData[peerIdT] = nil
                server.setVehicleKeypad(vehicleId, "sb-ispaired", 0)
                server.notify(peerIdT, "Disconnected From Vehicle", "Your vehicle was unloaded, this can be caused by going too far away from the vehicle. Please add a keep active block to the creation to prevent this from happening.", 6)
                break
            end
        end
    end

    -- iterate over each vehicle until the vehicle with the correct ID is found
    -- when/if found, remove from table
    for index, data in ipairs(globalVehicleData) do
        if (vehicleId == data["vehicleId"]) then
            table.remove(globalVehicleData, index)
            break;
        end
    end
end

-- remove player from tables if they disconnect
function onPlayerLeave(peerId)
    pairedData[peerId] = nil
    globalPlayerData[peerId] = nil
    globalPlayerData = nil
end

-- handle disasters by collecting all disasters to one function
-- 1: forest fire; 2: tornado; 3: meteor; 4: tsunami; 5: whirlpool; 6: volcano
function onDisaster(disasterId, transform, magnitude)
    for peerId, data in pairs(pairedData) do
        local vehicleId = data.vehicleId
        local posX, posZ, posY = matrix.position(transform)
        local requestDial, success = server.getVehicleDial(vehicleId, "sb-require-disasterdata")
        if (success and requestDial.value == 1) then
            server.setVehicleKeypad(vehicleId, "sb-disasterdata-id", disasterId)
            server.setVehicleKeypad(vehicleId, "sb-disasterdata-posX", posX)
            server.setVehicleKeypad(vehicleId, "sb-disasterdata-posY", posY)
            server.setVehicleKeypad(vehicleId, "sb-disasterdata-posZ", posZ)
            server.setVehicleKeypad(vehicleId, "sb-disasterdata-magnitude", magnitude)
        end
    end
end

function onForestFireSpawned(fireObjectiveId, fireX, fireY, fireZ)
    onDisaster(1, matrix.translation(fireX, fireY, fireZ), 0)
end
function onTornado(transform)
    onDisaster(2, transform, 0)
end
function onMeteor(transform, magnitude)
    onDisaster(3, transform, magnitude)
end
function onTsunami(transform, magnitude)
    onDisaster(4, transform, magnitude)
end
function onWhirlpool(transform, magnitude)
    onDisaster(5, transform, magnitude)
end
function onVolcano(transform, magnitude)
    onDisaster(6, transform, magnitude)
end

function onButtonPress(vehicleId, peerId, buttonName)
    local buttonState, success1 = server.getVehicleButton(vehicleId, buttonName)
    server.announce("button pressed on" .. vehicleId)

    if (success1 and buttonName == "Pair with StormBand" and buttonState.on and hasStormBand(peerId)) then
        server.announce("button press verified")
        local name, success2 = server.getVehicleName(vehicleId)
        local dialData, success3 = server.getVehicleDial(vehicleId, "sb-pairable")
        local roundedDial = tonumber(string.format("%.1f", dialData.value))
        local isAlreadyPaired = false

        -- check if the vehicle has been paired with someone else already
        for peerIdT, data in pairs(pairedData) do
            if (vehicleId == pairedData[peerIdT]["vehicleId"]) then
                isAlreadyPaired = true
            end
        end

        if (success2 and success3 and pairedData[peerId] == nil and not isAlreadyPaired) then
            server.notify(peerId, "StormBand Paired", "Successfully paired with " .. name .. ".", 7)

            pairedData[peerId] = {
                ["vehicleId"] = vehicleId,
                ["pairType"] = roundedDial,
                ["hide"] = false
            }
            server.setVehicleKeypad(vehicleId, "sb-ispaired", 1)

        elseif (pairedData[peerId] ~= nil) then
            server.notify(peerId, "StormBand Pairing Error", "You have alr  eady paired with a vehicle use the command ?sb unpair to unpair.", 6)
        elseif (isAlreadyPaired) then
            server.notify(peerId, "Someone has already paired with this vehice. Due to in-game limitations, only one person can be paired to a vehicle at a time.", 6)
        else
            server.notify(peerId, "StormBand Pairing Error", "There was an error while trying to pair with that vehicle.", 6)
        end
    end
end

function onCustomCommand(fullMessage, peerId, isAdmin, isAuth, command, arg1, arg2, arg3, arg4)
    -- check if player has a StormBand
    if (not hasStormBand(peerId) and (command == "?sb" and arg1 ~= "help")) then
        server.announce("[StormBand]", "You do not have a StormBand. You can get one by putting a compass in your last inventory slot.")
        return
    end

    local paired = pairedData[peerId] ~= nil
    local vehicleId = nil
    local pairType = -1
    local summon = false

    -- only get vehicleId if the pairedData table exists for the peer
    if (pairedData[peerId] ~= nil) then
        vehicleId = pairedData[peerId]["vehicleId"]
        pairType, summon = math.modf(pairedData[peerId]["pairType"])
        summon = math.abs(summon) > 0 or pairType == -1
    end

    -- the actual commands
    if (command == "?sb" and arg1 == "help") then
        server.announce("[StormBand]", "Available commands:", peerId)
        server.announce("[StormBand]", "NOTICE: These commands are only usable if you have a StormBand.", peerId)
        server.announce("[StormBand]", "?sb unpair - Unpair the currently paired vehicle.", peerId)
        server.announce("[StormBand]", "?sb func [function numbers] - Execute pre-defined functions on the vehicle, see workshop page for details.", peerId)
        server.announce("[StormBand]", "?sb summon - Call your vehicle to you if supported.", peerId)
        server.announce("[StormBand]", "?sb hide - Hide you StormBand's HUD.", peerId)
        server.announce("[StormBand]", "?sb weapon mode - Activate weapon mode. (Alias: ?wm)", peerId)

    elseif (command == "?sb" and arg1 == "unpair" and paired) then
        pairedData[peerId] = nil
        server.setVehicleKeypad(vehicleId, "sb-ispaired", 0)
        server.notify(peerId, "Disconnected From Vehicle", "Successfully disconnected from your paired vehicle.", 7)

    elseif (command == "?sb" and arg1 == "func" and arg2 ~= nil and paired) then
        local funcNumber = tonumber(arg2)
        if (funcNumber == nil) then
            server.announce("[StormBand]", "You did not provide a valid function ID. Please check the workshop page for details.", peerId)
            return
        elseif (funcNumber <= 0 or funcNumber > 6.1) then
            server.announce("[StormBand]", "You did not provide a valid function ID. Please check the workshop page for details.", peerId)
            return
        end
        -- iterate through each possible type and only accept the functionNumber accordingly
        for i = -1, 6 do
            if (i == pairType) then
                if (i == -1) then
                    server.pressVehicleButton(vehicleId, "sb-func-".. funcNumber)
                    server.notify(peerId, "Command Sent", "The command was sent to your paired vehicle.", 7)
                    break
                elseif (i == 0) then goto continue end

                if (funcNumber <= 0 or funcNumber > i) then
                    server.announce("[StormBand]", "You cannot use that function on your paired vehicle. Please check the workshop page for details.", peerId)
                    break
                elseif (funcNumber <= i and funcNumber > 0) then
                    server.pressVehicleButton(vehicleId, "sb-func-".. funcNumber)
                    server.notify(peerId, "Command Sent", "The command was sent to your paired vehicle.", 7)
                    break
                end
            end
            ::continue::
        end

    elseif (command == "?sb" and arg1 == "summon" and paired) then
        if (summon) then
            server.pressVehicleButton(vehicleId, "sb-summon")
            server.notify(peerId, "Vehicle Summoned", "Your vehicle should be on it's way to you.", 7)
        else
            server.announce("[StormBand]", "You cannot use SM Summon on your paired vehicle. Please check the workshop page for details.", peerId)
        end

    elseif (command == "?sb" and arg1 == "hide" and paired) then
        if (pairedData[peerId].hideHud == false) then
            pairedData[peerId].hideHud = true
            server.announce("[StormBand]", "Your StormBand's HUD is now hidden.", peerId)
        elseif (pairedData[peerId].hideHud == true) then
            pairedData[peerId].hideHud = false
            server.announce("[StormBand]", "Your StormBand's HUD is now on.", peerId)
        end

    elseif ((command == "?sb" and arg1 == "weapon" and arg2 == "mode") or command == "?wm") then
        if (globalPlayerSettings[peerId].weaponMode == false) then
            globalPlayerSettings[peerId].weaponMode = true
            globalPlayerSettings[peerId].weaponModeOffIterDone = false
            server.announce("[StormBand]", "Weapons mode activated.", peerId)
        elseif (globalPlayerSettings[peerId].weaponMode == true) then
            globalPlayerSettings[peerId].weaponMode = false
            server.announce("[StormBand]", "Weapons mode deactivated.", peerId)
        end

    elseif (not paired and command == "?sb") then
        server.announce("[StormBand]", "You are not paired with a vehicle.", peerId)
    end
end

-- check if peer has a StormBand
function hasStormBand(peerId)
    local objectId, success1 = server.getPlayerCharacterID(peerId)
    local equipmentId, success2 = server.getCharacterItem(objectId, 5)
    if (not success1 or not success2) then
        return false
    end
    return equipmentId == 8
end

function hasWeapon(peerId)
    local objectId, success1 = server.getPlayerCharacterID(peerId)
    local equipmentId, success2 = server.getCharacterItem(objectId, 1)
    if (not success1 or not success2) then
        return false
    end
    return equipmentId == 31 or equipmentId == 33 or equipmentId == 35 or equipmentId == 37 or equipmentId == 39 or equipmentId == 41
end

-- get the alarm state of the vehicle
function getAlarmState(vehicleId)
    local data, isSuccess = server.getVehicleDial(vehicleId, "sb-alarm")
    if (data ~= nil and isSuccess) then
        if (data.value > 0 and isSuccess) then
            return true, data.value
        else
            return false, 0
        end
    end
end

-- get the length of a table with gaps
function tableLength(T)
    local count = 0
    for _ in pairs(T) do count = count + 1 end
    return count
end