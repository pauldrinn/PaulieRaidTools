AceGUI = LibStub("AceGUI-3.0")

function PRTAddon:Draw()
    local frame = AceGUI:Create("Frame")
    frame:SetTitle("Paulie Raid Tools")
    frame:SetStatusText("v0.2b")
    frame:SetCallback("OnClose", function(widget)
        self:SaveData()
        AceGUI:Release(widget)
    end)
    frame:SetLayout("Fill")

    -- Create a main container for all content
    local mainContainer = AceGUI:Create("SimpleGroup")
    mainContainer:SetLayout("None") -- Using None layout for absolute positioning
    mainContainer:SetFullWidth(true)
    mainContainer:SetFullHeight(true)

    -- Check if player is group leader
    local isGroupLeader = UnitIsGroupLeader("player") or not IsInGroup()

    -- Create tab group
    local tabGroup = AceGUI:Create("TabGroup")
    tabGroup:SetLayout("Flow")
    tabGroup:SetFullWidth(true)
    tabGroup:SetFullHeight(true)

    local tabs = {
        {text = "WeakAura Check", value = "check"},
        {text = "Manage Auras", value = "manage", disabled = not isGroupLeader}
    }

    tabGroup:SetTabs(tabs)

    -- Store the selected tab for refreshing the UI and save reference to the tab group
    tabGroup:SetUserData("selectedTab", "check")
    self.mainTabGroup = tabGroup
    
    tabGroup:SetCallback("OnGroupSelected", function(container, event, group)
        container:ReleaseChildren()
        tabGroup:SetUserData("selectedTab", group)
        if group == "check" then
            PRTAddon:DrawCheckTab(container)
        elseif group == "manage" then
            PRTAddon:DrawManageTab(container)
        end
    end)

    -- Now create the check button after tabGroup is defined
    local checkButton = AceGUI:Create("Button")
    checkButton:SetText("Check WeakAuras")
    checkButton:SetWidth(140)
    -- Disable the button if not group leader
    checkButton:SetDisabled(not isGroupLeader)
    checkButton:SetCallback("OnClick", function()
        -- Display a status message
        self:Print("Checking WeakAura versions...")

        -- Clear existing data
        self.receivedWAData = {}

        -- Broadcast version check request
        self:BroadcastVersionCheck()
    end)

    -- Manually position the button in the top right
    mainContainer:AddChild(checkButton)
    checkButton.frame:ClearAllPoints()
    checkButton.frame:SetPoint("TOPRIGHT", mainContainer.frame, "TOPRIGHT", -10, -10)

    -- Add the tab group to main container and position it to fill most of the space
    mainContainer:AddChild(tabGroup)
    tabGroup.frame:ClearAllPoints()
    tabGroup.frame:SetPoint("TOPLEFT", mainContainer.frame, "TOPLEFT", 0, -30)
    tabGroup.frame:SetPoint("BOTTOMRIGHT", mainContainer.frame, "BOTTOMRIGHT", 0, 0)

    -- Select first tab by default
    tabGroup:SelectTab("check")

    -- Add the main container to the frame (this is the only direct child of the frame)
    frame:AddChild(mainContainer)
end

