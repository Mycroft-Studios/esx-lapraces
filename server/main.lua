local Races = {}
local AvailableRaces = {}
local LastRaces = {}
local NotFinished = {}

-- Functions

local function SecondsToClock(seconds)
    seconds = tonumber(seconds)
    local retval
    if seconds <= 0 then
        retval = "00:00:00";
    else
        local hours = string.format("%02.f", math.floor(seconds / 3600));
        local mins = string.format("%02.f", math.floor(seconds / 60 - (hours * 60)));
        local secs = string.format("%02.f", math.floor(seconds - hours * 3600 - mins * 60));
        retval = hours .. ":" .. mins .. ":" .. secs
    end
    return retval
end

local function IsWhitelisted(identifier)
    local xPlayer = ESX.GetPlayerFromIdentifier(identifier)
    if xPlayer.group == "admin" then
        return true
    end
    return false
end

local function IsNameAvailable(RaceName)
    local retval = true
    for RaceId, _ in pairs(Races) do
        if Races[RaceId].RaceName == RaceName then
            retval = false
            break
        end
    end
    return retval
end

local function HasOpenedRace(CitizenId)
    local retval = false
    for _, v in pairs(AvailableRaces) do
        if v.SetupCitizenId == CitizenId then
            retval = true
        end
    end
    return retval
end

local function GetOpenedRaceKey(RaceId)
    local retval = nil
    for k, v in pairs(AvailableRaces) do
        if v.RaceId == RaceId then
            retval = k
            break
        end
    end
    return retval
end

local function GetCurrentRace(MyIdentifier)
    local retval = nil
    for RaceId, _ in pairs(Races) do
        for identifier, _ in pairs(Races[RaceId].Racers) do
            if identifier == MyIdentifier then
                retval = RaceId
                break
            end
        end
    end
    return retval
end

local function GetRaceId(name)
    local retval = nil
    for k, v in pairs(Races) do
        if v.RaceName == name then
            retval = k
            break
        end
    end
    return retval
end

local function GenerateRaceId()
    local RaceId = "LR-" .. math.random(1111, 9999)
    while Races[RaceId] do
        RaceId = "LR-" .. math.random(1111, 9999)
    end
    return RaceId
end

-- Events

