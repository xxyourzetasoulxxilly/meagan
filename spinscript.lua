if _G.MockTradeScriptLoaded then
    return
end
_G.MockTradeScriptLoaded = true
local Services = {
    Players = game:GetService('Players'),
    ReplicatedStorage = game:GetService('ReplicatedStorage'),
    RunService = game:GetService('RunService'),
    UserInputService = game:GetService('UserInputService'),
    TweenService = game:GetService('TweenService'),
    HttpService = game:GetService('HttpService'),
    Chat = game:GetService('Chat')
}
pcall(function()
    setthreadidentity(2)
end)
local fakePlayerIds = {}
_G.fakePlayerIds = fakePlayerIds
task.spawn(function()
    task.wait(0.1)
    local SettingsHelper = require(Services.ReplicatedStorage:WaitForChild('Fsys')).load('SettingsHelper')
    local original_get_setting_server = SettingsHelper.get_setting_server
    SettingsHelper.get_setting_server = function(player, settingName, ...)
        if player and player.UserId then
            if fakePlayerIds[player.UserId] then return false end
            if not Services.Players:GetPlayerByUserId(player.UserId) then return false end
        end
        local args = { ... }
        local success, result = pcall(function()
            return original_get_setting_server(player, settingName, table.unpack(args))
        end)
        if success then return result else return false end
    end
end)
task.spawn(function()
    task.wait(0.1)
    local FamilyHelper = require(Services.ReplicatedStorage:WaitForChild('Fsys')).load('FamilyHelper')
    local original_are_friends_family = FamilyHelper.are_friends_family
    local original_is_my_friend_or_family = FamilyHelper.is_my_friend_or_family
    local original_are_family_because_friends = FamilyHelper.are_family_because_friends
    local original_is_my_family_because_friend = FamilyHelper.is_my_family_because_friend
    FamilyHelper.are_friends_family = function(player1, player2)
        if player1 and player2 and (fakePlayerIds[player1.UserId] or fakePlayerIds[player2.UserId]) then return false end
        return original_are_friends_family(player1, player2)
    end
    FamilyHelper.is_my_friend_or_family = function(player)
        if player and fakePlayerIds[player.UserId] then return false end
        return original_is_my_friend_or_family(player)
    end
    FamilyHelper.are_family_because_friends = function(player1, player2)
        if player1 and player2 and (fakePlayerIds[player1.UserId] or fakePlayerIds[player2.UserId]) then return false end
        return original_are_family_because_friends(player1, player2)
    end
    FamilyHelper.is_my_family_because_friend = function(player)
        if player and fakePlayerIds[player.UserId] then return false end
        return original_is_my_family_because_friend(player)
    end
end)
local Fsys = require(Services.ReplicatedStorage:WaitForChild('Fsys'))
local Modules = {
    UIManager = Fsys.load('UIManager'),
    ClientData = Fsys.load('ClientData'),
    TableUtil = Fsys.load('TableUtil'),
    RouterClient = Fsys.load('RouterClient'),
    InventoryDB = Fsys.load('InventoryDB'),
    animationManager = Fsys.load('AnimationManager'),
    ColorThemeManager = Fsys.load('ColorThemeManager')
}
if Modules.UIManager.wait_for_initialization then
    Modules.UIManager:wait_for_initialization()
else
    task.wait(2)
end
local Apps = {
    TradeApp = Modules.UIManager.apps.TradeApp,
    BackpackApp = Modules.UIManager.apps.BackpackApp,
    DialogApp = Modules.UIManager.apps.DialogApp,
    HintApp = Modules.UIManager.apps.HintApp,
    SettingsApp = Modules.UIManager.apps.SettingsApp,
    PlayerProfileApp = Modules.UIManager.apps.PlayerProfileApp,
    TradeHistoryApp = Modules.UIManager.apps.TradeHistoryApp,
    TradePreviewApp = Modules.UIManager.apps.TradePreviewApp
}
local NegotiationFrame = Services.Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame
local ConfirmationFrame = Services.Players.LocalPlayer.PlayerGui.TradeApp.Frame.ConfirmationFrame
do
    local originalDialog = Apps.DialogApp.dialog
    Apps.DialogApp.dialog = function(self, data, ...)
        if data and data.text then
            data.text = data.text:gsub("suggestion", "boost"):gsub("Suggestion", "Boost"):gsub("suggest", "boost"):gsub("Suggest", "Boost")
        end
        if data and data.right then
            data.right = data.right:gsub("Suggest", "Boost")
        end
        if data and data.left then
            data.left = data.left:gsub("Suggest", "Boost")
        end
        return originalDialog(self, data, ...)
    end
end
local function FriendHighlight(FriendValue)
    NegotiationFrame.FriendHighlight.Visible = FriendValue
    NegotiationFrame.FriendBorder.Visible = FriendValue
    NegotiationFrame.Header.PartnerFrame.NameLabel.FriendLabel.Visible = FriendValue
    local ColorThemeManagerColor = Modules.ColorThemeManager.lookup(FriendValue and 'background' or 'saturated')
    NegotiationFrame.Header.PartnerFrame.ProfileIcon.ImageColor3 = ColorThemeManagerColor
    NegotiationFrame.Header.PartnerFrame.NameLabel.TextColor3 = ColorThemeManagerColor
    NegotiationFrame.Header.PartnerFrame.Icon.Visible = FriendValue
    NegotiationFrame.Header.PartnerFrame.Icon.Image = 'rbxassetid://84667805159408'
    Apps.TradeApp.confirmation_partner_icon.Image = FriendValue and 'rbxassetid://84667805159408' or ''
    Apps.TradeApp.confirmation_partner_icon.Visible = FriendValue
    pcall(function()
        if mockState and mockState.active then
            NegotiationFrame.Header.PartnerFrame.NameLabel.Text = CONFIG.PARTNER_NAME
        end
    end)
end
do
    local originalRemotes = {}
    local routerInit
    local routerInitIdx
    for idx = 1, 30 do
        local val = debug.getupvalue(Modules.RouterClient.init, idx)
        if type(val) == "table" then
            local isRemoteTable = false
            for _, entry in pairs(val) do
                if typeof(entry) == "Instance" and (entry:IsA("RemoteFunction") or entry:IsA("RemoteEvent")) then
                    isRemoteTable = true
                    break
                end
            end
            if isRemoteTable then
                routerInit = val
                routerInitIdx = idx
                break
            end
        end
    end
    if not routerInit then
        warn("[MockTrade] Could not find RouterClient remotes upvalue - skipping tool hook")
        return
    end
    for i, v in pairs(routerInit) do
        v.Name = i
        originalRemotes[i] = v
    end
    local spawnToys = Modules.ClientData.get("inventory").toys
    local spawnLicenseUniqueId
    for i, v in pairs(spawnToys) do
        if v.id == "trade_license" then
            spawnLicenseUniqueId = i
            break
        end
    end
    local function hookedEquip(player, uniqueId, ...)
        if uniqueId == spawnLicenseUniqueId then
            Modules.UIManager.set_app_visibility("TradeHistoryApp", true)
        end
        return originalRemotes["ToolAPI/Equip"](player, uniqueId, ...)
    end
    local function hookedUnequip(player, uniqueId)
        if uniqueId == spawnLicenseUniqueId then
            Modules.UIManager.set_app_visibility("TradeHistoryApp", false)
        end
        return originalRemotes["ToolAPI/Unequip"](player, uniqueId)
    end
    debug.setupvalue(Modules.RouterClient.init, routerInitIdx,
        setmetatable({
            ["ToolAPI/Equip"] = hookedEquip,
            ["ToolAPI/Unequip"] = hookedUnequip
        }, {
            __index = originalRemotes,
            __newindex = function(t, k, v)
                if k == "ToolAPI/Equip" or k == "ToolAPI/Unequip" then
                    rawset(t, k, v)
                else
                    originalRemotes[k] = v
                end
            end
        })
    )
end
do
    if Apps.TradeHistoryApp._ORIGINAL_create_trade_frame then
        Apps.TradeHistoryApp._create_trade_frame = Apps.TradeHistoryApp._ORIGINAL_create_trade_frame
    end
    if Apps.TradeApp._ORIGINAL_change_local_trade_state then
        Apps.TradeApp._change_local_trade_state = Apps.TradeApp._ORIGINAL_change_local_trade_state
    end
    if Apps.TradeApp._ORIGINAL_overwrite_local_trade_state then
        Apps.TradeApp._overwrite_local_trade_state = Apps.TradeApp._ORIGINAL_overwrite_local_trade_state
    end
    Apps.TradeHistoryApp._ORIGINAL_create_trade_frame = Apps.TradeHistoryApp._create_trade_frame
    Apps.TradeApp._ORIGINAL_change_local_trade_state = Apps.TradeApp._change_local_trade_state
    Apps.TradeApp._ORIGINAL_overwrite_local_trade_state = Apps.TradeApp._overwrite_local_trade_state
    local spawnTradeOffers = {}
    Apps.TradeApp._change_local_trade_state = function(self, change, ...)
        local state = self:_get_local_trade_state()
        if state and state.trade_id then
            if state.sender == Services.Players.LocalPlayer and change.sender_offer then
                spawnTradeOffers[state.trade_id] = {
                    items = table.clone(change.sender_offer.items),
                    isSender = true
                }
            elseif state.recipient == Services.Players.LocalPlayer and change.recipient_offer then
                spawnTradeOffers[state.trade_id] = {
                    items = table.clone(change.recipient_offer.items),
                    isSender = false
                }
            end
        end
        return Apps.TradeApp._ORIGINAL_change_local_trade_state(self, change, ...)
    end
    Apps.TradeApp._overwrite_local_trade_state = function(self, trade, ...)
        if not trade and Apps.TradeApp._last_trade_id then
            spawnTradeOffers[Apps.TradeApp._last_trade_id] = nil
        end
        return Apps.TradeApp._ORIGINAL_overwrite_local_trade_state(self, trade, ...)
    end
    Apps.TradeHistoryApp._create_trade_frame = function(self, tradeData, ...)
        if tradeData.trade_id and spawnTradeOffers[tradeData.trade_id] then
            local offer = spawnTradeOffers[tradeData.trade_id]
            local modified = table.clone(tradeData)
            if offer.isSender then
                modified.sender_items = table.clone(offer.items)
            else
                modified.recipient_items = table.clone(offer.items)
            end
            return self._ORIGINAL_create_trade_frame(self, modified, ...)
        end
        return self._ORIGINAL_create_trade_frame(self, tradeData, ...)
    end
end
do
    local spawnData
    local _spawnOverwrite = Modules.UIManager.apps.TradeApp._overwrite_local_trade_state
    Modules.UIManager.apps.TradeApp._overwrite_local_trade_state = function(self, trade, ...)
        if trade then
            local offer = trade.sender == Services.Players.LocalPlayer and trade.sender_offer or trade.recipient == Services.Players.LocalPlayer and trade.recipient_offer
            if offer then
                if spawnData then offer.items = spawnData end
            end
        else
            spawnData = nil
        end
        return _spawnOverwrite(self, trade, ...)
    end
    local _spawnChange = Modules.UIManager.apps.TradeApp._change_local_trade_state
    Modules.UIManager.apps.TradeApp._change_local_trade_state = function(self, change, ...)
        local trade = Modules.UIManager.apps.TradeApp.local_trade_state
        if trade then
            local team = trade.sender == Services.Players.LocalPlayer and "sender_offer" or trade.recipient == Services.Players.LocalPlayer and "recipient_offer"
            if team then
                local offer = change[team]
                if offer and offer.items then spawnData = offer.items end
            end
        end
        return _spawnChange(self, change, ...)
    end
end
local PetData = {}
PetData.downloader = Fsys.load('DownloadClient')
PetData.petModels = {}
local function getPetModel(kind)
    if PetData.petModels[kind] then return PetData.petModels[kind]:Clone() end
    local success, streamed = pcall(function()
        local promise = PetData.downloader.promise_download_copy('Pets', kind)
        if promise then return promise:expect() end
        return nil
    end)
    if success and streamed then
        PetData.petModels[kind] = streamed
        return streamed:Clone()
    else
        return nil
    end
end
if not Apps.TradeApp then return end
PetData.petDisplayNames = {}
for category, items in pairs(Modules.InventoryDB) do
    if category == "pets" then
        for id, petinfo in pairs(items) do
            PetData.petDisplayNames[id] = petinfo.name
        end
    end
