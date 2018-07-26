SimpleMB = LibStub("AceAddon-3.0"):NewAddon("SimpleMB", "AceConsole-3.0", "AceEvent-3.0")
local L = LibStub("AceLocale-3.0"):GetLocale("SimpleMB", true)

local options = {
    name = "SimpleMacroBindings",
    handler = SimpleMB,
    type = 'group',
    args = {
        main = {
            name = L['Edit Macros'],
            type = 'group',
            args = {
                newMacro = {
                    name = L['New Macro'],
                    type = 'input',
                    desc = L['Create a new empty macro'],
                    set = 'SetNewMacro',
                    get = 'GetNewMacro',
                    order = 10,
                },

                macroSelectBox = {
                    name = L['Existing Macros'],
                    type = 'select',
                    desc = L['Select a macro to edit'],
                    set = 'SetSelectMacro',
                    get = 'GetSelectMacro',
                    style = 'dropdown',
                    values = {},
                    order = 20,
                },

                macroName = {
                    name = L['Macro Name'],
                    type = 'input',
                    desc = L['Macro being edited'],
                    set = 'SetMacroName',
                    get = 'GetMacroName',
                    order = 30,
                },

                macroBinding = {
                    name = L['Macro Binding'],
                    type = 'keybinding',
                    set = 'SetMacroBinding',
                    get = 'GetMacroBinding',
                    order = 31,
                },

                macroKeyDown = {
                    name = L['Key Down'],
                    type = 'toggle',
                    desc = L['Execute macro when key is pressed down. Default behavior is to execute on key release.'],
                    tristate = true,
                    set = 'SetMacroKeyDown',
                    get = 'GetMacroKeyDown',
                    order = 32,
                },

                macroEditBox = {
                    name = L['Macro Text'],
                    type = 'input',
                    desc = "",
                    set = 'SetMacroBody',
                    get = 'GetMacroBody',
                    multiline = true,
                    width = 'full',
                    order = 35
                },

                macroDeleteBox = {
                    name = L['Delete macro'],
                    type = 'select',
                    desc = L['Select a macro to be deleted'],
                    set = 'SetMacroDelete',
                    get = 'GetMacroDelete',
                    style = 'dropdown',
                    values = {},
                    confirm = true,
                    confirmText = L['Are you sure you wish to delete the selected macro?'],
                    order = 40,
                },
            },
        },

        templates = {
            name = L['Edit Templates'],
            type = 'group',
            args = {
                newMacro = {
                    name = L['New Template'],
                    type = 'input',
                    desc = L['Create a new empty template'],
                    set = nil,
                    get = nil,
                    order = 10,
                },
            },
        },
    },
}

local defaults = {
    profile = {
        macroTable = {},
    },
}

local macroList = {}

local function getButton(index)
    local button

    if (_G["SimpleMB_Button" .. index]) then
        button = _G["SimpleMB_Button" .. index]
    else
        button = CreateFrame("CheckButton", "SimpleMB_Button" .. index, UIParent, "SecureActionButtonTemplate")
    end

    return button
end

local function deleteButton(index)
    local button = getButton(index)

    if button then
        button:SetAttribute("type", nil)
        button:SetAttribute("macrotext", nil)
        ClearOverrideBindings(button)
        return true
    end

    return false
end

function SimpleMB:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SimpleMB_DB", defaults)
    options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("SimpleMB", options, nil)

    local LibDualSpec = LibStub('LibDualSpec-1.0')
    LibDualSpec:EnhanceDatabase(self.db, "SimpleMB_DB")
    LibDualSpec:EnhanceOptions(options.args.profile, self.db)

    self.inCombat = nil
    self.selectedMacro = nil
    self.selectedMacroName = nil
    self.selectedMacroBody = nil
    self.delayedMacroUpdate = false

    self:RegisterEvent("PLAYER_LOGIN", "OnPlayerLogin")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerLeaveCombat")

    self.db.RegisterCallback(self, "OnNewProfile", "InitializePresets")
    self.db.RegisterCallback(self, "OnProfileReset", "InitializePresets")
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")

    local ACD = LibStub("AceConfigDialog-3.0")
    ACD:AddToBlizOptions("SimpleMB", "SimpleMacroBindings", nil, "main")
    ACD:AddToBlizOptions("SimpleMB", L["Templates"], "SimpleMacroBindings", "templates")
    ACD:AddToBlizOptions("SimpleMB", L["Profile"], "SimpleMacroBindings", "profile")

    self:RegisterChatCommand("simplemb", "ChatCommand")
    self:RegisterChatCommand("simplemacrobindings", "ChatCommand")

    self:UpdateDisplayedMacro()
    self:UpdateMacroList()
