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

                macroGenerate = {
                    name = L['Generate Macro'],
                    type = 'toggle',
                    desc = L['Generate a macro in the general tab.'],
                    tristate = false,
                    set = 'SetMacroGenerate',
                    get = 'GetMacroGenerate',
                    order = 33,
                },

                macroIdName = {
                    name = L['Macro ID-Name'],
                    desc = L['Sets the Macro ID-Name for generate a macro.'],
                    type = 'input',
                    set = 'SetMacroIdName',
                    get = 'GetMacroIdName',
                    order = 34,
                },

                macroEditBox = {
                    name = L['Macro Text'],
                    type = 'input',
                    desc = "",
                    set = 'SetMacroBody',
                    get = 'GetMacroBody',
                    multiline = 5,
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

                macroCopyBox = {
                    name = L['Copy macro'],
                    type = 'select',
                    desc = L['Select a macro to be copied'],
                    set = 'SetMacroCopy',
                    get = 'GetMacroCopy',
                    style = 'dropdown',
                    values = {},
                    confirm = true,
                    confirmText = L['Are you sure you wish to copy the selected macro?'],
                    order = 45,
                },
            },
        },
        settings = {
            name = L['Settings'],
            type = 'group',
            args = {
                chatInfo = {
                    name = L['Chat messages'],
                    type = 'toggle',
                    desc = L['Chat message for macro generation.'],
                    tristate = false,
                    set = 'SetChatInfo',
                    get = 'GetChatInfo',
                    order = 1,
                },
            },
        },
    },
}

local defaults = {
    profile = {
        macroTable = {},
        settings = {
            chatInfo = true,
        }
    },
}

local macroList = {}

--- Event: OnInitialize
-- Called when the addon is initialized
function SimpleMB:OnInitialize()
    self.db = LibStub("AceDB-3.0"):New("SimpleMB_DB", defaults, true)
    options.args.profile = LibStub("AceDBOptions-3.0"):GetOptionsTable(self.db)
    LibStub("AceConfig-3.0"):RegisterOptionsTable("SimpleMB", options, nil)

    --@retail@
    local LibDualSpec = LibStub('LibDualSpec-1.0')
    LibDualSpec:EnhanceDatabase(self.db, "SimpleMB_DB")
    LibDualSpec:EnhanceOptions(options.args.profile, self.db)
    --@end-retail@

    self.inCombat = nil
    self.selectedMacro = nil
    self.selectedMacroName = nil
    self.selectedMacroBody = nil
    self.delayedMacroUpdate = false

    self:RegisterEvent("PLAYER_LOGIN", "RefreshConfig")
    self:RegisterEvent("PLAYER_REGEN_DISABLED", "OnPlayerEnterCombat")
    self:RegisterEvent("PLAYER_REGEN_ENABLED", "OnPlayerLeaveCombat")

    self.db.RegisterCallback(self, "OnNewProfile", "InitializePresets")
    self.db.RegisterCallback(self, "OnProfileReset", "InitializePresets")
    self.db.RegisterCallback(self, "OnProfileChanged", "RefreshConfig")
    self.db.RegisterCallback(self, "OnProfileCopied", "RefreshConfig")

    local ACD = LibStub("AceConfigDialog-3.0")
    ACD:AddToBlizOptions("SimpleMB", "SimpleMacroBindings", nil, "main")
    ACD:AddToBlizOptions("SimpleMB", L["Settings"], "SimpleMacroBindings", "settings")
    ACD:AddToBlizOptions("SimpleMB", L["Profile"], "SimpleMacroBindings", "profile")

    self:RegisterChatCommand("smb", "ChatCommand")
    self:RegisterChatCommand("simplemb", "ChatCommand")
    self:RegisterChatCommand("simplemacrobindings", "ChatCommand")

    self:UpdateDisplayedMacro()
    self:UpdateMacroList()
end

--- Callback: OnEnable
-- Called when the addon is enabled
function SimpleMB:OnEnable()

end

--- Callback: OnEnable
-- Called when the addon is disabled
function SimpleMB:OnDisable()

end

--- Callback: OnPlayerLogin
-- Called when the player login in
function SimpleMB:OnPlayerLogin()

end

--- Callback: OnPlayerEnterCombat
-- Called when the player is entered combat
function SimpleMB:OnPlayerEnterCombat()
    self.inCombat = true
end

--- Callback: OnPlayerLeaveCombat
-- Called when the player is leaved combat
function SimpleMB:OnPlayerLeaveCombat()
    self.inCombat = false

    if self.delayedMacroUpdate == true then
        self:UpdateAll()
        self.delayedMacroUpdate = false
    end
end


--- Service: ChatCommand
-- For chat commands handling
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