RegisterNetEvent('esx-lapraces:server:FinishPlayer', function(RaceData, TotalTime, TotalLaps, BestLap)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local PlayersFinished = 0
    local AmountOfRacers = 0
    for _, v in pairs(Races[RaceData.RaceId].Racers) do
        if v.Finished then
            PlayersFinished = PlayersFinished + 1
        end
        AmountOfRacers = AmountOfRacers + 1
    end
    local BLap
    if TotalLaps < 2 then
        BLap = TotalTime
    else
        BLap = BestLap
    end
    if LastRaces[RaceData.RaceId] then
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] = {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = {
                [1] = xPlayer.get("firstname"),
                [2] = xPlayer.get("lastname")
            }
        }
    else
        LastRaces[RaceData.RaceId] = {}
        LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] = {
            TotalTime = TotalTime,
            BestLap = BLap,
            Holder = {
                [1] = xPlayer.get("firstname"),
                [2] = xPlayer.get("lastname")
            }
        }
    end
    if Races[RaceData.RaceId].Records and next(Races[RaceData.RaceId].Records) then
        if BLap < Races[RaceData.RaceId].Records.Time then
            Races[RaceData.RaceId].Records = {
                Time = BLap,
                Holder = {
                    [1] = xPlayer.get("firstname"),
                    [2] = xPlayer.get("lastname")
                }
            }
            MySQL.Async.execute('UPDATE lapraces SET records = ? WHERE raceid = ?',
                {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
            TriggerClientEvent('esx-phone:client:RaceNotify', src, 'You have won the WR from ' .. RaceData.RaceName ..
                ' disconnected with a time of: ' .. SecondsToClock(BLap) .. '!')
        end
    else
        Races[RaceData.RaceId].Records = {
            Time = BLap,
            Holder = {
                [1] = xPlayer.get("firstname"),
                [2] = xPlayer.get("lastname")
            }
        }
        MySQL.Async.execute('UPDATE lapraces SET records = ? WHERE raceid = ?',
            {json.encode(Races[RaceData.RaceId].Records), RaceData.RaceId})
        TriggerClientEvent('esx-phone:client:RaceNotify', src, 'You have won the WR from ' .. RaceData.RaceName ..
            ' put down with a time of: ' .. SecondsToClock(BLap) .. '!')
    end
    AvailableRaces[AvailableKey].RaceData = Races[RaceData.RaceId]
    TriggerClientEvent('esx-lapraces:client:PlayerFinishs', -1, RaceData.RaceId, PlayersFinished, xPlayer)
    if PlayersFinished == AmountOfRacers then
        if NotFinished and next(NotFinished) and NotFinished[RaceData.RaceId] and
            next(NotFinished[RaceData.RaceId]) then
            for _, v in pairs(NotFinished[RaceData.RaceId]) do
                LastRaces[RaceData.RaceId][#LastRaces[RaceData.RaceId] + 1] = {
                    TotalTime = v.TotalTime,
                    BestLap = v.BestLap,
                    Holder = {
                        [1] = v.Holder[1],
                        [2] = v.Holder[2]
                    }
                }
            end
        end
        Races[RaceData.RaceId].LastLeaderboard = LastRaces[RaceData.RaceId]
        Races[RaceData.RaceId].Racers = {}
        Races[RaceData.RaceId].Started = false
        Races[RaceData.RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        LastRaces[RaceData.RaceId] = nil
        NotFinished[RaceData.RaceId] = nil
    end
    TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('esx-lapraces:server:CreateLapRace', function(RaceName)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)

    if IsWhitelisted(xPlayer.identifier) then
        if IsNameAvailable(RaceName) then
            TriggerClientEvent('esx-lapraces:client:StartRaceEditor', src, RaceName)
        else
            xPlayer.showNotification('There is already a race with this name.', 'error')
        end
    else
        xPlayer.showNotification('You have not been authorized to race\'s to create.', 'error')
    end
end)

RegisterNetEvent('esx-lapraces:server:JoinRace', function(RaceData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local RaceName = RaceData.RaceData.RaceName
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local CurrentRace = GetCurrentRace(xPlayer.identifier)
    if CurrentRace then
        local AmountOfRacers = 0
        local PreviousRaceKey = GetOpenedRaceKey(CurrentRace)
        for _, _ in pairs(Races[CurrentRace].Racers) do
            AmountOfRacers = AmountOfRacers + 1
        end
        Races[CurrentRace].Racers[xPlayer.identifier] = nil
        if (AmountOfRacers - 1) == 0 then
            Races[CurrentRace].Racers = {}
            Races[CurrentRace].Started = false
            Races[CurrentRace].Waiting = false
            table.remove(AvailableRaces, PreviousRaceKey)
            xPlayer.showNotification('You were the only one in the race, the race had ended', 'error')
            TriggerClientEvent('esx-lapraces:client:LeaveRace', src, Races[CurrentRace])
        else
            AvailableRaces[PreviousRaceKey].RaceData = Races[CurrentRace]
            TriggerClientEvent('esx-lapraces:client:LeaveRace', src, Races[CurrentRace])
        end
        TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
    end
    Races[RaceId].Waiting = true
    Races[RaceId].Racers[Player.PlayerData.citizenid] = {
        Checkpoint = 0,
        Lap = 1,
        Finished = false
    }
    AvailableRaces[AvailableKey].RaceData = Races[RaceId]
    TriggerClientEvent('esx-lapraces:client:JoinRace', src, Races[RaceId], RaceData.Laps)
    TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
    local creatorsource = ESX.GetPlayerFromIdentifier(AvailableRaces[AvailableKey].SetupCitizenId).source
    if creatorsource ~= src then
        TriggerClientEvent('esx-phone:client:RaceNotify', creatorsource, string.sub(xPlayer.get("firstname"), 1, 1) ..
            '. ' .. xPlayer.get("lastname") .. ' the race has been joined!')
    end
end)

RegisterNetEvent('esx-lapraces:server:LeaveRace', function(RaceData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local RaceName
    if RaceData.RaceData then
        RaceName = RaceData.RaceData.RaceName
    else
        RaceName = RaceData.RaceName
    end
    local RaceId = GetRaceId(RaceName)
    local AvailableKey = GetOpenedRaceKey(RaceData.RaceId)
    local creatorsource = ESX.GetPlayerFromIdentifier(AvailableRaces[AvailableKey].SetupCitizenId).source
    if creatorsource ~= src then
        TriggerClientEvent('esx-phone:client:RaceNotify', creatorsource, string.sub(xPlayer.get("firstname"), 1, 1) ..
            '. ' .. xPlayer.get("lastname") .. ' the race has been delivered!')
    end
    local AmountOfRacers = 0
    for _, _ in pairs(Races[RaceData.RaceId].Racers) do
        AmountOfRacers = AmountOfRacers + 1
    end
    if NotFinished[RaceData.RaceId] then
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId] + 1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = {
                [1] = xPlayer.get("firstname"),
                [2] = xPlayer.get("lastname")
            }
        }
    else
        NotFinished[RaceData.RaceId] = {}
        NotFinished[RaceData.RaceId][#NotFinished[RaceData.RaceId] + 1] = {
            TotalTime = "DNF",
            BestLap = "DNF",
            Holder = {
                [1] = xPlayer.get("firstname"),
                [2] = xPlayer.get("lastname")
            }
        }
    end
    Races[RaceId].Racers[xPlayer.identifier] = nil
    if (AmountOfRacers - 1) == 0 then
        if NotFinished and next(NotFinished) and NotFinished[RaceId] and next(NotFinished[RaceId]) ~=
            nil then
            for _, v in pairs(NotFinished[RaceId]) do
                if LastRaces[RaceId] then
                    LastRaces[RaceId][#LastRaces[RaceId] + 1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = {
                            [1] = xPlayer.get("firstname"),
                            [2] = xPlayer.get("lastname")
                        }
                    }
                else
                    LastRaces[RaceId] = {}
                    LastRaces[RaceId][#LastRaces[RaceId] + 1] = {
                        TotalTime = v.TotalTime,
                        BestLap = v.BestLap,
                        Holder = {
                            [1] = xPlayer.get("firstname"),
                            [2] = xPlayer.get("lastname")
                        }
                    }
                end
            end
        end
        Races[RaceId].LastLeaderboard = LastRaces[RaceId]
        Races[RaceId].Racers = {}
        Races[RaceId].Started = false
        Races[RaceId].Waiting = false
        table.remove(AvailableRaces, AvailableKey)
        xPlayer.showNotification('You were the only one in the race.The race had ended.', 'error')
        TriggerClientEvent('esx-lapraces:client:LeaveRace', src, Races[RaceId])
        LastRaces[RaceId] = nil
        NotFinished[RaceId] = nil
    else
        AvailableRaces[AvailableKey].RaceData = Races[RaceId]
        TriggerClientEvent('esx-lapraces:client:LeaveRace', src, Races[RaceId])
    end
    TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
end)

RegisterNetEvent('esx-lapraces:server:SetupRace', function(RaceId, Laps)
    local xPlayer = ESX.GetPlayerFromId(source)
    if Races[RaceId] then
        if not Races[RaceId].Waiting then
            if not Races[RaceId].Started then
                Races[RaceId].Waiting = true
                AvailableRaces[#AvailableRaces + 1] = {
                    RaceData = Races[RaceId],
                    Laps = Laps,
                    RaceId = RaceId,
                    SetupCitizenId = xPlayer.identifier
                }
                TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
                SetTimeout(5 * 60 * 1000, function()
                    if Races[RaceId].Waiting then
                        local AvailableKey = GetOpenedRaceKey(RaceId)
                        for cid, _ in pairs(Races[RaceId].Racers) do
                            local RacerData = ESX.GetPlayerFromIdentifier(cid)
                            if RacerData then
                                TriggerClientEvent('esx-lapraces:client:LeaveRace', RacerData.source,
                                    Races[RaceId])
                            end
                        end
                        table.remove(AvailableRaces, AvailableKey)
                        Races[RaceId].LastLeaderboard = {}
                        Races[RaceId].Racers = {}
                        Races[RaceId].Started = false
                        Races[RaceId].Waiting = false
                        LastRaces[RaceId] = nil
                        TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
                    end
                end)
            else
                xPlayer.showNotification('The race is already running', 'error')
            end
        else
            xPlayer.showNotification('The race is already running', 'error')
        end
    else
        xPlayer.showNotification('This race does not exist :(', 'error')
    end
end)

RegisterNetEvent('esx-lapraces:server:UpdateRaceState', function(RaceId, Started, Waiting)
    Races[RaceId].Waiting = Waiting
    Races[RaceId].Started = Started
end)

RegisterNetEvent('esx-lapraces:server:UpdateRacerData', function(RaceId, Checkpoint, Lap, Finished)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local CitizenId = xPlayer.identifier

    Races[RaceId].Racers[CitizenId].Checkpoint = Checkpoint
    Races[RaceId].Racers[CitizenId].Lap = Lap
    Races[RaceId].Racers[CitizenId].Finished = Finished

    TriggerClientEvent('esx-lapraces:client:UpdateRaceRacerData', -1, RaceId, Races[RaceId])
end)

RegisterNetEvent('esx-lapraces:server:StartRace', function(RaceId)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local AvailableKey = GetOpenedRaceKey(RaceId)

    if RaceId then
        if AvailableRaces[AvailableKey].SetupCitizenId == xPlayer.identifier then
            AvailableRaces[AvailableKey].RaceData.Started = true
            AvailableRaces[AvailableKey].RaceData.Waiting = false
            for CitizenId, _ in pairs(Races[RaceId].Racers) do
                local xTarget = ESX.GetPlayerFromIdentifier(CitizenId)
                if xTarget then
                    TriggerClientEvent('esx-lapraces:client:RaceCountdown', xPlayer.source)
                end
            end
            TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
        else
            xPlayer.showNotification('You are not the creator of the race..', 'error')
        end
    else
        xPlayer.showNotification('You are not in a race..', 'error')
    end
end)

RegisterNetEvent('esx-lapraces:server:SaveRace', function(RaceData)
    local src = source
    local xPlayer = ESX.GetPlayerFromId(src)
    local RaceId = GenerateRaceId()
    local Checkpoints = {}
    for k, v in pairs(RaceData.Checkpoints) do
        Checkpoints[k] = {
            offset = v.offset,
            coords = v.coords
        }
    end
    Races[RaceId] = {
        RaceName = RaceData.RaceName,
        Checkpoints = Checkpoints,
        Records = {},
        Creator = xPlayer.identifier,
        RaceId = RaceId,
        Started = false,
        Waiting = false,
        Distance = math.ceil(RaceData.RaceDistance),
        Racers = {},
        LastLeaderboard = {}
    }
    MySQL.Async.insert('INSERT INTO lapraces (name, checkpoints, creator, distance, raceid) VALUES (?, ?, ?, ?, ?)',
        {RaceData.RaceName, json.encode(Checkpoints), xPlayer.identifier, RaceData.RaceDistance,
         GenerateRaceId()})
end)

-- Callbacks

ESX.RegisterServerCallback('esx-lapraces:server:GetRacingLeaderboards', function(_, cb)
    cb(Races)
end)

ESX.RegisterServerCallback('esx-lapraces:server:GetRaces', function(_, cb)
    cb(AvailableRaces)
end)

ESX.RegisterServerCallback('esx-lapraces:server:GetListedRaces', function(_, cb)
    cb(Races)
end)

ESX.RegisterServerCallback('esx-lapraces:server:GetRacingData', function(_, cb, RaceId)
    cb(Races[RaceId])
end)

ESX.RegisterServerCallback('esx-lapraces:server:HasCreatedRace', function(source, cb)
    cb(HasOpenedRace(ESX.GetPlayerFromId(source).identifier))
end)

ESX.RegisterServerCallback('esx-lapraces:server:IsAuthorizedToCreateRaces', function(source, cb, TrackName)
    cb(IsWhitelisted(ESX.GetPlayerFromId(source).identifier), IsNameAvailable(TrackName))
end)

ESX.RegisterServerCallback('esx-lapraces:server:CanRaceSetup', function(_, cb)
    cb(Config.RaceSetupAllowed)
end)

-- ESX.RegisterServerCallback('esx-lapraces:server:GetTrackData', function(_, cb, RaceId)
--     local result = MySQL.Sync.fetchAll('SELECT * FROM users WHERE identifier = ?', {Races[RaceId].Creator})
--     if result[1] then
--         result[1].charinfo = json.decode(result[1].charinfo)
--         cb(Races[RaceId], result[1])
--     else
--         cb(Races[RaceId], {
--             charinfo = {
--                 firstname = "Unknown",
--                 lastname = "Unknown"
--             }
--         })
--     end
-- end)

-- Commands

-- QBCore.Commands.Add("cancelrace", "Cancel going race..", {}, false, function(source, args)
--     local Player = QBCore.Functions.GetPlayer(source)

--     if IsWhitelisted(Player.PlayerData.citizenid) then
--         local RaceName = table.concat(args, " ")
--         if RaceName then
--             local RaceId = GetRaceId(RaceName)
--             if Races[RaceId].Started then
--                 local AvailableKey = GetOpenedRaceKey(RaceId)
--                 for cid, _ in pairs(Races[RaceId].Racers) do
--                     local RacerData = QBCore.Functions.GetPlayerByCitizenId(cid)
--                     if RacerData then
--                         TriggerClientEvent('esx-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
--                     end
--                 end
--                 table.remove(AvailableRaces, AvailableKey)
--                 Races[RaceId].LastLeaderboard = {}
--                 Races[RaceId].Racers = {}
--                 Races[RaceId].Started = false
--                 Races[RaceId].Waiting = false
--                 LastRaces[RaceId] = nil
--                 TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
--             else
--                 TriggerClientEvent('QBCore:Notify', source, 'This race has not started yet.', 'error')
--             end
--         end
--     else
--         TriggerClientEvent('QBCore:Notify', source, 'You have not been authorized to do this.', 'error')
--     end
-- end)

-- ESX.RegisterCommand('cancelrace', 'admin', function(xPlayer, args, showError)
--     if IsWhitelisted(Player.PlayerData.citizenid) then
--         local RaceName = table.concat(args, " ")
--         if RaceName then
--             local RaceId = GetRaceId(RaceName)
--             if Races[RaceId].Started then
--                 local AvailableKey = GetOpenedRaceKey(RaceId)
--                 for cid, _ in pairs(Races[RaceId].Racers) do
--                     local RacerData = QBCore.Functions.GetPlayerByCitizenId(cid)
--                     if RacerData then
--                         TriggerClientEvent('esx-lapraces:client:LeaveRace', RacerData.PlayerData.source, Races[RaceId])
--                     end
--                 end
--                 table.remove(AvailableRaces, AvailableKey)
--                 Races[RaceId].LastLeaderboard = {}
--                 Races[RaceId].Racers = {}
--                 Races[RaceId].Started = false
--                 Races[RaceId].Waiting = false
--                 LastRaces[RaceId] = nil
--                 TriggerClientEvent('esx-phone:client:UpdateLapraces', -1)
--             else
--                 TriggerClientEvent('QBCore:Notify', source, 'This race has not started yet.', 'error')
--             end
--         end
--     else
--         TriggerClientEvent('QBCore:Notify', source, 'You have not been authorized to do this.', 'error')
--     end
-- end, false, {help = "Turn on / off racing setup"})


ESX.RegisterCommand('togglesetup', 'admin', function(xPlayer, args, showError)
    if IsWhitelisted(xPlayer.identifier) then
        Config.RaceSetupAllowed = not Config.RaceSetupAllowed
        if not Config.RaceSetupAllowed then
            xPlayer.showNotification('No more races can be created!', 'error')
        else
            xPlayer.showNotification('Races can be created again!', 'success')
        end
    else
        xPlayer.showNotification('You have not been authorized to do this.', 'error')
    end
end, false, {help = "Turn on / off racing setup"})

-- Threads

CreateThread(function()
    local races = MySQL.Sync.fetchAll('SELECT * FROM lapraces', {})
    if races[1] then
        for _, v in pairs(races) do
            local Records = {}
            if v.records then
                Records = json.decode(v.records)
            end
            Races[v.raceid] = {
                RaceName = v.name,
                Checkpoints = json.decode(v.checkpoints),
                Records = Records,
                Creator = v.creator,
                RaceId = v.raceid,
                Started = false,
                Waiting = false,
                Distance = v.distance,
                LastLeaderboard = {},
                Racers = {}
            }
        end
    end
end)