end
local fallbackPetValues = {
    ["Bat Dragon"] = {name = "Bat Dragon", ["rvalue - nopotion"] = 503, ["rvalue - fly&ride"] = 491, ["nvalue - fly&ride"] = 1280, ["mvalue - fly&ride"] = 3620},
    ["Shadow Dragon"] = {name = "Shadow Dragon", ["rvalue - nopotion"] = 473, ["rvalue - fly&ride"] = 331, ["nvalue - fly&ride"] = 777, ["mvalue - fly&ride"] = 1950},
    ["Giraffe"] = {name = "Giraffe", ["rvalue - nopotion"] = 230, ["rvalue - fly&ride"] = 220, ["nvalue - fly&ride"] = 536, ["mvalue - fly&ride"] = 1870},
    ["Frost Dragon"] = {name = "Frost Dragon", ["rvalue - nopotion"] = 181, ["rvalue - fly&ride"] = 170, ["nvalue - fly&ride"] = 361, ["mvalue - fly&ride"] = 1050},
    ["Owl"] = {name = "Owl", ["rvalue - nopotion"] = 144, ["rvalue - fly&ride"] = 142, ["nvalue - fly&ride"] = 389, ["mvalue - fly&ride"] = 1430},
    ["Parrot"] = {name = "Parrot", ["rvalue - nopotion"] = 112.5, ["rvalue - fly&ride"] = 111.5, ["nvalue - fly&ride"] = 242, ["mvalue - fly&ride"] = 840},
    ["Crow"] = {name = "Crow", ["rvalue - nopotion"] = 93, ["rvalue - fly&ride"] = 92.5, ["nvalue - fly&ride"] = 233, ["mvalue - fly&ride"] = 920},
    ["Evil Unicorn"] = {name = "Evil Unicorn", ["rvalue - nopotion"] = 80.5, ["rvalue - fly&ride"] = 80, ["nvalue - fly&ride"] = 174, ["mvalue - fly&ride"] = 670},
    ["African Wild Dog"] = {name = "African Wild Dog", ["rvalue - nopotion"] = 57, ["rvalue - fly&ride"] = 58, ["nvalue - fly&ride"] = 192, ["mvalue - fly&ride"] = 720},
    ["Hedgehog"] = {name = "Hedgehog", ["rvalue - nopotion"] = 53.5, ["rvalue - fly&ride"] = 54, ["nvalue - fly&ride"] = 182, ["mvalue - fly&ride"] = 705},
    ["Balloon Unicorn"] = {name = "Balloon Unicorn", ["rvalue - nopotion"] = 51.5, ["rvalue - fly&ride"] = 53, ["nvalue - fly&ride"] = 186, ["mvalue - fly&ride"] = 730},
    ["Diamond Butterfly"] = {name = "Diamond Butterfly", ["rvalue - nopotion"] = 51, ["rvalue - fly&ride"] = 49, ["nvalue - fly&ride"] = 160, ["mvalue - fly&ride"] = 565},
    ["Blazing Lion"] = {name = "Blazing Lion", ["rvalue - nopotion"] = 46, ["rvalue - fly&ride"] = 48, ["nvalue - fly&ride"] = 175, ["mvalue - fly&ride"] = 708},
    ["Orchid Butterfly"] = {name = "Orchid Butterfly", ["rvalue - nopotion"] = 44, ["rvalue - fly&ride"] = 45, ["nvalue - fly&ride"] = 183, ["mvalue - fly&ride"] = 735},
    ["Dalmatian"] = {name = "Dalmatian", ["rvalue - nopotion"] = 43.5, ["rvalue - fly&ride"] = 44, ["nvalue - fly&ride"] = 134, ["mvalue - fly&ride"] = 490},
    ["Arctic Reindeer"] = {name = "Arctic Reindeer", ["rvalue - nopotion"] = 39, ["rvalue - fly&ride"] = 38, ["nvalue - fly&ride"] = 80, ["mvalue - fly&ride"] = 302},
    ["Giant Panda"] = {name = "Giant Panda", ["rvalue - nopotion"] = 35, ["rvalue - fly&ride"] = 35, ["nvalue - fly&ride"] = 155, ["mvalue - fly&ride"] = 650},
    ["Cryptid"] = {name = "Cryptid", ["rvalue - nopotion"] = 26.5, ["rvalue - fly&ride"] = 28, ["nvalue - fly&ride"] = 97, ["mvalue - fly&ride"] = 330},
    ["Haetae"] = {name = "Haetae", ["rvalue - nopotion"] = 25.5, ["rvalue - fly&ride"] = 26, ["nvalue - fly&ride"] = 105, ["mvalue - fly&ride"] = 430},
    ["Cow"] = {name = "Cow", ["rvalue - nopotion"] = 23, ["rvalue - fly&ride"] = 25.5, ["nvalue - fly&ride"] = 58.5, ["mvalue - fly&ride"] = 212},
    ["Pelican"] = {name = "Pelican", ["rvalue - nopotion"] = 24, ["rvalue - fly&ride"] = 25, ["nvalue - fly&ride"] = 99, ["mvalue - fly&ride"] = 410},
    ["Strawberry Shortcake Bat Dragon"] = {name = "Strawberry Shortcake Bat Dragon", ["rvalue - nopotion"] = 22, ["rvalue - fly&ride"] = 23.5, ["nvalue - fly&ride"] = 69, ["mvalue - fly&ride"] = 217},
    ["Peppermint Penguin"] = {name = "Peppermint Penguin", ["rvalue - nopotion"] = 21.25, ["rvalue - fly&ride"] = 22.75, ["nvalue - fly&ride"] = 71, ["mvalue - fly&ride"] = 240},
    ["Turtle"] = {name = "Turtle", ["rvalue - nopotion"] = 20, ["rvalue - fly&ride"] = 22.5, ["nvalue - fly&ride"] = 48.5, ["mvalue - fly&ride"] = 128.5},
    ["Chocolate Chip Bat Dragon"] = {name = "Chocolate Chip Bat Dragon", ["rvalue - nopotion"] = 20, ["rvalue - fly&ride"] = 21.5, ["nvalue - fly&ride"] = 67, ["mvalue - fly&ride"] = 214},
    ["Monkey King"] = {name = "Monkey King", ["rvalue - nopotion"] = 21, ["rvalue - fly&ride"] = 20, ["nvalue - fly&ride"] = 69, ["mvalue - fly&ride"] = 275},
    ["Flamingo"] = {name = "Flamingo", ["rvalue - nopotion"] = 17.5, ["rvalue - fly&ride"] = 18, ["nvalue - fly&ride"] = 71, ["mvalue - fly&ride"] = 280},
    ["Mini Pig"] = {name = "Mini Pig", ["rvalue - nopotion"] = 17.5, ["rvalue - fly&ride"] = 18, ["nvalue - fly&ride"] = 72, ["mvalue - fly&ride"] = 295},
    ["Hot Doggo"] = {name = "Hot Doggo", ["rvalue - nopotion"] = 16, ["rvalue - fly&ride"] = 16.5, ["nvalue - fly&ride"] = 68, ["mvalue - fly&ride"] = 286},
    ["Kangaroo"] = {name = "Kangaroo", ["rvalue - nopotion"] = 15, ["rvalue - fly&ride"] = 16.5, ["nvalue - fly&ride"] = 36, ["mvalue - fly&ride"] = 101.5},
    ["Albino Monkey"] = {name = "Albino Monkey", ["rvalue - nopotion"] = 15.25, ["rvalue - fly&ride"] = 15.5, ["nvalue - fly&ride"] = 50, ["mvalue - fly&ride"] = 204},
    ["Elephant"] = {name = "Elephant", ["rvalue - nopotion"] = 15, ["rvalue - fly&ride"] = 15.5, ["nvalue - fly&ride"] = 47.5, ["mvalue - fly&ride"] = 195},
    ["Candyfloss Chick"] = {name = "Candyfloss Chick", ["rvalue - nopotion"] = 13.5, ["rvalue - fly&ride"] = 14.5, ["nvalue - fly&ride"] = 54.5, ["mvalue - fly&ride"] = 220},
    ["Crocodile"] = {name = "Crocodile", ["rvalue - nopotion"] = 11.75, ["rvalue - fly&ride"] = 12.75, ["nvalue - fly&ride"] = 43, ["mvalue - fly&ride"] = 172},
    ["Blue Dog"] = {name = "Blue Dog", ["rvalue - nopotion"] = 12, ["rvalue - fly&ride"] = 12, ["nvalue - fly&ride"] = 42, ["mvalue - fly&ride"] = 162},
    ["Sugar Glider"] = {name = "Sugar Glider", ["rvalue - nopotion"] = 11.5, ["rvalue - fly&ride"] = 12, ["nvalue - fly&ride"] = 49, ["mvalue - fly&ride"] = 207},
    ["Caterpillar"] = {name = "Caterpillar", ["rvalue - nopotion"] = 11.5, ["rvalue - fly&ride"] = 12, ["nvalue - fly&ride"] = 50, ["mvalue - fly&ride"] = 210},
    ["Lion"] = {name = "Lion", ["rvalue - nopotion"] = 11, ["rvalue - fly&ride"] = 12, ["nvalue - fly&ride"] = 40, ["mvalue - fly&ride"] = 167},
    ["Fairy Bat Dragon"] = {name = "Fairy Bat Dragon", ["rvalue - nopotion"] = 9.5, ["rvalue - fly&ride"] = 10.75, ["nvalue - fly&ride"] = 36, ["mvalue - fly&ride"] = 140},
    ["Winged Tiger"] = {name = "Winged Tiger", ["rvalue - nopotion"] = 7, ["rvalue - fly&ride"] = 7.5, ["nvalue - fly&ride"] = 33.5, ["mvalue - fly&ride"] = 146},
    ["Goat"] = {name = "Goat", ["rvalue - nopotion"] = 6.75, ["rvalue - fly&ride"] = 7.25, ["nvalue - fly&ride"] = 30, ["mvalue - fly&ride"] = 136},
    ["Lion Cub"] = {name = "Lion Cub", ["rvalue - nopotion"] = 6.5, ["rvalue - fly&ride"] = 7, ["nvalue - fly&ride"] = 29.5, ["mvalue - fly&ride"] = 131},
    ["Sheeeeep"] = {name = "Sheeeeep", ["rvalue - nopotion"] = 5.5, ["rvalue - fly&ride"] = 6, ["nvalue - fly&ride"] = 25, ["mvalue - fly&ride"] = 113},
    ["Shark Puppy"] = {name = "Shark Puppy", ["rvalue - nopotion"] = 5.5, ["rvalue - fly&ride"] = 6, ["nvalue - fly&ride"] = 27, ["mvalue - fly&ride"] = 117},
    ["Jellyfish"] = {name = "Jellyfish", ["rvalue - nopotion"] = 5.5, ["rvalue - fly&ride"] = 6, ["nvalue - fly&ride"] = 25, ["mvalue - fly&ride"] = 113},
    ["Meerkat"] = {name = "Meerkat", ["rvalue - nopotion"] = 5.25, ["rvalue - fly&ride"] = 5.75, ["nvalue - fly&ride"] = 26, ["mvalue - fly&ride"] = 114},
    ["Nessie"] = {name = "Nessie", ["rvalue - nopotion"] = 5, ["rvalue - fly&ride"] = 5.5, ["nvalue - fly&ride"] = 24, ["mvalue - fly&ride"] = 109},
    ["Pink Cat"] = {name = "Pink Cat", ["rvalue - nopotion"] = 4.75, ["rvalue - fly&ride"] = 5.25, ["nvalue - fly&ride"] = 20, ["mvalue - fly&ride"] = 86},
    ["Hare"] = {name = "Hare", ["rvalue - nopotion"] = 4.5, ["rvalue - fly&ride"] = 5, ["nvalue - fly&ride"] = 20.5, ["mvalue - fly&ride"] = 87},
    ["Zombie Buffalo"] = {name = "Zombie Buffalo", ["rvalue - nopotion"] = 4.25, ["rvalue - fly&ride"] = 4.75, ["nvalue - fly&ride"] = 21, ["mvalue - fly&ride"] = 94},
    ["Many Mackerel"] = {name = "Many Mackerel", ["rvalue - nopotion"] = 4.25, ["rvalue - fly&ride"] = 4.75, ["nvalue - fly&ride"] = 21, ["mvalue - fly&ride"] = 94},
    ["Honey Badger"] = {name = "Honey Badger", ["rvalue - nopotion"] = 3.5, ["rvalue - fly&ride"] = 4, ["nvalue - fly&ride"] = 17.5, ["mvalue - fly&ride"] = 75},
    ["Unicorn"] = {name = "Unicorn", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 4, ["nvalue - fly&ride"] = 15, ["mvalue - fly&ride"] = 44},
    ["Happy Clam"] = {name = "Happy Clam", ["rvalue - nopotion"] = 3.25, ["rvalue - fly&ride"] = 3.75, ["nvalue - fly&ride"] = 16, ["mvalue - fly&ride"] = 68},
    ["Rhino"] = {name = "Rhino", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 7, ["mvalue - fly&ride"] = 35},
    ["Ram"] = {name = "Ram", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 43},
    ["Yeti"] = {name = "Yeti", ["rvalue - nopotion"] = 0.65, ["rvalue - fly&ride"] = 1.15, ["nvalue - fly&ride"] = 5.25, ["mvalue - fly&ride"] = 26},
    ["Frostbite Bear"] = {name = "Frostbite Bear", ["rvalue - nopotion"] = 7.75, ["rvalue - fly&ride"] = 8.25, ["nvalue - fly&ride"] = 37, ["mvalue - fly&ride"] = 160},
    ["Cat"] = {name = "Cat", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Dog"] = {name = "Dog", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Lunar Tiger"] = {name = "Lunar Tiger", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.55, ["nvalue - fly&ride"] = 0.75, ["mvalue - fly&ride"] = 2.5},
    ["King Bee"] = {name = "King Bee", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Queen Bee"] = {name = "Queen Bee", ["rvalue - nopotion"] = 8, ["rvalue - fly&ride"] = 8.5, ["nvalue - fly&ride"] = 35, ["mvalue - fly&ride"] = 145},
    ["Dragon"] = {name = "Dragon", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 40},
    ["Griffin"] = {name = "Griffin", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 32},
    ["Golden Unicorn"] = {name = "Golden Unicorn", ["rvalue - nopotion"] = 3.5, ["rvalue - fly&ride"] = 4, ["nvalue - fly&ride"] = 16, ["mvalue - fly&ride"] = 65},
    ["Golden Dragon"] = {name = "Golden Dragon", ["rvalue - nopotion"] = 3.5, ["rvalue - fly&ride"] = 4, ["nvalue - fly&ride"] = 16, ["mvalue - fly&ride"] = 65},
    ["Golden Griffin"] = {name = "Golden Griffin", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Diamond Unicorn"] = {name = "Diamond Unicorn", ["rvalue - nopotion"] = 5, ["rvalue - fly&ride"] = 5.5, ["nvalue - fly&ride"] = 22, ["mvalue - fly&ride"] = 90},
    ["Diamond Dragon"] = {name = "Diamond Dragon", ["rvalue - nopotion"] = 5, ["rvalue - fly&ride"] = 5.5, ["nvalue - fly&ride"] = 22, ["mvalue - fly&ride"] = 90},
    ["Diamond Griffin"] = {name = "Diamond Griffin", ["rvalue - nopotion"] = 4.5, ["rvalue - fly&ride"] = 5, ["nvalue - fly&ride"] = 20, ["mvalue - fly&ride"] = 82},
    ["Frost Fury"] = {name = "Frost Fury", ["rvalue - nopotion"] = 4, ["rvalue - fly&ride"] = 4.5, ["nvalue - fly&ride"] = 18, ["mvalue - fly&ride"] = 75},
    ["Snow Owl"] = {name = "Snow Owl", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["T-Rex"] = {name = "T-Rex", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Dodo"] = {name = "Dodo", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Skele-Rex"] = {name = "Skele-Rex", ["rvalue - nopotion"] = 4, ["rvalue - fly&ride"] = 4.5, ["nvalue - fly&ride"] = 18, ["mvalue - fly&ride"] = 75},
    ["Cerberus"] = {name = "Cerberus", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 33},
    ["Robo Dog"] = {name = "Robo Dog", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Guardian Lion"] = {name = "Guardian Lion", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 33},
    ["Peacock"] = {name = "Peacock", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Axolotl"] = {name = "Axolotl", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Phoenix"] = {name = "Phoenix", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Goldhorn"] = {name = "Goldhorn", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Shark"] = {name = "Shark", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Octopus"] = {name = "Octopus", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Metal Ox"] = {name = "Metal Ox", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Lunar Gold Tiger"] = {name = "Lunar Gold Tiger", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Dancing Dragon"] = {name = "Dancing Dragon", ["rvalue - nopotion"] = 3.5, ["rvalue - fly&ride"] = 4, ["nvalue - fly&ride"] = 16, ["mvalue - fly&ride"] = 65},
    ["Capricorn"] = {name = "Capricorn", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Lavender Dragon"] = {name = "Lavender Dragon", ["rvalue - nopotion"] = 10, ["rvalue - fly&ride"] = 10.5, ["nvalue - fly&ride"] = 42, ["mvalue - fly&ride"] = 175},
    ["Ice Golem"] = {name = "Ice Golem", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Hawk"] = {name = "Hawk", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Chimera"] = {name = "Chimera", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Maneki-Neko"] = {name = "Maneki-Neko", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Winged Horse"] = {name = "Winged Horse", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Fallow Deer"] = {name = "Fallow Deer", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Mechapup"] = {name = "Mechapup", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Albino Bat"] = {name = "Albino Bat", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Arctic Fox"] = {name = "Arctic Fox", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Bee"] = {name = "Bee", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Business Monkey"] = {name = "Business Monkey", ["rvalue - nopotion"] = 4, ["rvalue - fly&ride"] = 4.5, ["nvalue - fly&ride"] = 18, ["mvalue - fly&ride"] = 75},
    ["Clownfish"] = {name = "Clownfish", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Deinonychus"] = {name = "Deinonychus", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Frog"] = {name = "Frog", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Ghost Bunny"] = {name = "Ghost Bunny", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 33},
    ["Ginger Cat"] = {name = "Ginger Cat", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Horse"] = {name = "Horse", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Koala"] = {name = "Koala", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Lamb"] = {name = "Lamb", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 33},
    ["Llama"] = {name = "Llama", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Penguin"] = {name = "Penguin", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Pig"] = {name = "Pig", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Platypus"] = {name = "Platypus", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Red Panda"] = {name = "Red Panda", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Shiba Inu"] = {name = "Shiba Inu", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Sloth"] = {name = "Sloth", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Starfish"] = {name = "Starfish", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Turkey"] = {name = "Turkey", ["rvalue - nopotion"] = 4, ["rvalue - fly&ride"] = 4.5, ["nvalue - fly&ride"] = 18, ["mvalue - fly&ride"] = 75},
    ["Zombie Buffalo"] = {name = "Zombie Buffalo", ["rvalue - nopotion"] = 4.25, ["rvalue - fly&ride"] = 4.75, ["nvalue - fly&ride"] = 21, ["mvalue - fly&ride"] = 94},
    ["Toy Monkey"] = {name = "Toy Monkey", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Toucan"] = {name = "Toucan", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Lynx"] = {name = "Lynx", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Panda"] = {name = "Panda", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Brown Bear"] = {name = "Brown Bear", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Polar Bear"] = {name = "Polar Bear", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Hyena"] = {name = "Hyena", ["rvalue - nopotion"] = 3, ["rvalue - fly&ride"] = 3.5, ["nvalue - fly&ride"] = 14, ["mvalue - fly&ride"] = 58},
    ["Wild Boar"] = {name = "Wild Boar", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Capybara"] = {name = "Capybara", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Merhorse"] = {name = "Merhorse", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Sabertooth"] = {name = "Sabertooth", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Ladybug"] = {name = "Ladybug", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Wyvern"] = {name = "Wyvern", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Hydra"] = {name = "Hydra", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["St. Bernard"] = {name = "St. Bernard", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Squirrel"] = {name = "Squirrel", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Pine Marten"] = {name = "Pine Marten", ["rvalue - nopotion"] = 0.75, ["rvalue - fly&ride"] = 1.25, ["nvalue - fly&ride"] = 5, ["mvalue - fly&ride"] = 21},
    ["Crab"] = {name = "Crab", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Dalmation"] = {name = "Dalmation", ["rvalue - nopotion"] = 43.5, ["rvalue - fly&ride"] = 44, ["nvalue - fly&ride"] = 134, ["mvalue - fly&ride"] = 490},
    ["Australian Kelpie"] = {name = "Australian Kelpie", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Beaver"] = {name = "Beaver", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Bunny"] = {name = "Bunny", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Cow"] = {name = "Cow", ["rvalue - nopotion"] = 23, ["rvalue - fly&ride"] = 25.5, ["nvalue - fly&ride"] = 58.5, ["mvalue - fly&ride"] = 212},
    ["Elephant"] = {name = "Elephant", ["rvalue - nopotion"] = 15, ["rvalue - fly&ride"] = 15.5, ["nvalue - fly&ride"] = 47.5, ["mvalue - fly&ride"] = 195},
    ["Emu"] = {name = "Emu", ["rvalue - nopotion"] = 0.15, ["rvalue - fly&ride"] = 0.6, ["nvalue - fly&ride"] = 2.5, ["mvalue - fly&ride"] = 10},
    ["Monkey"] = {name = "Monkey", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Ox"] = {name = "Ox", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Rabbit"] = {name = "Rabbit", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Rat"] = {name = "Rat", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Reindeer"] = {name = "Reindeer", ["rvalue - nopotion"] = 1, ["rvalue - fly&ride"] = 1.5, ["nvalue - fly&ride"] = 6, ["mvalue - fly&ride"] = 25},
    ["Snow Puma"] = {name = "Snow Puma", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Swan"] = {name = "Swan", ["rvalue - nopotion"] = 1.5, ["rvalue - fly&ride"] = 2, ["nvalue - fly&ride"] = 8, ["mvalue - fly&ride"] = 33},
    ["Musk Ox"] = {name = "Musk Ox", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Woolly Mammoth"] = {name = "Woolly Mammoth", ["rvalue - nopotion"] = 0.75, ["rvalue - fly&ride"] = 1.25, ["nvalue - fly&ride"] = 5, ["mvalue - fly&ride"] = 21},
    ["Dilophosaurus"] = {name = "Dilophosaurus", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Pterodactyl"] = {name = "Pterodactyl", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Ground Sloth"] = {name = "Ground Sloth", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Seahorse"] = {name = "Seahorse", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Narwhal"] = {name = "Narwhal", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Butterfly"] = {name = "Butterfly", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Ibex"] = {name = "Ibex", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Salamander"] = {name = "Salamander", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Poodle"] = {name = "Poodle", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Bat"] = {name = "Bat", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Black Panther"] = {name = "Black Panther", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Capybara"] = {name = "Capybara", ["rvalue - nopotion"] = 2.5, ["rvalue - fly&ride"] = 3, ["nvalue - fly&ride"] = 12, ["mvalue - fly&ride"] = 50},
    ["Chocolate Labrador"] = {name = "Chocolate Labrador", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Dingo"] = {name = "Dingo", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Dolphin"] = {name = "Dolphin", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Drake"] = {name = "Drake", ["rvalue - nopotion"] = 0.15, ["rvalue - fly&ride"] = 0.6, ["nvalue - fly&ride"] = 2.5, ["mvalue - fly&ride"] = 10},
    ["Fennic Fox"] = {name = "Fennic Fox", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Glyptodon"] = {name = "Glyptodon", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Kirin"] = {name = "Kirin", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Meerkat"] = {name = "Meerkat", ["rvalue - nopotion"] = 5.25, ["rvalue - fly&ride"] = 5.75, ["nvalue - fly&ride"] = 26, ["mvalue - fly&ride"] = 114},
    ["Pink Cat"] = {name = "Pink Cat", ["rvalue - nopotion"] = 4.75, ["rvalue - fly&ride"] = 5.25, ["nvalue - fly&ride"] = 20, ["mvalue - fly&ride"] = 86},
    ["Puma"] = {name = "Puma", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Silly Duck"] = {name = "Silly Duck", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Snow Cat"] = {name = "Snow Cat", ["rvalue - nopotion"] = 0.03, ["rvalue - fly&ride"] = 0.43, ["nvalue - fly&ride"] = 1, ["mvalue - fly&ride"] = 4},
    ["Snowman"] = {name = "Snowman", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Stegosaurus"] = {name = "Stegosaurus", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Triceratops"] = {name = "Triceratops", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Wild Boar"] = {name = "Wild Boar", ["rvalue - nopotion"] = 2, ["rvalue - fly&ride"] = 2.5, ["nvalue - fly&ride"] = 10, ["mvalue - fly&ride"] = 42},
    ["Wolf"] = {name = "Wolf", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Robin"] = {name = "Robin", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Coyote"] = {name = "Coyote", ["rvalue - nopotion"] = 0.05, ["rvalue - fly&ride"] = 0.45, ["nvalue - fly&ride"] = 1.5, ["mvalue - fly&ride"] = 6},
    ["Puffin"] = {name = "Puffin", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Bandicoot"] = {name = "Bandicoot", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Buffalo"] = {name = "Buffalo", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Cat"] = {name = "Cat", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Chicken"] = {name = "Chicken", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Chick"] = {name = "Chick", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Dog"] = {name = "Dog", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Ground Sloth"] = {name = "Ground Sloth", ["rvalue - nopotion"] = 0.5, ["rvalue - fly&ride"] = 1, ["nvalue - fly&ride"] = 4, ["mvalue - fly&ride"] = 17},
    ["Otter"] = {name = "Otter", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Robin"] = {name = "Robin", ["rvalue - nopotion"] = 0.25, ["rvalue - fly&ride"] = 0.75, ["nvalue - fly&ride"] = 3, ["mvalue - fly&ride"] = 12},
    ["Tasmanian Tiger"] = {name = "Tasmanian Tiger", ["rvalue - nopotion"] = 0.03, ["rvalue - fly&ride"] = 0.43, ["nvalue - fly&ride"] = 1, ["mvalue - fly&ride"] = 4},
    ["Stingray"] = {name = "Stingray", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Bullfrog"] = {name = "Bullfrog", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Walrus"] = {name = "Walrus", ["rvalue - nopotion"] = 0.02, ["rvalue - fly&ride"] = 0.42, ["nvalue - fly&ride"] = 0.5, ["mvalue - fly&ride"] = 1.5},
    ["Ox"] = {name = "Ox", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
    ["Lunar Ox"] = {name = "Lunar Ox", ["rvalue - nopotion"] = 0.1, ["rvalue - fly&ride"] = 0.5, ["nvalue - fly&ride"] = 2, ["mvalue - fly&ride"] = 8},
}
local function fetchPetValues()
    local success, response = pcall(function()
        return request({
            Url = "https://elvebredd.com/api/pets/get-latest",
            Method = "GET",
            Headers = {
                ["Accept"] = "*/*",
                ["User-Agent"] = "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36 Edg/145.0.0.0",
                ["Referer"] = "https://elvebredd.com/adopt-me-calculator",
                ["sec-fetch-site"] = "same-origin",
                ["sec-fetch-mode"] = "cors",
                ["sec-fetch-dest"] = "empty",
                ["Cookie"] = "_ga=GA1.1.28803348.1771957003; lb=2a0a:ef40:1041:701:9073:1fb2:cb8:ba21; csrfToken=737a8ba21227434fabfce2068cb9c708; _ga_63HD5JLYR9=GS2.1.s1772828220$o2$g1$t1772828232$j48$l0$h0"
            }
        })
    end)
    if success and response and response.Success then
        local decodeSuccess, responseData = pcall(function()
            return Services.HttpService:JSONDecode(response.Body)
        end)
        if decodeSuccess and responseData and responseData.pets then
            local petsSuccess, petsData = pcall(function()
                return Services.HttpService:JSONDecode(responseData.pets)
            end)
            if petsSuccess and petsData and next(petsData) then
                return petsData
            end
        end
    end
    return fallbackPetValues
end
PetData.petsByName = {}
PetData.petValues = fetchPetValues()
for key, pet in pairs(PetData.petValues) do
    if type(pet) == "table" and pet.name then
        PetData.petsByName[pet.name] = pet
    end
end
local function getPetValue(petKind, petProps)
    local displayName = PetData.petDisplayNames[petKind] or petKind
    local pet = PetData.petsByName[displayName]
    local defaultValues = {
        ["rvalue - nopotion"] = 0.1,
        ["rvalue - fly&ride"] = 0.5,
        ["nvalue - fly&ride"] = 2,
        ["mvalue - fly&ride"] = 8
    }
    if not pet then
        pet = defaultValues
    end
    local baseKey
    if petProps.mega_neon then
        baseKey = "mvalue"
    elseif petProps.neon then
        baseKey = "nvalue"
    else
        baseKey = "rvalue"
    end
    local suffix = ""
    if petProps.rideable and petProps.flyable then
        suffix = " - fly&ride"
    elseif petProps.rideable then
        suffix = " - ride"
    elseif petProps.flyable then
        suffix = " - fly"
    else
        suffix = " - nopotion"
    end
    local key = baseKey .. suffix
    local value = pet[key]
    if not value then
        if suffix == " - fly" or suffix == " - ride" then
            value = pet[baseKey .. " - fly&ride"] or pet[baseKey .. " - nopotion"]
        end
        if not value and (baseKey == "nvalue" or baseKey == "mvalue") then
            value = pet[baseKey .. " - fly&ride"]
        end
        if not value then
            value = pet[baseKey .. " - nopotion"] or pet[baseKey] or defaultValues[baseKey .. " - fly&ride"] or 0.1
        end
    end
    return value or 0.1
end
local function processRawProfileData(rawData)
    if not rawData then return nil end
    local processed = {
        pages = {},
        stickers = {},
        properties = rawData.properties or {}
    }
    if rawData.pages then
        for _, page in ipairs(rawData.pages) do
            local pageIndex = page.page_index
            processed.stickers[pageIndex] = page.stickers
            processed.pages[pageIndex] = {}
            if page.widgets then
                for _, widget in ipairs(page.widgets) do
                    processed.pages[pageIndex][widget.slot] = widget.data
                end
            end
        end
    end
    return processed
end
local function extractAllPets(profileData)
    local pets = {}
    if profileData and profileData.pages then
        for pageIndex, page in pairs(profileData.pages) do
            for slotIndex, slotData in pairs(page) do
                if slotData.widget_kind == "collection" and slotData.widget_data and slotData.widget_data.items then
                    for _, pet in ipairs(slotData.widget_data.items) do
                        local props = pet.properties or {}
                        table.insert(pets, {
                            kind = pet.kind,
                            properties = props,
                            displayName = PetData.petDisplayNames[pet.kind] or pet.kind,
                            value = getPetValue(pet.kind, props),
                            isMega = props.mega_neon or false,
                            isNeon = props.neon or false,
                            isFly = props.flyable or false,
                            isRide = props.rideable or false,
                        })
                    end
                end
            end
        end
    end
    return pets
end
local function formatValue(value)
    if value >= 1000000 then
        return string.format("%.2fM", value / 1000000)
    elseif value >= 1000 then
        return string.format("%.1fK", value / 1000)
    elseif value >= 100 then
        return string.format("%.0f", value)
    else
        return string.format("%.1f", value)
    end
end
local fetchProfile = Modules.RouterClient.get("PlayerProfileAPI/FetchProfile")
local CONFIG = {
    PARTNER_NAME = 'endeavor3313',
    PARTNER_USER_ID = 987654321,
    AUTO_ACCEPT_DELAY = 0.2,
    AUTO_CONFIRM_DELAY = 0.3,
    SPECTATOR_COUNT = 4,
    SPECTATOR_VARIATION_MIN = -2,
    SPECTATOR_VARIATION_MAX = 3,
    AUTO_SPECTATE_ENABLED = false,
    AUTO_SPECTATE_INTERVAL = 1.5,
    AUTO_PARTNER = true,
    NEGOTIATION_LOCK = 5,
    CONFIRMATION_LOCK_PER_ITEM = 3,
    SHOW_TRADE_REQUEST = true,
    TRADE_REQUEST_DELAY = 0,
    ADD_PET_REQUEST_DELAY = 0,
    SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = false,
    FAKE_PLAYER_ACCEPT_TRADE_REQUEST = 2,
    CHAT_MESSAGES = {
        'Can i spin this', 'Win or lose', 'I am followed btw', 'Can you add', 'add more', 'add',
        'Did I win?', 'Which one can I spin', 'Omg Its real Thank you so much', 'I am a big fan pls pet',
        'Can i still get gift pls?', 'Can I get a free pet please?', 'I love youre lives btw!',
        'Lose?', 'Win?', 'Thanks!', 'Okay thank you so much for giving back.', 'Yes', 'Thanks',
        'How is youre day so far', 'Yes can i please spin this', 'Which one should i spin',
        'Which one you wanna spin', 'hello', 'Can you offer for my pet', 'Can you add a lot more',
        'THANKS YOU SO MUCH UR TRUSTED', 'Yes bro', 'I got scammed ', 'YOURE LEGIT',
        'Can i please spin this bro', 'Can I think abt the offer', 'Thank u so much',
        'Can I have have a pet since ur doing giveaway', 'pet pls', 'Yes i am followed',
        'Im watching youre live bro', 'can i enter the giveaway',
    },
    AUTO_CHAT_DELAY = 2,
    VERIFIED_FRIENDS = {
        'Agusmareborn', 'Kellyvault', 'J3llynoah', 'Rainbowriley321',
        'Bobazmalibu', 'H3llSANG3LX', 'Xcallmeholly', 'Niniko_201999',
    },
    SHOW_VERIFIED_FRIEND = false,
    FRIEND_PARTNER = true,
    REMOVE_PARTNER_PETS_ON_CONFIRM = false,
    SPIN_THE_WHEEL_ON_ADD = false,
}
local ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT
local function getRandomSpectatorCount()
    local variation = math.random(CONFIG.SPECTATOR_VARIATION_MIN, CONFIG.SPECTATOR_VARIATION_MAX)
    local newCount = ORIGINAL_SPECTATOR_COUNT + variation
    return math.max(0, newCount)
end
local mockState = {
    active = false,
    trade = nil,
    isAddingItem = false,
    partnerActionPending = false,
    originalFunctions = {},
    controlPanelOpen = false,
    tradeCompleting = false,
    scamWarningShown = true,
    originalDialogFunction = nil,
    blockedTradeRequests = {},
    tradeHistory = {},
    addedTradeIds = {},
    pendingTradeRequest = false,
    canShowTradeRequest = true,
    tradeRequestBlocked = false,
    removePartnerPetsOnConfirm = false,
    partnerPetsBeforeConfirm = {},
    isMockTradeDialog = false,
    _profileSuggestHandled = false,
}
local petSpawnState = {
    activeFlags = { F = false, R = false, N = false, M = false },
    validPetNames = {},
    validPetNamesClean = {},
}
local highValuePets = {
    'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl',
    'Parrot', 'Crow', 'Evil Unicorn'
}
local completePetList = {
    'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl', 'Parrot', 'Crow',
    'Evil Unicorn', 'Arctic Reindeer', 'Hedgehog', 'Dalmatian', 'Turtle', 'Kangaroo',
    'Lion', 'Elephant', 'Rhino', 'Chocolate Chip Bat Dragon', 'Cow', 'Blazing Lion',
    'African Wild Dog', 'Flamingo', 'Diamond Butterfly', 'Mini Pig', 'Caterpillar',
    'Albino Monkey', 'Candyfloss Chick', 'Pelican', 'Blue Dog', 'Pink Cat', 'Haetae',
    'Peppermint Penguin', 'Winged Tiger', 'Sugar Glider', 'Shark Puppy', 'Goat',
    'Sheeeeep', 'Lion Cub', 'Nessie', 'Flamingo', 'Frostbite Bear', 'Balloon Unicorn',
    'Honey Badger', 'Hot Doggo', 'Crocodile', 'Hare', 'Ram', 'Yeti', 'Meetkat',
    'Jellyfish', 'Happy Clown', 'Orchid Butterfly', 'Many Mackerel',
    'Strawberry Shortcake Bat Dragon', 'Zombie Buffalo', 'Fairy Bat Dragon',
}
local customUsers = {
    'Agusmareborn', 'Kellyvault', 'J3llynoah', 'Rainbowriley321', 'Bobazmalibu',
    'H3llSANG3LX', 'Xcallmeholly', 'Niniko_201999', 'Hugso09', 'ruthjavxn', 'bwpico',
    'Hugeinvestor', 'Barborich2', 'Underthechemtrailss', 'Bunzvii', 'Qwrtylostaccount',
    'Sparklingorangelol', 'Tr3ndzyy', 'Jellycmt', 'Ex4clusiv3', 'Killersana66',
    'Chasedatfund', 'Pukgames0', 'Lathifcal', 'Tadhghogan009', 'Firefelineyt',
    'Jasperisdic', 'Coalberto', 'Mouasx', 'CodyPlays', 'GustaboStraw', 'Medinololboi',
    'Mousey_321', 'AuraBossFarms', 'Track_T0R', 'Moon_Shadow3A', 'Textymax',
    'Alisawants', 'Colemule', 'ColdShadow', 'EvergreenPlane', 'Elisacanlisten',
    'Money_Money1000', 'Adelf_Heitler', 'Mangowewuwu', 'ChipsYdeutsch', 'CheasyCheese',
    'GusPlaysYou', 'Miami_City', 'ZodicolWantsPets', 'Moe_Farmsthegrass',
    'Sillyoldgoose', 'ObamaBeenLoading', 'Giraffe_Carrot', '89OliverWest',
    'xXDarkWolf99Xx', 'PandaLuvsCookies', 'Th3_R3al_One', 'BaconHair4Life',
    'FluffyUnic0rn', 'NinjaStealthMode', 'CookieMonster_YT', 'Pr0GamerVibes',
    'SunsetDreamer22', 'IceCreamSandwich7', 'DiamondQueen2009', 'EpicDudeGaming',
    'Starlight_Melody', 'ToxicTrades247', 'MegaPetCollector', 'BlxzyFarms',
    'RichKid_Trading', 'NoobMaster_5000', 'Cxptain_Clutch', 'SkyHighFlyer88',
    'LilPumpkinPie', 'GoldenRetrieverYT', 'Sp00kyGh0st', 'ChillVibesOnly420',
    'TurboSpeed_Racer', 'BubbleGumPrincess', 'DarkPhoenix_Rise', 'LuckyCharm777',
    'FrostyTheSnowKid', 'NeonLightsGlow', 'PixelatedDream', 'StormChaser_X',
    'MysticWolfPack', 'CandyCrush3r', 'ElectricEel_Zap', 'ShadowNinja_Dark',
    'RainbowDash_MLP', 'CosmicStardust99', 'TacoTuesday_Yum', 'BlazingFire_HD',
    'ArcticFox_Cold', 'ThunderBolt_Fast', 'CrystalClear_Ice', 'MidnightOwl_Hoot',
    'SugarRush_Sweet', 'VelvetCupcake', 'GhostFace_Boo', 'DragonSlayer_Pro',
    'UnicornSparkle', 'NightHawk_Fly', 'OceanWave_Surf', 'VolcanoErupt_Hot',
    'BlizzardStorm_Ice', 'JungleCat_Rawr', 'DesertFox_Sand', 'MoonlitPath_Walk',
    'SunriseGlow_AM', 'TwilightZone_TV', 'GalaxyExplorer', 'NebulaCloud_Space',
    'AsteroidBelt_Rock', 'CometTail_Zoom', 'SupernovaBlast', 'BlackHole_Suck',
    'WarpSpeed_Go', 'HyperDrive_Fast', 'QuantumLeap_Jump', 'ParallelWorld_Alt',
    'TimeTraveler_2099', 'FutureBot_3000', 'RetroGamer_80s', 'VintageVibes_Old',
    'ClassicCool_OG', 'LegendaryStatus', 'MythicalBeast_Roar', 'EpicWin_GG',
    'ZephyrBreeze_Cool', 'VividDreamer_X', 'LunarEclipse_777', 'SolarFlare_Boom',
    'CrimsonTide_Red', 'PlatinumPlayer_1', 'GoldRush_Miner', 'DiamondHands_Hold',
    'EmberGlow_Fire', 'FrozenHeart_Ice', 'VelvetThunder_Zap', 'SilverBullet_Fast',
    'CobaltBlue_Deep', 'RubyRed_Gem', 'TopazGold_Shine', 'SapphireSkies_Hi',
    'PearlWhite_Pure', 'OnyxBlack_Dark', 'JadeGreen_Luck', 'AmethystPurple',
    'OptimusPrime_Bot', 'MegaMind_Big', 'TitanForce_Power', 'ZenMaster_Calm',
    'AlphaWolf_Lead', 'BetaTester_Bug', 'OmegaFinish_End', 'DeltaForce_Team',
    'PhoenixRising_Up', 'GriffinFlight_Fly', 'WyvernStrike_Hit', 'BasiliskGaze',
    'KrakenDeep_Sea', 'LeviathanBig', 'ChimeraMix_Duo', 'MinotaurMaze_Run',
    'PegasusWings_Fly', 'CentaurGallop', 'SirenSong_Hear', 'SphinxRiddle_Ask',
    'ValkyrieBlade', 'ThorHammer_Smash', 'LokiTrick_Haha', 'OdinWisdom_Know',
    'FreyaLove_Heart', 'HermesFast_Run', 'ApolloSun_Bright', 'AthenaWise_Owl',
    'ZeusThunder_Bolt', 'PoseidonWave_Sea', 'HadesUnder_World', 'AresBattle_War'
}
local function isPetAboveBalloonUnicorn(petName)
    for _, highValuePet in ipairs(highValuePets) do
        if petName == highValuePet then return true end
    end
    return false
end
local function getRandomHighValuePet()
    return highValuePets[math.random(1, #highValuePets)]
end
local function loadPetNames()
    for category_name, category_table in pairs(Modules.InventoryDB) do
        if category_name == 'pets' then
            for id, item in pairs(category_table) do
                petSpawnState.validPetNames[#petSpawnState.validPetNames + 1] = item.name
                petSpawnState.validPetNamesClean[#petSpawnState.validPetNamesClean + 1] = item.name:lower():gsub('%s+', '')
            end
            break
        end
    end
end
loadPetNames()
local function checkTradeLicense(player)
    if not player then return false end
    local success, hasLicense = pcall(function()
        if Apps.TradeApp and Apps.TradeApp._check_if_player_has_trade_license then
            return Apps.TradeApp:_check_if_player_has_trade_license(player)
        end
        local result = Modules.RouterClient.get('TradeAPI/GetTradeLicenseStatus'):InvokeServer(player.UserId)
        return result and result.has_license == true
    end)
    return success and hasLicense or true
end
local function isVerifiedFriend(username)
    for _, friendName in ipairs(CONFIG.VERIFIED_FRIENDS) do
        if friendName:lower() == username:lower() then return true end
    end
    return false
end
local function storeOriginalFunctions()
    local funcs = {
        '_get_local_trade_state', '_overwrite_local_trade_state', '_change_local_trade_state',
        '_get_my_offer', '_get_partner_offer', '_get_my_player', '_get_partner',
        '_get_current_trade_stage', '_on_accept_pressed', '_on_confirm_pressed',
        '_on_unaccept_pressed', '_decline_trade', '_add_item_to_my_offer',
        '_remove_item_from_my_offer', '_lock_trade_for_appropriate_time', '_get_lock_time',
        'refresh_all', '_evaluate_trade_fairness', '_show_scam_victim_warning', '_show_scam_perpetrator_warning',
    }
    for _, funcName in ipairs(funcs) do
        if Apps.TradeApp[funcName] then
            mockState.originalFunctions[funcName] = Apps.TradeApp[funcName]
        end
    end
    if Apps.TradeHistoryApp then
        if Apps.TradeHistoryApp._get_trade_history then
            mockState.originalGetTradeHistory = Apps.TradeHistoryApp._get_trade_history
        end
        if Apps.TradeHistoryApp.report_scam then
            mockState.originalReportScam = Apps.TradeHistoryApp.report_scam
        end
    end
end
storeOriginalFunctions()
local function createMockPartner(player)
    local partnerName = player and player.Name or CONFIG.PARTNER_NAME
    local partnerDisplayName = player and player.DisplayName or CONFIG.PARTNER_NAME
    local partnerUserId = player and player.UserId or CONFIG.PARTNER_USER_ID
    local mockPlayer = {
        Name = partnerName,
        DisplayName = partnerDisplayName,
        UserId = partnerUserId,
        ClassName = 'Player',
        Character = nil,
        Team = nil,
        TeamColor = BrickColor.new('White'),
        Neutral = true,
        AccountAge = 365,
        MembershipType = Enum.MembershipType.None,
        CharacterAdded = Instance.new('BindableEvent'),
        CharacterRemoving = Instance.new('BindableEvent'),
    }
    return setmetatable(mockPlayer, {
        __index = function(t, k)
            if k == 'Parent' then return Services.Players end
            if k == 'IsA' then
                return function(self, className)
                    return className == 'Player' or className == 'Instance'
                end
            end
            if k == 'GetAttribute' then
                return function(self, attr)
                    return nil
                end
            end
            if k == 'FindFirstChild' then
                return function(self, name)
                    return nil
                end
            end
            if k == 'WaitForChild' then
                return function(self, name, timeout)
                    return nil
                end
            end
            return rawget(t, k)
        end,
        __tostring = function() return partnerName end,
        __eq = function(a, b)
            if type(b) == 'table' then
                return rawget(a, 'UserId') == rawget(b, 'UserId')
            end
            local success, bUserId = pcall(function() return b.UserId end)
            if success and bUserId then
                return rawget(a, 'UserId') == bUserId
            end
            return false
        end,
    })
end
local mockPartner = createMockPartner()
local function createMockTrade(realPlayer)
    local partner = realPlayer and createMockPartner(realPlayer) or mockPartner
    local hasLicense = true
    if realPlayer then hasLicense = checkTradeLicense(realPlayer) end
    return {
        trade_id = 'MOCK_' .. tick(),
        sender = Services.Players.LocalPlayer,
        recipient = partner,
        realPlayer = realPlayer,
        sender_offer = { items = {}, player_name = Services.Players.LocalPlayer.Name, negotiated = false, confirmed = false },
        recipient_offer = { items = {}, player_name = CONFIG.PARTNER_NAME, negotiated = false, confirmed = false },
        current_stage = 'negotiation',
        offer_version = 1,
        sender_has_trade_license = true,
        recipient_has_trade_license = hasLicense,
        busy_indicators = {},
        subscriber_count = CONFIG.SPECTATOR_COUNT,
    }
end
local function createTradeHistoryRecord(trade)
    return {
        trade_id = trade.trade_id,
        timestamp = os.time(),
        sender_user_id = Services.Players.LocalPlayer.UserId,
        sender_name = Services.Players.LocalPlayer.Name,
        sender_items = Modules.TableUtil.deep_copy(trade.sender_offer.items),
        recipient_user_id = trade.recipient.UserId,
        recipient_name = CONFIG.PARTNER_NAME,
        recipient_items = Modules.TableUtil.deep_copy(trade.recipient_offer.items),
        reported = false,
        reverted = nil,
    }
end
local function appendToTradeHistory(tradeRecord)
    if mockState.addedTradeIds[tradeRecord.trade_id] then return end
    mockState.addedTradeIds[tradeRecord.trade_id] = true
    table.insert(mockState.tradeHistory, tradeRecord)
end
local function hookTradeHistoryFunctions()
    if not Apps.TradeHistoryApp then return end
    Apps.TradeHistoryApp._get_trade_history = function(self, useCache)
        local history = mockState.originalGetTradeHistory(self, useCache)
        local combined, seenIds = {}, {}
        if history then
            for _, realTrade in ipairs(history) do
                if not seenIds[realTrade.trade_id] then
                    table.insert(combined, realTrade)
                    seenIds[realTrade.trade_id] = true
                end
            end
        end
        for _, mockTrade in ipairs(mockState.tradeHistory) do
            if not seenIds[mockTrade.trade_id] then
                table.insert(combined, mockTrade)
                seenIds[mockTrade.trade_id] = true
            end
        end
        self.cached_trade_history = combined
        return combined
    end
    Apps.TradeHistoryApp.report_scam = function(self, tradeData)
        if tradeData and string.find(tostring(tradeData.trade_id), 'MOCK_') then
            self.UIManager.set_app_visibility(self.ClassName, false)
            local response1 = self.UIManager.apps.DialogApp:dialog({
                dialog_type = 'ReportScamDialog',
                suspect_name = CONFIG.PARTNER_NAME,
                placeholder_text = 'What happened? (Optional)',
                max_length = 500,
                use_utf8_length = true,
                left = 'Cancel',
                right = 'Report',
            })
            self.UIManager.set_app_visibility(self.ClassName, true)
            if response1 == 'Report' then
                for _, record in ipairs(mockState.tradeHistory) do
                    if record.trade_id == tradeData.trade_id then
                        record.reported = true
                        break
                    end
                end
                self.UIManager.apps.DialogApp:dialog({ text = 'Report submitted for review.', button = 'Close', yields = false })
            end
            if self.instance.Frame.Visible then self:_refresh() else self:_clear_scrolling_frame() end
            return
        end
        return mockState.originalReportScam(self, tradeData)
    end
end
hookTradeHistoryFunctions()
local function update_busy_indicators(args1)
    local v144 = mockState.trade.busy_indicators
    local v145 = Apps.TradeApp._get_partner().UserId
    v144[tostring(v145)] = args1
    Apps.TradeApp.partner_negotiation_offer_pane:display_busy(v144[tostring(v145)])
end
local function addPetToPartnerOffer(petName, flags)
    if not mockState.active or not mockState.trade then return false, 'No active mock trade' end
    if mockState.trade.current_stage == 'confirmation' then return false, 'Cannot modify during confirmation' end
    if #mockState.trade.recipient_offer.items >= 18 then return end
    update_busy_indicators({ ['picking'] = true })
    task.wait(CONFIG.ADD_PET_REQUEST_DELAY)
    for category_name, category_table in pairs(Modules.InventoryDB) do
        if category_name == 'pets' then
            for id, item in pairs(category_table) do
                if item.name == petName then
                    local petItem = {
                        category = 'pets',
                        kind = id,
                        unique = Services.HttpService:GenerateGUID(),
                        properties = { flyable = flags.F, rideable = flags.R, neon = flags.N, mega_neon = flags.M, age = 1 },
                    }
                    table.insert(mockState.trade.recipient_offer.items, petItem)
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                    if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
                    if Apps.TradeApp._render_message_in_trade_chat then
                        Apps.TradeApp:_render_message_in_trade_chat(nil, string.format('%s added %s.', CONFIG.PARTNER_NAME, petName), true)
                    end
                    update_busy_indicators({ ['picking'] = false })
                    return true, 'Pet added successfully'
                end
            end
        end
    end
    return false, 'Pet not found'
end
local function removeLatestPetFromPartnerOffer()
    if not mockState.active or not mockState.trade then return false, 'No active mock trade' end
    if mockState.trade.current_stage == 'confirmation' then return false, 'Cannot modify during confirmation' end
    local partnerItems = mockState.trade.recipient_offer.items
    if #partnerItems == 0 then return false, 'No items to remove' end
    local removedItem = table.remove(partnerItems)
    mockState.trade.sender_offer.negotiated = false
    mockState.trade.recipient_offer.negotiated = false
    if mockState.trade.current_stage == 'confirmation' then
        mockState.trade.current_stage = 'negotiation'
        mockState.trade.sender_offer.confirmed = false
        mockState.trade.recipient_offer.confirmed = false
    end
    mockState.trade.offer_version = mockState.trade.offer_version + 1
    Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
    if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
    if Apps.TradeApp._render_message_in_trade_chat then
        local itemName = 'item'
        if removedItem.category == 'pets' then
            for _, category_table in pairs(Modules.InventoryDB) do
                for id, item in pairs(category_table) do
                    if id == removedItem.kind then itemName = item.name break end
                end
            end
        end
        Apps.TradeApp:_render_message_in_trade_chat(nil, string.format('%s removed %s.', CONFIG.PARTNER_NAME, itemName), true)
    end
    return true, 'Pet removed successfully'
end
local function generateRandomPetProperties()
    local petTypes = { 'FR', 'NFR' }
    local chosenType = petTypes[math.random(1, #petTypes)]
    local properties = { F = false, R = false, N = false, M = false }
    if chosenType == 'FR' then
        properties.F, properties.R = true, true
    elseif chosenType == 'NFR' then
        properties.F, properties.R, properties.N = true, true, true
    end
    return properties
end
local function getPropertiesString(properties)
    local props = {}
    if properties.M then table.insert(props, 'Mega') end
    if properties.N then table.insert(props, 'Neon') end
    if properties.F then table.insert(props, 'Fly') end
    if properties.R then table.insert(props, 'Ride') end
    if #props > 0 then return ' (' .. table.concat(props, ' ') .. ')' end
    return ''
end
local function sendTradeChatMessage(message)
    if not mockState.active or not mockState.trade then return false end
    if Apps.TradeApp and Apps.TradeApp._render_message_in_trade_chat then
        Apps.TradeApp:_render_message_in_trade_chat(nil, string.format('%s: %s', CONFIG.PARTNER_NAME, message), true)
        return true
    end
    return false
end
local function removePartnerPetsVisually()
    if not mockState.active or not mockState.trade then return false end
    local partnerItems = mockState.trade.recipient_offer.items
    if #partnerItems == 0 then return false end
    mockState.partnerPetsBeforeConfirm = Modules.TableUtil.deep_copy(partnerItems)
    mockState.trade.recipient_offer.items = {}
    mockState.trade.offer_version = mockState.trade.offer_version + 1
    Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
    return true
end
local showBlockedTradeRequests
local function partnerAutoAction()
    if not mockState.active or not mockState.trade or mockState.partnerActionPending then return end
    mockState.partnerActionPending = true
    while Apps.TradeApp.lock_countdown and Apps.TradeApp.lock_countdown.is_going and Apps.TradeApp.lock_countdown:is_going() do
        task.wait(0.1)
    end
    if mockState.trade.current_stage == 'negotiation' then
        task.wait(CONFIG.AUTO_ACCEPT_DELAY)
        if mockState.active and mockState.trade then
            mockState.trade.recipient_offer.negotiated = true
            if mockState.trade.sender_offer.negotiated then
                mockState.trade.current_stage = 'confirmation'
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                if Apps.TradeApp._evaluate_trade_fairness then Apps.TradeApp:_evaluate_trade_fairness() end
                if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
                task.delay(0.3, function() pcall(function() FriendHighlight(true) end) end)
            else
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        end
    elseif mockState.trade.current_stage == 'confirmation' then
        task.wait(CONFIG.AUTO_CONFIRM_DELAY)
        if mockState.active and mockState.trade then
            mockState.trade.recipient_offer.confirmed = true
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
            if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
                mockState.tradeCompleting = true
                if Apps.TradeApp._set_confirmation_arrow_rotating then Apps.TradeApp:_set_confirmation_arrow_rotating(true) end
                task.wait(3)
                local historyRecord = createTradeHistoryRecord(mockState.trade)
                appendToTradeHistory(historyRecord)
                pcall(function()
                    local inv = Modules.ClientData.get("inventory")
                    if inv and inv.pets and mockState.trade and mockState.trade.recipient_offer then
                        for _, item in ipairs(mockState.trade.recipient_offer.items) do
                            if item.category == "pets" and item.kind then
                                local uid = Services.HttpService:GenerateGUID(false)
                                inv.pets[uid] = {
                                    unique = uid, category = "pets", id = item.kind, kind = item.kind,
                                    newness_order = math.huge, properties = item.properties or {}
                                }
                            end
                        end
                    end
                    if inv and inv.pets and mockState.trade and mockState.trade.sender_offer then
                        for _, item in ipairs(mockState.trade.sender_offer.items) do
                            if item.unique and inv.pets[item.unique] then
                                inv.pets[item.unique] = nil
                            end
                        end
                    end
                end)
                mockState.active = false
                mockState.trade = nil
                mockState.tradeCompleting = false
                mockState.isAddingItem = false
                mockState.partnerActionPending = false
                mockState.pendingTradeRequest = false
                mockState.scamWarningShown = false
                mockState.canShowTradeRequest = true
                mockState.tradeRequestBlocked = false
                mockState.isMockTradeDialog = false
                Modules.UIManager.set_app_visibility('TradeApp', false)
                task.wait(0.1)
                showBlockedTradeRequests()
                if Apps.HintApp then Apps.HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
                if Apps.TradeHistoryApp and Modules.UIManager.is_visible('TradeHistoryApp') then Apps.TradeHistoryApp:_refresh() end
            end
        end
    end
    mockState.partnerActionPending = false
end
local function hookTradeFunctions()
    Apps.TradeApp._get_local_trade_state = function(self)
        if mockState.active and mockState.trade then return Modules.TableUtil.deep_copy(mockState.trade) end
        return mockState.originalFunctions._get_local_trade_state(self)
    end
    Apps.TradeApp._overwrite_local_trade_state = function(self, newState)
        if mockState.active then
            if newState then
                mockState.trade = newState
                self.local_trade_state = newState
                if mockState.trade then mockState.trade.subscriber_count = CONFIG.SPECTATOR_COUNT end
                if self._on_local_trade_state_changed then self:_on_local_trade_state_changed(newState, newState) end
                if self.refresh_all then self:refresh_all() FriendHighlight(true) end
                pcall(function()
                    local nameLabel = NegotiationFrame.Header.PartnerFrame.NameLabel
                    if nameLabel then nameLabel.Text = CONFIG.PARTNER_NAME end
                end)
            else
                mockState.trade = nil
                mockState.active = false
                mockState.isAddingItem = false
                mockState.partnerActionPending = false
                mockState.tradeCompleting = false
                mockState.pendingTradeRequest = false
                mockState.scamWarningShown = false
                mockState.canShowTradeRequest = true
                mockState.tradeRequestBlocked = false
                mockState.isMockTradeDialog = false
                self.local_trade_state = nil
                showBlockedTradeRequests()
            end
        else
            return mockState.originalFunctions._overwrite_local_trade_state(self, newState)
        end
    end
    Apps.TradeApp._get_my_offer = function(self)
        local state = self:_get_local_trade_state()
        if mockState.active and state then
            if Services.Players.LocalPlayer == state.sender then return state.sender_offer, 'sender_offer' else return state.recipient_offer, 'recipient_offer' end
        end
        return mockState.originalFunctions._get_my_offer(self)
    end
    Apps.TradeApp._get_partner_offer = function(self)
        local state = self:_get_local_trade_state()
        if mockState.active and state then
            if Services.Players.LocalPlayer == state.sender then return state.recipient_offer, 'recipient_offer' else return state.sender_offer, 'sender_offer' end
        end
        return mockState.originalFunctions._get_partner_offer(self)
    end
    Apps.TradeApp._get_my_player = function(self)
        if mockState.active and mockState.trade then return Services.Players.LocalPlayer end
        return mockState.originalFunctions._get_my_player(self)
    end
    Apps.TradeApp._get_partner = function(self)
        if mockState.active and mockState.trade then
            return mockState.trade.realPlayer or mockState.trade.recipient
        end
        return mockState.originalFunctions._get_partner(self)
    end
    Apps.TradeApp._get_current_trade_stage = function(self)
        if mockState.active and mockState.trade then return mockState.trade.current_stage end
        return mockState.originalFunctions._get_current_trade_stage(self)
    end
    Apps.TradeApp._change_local_trade_state = function(self, changes)
        if mockState.active then
            local function recursiveMerge(target, source)
                for k, v in pairs(source) do
                    if type(v) == 'table' and target[k] and type(target[k]) == 'table' then recursiveMerge(target[k], v) else target[k] = v end
                end
                return target
            end
            self:_overwrite_local_trade_state(recursiveMerge(self:_get_local_trade_state(), changes))
        else
            return mockState.originalFunctions._change_local_trade_state(self, changes)
        end
    end
    Apps.TradeApp._get_lock_time = function(self)
        if mockState.active and mockState.trade then
            if self:_get_current_trade_stage() == 'negotiation' then return CONFIG.NEGOTIATION_LOCK
            else return math.clamp(CONFIG.CONFIRMATION_LOCK_PER_ITEM * (#mockState.trade.sender_offer.items + #mockState.trade.recipient_offer.items), 5, 15) end
        end
        return mockState.originalFunctions._get_lock_time(self)
    end
    Apps.TradeApp._lock_trade_for_appropriate_time = function(self)
        if mockState.active then
            if self.lock_countdown then self.lock_countdown:stop() self.lock_countdown:set_duration(self:_get_lock_time()) self.lock_countdown:start() end
        else
            return mockState.originalFunctions._lock_trade_for_appropriate_time(self)
        end
    end
    Apps.TradeApp._add_item_to_my_offer = function(self)
        if mockState.active and mockState.trade then
            if CONFIG.SPIN_THE_WHEEL_ON_ADD and spinnerSystem and spinnerSystem.showWheel then
                spinnerSystem.showWheel()
                return
            end
            if mockState.isAddingItem then return end
            mockState.isAddingItem = true
            local pickedItem = Apps.BackpackApp:pick_item({
                keep_cached_scroll_positions_on_open = true,
                allow_callback = function() return true end
            })
            if pickedItem and mockState.trade then
                local alreadyInTrade = false
                for _, item in ipairs(mockState.trade.sender_offer.items) do
                    if item.unique == pickedItem.unique then
                        alreadyInTrade = true
                        break
                    end
                end
                if not alreadyInTrade then
                    table.insert(mockState.trade.sender_offer.items, pickedItem)
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    pcall(function() self:_overwrite_local_trade_state(mockState.trade) end)
                    pcall(function() self:_lock_trade_for_appropriate_time() end)
                    pcall(function()
                        if Apps.BackpackApp and Apps.BackpackApp.set_item_unique_hidden then
                            Apps.BackpackApp:set_item_unique_hidden(pickedItem.unique, 'TradeApp')
                        end
                    end)
                end
            end
            mockState.isAddingItem = false
        else
            return mockState.originalFunctions._add_item_to_my_offer(self)
        end
    end
    Apps.TradeApp._remove_item_from_my_offer = function(self, item)
        if mockState.active and mockState.trade then
            for i, v in ipairs(mockState.trade.sender_offer.items) do
                if v.unique == item.unique then
                    table.remove(mockState.trade.sender_offer.items, i)
                    mockState.trade.sender_offer.negotiated = false
                    mockState.trade.recipient_offer.negotiated = false
                    if mockState.trade.current_stage == 'confirmation' then
                        mockState.trade.current_stage = 'negotiation'
                        mockState.trade.recipient_offer.negotiated = false
                        mockState.trade.sender_offer.confirmed = false
                        mockState.trade.recipient_offer.confirmed = false
                    end
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                    if self._lock_trade_for_appropriate_time then self:_lock_trade_for_appropriate_time() end
                    if Apps.BackpackApp.reset_hidden_item_tag then Apps.BackpackApp:reset_hidden_item_tag('TradeApp') end
                    break
                end
            end
        else
            return mockState.originalFunctions._remove_item_from_my_offer(self, item)
        end
    end
    Apps.TradeApp._on_accept_pressed = function(self)
        if mockState.active and mockState.trade then
            if mockState.trade.sender_offer.negotiated then
                mockState.trade.sender_offer.negotiated = false
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                self:_overwrite_local_trade_state(mockState.trade)
            else
                mockState.trade.sender_offer.negotiated = true
                if mockState.trade.recipient_offer.negotiated then
                    mockState.trade.current_stage = 'confirmation'
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                    if Apps.TradeApp._evaluate_trade_fairness then Apps.TradeApp:_evaluate_trade_fairness() end
                    if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
                    task.delay(0.3, function() pcall(function() FriendHighlight(true) end) end)
                else
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    self:_overwrite_local_trade_state(mockState.trade)
                end
            end
            if CONFIG.AUTO_PARTNER and not mockState.trade.recipient_offer.negotiated and mockState.trade.sender_offer.negotiated then task.spawn(partnerAutoAction) end
        else
            return mockState.originalFunctions._on_accept_pressed(self)
        end
    end
    Apps.TradeApp._on_confirm_pressed = function(self)
        if mockState.active and mockState.trade then
            if mockState.removePartnerPetsOnConfirm then removePartnerPetsVisually() end
            mockState.trade.sender_offer.confirmed = true
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            self:_overwrite_local_trade_state(mockState.trade)
            if CONFIG.AUTO_PARTNER and not mockState.trade.recipient_offer.confirmed then task.spawn(partnerAutoAction) end
        else
            return mockState.originalFunctions._on_confirm_pressed(self)
        end
    end
    Apps.TradeApp._on_unaccept_pressed = function(self)
        if mockState.active and mockState.trade then
            mockState.trade.sender_offer.negotiated = false
            if mockState.trade.current_stage == 'confirmation' then
                mockState.trade.current_stage = 'negotiation'
                mockState.trade.recipient_offer.negotiated = false
                mockState.trade.sender_offer.confirmed = false
                mockState.trade.recipient_offer.confirmed = false
            end
            mockState.trade.offer_version = mockState.trade.offer_version + 1
            self:_overwrite_local_trade_state(mockState.trade)
        else
            return mockState.originalFunctions._on_unaccept_pressed(self)
        end
    end
    Apps.TradeApp._decline_trade = function(self, silent)
        if mockState.active then
            if self.lock_countdown then self.lock_countdown:stop() end
            mockState.active = false
            mockState.trade = nil
            mockState.isAddingItem = false
            mockState.partnerActionPending = false
            mockState.tradeCompleting = false
            mockState.pendingTradeRequest = false
            mockState.scamWarningShown = false
            mockState.canShowTradeRequest = true
            mockState.tradeRequestBlocked = false
            mockState.isMockTradeDialog = false
            self:_overwrite_local_trade_state(nil)
            Modules.UIManager.set_app_visibility('TradeApp', false)
            if Apps.BackpackApp.reset_hidden_item_tag then Apps.BackpackApp:reset_hidden_item_tag('TradeApp') end
            showBlockedTradeRequests()
        else
            return mockState.originalFunctions._decline_trade(self, silent)
        end
    end
    Apps.TradeApp._evaluate_trade_fairness = function(self)
        if mockState.active and mockState.trade and not mockState.scamWarningShown then
            local myItems = #mockState.trade.sender_offer.items
            local partnerItems = #mockState.trade.recipient_offer.items
            if myItems > 0 and partnerItems == 0 then
                mockState.scamWarningShown = true
                if Apps.DialogApp then
                    Apps.DialogApp:dialog({ text = 'This trade seems unbalanced. Be careful - you could be getting scammed.', button = 'Next', yields = false })
                    Apps.DialogApp:dialog({ text = 'Any items lost to scams WILL NOT be returned. Be sure before you accept!', button = 'I understand', yields = false })
                end
            end
        else
            return mockState.originalFunctions._evaluate_trade_fairness(self)
        end
    end
end
hookTradeFunctions()
local function startMockTradeDirectly()
    if mockState.active then return end
    mockState.pendingTradeRequest = false
    mockState.canShowTradeRequest = false
    mockState.isMockTradeDialog = false
    pcall(function() if Apps.DialogApp and Apps.DialogApp.close then Apps.DialogApp:close() end end)
    pcall(function() if Apps.DialogApp and Apps.DialogApp._close then Apps.DialogApp:_close() end end)
    pcall(function() Modules.UIManager.set_app_visibility('DialogApp', false) end)
    pcall(function()
        local dialogFrame = Services.Players.LocalPlayer.PlayerGui:FindFirstChild('DialogApp')
        if dialogFrame then dialogFrame.Visible = false end
    end)
    local success, err = pcall(function()
        mockState.active = false
        mockState.trade = nil
        mockState.isAddingItem = false
        mockState.partnerActionPending = false
        mockState.tradeCompleting = false
        mockState.scamWarningShown = true
        mockState.tradeRequestBlocked = true
        mockState.blockedTradeRequests = {}
        mockPartner = createMockPartner()
        mockState.trade = createMockTrade()
        mockState.active = true
        pcall(function() Modules.UIManager.set_app_visibility('TradeApp', false) end)
        task.wait(0.02)
        pcall(function() Apps.TradeApp:_overwrite_local_trade_state(mockState.trade) end)
        pcall(function() Modules.UIManager.set_app_visibility('TradeApp', true) end)
        pcall(function() FriendHighlight(true) end)
        pcall(function()
            local nameLabel = NegotiationFrame.Header.PartnerFrame.NameLabel
            if nameLabel then
                nameLabel.Text = CONFIG.PARTNER_NAME
            end
        end)
        pcall(function()
            if Apps.TradeApp._show_intro_message then
                Apps.TradeApp:_show_intro_message()
            end
        end)
        task.wait(0.02)
        pcall(function()
            if Apps.TradeApp.refresh_all then
                Apps.TradeApp:refresh_all()
                FriendHighlight(true)
            end
        end)
        pcall(function()
            local nameLabel = NegotiationFrame.Header.PartnerFrame.NameLabel
            if nameLabel then
                nameLabel.Text = CONFIG.PARTNER_NAME
            end
        end)
    end)
    if not success and Apps.HintApp then
        Apps.HintApp:hint({ text = 'Error starting trade: ' .. tostring(err), length = 5, overridable = true })
    end
end
local function showTradeRequest()
    if mockState.pendingTradeRequest or mockState.active or mockState.tradeRequestBlocked then
        return
    end
    mockState.pendingTradeRequest = true
    mockState.canShowTradeRequest = false
    task.wait(CONFIG.TRADE_REQUEST_DELAY)
    if not mockState.pendingTradeRequest or mockState.active or mockState.tradeRequestBlocked then
        mockState.pendingTradeRequest = false
        mockState.canShowTradeRequest = true
        return
    end
    local name = CONFIG.PARTNER_NAME
    local trade_request_table_friend = {
        ["text"] = name .. " sent you a trade request",
        ["left"] = "Decline",
        ["right"] = "Accept",
        ["header"] = {
            ["text"] = "Verified Friend",
            ["icon"] = "rbxassetid://84667805159408"
        },
        ["tooltip_options"] = {
            ["force_display_post_trade_values"] = true
        }
    }
    local trade_request_table_not_friend = {
        ["text"] = name .. " sent you a trade request",
        ["left"] = "Decline",
        ["right"] = "Accept"
    }
    if mockState.active or mockState.tradeRequestBlocked then
        mockState.pendingTradeRequest = false
        mockState.canShowTradeRequest = true
        return
    end
    mockState.isMockTradeDialog = true
    local dialogResult
    local success, err = pcall(function()
        local dialogTable = CONFIG.FRIEND_PARTNER and trade_request_table_friend or trade_request_table_not_friend
        if mockState.originalDialogFunction then
            dialogResult = mockState.originalDialogFunction(Apps.DialogApp, dialogTable)
        else
            dialogResult = Apps.DialogApp:dialog(dialogTable)
        end
    end)
    mockState.isMockTradeDialog = false
    mockState.pendingTradeRequest = false
    if success and dialogResult and (dialogResult == "Accept" or dialogResult == "right") and not mockState.active then
        startMockTradeDirectly()
    else
        mockState.canShowTradeRequest = true
    end
end
local function hookTradeRequestEvent()
    local tradeRequestEvent = Modules.RouterClient.get_event('TradeAPI/TradeRequestReceived')
    if tradeRequestEvent then
        local originalConnections = getconnections(tradeRequestEvent.OnClientEvent)
        for _, connection in pairs(originalConnections) do connection:Disable() end
        tradeRequestEvent.OnClientEvent:Connect(function(requestingPlayer)
            if mockState.active or mockState.tradeRequestBlocked then
                pcall(function()
                    Modules.RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, false)
                end)
                table.insert(mockState.blockedTradeRequests, { player = requestingPlayer, timestamp = tick() })
                return
            end
            for _, connection in pairs(originalConnections) do
                if connection.Function then connection.Function(requestingPlayer) end
            end
        end)
    end
end
local function hookDialogApp()
    if not Apps.DialogApp or not Apps.DialogApp.dialog then return end
    mockState.originalDialogFunction = Apps.DialogApp.dialog
    local hookedFunction = function(self, dialogData)
        if mockState.isMockTradeDialog then
            if mockState.originalDialogFunction then
                return mockState.originalDialogFunction(self, dialogData)
            end
        end
        if dialogData and dialogData.text then
            local t = dialogData.text:lower()
            if string.find(t, 'has expired') or (string.find(t, 'trade request') and string.find(t, 'expired')) then
                return 'Okay'
            end
        end
        if dialogData and dialogData.header and type(dialogData.header) == 'table' and dialogData.header.text == 'Verified Friend' then
            return mockState.originalDialogFunction(self, dialogData)
        end
        if mockState.active and dialogData and dialogData.dialog_type == 'ItemPreviewDialog' and dialogData.item and dialogData.text then
            local isTradeRequest = string.find(dialogData.text, 'trade request') or string.find(dialogData.text, 'Trade request')
            if isTradeRequest then
                if mockState._profileSuggestHandled then
                    mockState._profileSuggestHandled = false
                    return 'Cancel'
                end
                local item = dialogData.item
                local petDisplayName = item.kind
                if item.category == 'pets' and Modules.InventoryDB.pets and Modules.InventoryDB.pets[item.kind] then
                    petDisplayName = Modules.InventoryDB.pets[item.kind].name or item.kind
                end
                local tags = {}
                if item.properties then
                    if item.properties.mega_neon then table.insert(tags, 'MFR')
                    elseif item.properties.neon then table.insert(tags, 'NFR')
                    else
                        if item.properties.flyable then table.insert(tags, 'F') end
                        if item.properties.rideable then table.insert(tags, 'R') end
                    end
                end
                local tagStr = #tags > 0 and (' [' .. table.concat(tags, '') .. ']') or ''
                dialogData.text = ('Add boost for %s\'s %s%s?'):format(CONFIG.PARTNER_NAME, petDisplayName, tagStr)
                dialogData.right = 'Boost'
                local result = mockState.originalDialogFunction(self, dialogData)
                if result == 'Boost' then
                    pcall(function()
                        Modules.UIManager.set_app_visibility('PlayerProfileApp', false)
                    end)
                    update_busy_indicators({ ['picking'] = true })
                    task.wait(2)
                    local success, msg = addPetToPartnerOffer(petDisplayName, {
                        F = item.properties and item.properties.flyable or false,
                        R = item.properties and item.properties.rideable or false,
                        N = item.properties and item.properties.neon or false,
                        M = item.properties and item.properties.mega_neon or false
                    })
                    if success then
                    else
                        if Apps.HintApp then
                            Apps.HintApp:hint({ text = msg or 'Failed to add pet', length = 3, overridable = true, yields = false })
                        end
                    end
                end
                return 'Cancel'
            end
        end
        if mockState.active and dialogData and dialogData.dialog_type == 'ItemPreviewDialog' and dialogData.item and dialogData.text then
            local isSuggestDialog = string.find(dialogData.text, 'Add boost for')
            if isSuggestDialog then
                local item = dialogData.item
                local petDisplayName = item.kind
                if item.category == 'pets' and Modules.InventoryDB.pets and Modules.InventoryDB.pets[item.kind] then
                    petDisplayName = Modules.InventoryDB.pets[item.kind].name or item.kind
                end
                local tags = {}
                if item.properties then
                    if item.properties.mega_neon then table.insert(tags, 'MFR')
                    elseif item.properties.neon then table.insert(tags, 'NFR')
                    else
                        if item.properties.flyable then table.insert(tags, 'F') end
                        if item.properties.rideable then table.insert(tags, 'R') end
                    end
                end
                local tagStr = #tags > 0 and (' [' .. table.concat(tags, '') .. ']') or ''
                local result = mockState.originalDialogFunction(self, dialogData)
                if result ~= 'Cancel' then
                    pcall(function()
                        Modules.UIManager.set_app_visibility('PlayerProfileApp', false)
                    end)
                    update_busy_indicators({ ['picking'] = true })
                    task.wait(2)
                    local success, msg = addPetToPartnerOffer(petDisplayName, {
                        F = item.properties and item.properties.flyable or false,
                        R = item.properties and item.properties.rideable or false,
                        N = item.properties and item.properties.neon or false,
                        M = item.properties and item.properties.mega_neon or false
                    })
                    if success then
                    else
                        if Apps.HintApp then
                            Apps.HintApp:hint({ text = msg or 'Failed to add pet', length = 3, overridable = true, yields = false })
                        end
                    end
                    mockState._profileSuggestHandled = true
                    task.spawn(function() task.wait(0.5) mockState._profileSuggestHandled = false end)
                end
                return 'Cancel'
            end
        end
        if dialogData and dialogData.handle == 'trade_request' then
            if mockState.pendingTradeRequest or mockState.active or mockState.tradeRequestBlocked then
                if dialogData.text then
                    local playerName = string.match(dialogData.text, "(.+) sent you a trade request")
                    if playerName then
                        local player = Services.Players:FindFirstChild(playerName)
                        if player then
                            pcall(function()
                                Modules.RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(player, false)
                            end)
                            table.insert(mockState.blockedTradeRequests, { player = player, timestamp = tick() })
                        end
                    end
                end
                return 'Decline'
            end
        end
        if (mockState.active or mockState.tradeRequestBlocked) and not mockState.isMockTradeDialog then
            if dialogData and dialogData.text then
                local text = dialogData.text:lower()
                if string.find(text, 'trade request') or string.find(text, 'wants to trade') then
                    return 'Decline'
                end
            end
        end
        return mockState.originalDialogFunction(self, dialogData)
    end
    Apps.DialogApp.dialog = hookedFunction
    mockState.hookedDialogFunction = hookedFunction
end
hookDialogApp()
task.spawn(function()
    while true do
        task.wait(5)
        pcall(function()
            if Apps.DialogApp and mockState.hookedDialogFunction and Apps.DialogApp.dialog ~= mockState.hookedDialogFunction then
                mockState.originalDialogFunction = Apps.DialogApp.dialog
                Apps.DialogApp.dialog = mockState.hookedDialogFunction
            end
        end)
    end
end)
hookTradeRequestEvent()
showBlockedTradeRequests = function()
    mockState.blockedTradeRequests = {}
end
task.spawn(function()
    task.wait(1)
    pcall(function()
        if Apps.TradeApp and Apps.TradeApp.partner_profile_button then
            local profileButton = Apps.TradeApp.partner_profile_button
            if profileButton.callbacks and profileButton.callbacks.mouse_button1_click then
                local originalProfileClick = profileButton.callbacks.mouse_button1_click
                profileButton.callbacks.mouse_button1_click = function()
                    if mockState.active and mockState.trade and mockState.trade.recipient then
                        if Apps.PlayerProfileApp and Apps.PlayerProfileApp.open_player_profile_for_user_id then
                            Apps.PlayerProfileApp:open_player_profile_for_user_id(mockState.trade.recipient.UserId)
                        end
                    else
                        if originalProfileClick then originalProfileClick() end
                    end
                end
            end
        end
    end)
end)
function updatePartnerFromUsername(username)
    if not mockState.active then
        mockState.pendingTradeRequest = false
        mockState.canShowTradeRequest = true
        mockState.tradeRequestBlocked = false
        mockState.isMockTradeDialog = false
    end
    local success, userId = pcall(function() return Services.Players:GetUserIdFromNameAsync(username) end)
    if success and userId then
        CONFIG.PARTNER_USER_ID = userId
        CONFIG.PARTNER_NAME = string.lower(username)
        mockPartner = createMockPartner()
        return true
    else
        CONFIG.PARTNER_NAME = string.lower(username)
        mockPartner = createMockPartner()
        return false
    end
end
local function applyMegaNeonEffects(petModel, kind)
    local petRigs = Fsys.load('new:PetRigs')
    local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
    local petData = Modules.InventoryDB.pets[kind]
    if not petData or not petData.neon_parts then return end
    for neonPart, configuration in pairs(petData.neon_parts) do
        local trueNeonPart = petRigs.get(petModelInstance).get_geo_part(petModelInstance, neonPart)
        if trueNeonPart then
            trueNeonPart.Material = Enum.Material.Neon
            local originalColor = configuration.Color
            if originalColor then
                local h, s, v = originalColor:ToHSV()
                trueNeonPart.Color = Color3.fromHSV(h, math.min(s * 1.3, 1), math.min(v * 1.4, 1))
            else
                trueNeonPart.Color = Color3.fromRGB(170, 0, 255)
            end
        end
    end
end
local function applyNeonEffects(petModel, kind)
    local petRigs = Fsys.load('new:PetRigs')
    local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
    local petData = Modules.InventoryDB.pets[kind]
    if not petData or not petData.neon_parts then return end
    for neonPart, configuration in pairs(petData.neon_parts) do
        local trueNeonPart = petRigs.get(petModelInstance).get_geo_part(petModelInstance, neonPart)
        if trueNeonPart then
            trueNeonPart.Material = Enum.Material.Neon
            if configuration.Color then trueNeonPart.Color = configuration.Color end
        end
    end
end
local UIState = {
    currentTab = 'Control',
    tabFrames = {},
    tabButtons = {},
    activeTabPulseTween = nil,
    hasShownAnimation = {},
    playerListButtons = {},
    userListButtons = {},
    petListButtons = {},
    noclipEnabled = true,
    selectedPlayers = {},
    selectionMode = false,
    pulsationTweens = {},
    richestData = {},
    expandedPlayers = {},
    keybinds = {
        selectPartner = Enum.KeyCode.P,
        addRandomItem = Enum.KeyCode.R,
        startTrade = Enum.KeyCode.T,
        blockPlayer = Enum.KeyCode.B,
        randomUser = Enum.KeyCode.G
    },
    waitingForKeybind = nil
}
local Spawning = {}
Spawning.FakePlayers = {}
Spawning.FakePetRegistry = {}
local function updateData(key, action)
    local data = Modules.ClientData.get(key)
    local clonedData = table.clone(data)
    Modules.ClientData.predict(key, action(clonedData))
end
local AnimationManager = { running = false, checkInterval = 0.3, animationTracks = {} }
function AnimationManager:Start()
    if self.running then return end
    self.running = true
    task.spawn(function()
        while self.running do
            task.wait(self.checkInterval)
            for _, petData in ipairs(Spawning.FakePetRegistry) do
                if petData and petData.model and petData.model.Parent then
                    pcall(function()
                        local character = petData.character
                        if character and character.Parent then
                            local humanoid = character:FindFirstChild('Humanoid')
                            if humanoid then
                                local animator = humanoid:FindFirstChild('Animator')
                                if animator then
                                    local isRiding = false
                                    for _, track in ipairs(animator:GetPlayingAnimationTracks()) do
                                        if track.Animation.AnimationId:find('PlayerRidingPet') or track.Animation.AnimationId:find('507766666') then isRiding = true break end
                                    end
                                    if not isRiding and petData.hasRidingPet then
                                        if not petData.ridingAnim or not petData.ridingAnim.IsPlaying then
                                            if petData.ridingAnim then petData.ridingAnim:Stop() end
                                            petData.ridingAnim = animator:LoadAnimation(Modules.animationManager.get_track('PlayerRidingPet'))
                                            petData.ridingAnim.Looped = true
                                            petData.ridingAnim:Play()
                                            humanoid.Sit = true
                                        end
                                    end
                                end
                            end
                        end
                        if petData.wrapper.mega_neon then applyMegaNeonEffects(petData.model, petData.wrapper.pet_id)
                        elseif petData.wrapper.neon then applyNeonEffects(petData.model, petData.wrapper.pet_id) end
                    end)
                end
            end
        end
    end)
end
function AnimationManager:Stop()
    self.running = false
    for _, petData in ipairs(Spawning.FakePetRegistry) do
        if petData.ridingAnim then petData.ridingAnim:Stop() end
    end
end
function AnimationManager:AddPet(petData)
    table.insert(Spawning.FakePetRegistry, petData)
    if not self.running then self:Start() end
end
local function createFakePetOwner(fakeCharacter, partnerName, partnerId)
    return setmetatable({
        Name = partnerName, DisplayName = partnerName, UserId = partnerId, Character = fakeCharacter,
    }, {
        __index = function(t, k)
            if k == 'Parent' then return Services.Players end
            if k == 'IsA' then return function(self, className) return className == 'Player' end end
            if k == 'GetChildren' then return function() return {} end end
            return rawget(t, k)
        end,
        __tostring = function() return partnerName end
    })
end
function OpenProfile(Id)
    Modules.UIManager.apps.PlayerProfileApp:open_player_profile_for_user_id(Id)
end
task.spawn(function()
    task.wait(0.1)
    local InteractionsEngine = Fsys.load('InteractionsEngine')
    local original_register = InteractionsEngine.register
    InteractionsEngine.register = function(self, interactionData)
        if interactionData and interactionData.part then
            local checkPart = interactionData.part
            while checkPart do
                if checkPart:GetAttribute('IsFakePet') == true and checkPart.Parent then return end
                checkPart = checkPart.Parent
            end
        end
        return original_register(self, interactionData)
    end
end)
local currentFakePetType = 'regular'
function CreateFakePlayerCharacterFromPARTNER_NAME(partner_name, partner_id, pros_fake_pet, pet_flags)
    local maxRetries, retryCount = 3, 0
    local function attemptCreate()
        retryCount = retryCount + 1
        fakePlayerIds[partner_id] = true
        _G.fakePlayerIds[partner_id] = true
        local folder_fake = Instance.new('Folder')
        folder_fake.Name = 'fake_folder_' .. partner_name
        folder_fake.Parent = workspace
        local character = Services.Players:CreateHumanoidModelFromUserId(partner_id)
        local playerCharacter = Services.Players.LocalPlayer.Character
        character:SetPrimaryPartCFrame(playerCharacter.HumanoidRootPart.CFrame * CFrame.new(math.random(-10, 10), 0, math.random(-10, 10)))
        local humanoid = character:WaitForChild('Humanoid')
        humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
        humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
        humanoid.HealthDisplayDistance = 0
        character.Parent = folder_fake
        if pros_fake_pet ~= nil then
            local petCreated = false
            local success, err = pcall(function()
                local kind = pros_fake_pet.kind
                local petModel = getPetModel(kind)
                if not petModel then warn('Could not get pet model for kind:', kind) return end
                petModel = petModel:Clone()
                petModel:SetAttribute('IsFakePet', true)
                if pet_flags then
                    if pet_flags.M then applyMegaNeonEffects(petModel, kind)
                    elseif pet_flags.N then applyNeonEffects(petModel, kind) end
                end
                petModel.Parent = folder_fake
                petModel:SetPrimaryPartCFrame(character.HumanoidRootPart.CFrame)
                petModel:ScaleTo(2)
                for _, part in ipairs(petModel:GetDescendants()) do
                    if part:IsA('BasePart') then part:SetAttribute('IsFakePet', true) end
                end
                local ridePosition = petModel:FindFirstChild('RidePosition', true)
                if ridePosition then
                    local sourceAttachment = Instance.new('Attachment')
                    sourceAttachment.Parent = ridePosition
                    sourceAttachment.Position = Vector3.new(0, 1.237, 0)
                    sourceAttachment.Name = 'SourceAttachment'
                    local stateConnection = Instance.new('RigidConstraint')
                    stateConnection.Name = 'StateConnection'
                    stateConnection.Attachment0 = sourceAttachment
                    stateConnection.Attachment1 = character.PrimaryPart.RootAttachment
                    stateConnection.Parent = character
                end
                local ridingAnim = character.Humanoid.Animator:LoadAnimation(Modules.animationManager.get_track('PlayerRidingPet'))
                ridingAnim.Looped = true
                ridingAnim:Play()
                character.Humanoid.Sit = true
                for _, descendant in pairs(character:GetDescendants()) do
                    if descendant:IsA('BasePart') and descendant.Massless == false then
                        descendant.Massless = true
                        descendant:SetAttribute('HaveMass', true)
                    end
                end
                local fakePetOwner = createFakePetOwner(character, partner_name, partner_id)
                local petWrapper = {
                    char = petModel, mega_neon = pet_flags and pet_flags.M or false, neon = pet_flags and pet_flags.N or false,
                    player = fakePetOwner, entity_controller = fakePetOwner, controller = fakePetOwner, rp_name = '',
                    pet_trick_level = math.random(1, 5), pet_unique = Services.HttpService:GenerateGUID(false), pet_id = kind,
                    location = { full_destination_id = 'housing', destination_id = 'housing', house_owner = fakePetOwner },
                    pet_progression = { age = math.random(1, 900000), percentage = math.random(0.01, 0.99) },
                    are_colors_sealed = false, is_pet = true,
                }
                local petState = { char = petModel, player = fakePetOwner, store_key = 'pet_state_managers', is_sitting = false, chars_connected_to_me = {}, states = { { id = 'PetBeingRidden' } } }
                updateData('pet_char_wrappers', function(petWrappers)
                    petWrapper.unique = #petWrappers + 1
                    petWrapper.index = #petWrappers + 1
                    petWrappers[#petWrappers + 1] = petWrapper
                    return petWrappers
                end)
                updateData('pet_state_managers', function(petStates)
                    petStates[#petStates + 1] = petState
                    return petStates
                end)
                table.insert(Spawning.FakePetRegistry, {
                    wrapper = petWrapper, state = petState, model = petModel, character = character,
                    hasRidingPet = true, owner = fakePetOwner, ridingAnim = ridingAnim, folder = folder_fake,
                })
                if not AnimationManager.running then AnimationManager:Start() end
                petCreated = true
            end)
            if not success or not petCreated then
                folder_fake:Destroy()
                for i, folder in ipairs(Spawning.FakePlayers) do if folder == folder_fake then table.remove(Spawning.FakePlayers, i) break end end
                if retryCount < maxRetries then
                    task.wait(0.5)
                    return attemptCreate()
                else
                    return false
                end
            end
        else
            local Animation = Instance.new('Animation')
            Animation.AnimationId = 'http://www.roblox.com/asset/?id=507766666'
            local track = character.Humanoid.Animator:LoadAnimation(Animation)
            track.Looped = true
            track:Play()
        end
        pcall(function() Modules.UIManager.apps.PlayerNameApp:add_npc_id(character, partner_name) end)
        local Part = character:FindFirstChild('HumanoidRootPart')
        if Part then
            local InteractionsEngine = Fsys.load('InteractionsEngine')
            local emptyFunc = function() end
            pcall(function()
                InteractionsEngine:register({
                    text = partner_name, part = Part,
                    on_selected = {
                        { text = 'Profile', on_selected = function() pcall(OpenProfile, partner_id) end },
                        { text = 'Trade', on_selected = function()
                            pcall(function()
                                task.spawn(function()
                                    pcall(function()
                                        if Apps.HintApp then Apps.HintApp:hint({ text = 'Trade request sent to ' .. partner_name, length = 3, overridable = true }) end
                                    end)
                                end)
                                task.wait(CONFIG.FAKE_PLAYER_ACCEPT_TRADE_REQUEST)
                                partnerBox.Text = partner_name
                                updatePartnerFromUsername(partner_name)
                                startMockTradeDirectly()
                            end)
                        end },
                        { text = 'Give Item...', on_selected = emptyFunc },
                        { text = 'Mute', on_selected = emptyFunc },
                    },
                })
            end)
        end
        table.insert(Spawning.FakePlayers, folder_fake)
        folder_fake:SetAttribute('IsFakePlayer', true)
        folder_fake:SetAttribute('PartnerName', partner_name)
        folder_fake:SetAttribute('PartnerId', partner_id)
        return true
    end
    return attemptCreate()
end
function GetKindPet(name)
    for k, v in pairs(Modules.InventoryDB.pets) do
        if v['name']:lower() == name:lower() then return k end
    end
end
local function enableNoclip(character)
    if not character then return end
    for _, part in ipairs(character:GetDescendants()) do
        if part:IsA('BasePart') then
            part.CanCollide = false
            part.CanTouch = false
            part.CanQuery = false
            pcall(function() part.CollisionGroup = 'Noclip' end)
        end
    end
    character.DescendantAdded:Connect(function(descendant)
        if descendant:IsA('BasePart') then
            task.wait()
            descendant.CanCollide = false
            descendant.CanTouch = false
            descendant.CanQuery = false
            pcall(function() descendant.CollisionGroup = 'Noclip' end)
        end
    end)
end
local function enableNoclipForAllFakePlayers()
    for _, folder in ipairs(Spawning.FakePlayers) do
        if folder and folder.Parent then
            for _, child in ipairs(folder:GetChildren()) do
                if child:IsA('Model') then enableNoclip(child) end
            end
        end
    end
end
local function enableNoclipForPets()
    for _, petData in ipairs(Spawning.FakePetRegistry) do
        if petData and petData.model and petData.model.Parent then enableNoclip(petData.model) end
    end
end
function BlockPlayer(Selected)
    pcall(function()
        setthreadidentity(8)
    end)
    game:GetService('StarterGui'):SetCore('PromptBlockPlayer', Selected)

    local startTime = tick()
    local modal = nil
    while not modal do
        game:GetService('RunService').Heartbeat:Wait()
        if tick() - startTime > 10 then
            pcall(function() setthreadidentity(2) end)
            return
        end
        local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
        if overlay then
            modal = overlay:FindFirstChild("BlockingModalScreen", true)
        end
    end

    local function hideModal()
        pcall(function()
            modal.BackgroundTransparency = 1
            for _, desc in ipairs(modal:GetDescendants()) do
                pcall(function()
                    if desc:IsA('ImageLabel') or desc:IsA('ImageButton') then
                        desc.ImageTransparency = 1
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('TextLabel') or desc:IsA('TextButton') then
                        desc.TextTransparency = 1
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('Frame') then
                        desc.BackgroundTransparency = 1
                    end
                    if desc:IsA('UIStroke') then
                        desc.Transparency = 1
                    end
                end)
            end
        end)
    end
    hideModal()

    local posConn
    posConn = game:GetService('RunService').Heartbeat:Connect(function()
        pcall(function()
            if modal and modal.Parent then
                hideModal()
            else
                posConn:Disconnect()
            end
        end)
    end)

    local blockBtn = nil

    pcall(function()
        blockBtn = modal.BlockingModalContainerWrapper.BlockingModal.AlertModal.AlertContents.Footer.Buttons['3']
    end)

    if not blockBtn then
        pcall(function()
            local buttonsContainer = modal:FindFirstChild("Buttons", true)
            if buttonsContainer then
                for _, btn in ipairs(buttonsContainer:GetChildren()) do
                    if btn:IsA('ImageButton') or btn:IsA('TextButton') then
                        local textLabel = btn:FindFirstChild("Text")
                        if textLabel and textLabel:IsA('TextLabel') and textLabel.Text == "Block" then
                            blockBtn = btn
                            break
                        end
                    end
                end
                if not blockBtn then
                    blockBtn = buttonsContainer:FindFirstChild('3')
                end
            end
        end)
    end

    if not blockBtn then
        pcall(function()
            for _, desc in ipairs(modal:GetDescendants()) do
                if (desc:IsA('ImageButton') or desc:IsA('TextButton')) then
                    local textChild = desc:FindFirstChild("Text")
                    if textChild and textChild:IsA('TextLabel') and textChild.Text == "Block" then
                        blockBtn = desc
                        break
                    end
                end
            end
        end)
    end

    if blockBtn then
        local attempts = 0
        while attempts < 20 do
            attempts = attempts + 1

            pcall(function()
                game:GetService('GuiService').SelectedObject = blockBtn
            end)
            task.wait()
            pcall(function()
                if game:GetService('GuiService').SelectedObject == blockBtn then
                    game:GetService('VirtualInputManager'):SendKeyEvent(true, Enum.KeyCode.Return, false, game)
                    game:GetService('VirtualInputManager'):SendKeyEvent(false, Enum.KeyCode.Return, false, game)
                end
            end)
            task.wait(0.1)

            pcall(function()
                local absPos = blockBtn.AbsolutePosition
                local absSize = blockBtn.AbsoluteSize
                local cx = absPos.X + absSize.X / 2
                local cy = absPos.Y + absSize.Y / 2
                local vim = game:GetService('VirtualInputManager')
                vim:SendMouseButtonEvent(cx, cy, 0, true, game, 1)
                task.wait()
                vim:SendMouseButtonEvent(cx, cy, 0, false, game, 1)
            end)

            pcall(function()
                if firesignal then firesignal(blockBtn.MouseButton1Click) end
            end)
            pcall(function()
                if fireclick then fireclick(blockBtn) end
            end)

            task.wait(0.2)

            local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
            if not overlay or not overlay:FindFirstChild("BlockingModalScreen", true) then
                break
            end
        end
        pcall(function() game:GetService('GuiService').SelectedObject = nil end)
    end

    pcall(function() if posConn then posConn:Disconnect() end end)

    local timeout = tick() + 10
    while tick() < timeout do
        local overlay = game:GetService('CoreGui'):FindFirstChild('FoundationOverlay')
        if not overlay or not overlay:FindFirstChild("BlockingModalScreen", true) then
            break
        end
        game:GetService('RunService').Heartbeat:Wait()
    end

    pcall(function()
        setthreadidentity(2)
    end)
end
local function sendTradeToPlayer(player)
    if not player then return end
    local targetPlayer = Services.Players:FindFirstChild(player.Name)
    if targetPlayer then
        pcall(function()
            local success = false
            if not success then
                local success1 = pcall(function()
                    local sendRequest = Modules.RouterClient.get('TradeAPI/SendTradeRequest')
                    if sendRequest then
                        if sendRequest.FireServer then
                            sendRequest:FireServer(targetPlayer)
                            success = true
                        elseif sendRequest.InvokeServer then
                            sendRequest:InvokeServer(targetPlayer)
                            success = true
                        end
                    end
                end)
            end
            if not success then
                local success2 = pcall(function()
                    local TradeRemote = Services.ReplicatedStorage:FindFirstChild('Remotes') and Services.ReplicatedStorage.Remotes:FindFirstChild('TradeAPI') and Services.ReplicatedStorage.Remotes.TradeAPI:FindFirstChild('SendTradeRequest')
                    if TradeRemote then
                        TradeRemote:FireServer(targetPlayer)
                        success = true
                    end
                end)
            end
            if not success then
                local success3 = pcall(function()
                    local InteractionsEngine = Fsys.load('InteractionsEngine')
                    if InteractionsEngine then
                        InteractionsEngine:send_trade_request(targetPlayer)
                        success = true
                    end
                end)
            end
            if success and Apps.HintApp then
                Apps.HintApp:hint({ text = 'Trade request sent to ' .. player.Name, length = 3, overridable = true })
            elseif Apps.HintApp then
                Apps.HintApp:hint({ text = 'Could not send trade request to ' .. player.Name, length = 3, overridable = true })
            end
        end)
    else
        if Apps.HintApp then
            Apps.HintApp:hint({ text = 'Player ' .. player.Name .. ' not found in server', length = 3, overridable = true })
        end
    end
end
local autoSpectateConnection = nil
local function startAutoSpectate()
    if autoSpectateConnection then return end
    autoSpectateConnection = task.spawn(function()
        while CONFIG.AUTO_SPECTATE_ENABLED do
            task.wait(CONFIG.AUTO_SPECTATE_INTERVAL)
            if mockState.active and mockState.trade then
                local newCount = getRandomSpectatorCount()
                CONFIG.SPECTATOR_COUNT = newCount
                if spectatorBox then
                    spectatorBox.Text = tostring(newCount)
                end
                mockState.trade.subscriber_count = newCount
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        end
        autoSpectateConnection = nil
    end)
end
local function stopAutoSpectate()
    CONFIG.AUTO_SPECTATE_ENABLED = false
end
local UI = {}
UI.controlGui = Instance.new('ScreenGui')
UI.controlGui.Name = 'MockTradeControl'
UI.controlGui.ResetOnSpawn = false
UI.controlGui.DisplayOrder = 10
UI.controlGui.Enabled = true
UI.controlGui.Parent = Services.Players.LocalPlayer:WaitForChild('PlayerGui')
UI.mainFrame = Instance.new('Frame')
UI.mainFrame.Size = UDim2.new(0, 220, 0, 750)
UI.mainFrame.Position = UDim2.new(0, 10, 0, 10)
UI.mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
UI.mainFrame.BorderSizePixel = 0
UI.mainFrame.ZIndex = 1
UI.mainFrame.Active = true
UI.mainFrame.Parent = UI.controlGui
UI.mainCorner = Instance.new('UICorner')
UI.mainCorner.CornerRadius = UDim.new(0, 6)
UI.mainCorner.Parent = UI.mainFrame
UI.mainStroke = Instance.new('UIStroke')
UI.mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.mainStroke.Color = Color3.fromRGB(100, 100, 255)
UI.mainStroke.Thickness = 1.5
UI.mainStroke.Parent = UI.mainFrame
UI.titleLabel = Instance.new('TextLabel')
UI.titleLabel.Size = UDim2.new(1, 0, 0, 22)
UI.titleLabel.Position = UDim2.new(0, 0, 0, 2)
UI.titleLabel.BackgroundTransparency = 1
UI.titleLabel.Text = 'ZetaScripts(last4zeta on tt)'
UI.titleLabel.Font = Enum.Font.FredokaOne
UI.titleLabel.TextSize = 12
UI.titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
UI.titleLabel.Parent = UI.mainFrame
UI.titleStroke = Instance.new('UIStroke')
UI.titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
UI.titleStroke.Color = Color3.new(0, 0, 0)
UI.titleStroke.Thickness = 0.8
UI.titleStroke.Parent = UI.titleLabel
UI.tabContainer = Instance.new('Frame')
UI.tabContainer.Size = UDim2.new(0.94, 0, 0, 26)
UI.tabContainer.Position = UDim2.new(0.03, 0, 0, 26)
UI.tabContainer.BackgroundTransparency = 1
UI.tabContainer.Parent = UI.mainFrame
function setActiveTab(tabName)
    if UIState.currentTab == tabName then return end
    if UIState.activeTabPulseTween then UIState.activeTabPulseTween:Cancel() UIState.activeTabPulseTween = nil end
    UIState.currentTab = tabName
    for name, data in pairs(UIState.tabButtons) do
        local isActive = name == tabName
        Services.TweenService:Create(data.button, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            BackgroundColor3 = isActive and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(40, 40, 50)
        }):Play()
        local targetColor = isActive and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
        Services.TweenService:Create(data.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
            Color = targetColor, Thickness = isActive and 1.2 or 0.8
        }):Play()
        if isActive then
            UIState.activeTabPulseTween = Services.TweenService:Create(data.stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
                Color = targetColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25), Thickness = 1.5
            })
            UIState.activeTabPulseTween:Play()
        end
    end
    for name, frame in pairs(UIState.tabFrames) do frame.Visible = name == tabName end
end
local tabs = { 'Control', 'Players', 'Pets', 'Users', 'Sets', 'Spawner' }
local tabIcons = { '🎮', '👥', '🐾', '🧑', '⚙️', '🔮' }
for i, tabName in ipairs(tabs) do
    local tabButton = Instance.new('TextButton')
    tabButton.Size = UDim2.new(1 / #tabs - 0.02, 0, 1, 0)
    tabButton.Position = UDim2.new((i - 1) * (1 / #tabs), 0, 0, 0)
    tabButton.BackgroundColor3 = i == 1 and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(40, 40, 50)
    tabButton.BackgroundTransparency = 0.2
    tabButton.Text = tabIcons[i] .. ' ' .. tabName
    tabButton.Font = Enum.Font.FredokaOne
    tabButton.TextSize = 10
    tabButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tabButton.Parent = UI.tabContainer
    local tabCorner = Instance.new('UICorner')
    tabCorner.CornerRadius = UDim.new(0, 4)
    tabCorner.Parent = tabButton
    local tabStroke = Instance.new('UIStroke')
    tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    tabStroke.Color = i == 1 and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
    tabStroke.Thickness = i == 1 and 1.2 or 0.8
    tabStroke.Transparency = 0.3
    tabStroke.Parent = tabButton
    UIState.tabButtons[tabName] = { button = tabButton, stroke = tabStroke }
    local tabFrame
    if tabName == 'Control' or tabName == 'Spawner' then
        tabFrame = Instance.new('ScrollingFrame')
        tabFrame.Size = UDim2.new(0.9, 0, 0, 670)
        tabFrame.Position = UDim2.new(0.05, 0, 0, 56)
        tabFrame.BackgroundTransparency = 1
        tabFrame.BorderSizePixel = 0
        tabFrame.ScrollBarThickness = 4
        tabFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
        tabFrame.ScrollBarImageTransparency = 0.5
        tabFrame.CanvasSize = UDim2.new(0, 0, 0, 850)
        tabFrame.Visible = i == 1
        tabFrame.Parent = UI.mainFrame
    else
        tabFrame = Instance.new('Frame')
        tabFrame.Size = UDim2.new(0.9, 0, 0, 670)
        tabFrame.Position = UDim2.new(0.05, 0, 0, 56)
        tabFrame.BackgroundTransparency = 1
        tabFrame.Visible = i == 1
        tabFrame.Parent = UI.mainFrame
    end
    UIState.tabFrames[tabName] = tabFrame
    tabButton.MouseButton1Click:Connect(function() setActiveTab(tabName) end)
end
UI.controlFrame = UIState.tabFrames['Control']
UI.controlLayout = Instance.new('UIListLayout')
UI.controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.controlLayout.Padding = UDim.new(0, 4)
UI.controlLayout.Parent = UI.controlFrame
UI.controlPadding = Instance.new('UIPadding')
UI.controlPadding.PaddingTop = UDim.new(0, 4)
UI.controlPadding.PaddingBottom = UDim.new(0, 4)
UI.controlPadding.PaddingLeft = UDim.new(0, 4)
UI.controlPadding.PaddingRight = UDim.new(0, 4)
UI.controlPadding.Parent = UI.controlFrame
function createSettingRow(labelText, defaultValue, parent)
    local heading = Instance.new('TextLabel')
    heading.Size = UDim2.new(1, 0, 0, 14)
    heading.BackgroundTransparency = 1
    heading.Text = labelText
    heading.Font = Enum.Font.SourceSansSemibold
    heading.TextSize = 10
    heading.TextColor3 = Color3.fromRGB(180, 180, 180)
    heading.TextXAlignment = Enum.TextXAlignment.Left
    heading.Parent = parent
    local box = Instance.new('TextBox')
    box.Size = UDim2.new(1, 0, 0, 24)
    box.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    box.BackgroundTransparency = 0.2
    box.Text = tostring(defaultValue)
    box.Font = Enum.Font.SourceSans
    box.TextSize = 12
    box.TextColor3 = Color3.fromRGB(255, 255, 255)
    box.ClearTextOnFocus = false
    box.TextXAlignment = Enum.TextXAlignment.Center
    box.Parent = parent
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = box
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(100, 100, 100)
    stroke.Thickness = 0.8
    stroke.Transparency = 0.5
    stroke.Parent = box
    box.Focused:Connect(function()
        if UIState.pulsationTweens[box] then UIState.pulsationTweens[box]:Cancel() end
        UIState.pulsationTweens[box] = Services.TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Color = Color3.fromRGB(100, 100, 255):Lerp(Color3.fromRGB(150, 150, 255), 0.5), Thickness = 1.2, Transparency = 0.2
        })
        UIState.pulsationTweens[box]:Play()
    end)
    box.FocusLost:Connect(function()
        if UIState.pulsationTweens[box] then UIState.pulsationTweens[box]:Cancel() UIState.pulsationTweens[box] = nil end
        Services.TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = Color3.fromRGB(100, 100, 100), Thickness = 0.8, Transparency = 0.5 }):Play()
    end)
    return box, stroke, heading
end
partnerBox, partnerStroke = createSettingRow('Partner Username', CONFIG.PARTNER_NAME, UI.controlFrame)
UI.acceptBox = createSettingRow('Accept Delay (s)', CONFIG.AUTO_ACCEPT_DELAY, UI.controlFrame)
UI.confirmBox = createSettingRow('Confirm Delay (s)', CONFIG.AUTO_CONFIRM_DELAY, UI.controlFrame)
spectatorBox = createSettingRow('Spectator Count', CONFIG.SPECTATOR_COUNT, UI.controlFrame)
UI.requestDelayBox = createSettingRow('Request Delay (s)', CONFIG.TRADE_REQUEST_DELAY, UI.controlFrame)
partnerBox.FocusLost:Connect(function() updatePartnerFromUsername(partnerBox.Text) end)
UI.acceptBox.FocusLost:Connect(function()
    local value = tonumber(UI.acceptBox.Text)
    if value and value >= 0 then CONFIG.AUTO_ACCEPT_DELAY = value else UI.acceptBox.Text = tostring(CONFIG.AUTO_ACCEPT_DELAY) end
end)
UI.confirmBox.FocusLost:Connect(function()
    local value = tonumber(UI.confirmBox.Text)
    if value and value >= 0 then CONFIG.AUTO_CONFIRM_DELAY = value else UI.confirmBox.Text = tostring(CONFIG.AUTO_CONFIRM_DELAY) end
end)
spectatorBox.FocusLost:Connect(function()
    local value = tonumber(spectatorBox.Text)
    if value and value >= 0 then
        CONFIG.SPECTATOR_COUNT = value
        ORIGINAL_SPECTATOR_COUNT = value
        if mockState.trade then
            mockState.trade.subscriber_count = value
            if Apps.TradeApp.refresh_all then Apps.TradeApp:refresh_all() FriendHighlight(true) end
        end
    else
        spectatorBox.Text = tostring(CONFIG.SPECTATOR_COUNT)
    end
end)
UI.requestDelayBox.FocusLost:Connect(function()
    local value = tonumber(UI.requestDelayBox.Text)
    if value and value >= 0 then CONFIG.TRADE_REQUEST_DELAY = value else UI.requestDelayBox.Text = tostring(CONFIG.TRADE_REQUEST_DELAY) end
end)
local function createButton(text, bgColor, strokeColor, parent, onClick)
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(1, 0, 0, 26)
    btn.BackgroundColor3 = bgColor
    btn.BackgroundTransparency = 0.2
    btn.Text = text
    btn.Font = Enum.Font.FredokaOne
    btn.TextSize = 12
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = parent
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = strokeColor
    stroke.Thickness = 1.0
    stroke.Transparency = 0.3
    stroke.Parent = btn
    if onClick then btn.MouseButton1Click:Connect(onClick) end
    return btn, stroke
end
local function createSpacer(parent, height)
    local spacer = Instance.new('Frame')
    spacer.Size = UDim2.new(1, 0, 0, height or 3)
    spacer.BackgroundTransparency = 1
    spacer.Parent = parent
    return spacer
end
createSpacer(UI.controlFrame, 4)
UI.autoSpectateButton = Instance.new('TextButton')
UI.autoSpectateButton.Size = UDim2.new(1, 0, 0, 32)
UI.autoSpectateButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
UI.autoSpectateButton.BackgroundTransparency = 0.1
UI.autoSpectateButton.Text = '🎲 Auto Spectate: OFF'
UI.autoSpectateButton.Font = Enum.Font.FredokaOne
UI.autoSpectateButton.TextSize = 13
UI.autoSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.autoSpectateButton.Parent = UI.controlFrame
UI.autoSpectateCorner = Instance.new('UICorner')
UI.autoSpectateCorner.CornerRadius = UDim.new(0, 4)
UI.autoSpectateCorner.Parent = UI.autoSpectateButton
UI.autoSpectateStroke = Instance.new('UIStroke')
UI.autoSpectateStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.autoSpectateStroke.Color = Color3.fromRGB(255, 100, 100)
UI.autoSpectateStroke.Thickness = 1.5
UI.autoSpectateStroke.Parent = UI.autoSpectateButton
UI.autoSpectateButton.MouseButton1Click:Connect(function()
    CONFIG.AUTO_SPECTATE_ENABLED = not CONFIG.AUTO_SPECTATE_ENABLED
    if CONFIG.AUTO_SPECTATE_ENABLED then
        UI.autoSpectateButton.Text = '🎲 Auto Spectate: ON (Random)'
        UI.autoSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        UI.autoSpectateStroke.Color = Color3.fromRGB(100, 255, 100)
        ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT
        startAutoSpectate()
        if Apps.HintApp then
            Apps.HintApp:hint({ text = 'Auto Spectate ON! Range: ' .. (ORIGINAL_SPECTATOR_COUNT + CONFIG.SPECTATOR_VARIATION_MIN) .. '-' .. (ORIGINAL_SPECTATOR_COUNT + CONFIG.SPECTATOR_VARIATION_MAX), length = 3, overridable = true })
        end
    else
        UI.autoSpectateButton.Text = '🎲 Auto Spectate: OFF'
        UI.autoSpectateButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        UI.autoSpectateStroke.Color = Color3.fromRGB(255, 100, 100)
        stopAutoSpectate()
        if Apps.HintApp then
            Apps.HintApp:hint({ text = 'Auto Spectate OFF', length = 2, overridable = true })
        end
    end
end)
createSpacer(UI.controlFrame)
createButton('Add Random Item', Color3.fromRGB(100, 50, 150), Color3.fromRGB(200, 100, 255), UI.controlFrame, function()
    if mockState.active and mockState.trade then
        addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
    end
end)
createSpacer(UI.controlFrame)
createButton('Clear Trade', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), UI.controlFrame, function()
    if mockState.active and mockState.trade then
        mockState.trade.sender_offer.items = {}
        mockState.trade.recipient_offer.items = {}
        mockState.trade.sender_offer.negotiated = false
        mockState.trade.recipient_offer.negotiated = false
        mockState.trade.current_stage = 'negotiation'
        mockState.trade.offer_version = mockState.trade.offer_version + 1
        Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
    end
end)
createSpacer(UI.controlFrame)
createButton('Start Trade', Color3.fromRGB(50, 80, 60), Color3.fromRGB(0, 255, 100), UI.controlFrame, function()
    if mockState.active or mockState.pendingTradeRequest then return end
    if CONFIG.SHOW_TRADE_REQUEST then
        task.spawn(showTradeRequest)
    else
        startMockTradeDirectly()
    end
end)
createButton('Block Player', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), UI.controlFrame, function()
    local player = Services.Players:FindFirstChild(partnerBox.Text)
    if player then BlockPlayer(player) end
end)
createSpacer(UI.controlFrame)
createButton('Spin The Wheel', Color3.fromRGB(50, 100, 200), Color3.fromRGB(80, 160, 255), UI.controlFrame, function()
    if spinnerSystem and spinnerSystem.showWheel then
        spinnerSystem.showWheel()
    end
end)
UI.spinOnAddButton = Instance.new('TextButton')
UI.spinOnAddButton.Size = UDim2.new(1, 0, 0, 26)
UI.spinOnAddButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
UI.spinOnAddButton.BackgroundTransparency = 0.2
UI.spinOnAddButton.Text = 'Spin on +: OFF'
UI.spinOnAddButton.Font = Enum.Font.FredokaOne
UI.spinOnAddButton.TextSize = 12
UI.spinOnAddButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.spinOnAddButton.Parent = UI.controlFrame
Instance.new('UICorner', UI.spinOnAddButton).CornerRadius = UDim.new(0, 4)
UI.spinOnAddStroke = Instance.new('UIStroke')
UI.spinOnAddStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.spinOnAddStroke.Color = Color3.fromRGB(255, 100, 100)
UI.spinOnAddStroke.Thickness = 1.0
UI.spinOnAddStroke.Transparency = 0.3
UI.spinOnAddStroke.Parent = UI.spinOnAddButton
UI.spinOnAddButton.MouseButton1Click:Connect(function()
    CONFIG.SPIN_THE_WHEEL_ON_ADD = not CONFIG.SPIN_THE_WHEEL_ON_ADD
    if CONFIG.SPIN_THE_WHEEL_ON_ADD then
        UI.spinOnAddButton.Text = 'Spin on +: ON'
        UI.spinOnAddButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        UI.spinOnAddStroke.Color = Color3.fromRGB(100, 255, 100)
    else
        UI.spinOnAddButton.Text = 'Spin on +: OFF'
        UI.spinOnAddButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        UI.spinOnAddStroke.Color = Color3.fromRGB(255, 100, 100)
    end
end)
createSpacer(UI.controlFrame)
function makePartnerAccept()
    if mockState.active and mockState.trade then
        if mockState.trade.current_stage == 'negotiation' then
            if not mockState.trade.recipient_offer.negotiated then
                mockState.trade.recipient_offer.negotiated = true
                if mockState.trade.sender_offer.negotiated then
                    mockState.trade.current_stage = 'confirmation'
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                    if Apps.TradeApp._evaluate_trade_fairness then Apps.TradeApp:_evaluate_trade_fairness() end
                    if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
                else
                    mockState.trade.offer_version = mockState.trade.offer_version + 1
                    Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                end
            end
        elseif mockState.trade.current_stage == 'confirmation' then
            if not mockState.trade.recipient_offer.confirmed then
                mockState.trade.recipient_offer.confirmed = true
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
                    mockState.tradeCompleting = true
                    if Apps.TradeApp._set_confirmation_arrow_rotating then Apps.TradeApp:_set_confirmation_arrow_rotating(true) end
                    task.wait(3)
                    local historyRecord = createTradeHistoryRecord(mockState.trade)
                    appendToTradeHistory(historyRecord)
                    pcall(function()
                        local inv = Modules.ClientData.get("inventory")
                        if inv and inv.pets and mockState.trade and mockState.trade.recipient_offer then
                            for _, item in ipairs(mockState.trade.recipient_offer.items) do
                                if item.category == "pets" and item.kind then
                                    local uid = Services.HttpService:GenerateGUID(false)
                                    inv.pets[uid] = {
                                        unique = uid, category = "pets", id = item.kind, kind = item.kind,
                                        newness_order = math.huge, properties = item.properties or {}
                                    }
                                end
                            end
                        end
                        if inv and inv.pets and mockState.trade and mockState.trade.sender_offer then
                            for _, item in ipairs(mockState.trade.sender_offer.items) do
                                if item.unique and inv.pets[item.unique] then
                                    inv.pets[item.unique] = nil
                                end
                            end
                        end
                    end)
                    mockState.active = false
                    mockState.trade = nil
                    mockState.tradeCompleting = false
                    mockState.scamWarningShown = true
                    mockState.canShowTradeRequest = true
                    mockState.tradeRequestBlocked = false
                    Modules.UIManager.set_app_visibility('TradeApp', false)
                    task.wait(0.1)
                    showBlockedTradeRequests()
                    if Apps.HintApp then Apps.HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
                    if Apps.TradeHistoryApp and Modules.UIManager.is_visible('TradeHistoryApp') then Apps.TradeHistoryApp:_refresh() end
                end
            end
        end
    end
end
function makePartnerUnaccept()
    if mockState.active and mockState.trade then
        if mockState.trade.current_stage == 'negotiation' then
            if mockState.trade.recipient_offer.negotiated then
                mockState.trade.recipient_offer.negotiated = false
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        elseif mockState.trade.current_stage == 'confirmation' then
            if mockState.trade.recipient_offer.confirmed then
                mockState.trade.recipient_offer.confirmed = false
                mockState.trade.offer_version = mockState.trade.offer_version + 1
                Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
            end
        end
    end
end
createButton('Make Partner Accept', Color3.fromRGB(50, 150, 50), Color3.fromRGB(100, 255, 100), UI.controlFrame, makePartnerAccept)
createSpacer(UI.controlFrame)
UI.noclipButton, UI.noclipStroke = createButton('Toggle Noclip: ON', Color3.fromRGB(80, 80, 180), Color3.fromRGB(100, 100, 255), UI.controlFrame, function()
    UIState.noclipEnabled = not UIState.noclipEnabled
    if UIState.noclipEnabled then
        UI.noclipButton.Text = 'Toggle Noclip: ON'
        UI.noclipButton.BackgroundColor3 = Color3.fromRGB(80, 80, 180)
        UI.noclipStroke.Color = Color3.fromRGB(100, 100, 255)
        enableNoclipForAllFakePlayers()
        enableNoclipForPets()
    else
        UI.noclipButton.Text = 'Toggle Noclip: OFF'
        UI.noclipButton.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
        UI.noclipStroke.Color = Color3.fromRGB(255, 100, 100)
    end
end)
createSpacer(UI.controlFrame)
createButton('Make Partner Unaccept', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), UI.controlFrame, makePartnerUnaccept)
createSpacer(UI.controlFrame)
UI.petTypeContainer = Instance.new('Frame')
UI.petTypeContainer.Size = UDim2.new(1, 0, 0, 24)
UI.petTypeContainer.BackgroundTransparency = 1
UI.petTypeContainer.Parent = UI.controlFrame
UI.petTypeLabel = Instance.new('TextLabel')
UI.petTypeLabel.Size = UDim2.new(0.4, 0, 1, 0)
UI.petTypeLabel.BackgroundTransparency = 1
UI.petTypeLabel.Text = 'Fake Player Pet:'
UI.petTypeLabel.Font = Enum.Font.SourceSansSemibold
UI.petTypeLabel.TextSize = 10
UI.petTypeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.petTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
UI.petTypeLabel.Parent = UI.petTypeContainer
UI.petTypeButtons = {}
local petTypes = { { name = 'regular', label = 'Reg', pos = 0.4 }, { name = 'neon', label = 'Neon', pos = 0.6 }, { name = 'mega', label = 'Mega', pos = 0.8 } }
for _, pt in ipairs(petTypes) do
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0.18, 0, 1, 0)
    btn.Position = UDim2.new(pt.pos, 0, 0, 0)
    btn.Text = pt.label
    btn.BackgroundColor3 = pt.name == 'regular' and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 70)
    btn.Font = Enum.Font.FredokaOne
    btn.TextSize = 9
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = UI.petTypeContainer
    local corner = Instance.new('UICorner')
    corner.CornerRadius = UDim.new(0, 4)
    corner.Parent = btn
    UI.petTypeButtons[pt.name] = btn
    btn.MouseButton1Click:Connect(function()
        currentFakePetType = pt.name
        for name, b in pairs(UI.petTypeButtons) do
            b.BackgroundColor3 = name == pt.name and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 70)
        end
    end)
end
createButton('Spawn fake player', Color3.fromRGB(65, 50, 150), Color3.fromRGB(74, 207, 255), UI.controlFrame, function()
    local petData, petFlags = nil, nil
    if CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET then
        local highValuePet = getRandomHighValuePet()
        petFlags = { M = currentFakePetType == 'mega', N = currentFakePetType == 'neon', F = true, R = true }
        petData = { kind = GetKindPet(highValuePet) }
    end
    CreateFakePlayerCharacterFromPARTNER_NAME(CONFIG.PARTNER_NAME, Services.Players:GetUserIdFromNameAsync(CONFIG.PARTNER_NAME), petData, petFlags)
end)
createSpacer(UI.controlFrame)
UI.spawnWithPetsButton = Instance.new('TextButton')
UI.spawnWithPetsButton.Size = UDim2.new(1, 0, 0, 14)
UI.spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
UI.spawnWithPetsButton.BackgroundTransparency = 0.2
UI.spawnWithPetsButton.Text = 'Spawn with random pet: false'
UI.spawnWithPetsButton.Font = Enum.Font.FredokaOne
UI.spawnWithPetsButton.TextSize = 7
UI.spawnWithPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.spawnWithPetsButton.Parent = UI.controlFrame
UI.spawnWithPetsCorner = Instance.new('UICorner')
UI.spawnWithPetsCorner.CornerRadius = UDim.new(0, 3)
UI.spawnWithPetsCorner.Parent = UI.spawnWithPetsButton
UI.spawnWithPetsStroke = Instance.new('UIStroke')
UI.spawnWithPetsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.spawnWithPetsStroke.Color = Color3.fromRGB(255, 100, 100)
UI.spawnWithPetsStroke.Thickness = 0.8
UI.spawnWithPetsStroke.Transparency = 0.3
UI.spawnWithPetsStroke.Parent = UI.spawnWithPetsButton
UI.spawnWithPetsButton.MouseButton1Click:Connect(function()
    CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = not CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET
    UI.spawnWithPetsButton.Text = 'Spawn with random pet: ' .. (CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET and 'true' or 'false')
    if CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET then
        UI.spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        UI.spawnWithPetsStroke.Color = Color3.fromRGB(100, 255, 100)
    else
        UI.spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        UI.spawnWithPetsStroke.Color = Color3.fromRGB(255, 100, 100)
    end
end)
createSpacer(UI.controlFrame)
UI.deleteFakePlayerButton = Instance.new('TextButton')
UI.deleteFakePlayerButton.Size = UDim2.new(1, 0, 0, 14)
UI.deleteFakePlayerButton.BackgroundColor3 = Color3.fromRGB(157, 58, 0)
UI.deleteFakePlayerButton.BackgroundTransparency = 0.2
UI.deleteFakePlayerButton.Text = 'Delete all fake players'
UI.deleteFakePlayerButton.Font = Enum.Font.FredokaOne
UI.deleteFakePlayerButton.TextSize = 7
UI.deleteFakePlayerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.deleteFakePlayerButton.Parent = UI.controlFrame
UI.deleteFakePlayerCorner = Instance.new('UICorner')
UI.deleteFakePlayerCorner.CornerRadius = UDim.new(0, 3)
UI.deleteFakePlayerCorner.Parent = UI.deleteFakePlayerButton
UI.deleteFakePlayerButton.MouseButton1Click:Connect(function()
    pcall(function()
        AnimationManager:Stop()
        for _, petData in ipairs(Spawning.FakePetRegistry) do
            if petData and petData.model then
                pcall(function()
                    updateData('pet_char_wrappers', function(petWrappers)
                        for i = #petWrappers, 1, -1 do
                            if petWrappers[i].pet_unique == petData.wrapper.pet_unique then table.remove(petWrappers, i) end
                        end
                        return petWrappers
                    end)
                end)
                pcall(function()
                    updateData('pet_state_managers', function(petStates)
                        for i = #petStates, 1, -1 do
                            if petStates[i].char == petData.model then table.remove(petStates, i) end
                        end
                        return petStates
                    end)
                end)
            end
        end
        for _, folder in pairs(Spawning.FakePlayers) do if folder and folder.Parent then folder:Destroy() end end
        Spawning.FakePlayers = {}
        Spawning.FakePetRegistry = {}
        fakePlayerIds = {}
        _G.fakePlayerIds = {}
    end)
end)
createSpacer(UI.controlFrame)
UI.removePetsButton, UI.removePetsStroke = createButton('Remove Partner Pets: OFF', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), UI.controlFrame, function()
    mockState.removePartnerPetsOnConfirm = not mockState.removePartnerPetsOnConfirm
    CONFIG.REMOVE_PARTNER_PETS_ON_CONFIRM = mockState.removePartnerPetsOnConfirm
    if mockState.removePartnerPetsOnConfirm then
        UI.removePetsButton.Text = 'Remove Partner Pets: ON'
        UI.removePetsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        UI.removePetsStroke.Color = Color3.fromRGB(100, 255, 100)
    else
        UI.removePetsButton.Text = 'Remove Partner Pets: OFF'
        UI.removePetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        UI.removePetsStroke.Color = Color3.fromRGB(255, 100, 100)
    end
end)
UI.playersFrame = UIState.tabFrames['Players']
UI.playerSearchBox = Instance.new('TextBox')
UI.playerSearchBox.Size = UDim2.new(1, 0, 0, 26)
UI.playerSearchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
UI.playerSearchBox.BackgroundTransparency = 0.2
UI.playerSearchBox.Text = ''
UI.playerSearchBox.PlaceholderText = 'Search players...'
UI.playerSearchBox.Font = Enum.Font.SourceSans
UI.playerSearchBox.TextSize = 12
UI.playerSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.playerSearchBox.ClearTextOnFocus = false
UI.playerSearchBox.TextXAlignment = Enum.TextXAlignment.Left
UI.playerSearchBox.Parent = UI.playersFrame
Instance.new('UICorner', UI.playerSearchBox).CornerRadius = UDim.new(0, 4)
UI.selectionControls = Instance.new('Frame')
UI.selectionControls.Size = UDim2.new(1, 0, 0, 26)
UI.selectionControls.Position = UDim2.new(0, 0, 0, 30)
UI.selectionControls.BackgroundTransparency = 1
UI.selectionControls.Parent = UI.playersFrame
UI.selectPlayersButton = Instance.new('TextButton')
UI.selectPlayersButton.Size = UDim2.new(0.48, 0, 1, 0)
UI.selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
UI.selectPlayersButton.BackgroundTransparency = 0.2
UI.selectPlayersButton.Text = 'Select Services.Players'
UI.selectPlayersButton.Font = Enum.Font.FredokaOne
UI.selectPlayersButton.TextSize = 10
UI.selectPlayersButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.selectPlayersButton.Parent = UI.selectionControls
Instance.new('UICorner', UI.selectPlayersButton).CornerRadius = UDim.new(0, 4)
UI.selectPlayersStroke = Instance.new('UIStroke')
UI.selectPlayersStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
UI.selectPlayersStroke.Thickness = 1.0
UI.selectPlayersStroke.Parent = UI.selectPlayersButton
UI.blockSelectedButton = Instance.new('TextButton')
UI.blockSelectedButton.Size = UDim2.new(0.48, 0, 1, 0)
UI.blockSelectedButton.Position = UDim2.new(0.52, 0, 0, 0)
UI.blockSelectedButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
UI.blockSelectedButton.BackgroundTransparency = 0.2
UI.blockSelectedButton.Text = 'Block Selected'
UI.blockSelectedButton.Font = Enum.Font.FredokaOne
UI.blockSelectedButton.TextSize = 10
UI.blockSelectedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.blockSelectedButton.Parent = UI.selectionControls
Instance.new('UICorner', UI.blockSelectedButton).CornerRadius = UDim.new(0, 4)
UI.playerListFrame = Instance.new('ScrollingFrame')
UI.playerListFrame.Size = UDim2.new(1, 0, 0, 250)
UI.playerListFrame.Position = UDim2.new(0, 0, 0, 60)
UI.playerListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
UI.playerListFrame.BackgroundTransparency = 0.5
UI.playerListFrame.BorderSizePixel = 0
UI.playerListFrame.ScrollBarThickness = 4
UI.playerListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
UI.playerListFrame.ScrollBarImageTransparency = 0.5
UI.playerListFrame.Parent = UI.playersFrame
Instance.new('UICorner', UI.playerListFrame).CornerRadius = UDim.new(0, 4)
UI.playerListLayout = Instance.new('UIListLayout')
UI.playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.playerListLayout.Padding = UDim.new(0, 3)
UI.playerListLayout.Parent = UI.playerListFrame
UI.playerListPadding = Instance.new('UIPadding')
UI.playerListPadding.PaddingTop = UDim.new(0, 4)
UI.playerListPadding.PaddingBottom = UDim.new(0, 4)
UI.playerListPadding.PaddingLeft = UDim.new(0, 4)
UI.playerListPadding.PaddingRight = UDim.new(0, 4)
UI.playerListPadding.Parent = UI.playerListFrame
UI.richestHeading = Instance.new('TextLabel')
UI.richestHeading.Size = UDim2.new(1, 0, 0, 18)
UI.richestHeading.Position = UDim2.new(0, 0, 0, 315)
UI.richestHeading.BackgroundTransparency = 1
UI.richestHeading.Text = '💰 Top 35 Richest Services.Players (Auto-Refresh)'
UI.richestHeading.Font = Enum.Font.FredokaOne
UI.richestHeading.TextSize = 11
UI.richestHeading.TextColor3 = Color3.fromRGB(255, 215, 0)
UI.richestHeading.TextXAlignment = Enum.TextXAlignment.Left
UI.richestHeading.Parent = UI.playersFrame
UI.autoRefreshButton = Instance.new('TextButton')
UI.autoRefreshButton.Size = UDim2.new(0.3, 0, 0, 18)
UI.autoRefreshButton.Position = UDim2.new(0.7, 0, 0, 315)
UI.autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
UI.autoRefreshButton.BackgroundTransparency = 0.2
UI.autoRefreshButton.Text = 'Auto: ON'
UI.autoRefreshButton.Font = Enum.Font.FredokaOne
UI.autoRefreshButton.TextSize = 8
UI.autoRefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.autoRefreshButton.Parent = UI.playersFrame
Instance.new('UICorner', UI.autoRefreshButton).CornerRadius = UDim.new(0, 4)
UI.refreshRichestButton = Instance.new('TextButton')
UI.refreshRichestButton.Size = UDim2.new(0.3, 0, 0, 18)
UI.refreshRichestButton.Position = UDim2.new(0.35, 0, 0, 315)
UI.refreshRichestButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
UI.refreshRichestButton.BackgroundTransparency = 0.2
UI.refreshRichestButton.Text = '🔄 Manual'
UI.refreshRichestButton.Font = Enum.Font.FredokaOne
UI.refreshRichestButton.TextSize = 8
UI.refreshRichestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.refreshRichestButton.Parent = UI.playersFrame
Instance.new('UICorner', UI.refreshRichestButton).CornerRadius = UDim.new(0, 4)
UI.richestListFrame = Instance.new('ScrollingFrame')
UI.richestListFrame.Size = UDim2.new(1, 0, 0, 320)
UI.richestListFrame.Position = UDim2.new(0, 0, 0, 337)
UI.richestListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
UI.richestListFrame.BackgroundTransparency = 0.5
UI.richestListFrame.BorderSizePixel = 0
UI.richestListFrame.ScrollBarThickness = 4
UI.richestListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
UI.richestListFrame.ScrollBarImageTransparency = 0.5
UI.richestListFrame.Parent = UI.playersFrame
Instance.new('UICorner', UI.richestListFrame).CornerRadius = UDim.new(0, 4)
UI.richestListLayout = Instance.new('UIListLayout')
UI.richestListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.richestListLayout.Padding = UDim.new(0, 3)
UI.richestListLayout.Parent = UI.richestListFrame
UI.richestListPadding = Instance.new('UIPadding')
UI.richestListPadding.PaddingTop = UDim.new(0, 4)
UI.richestListPadding.PaddingBottom = UDim.new(0, 4)
UI.richestListPadding.PaddingLeft = UDim.new(0, 4)
UI.richestListPadding.PaddingRight = UDim.new(0, 4)
UI.richestListPadding.Parent = UI.richestListFrame
local RefreshState = {
    autoRefreshEnabled = true,
    playerCache = {},
    isRefreshing = false,
    lastRefreshTime = 0,
    lastFullRefreshTime = 0,
    REFRESH_COOLDOWN = 2,
    FULL_REFRESH_INTERVAL = 30,
    playerContainers = {}
}
local function getExistingPlayerNames()
    local names = {}
    for _, child in ipairs(UI.richestListFrame:GetChildren()) do
        if child:IsA('Frame') and child.Name:sub(1, 14) == 'RichestPlayer_' then
            names[child.Name:sub(15)] = true
        end
    end
    return names
end
local function removePlayerFromList(playerName)
    for _, child in ipairs(UI.richestListFrame:GetChildren()) do
        if child:IsA('Frame') and child.Name == 'RichestPlayer_' .. playerName then
            child:Destroy()
        end
    end
    RefreshState.playerContainers[playerName] = nil
    RefreshState.playerCache[playerName] = nil
    UIState.expandedPlayers[playerName] = nil
end
local function updateCanvasSize()
    task.wait(0.05)
    local totalHeight = 8
    for _, child in ipairs(UI.richestListFrame:GetChildren()) do
        if child:IsA('Frame') then
            totalHeight = totalHeight + child.AbsoluteSize.Y + 3
        end
    end
    UI.richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end
local function createRichestPlayerButton(playerData, index)
    local container = Instance.new('Frame')
    container.Size = UDim2.new(1, -8, 0, 32)
    container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
    container.BackgroundTransparency = 0.1
    container.LayoutOrder = index
    container.Name = 'RichestPlayer_' .. playerData.playerName
    container.ClipsDescendants = true
    container.Parent = UI.richestListFrame
    Instance.new('UICorner', container).CornerRadius = UDim.new(0, 8)
    local containerGradient = Instance.new('UIGradient')
    containerGradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(50, 45, 65)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(35, 32, 48))
    })
    containerGradient.Rotation = 90
    containerGradient.Parent = container
    local containerStroke = Instance.new('UIStroke')
    containerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    containerStroke.Color = Color3.fromRGB(255, 200, 50)
    containerStroke.Thickness = 1.5
    containerStroke.Transparency = 0.2
    containerStroke.Parent = container
    local rankColors = {
        [1] = Color3.fromRGB(255, 215, 0),
        [2] = Color3.fromRGB(200, 200, 210),
        [3] = Color3.fromRGB(205, 140, 80),
    }
    local rankBadge = Instance.new('TextLabel')
    rankBadge.Size = UDim2.new(0, 22, 0, 22)
    rankBadge.Position = UDim2.new(0, 5, 0, 5)
    rankBadge.BackgroundColor3 = rankColors[index] or Color3.fromRGB(70, 70, 90)
    rankBadge.BackgroundTransparency = 0.2
    rankBadge.Text = tostring(index)
    rankBadge.Font = Enum.Font.GothamBlack
    rankBadge.TextSize = 11
    rankBadge.TextColor3 = Color3.fromRGB(255, 255, 255)
    rankBadge.Parent = container
    Instance.new('UICorner', rankBadge).CornerRadius = UDim.new(0, 11)
    local tradeButton = Instance.new('TextButton')
    tradeButton.Size = UDim2.new(0, 32, 0, 22)
    tradeButton.Position = UDim2.new(1, -74, 0, 5)
    tradeButton.BackgroundColor3 = Color3.fromRGB(50, 130, 100)
    tradeButton.BackgroundTransparency = 0.1
    tradeButton.Text = '🤝'
    tradeButton.Font = Enum.Font.GothamBold
    tradeButton.TextSize = 12
    tradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    tradeButton.Parent = container
    Instance.new('UICorner', tradeButton).CornerRadius = UDim.new(0, 6)
    tradeButton.MouseEnter:Connect(function()
        Services.TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 160, 120) }):Play()
    end)
    tradeButton.MouseLeave:Connect(function()
        Services.TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 130, 100) }):Play()
    end)
    tradeButton.MouseButton1Click:Connect(function()
        local targetPlayer = Services.Players:FindFirstChild(playerData.playerName)
        if targetPlayer then
            sendTradeToPlayer(targetPlayer)
        else
            for _, player in ipairs(Services.Players:GetPlayers()) do
                if player.Name == playerData.playerName then
                    sendTradeToPlayer(player)
                    return
                end
            end
            if Apps.HintApp then
                Apps.HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true })
            end
        end
    end)
    local profileButton = Instance.new('TextButton')
    profileButton.Size = UDim2.new(0, 32, 0, 22)
    profileButton.Position = UDim2.new(1, -38, 0, 5)
    profileButton.BackgroundColor3 = Color3.fromRGB(100, 70, 150)
    profileButton.BackgroundTransparency = 0.1
    profileButton.Text = '👤'
    profileButton.Font = Enum.Font.GothamBold
    profileButton.TextSize = 12
    profileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    profileButton.Parent = container
    Instance.new('UICorner', profileButton).CornerRadius = UDim.new(0, 6)
    profileButton.MouseEnter:Connect(function()
        Services.TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(130, 90, 180) }):Play()
    end)
    profileButton.MouseLeave:Connect(function()
        Services.TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 70, 150) }):Play()
    end)
    profileButton.MouseButton1Click:Connect(function()
        local targetPlayer = Services.Players:FindFirstChild(playerData.playerName)
        if targetPlayer then
            pcall(function()
                OpenProfile(targetPlayer.UserId)
            end)
        else
            for _, player in ipairs(Services.Players:GetPlayers()) do
                if player.Name == playerData.playerName then
                    pcall(function()
                        OpenProfile(player.UserId)
                    end)
                    return
                end
            end
            if Apps.HintApp then
                Apps.HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true })
            end
        end
    end)
    local mainButton = Instance.new('TextButton')
    mainButton.Size = UDim2.new(1, -110, 0, 32)
    mainButton.Position = UDim2.new(0, 30, 0, 0)
    mainButton.BackgroundTransparency = 1
    mainButton.Text = ''
    mainButton.Parent = container
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(0.55, 0, 1, 0)
    nameLabel.Position = UDim2.new(0, 0, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = playerData.playerName
    nameLabel.Font = Enum.Font.GothamBold
    nameLabel.TextSize = 10
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
    nameLabel.Parent = mainButton
    local valueLabel = Instance.new('TextLabel')
    valueLabel.Size = UDim2.new(0.45, 0, 1, 0)
    valueLabel.Position = UDim2.new(0.55, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = formatValue(playerData.totalValue)
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 10
    valueLabel.TextColor3 = Color3.fromRGB(120, 255, 120)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = mainButton
    local petsSection = Instance.new('Frame')
    petsSection.Size = UDim2.new(1, -8, 0, 0)
    petsSection.Position = UDim2.new(0, 4, 0, 34)
    petsSection.BackgroundColor3 = Color3.fromRGB(30, 30, 45)
    petsSection.BackgroundTransparency = 0.3
    petsSection.Visible = false
    petsSection.Name = 'PetsSection'
    petsSection.Parent = container
    Instance.new('UICorner', petsSection).CornerRadius = UDim.new(0, 6)
    local petsLayout = Instance.new('UIListLayout')
    petsLayout.SortOrder = Enum.SortOrder.LayoutOrder
    petsLayout.Padding = UDim.new(0, 2)
    petsLayout.Parent = petsSection
    local petsPadding = Instance.new('UIPadding')
    petsPadding.PaddingTop = UDim.new(0, 4)
    petsPadding.PaddingBottom = UDim.new(0, 4)
    petsPadding.PaddingLeft = UDim.new(0, 6)
    petsPadding.PaddingRight = UDim.new(0, 6)
    petsPadding.Parent = petsSection
    local isExpanded = false
    local expandId = 0
    mainButton.MouseButton1Click:Connect(function()
        if isExpanded then
            isExpanded = false
            expandId = expandId + 1
            petsSection.Visible = false
            petsSection.Size = UDim2.new(1, -8, 0, 0)
            container.Size = UDim2.new(1, -8, 0, 32)
        else
            isExpanded = true
            expandId = expandId + 1
            local currentExpandId = expandId
            for _, child in ipairs(petsSection:GetChildren()) do
                if child:IsA('TextLabel') then child:Destroy() end
            end
            local petsHeight = 0
            if playerData.pets and #playerData.pets > 0 then
                local sortedPets = {}
                for _, pet in ipairs(playerData.pets) do table.insert(sortedPets, pet) end
                table.sort(sortedPets, function(a, b) return a.value > b.value end)
                local displayCount = math.min(#sortedPets, 8)
                for i = 1, displayCount do
                    local pet = sortedPets[i]
                    local prefix = ""
                    if pet.isMega then prefix = "M "
                    elseif pet.isNeon then prefix = "N " end
                    if pet.isFly then prefix = prefix .. "F" end
                    if pet.isRide then prefix = prefix .. "R" end
                    if prefix ~= "" then prefix = "[" .. prefix:gsub("%s+$", "") .. "] " end
                    local petLabel = Instance.new('TextLabel')
                    petLabel.Size = UDim2.new(1, 0, 0, 14)
                    petLabel.BackgroundTransparency = 1
                    petLabel.Text = prefix .. pet.displayName .. ' - ' .. formatValue(pet.value)
                    petLabel.Font = Enum.Font.SourceSans
                    petLabel.TextSize = 9
                    petLabel.TextColor3 = pet.isMega and Color3.fromRGB(170, 100, 255) or (pet.isNeon and Color3.fromRGB(100, 255, 150) or Color3.fromRGB(200, 200, 200))
                    petLabel.TextXAlignment = Enum.TextXAlignment.Left
                    petLabel.LayoutOrder = i
                    petLabel.Parent = petsSection
                end
                if #sortedPets > 8 then
                    local moreLabel = Instance.new('TextLabel')
                    moreLabel.Size = UDim2.new(1, 0, 0, 12)
                    moreLabel.BackgroundTransparency = 1
                    moreLabel.Text = '... and ' .. (#sortedPets - 8) .. ' more pets'
                    moreLabel.Font = Enum.Font.SourceSansItalic
                    moreLabel.TextSize = 8
                    moreLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                    moreLabel.TextXAlignment = Enum.TextXAlignment.Left
                    moreLabel.LayoutOrder = 999
                    moreLabel.Parent = petsSection
                end
                petsHeight = (displayCount * 16) + 10
                if #sortedPets > 8 then petsHeight = petsHeight + 14 end
            else
                local noPetsLabel = Instance.new('TextLabel')
                noPetsLabel.Size = UDim2.new(1, 0, 0, 14)
                noPetsLabel.BackgroundTransparency = 1
                noPetsLabel.Text = 'No pets listed in profile'
                noPetsLabel.Font = Enum.Font.SourceSansItalic
                noPetsLabel.TextSize = 9
                noPetsLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
                noPetsLabel.TextXAlignment = Enum.TextXAlignment.Left
                noPetsLabel.Parent = petsSection
                petsHeight = 22
            end
            petsSection.Size = UDim2.new(1, -8, 0, petsHeight)
            petsSection.Visible = true
            container.Size = UDim2.new(1, -8, 0, 36 + petsHeight)
            task.spawn(function()
                task.wait(10)
                if isExpanded and expandId == currentExpandId then
                    isExpanded = false
                    petsSection.Visible = false
                    petsSection.Size = UDim2.new(1, -8, 0, 0)
                    container.Size = UDim2.new(1, -8, 0, 32)
                    task.wait(0.05)
                    local totalHeight = 8
                    for _, child in ipairs(UI.richestListFrame:GetChildren()) do
                        if child:IsA('Frame') then
                            totalHeight = totalHeight + child.AbsoluteSize.Y + 3
                        end
                    end
                    UI.richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
                end
            end)
        end
        task.wait(0.05)
        local totalHeight = 8
        for _, child in ipairs(UI.richestListFrame:GetChildren()) do
            if child:IsA('Frame') then
                totalHeight = totalHeight + child.AbsoluteSize.Y + 3
            end
        end
        UI.richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
    end)
    return container
end
local function refreshRichestPlayers(forceRefresh)
    if RefreshState.isRefreshing then return end
    local currentTime = tick()
    if not forceRefresh and (currentTime - RefreshState.lastRefreshTime) < RefreshState.REFRESH_COOLDOWN then
        return
    end
    local isFullRefresh = forceRefresh or (currentTime - RefreshState.lastFullRefreshTime) >= RefreshState.FULL_REFRESH_INTERVAL
    RefreshState.isRefreshing = true
    RefreshState.lastRefreshTime = currentTime
    if isFullRefresh then
        RefreshState.lastFullRefreshTime = currentTime
    end
    local localPlayer = Services.Players.LocalPlayer
    local currentPlayers = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if player ~= localPlayer then
            currentPlayers[player.Name] = player
        end
    end
    local existingNames = getExistingPlayerNames()
    for playerName in pairs(existingNames) do
        if not currentPlayers[playerName] then
            removePlayerFromList(playerName)
            for i, data in ipairs(UIState.richestData) do
                if data.playerName == playerName then
                    table.remove(UIState.richestData, i)
                    break
                end
            end
        end
    end
    if forceRefresh then
        for _, child in ipairs(UI.richestListFrame:GetChildren()) do
            if child:IsA('Frame') then child:Destroy() end
        end
        UIState.expandedPlayers = {}
        UIState.richestData = {}
        RefreshState.playerContainers = {}
        existingNames = {}
        local loadingLabel = Instance.new('TextLabel')
        loadingLabel.Size = UDim2.new(1, -8, 0, 30)
        loadingLabel.BackgroundTransparency = 1
        loadingLabel.Text = '⏳ Scanning players...'
        loadingLabel.Font = Enum.Font.FredokaOne
        loadingLabel.TextSize = 11
        loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
        loadingLabel.LayoutOrder = 0
        loadingLabel.Name = 'LoadingLabel'
        loadingLabel.Parent = UI.richestListFrame
    end
    task.spawn(function()
        local playersToFetch = {}
        if isFullRefresh then
            for playerName, player in pairs(currentPlayers) do
                table.insert(playersToFetch, player)
            end
            if not forceRefresh then
                UIState.richestData = {}
            end
        else
            for playerName, player in pairs(currentPlayers) do
                if not existingNames[playerName] then
                    table.insert(playersToFetch, player)
                end
            end
        end
        for _, player in ipairs(playersToFetch) do
            local success, profileData = pcall(function()
                return fetchProfile:InvokeServer(player.UserId)
            end)
            local totalValue = 0
            local allPets = {}
            if success and profileData then
                local processedData = processRawProfileData(profileData)
                allPets = extractAllPets(processedData)
                for _, pet in ipairs(allPets) do totalValue = totalValue + pet.value end
            end
            local playerData = { playerName = player.Name, totalValue = totalValue, pets = allPets, player = player }
            RefreshState.playerCache[player.Name] = { totalValue = totalValue, pets = allPets, player = player, lastUpdated = tick() }
            if isFullRefresh and not forceRefresh then
                table.insert(UIState.richestData, playerData)
            else
                local found = false
                for i, data in ipairs(UIState.richestData) do
                    if data.playerName == player.Name then
                        UIState.richestData[i] = playerData
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(UIState.richestData, playerData)
                end
            end
        end
        local loadingLabel = UI.richestListFrame:FindFirstChild('LoadingLabel')
        if loadingLabel then loadingLabel:Destroy() end
        table.sort(UIState.richestData, function(a, b) return a.totalValue > b.totalValue end)
        local displayCount = math.min(#UIState.richestData, 35)
        local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
        for i = 1, displayCount do
            local data = UIState.richestData[i]
            local existingContainer = UI.richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
            if not existingContainer then
                createRichestPlayerButton(data, i)
                RefreshState.playerContainers[data.playerName] = true
            else
                existingContainer.LayoutOrder = i
                local rankBadge = existingContainer:FindFirstChildOfClass('TextLabel')
                if rankBadge and rankBadge.Size == UDim2.new(0, 20, 0, 20) then
                    rankBadge.Text = tostring(i)
                    rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                end
                local mainBtn = existingContainer:FindFirstChildOfClass('TextButton')
                if mainBtn and mainBtn.BackgroundTransparency == 1 then
                    local valLabel = mainBtn:FindFirstChild('TextLabel')
                    if not valLabel then
                        for _, child in ipairs(mainBtn:GetChildren()) do
                            if child:IsA('TextLabel') and child.TextXAlignment == Enum.TextXAlignment.Right then
                                child.Text = formatValue(data.totalValue)
                                break
                            end
                        end
                    end
                end
            end
        end
        for i = displayCount + 1, #UIState.richestData do
            local data = UIState.richestData[i]
            local container = UI.richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
            if container then container:Destroy() end
        end
        updateCanvasSize()
        if forceRefresh and Apps.HintApp then
            Apps.HintApp:hint({ text = 'Updated ' .. #UIState.richestData .. ' players!', length = 2, overridable = true })
        end
        RefreshState.isRefreshing = false
    end)
end
local function autoRefreshCheck()
    if not RefreshState.autoRefreshEnabled then return end
    refreshRichestPlayers(false)
end
task.spawn(function()
    while true do
        task.wait(10)
        autoRefreshCheck()
    end
end)
UI.refreshRichestButton.MouseButton1Click:Connect(function()
    refreshRichestPlayers(true)
end)
UI.autoRefreshButton.MouseButton1Click:Connect(function()
    RefreshState.autoRefreshEnabled = not RefreshState.autoRefreshEnabled
    if RefreshState.autoRefreshEnabled then
        UI.autoRefreshButton.Text = 'Auto: ON'
        UI.autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        refreshRichestPlayers(true)
    else
        UI.autoRefreshButton.Text = 'Auto: OFF'
        UI.autoRefreshButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
end)
Services.Players.PlayerAdded:Connect(function(player)
    if RefreshState.autoRefreshEnabled then
        task.wait(1)
        if player ~= Services.Players.LocalPlayer then
            task.spawn(function()
                local success, profileData = pcall(function()
                    return fetchProfile:InvokeServer(player.UserId)
                end)
                local totalValue = 0
                local allPets = {}
                if success and profileData then
                    local processedData = processRawProfileData(profileData)
                    allPets = extractAllPets(processedData)
                    for _, pet in ipairs(allPets) do totalValue = totalValue + pet.value end
                end
                local playerData = { playerName = player.Name, totalValue = totalValue, pets = allPets, player = player }
                RefreshState.playerCache[player.Name] = { totalValue = totalValue, pets = allPets, player = player, lastUpdated = tick() }
                table.insert(UIState.richestData, playerData)
                table.sort(UIState.richestData, function(a, b) return a.totalValue > b.totalValue end)
                local newIndex = 1
                for i, data in ipairs(UIState.richestData) do
                    if data.playerName == player.Name then newIndex = i break end
                end
                if newIndex <= 35 then
                    createRichestPlayerButton(playerData, newIndex)
                    RefreshState.playerContainers[player.Name] = true
                    local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
                    for i, data in ipairs(UIState.richestData) do
                        if i <= 35 then
                            local container = UI.richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                            if container then
                                container.LayoutOrder = i
                                local rankBadge = container:FindFirstChildOfClass('TextLabel')
                                if rankBadge and rankBadge.Size == UDim2.new(0, 20, 0, 20) then
                                    rankBadge.Text = tostring(i)
                                    rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                                end
                            end
                        end
                    end
                    updateCanvasSize()
                end
            end)
        end
    end
end)
Services.Players.PlayerRemoving:Connect(function(player)
    if RefreshState.autoRefreshEnabled then
        removePlayerFromList(player.Name)
        for i, data in ipairs(UIState.richestData) do
            if data.playerName == player.Name then
                table.remove(UIState.richestData, i)
                break
            end
        end
        local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
        for i, data in ipairs(UIState.richestData) do
            if i <= 35 then
                local container = UI.richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
                if container then
                    container.LayoutOrder = i
                    local rankBadge = container:FindFirstChildOfClass('TextLabel')
                    if rankBadge and rankBadge.Size == UDim2.new(0, 20, 0, 20) then
                        rankBadge.Text = tostring(i)
                        rankBadge.BackgroundColor3 = rankColors[i] or Color3.fromRGB(80, 80, 100)
                    end
                end
            end
        end
        updateCanvasSize()
    end
end)
local function createPlayerButton(player, index, isSelected)
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 32)
    button.BackgroundColor3 = isSelected and Color3.fromRGB(50, 80, 100) or Color3.fromRGB(40, 40, 50)
    button.BackgroundTransparency = 0.2
    button.Text = ''
    button.LayoutOrder = index
    button.Parent = UI.playerListFrame
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 4)
    local buttonStroke = Instance.new('UIStroke')
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = isSelected and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(80, 80, 80)
    buttonStroke.Thickness = 1.0
    buttonStroke.Parent = button
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(1, -30, 1, 0)
    nameLabel.Position = UDim2.new(0, 4, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = player.Name
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = button
    local checkBox = Instance.new('Frame')
    checkBox.Size = UDim2.new(0, 20, 0, 20)
    checkBox.Position = UDim2.new(1, -25, 0.5, -10)
    checkBox.BackgroundColor3 = isSelected and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 70)
    checkBox.BackgroundTransparency = 0.2
    checkBox.Visible = UIState.selectionMode
    checkBox.Parent = button
    Instance.new('UICorner', checkBox).CornerRadius = UDim.new(0, 4)
    local checkBoxStroke = Instance.new('UIStroke')
    checkBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    checkBoxStroke.Color = isSelected and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 80)
    checkBoxStroke.Thickness = 1.0
    checkBoxStroke.Parent = checkBox
    local checkMark = Instance.new('TextLabel')
    checkMark.Size = UDim2.new(1, 0, 1, 0)
    checkMark.BackgroundTransparency = 1
    checkMark.Text = '✓'
    checkMark.Font = Enum.Font.FredokaOne
    checkMark.TextSize = 14
    checkMark.TextColor3 = Color3.fromRGB(255, 255, 255)
    checkMark.Visible = isSelected
    checkMark.Parent = checkBox
    button.MouseButton1Click:Connect(function()
        if UIState.selectionMode then
            local isNowSelected = not UIState.selectedPlayers[player.Name]
            UIState.selectedPlayers[player.Name] = isNowSelected
            checkBox.BackgroundColor3 = isNowSelected and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 70)
            checkBoxStroke.Color = isNowSelected and Color3.fromRGB(100, 255, 100) or Color3.fromRGB(80, 80, 80)
            checkMark.Visible = isNowSelected
            button.BackgroundColor3 = isNowSelected and Color3.fromRGB(50, 80, 100) or Color3.fromRGB(40, 40, 50)
            buttonStroke.Color = isNowSelected and Color3.fromRGB(100, 150, 255) or Color3.fromRGB(80, 80, 80)
        elseif mockState.active and mockState.trade then
            BlockPlayer(player)
        else
            setActiveTab('Control')
            partnerBox.Text = player.Name
            updatePartnerFromUsername(player.Name)
        end
    end)
    return button, checkBox
end
local function createSelectFromTradeButton()
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 32)
    button.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
    button.BackgroundTransparency = 0.2
    button.Text = ''
    button.Name = 'SelectFromTradeButton'
    button.LayoutOrder = -999
    button.Parent = UI.playerListFrame
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 4)
    local nameLabel = Instance.new('TextLabel')
    nameLabel.Size = UDim2.new(1, -8, 1, 0)
    nameLabel.Position = UDim2.new(0, 4, 0, 0)
    nameLabel.BackgroundTransparency = 1
    nameLabel.Text = 'Select Partner From Trade'
    nameLabel.Font = Enum.Font.FredokaOne
    nameLabel.TextSize = 12
    nameLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
    nameLabel.TextXAlignment = Enum.TextXAlignment.Left
    nameLabel.Parent = button
    button.MouseButton1Click:Connect(function()
        setActiveTab('Control')
        pcall(function()
            local tradePart = Services.Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Header.PartnerFrame.NameLabel.Text
            for _, player in ipairs(Services.Players:GetPlayers()) do
                if player.Name:lower() == tradePart:lower() then
                    partnerBox.Text = player.Name
                    updatePartnerFromUsername(player.Name)
                    break
                end
            end
        end)
    end)
    return button
end
local function refreshPlayerList()
    for _, child in ipairs(UI.playerListFrame:GetChildren()) do
        if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then child:Destroy() end
    end
    UIState.playerListButtons = {}
    local searchText = UI.playerSearchBox.Text:lower()
    local filteredPlayers = {}
    for _, player in ipairs(Services.Players:GetPlayers()) do
        if searchText == '' or player.Name:lower():sub(1, #searchText) == searchText then
            table.insert(filteredPlayers, player)
        end
    end
    table.sort(filteredPlayers, function(a, b) return a.Name:lower() < b.Name:lower() end)
    for i, player in ipairs(filteredPlayers) do
        local isSelected = UIState.selectedPlayers[player.Name] == true
        local button = createPlayerButton(player, i, isSelected)
        table.insert(UIState.playerListButtons, button)
    end
    UI.playerListFrame.CanvasSize = UDim2.new(0, 0, 0, (#filteredPlayers * 36) + 40)
end
UI.playerSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshPlayerList)
UI.selectPlayersButton.MouseButton1Click:Connect(function()
    UIState.selectionMode = not UIState.selectionMode
    if UIState.selectionMode then
        UI.selectPlayersButton.Text = 'Cancel Selection'
        UI.selectPlayersButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
        UI.selectPlayersStroke.Color = Color3.fromRGB(255, 100, 100)
    else
        UI.selectPlayersButton.Text = 'Select Services.Players'
        UI.selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
        UI.selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
        UIState.selectedPlayers = {}
    end
    for _, child in ipairs(UI.playerListFrame:GetChildren()) do
        if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then
            local checkBox = child:FindFirstChildOfClass('Frame')
            if checkBox then checkBox.Visible = UIState.selectionMode end
        end
    end
end)
UI.blockSelectedButton.MouseButton1Click:Connect(function()
    if not UIState.selectionMode then return end
    local count = 0
    for playerName, isSelected in pairs(UIState.selectedPlayers) do
        if isSelected then
            local player = Services.Players:FindFirstChild(playerName)
            if player then
                pcall(function() BlockPlayer(player) count = count + 1 end)
                task.wait(1.5)
            end
        end
    end
    UIState.selectionMode = false
    UI.selectPlayersButton.Text = 'Select Services.Players'
    UI.selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
    UI.selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
    UIState.selectedPlayers = {}
    refreshPlayerList()
end)
refreshPlayerList()
createSelectFromTradeButton()
Services.Players.PlayerAdded:Connect(refreshPlayerList)
Services.Players.PlayerRemoving:Connect(refreshPlayerList)
UI.petsFrame = UIState.tabFrames['Pets']
UI.petInputSection = Instance.new('Frame')
UI.petInputSection.Size = UDim2.new(1, 0, 0, 190)
UI.petInputSection.Position = UDim2.new(0, 0, 0, 0)
UI.petInputSection.BackgroundTransparency = 1
UI.petInputSection.Parent = UI.petsFrame
UI.petNameHeading = Instance.new('TextLabel')
UI.petNameHeading.Size = UDim2.new(1, 0, 0, 16)
UI.petNameHeading.BackgroundTransparency = 1
UI.petNameHeading.Text = 'Pet Name To Add'
UI.petNameHeading.Font = Enum.Font.SourceSansSemibold
UI.petNameHeading.TextSize = 11
UI.petNameHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.petNameHeading.TextXAlignment = Enum.TextXAlignment.Left
UI.petNameHeading.Parent = UI.petInputSection
UI.petNameBox = Instance.new('TextBox')
UI.petNameBox.Size = UDim2.new(1, 0, 0, 26)
UI.petNameBox.Position = UDim2.new(0, 0, 0, 18)
UI.petNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
UI.petNameBox.BackgroundTransparency = 0.2
UI.petNameBox.Text = ''
UI.petNameBox.PlaceholderText = 'Enter pet name...'
UI.petNameBox.Font = Enum.Font.FredokaOne
UI.petNameBox.TextSize = 11
UI.petNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.petNameBox.ClearTextOnFocus = false
UI.petNameBox.Parent = UI.petInputSection
Instance.new('UICorner', UI.petNameBox).CornerRadius = UDim.new(0, 4)
UI.petNameStroke = Instance.new('UIStroke')
UI.petNameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
UI.petNameStroke.Color = Color3.fromRGB(100, 100, 100)
UI.petNameStroke.Thickness = 0.8
UI.petNameStroke.Transparency = 0.5
UI.petNameStroke.Parent = UI.petNameBox
UI.propContainer = Instance.new('Frame')
UI.propContainer.Size = UDim2.new(1, 0, 0, 26)
UI.propContainer.Position = UDim2.new(0, 0, 0, 49)
UI.propContainer.BackgroundTransparency = 1
UI.propContainer.Parent = UI.petInputSection
local prefixes = { 'M', 'N', 'F', 'R' }
local prefixColors = {
    M = Color3.fromRGB(170, 0, 255),
    N = Color3.fromRGB(0, 255, 100),
    F = Color3.fromRGB(0, 200, 255),
    R = Color3.fromRGB(255, 50, 150),
}
local prefixButtons = {}
for i, prefix in ipairs(prefixes) do
    local prefixButton = Instance.new('TextButton')
    prefixButton.Size = UDim2.new(0.23, 0, 1, 0)
    prefixButton.Position = UDim2.new((i - 1) * 0.25 + 0.01, 0, 0, 0)
    prefixButton.Text = prefix
    prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
    prefixButton.BackgroundTransparency = 0.2
    prefixButton.Font = Enum.Font.FredokaOne
    prefixButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    prefixButton.TextSize = 13
    prefixButton.Parent = UI.propContainer
    Instance.new('UICorner', prefixButton).CornerRadius = UDim.new(0, 4)
    local buttonStroke = Instance.new('UIStroke')
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = prefixColors[prefix]
    buttonStroke.Thickness = 1.0
    buttonStroke.Transparency = 0.5
    buttonStroke.Parent = prefixButton
    prefixButtons[prefix] = { button = prefixButton, stroke = buttonStroke }
    prefixButton.MouseButton1Click:Connect(function()
        if prefix == 'M' and petSpawnState.activeFlags['N'] then return end
        if prefix == 'N' and petSpawnState.activeFlags['M'] then return end
        petSpawnState.activeFlags[prefix] = not petSpawnState.activeFlags[prefix]
        if petSpawnState.activeFlags[prefix] then
            prefixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
            Services.TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = Color3.fromRGB(0, 255, 0), Thickness = 1.2, Transparency = 0.2 }):Play()
        else
            prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
            Services.TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = prefixColors[prefix], Thickness = 1.0, Transparency = 0.5 }):Play()
        end
    end)