function PRTAddon:DrawCheckTab(container)
    -- Create a scroll frame for the group members
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("List")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)

    -- Header with action buttons
    local headerGroup = AceGUI:Create("SimpleGroup")
    headerGroup:SetLayout("Flow")
    headerGroup:SetFullWidth(true)

    local header = AceGUI:Create("Heading")
    header:SetText("WeakAura Checks")
    header:SetFullWidth(true)
    headerGroup:AddChild(header)

    -- We're removing the check button from here as it's now in the main frame
    scroll:AddChild(headerGroup)

    -- Create a sorted list of weakaura indices and names
    local allAuraIndices = {}
    local allAuraNames = {}
    
    if self.weakAuraConfigs then
        for i, config in ipairs(self.weakAuraConfigs) do
            table.insert(allAuraIndices, i)
            allAuraNames[i] = config.name
        end
        table.sort(allAuraIndices)
    end
    
    -- Create the header with indices
    if #allAuraIndices > 0 then
        local indexHeaderGroup = AceGUI:Create("SimpleGroup")
        indexHeaderGroup:SetLayout("Flow")
        indexHeaderGroup:SetFullWidth(true)
        
        -- Add a spacer for player name column
        local spacer = AceGUI:Create("Label")
        spacer:SetWidth(150)
        spacer:SetText("")
        indexHeaderGroup:AddChild(spacer)
        
        -- Add index numbers as column headers
        for _, index in ipairs(allAuraIndices) do
            local indexHeader = AceGUI:Create("Label")
            indexHeader:SetText("[" .. index .. "]")
            indexHeader:SetWidth(30)
            
            -- Custom handler for tooltip
            indexHeader.frame:SetScript("OnEnter", function()
                GameTooltip:SetOwner(indexHeader.frame, "ANCHOR_TOP")
                GameTooltip:AddLine(allAuraNames[index] or "Unknown")
                GameTooltip:Show()
            end)
            
            indexHeader.frame:SetScript("OnLeave", function()
                GameTooltip:Hide()
            end)
            
            -- Make clickable
            indexHeader.frame:EnableMouse(true)
            
            -- Center text in label
            indexHeader.label:SetJustifyH("CENTER")
            
            indexHeaderGroup:AddChild(indexHeader)
        end
        
        scroll:AddChild(indexHeaderGroup)
        
        -- Add a separator
        local separator = AceGUI:Create("Heading")
        separator:SetFullWidth(true)
        scroll:AddChild(separator)
    end

    -- Group members and WeakAura status
    local players = {}
    
    -- Collect player names
    if IsInGroup() then
        local groupSize = IsInRaid() and GetNumGroupMembers() or GetNumGroupMembers()
        for i = 1, groupSize do
            local name, _, _, _, _, class = GetRaidRosterInfo(i)
            if name then
                table.insert(players, {name = name, class = class})
            end
        end
    else
        local playerName = UnitName("player")
        local _, class = UnitClass("player")
        table.insert(players, {name = playerName, class = class})
    end
    
    -- Display player rows
    for _, player in ipairs(players) do
        local playerRow = AceGUI:Create("SimpleGroup")
        playerRow:SetLayout("Flow")
        playerRow:SetFullWidth(true)
        
        local nameLabel = AceGUI:Create("Label")
        nameLabel:SetText(player.name)
        nameLabel:SetWidth(150)
        
        -- Color by class if available
        if player.class then
            local classColor = RAID_CLASS_COLORS[player.class]
            nameLabel:SetColor(classColor.r, classColor.g, classColor.b)
        end
        
        -- Ensure no tooltips appear on player names by explicitly setting empty handlers
        nameLabel.frame:SetScript("OnEnter", nil)
        nameLabel.frame:SetScript("OnLeave", nil)
        
        playerRow:AddChild(nameLabel)
        
        -- Check each WeakAura for this player
        local auraStatus = self:GetPlayerWeakAuras(player.name)
        local hasData = next(auraStatus) ~= nil
        
        if hasData and #allAuraIndices > 0 then
            -- For each index in our sorted list
            for _, index in ipairs(allAuraIndices) do
                local auraName = allAuraNames[index]
                local status = auraStatus[auraName]
                
                local statusIcon = AceGUI:Create("Icon")
                if not status then
                    -- WeakAura not found for this player
                    statusIcon:SetImage("Interface\\RaidFrame\\ReadyCheck-NotReady")
                    statusIcon:SetImageSize(16, 16)
                elseif status.installed and status.upToDate then
                    statusIcon:SetImage("Interface\\RaidFrame\\ReadyCheck-Ready")
                    statusIcon:SetImageSize(16, 16)
                else
                    statusIcon:SetImage("Interface\\RaidFrame\\ReadyCheck-NotReady")
                    statusIcon:SetImageSize(16, 16)
                end
                statusIcon:SetWidth(30) -- Match the exact width of the header
                
                -- Center the icon within its container
                -- Access the Icon's widget and set it to center
                if statusIcon.image then
                    statusIcon.image:SetPoint("CENTER", statusIcon.frame, "CENTER")
                end
                
                -- Add tooltip with detailed information
                statusIcon:SetCallback("OnEnter", function(widget)
                    GameTooltip:SetOwner(widget.frame, "ANCHOR_TOP")
                    GameTooltip:AddLine(auraName)
                    
                    if not status then
                        GameTooltip:AddLine("Status: No data", 0.8, 0.8, 0.8)
                    elseif not status.installed then
                        GameTooltip:AddLine("Status: Not installed", 1, 0, 0)
                    elseif not status.upToDate then
                        GameTooltip:AddLine("Status: Outdated", 1, 0.5, 0)
                        GameTooltip:AddLine("Current version: " .. status.version, 0.8, 0.8, 0.8)
                        GameTooltip:AddLine("Versions behind: " .. status.versionsBack, 0.8, 0.8, 0.8)
                    else
                        GameTooltip:AddLine("Status: Up to date", 0, 1, 0)
                        GameTooltip:AddLine("Version: " .. status.version, 0.8, 0.8, 0.8)
                    end
                    
                    GameTooltip:Show()
                end)
                
                statusIcon:SetCallback("OnLeave", function()
                    GameTooltip:Hide()
                end)
                
                playerRow:AddChild(statusIcon)
            end
        else
            local noDataLabel = AceGUI:Create("Label")
            
            if player.name ~= UnitName("player") then
                noDataLabel:SetText("No data received yet. Click 'Check WeakAuras'")
            else
                noDataLabel:SetText("You have no WeakAuras configured for checking")
            end
            
            playerRow:AddChild(noDataLabel)
        end
        
        scroll:AddChild(playerRow)
    end

    container:AddChild(scroll)
