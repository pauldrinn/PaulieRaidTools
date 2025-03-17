local LibSerialize = LibStub("LibSerialize")
local LibDeflate = LibStub("LibDeflate")

-- Initialize communication
function PRTAddon:InitCommunication()
    self:RegisterComm("PRTWACheck")
    self.receivedWAData = {}
end

function PRTAddon:Pack(data)
    local serialized = LibSerialize:Serialize(data)
    local compressed = LibDeflate:CompressDeflate(serialized)
    local encoded = LibDeflate:EncodeForWoWAddonChannel(compressed)
    return encoded
end

function PRTAddon:Unpack(encoded)
    local decoded = LibDeflate:DecodeForWoWAddonChannel(encoded)
    if not decoded then return end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end
    local success, data = LibSerialize:Deserialize(decompressed)
    if not success then return end
    return data
end

-- Handle incoming messages
function PRTAddon:OnCommReceived(prefix, message, distribution, sender)
    if prefix ~= "PRTWACheck" then return end

    -- Don't process our own messages
    if sender == UnitName("player") then return end

    local data = self:Unpack(message)
    if not data then return end

    if data.type == "REQUEST" then
        -- Someone is requesting our WeakAura versions
        self:SendWeakAuraData(sender)
    elseif data.type == "DATA" then
        -- We received WeakAura data from someone
        self.receivedWAData[sender] = data.auras
        self:RefreshUI()
    elseif data.type == "AURAS" then
        -- We received WeakAura strings from someone
        self.weakAuraConfigs = data.configs
    end
end

-- Send our WeakAura versions to someone
function PRTAddon:SendWeakAuraData(target)
    local auras = self:GetOwnWeakAuras()
    local data = {
        type = "DATA",
        auras = auras
    }

    local distribution = "RAID" -- target and "WHISPER" or "RAID"
    self:SendCommMessage("PRTWACheck", self:Pack(data), distribution) --, target)
end

-- Request WeakAura versions from others
function PRTAddon:BroadcastVersionCheck()
    if not IsInGroup() then return end

    local auras = {
        type = "AURAS",
        configs = self.weakAuraConfigs
    }

    local data = {
        type = "REQUEST"
    }

    self:SendCommMessage("PRTWACheck", self:Pack(auras), "RAID")
    self:SendCommMessage("PRTWACheck", self:Pack(data), "RAID")
end

-- Get our own WeakAuras data
function PRTAddon:GetOwnWeakAuras()
    local result = {}
    -- Get the stored WeakAura configs we want to check
    for i, waConfig in pairs(self.weakAuraConfigs) do
        if waConfig.name then
            -- Check if this WeakAura is installed in our WeakAuras
            local installed = false
            local installedVersion = nil
            -- Use WeakAuras API to check if installed
            if WeakAuras and WeakAuras.GetData then
                local auraData = WeakAuras.GetData(waConfig.name)
                if auraData then
                    installed = true
                    installedVersion = auraData.version
                end
            end

            result[waConfig.name] = {
                installed = installed,
                version = tostring(installedVersion or 0),
                requiredVersion = tostring(waConfig.version or 0),
                upToDate = self:CompareVersions(installedVersion, waConfig.version) >= 0,
                versionsBack = self:VersionsBehind(installedVersion, waConfig.version)
            }
        end
    end
    return result
end

-- Parse WeakAura string to extract name and revision/version
function PRTAddon:ParseWeakAuraString(waString)
    if not waString or waString == "" then
        return nil, nil
    end

    -- Check stored configs first (for previously saved data)
    for i, config in ipairs(self.weakAuraConfigs or {}) do
        if self.weakAuraStrings[i] == waString and config.name and config.version then
            return config.name, config.version
        end
    end

    -- Check for raw string format (Name:Version)
    local rawName, rawVersion = waString:match("^([^:]+):([%d%.]+)$")
    if rawName and rawVersion then
        return rawName, rawVersion
    end

    -- WeakAura strings often start with "!WA:"
    local dataString = waString
    if dataString:sub(1, 6) == "!WA:2!" then
        dataString = dataString:sub(7)
    else
        return nil, nil
    end

    local decoded = LibDeflate:DecodeForPrint(dataString)
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    local success, data = LibSerialize:Deserialize(decompressed)

    -- Try to get name and revision
    local name = data.d.id
    -- Prefer revision over version if available
    local version = data.d.version or data.d.semver

    return name, tostring(version or "1")
end