--Screening Bot Attack:
--First find bots with lower health than my bot, and then select bots with lower energy than my bot from these bots.
--Finally, sort by short distance, take out the first bot to attack.
--kaxiu(mark)
-- Initializing global variables to store the latest game state and game host process.
LatestGameState = LatestGameState or nil

CRED = "Sa0iBLPNyJQrwpTTG-tWLQU-1QeUAJA73DdxGGiKoJc"

--Pick a Grid To Join
--Grid 1 - Bikini Bottom
Game = "-vsAs0-3xQw6QUAYbUuonTbXAnFNJtzqhriKKOymQ9w"

InAction = InAction or false -- Prevents the agent from taking multiple actions at once.

Logs = Logs or {}

colors = {
    red = "\27[31m",
    green = "\27[32m",
    blue = "\27[34m",
    reset = "\27[0m",
    gray = "\27[90m"
}


-- Checks if two points are within a given range.
-- @param x1, y1: Coordinates of the first point.
-- @param x2, y2: Coordinates of the second point.
-- @param range: The maximum allowed distance between the points.
-- @return: Boolean indicating if the points are within the specified range.
function inRange(x1, y1, x2, y2, range)
    return math.abs(x1 - x2) <= range and math.abs(y1 - y2) <= range
end

-- Decides the next action based on player proximity, health, and energy.
function decideNextAction()
    local player = LatestGameState.Players[ao.id]
    local potentialTargets = {}

    -- Find all players with lower health and energy than our player
    for targetId, state in pairs(LatestGameState.Players) do
        if targetId ~= ao.id and state.health < player.health and state.energy < player.energy then
            -- Calculate distance between our player and the target player
            local distance = calculateDistance(player.x, player.y, state.x, state.y)
            -- Add the target player to potentialTargets along with their distance
            table.insert(potentialTargets, { player = state, distance = distance })
        end
    end

    -- Sort potentialTargets based on distance (closest first)
    table.sort(potentialTargets, function(a, b) return a.distance < b.distance end)

    -- Attack the closest suitable target (if any)
    if #potentialTargets > 0 then
        local targetPlayer = potentialTargets[1].player -- Get the closest player
        print(colors.red .. "Attacking player with ID: " .. targetPlayer.id .. colors.reset)
        if inRange(player.x, player.y, targetPlayer.x, targetPlayer.y, 1) then
            ao.send({
                Target = Game,
                Action = "PlayerAttack",
                Player = ao.id,
                AttackEnergy = tostring(player.energy),
                TargetPlayer = targetPlayer.id
            })
        else
            -- Move towards the target player
            moveToTarget(targetPlayer)
        end
    else
        -- No suitable target found, perform default action (move randomly)
        print(colors.red .. "No suitable target found. Performing default action." .. colors.reset)
        moveRandomly()
    end

    InAction = false -- Reset InAction flag
end

-- Function to calculate distance between two points
function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

-- Move towards the target player
function moveToTarget(targetPlayer)
    local player = LatestGameState.Players[ao.id]
    local directionX = ""
    local directionY = ""

    if targetPlayer.x > player.x then
        directionX = "Right"
    elseif targetPlayer.x < player.x then
        directionX = "Left"
    end

    if targetPlayer.y > player.y then
        directionY = "Down"
    elseif targetPlayer.y < player.y then
        directionY = "Up"
    end

    if directionX ~= "" or directionY ~= "" then
        local direction = directionY .. directionX
        print(colors.red .. "Moving towards the target: " .. direction .. colors.reset)
        ao.send({
            Target = Game,
            Action = "PlayerMove",
            Player = ao.id,
            Direction = direction
        })
    else
        print(colors.red .. "Already at the target's position." .. colors.reset)
    end
end

-- Move randomly
function moveRandomly()
    local directionMap = { "Up", "Down", "Left", "Right", "UpRight", "UpLeft", "DownRight", "DownLeft" }
    local randomIndex = math.random(#directionMap)
    ao.send({ Target = Game, Action = "PlayerMove", Player = ao.id, Direction = directionMap[randomIndex] })
end

-- Function to calculate distance between two points
function calculateDistance(x1, y1, x2, y2)
    return math.sqrt((x1 - x2) ^ 2 + (y1 - y2) ^ 2)
end

-- Handler to print game announcements and trigger game state updates.
Handlers.add(
    "PrintAnnouncements",
    Handlers.utils.hasMatchingTag("Action", "Announcement"),
    function(msg)
        if msg.Event == "Started-Waiting-Period" then
            ao.send({ Target = ao.id, Action = "AutoPay" })
        elseif (msg.Event == "Tick" or msg.Event == "Started-Game") and not InAction then
            InAction = true  -- InAction logic added
            ao.send({ Target = Game, Action = "GetGameState" })
        elseif InAction then -- InAction logic added
            print("Previous action still in progress. Skipping.")
        end
        print(colors.green .. msg.Event .. ": " .. msg.Data .. colors.reset)
    end
)

-- Handler to trigger game state updates.
Handlers.add(
    "GetGameStateOnTick",
    Handlers.utils.hasMatchingTag("Action", "Tick"),
    function()
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            print(colors.gray .. "Getting game state..." .. colors.reset)
            ao.send({ Target = Game, Action = "GetGameState" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)

-- Handler to automate payment confirmation when waiting period starts.
Handlers.add(
    "AutoPay",
    Handlers.utils.hasMatchingTag("Action", "AutoPay"),
    function(msg)
        print("Auto-paying confirmation fees.")
        ao.send({ Target = Game, Action = "Transfer", Recipient = Game, Quantity = "1000" })
    end
)

-- Handler to update the game state upon receiving game state information.
Handlers.add(
    "UpdateGameState",
    Handlers.utils.hasMatchingTag("Action", "GameState"),
    function(msg)
        local json = require("json")
        LatestGameState = json.decode(msg.Data)
        ao.send({ Target = ao.id, Action = "UpdatedGameState" })
        print("Game state updated. Print \'LatestGameState\' for detailed view.")
    end
)

-- Handler to decide the next best action.
Handlers.add(
    "decideNextAction",
    Handlers.utils.hasMatchingTag("Action", "UpdatedGameState"),
    function()
        if LatestGameState.GameMode ~= "Playing" then
            InAction = false -- InAction logic added
            return
        end
        print("Deciding next action.")
        decideNextAction()
        ao.send({ Target = ao.id, Action = "Tick" })
    end
)

-- Handler to automatically attack when hit by another player.
Handlers.add(
    "ReturnAttack",
    Handlers.utils.hasMatchingTag("Action", "Hit"),
    function(msg)
        if not InAction then -- InAction logic added
            InAction = true  -- InAction logic added
            local playerEnergy = LatestGameState.Players[ao.id].energy
            if playerEnergy == undefined then
                print(colors.red .. "Unable to read energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Unable to read energy." })
            elseif playerEnergy == 0 then
                print(colors.red .. "Player has insufficient energy." .. colors.reset)
                ao.send({ Target = Game, Action = "Attack-Failed", Reason = "Player has no energy." })
            else
                print(colors.red .. "Returning attack." .. colors.reset)
                ao.send({ Target = Game, Action = "PlayerAttack", Player = ao.id, AttackEnergy = tostring(playerEnergy) })
            end
            InAction = false -- InAction logic added
            ao.send({ Target = ao.id, Action = "Tick" })
        else
            print("Previous action still in progress. Skipping.")
        end
    end
)