end
UI.addPetDelayText = Instance.new('TextLabel')
UI.addPetDelayText.Size = UDim2.new(1, 0, 0, 14)
UI.addPetDelayText.Position = UDim2.new(0, 0, 0, 68)
UI.addPetDelayText.BackgroundTransparency = 1
UI.addPetDelayText.Text = 'Add Pet Delay (s)'
UI.addPetDelayText.Font = Enum.Font.SourceSansSemibold
UI.addPetDelayText.TextSize = 10
UI.addPetDelayText.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.addPetDelayText.TextXAlignment = Enum.TextXAlignment.Left
UI.addPetDelayText.Parent = UI.petInputSection
UI.requestAddPetBox = Instance.new('TextBox')
UI.requestAddPetBox.Size = UDim2.new(1, 0, 0, 24)
UI.requestAddPetBox.Position = UDim2.new(0, 0, 0, 82)
UI.requestAddPetBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
UI.requestAddPetBox.BackgroundTransparency = 0.2
UI.requestAddPetBox.Text = tostring(CONFIG.ADD_PET_REQUEST_DELAY)
UI.requestAddPetBox.Font = Enum.Font.SourceSans
UI.requestAddPetBox.TextSize = 12
UI.requestAddPetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.requestAddPetBox.ClearTextOnFocus = false
UI.requestAddPetBox.TextXAlignment = Enum.TextXAlignment.Center
UI.requestAddPetBox.Parent = UI.petInputSection
Instance.new('UICorner', UI.requestAddPetBox).CornerRadius = UDim.new(0, 4)
UI.requestAddPetBox.FocusLost:Connect(function()
    local value = tonumber(UI.requestAddPetBox.Text)
    if value and value >= 0 then CONFIG.ADD_PET_REQUEST_DELAY = value else UI.requestAddPetBox.Text = tostring(CONFIG.ADD_PET_REQUEST_DELAY) end
end)
UI.addPetButton = Instance.new('TextButton')
UI.addPetButton.Size = UDim2.new(1, 0, 0, 26)
UI.addPetButton.Position = UDim2.new(0, 0, 0, 114)
UI.addPetButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
UI.addPetButton.BackgroundTransparency = 0.2
UI.addPetButton.Text = 'Add Pet to Trade'
UI.addPetButton.Font = Enum.Font.FredokaOne
UI.addPetButton.TextSize = 12
UI.addPetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.addPetButton.Parent = UI.petInputSection
Instance.new('UICorner', UI.addPetButton).CornerRadius = UDim.new(0, 4)
UI.addPetButton.MouseButton1Click:Connect(function()
    local petName = UI.petNameBox.Text
    if petName and petName ~= '' then addPetToPartnerOffer(petName, petSpawnState.activeFlags) end
end)
UI.removePetButton2 = Instance.new('TextButton')
UI.removePetButton2.Size = UDim2.new(1, 0, 0, 26)
UI.removePetButton2.Position = UDim2.new(0, 0, 0, 145)
UI.removePetButton2.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
UI.removePetButton2.BackgroundTransparency = 0.2
UI.removePetButton2.Text = 'Remove Latest Pet'
UI.removePetButton2.Font = Enum.Font.FredokaOne
UI.removePetButton2.TextSize = 12
UI.removePetButton2.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.removePetButton2.Parent = UI.petInputSection
Instance.new('UICorner', UI.removePetButton2).CornerRadius = UDim.new(0, 4)
UI.removePetButton2.MouseButton1Click:Connect(removeLatestPetFromPartnerOffer)
UI.addRandomPetButton = Instance.new('TextButton')
UI.addRandomPetButton.Size = UDim2.new(1, 0, 0, 26)
UI.addRandomPetButton.Position = UDim2.new(0, 0, 0, 176)
UI.addRandomPetButton.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
UI.addRandomPetButton.BackgroundTransparency = 0.2
UI.addRandomPetButton.Text = 'Add Random High-Value Pet'
UI.addRandomPetButton.Font = Enum.Font.FredokaOne
UI.addRandomPetButton.TextSize = 10
UI.addRandomPetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.addRandomPetButton.Parent = UI.petInputSection
Instance.new('UICorner', UI.addRandomPetButton).CornerRadius = UDim.new(0, 4)
UI.addRandomPetButton.MouseButton1Click:Connect(function()
    addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
end)
UI.petListSection = Instance.new('Frame')
UI.petListSection.Size = UDim2.new(1, 0, 0, 400)
UI.petListSection.Position = UDim2.new(0, 0, 0, 195)
UI.petListSection.BackgroundTransparency = 1
UI.petListSection.Parent = UI.petsFrame
UI.petListHeading = Instance.new('TextLabel')
UI.petListHeading.Size = UDim2.new(1, 0, 0, 16)
UI.petListHeading.BackgroundTransparency = 1
UI.petListHeading.Text = 'High-Value Pets (Balloon Unicorn+)'
UI.petListHeading.Font = Enum.Font.SourceSansSemibold
UI.petListHeading.TextSize = 11
UI.petListHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.petListHeading.TextXAlignment = Enum.TextXAlignment.Left
UI.petListHeading.Parent = UI.petListSection
UI.petListFrame = Instance.new('ScrollingFrame')
UI.petListFrame.Size = UDim2.new(1, 0, 0, 380)
UI.petListFrame.Position = UDim2.new(0, 0, 0, 18)
UI.petListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
UI.petListFrame.BackgroundTransparency = 0.5
UI.petListFrame.BorderSizePixel = 0
UI.petListFrame.ScrollBarThickness = 4
UI.petListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
UI.petListFrame.ScrollBarImageTransparency = 0.5
UI.petListFrame.Parent = UI.petListSection
Instance.new('UICorner', UI.petListFrame).CornerRadius = UDim.new(0, 4)
UI.petListLayout = Instance.new('UIListLayout')
UI.petListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.petListLayout.Padding = UDim.new(0, 3)
UI.petListLayout.Parent = UI.petListFrame
UI.petListPadding2 = Instance.new('UIPadding')
UI.petListPadding2.PaddingTop = UDim.new(0, 4)
UI.petListPadding2.PaddingBottom = UDim.new(0, 4)
UI.petListPadding2.PaddingLeft = UDim.new(0, 4)
UI.petListPadding2.PaddingRight = UDim.new(0, 4)
UI.petListPadding2.Parent = UI.petListFrame
for i, petName in ipairs(completePetList) do
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    button.BackgroundTransparency = 0.1
    button.Text = petName
    button.Font = Enum.Font.GothamBold
    button.TextSize = 10
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.LayoutOrder = i
    button.Parent = UI.petListFrame
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 6)
    local buttonStroke = Instance.new('UIStroke')
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = Color3.fromRGB(255, 200, 50)
    buttonStroke.Thickness = 1.5
    buttonStroke.Transparency = 0.2
    buttonStroke.Parent = button
    button.MouseEnter:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
    end)
    button.MouseLeave:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
    end)
    button.MouseButton1Click:Connect(function()
        UI.petNameBox.Text = petName
        Services.TweenService:Create(UI.petNameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Color = Color3.fromRGB(255, 200, 50), Thickness = 1.5 }):Play()
        task.wait(0.5)
        Services.TweenService:Create(UI.petNameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Color = Color3.fromRGB(100, 100, 100), Thickness = 0.8 }):Play()
    end)
