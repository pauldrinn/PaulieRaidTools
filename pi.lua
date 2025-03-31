-- Table containing the PI gain values for different specializations
-- Format: [class-spec-talent] = {raw_gain, percentage_gain}
local PI_GAIN_TABLE = {
    ["DEATHKNIGHT-FROST"] = 4.15,
    ["DEATHKNIGHT-UNHOLY"] = 5.43,
    ["DEMONHUNTER-HAVOC"] = 2.52,
    ["DRUID-BALANCE"] = 2.42,
    ["DRUID-FERAL"] = 4.17,
    ["EVOKER-DEVASTATION"] = 5.04,
    ["HUNTER-BEASTMASTERY"] = 4.24,
    ["HUNTER-MARKSMANSHIP"] = 4.47,
    ["HUNTER-SURVIVAL"] = 5.53,
    ["MAGE-ARCANE-SUNFURY"] = 3.48,
    ["MAGE-ARCANE-SPELLSLINGER"] = 3.52,
    ["MAGE-FIRE"] = 5.08,
    ["MAGE-FROST"] = 2.02,
    ["MONK-WINDWALKER"] = 3.37,
    ["PALADIN-RETRIBUTION"] = 2.73,
    ["ROGUE-ASSASSINATION"] = 3.76,
    ["ROGUE-OUTLAW"] = 0.95,
    ["ROGUE-SUBTLETY"] = 2.00,
    ["SHAMAN-ELEMENTAL"] = 2.54,
    ["SHAMAN-ENHANCEMENT-STORMBRINGER"] = 5.53,
    ["SHAMAN-ENHANCEMENT-TOTEMIC"] = 3.24,
    ["WARLOCK-AFFLICTION"] = 5.23,
    ["WARLOCK-DEMONOLOGY"] = 4.98,
    ["WARLOCK-DESTRUCTION"] = 3.49,
    ["WARRIOR-ARMS"] = 3.32,
    ["WARRIOR-FURY"] = 2.05,
}

local PI_GAIN_TABLE_SPRIEST = {
    ["DEATHKNIGHT-FROST"] = 2.65,
    ["DEATHKNIGHT-UNHOLY"] = 3.77,
    ["DEMONHUNTER-HAVOC"] = 2.27,
    ["DRUID-BALANCE"] = 2.29,
    ["DRUID-FERAL"] = 3.88,
    ["EVOKER-DEVASTATION"] = 4.21,
    ["HUNTER-BEASTMASTERY"] = 3.95,
    ["HUNTER-MARKSMANSHIP"] = 3.82,
    ["HUNTER-SURVIVAL"] = 5.19,
    ["MAGE-ARCANE-SUNFURY"] = 3.47,
    ["MAGE-ARCANE-SPELLSLINGER"] = 3.34,
    ["MAGE-FIRE"] = 3.95,
    ["MAGE-FROST"] = 1.95,
    ["MONK-WINDWALKER"] = 2.48,
    ["PALADIN-RETRIBUTION"] = 2.55,
    ["ROGUE-ASSASSINATION"] = 3.40,
    ["ROGUE-OUTLAW"] = 1.04,
    ["ROGUE-SUBTLETY"] = 1.45,
    ["SHAMAN-ELEMENTAL"] = 2.60,
    ["SHAMAN-ENHANCEMENT-STORMBRINGER"] = 5.36,
    ["SHAMAN-ENHANCEMENT-TOTEMIC"] = 3.17,
    ["WARLOCK-AFFLICTION"] = 4.86,
    ["WARLOCK-DEMONOLOGY"] = 2.98,
    ["WARLOCK-DESTRUCTION"] = 3.37,
    ["WARRIOR-ARMS"] = 2.88,
    ["WARRIOR-FURY"] = 2.52,
}

-- Variables for the inspection queue
local inspectQueue = {}
local currentlyInspecting = nil
local inspectionTimer = nil
local INSPECTION_TIMEOUT = 3 -- seconds before timeout
local inspectionResults = {}

