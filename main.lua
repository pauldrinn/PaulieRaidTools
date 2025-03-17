PRTAddon = LibStub("AceAddon-3.0"):NewAddon("PaulieRaidTools", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0")

function PRTAddon:OnInitialize()
    -- Initialize saved variables
    self.db = LibStub("AceDB-3.0"):New("PRTAddonDB", {
        profile = {
            weakAuraStrings = {},
            weakAuraConfigs = {}
        }
    })

    -- Load saved WeakAura strings
    self:LoadData()
    -- Code that you want to run when the addon is first loaded goes here.
    self:RegisterChatCommand("prt", "SlashCommand")
    self:InitCommunication()
end

function PRTAddon:OnEnable()
    ---
end

function PRTAddon:OnDisable()
    -- Called when the addon is disabled
    self:SaveData()
end

function PRTAddon:SlashCommand(input)
    local ownAuras = self:GetOwnWeakAuras()

    self.receivedWAData = {}
    self.receivedWAData[UnitName("player")] = ownAuras
    self:BroadcastVersionCheck()

    self:Draw()
    -- self:Draw()
end

function PRTAddon:LoadData()
    self.weakAuraStrings = self.db.profile.weakAuraStrings
    self.weakAuraConfigs = self.db.profile.weakAuraConfigs
end

function PRTAddon:SaveData()
    self.db.profile.weakAuraStrings = self.weakAuraStrings
    self.db.profile.weakAuraConfigs = self.weakAuraConfigs
end