end
UI.petListFrame.CanvasSize = UDim2.new(0,0, 0, (#completePetList * 31) + 8)
UI.usersFrame = UIState.tabFrames['Users']
UI.userSearchBox = Instance.new('TextBox')
UI.userSearchBox.Size = UDim2.new(1, 0, 0, 26)
UI.userSearchBox.Position = UDim2.new(0, 0, 0, 0)
UI.userSearchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
UI.userSearchBox.BackgroundTransparency = 0.2
UI.userSearchBox.Text = ''
UI.userSearchBox.PlaceholderText = 'Search users...'
UI.userSearchBox.Font = Enum.Font.SourceSans
UI.userSearchBox.TextSize = 12
UI.userSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.userSearchBox.ClearTextOnFocus = false
UI.userSearchBox.TextXAlignment = Enum.TextXAlignment.Left
UI.userSearchBox.Parent = UI.usersFrame
Instance.new('UICorner', UI.userSearchBox).CornerRadius = UDim.new(0, 4)
UI.userListFrame = Instance.new('ScrollingFrame')
UI.userListFrame.Size = UDim2.new(1, 0, 0, 180)
UI.userListFrame.Position = UDim2.new(0, 0, 0, 30)
UI.userListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
UI.userListFrame.BackgroundTransparency = 0.5
UI.userListFrame.BorderSizePixel = 0
UI.userListFrame.ScrollBarThickness = 4
UI.userListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
UI.userListFrame.ScrollBarImageTransparency = 0.5
UI.userListFrame.Parent = UI.usersFrame
Instance.new('UICorner', UI.userListFrame).CornerRadius = UDim.new(0, 4)
UI.userListLayout = Instance.new('UIListLayout')
UI.userListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.userListLayout.Padding = UDim.new(0, 3)
UI.userListLayout.Parent = UI.userListFrame
UI.userListPadding = Instance.new('UIPadding')
UI.userListPadding.PaddingTop = UDim.new(0, 4)
UI.userListPadding.PaddingBottom = UDim.new(0, 4)
UI.userListPadding.PaddingLeft = UDim.new(0, 4)
UI.userListPadding.PaddingRight = UDim.new(0, 4)
UI.userListPadding.Parent = UI.userListFrame
UI.chatHeading = Instance.new('TextLabel')
UI.chatHeading.Size = UDim2.new(1, 0, 0, 16)
UI.chatHeading.Position = UDim2.new(0, 0, 0, 215)
UI.chatHeading.BackgroundTransparency = 1
UI.chatHeading.Text = 'Chat Messages'
UI.chatHeading.Font = Enum.Font.SourceSansSemibold
UI.chatHeading.TextSize = 11
UI.chatHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.chatHeading.TextXAlignment = Enum.TextXAlignment.Left
UI.chatHeading.Parent = UI.usersFrame
UI.customMessageBox = Instance.new('TextBox')
UI.customMessageBox.Size = UDim2.new(1, 0, 0, 26)
UI.customMessageBox.Position = UDim2.new(0, 0, 0, 233)
UI.customMessageBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
UI.customMessageBox.BackgroundTransparency = 0.2
UI.customMessageBox.Text = ''
UI.customMessageBox.PlaceholderText = 'Enter custom message...'
UI.customMessageBox.Font = Enum.Font.SourceSans
UI.customMessageBox.TextSize = 12
UI.customMessageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.customMessageBox.ClearTextOnFocus = false
UI.customMessageBox.TextXAlignment = Enum.TextXAlignment.Left
UI.customMessageBox.Parent = UI.usersFrame
Instance.new('UICorner', UI.customMessageBox).CornerRadius = UDim.new(0, 4)
UI.sendMessageButton = Instance.new('TextButton')
UI.sendMessageButton.Size = UDim2.new(1, 0, 0, 26)
UI.sendMessageButton.Position = UDim2.new(0, 0, 0, 263)
UI.sendMessageButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
UI.sendMessageButton.BackgroundTransparency = 0.2
UI.sendMessageButton.Text = 'Send Chat Message'
UI.sendMessageButton.Font = Enum.Font.FredokaOne
UI.sendMessageButton.TextSize = 12
UI.sendMessageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
UI.sendMessageButton.Parent = UI.usersFrame
Instance.new('UICorner', UI.sendMessageButton).CornerRadius = UDim.new(0, 4)
UI.sendMessageButton.MouseButton1Click:Connect(function()
    local message = UI.customMessageBox.Text
    if message and message ~= '' then
        sendTradeChatMessage(message)
        UI.customMessageBox.Text = ''
    end
end)
UI.chatListHeading = Instance.new('TextLabel')
UI.chatListHeading.Size = UDim2.new(1, 0, 0, 16)
UI.chatListHeading.Position = UDim2.new(0, 0, 0, 295)
UI.chatListHeading.BackgroundTransparency = 1
UI.chatListHeading.Text = 'Quick Messages'
UI.chatListHeading.Font = Enum.Font.SourceSansSemibold
UI.chatListHeading.TextSize = 11
UI.chatListHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
UI.chatListHeading.TextXAlignment = Enum.TextXAlignment.Left
UI.chatListHeading.Parent = UI.usersFrame
UI.chatListFrame = Instance.new('ScrollingFrame')
UI.chatListFrame.Size = UDim2.new(1, 0, 0, 300)
UI.chatListFrame.Position = UDim2.new(0, 0, 0, 313)
UI.chatListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
UI.chatListFrame.BackgroundTransparency = 0.5
UI.chatListFrame.BorderSizePixel = 0
UI.chatListFrame.ScrollBarThickness = 4
UI.chatListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
UI.chatListFrame.ScrollBarImageTransparency = 0.5
UI.chatListFrame.Parent = UI.usersFrame
Instance.new('UICorner', UI.chatListFrame).CornerRadius = UDim.new(0, 4)
UI.chatListLayout = Instance.new('UIListLayout')
UI.chatListLayout.SortOrder = Enum.SortOrder.LayoutOrder
UI.chatListLayout.Padding = UDim.new(0, 3)
UI.chatListLayout.Parent = UI.chatListFrame
UI.chatListPadding = Instance.new('UIPadding')
UI.chatListPadding.PaddingTop = UDim.new(0, 4)
UI.chatListPadding.PaddingBottom = UDim.new(0, 4)
UI.chatListPadding.PaddingLeft = UDim.new(0, 4)
UI.chatListPadding.PaddingRight = UDim.new(0, 4)
UI.chatListPadding.Parent = UI.chatListFrame
for i, message in ipairs(CONFIG.CHAT_MESSAGES) do
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 24)
    button.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    button.BackgroundTransparency = 0.1
    button.Text = '  ' .. message
    button.Font = Enum.Font.GothamMedium
    button.TextSize = 10
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextTruncate = Enum.TextTruncate.AtEnd
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.LayoutOrder = i
    button.Parent = UI.chatListFrame
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 5)
    local buttonStroke = Instance.new('UIStroke')
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = Color3.fromRGB(255, 200, 50)
    buttonStroke.Thickness = 1.5
    buttonStroke.Transparency = 0.2
    buttonStroke.Parent = button
    button.MouseEnter:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
    end)
    button.MouseLeave:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
    end)
    button.MouseButton1Click:Connect(function()
        sendTradeChatMessage(message)
    end)
