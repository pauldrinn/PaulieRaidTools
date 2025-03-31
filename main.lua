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
    self:RegisterEvent("INSPECT_READY")
end

function PRTAddon:OnDisable()
    -- Called when the addon is disabled
    self:SaveData()
end

function PRTAddon:SlashCommand(input)
    local command = self:GetArgs(input)

    if command == "pi" then
        self:CalculateAndDisplayPIGains()
    elseif command == "wa" then
        local ownAuras = self:GetOwnWeakAuras()

        self.receivedWAData = {}
        self.receivedWAData[UnitName("player")] = ownAuras
        self:BroadcastVersionCheck()

        self:Draw()
    else
        self:Print("PRT Usage:  ")
        self:Print("/prt wa - Show WA check panel")
        self:Print("/prt pi - Display optimal Power Infusion targets")
    end
end

function PRTAddon:LoadData()
    self.weakAuraStrings = self.db.profile.weakAuraStrings
    self.weakAuraConfigs = self.db.profile.weakAuraConfigs
end

function PRTAddon:SaveData()
    self.db.profile.weakAuraStrings = self.weakAuraStrings
    self.db.profile.weakAuraConfigs = self.weakAuraConfigs
end