-- Get the player's class, spec, and hero talent
function PRTAddon:GetPlayerSpecInfo(unit)
    if not UnitExists(unit) then return nil end

    local name = UnitName(unit)
    local _, class = UnitClass(unit)
    if not class then
        -- Return basic info if we can't get class
        return {
            name = name,
            class = "UNKNOWN",
            spec = "UNKNOWN"
        }
    end

    -- For the player character, we can get information directly
    if UnitIsUnit(unit, "player") then
        -- Get player's active specialization
        local specIndex = GetSpecialization()
        if not specIndex then
            return {
                name = name,
                class = class,
                spec = "UNKNOWN"
            }
        end

        local _, specName = GetSpecializationInfo(specIndex)
        if not specName then
            return {
                name = name,
                class = class,
                spec = "UNKNOWN"
            }
        end

        -- Remove spaces for consistent naming
        specName = specName:upper():gsub(" ", "")

        -- Try to get hero talent info for specific specs (Arcane Mage and Enhancement Shaman)
        local heroTalent = nil
        if (class == "MAGE" and specName == "ARCANE") or (class == "SHAMAN" and specName == "ENHANCEMENT") then
            -- This would need expansion based on actual talent API
            for i = 1, 3 do  -- Assuming hero talents are in the first 3 positions
                local talentID, name, _, selected = GetTalentInfo(1, i, 1)
                if selected then
                    if name == "Sunfury" or name == "Spellslinger" or 
                       name == "Stormbringer" or name == "Totemic" then
                        heroTalent = name:upper()
                        break
                    end
                end
            end
        end

        local specKey = class .. "-" .. specName
        if heroTalent then
            specKey = specKey .. "-" .. heroTalent
        end

        return {
            name = name,
            class = class,
            spec = specName,
            heroTalent = heroTalent,
            specKey = specKey
        }
    else
        -- For other players, use cached inspection results if available
        if inspectionResults[name] then
            return inspectionResults[name]
        end

        -- Otherwise, return basic info for now and queue for inspection
        return {
            name = name,
            class = class,
            spec = "UNKNOWN"
        }
    end
end

-- Queue a player for inspection
function PRTAddon:QueueForInspection(unit)
    if UnitIsUnit(unit, "player") then return end -- No need to inspect ourselves

    local name = UnitName(unit)
    if not name then return end

    -- Add to queue if not already queued or inspected
    if not inspectionResults[name] and not tContains(inspectQueue, unit) then
        table.insert(inspectQueue, unit)
    end

    -- Start processing the queue if not already doing so
    self:ProcessInspectQueue()
end

-- Process the inspection queue
function PRTAddon:ProcessInspectQueue()
    -- If already inspecting someone, don't start another inspection
    if currentlyInspecting then return end

    -- If the queue is empty, we're done
    if #inspectQueue == 0 then
        -- No debug message to keep chat clean
        return
    end

    -- Get the next unit to inspect
    currentlyInspecting = table.remove(inspectQueue, 1)

    -- Request inspection
    if UnitExists(currentlyInspecting) and CanInspect(currentlyInspecting) then
        -- No debug message to keep chat clean
        NotifyInspect(currentlyInspecting)

        -- Set a timeout in case the inspection never completes
        inspectionTimer = C_Timer.NewTimer(INSPECTION_TIMEOUT, function()
            -- No debug message to keep chat clean
            currentlyInspecting = nil
            self:ProcessInspectQueue()
        end)
    else
        -- Skip this unit if it can't be inspected
        currentlyInspecting = nil
        self:ProcessInspectQueue()
    end
end

-- Handle the INSPECT_READY event
function PRTAddon:INSPECT_READY(event, guid)
    -- Cancel the timeout timer
    if inspectionTimer then
        inspectionTimer:Cancel()
        inspectionTimer = nil
    end

    -- Check if this is the unit we're currently inspecting
    if not currentlyInspecting or UnitGUID(currentlyInspecting) ~= guid then
        currentlyInspecting = nil
        self:ProcessInspectQueue()
        return
    end

    local unit = currentlyInspecting
    local name = UnitName(unit)
    local _, class = UnitClass(unit)

    -- Get specialization from inspection
    local specID = GetInspectSpecialization(unit)
    local specName = "UNKNOWN"
    if specID and specID > 0 then
        local _, specNameRaw = GetSpecializationInfoByID(specID)
        if specNameRaw then
            specName = specNameRaw:upper():gsub(" ", "")
        end
    end

    -- Try to get hero talent info for specific specs (limited functionality)
    local heroTalent = nil
    -- In a real implementation, you would need to use GetInspectTalent APIs here

    local specKey = class .. "-" .. specName
    if heroTalent then
        specKey = specKey .. "-" .. heroTalent
    end

    -- Save the inspection results
    inspectionResults[name] = {
        name = name,
        class = class,
        spec = specName,
        heroTalent = heroTalent,
        specKey = specKey
    }

    -- Clear the currently inspecting unit
    currentlyInspecting = nil

    -- Process the next unit in the queue
    self:ProcessInspectQueue()