end
UI.chatListFrame.CanvasSize = UDim2.new(0, 0, 0, (#CONFIG.CHAT_MESSAGES * 27) + 8)
local function createUserButton(username, index)
    local button = Instance.new('TextButton')
    button.Size = UDim2.new(1, -8, 0, 28)
    button.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    button.BackgroundTransparency = 0.1
    button.Text = '  ' .. username
    button.Font = Enum.Font.GothamBold
    button.TextSize = 11
    button.TextColor3 = Color3.fromRGB(255, 255, 255)
    button.TextXAlignment = Enum.TextXAlignment.Left
    button.LayoutOrder = index
    button.Parent = UI.userListFrame
    Instance.new('UICorner', button).CornerRadius = UDim.new(0, 6)
    local buttonStroke = Instance.new('UIStroke')
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = Color3.fromRGB(255, 200, 50)
    buttonStroke.Thickness = 1.5
    buttonStroke.Transparency = 0.2
    buttonStroke.Parent = button
    button.MouseEnter:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
    end)
    button.MouseLeave:Connect(function()
        Services.TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
        Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
    end)
    button.MouseButton1Click:Connect(function()
        setActiveTab('Control')
        partnerBox.Text = username
        updatePartnerFromUsername(username)
    end)
    return button
end
local function refreshUserList()
    for _, child in ipairs(UI.userListFrame:GetChildren()) do
        if child:IsA('TextButton') then child:Destroy() end
    end
    UIState.userListButtons = {}
    local searchText = UI.userSearchBox.Text:lower()
    local filteredUsers = {}
    for _, username in ipairs(customUsers) do
        if searchText == '' or username:lower():sub(1, #searchText) == searchText then
            table.insert(filteredUsers, username)
        end
    end
    table.sort(filteredUsers, function(a, b) return a:lower() < b:lower() end)
    for i, username in ipairs(filteredUsers) do
        local button = createUserButton(username, i)
        table.insert(UIState.userListButtons, button)
    end
    UI.userListFrame.CanvasSize = UDim2.new(0, 0, 0, (#filteredUsers * 29) + 8)
end
UI.userSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshUserList)
refreshUserList()
local RGBState = { hue = 0, speed = 0.5, enabled = true }
UI.setsFrame = UIState.tabFrames['Sets']
local SetsUI = { keybindButtons = {}, currentScale = 1.0 }
do
    local layout = Instance.new('UIListLayout')
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    layout.Padding = UDim.new(0, 6)
    layout.Parent = UI.setsFrame
    local padding = Instance.new('UIPadding')
    padding.PaddingTop = UDim.new(0, 8)
    padding.PaddingLeft = UDim.new(0, 4)
    padding.PaddingRight = UDim.new(0, 4)
    padding.Parent = UI.setsFrame
    local heading = Instance.new('TextLabel')
    heading.Size = UDim2.new(1, 0, 0, 20)
    heading.BackgroundTransparency = 1
    heading.Text = '⌨️ Keybind Settings'
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 14
    heading.TextColor3 = Color3.fromRGB(255, 200, 50)
    heading.TextXAlignment = Enum.TextXAlignment.Center
    heading.LayoutOrder = 0
    heading.Parent = UI.setsFrame
end
local function createKeybindRow(labelText, keybindKey, layoutOrder)
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    row.BackgroundTransparency = 0.1
    row.LayoutOrder = layoutOrder
    row.Parent = UI.setsFrame
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 200, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = row
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(0.6, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = labelText
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local btn = Instance.new('TextButton')
    btn.Size = UDim2.new(0.35, -8, 0, 26)
    btn.Position = UDim2.new(0.65, 0, 0.5, -13)
    btn.BackgroundColor3 = Color3.fromRGB(70, 65, 95)
    btn.BackgroundTransparency = 0.1
    btn.Text = UIState.keybinds[keybindKey].Name
    btn.Font = Enum.Font.GothamBold
    btn.TextSize = 11
    btn.TextColor3 = Color3.fromRGB(255, 255, 255)
    btn.Parent = row
    Instance.new('UICorner', btn).CornerRadius = UDim.new(0, 4)
    Instance.new('UIStroke', btn).Color = Color3.fromRGB(100, 100, 150)
    SetsUI.keybindButtons[keybindKey] = btn
    btn.MouseEnter:Connect(function()
        if UIState.waitingForKeybind ~= keybindKey then
            Services.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(90, 85, 120) }):Play()
        end
    end)
    btn.MouseLeave:Connect(function()
        if UIState.waitingForKeybind ~= keybindKey then
            Services.TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
        end
    end)
    btn.MouseButton1Click:Connect(function()
        if UIState.waitingForKeybind then
            local old = SetsUI.keybindButtons[UIState.waitingForKeybind]
            if old then old.Text = UIState.keybinds[UIState.waitingForKeybind].Name; old.BackgroundColor3 = Color3.fromRGB(70, 65, 95) end
        end
        UIState.waitingForKeybind = keybindKey
        btn.Text = '...'
        btn.BackgroundColor3 = Color3.fromRGB(100, 80, 150)
    end)
    return row
end
createKeybindRow('Select Partner from Trade', 'selectPartner', 1)
createKeybindRow('Add Random Item', 'addRandomItem', 2)
createKeybindRow('Start Trade', 'startTrade', 3)
createKeybindRow('Block Player', 'blockPlayer', 4)
createKeybindRow('Random User', 'randomUser', 5)
do
    local spacer = Instance.new('Frame')
    spacer.Size = UDim2.new(1, 0, 0, 10)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = 10
    spacer.Parent = UI.setsFrame
    local heading = Instance.new('TextLabel')
    heading.Size = UDim2.new(1, 0, 0, 18)
    heading.BackgroundTransparency = 1
    heading.Text = '🌈 RGB Settings'
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 12
    heading.TextColor3 = Color3.fromRGB(255, 200, 50)
    heading.TextXAlignment = Enum.TextXAlignment.Center
    heading.LayoutOrder = 11
    heading.Parent = UI.setsFrame
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    row.BackgroundTransparency = 0.1
    row.LayoutOrder = 12
    row.Parent = UI.setsFrame
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 200, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = row
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(0.5, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = 'RGB Speed'
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local valueBox = Instance.new('TextBox')
    valueBox.Size = UDim2.new(0.2, 0, 0, 24)
    valueBox.Position = UDim2.new(0.5, 0, 0.5, -12)
    valueBox.BackgroundColor3 = Color3.fromRGB(70, 65, 95)
    valueBox.Text = '0.5'
    valueBox.Font = Enum.Font.GothamBold
    valueBox.TextSize = 11
    valueBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    valueBox.Parent = row
    Instance.new('UICorner', valueBox).CornerRadius = UDim.new(0, 4)
    local minusBtn = Instance.new('TextButton')
    minusBtn.Size = UDim2.new(0, 26, 0, 24)
    minusBtn.Position = UDim2.new(0.72, 0, 0.5, -12)
    minusBtn.BackgroundColor3 = Color3.fromRGB(150, 60, 60)
    minusBtn.Text = '-'
    minusBtn.Font = Enum.Font.GothamBold
    minusBtn.TextSize = 14
    minusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    minusBtn.Parent = row
    Instance.new('UICorner', minusBtn).CornerRadius = UDim.new(0, 4)
    local plusBtn = Instance.new('TextButton')
    plusBtn.Size = UDim2.new(0, 26, 0, 24)
    plusBtn.Position = UDim2.new(0.86, 0, 0.5, -12)
    plusBtn.BackgroundColor3 = Color3.fromRGB(60, 150, 60)
    plusBtn.Text = '+'
    plusBtn.Font = Enum.Font.GothamBold
    plusBtn.TextSize = 14
    plusBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    plusBtn.Parent = row
    Instance.new('UICorner', plusBtn).CornerRadius = UDim.new(0, 4)
    minusBtn.MouseButton1Click:Connect(function()
        local current = math.max(0.1, (tonumber(valueBox.Text) or 0.5) - 0.1)
        valueBox.Text = string.format('%.1f', current)
        RGBState.speed = current
    end)
    plusBtn.MouseButton1Click:Connect(function()
        local current = math.min(2.0, (tonumber(valueBox.Text) or 0.5) + 0.1)
        valueBox.Text = string.format('%.1f', current)
        RGBState.speed = current
    end)
    valueBox.FocusLost:Connect(function()
        local val = tonumber(valueBox.Text)
        if val then
            val = math.clamp(val, 0.1, 2.0)
            valueBox.Text = string.format('%.1f', val)
            RGBState.speed = val
        else
            valueBox.Text = '0.5'
            RGBState.speed = 0.5
        end
    end)
end
do
    local spacer = Instance.new('Frame')
    spacer.Size = UDim2.new(1, 0, 0, 10)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = 13
    spacer.Parent = UI.setsFrame
    local heading = Instance.new('TextLabel')
    heading.Size = UDim2.new(1, 0, 0, 18)
    heading.BackgroundTransparency = 1
    heading.Text = '🕐 Server Info'
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 12
    heading.TextColor3 = Color3.fromRGB(255, 200, 50)
    heading.TextXAlignment = Enum.TextXAlignment.Center
    heading.LayoutOrder = 14
    heading.Parent = UI.setsFrame
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 36)
    row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
    row.BackgroundTransparency = 0.1
    row.LayoutOrder = 15
    row.Parent = UI.setsFrame
    Instance.new('UICorner', row).CornerRadius = UDim.new(0, 6)
    local stroke = Instance.new('UIStroke')
    stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    stroke.Color = Color3.fromRGB(255, 200, 50)
    stroke.Thickness = 1.5
    stroke.Transparency = 0.2
    stroke.Parent = row
    local label = Instance.new('TextLabel')
    label.Size = UDim2.new(0.45, 0, 1, 0)
    label.Position = UDim2.new(0, 8, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = 'Server Uptime'
    label.Font = Enum.Font.GothamMedium
    label.TextSize = 11
    label.TextColor3 = Color3.fromRGB(255, 255, 255)
    label.TextXAlignment = Enum.TextXAlignment.Left
    label.Parent = row
    local valueLabel = Instance.new('TextLabel')
    valueLabel.Size = UDim2.new(0.5, -8, 1, 0)
    valueLabel.Position = UDim2.new(0.5, 0, 0, 0)
    valueLabel.BackgroundTransparency = 1
    valueLabel.Text = '0h 0m 0s'
    valueLabel.Font = Enum.Font.GothamBold
    valueLabel.TextSize = 11
    valueLabel.TextColor3 = Color3.fromRGB(100, 255, 150)
    valueLabel.TextXAlignment = Enum.TextXAlignment.Right
    valueLabel.Parent = row
    task.spawn(function()
        while true do
            local uptime = workspace.DistributedGameTime
            valueLabel.Text = string.format('%dh %dm %ds', math.floor(uptime/3600), math.floor((uptime%3600)/60), math.floor(uptime%60))
            task.wait(1)
        end
    end)
end
do
    local spacer = Instance.new('Frame')
    spacer.Size = UDim2.new(1, 0, 0, 10)
    spacer.BackgroundTransparency = 1
    spacer.LayoutOrder = 16
    spacer.Parent = UI.setsFrame
    local heading = Instance.new('TextLabel')
    heading.Size = UDim2.new(1, 0, 0, 18)
    heading.BackgroundTransparency = 1
    heading.Text = '📱 GUI Size (Mobile)'
    heading.Font = Enum.Font.GothamBold
    heading.TextSize = 12
    heading.TextColor3 = Color3.fromRGB(255, 200, 50)
    heading.TextXAlignment = Enum.TextXAlignment.Center
    heading.LayoutOrder = 17
    heading.Parent = UI.setsFrame
    local row = Instance.new('Frame')
    row.Size = UDim2.new(1, 0, 0, 40)
    row.BackgroundTransparency = 1
    row.LayoutOrder = 18
    row.Parent = UI.setsFrame
    local smallBtn = Instance.new('TextButton')
    smallBtn.Size = UDim2.new(0.48, 0, 1, 0)
    smallBtn.Position = UDim2.new(0, 0, 0, 0)
    smallBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
    smallBtn.Text = '🔍 Small'
    smallBtn.Font = Enum.Font.GothamBold
    smallBtn.TextSize = 12
    smallBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    smallBtn.Parent = row
    Instance.new('UICorner', smallBtn).CornerRadius = UDim.new(0, 6)
    local ss = Instance.new('UIStroke', smallBtn)
    ss.Color = Color3.fromRGB(255, 200, 50)
    ss.Thickness = 1.5
    ss.Transparency = 0.2
    local bigBtn = Instance.new('TextButton')
    bigBtn.Size = UDim2.new(0.48, 0, 1, 0)
    bigBtn.Position = UDim2.new(0.52, 0, 0, 0)
    bigBtn.BackgroundColor3 = Color3.fromRGB(60, 120, 80)
    bigBtn.Text = '🔎 Big'
    bigBtn.Font = Enum.Font.GothamBold
    bigBtn.TextSize = 12
    bigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
    bigBtn.Parent = row
    Instance.new('UICorner', bigBtn).CornerRadius = UDim.new(0, 6)
    local bs = Instance.new('UIStroke', bigBtn)
    bs.Color = Color3.fromRGB(255, 200, 50)
    bs.Thickness = 1.5
    bs.Transparency = 0.2
    local uiScale = UI.mainFrame:FindFirstChild('UIScale') or Instance.new('UIScale')
    uiScale.Name = 'UIScale'
    uiScale.Parent = UI.mainFrame
    smallBtn.MouseButton1Click:Connect(function()
        SetsUI.currentScale = math.max(0.7, SetsUI.currentScale - 0.05)
        uiScale.Scale = SetsUI.currentScale
        if Apps.HintApp then Apps.HintApp:hint({ text = 'GUI Scale: ' .. string.format('%.0f%%', SetsUI.currentScale * 100), length = 1, overridable = true }) end
    end)
    bigBtn.MouseButton1Click:Connect(function()
        SetsUI.currentScale = math.min(1.3, SetsUI.currentScale + 0.05)
        uiScale.Scale = SetsUI.currentScale
        if Apps.HintApp then Apps.HintApp:hint({ text = 'GUI Scale: ' .. string.format('%.0f%%', SetsUI.currentScale * 100), length = 1, overridable = true }) end
    end)
    smallBtn.MouseEnter:Connect(function() Services.TweenService:Create(smallBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 80, 150) }):Play() end)
    smallBtn.MouseLeave:Connect(function() Services.TweenService:Create(smallBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(80, 60, 120) }):Play() end)
    bigBtn.MouseEnter:Connect(function() Services.TweenService:Create(bigBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(80, 150, 100) }):Play() end)
    bigBtn.MouseLeave:Connect(function() Services.TweenService:Create(bigBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(60, 120, 80) }):Play() end)