--- Service: UpdateAll
-- Updates all macros
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
            generate = false,
            idName = ""
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
    local generate = self.db.profile.macroTable[self.selectedMacroName].generate
    local idName = self.db.profile.macroTable[self.selectedMacroName].idName

    self.db.profile.macroTable[name] = {}
    self.db.profile.macroTable[name].body = body
    self.db.profile.macroTable[name].bindings = bindings
    self.db.profile.macroTable[name].generate = generate
    self.db.profile.macroTable[name].idName = idName

    -- Erases the old name and sets the new name as the selection
    self.db.profile.macroTable[self.selectedMacroName] = nil

    self.selectedMacroName = name
    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroBody(info)
    return self.selectedMacroBody
end

function SimpleMB:SetMacroBody(info, body)
    if not self.selectedMacroName then
        return
    end

    self.db.profile.macroTable[self.selectedMacroName].body = body
    self.selectedMacroBody = body

    self:UpdateDisplayedMacro()

    if self.db.profile.macroTable[self.selectedMacroName].generate then
        self:MacroGenerate(self.selectedMacroName)
    end
end

function SimpleMB:GetMacroDelete(info)
    return nil
end

function SimpleMB:SetMacroDelete(info, key)
    local name = options.args.main.args.macroDeleteBox.values[key]
    self.db.profile.macroTable[name] = nil

    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroCopy(info)
    return nil
end

function SimpleMB:SetMacroCopy(info, key)
    local name = options.args.main.args.macroCopyBox.values[key]
    local body = self.db.profile.macroTable[name].body

    if not self.selectedMacroName then
        return
    end

    self.db.profile.macroTable[self.selectedMacroName].body = body
    self.selectedMacroBody = body
    self:UpdateDisplayedMacro()
end

function SimpleMB:GetMacroGenerate(info)
    -- default value
    if not self.selectedMacroName then
        return false
    end

    return self.db.profile.macroTable[self.selectedMacroName].generate
end

function SimpleMB:SetMacroGenerate(info, value)
    local name = self.selectedMacroName

    if name == "" or name == nil then
        return
    end

    self.db.profile.macroTable[name].generate = value

    self:MacroGenerate(name)
end

function SimpleMB:GetMacroIdName(info)
    if not self.selectedMacroName then
        return false
    end

    return self.db.profile.macroTable[self.selectedMacroName].idName
end

function SimpleMB:SetMacroIdName(info, value)
    if strtrim(value) == "" then
        return
    end

    self.db.profile.macroTable[self.selectedMacroName].idName = self:CleanMacroIdName(value)
end

-- Settings
function SimpleMB:GetChatInfo(info)
    return self.db.profile.settings.chatInfo
end

function SimpleMB:SetChatInfo(info, value)
    self.db.profile.settings.chatInfo = value
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

        self:MacroGenerate(name)
    end

    table.sort(macroList)

    options.args.main.args.macroSelectBox.values = macroList
    options.args.main.args.macroDeleteBox.values = macroList
    options.args.main.args.macroCopyBox.values = macroList
end

function SimpleMB:UpdateDisplayedMacro()
    local name = self.selectedMacroName
    self.selectedMacro = self:GetMacroListKeyByName(name)

    if self.selectedMacro then
        self.selectedMacroBody = self.db.profile.macroTable[name].body
        options.args.main.args.macroName.disabled = false
        options.args.main.args.macroEditBox.disabled = false
    else
        self.selectedMacroName = nil
        self.selectedMacroBody = nil
        options.args.main.args.macroName.disabled = true
        options.args.main.args.macroEditBox.disabled = true
    end
end

-- Macro Handling
function SimpleMB:MacroGenerate(name)
    if self.db.profile.macroTable[name].generate and self.db.profile.macroTable[name].idName then
        local idName = "ZZ_SMB:" .. self.db.profile.macroTable[name].idName

        if GetMacroIndexByName(idName) > 0 then
            self:MacroUpdate(name, idName)
        else
            self:MacroCreate(name, idName)
        end
    end
end

function SimpleMB:MacroCreate(name, idName)
    CreateMacro(idName, "INV_Misc_QuestionMark", self.db.profile.macroTable[name].body, nil, nil)

    if self:Debug() then
        self:Print("Create Macro: " .. idName)
    end
end

function SimpleMB:MacroUpdate(name, idName)
    EditMacro(idName, idName, "INV_Misc_QuestionMark", self.db.profile.macroTable[name].body)

    if self:Debug() then
        self:Print("Update Macro: " .. idName)
    end
end

-- Helpers
function SimpleMB:CleanMacroName(name)
    return gsub(name, ":%s*", "-")
end

function SimpleMB:CleanMacroIdName(name)
    return strupper(gsub(name, "%s+", "_"))
end

-- Refresh UI
function SimpleMB:RefreshUI()

end

-- Profile Handling
function SimpleMB:InitializePresets(db, profile)
    --self:RefreshConfig()
end

function SimpleMB:RefreshConfig()
    self:UpdateMacroList()
    self:UpdateDisplayedMacro()
    self:RefreshUI()
end

function SimpleMB:Debug()
    return self.db.profile.settings.chatInfo
end