end

function SimpleMB:OnEnable()
    -- Called when the addon is enabled
    self:RefreshBindings()
end

function SimpleMB:OnDisable()
    -- Called when the addon is disabled
    self:ClearMacros()
end

function SimpleMB:OnPlayerLogin()
    -- this space for rent
    self:RefreshBindings()
end

function SimpleMB:OnPlayerEnterCombat()
    self.inCombat = true
end

function SimpleMB:OnPlayerLeaveCombat()
    self.inCombat = false
    if self.delayedMacroUpdate == true then
        -- self:UpdateAll()
        self.delayedMacroUpdate = false
    end
end

function SimpleMB:UpdateAll()
    self:UpdateDisplayedMacro()
end



-- Config dialog UI getters and setters
function SimpleMB:GetNewMacro(info)
    return ""
end

function SimpleMB:SetNewMacro(info, name)
    name = self:CleanMacroName(name)

    if strtrim(name) == "" then
        return
    end

    if not(self.db.profile.macroTable[name]) then
        self.db.profile.macroTable[name] = {
            body = "",
            bindings = {},
            keyDown = true,
        }
        self:UpdateMacroList()
    end

    self.selectedMacroName = name
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetSelectMacro(info)
    return self.selectedMacro
end

function SimpleMB:SetSelectMacro(info, key)
    -- Update contents of macro edit box
    local name = options.args.main.args.macroSelectBox.values[key]
    self.selectedMacroName = name
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroName(info)
    return self.selectedMacroName
end

function SimpleMB:SetMacroName(info, name)
    name = self:CleanMacroName(name)

    if strtrim(name) == "" or name == self.selectedMacroName then
        return
    end

    -- Grabs the macro text stored under the old name and stores it under the new name
    local body = self.db.profile.macroTable[self.selectedMacroName].body
    local bindings = self.db.profile.macroTable[self.selectedMacroName].bindings
    self.db.profile.macroTable[name] = {}
    self.db.profile.macroTable[name].body = body
    self.db.profile.macroTable[name].bindings = bindings

    -- Erases the old name and sets the new name as the selection
    deleteButton(self.selectedMacroName)
    self.db.profile.macroTable[self.selectedMacroName] = nil

    self.selectedMacroName = name
    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroBody(info)
    return self.selectedMacroBody
end

function SimpleMB:SetMacroBody(info, body)
    if not self.selectedMacroName then return end

    self.db.profile.macroTable[self.selectedMacroName].body = body
    self.selectedMacroBody = body
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroBinding(info)
    if not self.selectedMacroName then return end

    local string = ""
    local bindings = self.db.profile.macroTable[self.selectedMacroName].bindings
    if #bindings > 0 then
        for _, key in ipairs(bindings) do
            string = string .. " " .. key
        end
    end

    return string
end

function SimpleMB:SetMacroBinding(info, key)
    local name = self.selectedMacroName
    if name == "" then return end

    if key == "" then
        self.db.profile.macroTable[name].bindings = {}
    else
        for _, binding in ipairs(self.db.profile.macroTable[name].bindings) do
            if key == binding then return end
        end
        table.insert(self.db.profile.macroTable[name].bindings, key)
    end

    self:BindMacro(name, self.db.profile.macroTable[name].bindings)
end

function SimpleMB:GetMacroDelete(info)
    return nil
end

function SimpleMB:SetMacroDelete(info, key)
    local name = options.args.main.args.macroDeleteBox.values[key]
    self.db.profile.macroTable[name] = nil

    deleteButton(name)

    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroKeyDown(info)
    -- default value
    if not self.selectedMacroName then
        return false
    end

    local value = self.db.profile.macroTable[self.selectedMacroName].keyDown

    -- Check for existence of keydown parameter
    if value == nil then
        value = false

    -- Check for third check box state and return a true nil
    elseif value == "both" then
        value = nil

    -- else return the value as is
    end

    return value