end
do
    local PVC = { state = { M = false, N = false, F = false, R = false }, btns = {} }
    local colors = { M = {Color3.fromRGB(170,0,255), Color3.fromRGB(80,60,100)}, N = {Color3.fromRGB(255,215,0), Color3.fromRGB(80,60,100)}, F = {Color3.fromRGB(0,200,255), Color3.fromRGB(80,60,100)}, R = {Color3.fromRGB(0,255,100), Color3.fromRGB(80,60,100)} }
    local function fmtVal(v)
        if not v or v == 0 then return '?' end
        return v >= 1e9 and string.format('%.2fB',v/1e9) or (v >= 1e6 and string.format('%.2fM',v/1e6) or (v >= 1e3 and string.format('%.1fK',v/1e3) or tostring(v)))
    end
    Instance.new('Frame', UI.setsFrame).Size = UDim2.new(1,0,0,10); UI.setsFrame:GetChildren()[#UI.setsFrame:GetChildren()].BackgroundTransparency = 1; UI.setsFrame:GetChildren()[#UI.setsFrame:GetChildren()].LayoutOrder = 19
    local h = Instance.new('TextLabel', UI.setsFrame)
    h.Size, h.BackgroundTransparency, h.Text, h.Font, h.TextSize, h.TextColor3, h.TextXAlignment, h.LayoutOrder = UDim2.new(1,0,0,18), 1, '💎 Pet Value Calculator', Enum.Font.GothamBold, 12, Color3.fromRGB(255,200,50), Enum.TextXAlignment.Center, 20
    local ir = Instance.new('Frame', UI.setsFrame)
    ir.Size, ir.BackgroundColor3, ir.BackgroundTransparency, ir.LayoutOrder = UDim2.new(1,0,0,30), Color3.fromRGB(55,50,75), 0.1, 21
    Instance.new('UICorner', ir).CornerRadius = UDim.new(0,6)
    local irs = Instance.new('UIStroke', ir); irs.Color, irs.Thickness, irs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
    PVC.input = Instance.new('TextBox', ir)
    PVC.input.Size, PVC.input.Position, PVC.input.BackgroundTransparency, PVC.input.Text, PVC.input.PlaceholderText = UDim2.new(1,-16,1,-6), UDim2.new(0,8,0,3), 1, '', 'Enter pet name...'
    PVC.input.Font, PVC.input.TextSize, PVC.input.TextColor3, PVC.input.PlaceholderColor3, PVC.input.TextXAlignment, PVC.input.ClearTextOnFocus = Enum.Font.GothamMedium, 11, Color3.fromRGB(255,255,255), Color3.fromRGB(150,150,160), Enum.TextXAlignment.Left, false
    local pr = Instance.new('Frame', UI.setsFrame)
    pr.Size, pr.BackgroundTransparency, pr.LayoutOrder = UDim2.new(1,0,0,28), 1, 22
    for i, p in ipairs({'M','N','F','R'}) do
        local b = Instance.new('TextButton', pr)
        b.Size, b.Position, b.BackgroundColor3, b.Text, b.Font, b.TextSize, b.TextColor3 = UDim2.new(0.24,-4,1,0), UDim2.new((i-1)*0.25,2,0,0), colors[p][2], p, Enum.Font.GothamBold, 12, Color3.fromRGB(255,255,255)
        Instance.new('UICorner', b).CornerRadius = UDim.new(0,4)
        PVC.btns[p] = b
        b.MouseButton1Click:Connect(function()
            if p == 'M' then PVC.state.M = not PVC.state.M; if PVC.state.M then PVC.state.N = false end
            elseif p == 'N' then PVC.state.N = not PVC.state.N; if PVC.state.N then PVC.state.M = false end
            else PVC.state[p] = not PVC.state[p] end
            for k, v in pairs(PVC.btns) do v.BackgroundColor3 = PVC.state[k] and colors[k][1] or colors[k][2] end
        end)
    end
    local cb = Instance.new('TextButton', UI.setsFrame)
    cb.Size, cb.BackgroundColor3, cb.Text, cb.Font, cb.TextSize, cb.TextColor3, cb.LayoutOrder = UDim2.new(1,0,0,32), Color3.fromRGB(80,160,80), '📊 Calculate Value', Enum.Font.GothamBold, 12, Color3.fromRGB(255,255,255), 23
    Instance.new('UICorner', cb).CornerRadius = UDim.new(0,6)
    local cbs = Instance.new('UIStroke', cb); cbs.Color, cbs.Thickness, cbs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
    PVC.result = Instance.new('TextLabel', UI.setsFrame)
    PVC.result.Size, PVC.result.BackgroundColor3, PVC.result.Text, PVC.result.Font, PVC.result.TextSize, PVC.result.TextColor3, PVC.result.LayoutOrder = UDim2.new(1,0,0,36), Color3.fromRGB(40,35,55), 'Value: --', Enum.Font.GothamBold, 14, Color3.fromRGB(100,255,150), 24
    Instance.new('UICorner', PVC.result).CornerRadius = UDim.new(0,6)
    local rs = Instance.new('UIStroke', PVC.result); rs.Color, rs.Thickness, rs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
    cb.MouseButton1Click:Connect(function()
        local sn = PVC.input.Text:lower():gsub('^%s+',''):gsub('%s+$','')
        if sn == '' then PVC.result.Text, PVC.result.TextColor3 = 'Enter a pet name!', Color3.fromRGB(255,100,100) return end
        local fp, fk = nil, nil
        for k, pet in pairs(PetData.petsByName) do if k:lower():gsub('%s+','') == sn or k:lower():gsub('%s+',''):find(sn,1,true) then fp, fk = pet, k break end end
        if not fp then PVC.result.Text, PVC.result.TextColor3 = 'Pet not found!', Color3.fromRGB(255,100,100) return end
        local bk = PVC.state.M and 'mvalue' or (PVC.state.N and 'nvalue' or 'rvalue')
        local hasFly, hasRide = PVC.state.F, PVC.state.R
        local sf
        if hasFly and hasRide then sf = ' - fly&ride'
        elseif hasFly then sf = ' - fly'
        elseif hasRide then sf = ' - ride'
        else sf = ' - nopotion' end
        local v = fp[bk..sf] or fp[bk..' - fly&ride'] or fp[bk] or 0
        local fv = fmtVal(v)
        local ps = (PVC.state.M and 'M' or '')..(PVC.state.N and 'N' or '')..(PVC.state.F and 'F' or '')..(PVC.state.R and 'R' or '')
        if ps == '' then ps = 'NR' end
        PVC.result.Text, PVC.result.TextColor3 = fk..' ('..ps..'): '..fv, Color3.fromRGB(100,255,150)
    end)
    cb.MouseEnter:Connect(function() Services.TweenService:Create(cb, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(100,180,100)}):Play() end)
    cb.MouseLeave:Connect(function() Services.TweenService:Create(cb, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(80,160,80)}):Play() end)
