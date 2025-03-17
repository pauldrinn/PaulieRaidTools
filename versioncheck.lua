-- Helper function to get WeakAura status for a player
function PRTAddon:GetPlayerWeakAuras(playerName)
    local result = {}

    local isPlayer = (playerName == UnitName("player"))

    -- If checking ourselves, use direct data
    if isPlayer then
        return self:GetOwnWeakAuras()
    end

    -- Otherwise, use data received from others
    local playerData = self.receivedWAData[playerName]
    if playerData then
        return playerData
    else
        return result
    end
end

-- Compare two revision counts or version strings
-- This handles both numeric revision counts and semantic version strings
function PRTAddon:CompareVersions(a, b)
    -- Handle nil values
    if not a then a = 0 end
    if not b then b = 0 end

    -- Convert to numbers if possible (for revision counts)
    local numA = tonumber(a)
    local numB = tonumber(b)

    -- If both are numbers, do direct comparison (for revision counts)
    if numA and numB then
        if numA > numB then
            return 1
        elseif numA < numB then
            return -1
        else
            return 0
        end
    end

    -- If they're not both numbers, convert to string and do semantic version comparison
    a = tostring(a or "0")
    b = tostring(b or "0")

    local aParts = {strsplit(".", a)}
    local bParts = {strsplit(".", b)}

    for i = 1, math.max(#aParts, #bParts) do
        local aVal = tonumber(aParts[i] or "0") or 0
        local bVal = tonumber(bParts[i] or "0") or 0

        if aVal > bVal then
            return 1
        elseif aVal < bVal then
            return -1
        end
    end

    return 0  -- Equal versions
end

-- Calculate how many versions behind (handles both revision counts and semantic versions)
function PRTAddon:VersionsBehind(current, required)
    if self:CompareVersions(current, required) >= 0 then
        return 0
    end

    -- Convert to numbers if possible (for revision counts)
    local numCurrent = tonumber(current)
    local numRequired = tonumber(required)

    -- If both are numbers, return the direct difference
    if numCurrent and numRequired then
        return numRequired - numCurrent
    end

    -- Otherwise, fall back to semantic version difference
    local currentParts = {strsplit(".", tostring(current))}
    local requiredParts = {strsplit(".", tostring(required))}

    local currentMajor = tonumber(currentParts[1]) or 0
    local currentMinor = tonumber(currentParts[2]) or 0
    local requiredMajor = tonumber(requiredParts[1]) or 0
    local requiredMinor = tonumber(requiredParts[2]) or 0

    local majorDiff = requiredMajor - currentMajor
    local minorDiff = requiredMinor - currentMinor

    if majorDiff > 0 then
        return majorDiff .. "." .. requiredMinor
    else
        return "0." .. minorDiff
    end
end