end

-- Calculate and display the PI gains for the current group
function PRTAddon:CalculateAndDisplayPIGains()
    local groupMembers = {}
    local groupSize = 0
    local isInRaid = IsInRaid()

    -- Determine the group type and size
    if isInRaid then
        groupSize = GetNumGroupMembers()
        for i = 1, groupSize do
            table.insert(groupMembers, "raid" .. i)
        end
    elseif IsInGroup() then
        groupSize = GetNumGroupMembers()
        table.insert(groupMembers, "player")
        for i = 1, groupSize - 1 do
            table.insert(groupMembers, "party" .. i)
        end
    else
        -- Solo player
        groupSize = 1
        table.insert(groupMembers, "player")
    end

    -- Clear previous inspection results
    inspectionResults = {}

    -- Queue all group members for inspection
    for _, unitID in ipairs(groupMembers) do
        if not UnitIsUnit(unitID, "player") then -- Skip player, they don't need inspection
            self:QueueForInspection(unitID)
        end
    end

    -- Give some time for inspections to complete
    C_Timer.After(1, function()
        self:DisplayPIResults(groupMembers)
    end)
    
    self:Print("Collecting data for PI")
end

-- Display the results after inspection
function PRTAddon:DisplayPIResults(groupMembers)
    local playerGains = {}

    -- Collect data for each group member
    for _, unitID in ipairs(groupMembers) do
        local playerInfo = self:GetPlayerSpecInfo(unitID)

        if playerInfo then
            -- Default values for players without matching spec data
            local percentGain = 0.0
            local percentGainSPriest = 0.0
            local specKey = playerInfo.specKey or "UNKNOWN"

            -- If we have spec data, get the gain values
            if playerInfo.specKey then
                local gainInfo = PI_GAIN_TABLE[playerInfo.specKey]
                local gainInfoSPriest = PI_GAIN_TABLE_SPRIEST[playerInfo.specKey]

                -- If no specific entry for this spec+talent, try just the spec
                if not gainInfo and playerInfo.heroTalent then
                    local baseSpecKey = playerInfo.class .. "-" .. playerInfo.spec
                    gainInfo = PI_GAIN_TABLE[baseSpecKey]
                    gainInfoSPriest = PI_GAIN_TABLE_SPRIEST[baseSpecKey]
                end

                if gainInfo then
                    percentGain = gainInfo
                    percentGainSPriest = gainInfoSPriest
                end
            end

            if percentGain > 0.0 then
                table.insert(playerGains, {
                    name = playerInfo.name,
                    percentGain = percentGain,
                    percentGainSPriest = percentGainSPriest,
                    specKey = specKey,
                    class = playerInfo.class or "UNKNOWN",
                    spec = playerInfo.spec or "UNKNOWN"
                })
            end
        end
    end

    -- Sort by percentage gain (highest first)
    table.sort(playerGains, function(a, b) return a.percentGain > b.percentGain end)

    -- Determine which chat to use
    local chatType = "PARTY"
    if IsInRaid() then
        chatType = "RAID"
    end

    -- Display the results
    SendChatMessage("PI Priority List: ", chatType)

    for i, playerData in ipairs(playerGains) do
        -- Format the class and spec strings for display
        local className = "Unknown"
        if playerData.class and playerData.class ~= "UNKNOWN" then
            className = LOCALIZED_CLASS_NAMES_MALE[playerData.class] or playerData.class
        end

        local specName = playerData.spec or "Unknown"
        if specName == "UNKNOWN" then
            specName = "Unknown"
        end

        -- Format the message with class and spec at the end
        local message = string.format("%d. %s - %s %s - %.2f%% (CD) - %.2f%% (SP CDs)", 
            i, playerData.name, className, specName, playerData.percentGain, playerData.percentGainSPriest)
        SendChatMessage(message, chatType)
    end

    -- Also print to the chat frame for the player
    self:Print("PI Priority List has been sent to " .. string.lower(chatType) .. " chat.")
end