end
UI.spawnerFrame = UIState.tabFrames['Spawner']
local SpawnerState = {
    activeFlags = {F = false, R = false, N = false, M = false},
    baseColors = {
        F = Color3.fromRGB(0, 200, 255),
        R = Color3.fromRGB(255, 50, 150),
        N = Color3.fromRGB(0, 255, 100),
        M = Color3.fromRGB(170, 0, 255)
    },
    COLORS = {
        NEUTRAL = Color3.fromRGB(220, 220, 255),
        VALID = Color3.fromRGB(120, 255, 150),
        INVALID = Color3.fromRGB(255, 120, 120)
    }
}
task.spawn(function()
    set_thread_identity(2)
    local items = Fsys.load("KindDB")
    local petRigs = Fsys.load("new:PetRigs")
    set_thread_identity(8)
    local SC = {
        petModels = {},
        pets = {},
        equippedPet = nil,
        mountedPet = nil,
        currentMountTrack = nil
    }
    local function updateData(key, action)
        local data = Modules.ClientData.get(key)
        local clonedData = table.clone(data)
        Modules.ClientData.predict(key, action(clonedData))
    end
    local function getUniqueId()
        return Services.HttpService:GenerateGUID(false)
    end
    local function getSpawnerPetModel(kind)
        if SC.petModels[kind] then return SC.petModels[kind] end
        local streamed = PetData.downloader.promise_download_copy("Pets", kind):expect()
        SC.petModels[kind] = streamed
        return streamed
    end
    local RARITY_ORDER = { legendary = 900000, ultra_rare = 700000, rare = 500000, uncommon = 300000, common = 100000 }
    local rarityCounters = { legendary = 0, ultra_rare = 0, rare = 0, uncommon = 0, common = 0 }
    local function getRarityNewness(kind)
        local entry = Modules.InventoryDB.pets and Modules.InventoryDB.pets[kind]
        local rarity = (entry and entry.rarity) or "common"
        local base = RARITY_ORDER[rarity] or 100000
        rarityCounters[rarity] = (rarityCounters[rarity] or 0) + 1
        return base + 99999 - rarityCounters[rarity]
    end
    local function createPet(id, properties)
        local uniqueId = getUniqueId()
        local item = items[id]
        if not item then return nil end
        set_thread_identity(2)
        local new_pet = {
            unique = uniqueId, category = "pets", id = id, kind = item.kind,
            newness_order = 0, properties = properties or {}
        }
        local inventory = Modules.ClientData.get("inventory")
        inventory.pets[uniqueId] = new_pet
        set_thread_identity(8)
        SC.pets[uniqueId] = { data = new_pet, model = nil }
        return new_pet
    end
    local function createToy(id)
        local uniqueId = getUniqueId()
        local item = items[id]
        if not item then warn("Toy ID not found: "..id) return nil end
        set_thread_identity(2)
        local new_toy = {
            unique = uniqueId, category = "toys", id = id, kind = item.kind,
            newness_order = math.random(1, 900000), properties = {}
        }
        local inventory = Modules.ClientData.get("inventory")
        inventory.toys[uniqueId] = new_toy
        set_thread_identity(8)
        return new_toy
    end
    local function neonify(model, entry)
        local petModel = model:FindFirstChild("PetModel")
        if not petModel then return end
        for neonPart, configuration in pairs(entry.neon_parts) do
            local trueNeonPart = petRigs.get(petModel).get_geo_part(petModel, neonPart)
            trueNeonPart.Material = configuration.Material
            trueNeonPart.Color = configuration.Color
        end
    end
    local function addPetWrapper(wrapper)
        updateData("pet_char_wrappers", function(petWrappers)
            wrapper.unique = #petWrappers + 1
            wrapper.index = #petWrappers + 1
            petWrappers[#petWrappers + 1] = wrapper
            return petWrappers
        end)
    end
    local function addPetState(state)
        updateData("pet_state_managers", function(petStates)
            petStates[#petStates + 1] = state
            return petStates
        end)
    end
    local function findIndex(array, finder)
        for index, value in pairs(array) do
            if finder(value, index) then return index end
        end
        return nil
    end
    local function removePetWrapper(uniqueId)
        updateData("pet_char_wrappers", function(petWrappers)
            local index = findIndex(petWrappers, function(wrapper) return wrapper.pet_unique == uniqueId end)
            if not index then return petWrappers end
            table.remove(petWrappers, index)
            for wrapperIndex, wrapper in pairs(petWrappers) do
                wrapper.unique = wrapperIndex
                wrapper.index = wrapperIndex
            end
            return petWrappers
        end)
    end
    local function clearPetState(uniqueId)
        local pet = SC.pets[uniqueId]
        if not pet or not pet.model then return end
        updateData("pet_state_managers", function(states)
            local index = findIndex(states, function(state) return state.char == pet.model end)
            if not index then return states end
            local clonedStates = table.clone(states)
            clonedStates[index] = table.clone(clonedStates[index])
            clonedStates[index].states = {}
            return clonedStates
        end)
    end
    local function setPetState(uniqueId, id)
        local pet = SC.pets[uniqueId]
        if not pet or not pet.model then return end
        updateData("pet_state_managers", function(states)
            local index = findIndex(states, function(state) return state.char == pet.model end)
            if not index then return states end
            local clonedStates = table.clone(states)
            clonedStates[index] = table.clone(clonedStates[index])
            clonedStates[index].states = {{ id = id }}
            return clonedStates
        end)
    end
    local function attachPlayerToPet(pet)
        local character = Services.Players.LocalPlayer.Character
        if not character or not character.PrimaryPart then return false end
        local ridePosition = pet:FindFirstChild("RidePosition", true)
        if not ridePosition then return false end
        local sourceAttachment = Instance.new("Attachment")
        sourceAttachment.Parent = ridePosition
        sourceAttachment.Position = Vector3.new(0, 1.237, 0)
        sourceAttachment.Name = "SourceAttachment"
        local stateConnection = Instance.new("RigidConstraint")
        stateConnection.Name = "StateConnection"
        stateConnection.Attachment0 = sourceAttachment
        stateConnection.Attachment1 = character.PrimaryPart.RootAttachment
        stateConnection.Parent = character
        return true
    end
    local function clearPlayerState()
        updateData("state_manager", function(state)
            local clonedState = table.clone(state)
            clonedState.states = {}
            clonedState.is_sitting = false
            return clonedState
        end)
    end
    local function setPlayerState(id)
        updateData("state_manager", function(state)
            local clonedState = table.clone(state)
            clonedState.states = {{ id = id }}
            clonedState.is_sitting = true
            return clonedState
        end)
    end
    local function removePetState(uniqueId)
        local pet = SC.pets[uniqueId]
        if not pet or not pet.model then return end
        updateData("pet_state_managers", function(petStates)
            local index = findIndex(petStates, function(state) return state.char == pet.model end)
            if not index then return petStates end
            table.remove(petStates, index)
            return petStates
        end)
    end
    local function unmount(uniqueId)
        local pet = SC.pets[uniqueId]
        if not pet or not pet.model then return end
        if SC.currentMountTrack then
            SC.currentMountTrack:Stop()
            SC.currentMountTrack:Destroy()
        end
        local sourceAttachment = pet.model:FindFirstChild("SourceAttachment", true)
        if sourceAttachment then sourceAttachment:Destroy() end
        if Services.Players.LocalPlayer.Character then
            for _, descendant in pairs(Services.Players.LocalPlayer.Character:GetDescendants()) do
                if descendant:IsA("BasePart") and descendant:GetAttribute("HaveMass") then
                    descendant.Massless = false
                end
            end
        end
        clearPetState(uniqueId)
        clearPlayerState()
        pet.model:ScaleTo(1)
        SC.mountedPet = nil
    end
    local function mount(uniqueId, playerState, petState)
        local pet = SC.pets[uniqueId]
        if not pet or not pet.model then return end
        local player = Services.Players.LocalPlayer
        if not player.Character or not player.Character.PrimaryPart then return end
        SC.mountedPet = uniqueId
        setPetState(uniqueId, petState)
        setPlayerState(playerState)
        pet.model:ScaleTo(2)
        attachPlayerToPet(pet.model)
        SC.currentMountTrack = player.Character.Humanoid.Animator:LoadAnimation(Modules.animationManager.get_track("PlayerRidingPet"))
        player.Character.Humanoid.Sit = true
        for _, descendant in pairs(player.Character:GetDescendants()) do
            if descendant:IsA("BasePart") and descendant.Massless == false then
                descendant.Massless = true
                descendant:SetAttribute("HaveMass", true)
            end
        end
        SC.currentMountTrack:Play()
    end
    local function fly(uniqueId) mount(uniqueId, "PlayerFlyingPet", "PetBeingFlown") end
    local function ride(uniqueId) mount(uniqueId, "PlayerRidingPet", "PetBeingRidden") end
    local function unequip(item)
        local pet = SC.pets[item.unique]
        if not pet or not pet.model then return end
        unmount(item.unique)
        removePetWrapper(item.unique)
        removePetState(item.unique)
        pet.model:Destroy()
        pet.model = nil
        SC.equippedPet = nil
    end
    local function equip(item)
        if item.category == "pets" then
            if SC.equippedPet then unequip(SC.equippedPet) end
            local petModel = getSpawnerPetModel(item.kind):Clone()
            petModel.Parent = workspace
            SC.pets[item.unique].model = petModel
            if item.properties.neon or item.properties.mega_neon then
                neonify(petModel, items[item.kind])
            end
            SC.equippedPet = item
            addPetWrapper({
                char = petModel, mega_neon = item.properties.mega_neon, neon = item.properties.neon,
                player = Services.Players.LocalPlayer, entity_controller = Services.Players.LocalPlayer,
                controller = Services.Players.LocalPlayer, rp_name = item.properties.rp_name or "",
                pet_trick_level = item.properties.pet_trick_level, pet_unique = item.unique,
                pet_id = item.id,
                location = { full_destination_id = "housing", destination_id = "housing", house_owner = Services.Players.LocalPlayer },
                pet_progression = { age = math.random(1, 900000), percentage = math.random(0.01, 0.99) },
                are_colors_sealed = false, is_pet = true
            })
            addPetState({
                char = petModel, player = Services.Players.LocalPlayer, store_key = "pet_state_managers",
                is_sitting = false, chars_connected_to_me = {}, states = {}
            })
        else
            return oldGet("ToolAPI/Equip"):InvokeServer(item.unique)
        end
    end
    local oldGet = Modules.RouterClient.get
    local function createRemoteFunctionMock(callback)
        return { InvokeServer = function(_, ...) return callback(...) end }
    end
    local function createRemoteEventMock(callback)
        return { FireServer = function(_, ...) return callback(...) end }
    end
    local equipRemote = createRemoteFunctionMock(function(uniqueId, metadata)
        local pet = SC.pets[uniqueId]
        if pet then
            equip(pet.data)
            return true, { action = "equip", is_server = true }
        end
        return oldGet("ToolAPI/Equip"):InvokeServer(uniqueId, metadata)
    end)
    local unequipRemote = createRemoteFunctionMock(function(uniqueId)
        local pet = SC.pets[uniqueId]
        if pet then
            unequip(pet.data)
            return true, { action = "unequip", is_server = true }
        end
        return oldGet("ToolAPI/Unequip"):InvokeServer(uniqueId)
    end)
    local rideRemote = createRemoteFunctionMock(function(item) ride(item.pet_unique) end)
    local flyRemote = createRemoteFunctionMock(function(item) fly(item.pet_unique) end)
    local unmountRemoteFunction = createRemoteFunctionMock(function() unmount(SC.mountedPet) end)
    local unmountRemoteEvent = createRemoteEventMock(function() unmount(SC.mountedPet) end)
    Modules.RouterClient.get = function(name)
        if name == "ToolAPI/Equip" then return equipRemote
        elseif name == "ToolAPI/Unequip" then return unequipRemote
        elseif name == "AdoptAPI/RidePet" then return rideRemote
        elseif name == "AdoptAPI/FlyPet" then return flyRemote
        elseif name == "AdoptAPI/ExitSeatStatesYield" then return unmountRemoteFunction
        elseif name == "AdoptAPI/ExitSeatStates" then return unmountRemoteEvent
        end
        return oldGet(name)
    end
    for _, charWrapper in pairs(Modules.ClientData.get("pet_char_wrappers")) do
        oldGet("ToolAPI/Unequip"):InvokeServer(charWrapper.pet_unique)
    end
    local function GetPetByName(name)
        for i,v in pairs(Modules.InventoryDB.pets) do
            if v.name:lower() == name:lower() then return v.id end
        end
        return false
    end
    local function GetToyByName(name)
        for i,v in pairs(Modules.InventoryDB.toys) do
            if v.name:lower() == name:lower() then return v.id end
        end
        return false
    end
    local spawnerLayout = Instance.new('UIListLayout')
    spawnerLayout.SortOrder = Enum.SortOrder.LayoutOrder
    spawnerLayout.Padding = UDim.new(0, 4)
    spawnerLayout.Parent = UI.spawnerFrame
    local spawnerPadding = Instance.new('UIPadding')
    spawnerPadding.PaddingTop = UDim.new(0, 4)
    spawnerPadding.PaddingLeft = UDim.new(0, 4)
    spawnerPadding.PaddingRight = UDim.new(0, 4)
    spawnerPadding.Parent = UI.spawnerFrame
    local subTabFrame = Instance.new("Frame")
    subTabFrame.Size = UDim2.new(1, 0, 0, 30)
    subTabFrame.BackgroundTransparency = 1
    subTabFrame.LayoutOrder = 1
    subTabFrame.Parent = UI.spawnerFrame
    local petTab = Instance.new("TextButton")
    petTab.Size = UDim2.new(0.49, 0, 1, 0)
    petTab.Position = UDim2.new(0, 0, 0, 0)
    petTab.Text = "Pets"
    petTab.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    petTab.BackgroundTransparency = 0.1
    petTab.Font = Enum.Font.FredokaOne
    petTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    petTab.TextSize = 16
    petTab.Parent = subTabFrame
    Instance.new("UICorner", petTab).CornerRadius = UDim.new(0, 6)
    do
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255,255,255); s.Thickness = 1.5; s.Transparency = 0.1; s.Parent = petTab
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.5; ts.Parent = petTab
    end
    local toyTab = Instance.new("TextButton")
    toyTab.Size = UDim2.new(0.49, 0, 1, 0)
    toyTab.Position = UDim2.new(0.51, 0, 0, 0)
    toyTab.Text = "Toys"
    toyTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    toyTab.BackgroundTransparency = 0.1
    toyTab.Font = Enum.Font.FredokaOne
    toyTab.TextColor3 = Color3.fromRGB(255, 255, 255)
    toyTab.TextSize = 16
    toyTab.Parent = subTabFrame
    Instance.new("UICorner", toyTab).CornerRadius = UDim.new(0, 6)
    do
        local s = Instance.new("UIStroke"); s.Color = Color3.fromRGB(255,255,255); s.Thickness = 1.5; s.Transparency = 0.1; s.Parent = toyTab
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.5; ts.Parent = toyTab
    end
    local petContent = Instance.new("Frame")
    petContent.Size = UDim2.new(1, 0, 0, 500)
    petContent.BackgroundTransparency = 1
    petContent.Visible = true
    petContent.LayoutOrder = 2
    petContent.Parent = UI.spawnerFrame
    local toyContent = Instance.new("Frame")
    toyContent.Size = UDim2.new(1, 0, 0, 200)
    toyContent.BackgroundTransparency = 1
    toyContent.Visible = false
    toyContent.LayoutOrder = 3
    toyContent.Parent = UI.spawnerFrame
    petTab.MouseButton1Click:Connect(function()
        petContent.Visible = true
        toyContent.Visible = false
        petTab.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
        toyTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
    end)
    toyTab.MouseButton1Click:Connect(function()
        petContent.Visible = false
        toyContent.Visible = true
        petTab.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
        toyTab.BackgroundColor3 = Color3.fromRGB(80, 80, 100)
    end)
    UI.petNameBox = Instance.new("TextBox")
    UI.petNameBox.Size = UDim2.new(0.85, 0, 0, 28)
    UI.petNameBox.Position = UDim2.new(0.075, 0, 0, 10)
    UI.petNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    UI.petNameBox.BackgroundTransparency = 0.2
    UI.petNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    UI.petNameBox.TextSize = 14
    UI.petNameBox.Font = Enum.Font.FredokaOne
    UI.petNameBox.PlaceholderText = "Enter Pet Name to Spawn"
    UI.petNameBox.Text = ""
    UI.petNameBox.ClearTextOnFocus = false
    UI.petNameBox.Parent = petContent
    Instance.new("UICorner", UI.petNameBox).CornerRadius = UDim.new(0, 6)
    do
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.2; ts.Parent = UI.petNameBox
    end
    local boxGlow = Instance.new("UIStroke")
    boxGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    boxGlow.Color = Color3.fromRGB(255, 255, 255)
    boxGlow.Thickness = 2.2
    boxGlow.Transparency = 0.25
    boxGlow.Parent = UI.petNameBox
    local validPetNames = {}
    local validPetNamesClean = {}
    do
        for id, item in pairs(Modules.InventoryDB.pets) do
            validPetNames[#validPetNames + 1] = item.name
            validPetNamesClean[#validPetNamesClean + 1] = item.name:lower():gsub("%s+", "")
        end
    end
    local currentColorTween = nil
    local lastCursorPosition = 1
    local function capitalizeWords(str)
        local result = ""
        local i = 1
        local n = #str
        while i <= n do
            if str:sub(i, i):match("%S") then
                local wordStart = i
                while i <= n and str:sub(i, i):match("%S") do i = i + 1 end
                local word = str:sub(wordStart, i-1)
                if #word > 0 then word = word:sub(1,1):upper()..word:sub(2):lower() end
                result = result..word
            else
                result = result..str:sub(i, i)
                i = i + 1
            end
        end
        return result
    end
    local function setGlowColor(targetColor)
        if currentColorTween then currentColorTween:Cancel() end
        currentColorTween = Services.TweenService:Create(boxGlow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = targetColor})
        currentColorTween:Play()
    end
    UI.petNameBox:GetPropertyChangedSignal("Text"):Connect(function()
        lastCursorPosition = UI.petNameBox.CursorPosition
        local inputText = UI.petNameBox.Text
        local newText = capitalizeWords(inputText)
        if newText ~= inputText then
            UI.petNameBox.Text = newText
            local addedChars = #newText - #inputText
            UI.petNameBox.CursorPosition = math.max(1, math.min(lastCursorPosition + addedChars, #newText + 1))
            return
        end
        local displayedText = UI.petNameBox.Text
        local cleanName = displayedText:lower():gsub("%s+", "")
        local isExactMatch = false
        local isCleanMatch = false
        for _, name in ipairs(validPetNames) do
            if name:lower() == displayedText:lower() then isExactMatch = true break end
        end
        isCleanMatch = table.find(validPetNamesClean, cleanName) ~= nil
        local targetColor
        if displayedText == "" then targetColor = SpawnerState.COLORS.NEUTRAL
        elseif isExactMatch or isCleanMatch then targetColor = SpawnerState.COLORS.VALID
        else targetColor = SpawnerState.COLORS.INVALID end
        setGlowColor(targetColor)
    end)
    setGlowColor(SpawnerState.COLORS.NEUTRAL)
    local prefixes = {"F", "R", "N", "M"}
    local toggleButtonWidth = 0.18
    local toggleSpacing = 0.07
    local toggleTotalWidth = #prefixes * toggleButtonWidth + (#prefixes - 1) * toggleSpacing
    local toggleStartX = (1 - toggleTotalWidth) / 2
    for i, prefix in ipairs(prefixes) do
        local prefixButton = Instance.new("TextButton")
        prefixButton.Size = UDim2.new(toggleButtonWidth, 0, 0, 25)
        prefixButton.Position = UDim2.new(toggleStartX + (toggleButtonWidth + toggleSpacing) * (i - 1), 0, 0, 50)
        prefixButton.Text = prefix
        prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
        prefixButton.BackgroundTransparency = 0.2
        prefixButton.Font = Enum.Font.FredokaOne
        prefixButton.TextColor3 = Color3.fromRGB(255, 255, 255)
        prefixButton.TextSize = 16
        prefixButton.Parent = petContent
        Instance.new("UICorner", prefixButton).CornerRadius = UDim.new(0, 6)
        local btnStroke = Instance.new("UIStroke")
        btnStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
        btnStroke.Color = SpawnerState.baseColors[prefix]
        btnStroke.Thickness = 2
        btnStroke.Transparency = 0.5
        btnStroke.Parent = prefixButton
        local btnTextStroke = Instance.new("UIStroke")
        btnTextStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
        btnTextStroke.Color = Color3.new(0, 0, 0)
        btnTextStroke.Thickness = 1.5
        btnTextStroke.Transparency = 0
        btnTextStroke.Parent = prefixButton
        local origStroke = { Color = SpawnerState.baseColors[prefix], Thickness = 2, Transparency = 0.5 }
        prefixButton.MouseButton1Click:Connect(function()
            if prefix == "M" and SpawnerState.activeFlags["N"] then return end
            if prefix == "N" and SpawnerState.activeFlags["M"] then return end
            SpawnerState.activeFlags[prefix] = not SpawnerState.activeFlags[prefix]
            if SpawnerState.activeFlags[prefix] then
                prefixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
                Services.TweenService:Create(btnStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                    Color = Color3.fromRGB(0, 255, 0), Thickness = 3, Transparency = 0.2
                }):Play()
            else
                prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
                Services.TweenService:Create(btnStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
                    Color = origStroke.Color, Thickness = origStroke.Thickness, Transparency = origStroke.Transparency
                }):Play()
            end
            updateInfoBox(SpawnerState.activeFlags)
        end)
    end
    local infoBox = Instance.new("Frame")
    infoBox.Name = "InfoBox"
    infoBox.Size = UDim2.new(0.85, 0, 0, 30)
    infoBox.Position = UDim2.new(0.075, 0, 0, 90)
    infoBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    infoBox.BackgroundTransparency = 0.5
    infoBox.BorderSizePixel = 0
    infoBox.Parent = petContent
    Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 8)
    local infoBoxStroke = Instance.new("UIStroke")
    infoBoxStroke.Color = Color3.fromRGB(255, 255, 255)
    infoBoxStroke.Thickness = 1.2
    infoBoxStroke.Transparency = 0.7
    infoBoxStroke.Parent = infoBox
    local infoTextContainer = Instance.new("Frame")
    infoTextContainer.Name = "TextContainer"
    infoTextContainer.Size = UDim2.new(1, 0, 1, 0)
    infoTextContainer.BackgroundTransparency = 1
    infoTextContainer.Parent = infoBox
    local infoLayout = Instance.new("UIListLayout")
    infoLayout.FillDirection = Enum.FillDirection.Horizontal
    infoLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
    infoLayout.VerticalAlignment = Enum.VerticalAlignment.Center
    infoLayout.Padding = UDim.new(0, 4)
    infoLayout.Parent = infoTextContainer
    local animationSystem = { pulsePhase = 0, pulseSpeed = 2, baseThickness = 1.2, maxThickness = 3, activeColors = nil, active = false }
    local function updateAnimation(dt)
        if not animationSystem.active then return end
        animationSystem.pulsePhase = animationSystem.pulsePhase + dt * animationSystem.pulseSpeed
        local pulse = (math.sin(animationSystem.pulsePhase) + 1) * 0.5
        infoBoxStroke.Thickness = animationSystem.baseThickness + (animationSystem.maxThickness - animationSystem.baseThickness) * pulse
        infoBoxStroke.Transparency = 0.7 - (0.5 * pulse)
        if animationSystem.activeColors then
            local brightness = 0.8 + (0.4 * pulse)
            local r, g, b = 0, 0, 0
            for _, color in ipairs(animationSystem.activeColors) do
                r = r + (color.R * brightness); g = g + (color.G * brightness); b = b + (color.B * brightness)
            end
            infoBoxStroke.Color = Color3.new(
                math.min(r / #animationSystem.activeColors, 1),
                math.min(g / #animationSystem.activeColors, 1),
                math.min(b / #animationSystem.activeColors, 1)
            )
        end
    end
    local function createTextLabel(text, color)
        local label = Instance.new("TextLabel")
        label.Size = UDim2.new(0, 0, 1, 0)
        label.AutomaticSize = Enum.AutomaticSize.X
        label.BackgroundTransparency = 1
        label.Text = text
        label.Font = Enum.Font.FredokaOne
        label.TextSize = 16
        label.TextColor3 = color
        label.TextXAlignment = Enum.TextXAlignment.Left
        label.TextYAlignment = Enum.TextYAlignment.Center
        if text == "Mega Neon" then
            label.Text = "Mega Neon"
        elseif text ~= "Ride" and text ~= "Neon" and text ~= "Fly" then
            label.Text = label.Text .. " "
        end
        return label
    end
    function updateInfoBox(activeFlags)
        for _, child in ipairs(infoTextContainer:GetChildren()) do
            if child:IsA("TextLabel") then child:Destroy() end
        end
        local activeColors = {}
        local hasFlags = false
        local labels = {}
        if activeFlags["M"] then table.insert(labels, {"Mega Neon", SpawnerState.baseColors.M}); table.insert(activeColors, SpawnerState.baseColors.M); hasFlags = true end
        if activeFlags["N"] then table.insert(labels, {"Neon", SpawnerState.baseColors.N}); table.insert(activeColors, SpawnerState.baseColors.N); hasFlags = true end
        if activeFlags["F"] then table.insert(labels, {"Fly", SpawnerState.baseColors.F}); table.insert(activeColors, SpawnerState.baseColors.F); hasFlags = true end
        if activeFlags["R"] then table.insert(labels, {"Ride", SpawnerState.baseColors.R}); table.insert(activeColors, SpawnerState.baseColors.R); hasFlags = true end
        for _, labelData in ipairs(labels) do createTextLabel(labelData[1], labelData[2]).Parent = infoTextContainer end
        if hasFlags then
            animationSystem.active = true
            animationSystem.activeColors = activeColors
        else
            animationSystem.active = false
            createTextLabel("Normal", Color3.fromRGB(255, 255, 255)).Parent = infoTextContainer
            infoBoxStroke.Color = Color3.fromRGB(255, 255, 255)
            infoBoxStroke.Thickness = animationSystem.baseThickness
            infoBoxStroke.Transparency = 0.7
        end
    end
    Services.RunService.Heartbeat:Connect(updateAnimation)
    updateInfoBox({F = false, R = false, N = false, M = false})
    local highTierPets = {
        "Shadow Dragon", "Bat Dragon", "Frost Dragon", "Giraffe", "Owl", "Parrot",
        "Crow", "Evil Unicorn", "Arctic Reindeer", "Hedgehog", "Dalmatian", "Turtle",
        "Kangaroo", "Lion", "Cupid Dragon", "Undead Jousting Horse", "Diamond Amazon",
        "Glacier Moth", "Midnight Dragon", "Cabbit", "Sakura Spirit", "Arctic Dusk Dragon",
        "Elephant", "Dango Penguins", "Cryptid", "Jekyll Hydra", "Chocolate Chip Bat Dragon",
        "Cow", "Mermicorn", "Vampire Dragon", "Christmas Pudding Pup", "Blazing Lion",
        "African Wild Dog", "Flamingo", "Diamond Butterfly", "Mini Pig", "Caterpillar",
        "Albino Monkey", "Candyfloss Chick", "Pelican", "Blue Dog", "Pink Cat", "Haetae",
        "Peppermint Penguin", "Winged Tiger", "Sugar Glider", "Shark Puppy", "Goat",
        "Sheeeeep", "Frost Fury", "Lion Cub", "Nessie", "Flamingo", "Frostbite Bear",
        "Balloon Unicorn", "Honey Badger", "Hot Doggo", "Crocodile", "Hare", "Ram", "Yeti",
        "Lava Dragon", "Meerkat", "Jellyfish", "Happy Clam", "Orchid Butterfly",
        "Many Mackerel", "Strawberry Shortcake Bat Dragon", "Zombie Buffalo",
        "Fairy Bat Dragon", "Giant Panda", "Pirate Ghost Capuchin Monkey",
        "Dragonfruit Fox", "Rose Dragon", "Silverback Gorilla", "Velocirooster", "Pineapple Owl",
    }
    local highTierButton = Instance.new("TextButton")
    highTierButton.Size = UDim2.new(0.6, 0, 0, 25)
    highTierButton.Position = UDim2.new(0.2, 0, 0, 135)
    highTierButton.Text = "Spawn High Tier"
    highTierButton.BackgroundColor3 = Color3.fromRGB(200, 0, 200)
    highTierButton.BackgroundTransparency = 0.1
    highTierButton.Font = Enum.Font.FredokaOne
    highTierButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    highTierButton.TextSize = 16
    highTierButton.Parent = petContent
    Instance.new("UICorner", highTierButton).CornerRadius = UDim.new(0, 8)
    local highTierStroke = Instance.new("UIStroke")
    highTierStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    highTierStroke.Color = Color3.fromRGB(255, 255, 255)
    highTierStroke.Thickness = 1.5
    highTierStroke.Transparency = 0.1
    highTierStroke.Parent = highTierButton
    do
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.5; ts.Parent = highTierButton
    end
    local highTierOriginalProperties = {
        BackgroundColor3 = highTierButton.BackgroundColor3,
        StrokeColor = Color3.fromRGB(255, 255, 255),
        StrokeThickness = 1.5,
        StrokeTransparency = 0.1
    }
    local highTierActiveAnimation = { endTime = 0, strokeTween = nil, resetThread = nil, intensity = 1.0 }
    highTierButton.MouseEnter:Connect(function()
        if highTierActiveAnimation.endTime < os.clock() then
            highTierButton.BackgroundColor3 = Color3.fromRGB(220, 0, 220)
            Services.TweenService:Create(highTierStroke, TweenInfo.new(0.2), { Thickness = 2, Transparency = 0.05 }):Play()
        end
    end)
    highTierButton.MouseLeave:Connect(function()
        if highTierActiveAnimation.endTime < os.clock() then
            highTierButton.BackgroundColor3 = highTierOriginalProperties.BackgroundColor3
            Services.TweenService:Create(highTierStroke, TweenInfo.new(0.2), { Thickness = highTierOriginalProperties.StrokeThickness, Transparency = highTierOriginalProperties.StrokeTransparency }):Play()
        end
    end)
    highTierButton.MouseButton1Click:Connect(function()
        local currentTime = os.clock()
        local extendDuration = 1.5
        local isExtension = currentTime < highTierActiveAnimation.endTime
        if isExtension then
            highTierActiveAnimation.intensity = math.min(highTierActiveAnimation.intensity + 0.3, 1.5)
        else
            highTierActiveAnimation.intensity = 1.0
        end
        if highTierActiveAnimation.strokeTween then highTierActiveAnimation.strokeTween:Cancel() end
        if highTierActiveAnimation.resetThread then coroutine.close(highTierActiveAnimation.resetThread) end
        local feedbackColor = Color3.fromRGB(255, 50, 50)
        local spawnSuccess = false
        for _, petName in ipairs(highTierPets) do
            local petId = GetPetByName(petName)
            if petId then
                local props = {
                    pet_trick_level = math.random(1, 5),
                    mega_neon = SpawnerState.activeFlags['M'] or nil,
                    neon = (not SpawnerState.activeFlags['M'] and SpawnerState.activeFlags['N']) or nil,
                    rideable = SpawnerState.activeFlags['R'],
                    flyable = SpawnerState.activeFlags['F'],
                    age = math.random(1, 900000),
                    ailments_completed = 0,
                    rp_name = ""
                }
                if not SpawnerState.activeFlags['M'] and not SpawnerState.activeFlags['N'] then
                    props.neon = false; props.mega_neon = false
                end
                createPet(petId, props)
                spawnSuccess = true
            end
        end
        if spawnSuccess then
            feedbackColor = Color3.fromRGB(0, 255 * highTierActiveAnimation.intensity, 0)
            game.StarterGui:SetCore("SendNotification", { Title = "High Tier Pets Spawned!", Text = "All high tier pets have been spawned!", Duration = 5 })
        else
            game.StarterGui:SetCore("SendNotification", { Title = "Error", Text = "Failed to spawn high tier pets!", Duration = 3 })
        end
        highTierStroke.Color = feedbackColor
        highTierStroke.Thickness = 2 * highTierActiveAnimation.intensity
        highTierStroke.Transparency = 0.1 / highTierActiveAnimation.intensity
        if isExtension then
            highTierActiveAnimation.strokeTween = Services.TweenService:Create(highTierStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Thickness = 2.5 * highTierActiveAnimation.intensity, Transparency = 0.05 / highTierActiveAnimation.intensity })
            highTierActiveAnimation.strokeTween:Play()
        end
        highTierActiveAnimation.endTime = currentTime + extendDuration
        highTierActiveAnimation.resetThread = task.delay(extendDuration, function()
            if os.clock() >= highTierActiveAnimation.endTime then
                Services.TweenService:Create(highTierStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Color = highTierOriginalProperties.StrokeColor, Thickness = highTierOriginalProperties.StrokeThickness, Transparency = highTierOriginalProperties.StrokeTransparency }):Play()
            end
        end)
    end)
    local startButton = Instance.new("TextButton")
    startButton.Size = UDim2.new(0.6, 0, 0, 25)
    startButton.Position = UDim2.new(0.2, 0, 0, 175)
    startButton.Text = "Spawn Pet"
    startButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
    startButton.BackgroundTransparency = 0.1
    startButton.Font = Enum.Font.FredokaOne
    startButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    startButton.TextSize = 16
    startButton.Parent = petContent
    Instance.new("UICorner", startButton).CornerRadius = UDim.new(0, 8)
    local buttonStroke = Instance.new("UIStroke")
    buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    buttonStroke.Color = Color3.fromRGB(255, 255, 255)
    buttonStroke.Thickness = 1.5
    buttonStroke.Transparency = 0.1
    buttonStroke.Parent = startButton
    do
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.5; ts.Parent = startButton
    end
    local originalProperties = {
        BackgroundColor3 = startButton.BackgroundColor3,
        StrokeColor = Color3.fromRGB(255, 255, 255),
        StrokeThickness = 1.5,
        StrokeTransparency = 0.1
    }
    local activeAnimation = { endTime = 0, strokeTween = nil, resetThread = nil, intensity = 1.0, lastSuccess = false }
    startButton.MouseEnter:Connect(function()
        if activeAnimation.endTime < os.clock() then
            startButton.BackgroundColor3 = Color3.fromRGB(0, 130, 230)
            Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Thickness = 2, Transparency = 0.05 }):Play()
        end
    end)
    startButton.MouseLeave:Connect(function()
        if activeAnimation.endTime < os.clock() then
            startButton.BackgroundColor3 = originalProperties.BackgroundColor3
            Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Thickness = originalProperties.StrokeThickness, Transparency = originalProperties.StrokeTransparency }):Play()
        end
    end)
    startButton.MouseButton1Click:Connect(function()
        local pet_name = UI.petNameBox.Text
        local currentTime = os.clock()
        local extendDuration = 1.5
        local isExtension = currentTime < activeAnimation.endTime
        if isExtension then
            activeAnimation.intensity = math.min(activeAnimation.intensity + 0.3, 1.5)
        else
            activeAnimation.intensity = 1.0
        end
        if activeAnimation.strokeTween then activeAnimation.strokeTween:Cancel() end
        if activeAnimation.resetThread then coroutine.close(activeAnimation.resetThread) end
        local feedbackColor = Color3.fromRGB(255, 50, 50)
        local spawnSuccess = false
        if pet_name ~= "" then
            local petId = GetPetByName(pet_name)
            if petId then
                local props = {
                    pet_trick_level = math.random(1, 5),
                    mega_neon = SpawnerState.activeFlags['M'] or nil,
                    neon = (not SpawnerState.activeFlags['M'] and SpawnerState.activeFlags['N']) or nil,
                    rideable = SpawnerState.activeFlags['R'],
                    flyable = SpawnerState.activeFlags['F'],
                    age = math.random(1, 900000),
                    ailments_completed = 0,
                    rp_name = ""
                }
                if not SpawnerState.activeFlags['M'] and not SpawnerState.activeFlags['N'] then
                    props.neon = false; props.mega_neon = false
                end
                createPet(petId, props)
                spawnSuccess = true
                game.StarterGui:SetCore("SendNotification", { Title = "Pet Spawned!", Text = pet_name .. " has been spawned!", Duration = 5 })
            else
                game.StarterGui:SetCore("SendNotification", { Title = "Error", Text = "Pet not found: "..pet_name, Duration = 3 })
            end
        else
            game.StarterGui:SetCore("SendNotification", { Title = "Error", Text = "Please enter a pet name!", Duration = 3 })
        end
        activeAnimation.lastSuccess = spawnSuccess
        if isExtension and activeAnimation.lastSuccess then
            feedbackColor = Color3.fromRGB(0, 255 * activeAnimation.intensity, 0)
        end
        buttonStroke.Color = feedbackColor
        buttonStroke.Thickness = 2 * activeAnimation.intensity
        buttonStroke.Transparency = 0.1 / activeAnimation.intensity
        if isExtension then
            activeAnimation.strokeTween = Services.TweenService:Create(buttonStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Thickness = 2.5 * activeAnimation.intensity, Transparency = 0.05 / activeAnimation.intensity })
            activeAnimation.strokeTween:Play()
        end
        activeAnimation.endTime = currentTime + extendDuration
        activeAnimation.resetThread = task.delay(extendDuration, function()
            if os.clock() >= activeAnimation.endTime then
                Services.TweenService:Create(buttonStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Color = originalProperties.StrokeColor, Thickness = originalProperties.StrokeThickness, Transparency = originalProperties.StrokeTransparency }):Play()
            end
        end)
    end)
    local toyNameBox = Instance.new("TextBox")
    toyNameBox.Size = UDim2.new(0.85, 0, 0, 28)
    toyNameBox.Position = UDim2.new(0.075, 0, 0, 10)
    toyNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
    toyNameBox.BackgroundTransparency = 0.2
    toyNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
    toyNameBox.TextSize = 14
    toyNameBox.Font = Enum.Font.FredokaOne
    toyNameBox.PlaceholderText = "Enter Toy Name to Spawn"
    toyNameBox.Text = ""
    toyNameBox.ClearTextOnFocus = false
    toyNameBox.Parent = toyContent
    Instance.new("UICorner", toyNameBox).CornerRadius = UDim.new(0, 6)
    do
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.2; ts.Parent = toyNameBox
    end
    local toyBoxGlow = Instance.new("UIStroke")
    toyBoxGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    toyBoxGlow.Color = Color3.fromRGB(255, 255, 255)
    toyBoxGlow.Thickness = 2.2
    toyBoxGlow.Transparency = 0.25
    toyBoxGlow.Parent = toyNameBox
    local validToyNames = {}
    local validToyNamesClean = {}
    do
        for id, item in pairs(Modules.InventoryDB.toys) do
            validToyNames[#validToyNames + 1] = item.name
            validToyNamesClean[#validToyNamesClean + 1] = item.name:lower():gsub("%s+", "")
        end
    end
    local toyCurrentColorTween = nil
    toyNameBox:GetPropertyChangedSignal("Text"):Connect(function()
        lastCursorPosition = toyNameBox.CursorPosition
        local inputText = toyNameBox.Text
        local newText = capitalizeWords(inputText)
        if newText ~= inputText then
            toyNameBox.Text = newText
            local addedChars = #newText - #inputText
            toyNameBox.CursorPosition = math.max(1, math.min(lastCursorPosition + addedChars, #newText + 1))
            return
        end
        local displayedText = toyNameBox.Text
        local cleanName = displayedText:lower():gsub("%s+", "")
        local isExactMatch = false
        local isCleanMatch = false
        for _, name in ipairs(validToyNames) do
            if name:lower() == displayedText:lower() then isExactMatch = true break end
        end
        isCleanMatch = table.find(validToyNamesClean, cleanName) ~= nil
        local targetColor
        if displayedText == "" then targetColor = SpawnerState.COLORS.NEUTRAL
        elseif isExactMatch or isCleanMatch then targetColor = SpawnerState.COLORS.VALID
        else targetColor = SpawnerState.COLORS.INVALID end
        if toyCurrentColorTween then toyCurrentColorTween:Cancel() end
        toyCurrentColorTween = Services.TweenService:Create(toyBoxGlow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = targetColor})
        toyCurrentColorTween:Play()
    end)
    do
        toyCurrentColorTween = Services.TweenService:Create(toyBoxGlow, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {Color = SpawnerState.COLORS.NEUTRAL})
        toyCurrentColorTween:Play()
    end
    local toySpawnButton = Instance.new("TextButton")
    toySpawnButton.Size = UDim2.new(0.6, 0, 0, 25)
    toySpawnButton.Position = UDim2.new(0.2, 0, 0, 55)
    toySpawnButton.Text = "Spawn Toy"
    toySpawnButton.BackgroundColor3 = Color3.fromRGB(200, 100, 0)
    toySpawnButton.BackgroundTransparency = 0.1
    toySpawnButton.Font = Enum.Font.FredokaOne
    toySpawnButton.TextColor3 = Color3.fromRGB(255, 255, 255)
    toySpawnButton.TextSize = 16
    toySpawnButton.Parent = toyContent
    Instance.new("UICorner", toySpawnButton).CornerRadius = UDim.new(0, 8)
    local toyButtonStroke = Instance.new("UIStroke")
    toyButtonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    toyButtonStroke.Color = Color3.fromRGB(255, 255, 255)
    toyButtonStroke.Thickness = 1.5
    toyButtonStroke.Transparency = 0.1
    toyButtonStroke.Parent = toySpawnButton
    do
        local ts = Instance.new("UIStroke"); ts.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual; ts.Color = Color3.new(0,0,0); ts.Thickness = 1.5; ts.Parent = toySpawnButton
    end
    local toyOriginalProperties = {
        BackgroundColor3 = toySpawnButton.BackgroundColor3,
        StrokeColor = Color3.fromRGB(255, 255, 255),
        StrokeThickness = 1.5,
        StrokeTransparency = 0.1
    }
    local toyActiveAnimation = { endTime = 0, strokeTween = nil, resetThread = nil, intensity = 1.0, lastSuccess = false }
    toySpawnButton.MouseEnter:Connect(function()
        if toyActiveAnimation.endTime < os.clock() then
            toySpawnButton.BackgroundColor3 = Color3.fromRGB(220, 120, 0)
            Services.TweenService:Create(toyButtonStroke, TweenInfo.new(0.2), { Thickness = 2, Transparency = 0.05 }):Play()
        end
    end)
    toySpawnButton.MouseLeave:Connect(function()
        if toyActiveAnimation.endTime < os.clock() then
            toySpawnButton.BackgroundColor3 = toyOriginalProperties.BackgroundColor3
            Services.TweenService:Create(toyButtonStroke, TweenInfo.new(0.2), { Thickness = toyOriginalProperties.StrokeThickness, Transparency = toyOriginalProperties.StrokeTransparency }):Play()
        end
    end)
    toySpawnButton.MouseButton1Click:Connect(function()
        local toy_name = toyNameBox.Text
        local currentTime = os.clock()
        local extendDuration = 1.5
        local isExtension = currentTime < toyActiveAnimation.endTime
        if isExtension then
            toyActiveAnimation.intensity = math.min(toyActiveAnimation.intensity + 0.3, 1.5)
        else
            toyActiveAnimation.intensity = 1.0
        end
        if toyActiveAnimation.strokeTween then toyActiveAnimation.strokeTween:Cancel() end
        if toyActiveAnimation.resetThread then coroutine.close(toyActiveAnimation.resetThread) end
        local feedbackColor = Color3.fromRGB(255, 50, 50)
        local spawnSuccess = false
        if toy_name ~= "" then
            local toyId = GetToyByName(toy_name)
            if toyId then
                createToy(toyId)
                spawnSuccess = true
                game.StarterGui:SetCore("SendNotification", { Title = "Toy Spawned!", Text = toy_name .. " has been spawned!", Duration = 5 })
            else
                game.StarterGui:SetCore("SendNotification", { Title = "Error", Text = "Toy not found: "..toy_name, Duration = 3 })
            end
        else
            game.StarterGui:SetCore("SendNotification", { Title = "Error", Text = "Please enter a toy name!", Duration = 3 })
        end
        toyActiveAnimation.lastSuccess = spawnSuccess
        if isExtension and toyActiveAnimation.lastSuccess then
            feedbackColor = Color3.fromRGB(0, 255 * toyActiveAnimation.intensity, 0)
        end
        toyButtonStroke.Color = feedbackColor
        toyButtonStroke.Thickness = 2 * toyActiveAnimation.intensity
        toyButtonStroke.Transparency = 0.1 / toyActiveAnimation.intensity
        if isExtension then
            toyActiveAnimation.strokeTween = Services.TweenService:Create(toyButtonStroke, TweenInfo.new(0.2, Enum.EasingStyle.Quad), { Thickness = 2.5 * toyActiveAnimation.intensity, Transparency = 0.05 / toyActiveAnimation.intensity })
            toyActiveAnimation.strokeTween:Play()
        end
        toyActiveAnimation.endTime = currentTime + extendDuration
        toyActiveAnimation.resetThread = task.delay(extendDuration, function()
            if os.clock() >= toyActiveAnimation.endTime then
                Services.TweenService:Create(toyButtonStroke, TweenInfo.new(0.5, Enum.EasingStyle.Quad), { Color = toyOriginalProperties.StrokeColor, Thickness = toyOriginalProperties.StrokeThickness, Transparency = toyOriginalProperties.StrokeTransparency }):Play()
            end
        end)
    end)
end)
Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if UIState.waitingForKeybind and input.UserInputType == Enum.UserInputType.Keyboard then
        local key = input.KeyCode
        if key == Enum.KeyCode.Escape then
            local button = SetsUI.keybindButtons[UIState.waitingForKeybind]
            if button then button.Text = UIState.keybinds[UIState.waitingForKeybind].Name; button.BackgroundColor3 = Color3.fromRGB(70, 65, 95) end
            UIState.waitingForKeybind = nil
            return
        end
        UIState.keybinds[UIState.waitingForKeybind] = key
        local button = SetsUI.keybindButtons[UIState.waitingForKeybind]
        if button then button.Text = key.Name; button.BackgroundColor3 = Color3.fromRGB(70, 65, 95) end
        UIState.waitingForKeybind = nil
        if Apps.HintApp then Apps.HintApp:hint({ text = 'Keybind set to ' .. key.Name, length = 2, overridable = true }) end
        return
    end
    if input.UserInputType == Enum.UserInputType.Keyboard and not UIState.waitingForKeybind then
        local key = input.KeyCode
        if key == UIState.keybinds.selectPartner then
            pcall(function()
                local partner = nil
                if mockState.active and mockState.trade then
                    partner = mockState.trade.recipient
                else
                    partner = Apps.TradeApp:_get_partner()
                end
                if partner and partner.Name then
                    partnerBox.Text = partner.Name
                    updatePartnerFromUsername(partner.Name)
                end
            end)
        end
        if key == UIState.keybinds.addRandomItem then
            if mockState.active then
                addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
            end
        end
        if key == UIState.keybinds.startTrade then
            if not mockState.active and not mockState.pendingTradeRequest then
                if CONFIG.SHOW_TRADE_REQUEST then
                    task.spawn(showTradeRequest)
                else
                    startMockTradeDirectly()
                end
            end
        end
        if key == UIState.keybinds.blockPlayer then
            local player = Services.Players:FindFirstChild(partnerBox.Text)
            if player then
                BlockPlayer(player)
            end
        end
        if key == UIState.keybinds.randomUser then
            local randomUsername = customUsers[math.random(1, #customUsers)]
            partnerBox.Text = randomUsername
            updatePartnerFromUsername(randomUsername)
        end
    end
end)
local DragState = {}
DragState.dragging = false
DragState.dragInput, DragState.dragStart, DragState.startPos = nil, nil, nil
UI.mainFrame.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
        DragState.dragging = true
        DragState.dragStart = input.Position
        DragState.startPos = UI.mainFrame.Position
        input.Changed:Connect(function()
            if input.UserInputState == Enum.UserInputState.End then
                DragState.dragging = false
            end
        end)
    end
end)
UI.mainFrame.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
        DragState.dragInput = input
    end
end)
Services.UserInputService.InputChanged:Connect(function(input)
    if input == DragState.dragInput and DragState.dragging then
        local delta = input.Position - DragState.dragStart
        UI.mainFrame.Position = UDim2.new(DragState.startPos.X.Scale, DragState.startPos.X.Offset + delta.X, DragState.startPos.Y.Scale, DragState.startPos.Y.Offset + delta.Y)
    end
end)
Services.UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.F6 then
        UI.mainFrame.Visible = not UI.mainFrame.Visible
    end
end)
task.spawn(function()
    while true do
        task.wait(1)
        if UIState.noclipEnabled then
            enableNoclipForAllFakePlayers()
            enableNoclipForPets()
        end
    end
end)
if UIState.activeTabPulseTween == nil then
    local data = UIState.tabButtons['Control']
    if data then
        UIState.activeTabPulseTween = Services.TweenService:Create(data.stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
            Color = Color3.fromRGB(100, 100, 255):Lerp(Color3.fromRGB(255, 255, 255), 0.25), Thickness = 1.5
        })
        UIState.activeTabPulseTween:Play()
    end
end
task.wait(3)
refreshRichestPlayers(true)
_G.EmojiSystem = {
    running = false,
    reactions = Fsys.load('SharedConstants').trade_spectate_reactions
}
_G.EmojiSystem.display = function(index)
    if not _G.EmojiSystem.reactions[index] then return end
    if not mockState.active or not mockState.trade then return end
    pcall(function()
        local tradeFrame = Services.Players.LocalPlayer.PlayerGui.TradeApp.Frame
        local e = Instance.new('ImageLabel')
        e.Image = _G.EmojiSystem.reactions[index]
        e.BackgroundTransparency = 1
        e.ImageTransparency = 1
        e.Size = UDim2.fromOffset(40, 40)
        e.Position = UDim2.new(0.92 + math.random(-3, 3) / 100, 0, 0.95, 0)
        e.AnchorPoint = Vector2.new(0.5, 1)
        e.ZIndex = 100
        e.Parent = tradeFrame
        Services.TweenService:Create(e, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
            ImageTransparency = 0, Size = UDim2.fromOffset(45, 45)
        }):Play()
        local st, dur, spd = tick(), math.random(18, 28) / 10, 0.18
        local c
        c = Services.RunService.Heartbeat:Connect(function(dt)
            local el = tick() - st
            if el >= dur or not e.Parent then c:Disconnect() if e.Parent then e:Destroy() end return end
            local newY = e.Position.Y.Scale - spd * dt
            local drift = math.sin(el * 4) * dt * 0.0
            e.Position = UDim2.new(math.clamp(e.Position.X.Scale + drift, 0.85, 0.98), 0, newY, 0)
            if el >= dur * 0.5 then e.ImageTransparency = (el - dur * 0.5) / (dur * 0.5) end
        end)
    end)
end
createSpacer(UI.controlFrame)
createButton('🎭 Auto Partner Emoji: OFF', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), UI.controlFrame, function()
    _G.EmojiSystem.running = not _G.EmojiSystem.running
    local btn
    for _, v in pairs(UI.controlFrame:GetChildren()) do
        if v:IsA('TextButton') and v.Text:find('Emoji') then btn = v break end
    end
    if _G.EmojiSystem.running then
        btn.Text = '🎭 Auto Partner Emoji: ON'
        btn.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
        task.spawn(function()
            while _G.EmojiSystem.running do
                task.wait(math.random(8, 20) / 10)
                if _G.EmojiSystem.running and mockState.active and mockState.trade then
                    _G.EmojiSystem.display(math.random(1, #_G.EmojiSystem.reactions))
                end
            end
        end)
    else
        btn.Text = '🎭 Auto Partner Emoji: OFF'
        btn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
    end
end)
task.spawn(function()
    while true do
        task.wait(0.03)
        if RGBState.enabled and UI.mainStroke then
            RGBState.hue = (RGBState.hue + RGBState.speed) % 360
            local color = Color3.fromHSV(RGBState.hue / 360, 0.7, 1)
            UI.mainStroke.Color = color
        end
    end
end)
local function GetPlayerCollectionPetsByUserId(userId)
    local profileItems = {pets = {}, error = nil}
    local player = Services.Players:GetPlayerByUserId(userId)
    local playerProfileData = nil
    if player then
        local success = pcall(function()
            playerProfileData = Modules.ClientData.get_server(player, 'player_profile') or {}
        end)
        if not success then
            playerProfileData = {}
        end
    else
        local GetProfile = Modules.RouterClient.get("PlayerProfileAPI/FetchProfile")
        local profileData = nil
        local timeoutDone = false
        task.spawn(function()
            local success, result = pcall(function()
                return GetProfile:InvokeServer(userId)
            end)
            if not timeoutDone then
                profileData = (success and result) or {}
                playerProfileData = profileData
            end
        end)
        local startTime = os.clock()
        while profileData == nil and os.clock() - startTime < 3 do
            task.wait(0.05)
        end
        if profileData == nil then
            timeoutDone = true
            playerProfileData = {}
        end
    end
    if playerProfileData and type(playerProfileData) == 'table' then
        local normalizedData = playerProfileData
        if playerProfileData.profile then
            normalizedData = playerProfileData.profile
        elseif playerProfileData.data then
            normalizedData = playerProfileData.data
        end
        if normalizedData.pages and type(normalizedData.pages) == 'table' then
            for pageIdx = 1, #normalizedData.pages do
                local page = normalizedData.pages[pageIdx]
                if page and page.widgets then
                    for slotIdx = 1, #page.widgets do
                        local widget = page.widgets[slotIdx]
                        if widget and widget.data then
                            local widgetData = widget.data
                            if widgetData.widget_kind == 'collection' then
                                local collectionData = widgetData.widget_data
                                if collectionData and collectionData.items and type(collectionData.items) == 'table' then
                                    for itemIdx = 1, #collectionData.items do
                                        local item = collectionData.items[itemIdx]
                                        if item and item.kind then
                                            table.insert(profileItems.pets, item)
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
        end
    end
    return profileItems
end
local function GetPlayerCollectionPets(playerOrUserId)
    local userId = nil
    if type(playerOrUserId) == "number" then
        userId = playerOrUserId
    elseif playerOrUserId and playerOrUserId:IsA('Player') then
        userId = playerOrUserId.UserId
    else
        return {pets = {}, error = "Invalid player"}
    end
    return GetPlayerCollectionPetsByUserId(userId)
end
local suggestInventoryCache = {}
local lastTradeId = nil
local function hookSuggestInventorySystem()
    task.spawn(function()
        task.wait(2)
        pcall(function()
            if Apps.TradeApp then
                if not Apps.TradeApp._original_try_suggest_item then
                    Apps.TradeApp._original_try_suggest_item = Apps.TradeApp.try_suggest_item
                end
                if not Apps.TradeApp._original_suggest_item then
                    Apps.TradeApp._original_suggest_item = Apps.TradeApp.suggest_item
                end
                Apps.TradeApp.try_suggest_item = function(self)
                    if not mockState.active or not mockState.trade then
                        return self._original_try_suggest_item(self)
                    end
                    local currentTradeId = mockState.trade.trade_id
                    if lastTradeId ~= currentTradeId then
                        suggestInventoryCache = {}
                        lastTradeId = currentTradeId
                    end
                    if suggestInventoryCache[currentTradeId] then
                        self.backpack_access = true
                        local BackpackApp = self.UIManager.apps.BackpackApp
                        if BackpackApp then
                            local OriginalClientDataGet = Modules.ClientData.get
                            Modules.ClientData.get = function(key)
                                if key == 'trade_partner_inventory' then
                                    return suggestInventoryCache[currentTradeId]
                                end
                                return OriginalClientDataGet(key)
                            end
                            self:suggest_item()
                            task.spawn(function()
                                while self.UIManager.is_visible('BackpackApp') do
                                    task.wait(0.2)
                                end
                                Modules.ClientData.get = OriginalClientDataGet
                            end)
                        end
                        return
                    end
                    local partner = self:_get_partner()
                    if not partner then
                        return
                    end
                    if self.UIManager.apps.HintApp then
                        self.UIManager.apps.HintApp:hint({
                            text = "Backpack access requested..",
                            length = 3,
                            overridable = true,
                            yields = false
                        })
                    end
                    task.wait(0.5)
                    local collectionData = GetPlayerCollectionPets(partner.UserId)
                    local hasPets = collectionData.pets and #collectionData.pets > 0
                    if self.UIManager.apps.DialogApp then
                        local dialogText = ""
                        if hasPets then
                            dialogText = (("%* has granted you access to view their backpack! Make a boost now?"):format(partner.Name))
                        else
                            dialogText = (("%* has granted you access to view their backpack!\n\nNote: Their collection is empty or private."):format(partner.Name))
                        end
                        local response = self.UIManager.apps.DialogApp:dialog({
                            text = dialogText,
                            left = "Cancel",
                            right = hasPets and "Boost" or "Okay"
                        })
                        if response == "Cancel" or response == "Okay" then
                            self.backpack_access = true
                            suggestInventoryCache[currentTradeId] = {
                                pets = {}, toys = {}, food = {}, gifts = {},
                                roleplay = {}, stickers = {}, strollers = {},
                                transport = {}, pet_accessories = {}
                            }
                            return
                        end
                    end
                    if not hasPets then
                        self.backpack_access = true
                        return
                    end
                    local overrideInventory = {
                        pets = {}, toys = {}, food = {}, gifts = {},
                        roleplay = {}, stickers = {}, strollers = {},
                        transport = {}, pet_accessories = {}
                    }
                    local successCount = 0
                    local rarityBases = { legendary = 900000, ultra_rare = 700000, rare = 500000, uncommon = 300000, common = 100000 }
                    local rarityCounts = { legendary = 0, ultra_rare = 0, rare = 0, uncommon = 0, common = 0 }
                    for idx, pet in ipairs(collectionData.pets) do
                        if pet and pet.kind then
                            local petKey = pet.unique
                            if not petKey or petKey == "" then
                                petKey = "suggest_" .. pet.kind .. "_" .. idx
                            end
                            local inventoryDbPet = Modules.InventoryDB.pets[pet.kind]
                            if inventoryDbPet and not overrideInventory.pets[petKey] then
                                local rarity = inventoryDbPet.rarity or "common"
                                local base = rarityBases[rarity] or 100000
                                rarityCounts[rarity] = (rarityCounts[rarity] or 0) + 1
                                local newnessOrder = base + 99999 - rarityCounts[rarity]
                                local petData = {
                                    kind = pet.kind,
                                    id = pet.kind,
                                    category = 'pets',
                                    unique = petKey,
                                    typechecked = true,
                                    newness_order = newnessOrder,
                                    rarity = inventoryDbPet.rarity or 1,
                                    name = inventoryDbPet.name or pet.kind,
                                    properties = {
                                        rarity = inventoryDbPet.rarity or 1,
                                        is_new = false,
                                        amount = 1,
                                        age = (pet.properties and tonumber(pet.properties.age)) or 1,
                                        pet_trick_level = (pet.properties and tonumber(pet.properties.pet_trick_level)) or 0,
                                        neon = (pet.properties and pet.properties.neon) or false,
                                        mega_neon = (pet.properties and pet.properties.mega_neon) or false,
                                        rideable = (pet.properties and pet.properties.rideable) or false,
                                        flyable = (pet.properties and pet.properties.flyable) or false,
                                        rp_name = (pet.properties and pet.properties.rp_name) or "",
                                        custom_name = (pet.properties and pet.properties.custom_name) or nil
                                    }
                                }
                                if pet.properties then
                                    for k, v in pairs(pet.properties) do
                                        if petData.properties[k] == nil then
                                            petData.properties[k] = v
                                        end
                                    end
                                end
                                overrideInventory.pets[petKey] = petData
                                successCount = successCount + 1
                            end
                        end
                    end
                    suggestInventoryCache[currentTradeId] = overrideInventory
                    self.backpack_access = true
                    local BackpackApp = self.UIManager.apps.BackpackApp
                    if not BackpackApp then
                        return
                    end
                    local OriginalClientDataGet = Modules.ClientData.get
                    Modules.ClientData.get = function(key)
                        if key == 'trade_partner_inventory' then
                            return overrideInventory
                        end
                        return OriginalClientDataGet(key)
                    end
                    self:suggest_item()
                    task.spawn(function()
                        while self.UIManager.is_visible('BackpackApp') do
                            task.wait(0.2)
                        end
                        Modules.ClientData.get = OriginalClientDataGet
                    end)
                end
                Apps.TradeApp.suggest_item = function(self, specific_item)
                    if not mockState.active or not mockState.trade then
                        return self._original_suggest_item(self, specific_item)
                    end
                    local backpack_app = self.UIManager.apps.BackpackApp
                    if backpack_app:is_picking_item() then
                        return
                    end
                    local suggestible_items = self:_get_suggestible_items() or {}
                    local my_player = self:_get_my_player()
                    local picked_item = specific_item or backpack_app:pick_item({
                        friendship_hidden = true,
                        title_override = ("%*'S BACKPACK"):format((self:_get_partner().Name:upper())),
                        inventory_override = suggestible_items,
                        force_no_filters = true,
                        allow_callback = function(item)
                            local suggestion = self.suggestions[item.unique]
                            return (not suggestion or suggestion.item_owner == my_player) and true or false
                        end
                    })
                    if not picked_item then
                        return false
                    end
                    if self.suggestions[picked_item.unique] then
                        self.UIManager.apps.HintApp:hint({
                            text = "Item already boosted!",
                            length = 3,
                            overridable = true,
                            yields = false
                        })
                        return false
                    end
                    for _, offered_item in self:_get_partner_offer().items do
                        if offered_item.unique == picked_item.unique then
                            self.UIManager.apps.HintApp:hint({
                                text = "Item already added to offer!",
                                length = 4,
                                overridable = true,
                                yields = false
                            })
                            return false
                        end
                    end
                    local petName = picked_item.kind
                    if picked_item.category == 'pets' then
                        for category_name, category_table in pairs(Modules.InventoryDB) do
                            if category_name == 'pets' then
                                for id, item in pairs(category_table) do
                                    if id == picked_item.kind then
                                        petName = item.name
                                        break
                                    end
                                end
                                break
                            end
                        end
                    end
                    self:_render_suggestion(picked_item.unique, self:_get_partner())
                    task.spawn(function()
                        task.wait(math.random(15, 30) / 10)
                        self:_render_suggestion_finalized(picked_item.unique, true, Services.Players.LocalPlayer)
                        task.wait(math.random(5, 12) / 10)
                        local success, message = addPetToPartnerOffer(petName, {
                            F = picked_item.properties.flyable or false,
                            R = picked_item.properties.rideable or false,
                            N = picked_item.properties.neon or false,
                            M = picked_item.properties.mega_neon or false
                        })
                        if success then
                        else
                        end
                    end)
                    return true
                end
            end
        end)
    end)
    task.spawn(function()
        task.wait(2.5)
        pcall(function()
            local originalDeclineTrade = mockState.originalFunctions._decline_trade
            local newDeclineHook = function(self, silent)
                if mockState.active and mockState.trade then
                    local tradeId = mockState.trade.trade_id
                    if suggestInventoryCache[tradeId] then
                        suggestInventoryCache[tradeId] = nil
                    end
                    lastTradeId = nil
                end
                return originalDeclineTrade(self, silent)
            end
            if Apps.TradeApp._decline_trade ~= newDeclineHook then
                Apps.TradeApp._decline_trade = newDeclineHook
            end
        end)
    end)
end
do
    local originalOpenProfile = Apps.PlayerProfileApp.open_player_profile_for_user_id
    Apps.PlayerProfileApp.open_player_profile_for_user_id = function(self, userId)
        local result = originalOpenProfile(self, userId)
        if mockState.active and mockState.trade and self.player_profile then
            local partnerId = mockState.trade.recipient.UserId
            if userId == partnerId and not self.player_profile.player then
                self.player_profile.player = mockState.trade.recipient
            end
        end
        if mockState.active and mockState.trade then
            task.spawn(function()
                for _ = 1, 15 do
                    task.wait(0.15)
                    pcall(function()
                        local pGui = Services.Players.LocalPlayer.PlayerGui:FindFirstChild("PlayerProfileApp")
                        if not pGui then return end
                        for _, desc in ipairs(pGui:GetDescendants()) do
                            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) and (desc.Text == "Trade" or desc.Text == "Suggest") then
                                desc.Text = "Boost"
                            end
                        end
                    end)
                end
            end)
        end
        return result
    end
    local profileGui = Services.Players.LocalPlayer.PlayerGui:FindFirstChild("PlayerProfileApp")
    if profileGui then
        local function renameToBoost(desc)
            if (desc:IsA("TextLabel") or desc:IsA("TextButton")) then
                if desc.Text == "Suggest" or (desc.Text == "Trade" and mockState.active and mockState.trade) then
                    desc.Text = "Boost"
                end
                desc:GetPropertyChangedSignal("Text"):Connect(function()
                    if desc.Text == "Suggest" or (desc.Text == "Trade" and mockState.active and mockState.trade) then
                        desc.Text = "Boost"
                    end
                end)
            end
        end
        for _, desc in ipairs(profileGui:GetDescendants()) do renameToBoost(desc) end
        profileGui.DescendantAdded:Connect(function(desc) task.defer(renameToBoost, desc) end)
    end