end

function PRTAddon:DrawManageTab(container)
    local scroll = AceGUI:Create("ScrollFrame")
    scroll:SetLayout("Flow")
    scroll:SetFullWidth(true)
    scroll:SetFullHeight(true)
    
    -- Header
    local header = AceGUI:Create("Heading")
    header:SetText("Manage WeakAura Strings")
    header:SetFullWidth(true)
    scroll:AddChild(header)
    
    -- Add button to add new WeakAura field - moved to top below header
    local addButton = AceGUI:Create("Button")
    addButton:SetText("Add New WeakAura")
    addButton:SetFullWidth(true)
    addButton:SetCallback("OnClick", function()
        self:AddWeakAuraField(scroll, #self.weakAuraStrings + 1, "")
        container:DoLayout()
    end)
    scroll:AddChild(addButton)
    
    -- Get stored WeakAura strings
    self.weakAuraStrings = self.weakAuraStrings or {}
    
    -- Add WeakAura input fields
    for i, waString in ipairs(self.weakAuraStrings) do
        self:AddWeakAuraField(scroll, i, waString)
    end
    
    container:AddChild(scroll)
end

function PRTAddon:AddWeakAuraField(container, index, waString)
    local group = AceGUI:Create("InlineGroup")
    group:SetLayout("Flow")
    group:SetFullWidth(true)

    local auraName, auraVersion = self:ParseWeakAuraString(waString)
    local nameText = auraName and auraName or "Unknown WeakAura"
    group:SetTitle(nameText .. " (Index " .. index .. ")")
    
    -- Declare infoLabel at function scope so all callbacks can access it
    local infoLabel

    local editbox = AceGUI:Create("MultiLineEditBox")
    editbox:SetLabel("WeakAura String:")
    editbox:SetFullWidth(true)
    editbox:SetNumLines(3)
    editbox:SetText(waString)
    editbox:SetCallback("OnEnterPressed", function(widget)
        local newString = widget:GetText()
        self.weakAuraStrings[index] = newString

        -- Update the stored configuration
        local name, version = self:ParseWeakAuraString(newString)
        if name then
            self.weakAuraConfigs[index] = {
                name = name,
                version = version
            }

            -- Update the title with the new name
            group:SetTitle(name .. " (Index " .. index .. ")")
        end

        -- Save to database
        self:SaveData()

        -- Create a new info label with updated information
        if name and not infoLabel then
            infoLabel = AceGUI:Create("Label")
            
            -- Check if this WeakAura is installed
            local statusText = "Not installed"
            if WeakAuras and WeakAuras.GetData then
                local auraData = WeakAuras.GetData(name)
                if auraData then
                    -- Use revision count if available, otherwise fall back to version
                    local installedVersion = auraData.revision or auraData.version or "Unknown"
                    statusText = "Installed (rev " .. installedVersion .. ")"
                    if version then
                        if self:CompareVersions(installedVersion, version) >= 0 then
                            statusText = statusText .. " Up to date"
                            infoLabel:SetColor(0, 1, 0) -- Green
                        else
                            statusText = statusText .. " Outdated (required: rev " .. version .. ")"
                            infoLabel:SetColor(1, 0.5, 0) -- Orange
                        end
                    end
                else
                    infoLabel:SetColor(1, 0, 0) -- Red
                end
            end
            
            infoLabel:SetText("Status: " .. statusText)
            infoLabel:SetFullWidth(true)
            -- Clear any tooltip handlers that might be present on the label
            infoLabel.frame:SetScript("OnEnter", nil)
            infoLabel.frame:SetScript("OnLeave", nil)
            group:AddChild(infoLabel)
            
            -- Provide user feedback
            self:Print("WeakAura added: " .. name .. " (v" .. (version or "Unknown") .. ")")
        elseif name and infoLabel then
            self:RefreshUI()
        else
            -- Let the user know if parsing failed
            self:Print("Could not parse WeakAura string. Make sure it's valid.")
        end

        self.receivedWAData = {}
        self:BroadcastVersionCheck()

        -- Re-layout the group to accommodate changes
        group:DoLayout()
    end)
    group:AddChild(editbox)

    local buttonGroup = AceGUI:Create("SimpleGroup")
    buttonGroup:SetLayout("Flow")
    buttonGroup:SetFullWidth(true)

    local removeButton = AceGUI:Create("Button")
    removeButton:SetText("Remove")
    removeButton:SetWidth(120)
    removeButton:SetCallback("OnClick", function()
        table.remove(self.weakAuraStrings, index)
        table.remove(self.weakAuraConfigs, index)

        self:SaveData()
        self:RefreshUI()
    end)
    buttonGroup:AddChild(removeButton)

    -- Display current status information if we have a name
    if auraName then
        infoLabel = AceGUI:Create("Label")
        
        -- Clear any tooltip handlers that might be present on the label
        infoLabel.frame:SetScript("OnEnter", nil)
        infoLabel.frame:SetScript("OnLeave", nil)

        -- Check if this WeakAura is installed
        local statusText = "Not installed"
        if WeakAuras and WeakAuras.GetData then
            local auraData = WeakAuras.GetData(auraName)
            if auraData then
                statusText = "Installed (v" .. (auraData.version or "Unknown") .. ")"
                if auraVersion then
                    if self:CompareVersions(auraData.version, auraVersion) >= 0 then
                        statusText = statusText .. " Up to date"
                        infoLabel:SetColor(0, 1, 0) -- Green
                    else
                        statusText = statusText .. " Outdated (required: v" .. auraVersion .. ")"
                        infoLabel:SetColor(1, 0.5, 0) -- Orange
                    end
                end
            else
                infoLabel:SetColor(1, 0, 0) -- Red
            end
        end
        
        infoLabel:SetText("Status: " .. statusText)
        infoLabel:SetFullWidth(true)
        group:AddChild(infoLabel)
    end

    group:AddChild(buttonGroup)
    container:AddChild(group)
end

-- Add this new function to refresh the UI when data is updated
function PRTAddon:RefreshUI()
    if not self.mainTabGroup then return end

    local selectedTab = self.mainTabGroup:GetUserData("selectedTab")
    if not selectedTab then return end

    -- Only refresh the check tab since that's where WeakAura data is displayed
    if selectedTab == "check" then
        self.mainTabGroup:ReleaseChildren()
        self:DrawCheckTab(self.mainTabGroup)
        self.mainTabGroup:DoLayout()
    elseif selectedTab == "manage" then
        self.mainTabGroup:ReleaseChildren()
        self:DrawManageTab(self.mainTabGroup)
        self.mainTabGroup:DoLayout()
    end
end