end

function SimpleMB:SetMacroKeyDown(info, value)
    local name = self.selectedMacroName
    if name == "" or name == nil then return end

    if value == nil then
        value = "both"
    end

    self.db.profile.macroTable[name].keyDown = value
    self:RegisterForKeyPress(name)
end


-- Macro Processing
function SimpleMB:BindMacro(name, bindings)
    local macro = self.db.profile.macroTable[name]
    local button = getButton(name)
    if #bindings == 0 then
        ClearOverrideBindings(button)
    else
        button:SetAttribute("type", "macro")
        button:SetAttribute("macrotext", self.db.profile.macroTable[name].body)
        ClearOverrideBindings(button)
        for _, key in ipairs(self.db.profile.macroTable[name].bindings) do
            SetOverrideBindingClick(button, false, key, button:GetName())
        end
    end
end

function SimpleMB:RegisterForKeyPress(name)
    local macro = self.db.profile.macroTable[name]
    local button = getButton(name)

    local keyDown = self.db.profile.macroTable[name].keyDown
    local up = ""
    local down = ""

    -- Tristate
    if keyDown == "both" then
        up = "AnyUp"
        down = "AnyDown"

    -- Key down
    elseif keyDown == true then
        down = "AnyDown"

    -- Default to key up
    else
        up = "AnyUp"
    end

    button:RegisterForClicks(up, down)
end

function SimpleMB:RefreshBindings()
    for name, macro in pairs(self.db.profile.macroTable) do
        self:BindMacro(name, macro.bindings)
        self:RegisterForKeyPress(name)
    end
end

function SimpleMB:GetMacroListKeyByName(name)
    local index = nil

    for i, macroName in ipairs(options.args.main.args.macroSelectBox.values) do
        if macroName == name then
            index = i
            break
        end
    end

    return index
end

function SimpleMB:UpdateMacroList()
    wipe(macroList)
    for name, _ in pairs(self.db.profile.macroTable) do
        table.insert(macroList, name)
    end

    table.sort(macroList)
    options.args.main.args.macroSelectBox.values = macroList
    options.args.main.args.macroDeleteBox.values = macroList
end

function SimpleMB:UpdateDisplayedMacro()
    local name = self.selectedMacroName
    self.selectedMacro = self:GetMacroListKeyByName(name)
    if self.selectedMacro then
        self.selectedMacroBody = self.db.profile.macroTable[name].body
        options.args.main.args.macroName.disabled = false
        options.args.main.args.macroEditBox.disabled = false
        options.args.main.args.macroBinding.disabled = false
    else
        self.selectedMacroName = nil
        self.selectedMacroBody = nil
        options.args.main.args.macroName.disabled = true
        options.args.main.args.macroEditBox.disabled = true
        options.args.main.args.macroBinding.disabled = true
    end
    self:RefreshBindings()
end

-- Chat command handling
function SimpleMB:ChatCommand(input)
    if not input or input:trim() == "" then
        InterfaceOptionsFrame_OpenToCategory("SimpleMB")
        InterfaceOptionsFrame_OpenToCategory("SimpleMacroBindings")
    elseif input:trim() == "help" then
        LibStub("AceConfigCmd-3.0").HandleCommand(SimpleMB, "simplemb", "SimpleMB", "")
    else
        LibStub("AceConfigCmd-3.0").HandleCommand(SimpleMB, "simplemb", "SimpleMB", input)
    end
end

-- Refresh UI
function SimpleMB:RefreshUI()

end


-- Profile Handling
function SimpleMB:InitializePresets(db, profile)
    self:RefreshConfig()
end

function SimpleMB:RefreshConfig()
    self:ClearMacros()
    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
    self:RefreshUI()
end

function SimpleMB:ClearMacros()
    for _, name in ipairs(macroList) do
        deleteButton(name)
    end
end

function SimpleMB:CleanMacroName(name)
    return gsub(name, ":%s*", "-")
end