end
do
    pcall(function()
        local BCB = Fsys.load("BackpackCategoryButtons")
        local u148
        for i = 1, 20 do
            local ok, val = pcall(debug.getupvalue, BCB.get_buttons, i)
            if ok and type(val) == "table" and val.pets and type(val.pets) == "function" then
                u148 = val
                break
            end
        end
        if not u148 then return end
        local u147
        for i = 1, 20 do
            local ok, val = pcall(debug.getupvalue, u148.pets, i)
            if ok and type(val) == "function" then
                for j = 1, 20 do
                    local ok2, val2 = pcall(debug.getupvalue, val, j)
                    if ok2 and type(val2) == "table" and val2.alphabetical and val2.default then
                        u147 = val
                        break
                    end
                end
                if u147 then break end
            end
        end
        if not u147 then return end
        local u20
        for i = 1, 20 do
            local ok, val = pcall(debug.getupvalue, u147, i)
            if ok and type(val) == "table" and val.alphabetical and val.default and val.rarity then
                u20 = val
                break
            end
        end
        if not u20 then return end
        local u54, u54idx
        for i = 1, 20 do
            local ok, val = pcall(debug.getupvalue, u20.alphabetical, i)
            if ok and type(val) == "function" then
                u54 = val
                u54idx = i
                break
            end
        end
        if not u54 then return end
        local rarityInverse = { legendary = "1", event = "1", ultra_rare = "2", rare = "3", uncommon = "4", common = "5" }
        local InventoryDB = Fsys.load("InventoryDB")
        local hookedU54 = function(item, equipped)
            u54(item, equipped)
            if item.sort_transformed_cached and item.item_data then
                local entry = InventoryDB[item.item_data.category] and InventoryDB[item.item_data.category][item.item_data.kind]
                if entry then
                    local rarity = item.item_data.properties.displayed_rarity or entry.displayed_rarity or entry.rarity or "common"
                    local prefix = rarityInverse[rarity] or "5"
                    local origName = entry.name or item.item_data.kind
                    local firstChar = string.sub(origName, 1, 1):upper()
                    item.sort_transformed_cached.name = firstChar .. prefix .. origName
                end
            end
        end
        for _, sortName in ipairs({"alphabetical", "default", "rarity", "age", "favorites", "locked"}) do
            if u20[sortName] then
                for i = 1, 20 do
                    local ok, val = pcall(debug.getupvalue, u20[sortName], i)
                    if ok and val == u54 then
                        pcall(debug.setupvalue, u20[sortName], i, hookedU54)
                    end
                end
            end
        end
    end)
end
hookSuggestInventorySystem()
spinnerSystem = {}
do
    pcall(function() spinnerSystem.SoundPlayer = Fsys.load('SoundPlayer') end)
    spinnerSystem.Templates = Services.ReplicatedStorage.Resources.UI_Resources.Templates
    spinnerSystem.ItemImageTemplate = spinnerSystem.Templates.ItemImageTemplate
    spinnerSystem.PlayerGui = Services.Players.LocalPlayer:WaitForChild("PlayerGui")
    spinnerSystem.DailyLoginGui = spinnerSystem.PlayerGui:WaitForChild("DailyLoginApp")
    spinnerSystem.MainFrame = spinnerSystem.DailyLoginGui:WaitForChild("Frame")
    spinnerSystem.app = Modules.UIManager.apps.DailyLoginApp
    spinnerSystem.THEME = {
        cardDefaultBG = Color3.fromRGB(230, 240, 255),
        cardDefaultStroke = Color3.fromRGB(200, 80, 80),
        cardHighlightBG = Color3.fromRGB(200, 255, 210),
        cardHighlightStroke = Color3.fromRGB(74, 198, 85),
        cardWinFlashBG = Color3.fromRGB(255, 248, 215),
        cardWinFlashStroke = Color3.fromRGB(255, 200, 50),
        rewardBoxDefault = Color3.fromRGB(200, 60, 60),
        rewardBoxHighlight = Color3.fromRGB(50, 190, 80),
        rewardTextDefault = Color3.fromRGB(255, 255, 255),
        pointer = Color3.fromRGB(100, 180, 255),
        pointerStroke = Color3.fromRGB(60, 130, 220),
        innerStroke = Color3.fromRGB(180, 210, 255),
        cardShadow = Color3.fromRGB(40, 80, 140),
        petNameText = Color3.fromRGB(30, 50, 100),
        toggleBG = Color3.fromRGB(60, 140, 255),
        toggleShadow = Color3.fromRGB(30, 100, 200),
        toggleStroke = Color3.fromRGB(30, 100, 200),
    }
    spinnerSystem.TIERS = {
        HIGH = {
            'Shadow Dragon', 'Bat Dragon', 'Frost Dragon', 'Giraffe', 'Owl', 'Parrot', 'Crow',
            'Evil Unicorn', 'Arctic Reindeer', 'Hedgehog', 'Dalmatian',
        },
        MID = {
            'Turtle', 'Kangaroo', 'Lion', 'Elephant', 'Rhino', 'Chocolate Chip Bat Dragon',
            'Cow', 'Blazing Lion', 'African Wild Dog', 'Flamingo', 'Diamond Butterfly',
            'Mini Pig', 'Caterpillar', 'Albino Monkey', 'Candyfloss Chick', 'Pelican',
            'Blue Dog', 'Pink Cat', 'Haetae', 'Peppermint Penguin', 'Winged Tiger',
            'Sugar Glider', 'Shark Puppy', 'Goat', 'Sheeeeep', 'Lion Cub', 'Nessie',
            'Frostbite Bear', 'Balloon Unicorn', 'Honey Badger', 'Hot Doggo', 'Crocodile',
            'Hare', 'Ram', 'Yeti', 'Meerkat', 'Jellyfish', 'Happy Clam', 'Orchid Butterfly',
            'Many Mackerel', 'Strawberry Shortcake Bat Dragon', 'Zombie Buffalo', 'Fairy Bat Dragon',
        },
    }
    spinnerSystem.PROPERTY_COMBOS = {
        { flyable = true, rideable = true, neon = false, mega_neon = false, label = "FR" },
        { flyable = true, rideable = true, neon = true, mega_neon = false, label = "NFR" },
        { flyable = true, rideable = true, neon = false, mega_neon = true, label = "MFR" },
    }
    spinnerSystem.currentTier = nil
    spinnerSystem.resolvePetsForTier = function(tierName)
        local names = spinnerSystem.TIERS[tierName]
        if not names then return {} end
        local resolved = {}
        for _, petName in ipairs(names) do
            local found = false
            for kind, data in pairs(Modules.InventoryDB.pets or {}) do
                if data.name == petName then
                    local combo = spinnerSystem.PROPERTY_COMBOS[math.random(1, #spinnerSystem.PROPERTY_COMBOS)]
                    table.insert(resolved, {
                        name = petName,
                        kind = kind,
                        image = data.image or "",
                        item_data = {
                            category = "pets", kind = kind, unique = "spinner_" .. kind .. "_" .. math.random(1, 99999),
                            properties = { flyable = combo.flyable, rideable = combo.rideable, neon = combo.neon, mega_neon = combo.mega_neon },
                        },
                        propLabel = combo.label,
                    })
                    found = true
                    break
                end
            end
            if not found then
                table.insert(resolved, {
                    name = petName, kind = petName:gsub(" ", ""), image = "",
                    item_data = {
                        category = "pets", kind = petName:gsub(" ", ""), unique = "spinner_" .. petName:gsub(" ", ""),
                        properties = { flyable = true, rideable = true, neon = false, mega_neon = true },
                    },
                    propLabel = "MFR",
                })
            end
        end
        return resolved
    end
    spinnerSystem.PETS = {}
    spinnerSystem.STRIP_REPEATS = 20
    spinnerSystem.STRIP_PETS = {}
    spinnerSystem.CARD_GAP = 6
    spinnerSystem.CONFETTI_COLORS = {
        Color3.fromRGB(100, 180, 255), Color3.fromRGB(60, 220, 130),
        Color3.fromRGB(255, 130, 80), Color3.fromRGB(255, 220, 80),
        Color3.fromRGB(180, 100, 255), Color3.fromRGB(80, 230, 255),
        Color3.fromRGB(255, 100, 150), Color3.fromRGB(255, 255, 255),
    }
    spinnerSystem.spinning = false
    spinnerSystem.spinCount = 0
    spinnerSystem.persistentHL = -1
    spinnerSystem.petCards = {}
    spinnerSystem.cardScales = {}
    spinnerSystem.rewardBoxes = {}
    spinnerSystem.dragState = { dragStart = nil, startPos = nil, dragMoved = false }

    spinnerSystem.toggleGui = Instance.new("ScreenGui")
    spinnerSystem.toggleGui.Name = "PetSpinnerToggle"
    spinnerSystem.toggleGui.ResetOnSpawn = false
    spinnerSystem.toggleGui.DisplayOrder = 100
    spinnerSystem.toggleGui.Parent = spinnerSystem.PlayerGui

    spinnerSystem.toggleBtn = Instance.new("TextButton")
    spinnerSystem.toggleBtn.Name = "ToggleBtn"
    spinnerSystem.toggleBtn.Size = UDim2.new(0, 52, 0, 52)
    spinnerSystem.toggleBtn.Position = UDim2.new(0, 14, 0.5, 0)
    spinnerSystem.toggleBtn.AnchorPoint = Vector2.new(0, 0.5)
    spinnerSystem.toggleBtn.BackgroundColor3 = spinnerSystem.THEME.toggleBG
    spinnerSystem.toggleBtn.BorderSizePixel = 0
    spinnerSystem.toggleBtn.Text = ""
    spinnerSystem.toggleBtn.AutoButtonColor = true
    spinnerSystem.toggleBtn.Parent = spinnerSystem.toggleGui
    Instance.new("UICorner", spinnerSystem.toggleBtn).CornerRadius = UDim.new(0, 12)

    spinnerSystem.toggleShadow = Instance.new("Frame")
    spinnerSystem.toggleShadow.Size = UDim2.new(1, 2, 1, 2)
    spinnerSystem.toggleShadow.Position = UDim2.new(0.5, 0, 0.5, 3)
    spinnerSystem.toggleShadow.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.toggleShadow.BackgroundColor3 = spinnerSystem.THEME.toggleShadow
    spinnerSystem.toggleShadow.BorderSizePixel = 0
    spinnerSystem.toggleShadow.ZIndex = 0
    spinnerSystem.toggleShadow.Parent = spinnerSystem.toggleBtn
    Instance.new("UICorner", spinnerSystem.toggleShadow).CornerRadius = UDim.new(0, 12)

    spinnerSystem.tIcon = spinnerSystem.ItemImageTemplate:Clone()
    spinnerSystem.tIcon.Image = "rbxassetid://4115248712"
    spinnerSystem.tIcon.Size = UDim2.new(0, 34, 0, 34)
    spinnerSystem.tIcon.Position = UDim2.new(0.5, 0, 0.5, -1)
    spinnerSystem.tIcon.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.tIcon.BackgroundTransparency = 1
    spinnerSystem.tIcon.ScaleType = Enum.ScaleType.Fit
    spinnerSystem.tIcon.ZIndex = 2
    spinnerSystem.tIcon.Parent = spinnerSystem.toggleBtn

    spinnerSystem.tStroke = Instance.new("UIStroke")
    spinnerSystem.tStroke.Color = spinnerSystem.THEME.toggleStroke
    spinnerSystem.tStroke.Thickness = 2
    spinnerSystem.tStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
    spinnerSystem.tStroke.Parent = spinnerSystem.toggleBtn

    spinnerSystem.toggleBtn.MouseButton1Click:Connect(function()
        if spinnerSystem.DailyLoginGui.Enabled then
            spinnerSystem.DailyLoginGui.Enabled = false
            spinnerSystem.MainFrame.Visible = false
        else
            spinnerSystem.showTierPopup()
        end
    end)

    spinnerSystem.toggleBtn.InputBegan:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            spinnerSystem.dragState.dragMoved = false
            spinnerSystem.dragState.dragStart = input.Position
            spinnerSystem.dragState.startPos = spinnerSystem.toggleBtn.Position
        end
    end)
    Services.UserInputService.InputChanged:Connect(function(input)
        if spinnerSystem.dragState.dragStart and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
            local delta = input.Position - spinnerSystem.dragState.dragStart
            if delta.Magnitude > 6 then spinnerSystem.dragState.dragMoved = true end
            if spinnerSystem.dragState.dragMoved then
                spinnerSystem.toggleBtn.Position = UDim2.new(
                    spinnerSystem.dragState.startPos.X.Scale, spinnerSystem.dragState.startPos.X.Offset + delta.X,
                    spinnerSystem.dragState.startPos.Y.Scale, spinnerSystem.dragState.startPos.Y.Offset + delta.Y
                )
            end
        end
    end)
    Services.UserInputService.InputEnded:Connect(function(input)
        if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
            spinnerSystem.dragState.dragStart = nil
        end
    end)

    spinnerSystem.DailyLoginGui.Enabled = false
    spinnerSystem.MainFrame.Visible = false

    spinnerSystem.app.claim_ad_button_instance.Visible = false
    spinnerSystem.app.milestones_button_instance.Visible = false
    spinnerSystem.app.early_claim_explainer_button_instance.Visible = false
    spinnerSystem.daysContainer = spinnerSystem.app.days_list_container
    spinnerSystem.daysContainer:FindFirstChild("LeftArrowButtonContainer").Visible = false
    spinnerSystem.daysContainer:FindFirstChild("RightArrowButtonContainer").Visible = false
    for _, bucket in ipairs(spinnerSystem.app.day_buckets) do bucket:Destroy() end
    spinnerSystem.app.day_buckets = {}
    if spinnerSystem.app.page_layout then spinnerSystem.app.page_layout:Destroy() end

    do
        local taglineArea = spinnerSystem.app.body:FindFirstChild("TaglineArea")
        if taglineArea then
            taglineArea.Visible = true
            local tagline = taglineArea:FindFirstChild("Tagline")
            if tagline then
                tagline.Text = "Spin to win your dream pet!"
                tagline.Font = Enum.Font.GothamBold
            end
            for _, child in ipairs(taglineArea:GetChildren()) do
                if child.Name ~= "Tagline" and not child:IsA("UIListLayout") and not child:IsA("UIPadding") then
                    child.Visible = false
                end
            end
        end
    end

    spinnerSystem.spinBtn = spinnerSystem.app.claim_depth_button
    spinnerSystem.claimBtnInst = spinnerSystem.app.claim_button_instance

    do
        local buttonsContainer = spinnerSystem.app.body:FindFirstChild("Buttons")
        if buttonsContainer then buttonsContainer.Size = buttonsContainer.Size + UDim2.new(0.5, 0, 0, 0) end
    end
    spinnerSystem.claimBtnInst.Size = spinnerSystem.claimBtnInst.Size + UDim2.new(0.7, 0, 0, 0)
    do
        local face = spinnerSystem.claimBtnInst:FindFirstChild("Face")
        if face then face.Size = UDim2.new(1, 0, face.Size.Y.Scale, face.Size.Y.Offset) end
        local shadow = spinnerSystem.claimBtnInst:FindFirstChild("Shadow")
        if shadow then shadow.Size = UDim2.new(1, 0, shadow.Size.Y.Scale, shadow.Size.Y.Offset) end
    end
    spinnerSystem.spinBtn:set_state("normal")
    spinnerSystem.spinBtn:set_text("SPIN")

    spinnerSystem.daysList = spinnerSystem.app.days_list
    spinnerSystem.daysList.ClipsDescendants = true

    task.wait()
    spinnerSystem.vpH = spinnerSystem.daysList.AbsoluteSize.Y
    spinnerSystem.vpW = spinnerSystem.daysList.AbsoluteSize.X
    spinnerSystem.CARD_SIZE = math.max(math.floor(spinnerSystem.vpH * 0.68), 50)
    spinnerSystem.CELL_WIDTH = spinnerSystem.CARD_SIZE + spinnerSystem.CARD_GAP
    spinnerSystem.originalBtnSize = spinnerSystem.claimBtnInst.Size

    spinnerSystem.addPetToMySide = function(petName, flags)
        if not mockState.active or not mockState.trade then return end
        if #mockState.trade.sender_offer.items >= 18 then return end
        for category_name, category_table in pairs(Modules.InventoryDB) do
            if category_name == 'pets' then
                for id, item in pairs(category_table) do
                    if item.name == petName then
                        local petItem = {
                            category = 'pets',
                            kind = id,
                            unique = Services.HttpService:GenerateGUID(),
                            properties = { flyable = flags.F, rideable = flags.R, neon = flags.N, mega_neon = flags.M, age = 1 },
                        }
                        table.insert(mockState.trade.sender_offer.items, petItem)
                        mockState.trade.sender_offer.negotiated = false
                        mockState.trade.recipient_offer.negotiated = false
                        if mockState.trade.current_stage == 'confirmation' then
                            mockState.trade.current_stage = 'negotiation'
                            mockState.trade.sender_offer.confirmed = false
                            mockState.trade.recipient_offer.confirmed = false
                        end
                        mockState.trade.offer_version = mockState.trade.offer_version + 1
                        Apps.TradeApp:_overwrite_local_trade_state(mockState.trade)
                        if Apps.TradeApp._lock_trade_for_appropriate_time then Apps.TradeApp:_lock_trade_for_appropriate_time() end
                        return
                    end
                end
            end
        end
    end

    spinnerSystem.showWinPopup = function(pet)
        spinnerSystem.lastWonPet = pet
        task.spawn(function()
            local props = pet.item_data and pet.item_data.properties or {}
            local petKind = pet.kind
            Apps.DialogApp:dialog({
                dialog_type = "ItemPreviewDialog",
                item = {
                    unique = Services.HttpService:GenerateGUID(false),
                    category = "pets",
                    id = petKind,
                    kind = petKind,
                    properties = {
                        neon = props.neon or false,
                        mega_neon = props.mega_neon or false,
                        rideable = props.rideable or false,
                        flyable = props.flyable or false,
                    }
                },
                text = ("You won a %*!"):format(pet.name),
                button = "Add to Trade",
            })
            if spinnerSystem.lastWonPet and mockState.active and mockState.trade then
                local flags = props
                spinnerSystem.addPetToMySide(pet.name, {
                    F = flags.flyable or false,
                    R = flags.rideable or false,
                    N = flags.neon or false,
                    M = flags.mega_neon or false,
                })
            end
        end)
    end

    spinnerSystem.hideWinPopup = function() end

    spinnerSystem.animateStroke = function(stroke, color, thickness)
        Services.TweenService:Create(stroke, TweenInfo.new(0.12, Enum.EasingStyle.Quad), { Color = color, Thickness = thickness }):Play()
    end

    spinnerSystem.resetCard = function(card)
        local s = card:FindFirstChild("Stroke")
        if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardDefaultStroke, 2) end
        Services.TweenService:Create(card, TweenInfo.new(0.12), { BackgroundColor3 = spinnerSystem.THEME.cardDefaultBG }):Play()
        local idx = card:GetAttribute("CardIndex")
        if idx and spinnerSystem.rewardBoxes[idx] then
            Services.TweenService:Create(spinnerSystem.rewardBoxes[idx], TweenInfo.new(0.12), { BackgroundColor3 = spinnerSystem.THEME.rewardBoxDefault }):Play()
        end
    end

    spinnerSystem.highlightCard = function(card)
        local s = card:FindFirstChild("Stroke")
        if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardHighlightStroke, 3) end
        Services.TweenService:Create(card, TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.cardHighlightBG }):Play()
        local idx = card:GetAttribute("CardIndex")
        if idx and spinnerSystem.rewardBoxes[idx] then
            Services.TweenService:Create(spinnerSystem.rewardBoxes[idx], TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.rewardBoxHighlight }):Play()
        end
    end

    spinnerSystem.Strip = Instance.new("Frame")
    spinnerSystem.Strip.Name = "Strip"
    spinnerSystem.Strip.Size = UDim2.new(0, 100, 1, 0)
    spinnerSystem.Strip.Position = UDim2.new(0, 0, 0.5, 0)
    spinnerSystem.Strip.AnchorPoint = Vector2.new(0, 0.5)
    spinnerSystem.Strip.BackgroundTransparency = 1
    spinnerSystem.Strip.Parent = spinnerSystem.daysList

    spinnerSystem.Pointer = Instance.new("Frame")
    spinnerSystem.Pointer.Size = UDim2.new(0, 3, 0.7, 0)
    spinnerSystem.Pointer.Position = UDim2.new(0.5, 0, 0.5, 0)
    spinnerSystem.Pointer.AnchorPoint = Vector2.new(0.5, 0.5)
    spinnerSystem.Pointer.BackgroundColor3 = spinnerSystem.THEME.pointer
    spinnerSystem.Pointer.BorderSizePixel = 0
    spinnerSystem.Pointer.ZIndex = 10
    spinnerSystem.Pointer.Parent = spinnerSystem.daysList
    do
        local ps = Instance.new("UIStroke")
        ps.Color = spinnerSystem.THEME.pointerStroke
        ps.Thickness = 1
        ps.Transparency = 0.4
        ps.Parent = spinnerSystem.Pointer
    end

    spinnerSystem.MFR_PIP_SIZE = math.clamp(math.floor(spinnerSystem.CARD_SIZE * 0.17), 8, 16)

    spinnerSystem.buildStrip = function(tierName)
        if spinnerSystem.currentTier == tierName and #spinnerSystem.petCards > 0 then return end
        spinnerSystem.currentTier = tierName
        for _, child in ipairs(spinnerSystem.Strip:GetChildren()) do child:Destroy() end
        spinnerSystem.petCards = {}
        spinnerSystem.cardScales = {}
        spinnerSystem.rewardBoxes = {}
        spinnerSystem.persistentHL = -1
        spinnerSystem.PETS = spinnerSystem.resolvePetsForTier(tierName)
        spinnerSystem.STRIP_REPEATS = math.clamp(math.floor(300 / math.max(#spinnerSystem.PETS, 1)), 4, 30)
        spinnerSystem.SPIN_SETS = math.clamp(math.floor(spinnerSystem.STRIP_REPEATS / 4), 2, 8)
        spinnerSystem.STRIP_PETS = {}
        for _ = 1, spinnerSystem.STRIP_REPEATS do
            for _, pet in ipairs(spinnerSystem.PETS) do table.insert(spinnerSystem.STRIP_PETS, pet) end
        end
        spinnerSystem.Strip.Size = UDim2.new(0, #spinnerSystem.STRIP_PETS * spinnerSystem.CELL_WIDTH, 1, 0)
        spinnerSystem.Strip.Position = UDim2.new(0, 0, 0.5, 0)
        for i, pet in ipairs(spinnerSystem.STRIP_PETS) do
            local shadowFrame = Instance.new("Frame")
            shadowFrame.Name = "Shadow_" .. i
            shadowFrame.Size = UDim2.new(0, spinnerSystem.CARD_SIZE + 4, 0, spinnerSystem.CARD_SIZE + 4)
            shadowFrame.Position = UDim2.new(0, (i - 1) * spinnerSystem.CELL_WIDTH + spinnerSystem.CARD_SIZE / 2, 0.5, 2)
            shadowFrame.AnchorPoint = Vector2.new(0.5, 0.5)
            shadowFrame.BackgroundColor3 = spinnerSystem.THEME.cardShadow
            shadowFrame.BackgroundTransparency = 0.82
            shadowFrame.BorderSizePixel = 0
            shadowFrame.ZIndex = 0
            shadowFrame.Parent = spinnerSystem.Strip
            Instance.new("UICorner", shadowFrame).CornerRadius = UDim.new(0, 12)
            local card = Instance.new("Frame")
            card.Name = "Card_" .. i
            card.Size = UDim2.new(0, spinnerSystem.CARD_SIZE, 0, spinnerSystem.CARD_SIZE)
            card.Position = UDim2.new(0, (i - 1) * spinnerSystem.CELL_WIDTH, 0.5, 0)
            card.AnchorPoint = Vector2.new(0, 0.5)
            card.BackgroundColor3 = spinnerSystem.THEME.cardDefaultBG
            card.BorderSizePixel = 0
            card.ZIndex = 1
            card:SetAttribute("CardIndex", i)
            Instance.new("UICorner", card).CornerRadius = UDim.new(0, 10)
            local uiScale = Instance.new("UIScale")
            uiScale.Scale = 1
            uiScale.Parent = card
            spinnerSystem.cardScales[i] = uiScale
            local stroke = Instance.new("UIStroke")
            stroke.Name = "Stroke"
            stroke.Color = spinnerSystem.THEME.cardDefaultStroke
            stroke.Thickness = 2
            stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            stroke.Parent = card
            local innerBorder = Instance.new("Frame")
            innerBorder.Name = "InnerBorder"
            innerBorder.Size = UDim2.new(1, -4, 1, -4)
            innerBorder.Position = UDim2.new(0.5, 0, 0.5, 0)
            innerBorder.AnchorPoint = Vector2.new(0.5, 0.5)
            innerBorder.BackgroundTransparency = 1
            innerBorder.Parent = card
            Instance.new("UICorner", innerBorder).CornerRadius = UDim.new(0, 8)
            local innerStroke = Instance.new("UIStroke")
            innerStroke.Name = "InnerStroke"
            innerStroke.Color = spinnerSystem.THEME.innerStroke
            innerStroke.Thickness = 1
            innerStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            innerStroke.Parent = innerBorder
            local content = Instance.new("Frame")
            content.Name = "Content"
            content.Size = UDim2.new(1, -8, 1, -8)
            content.Position = UDim2.new(0.5, 0, 0.5, 0)
            content.AnchorPoint = Vector2.new(0.5, 0.5)
            content.BackgroundTransparency = 1
            content.Parent = card
            local rewardBox = Instance.new("Frame")
            rewardBox.Name = "RewardBox"
            rewardBox.Size = UDim2.new(0.55, 0, 0.11, 0)
            rewardBox.Position = UDim2.new(0.5, 0, 0, 0)
            rewardBox.AnchorPoint = Vector2.new(0.5, 0)
            rewardBox.BackgroundColor3 = spinnerSystem.THEME.rewardBoxDefault
            rewardBox.BorderSizePixel = 0
            rewardBox.ZIndex = 5
            rewardBox.Parent = content
            Instance.new("UICorner", rewardBox).CornerRadius = UDim.new(0, 6)
            local rwStroke = Instance.new("UIStroke")
            rwStroke.Color = Color3.fromRGB(160, 40, 40)
            rwStroke.Thickness = 1.5
            rwStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
            rwStroke.Parent = rewardBox
            local rwText = Instance.new("TextLabel")
            rwText.Size = UDim2.new(1, 0, 1, 0)
            rwText.BackgroundTransparency = 1
            rwText.Font = Enum.Font.GothamBold
            rwText.TextScaled = true
            rwText.TextColor3 = spinnerSystem.THEME.rewardTextDefault
            rwText.Text = "REWARD"
            rwText.ZIndex = 6
            rwText.Parent = rewardBox
            spinnerSystem.rewardBoxes[i] = rewardBox
            local img = spinnerSystem.ItemImageTemplate:Clone()
            img.Image = pet.image or ""
            img.Size = UDim2.new(1, 0, 0.52, 0)
            img.Position = UDim2.new(0.5, 0, 0.12, 0)
            img.AnchorPoint = Vector2.new(0.5, 0)
            img.ScaleType = Enum.ScaleType.Fit
            img.BackgroundTransparency = 1
            img.ZIndex = 1
            img.Parent = content
            local tagHolder = Instance.new("Frame")
            tagHolder.Name = "TagHolder"
            tagHolder.Size = UDim2.new(1, 0, 0.18, 0)
            tagHolder.Position = UDim2.new(0.5, 0, 0.65, 0)
            tagHolder.AnchorPoint = Vector2.new(0.5, 0)
            tagHolder.BackgroundTransparency = 1
            tagHolder.ZIndex = 1
            tagHolder.Parent = content
            pcall(function()
                Modules.UIManager.wrap(tagHolder, "ItemDataTagDisplay"):start({
                    item_data = pet.item_data, wearing = false, fixed_property_size = spinnerSystem.MFR_PIP_SIZE,
                })
            end)
            local nameLabel = Instance.new("TextLabel")
            nameLabel.Name = "PetName"
            nameLabel.Text = pet.name
            nameLabel.Font = Enum.Font.GothamBold
            nameLabel.TextScaled = true
            nameLabel.TextColor3 = spinnerSystem.THEME.petNameText
            nameLabel.Size = UDim2.new(1, 0, 0.16, 0)
            nameLabel.Position = UDim2.new(0.5, 0, 1, 0)
            nameLabel.AnchorPoint = Vector2.new(0.5, 1)
            nameLabel.BackgroundTransparency = 1
            nameLabel.TextTruncate = Enum.TextTruncate.AtEnd
            nameLabel.ZIndex = 1
            nameLabel.Parent = content
            card.Parent = spinnerSystem.Strip
            spinnerSystem.petCards[i] = card
        end
    end

    spinnerSystem.updateCardScales = function()
        local center = spinnerSystem.daysList.AbsolutePosition.X + spinnerSystem.vpW / 2
        for idx, card in ipairs(spinnerSystem.petCards) do
            local cardCenter = card.AbsolutePosition.X + spinnerSystem.CARD_SIZE / 2
            local dist = math.abs(cardCenter - center)
            local t = math.clamp(dist / (spinnerSystem.vpW / 2), 0, 1)
            local sc = spinnerSystem.cardScales[idx]
            if sc then sc.Scale = 1.12 - t * 0.24 end
        end
    end

    Services.RunService.Heartbeat:Connect(function()
        spinnerSystem.updateCardScales()
        local vc = spinnerSystem.vpW / 2
        local center = spinnerSystem.daysList.AbsolutePosition.X + vc
        for idx, card in ipairs(spinnerSystem.petCards) do
            local cc = card.AbsolutePosition.X + spinnerSystem.CARD_SIZE / 2
            if math.abs(cc - center) < spinnerSystem.CARD_SIZE / 2 then
                if idx ~= spinnerSystem.persistentHL then
                    if spinnerSystem.persistentHL > 0 and spinnerSystem.petCards[spinnerSystem.persistentHL] then
                        spinnerSystem.resetCard(spinnerSystem.petCards[spinnerSystem.persistentHL])
                    end
                    spinnerSystem.highlightCard(card)
                    spinnerSystem.persistentHL = idx
                end
                break
            end
        end
    end)

    spinnerSystem.doSpin = function()
        if spinnerSystem.spinning then return end
        spinnerSystem.spinning = true
        spinnerSystem.spinCount = spinnerSystem.spinCount + 1
        spinnerSystem.spinBtn:set_state("inactive")
        spinnerSystem.spinBtn:set_text("SPINNING...")
        spinnerSystem.hideWinPopup()
        Services.TweenService:Create(spinnerSystem.claimBtnInst, TweenInfo.new(0.15, Enum.EasingStyle.Quad), {
            Size = spinnerSystem.originalBtnSize - UDim2.new(0.03, 0, 0, 2)
        }):Play()
        for _, card in ipairs(spinnerSystem.petCards) do spinnerSystem.resetCard(card) end
        spinnerSystem.persistentHL = -1
        local winIndex = math.random(1, #spinnerSystem.PETS)
        local vc = spinnerSystem.vpW / 2
        local curX = spinnerSystem.Strip.Position.X.Offset
        local halfStrip = (#spinnerSystem.STRIP_PETS / 2) * spinnerSystem.CELL_WIDTH
        if -curX > halfStrip then
            local jumpBack = math.floor(spinnerSystem.STRIP_REPEATS / 2) * #spinnerSystem.PETS * spinnerSystem.CELL_WIDTH
            spinnerSystem.Strip.Position = UDim2.new(0, curX + jumpBack, 0.5, 0)
            curX = spinnerSystem.Strip.Position.X.Offset
        end
        local currentCenter = math.clamp(math.floor((-curX + vc) / spinnerSystem.CELL_WIDTH) + 1, 1, #spinnerSystem.STRIP_PETS)
        local targetIdx = math.clamp(currentCenter + ((spinnerSystem.SPIN_SETS or 3) * #spinnerSystem.PETS) + (winIndex - 1), 1, #spinnerSystem.STRIP_PETS)
        local targetX = -((targetIdx - 1) * spinnerSystem.CELL_WIDTH) + vc - (spinnerSystem.CARD_SIZE / 2)
        local spinTween = Services.TweenService:Create(spinnerSystem.Strip, TweenInfo.new(4, Enum.EasingStyle.Quint, Enum.EasingDirection.InOut), {
            Position = UDim2.new(0, targetX, 0.5, 0)
        })
        spinTween:Play()
        spinTween.Completed:Connect(function()
            local winCard = spinnerSystem.petCards[targetIdx]
            local winPet = spinnerSystem.STRIP_PETS[targetIdx]
            if winCard then
                local s = winCard:FindFirstChild("Stroke")
                for _ = 1, 3 do
                    if s then spinnerSystem.animateStroke(s, spinnerSystem.THEME.cardWinFlashStroke, 3.5) end
                    Services.TweenService:Create(winCard, TweenInfo.new(0.08), { BackgroundColor3 = spinnerSystem.THEME.cardWinFlashBG }):Play()
                    task.wait(0.12)
                    spinnerSystem.highlightCard(winCard)
                    task.wait(0.12)
                end
            end
            pcall(function() if spinnerSystem.SoundPlayer then spinnerSystem.SoundPlayer.FX:play("GoldSparklePrize") end end)
            task.wait(0.3)
            spinnerSystem.DailyLoginGui.Enabled = false
            spinnerSystem.MainFrame.Visible = false
            if winPet then spinnerSystem.showWinPopup(winPet) end
            spinnerSystem.spinBtn:set_state("normal")
            spinnerSystem.spinBtn:set_text("SPIN")
            spinnerSystem.spinning = false
        end)
    end

    spinnerSystem.spinBtn:set_mouse_button1_click(spinnerSystem.doSpin)

    spinnerSystem.selectTier = function(tierName)
        spinnerSystem.buildStrip(tierName)
        spinnerSystem.DailyLoginGui.Enabled = true
        spinnerSystem.MainFrame.Visible = true
        spinnerSystem.spinBtn:set_state("normal")
        spinnerSystem.spinBtn:set_text("SPIN")
    end

    spinnerSystem.showTierPopup = function()
        task.spawn(function()
            local response = Apps.DialogApp:dialog({
                text = "Which tier would you like to spin?",
                left = "High Tier",
                right = "Mid Tier",
            })
            if response == "High Tier" then
                spinnerSystem.selectTier("HIGH")
            elseif response == "Mid Tier" then
                spinnerSystem.selectTier("MID")
            end
        end)
    end

    spinnerSystem.showWheel = function()
        spinnerSystem.showTierPopup()
    end
end
