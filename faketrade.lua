local Services = {
   Players = game:GetService('Players'),
   ReplicatedStorage = game:GetService('ReplicatedStorage'),
   RunService = game:GetService('RunService'),
   UserInputService = game:GetService('UserInputService'),
   TweenService = game:GetService('TweenService'),
   HttpService = game:GetService('HttpService'),
   Chat = game:GetService('Chat')
}
local Players = Services.Players
local ReplicatedStorage = Services.ReplicatedStorage
local RunService = Services.RunService
local UserInputService = Services.UserInputService
local TweenService = Services.TweenService
local HttpService = Services.HttpService

pcall(function()
   setthreadidentity(2)
end)

-- COMPREHENSIVE HOOKS FOR FAKE PLAYERS - MUST BE FIRST
local fakePlayerIds = {}
_G.fakePlayerIds = fakePlayerIds

-- Hook SettingsHelper early with better fake player detection
task.spawn(function()
   task.wait(0.1)
   local SettingsHelper = require(ReplicatedStorage:WaitForChild('Fsys')).load('SettingsHelper')
   local original_get_setting_server = SettingsHelper.get_setting_server

   SettingsHelper.get_setting_server = function(player, settingName, ...)
       if player and player.UserId then
           if fakePlayerIds[player.UserId] then return false end
           if not Players:GetPlayerByUserId(player.UserId) then return false end
       end
       local args = { ... }
       local success, result = pcall(function()
           return original_get_setting_server(player, settingName, table.unpack(args))
       end)
       if success then return result else return false end
   end
end)

-- Hook FamilyHelper early
task.spawn(function()
   task.wait(0.1)
   local FamilyHelper = require(ReplicatedStorage:WaitForChild('Fsys')).load('FamilyHelper')
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

local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
local load = Fsys.load
local Modules = {
   UIManager = load('UIManager'),
   ClientData = load('ClientData'),
   TableUtil = load('TableUtil'),
   RouterClient = load('RouterClient'),
   InventoryDB = load('InventoryDB'),
   animationManager = load('AnimationManager'),
   ColorThemeManager = load('ColorThemeManager')
}
local UIManager = Modules.UIManager
local ClientData = Modules.ClientData
local TableUtil = Modules.TableUtil
local RouterClient = Modules.RouterClient
local InventoryDB = Modules.InventoryDB
local ColorThemeManager = Modules.ColorThemeManager
local animationManager = Modules.animationManager

if UIManager.wait_for_initialization then
   UIManager:wait_for_initialization()
else
   task.wait(2)
end

local Apps = {
   TradeApp = UIManager.apps.TradeApp,
   BackpackApp = UIManager.apps.BackpackApp,
   DialogApp = UIManager.apps.DialogApp,
   HintApp = UIManager.apps.HintApp,
   SettingsApp = UIManager.apps.SettingsApp,
   PlayerProfileApp = UIManager.apps.PlayerProfileApp,
   TradeHistoryApp = UIManager.apps.TradeHistoryApp,
   TradePreviewApp = UIManager.apps.TradePreviewApp
}
local TradeApp = Apps.TradeApp
local BackpackApp = Apps.BackpackApp
local HintApp = Apps.HintApp
local DialogApp = Apps.DialogApp
local TradeHistoryApp = Apps.TradeHistoryApp
local PlayerProfileApp = Apps.PlayerProfileApp

local NegotiationFrame = Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame

local function FriendHighlight(FriendValue)
   NegotiationFrame.FriendHighlight.Visible = FriendValue
   NegotiationFrame.FriendBorder.Visible = FriendValue
   local PartnerFrame = NegotiationFrame.Header.PartnerFrame
   NegotiationFrame.Header.PartnerFrame.NameLabel.FriendLabel.Visible = FriendValue
   local ColorThemeManagerColor = ColorThemeManager.lookup(FriendValue and 'background' or 'saturated')
   NegotiationFrame.Header.PartnerFrame.ProfileIcon.ImageColor3 = ColorThemeManagerColor
   NegotiationFrame.Header.PartnerFrame.NameLabel.TextColor3 = ColorThemeManagerColor
   NegotiationFrame.Header.PartnerFrame.Icon.Visible = FriendValue
   NegotiationFrame.Header.PartnerFrame.Icon.Image = 'rbxassetid://84667805159408'
end

local downloader = load('DownloadClient')
local petModels = {}

local function getPetModel(kind)
   if petModels[kind] then return petModels[kind]:Clone() end
   local success, streamed = pcall(function()
       local promise = downloader.promise_download_copy('Pets', kind)
       if promise then return promise:expect() end
       return nil
   end)
   if success and streamed then
       petModels[kind] = streamed
       return streamed:Clone()
   else
       warn('Failed to download pet model for:', kind)
       return nil
   end
end

if not TradeApp then return end

-- ==================== PET VALUE SYSTEM ====================
local petDisplayNames = {}
for category, items in pairs(InventoryDB) do
   if category == "pets" then
       for id, petinfo in pairs(items) do
           petDisplayNames[id] = petinfo.name
       end
   end
end

-- Fallback pet values when API fails (from winadopt.me/elvebredd)
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
}

local function fetchPetValues()
   local success, response = pcall(function()
       return request({
           Url = "https://elvebredd.com/api/pets/get-latest",
           Method = "GET",
           Headers = {
               ["Accept"] = "*/*",
               ["User-Agent"] = "Mozilla/5.0"
           }
       })
   end)
   if success and response and response.Success then
       local decodeSuccess, responseData = pcall(function()
           return HttpService:JSONDecode(response.Body)
       end)
       if decodeSuccess and responseData and responseData.pets then
           local petsSuccess, petsData = pcall(function()
               return HttpService:JSONDecode(responseData.pets)
           end)
           if petsSuccess and petsData and next(petsData) then
               return petsData
           end
       end
   end
   -- Return fallback values if API fails
   return fallbackPetValues
end

local petsByName = {}
local petValues = fetchPetValues()
for key, pet in pairs(petValues) do
   if type(pet) == "table" and pet.name then
       petsByName[pet.name] = pet
   end
end

local function getPetValue(petKind, petProps)
   local displayName = petDisplayNames[petKind] or petKind
   local pet = petsByName[displayName]
   if not pet then return 0 end
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
   return pet[key] or pet[baseKey] or 0
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
                           displayName = petDisplayNames[pet.kind] or pet.kind,
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

local fetchProfile = RouterClient.get("PlayerProfileAPI/FetchProfile")
-- ==================== END PET VALUE SYSTEM ====================

local CONFIG = {
   PARTNER_NAME = 'RobyPolarBearYT',
   PARTNER_USER_ID = 987654321,
   AUTO_ACCEPT_DELAY = 0.2,
   AUTO_CONFIRM_DELAY = 0.3,
   SPECTATOR_COUNT = 4,
   SPECTATOR_VARIATION_MIN = -1,  -- Minimum variation from base count
   SPECTATOR_VARIATION_MAX = 2,   -- Maximum variation from base count
   AUTO_SPECTATE_ENABLED = false,
   AUTO_SPECTATE_INTERVAL = 1.5,
   AUTO_PARTNER = true,
   NEGOTIATION_LOCK = 5,
   CONFIRMATION_LOCK_PER_ITEM = 3,
   SHOW_TRADE_REQUEST = true,  -- Set to true to show trade request dialog first
   TRADE_REQUEST_DELAY = 0,
   ADD_PET_REQUEST_DELAY = 0.5,
   SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = false,
   FAKE_PLAYER_ACCEPT_TRADE_REQUEST = 2,
   CHAT_MESSAGES = {
       'Ucciditi?', 'Obeso fai schifo regalami i tuoi pet', 'Aggiungi coglione??', 'Negro di merda', 'frocio succhiami il cazzo', 'Tutti a mettere il follow?',
       'Respinna ti prego?', 'balena', 'aggiungi o ti declino lo scambio coglione', 'abiti a Venezia vero?', 'è finita per te',
       'Can i get mega pet', 'Disabile', 'Hai 10 secondi per darmi i pet', '5 secondi da adesso',
       'sei da solo a casa?', 'frocetto sto arrivando a casa tua, ora uccido tutti i tuoi parenti',
   },
   AUTO_CHAT_DELAY = 2,
   VERIFIED_FRIENDS = {
       'Agusmareborn', 'Kellyvault', 'J3llynoah', 'Rainbowriley321',
       'Bobazmalibu', 'H3llSANG3LX', 'Xcallmeholly', 'Niniko_201999',
   },
   SHOW_VERIFIED_FRIEND = false,
   FRIEND_PARTNER = true,
   REMOVE_PARTNER_PETS_ON_CONFIRM = false,
}

-- Store original spectator count for reset functionality
local ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT

-- Function to get randomized spectator count based on original value
local function getRandomSpectatorCount()
   local variation = math.random(CONFIG.SPECTATOR_VARIATION_MIN, CONFIG.SPECTATOR_VARIATION_MAX)
   local newCount = ORIGINAL_SPECTATOR_COUNT + variation
   return math.max(0, newCount) -- Ensure it doesn't go negative
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
   isMockTradeDialog = false, -- NEW: Flag to track mock trade dialog
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
   'Evil Unicorn', 'Arctic Reindeer', 'Dalmatian', 'Turtle', 'Kangaroo', 'Peppermint Penguin', 
   'Strawberry Shortcake Bat Dragon', 'Chocolate Chip Bat Dragon', 'Cow', 'Mini Pig',
}

local customUsers = {
   'aliceroblox6166', 'DIVAHOLIC', 'iiicristianxx_o', 'Darcie_epic', 'banan_bartek1234',
   's18amg', 'Chicken_nuggitx23817', 'RmSbx_x', 'siqnnaz', 'Nidaanurr7', 'Kkiraly',
   'daisydoo_billy', 'youssefsalah135', 'aurivxs', 'princeplay', 'sofysofy986353',
   'heaseung008800112277'
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
   for category_name, category_table in pairs(InventoryDB) do
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
       if TradeApp and TradeApp._check_if_player_has_trade_license then
           return TradeApp:_check_if_player_has_trade_license(player)
       end
       local result = RouterClient.get('TradeAPI/GetTradeLicenseStatus'):InvokeServer(player.UserId)
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
       if TradeApp[funcName] then
           mockState.originalFunctions[funcName] = TradeApp[funcName]
       end
   end
   if TradeHistoryApp then
       if TradeHistoryApp._get_trade_history then
           mockState.originalGetTradeHistory = TradeHistoryApp._get_trade_history
       end
       if TradeHistoryApp.report_scam then
           mockState.originalReportScam = TradeHistoryApp.report_scam
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
           if k == 'Parent' then return Players end
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
       sender = Players.LocalPlayer,
       recipient = partner,
       sender_offer = { items = {}, player_name = Players.LocalPlayer.Name, negotiated = false, confirmed = false },
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
       sender_user_id = Players.LocalPlayer.UserId,
       sender_name = Players.LocalPlayer.Name,
       sender_items = TableUtil.deep_copy(trade.sender_offer.items),
       recipient_user_id = trade.recipient.UserId,
       recipient_name = CONFIG.PARTNER_NAME,
       recipient_items = TableUtil.deep_copy(trade.recipient_offer.items),
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
   if not TradeHistoryApp then return end

   TradeHistoryApp._get_trade_history = function(self, useCache)
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

   TradeHistoryApp.report_scam = function(self, tradeData)
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
   local v145 = TradeApp._get_partner().UserId
   v144[tostring(v145)] = args1
   TradeApp.partner_negotiation_offer_pane:display_busy(v144[tostring(v145)])
end

local function addPetToPartnerOffer(petName, flags)
   if not mockState.active or not mockState.trade then return false, 'No active mock trade' end
   if mockState.trade.current_stage == 'confirmation' then return false, 'Cannot modify during confirmation' end
   if #mockState.trade.recipient_offer.items >= 18 then return end

   update_busy_indicators({ ['picking'] = true })
   task.wait(CONFIG.ADD_PET_REQUEST_DELAY)

   for category_name, category_table in pairs(InventoryDB) do
       if category_name == 'pets' then
           for id, item in pairs(category_table) do
               if item.name == petName then
                   local petItem = {
                       category = 'pets',
                       kind = id,
                       unique = HttpService:GenerateGUID(),
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
                   TradeApp:_overwrite_local_trade_state(mockState.trade)
                   if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
                   if TradeApp._render_message_in_trade_chat then
                       TradeApp:_render_message_in_trade_chat(nil, string.format('%s added %s.', CONFIG.PARTNER_NAME, petName), true)
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
   TradeApp:_overwrite_local_trade_state(mockState.trade)
   if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
   if TradeApp._render_message_in_trade_chat then
       local itemName = 'item'
       if removedItem.category == 'pets' then
           for _, category_table in pairs(InventoryDB) do
               for id, item in pairs(category_table) do
                   if id == removedItem.kind then itemName = item.name break end
               end
           end
       end
       TradeApp:_render_message_in_trade_chat(nil, string.format('%s removed %s.', CONFIG.PARTNER_NAME, itemName), true)
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
   if TradeApp and TradeApp._render_message_in_trade_chat then
       TradeApp:_render_message_in_trade_chat(nil, string.format('%s: %s', CONFIG.PARTNER_NAME, message), true)
       return true
   end
   return false
end

local function removePartnerPetsVisually()
   if not mockState.active or not mockState.trade then return false end
   local partnerItems = mockState.trade.recipient_offer.items
   if #partnerItems == 0 then return false end
   mockState.partnerPetsBeforeConfirm = TableUtil.deep_copy(partnerItems)
   mockState.trade.recipient_offer.items = {}
   mockState.trade.offer_version = mockState.trade.offer_version + 1
   TradeApp:_overwrite_local_trade_state(mockState.trade)
   return true
end

local showBlockedTradeRequests

local function partnerAutoAction()
   if not mockState.active or not mockState.trade or mockState.partnerActionPending then return end
   mockState.partnerActionPending = true

   while TradeApp.lock_countdown and TradeApp.lock_countdown.is_going and TradeApp.lock_countdown:is_going() do
       task.wait(0.1)
   end

   if mockState.trade.current_stage == 'negotiation' then
       task.wait(CONFIG.AUTO_ACCEPT_DELAY)
       if mockState.active and mockState.trade then
           mockState.trade.recipient_offer.negotiated = true
           if mockState.trade.sender_offer.negotiated then
               mockState.trade.current_stage = 'confirmation'
               mockState.trade.offer_version = mockState.trade.offer_version + 1
               TradeApp:_overwrite_local_trade_state(mockState.trade)
               if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
               if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
           else
               mockState.trade.offer_version = mockState.trade.offer_version + 1
               TradeApp:_overwrite_local_trade_state(mockState.trade)
           end
       end
   elseif mockState.trade.current_stage == 'confirmation' then
       task.wait(CONFIG.AUTO_CONFIRM_DELAY)
       if mockState.active and mockState.trade then
           mockState.trade.recipient_offer.confirmed = true
           mockState.trade.offer_version = mockState.trade.offer_version + 1
           TradeApp:_overwrite_local_trade_state(mockState.trade)
           if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
               mockState.tradeCompleting = true
               if TradeApp._set_confirmation_arrow_rotating then TradeApp:_set_confirmation_arrow_rotating(true) end
               task.wait(3)
               local historyRecord = createTradeHistoryRecord(mockState.trade)
               appendToTradeHistory(historyRecord)
               mockState.active = false
               mockState.trade = nil
               mockState.tradeCompleting = false
               mockState.scamWarningShown = true
               mockState.canShowTradeRequest = true
               mockState.tradeRequestBlocked = false
               UIManager.set_app_visibility('TradeApp', false)
               task.wait(0.1)
               showBlockedTradeRequests()
               if HintApp then HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
               if TradeHistoryApp and UIManager.is_visible('TradeHistoryApp') then TradeHistoryApp:_refresh() end
           end
       end
   end
   mockState.partnerActionPending = false
end

local function hookTradeFunctions()
   TradeApp._get_local_trade_state = function(self)
       if mockState.active and mockState.trade then return TableUtil.deep_copy(mockState.trade) end
       return mockState.originalFunctions._get_local_trade_state(self)
   end

   TradeApp._overwrite_local_trade_state = function(self, newState)
       if mockState.active then
           if newState then
               mockState.trade = newState
               self.local_trade_state = newState
               if mockState.trade then mockState.trade.subscriber_count = CONFIG.SPECTATOR_COUNT end
               if self._on_local_trade_state_changed then self:_on_local_trade_state_changed(newState, newState) end
               if self.refresh_all then self:refresh_all() FriendHighlight(true) end
           else
               mockState.trade = nil
               mockState.active = false
               mockState.scamWarningShown = false
               mockState.canShowTradeRequest = true
               mockState.tradeRequestBlocked = false
               self.local_trade_state = nil
               showBlockedTradeRequests()
           end
       else
           return mockState.originalFunctions._overwrite_local_trade_state(self, newState)
       end
   end

   TradeApp._get_my_offer = function(self)
       local state = self:_get_local_trade_state()
       if mockState.active and state then
           if Players.LocalPlayer == state.sender then return state.sender_offer, 'sender_offer' else return state.recipient_offer, 'recipient_offer' end
       end
       return mockState.originalFunctions._get_my_offer(self)
   end

   TradeApp._get_partner_offer = function(self)
       local state = self:_get_local_trade_state()
       if mockState.active and state then
           if Players.LocalPlayer == state.sender then return state.recipient_offer, 'recipient_offer' else return state.sender_offer, 'sender_offer' end
       end
       return mockState.originalFunctions._get_partner_offer(self)
   end

   TradeApp._get_my_player = function(self)
       if mockState.active and mockState.trade then return Players.LocalPlayer end
       return mockState.originalFunctions._get_my_player(self)
   end

   TradeApp._get_partner = function(self)
       if mockState.active and mockState.trade then return mockState.trade.recipient end
       return mockState.originalFunctions._get_partner(self)
   end

   TradeApp._get_current_trade_stage = function(self)
       if mockState.active and mockState.trade then return mockState.trade.current_stage end
       return mockState.originalFunctions._get_current_trade_stage(self)
   end

   TradeApp._change_local_trade_state = function(self, changes)
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

   TradeApp._get_lock_time = function(self)
       if mockState.active and mockState.trade then
           if self:_get_current_trade_stage() == 'negotiation' then return CONFIG.NEGOTIATION_LOCK
           else return math.clamp(CONFIG.CONFIRMATION_LOCK_PER_ITEM * (#mockState.trade.sender_offer.items + #mockState.trade.recipient_offer.items), 5, 15) end
       end
       return mockState.originalFunctions._get_lock_time(self)
   end

   TradeApp._lock_trade_for_appropriate_time = function(self)
       if mockState.active then
           if self.lock_countdown then self.lock_countdown:stop() self.lock_countdown:set_duration(self:_get_lock_time()) self.lock_countdown:start() end
       else
           return mockState.originalFunctions._lock_trade_for_appropriate_time(self)
       end
   end

   TradeApp._add_item_to_my_offer = function(self)
       if mockState.active and mockState.trade then
           if mockState.isAddingItem then return end
           mockState.isAddingItem = true
           
           local pickedItem = nil
           pcall(function()
               pickedItem = BackpackApp:pick_item({ 
                   keep_cached_scroll_positions_on_open = true, 
                   allow_callback = function() return true end 
               })
           end)
           
           if pickedItem then
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
                       if BackpackApp and BackpackApp.set_item_unique_hidden then 
                           BackpackApp:set_item_unique_hidden(pickedItem.unique, 'TradeApp') 
                       end
                   end)
               end
           end
           mockState.isAddingItem = false
       else
           return mockState.originalFunctions._add_item_to_my_offer(self)
       end
   end

   TradeApp._remove_item_from_my_offer = function(self, item)
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
                   if BackpackApp.reset_hidden_item_tag then BackpackApp:reset_hidden_item_tag('TradeApp') end
                   break
               end
           end
       else
           return mockState.originalFunctions._remove_item_from_my_offer(self, item)
       end
   end

   TradeApp._on_accept_pressed = function(self)
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
                   if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
                   if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
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

   TradeApp._on_confirm_pressed = function(self)
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

   TradeApp._on_unaccept_pressed = function(self)
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

   TradeApp._decline_trade = function(self, silent)
       if mockState.active then
           if self.lock_countdown then self.lock_countdown:stop() end
           mockState.active = false
           mockState.trade = nil
           mockState.isAddingItem = false
           mockState.partnerActionPending = false
           mockState.tradeCompleting = false
           mockState.scamWarningShown = false
           mockState.canShowTradeRequest = true
           mockState.tradeRequestBlocked = false
           self:_overwrite_local_trade_state(nil)
           UIManager.set_app_visibility('TradeApp', false)
           if BackpackApp.reset_hidden_item_tag then BackpackApp:reset_hidden_item_tag('TradeApp') end
           showBlockedTradeRequests()
       else
           return mockState.originalFunctions._decline_trade(self, silent)
       end
   end

   TradeApp._evaluate_trade_fairness = function(self)
       if mockState.active and mockState.trade and not mockState.scamWarningShown then
           local myItems = #mockState.trade.sender_offer.items
           local partnerItems = #mockState.trade.recipient_offer.items
           if myItems > 0 and partnerItems == 0 then
               mockState.scamWarningShown = true
               if DialogApp then
                   DialogApp:dialog({ text = 'This trade seems unbalanced. Be careful - you could be getting scammed.', button = 'Next', yields = false })
                   DialogApp:dialog({ text = 'Any items lost to scams WILL NOT be returned. Be sure before you accept!', button = 'I understand', yields = false })
               end
           end
       else
           return mockState.originalFunctions._evaluate_trade_fairness(self)
       end
   end
end

hookTradeFunctions()

-- FIXED: Function to start mock trade directly without dialog issues
local function startMockTradeDirectly()
   -- Only prevent if already in a trade
   if mockState.active then return end
   
   local success, err = pcall(function()
       -- Reset all states first
       mockState.active = false
       mockState.trade = nil
       mockState.isAddingItem = false
       mockState.partnerActionPending = false
       mockState.tradeCompleting = false
       mockState.scamWarningShown = true
       mockState.tradeRequestBlocked = true
       mockState.blockedTradeRequests = {}
       mockState.pendingTradeRequest = false
       
       -- Create mock trade
       mockState.trade = createMockTrade()
       
       -- Set active immediately
       mockState.active = true
       
       -- Close any existing trade UI
       pcall(function() UIManager.set_app_visibility('TradeApp', false) end)
       task.wait(0.05)
       
       -- Overwrite trade state
       pcall(function() TradeApp:_overwrite_local_trade_state(mockState.trade) end)
       task.wait(0.05)
       
       -- Show trade UI
       pcall(function() UIManager.set_app_visibility('TradeApp', true) end)
       pcall(function() FriendHighlight(true) end)
       
       -- Show intro message (public chat notice)
       pcall(function()
           if TradeApp._show_intro_message then
               TradeApp:_show_intro_message()
           end
       end)
       
       task.wait(0.05)
       pcall(function() 
           if TradeApp.refresh_all then 
               TradeApp:refresh_all() 
               FriendHighlight(true) 
           end 
       end)
   end)
   
   if not success and HintApp then
       HintApp:hint({ text = 'Error starting trade: ' .. tostring(err), length = 5, overridable = true })
   end
end

-- FIXED: showTradeRequest function with proper dialog handling
local function showTradeRequest()
   if mockState.pendingTradeRequest or mockState.active then
       return
   end
   mockState.pendingTradeRequest = true
   mockState.canShowTradeRequest = false
   task.wait(CONFIG.TRADE_REQUEST_DELAY)
   if not mockState.pendingTradeRequest or mockState.active then
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
       },
       ["yields"] = true
   } 
   local trade_request_table_not_friend = { 
       ["text"] = name .. " sent you a trade request", 
       ["left"] = "Decline", 
       ["right"] = "Accept",
       ["yields"] = true
   } 
   
   -- Set flag so hookDialogApp doesn't interfere
   mockState.isMockTradeDialog = true
   
   local dialogResult
   local success, err = pcall(function()
       -- Use original function directly to avoid hook interference
       if mockState.originalDialogFunction then
           if CONFIG.FRIEND_PARTNER then
               dialogResult = mockState.originalDialogFunction(DialogApp, trade_request_table_friend)
           else
               dialogResult = mockState.originalDialogFunction(DialogApp, trade_request_table_not_friend)
           end
       else
           if CONFIG.FRIEND_PARTNER then
               dialogResult = DialogApp:dialog(trade_request_table_friend)
           else
               dialogResult = DialogApp:dialog(trade_request_table_not_friend)
           end
       end
   end)
   
   mockState.isMockTradeDialog = false
   mockState.pendingTradeRequest = false
   
   if success and dialogResult and (dialogResult == "Accept" or dialogResult == "right") then
       startMockTradeDirectly()
   else
       mockState.canShowTradeRequest = true
   end
end

local function hookTradeRequestEvent()
   local tradeRequestEvent = RouterClient.get_event('TradeAPI/TradeRequestReceived')
   if tradeRequestEvent then
       local originalConnections = getconnections(tradeRequestEvent.OnClientEvent)
       for _, connection in pairs(originalConnections) do connection:Disable() end
       tradeRequestEvent.OnClientEvent:Connect(function(requestingPlayer)
           if mockState.active or mockState.tradeRequestBlocked then
               table.insert(mockState.blockedTradeRequests, { player = requestingPlayer, timestamp = tick() })
               return
           end
           for _, connection in pairs(originalConnections) do
               if connection.Function then connection.Function(requestingPlayer) end
           end
       end)
   end
end

-- FIXED: hookDialogApp to not interfere with mock trade dialogs
local function hookDialogApp()
   if not DialogApp or not DialogApp.dialog then return end
   mockState.originalDialogFunction = DialogApp.dialog
   DialogApp.dialog = function(self, dialogData)
       -- Don't interfere with expired dialogs
       if dialogData and dialogData.text and string.find(dialogData.text, 'has expired!') then return 'Okay' end
       
       -- FIXED: Don't auto-decline if this is our mock trade dialog
       if mockState.isMockTradeDialog then
           return mockState.originalDialogFunction(self, dialogData)
       end
       
       -- FIXED: Also check for Verified Friend header to not auto-decline our dialogs
       if dialogData and dialogData.header and type(dialogData.header) == 'table' and dialogData.header.text == 'Verified Friend' then
           return mockState.originalDialogFunction(self, dialogData)
       end
       
       -- Auto-decline real trade requests while mock trade is active
       if dialogData and dialogData.handle == 'trade_request' then
           if mockState.pendingTradeRequest or mockState.active or mockState.tradeRequestBlocked then return 'Decline' end
       end
       
       return mockState.originalDialogFunction(self, dialogData)
   end
end

hookDialogApp()
hookTradeRequestEvent()

showBlockedTradeRequests = function()
   if #mockState.blockedTradeRequests > 0 then
       task.wait(0.5)
       local TradeExcluder = load('TradeExcluder')
       for _, request in ipairs(mockState.blockedTradeRequests) do
           local requestingPlayer = request.player
           if TradeExcluder and TradeExcluder.is_player_excluded(requestingPlayer) then
               RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, false)
           else
               if DialogApp and mockState.originalDialogFunction then
                   local response = mockState.originalDialogFunction(DialogApp, {
                       text = string.format('%s sent you a trade request', requestingPlayer.Name),
                       left = 'Decline', right = 'Accept', handle = 'trade_request',
                   })
                   if response == 'Accept' then
                       local shouldAccept = true
                       if TradeApp._confirm_player_if_suspicious then shouldAccept = TradeApp:_confirm_player_if_suspicious(requestingPlayer) end
                       if shouldAccept and not TradeApp:check_and_warn_if_trading_restricted() then TradeApp:show_scam_warning() end
                       RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, shouldAccept)
                   else
                       RouterClient.get('TradeAPI/AcceptOrDeclineTradeRequest'):InvokeServer(requestingPlayer, false)
                   end
               end
           end
       end
       mockState.blockedTradeRequests = {}
   end
end

-- Hook partner profile button to show mock partner's profile
task.spawn(function()
   task.wait(1) -- Wait for TradeApp to fully initialize
   pcall(function()
       if TradeApp and TradeApp.partner_profile_button then
           local profileButton = TradeApp.partner_profile_button
           if profileButton.callbacks and profileButton.callbacks.mouse_button1_click then
               local originalProfileClick = profileButton.callbacks.mouse_button1_click
               profileButton.callbacks.mouse_button1_click = function()
                   if mockState.active and mockState.trade and mockState.trade.recipient then
                       if PlayerProfileApp and PlayerProfileApp.open_player_profile_for_user_id then 
                           PlayerProfileApp:open_player_profile_for_user_id(mockState.trade.recipient.UserId) 
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
   local success, userId = pcall(function() return Players:GetUserIdFromNameAsync(username) end)
   if success and userId then
       CONFIG.PARTNER_USER_ID = userId
       CONFIG.PARTNER_NAME = username
       mockPartner = createMockPartner()
       return true
   else
       CONFIG.PARTNER_NAME = username
       mockPartner = createMockPartner()
       return false
   end
end

local function applyMegaNeonEffects(petModel, kind)
   local petRigs = load('new:PetRigs')
   local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
   local petData = InventoryDB.pets[kind]
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
   local petRigs = load('new:PetRigs')
   local petModelInstance = petModel:FindFirstChild('PetModel') or petModel
   local petData = InventoryDB.pets[kind]
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
       blockPlayer = Enum.KeyCode.B
   },
   waitingForKeybind = nil
}
local tabFrames = UIState.tabFrames
local tabButtons = UIState.tabButtons
local richestData = UIState.richestData
local expandedPlayers = UIState.expandedPlayers

local FakePlayers = {}
local FakePetRegistry = {}

local function updateData(key, action)
   local data = ClientData.get(key)
   local clonedData = table.clone(data)
   ClientData.predict(key, action(clonedData))
end

local AnimationManager = { running = false, checkInterval = 0.3, animationTracks = {} }

function AnimationManager:Start()
   if self.running then return end
   self.running = true
   task.spawn(function()
       while self.running do
           task.wait(self.checkInterval)
           for _, petData in ipairs(FakePetRegistry) do
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
                                           petData.ridingAnim = animator:LoadAnimation(animationManager.get_track('PlayerRidingPet'))
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
   for _, petData in ipairs(FakePetRegistry) do
       if petData.ridingAnim then petData.ridingAnim:Stop() end
   end
end

function AnimationManager:AddPet(petData)
   table.insert(FakePetRegistry, petData)
   if not self.running then self:Start() end
end

local function createFakePetOwner(fakeCharacter, partnerName, partnerId)
   return setmetatable({
       Name = partnerName, DisplayName = partnerName, UserId = partnerId, Character = fakeCharacter,
   }, {
       __index = function(t, k)
           if k == 'Parent' then return Players end
           if k == 'IsA' then return function(self, className) return className == 'Player' end end
           if k == 'GetChildren' then return function() return {} end end
           return rawget(t, k)
       end,
       __tostring = function() return partnerName end
   })
end

function OpenProfile(Id)
   UIManager.apps.PlayerProfileApp:open_player_profile_for_user_id(Id)
end

task.spawn(function()
   task.wait(0.1)
   local InteractionsEngine = load('InteractionsEngine')
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

       local character = Players:CreateHumanoidModelFromUserId(partner_id)
       local playerCharacter = Players.LocalPlayer.Character
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
               local ridingAnim = character.Humanoid.Animator:LoadAnimation(animationManager.get_track('PlayerRidingPet'))
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
                   pet_trick_level = math.random(1, 5), pet_unique = HttpService:GenerateGUID(false), pet_id = kind,
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
               table.insert(FakePetRegistry, {
                   wrapper = petWrapper, state = petState, model = petModel, character = character,
                   hasRidingPet = true, owner = fakePetOwner, ridingAnim = ridingAnim, folder = folder_fake,
               })
               if not AnimationManager.running then AnimationManager:Start() end
               petCreated = true
               print('? Registered fake pet with native game systems:', kind, pet_flags and (pet_flags.M and 'Mega Neon' or pet_flags.N and 'Neon' or 'Regular') or 'Regular')
           end)
           if not success or not petCreated then
               warn('Error creating fake pet (Attempt ' .. retryCount .. '/' .. maxRetries .. '):', err)
               folder_fake:Destroy()
               for i, folder in ipairs(FakePlayers) do if folder == folder_fake then table.remove(FakePlayers, i) break end end
               if retryCount < maxRetries then
                   print('? Retrying fake character creation for ' .. partner_name .. '...')
                   task.wait(0.5)
                   return attemptCreate()
               else
                   warn('? Failed to create fake character after ' .. maxRetries .. ' attempts')
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

       pcall(function() UIManager.apps.PlayerNameApp:add_npc_id(character, partner_name) end)

       local Part = character:FindFirstChild('HumanoidRootPart')
       if Part then
           local InteractionsEngine = load('InteractionsEngine')
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
                                       if HintApp then HintApp:hint({ text = 'Trade request sent to ' .. partner_name, length = 3, overridable = true }) end
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

       table.insert(FakePlayers, folder_fake)
       folder_fake:SetAttribute('IsFakePlayer', true)
       folder_fake:SetAttribute('PartnerName', partner_name)
       folder_fake:SetAttribute('PartnerId', partner_id)
       return true
   end

   return attemptCreate()
end

function GetKindPet(name)
   for k, v in pairs(InventoryDB.pets) do
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
   for _, folder in ipairs(FakePlayers) do
       if folder and folder.Parent then
           for _, child in ipairs(folder:GetChildren()) do
               if child:IsA('Model') then enableNoclip(child) end
           end
       end
   end
end

local function enableNoclipForPets()
   for _, petData in ipairs(FakePetRegistry) do
       if petData and petData.model and petData.model.Parent then enableNoclip(petData.model) end
   end
end

-- ORIGINAL BlockPlayer function
function BlockPlayer(Selected)
   pcall(function()
       setthreadidentity(8)
   end)
   game:GetService('StarterGui'):SetCore('PromptBlockPlayer', Selected)
   repeat
       game:GetService('RunService').Heartbeat:Wait()
   until game:GetService('CoreGui'):FindFirstChild('BlockingModalScreen')
   game:GetService('CoreGui').BlockingModalScreen.BlockingModalContainer.BlockingModalContainerWrapper.BlockingModal.BackgroundTransparency = 1
   game:GetService('CoreGui').BlockingModalScreen.BlockingModalContainer.BlockingModalContainerWrapper.BackgroundTransparency = 1
   game:GetService('CoreGui').BlockingModalScreen.BlockingModalContainer.BackgroundTransparency = 1
   game:GetService('CoreGui').BlockingModalScreen.BlockingModalContainer.BlockingModalContainerWrapper.BlockingModal.AlertModal.Position = UDim2.new(0.00800000038, -110, 0.5, 0)
   local interact = function(path)
       game:GetService('GuiService').SelectedObject = path
       task.wait()
       if game:GetService('GuiService').SelectedObject == path then
           game:GetService('VirtualInputManager'):SendKeyEvent(true, Enum.KeyCode.Return, false, game)
           game:GetService('VirtualInputManager'):SendKeyEvent(false, Enum.KeyCode.Return, false, game)
           task.wait()
       end
       game:GetService('GuiService').SelectedObject = nil
   end
   interact(game:GetService('CoreGui').BlockingModalScreen.BlockingModalContainer.BlockingModalContainerWrapper.BlockingModal.AlertModal.AlertContents.Footer.Buttons['3'])
   pcall(function()
       setthreadidentity(2)
   end)
end

-- FIXED: Send trade request to real player using the correct API
local function sendTradeToPlayer(player)
   if not player then return end
   local targetPlayer = Players:FindFirstChild(player.Name)
   if targetPlayer then
       pcall(function()
           -- Try multiple methods to send trade request
           local success = false
           
           -- Method 1: Use RouterClient
           if not success then
               local success1 = pcall(function()
                   local sendRequest = RouterClient.get('TradeAPI/SendTradeRequest')
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
           
           -- Method 2: Try direct remote
           if not success then
               local success2 = pcall(function()
                   local TradeRemote = ReplicatedStorage:FindFirstChild('Remotes') and ReplicatedStorage.Remotes:FindFirstChild('TradeAPI') and ReplicatedStorage.Remotes.TradeAPI:FindFirstChild('SendTradeRequest')
                   if TradeRemote then
                       TradeRemote:FireServer(targetPlayer)
                       success = true
                   end
               end)
           end
           
           -- Method 3: Use InteractionsEngine
           if not success then
               local success3 = pcall(function()
                   local InteractionsEngine = load('InteractionsEngine')
                   if InteractionsEngine then
                       InteractionsEngine:send_trade_request(targetPlayer)
                       success = true
                   end
               end)
           end
           
           if success and HintApp then
               HintApp:hint({ text = 'Trade request sent to ' .. player.Name, length = 3, overridable = true })
           elseif HintApp then
               HintApp:hint({ text = 'Could not send trade request to ' .. player.Name, length = 3, overridable = true })
           end
       end)
   else
       if HintApp then
           HintApp:hint({ text = 'Player ' .. player.Name .. ' not found in server', length = 3, overridable = true })
       end
   end
end

-- ==================== AUTO SPECTATE WITH RANDOM VARIATION ====================
local autoSpectateConnection = nil

local function startAutoSpectate()
   if autoSpectateConnection then return end
   
   autoSpectateConnection = task.spawn(function()
       while CONFIG.AUTO_SPECTATE_ENABLED do
           task.wait(CONFIG.AUTO_SPECTATE_INTERVAL)
           
           if mockState.active and mockState.trade then
               -- Get a new random spectator count
               local newCount = getRandomSpectatorCount()
               CONFIG.SPECTATOR_COUNT = newCount
               
               -- Update the spectator box text if it exists
               if spectatorBox then
                   spectatorBox.Text = tostring(newCount)
               end
               
               -- Update the trade state
               mockState.trade.subscriber_count = newCount
               mockState.trade.offer_version = mockState.trade.offer_version + 1
               TradeApp:_overwrite_local_trade_state(mockState.trade)
           end
       end
       autoSpectateConnection = nil
   end)
end

local function stopAutoSpectate()
   CONFIG.AUTO_SPECTATE_ENABLED = false
end

-- ==================== GUI CREATION ====================

local controlGui = Instance.new('ScreenGui')
controlGui.Name = 'MockTradeControl'
controlGui.ResetOnSpawn = false
controlGui.DisplayOrder = 10
controlGui.Enabled = true
controlGui.Parent = Players.LocalPlayer:WaitForChild('PlayerGui')

local mainFrame = Instance.new('Frame')
mainFrame.Size = UDim2.new(0, 220, 0, 750)
mainFrame.Position = UDim2.new(0, 10, 0, 10)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1
mainFrame.Active = true
mainFrame.Parent = controlGui

local mainCorner = Instance.new('UICorner')
mainCorner.CornerRadius = UDim.new(0, 6)
mainCorner.Parent = mainFrame

local mainStroke = Instance.new('UIStroke')
mainStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
mainStroke.Color = Color3.fromRGB(100, 100, 255)
mainStroke.Thickness = 1.5
mainStroke.Parent = mainFrame

local titleLabel = Instance.new('TextLabel')
titleLabel.Size = UDim2.new(1, 0, 0, 22)
titleLabel.Position = UDim2.new(0, 0, 0, 2)
titleLabel.BackgroundTransparency = 1
titleLabel.Text = 'ZetaScripts (last4zeta on tt)'
titleLabel.Font = Enum.Font.FredokaOne
titleLabel.TextSize = 12
titleLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
titleLabel.Parent = mainFrame

local titleStroke = Instance.new('UIStroke')
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Color = Color3.new(0, 0, 0)
titleStroke.Thickness = 0.8
titleStroke.Parent = titleLabel

local tabContainer = Instance.new('Frame')
tabContainer.Size = UDim2.new(0.94, 0, 0, 26)
tabContainer.Position = UDim2.new(0.03, 0, 0, 26)
tabContainer.BackgroundTransparency = 1
tabContainer.Parent = mainFrame

function setActiveTab(tabName)
   if UIState.currentTab == tabName then return end
   if UIState.activeTabPulseTween then UIState.activeTabPulseTween:Cancel() UIState.activeTabPulseTween = nil end
   UIState.currentTab = tabName

   for name, data in pairs(tabButtons) do
       local isActive = name == tabName
       TweenService:Create(data.button, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
           BackgroundColor3 = isActive and Color3.fromRGB(50, 50, 60) or Color3.fromRGB(40, 40, 50)
       }):Play()
       local targetColor = isActive and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
       TweenService:Create(data.stroke, TweenInfo.new(0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), {
           Color = targetColor, Thickness = isActive and 1.2 or 0.8
       }):Play()
       if isActive then
           UIState.activeTabPulseTween = TweenService:Create(data.stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
               Color = targetColor:Lerp(Color3.fromRGB(255, 255, 255), 0.25), Thickness = 1.5
           })
           UIState.activeTabPulseTween:Play()
       end
   end

   for name, frame in pairs(tabFrames) do frame.Visible = name == tabName end
end

local tabs = { 'Control', 'Players', 'Pets', 'Users', 'Sets' }
local tabIcons = { '?', '?', '?', '?', '??' }

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
   tabButton.Parent = tabContainer

   local tabCorner = Instance.new('UICorner')
   tabCorner.CornerRadius = UDim.new(0, 4)
   tabCorner.Parent = tabButton

   local tabStroke = Instance.new('UIStroke')
   tabStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
   tabStroke.Color = i == 1 and Color3.fromRGB(100, 100, 255) or Color3.fromRGB(80, 80, 80)
   tabStroke.Thickness = i == 1 and 1.2 or 0.8
   tabStroke.Transparency = 0.3
   tabStroke.Parent = tabButton

   tabButtons[tabName] = { button = tabButton, stroke = tabStroke }

   -- Make Control tab a ScrollingFrame for better visibility
   local tabFrame
   if tabName == 'Control' then
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
       tabFrame.Parent = mainFrame
   else
       tabFrame = Instance.new('Frame')
       tabFrame.Size = UDim2.new(0.9, 0, 0, 670)
       tabFrame.Position = UDim2.new(0.05, 0, 0, 56)
       tabFrame.BackgroundTransparency = 1
       tabFrame.Visible = i == 1
       tabFrame.Parent = mainFrame
   end

   tabFrames[tabName] = tabFrame

   tabButton.MouseButton1Click:Connect(function() setActiveTab(tabName) end)
end

-- ==================== CONTROL TAB ====================
local controlFrame = tabFrames['Control']

local controlLayout = Instance.new('UIListLayout')
controlLayout.SortOrder = Enum.SortOrder.LayoutOrder
controlLayout.Padding = UDim.new(0, 4)
controlLayout.Parent = controlFrame

local controlPadding = Instance.new('UIPadding')
controlPadding.PaddingTop = UDim.new(0, 4)
controlPadding.PaddingBottom = UDim.new(0, 4)
controlPadding.PaddingLeft = UDim.new(0, 4)
controlPadding.PaddingRight = UDim.new(0, 4)
controlPadding.Parent = controlFrame

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
       UIState.pulsationTweens[box] = TweenService:Create(stroke, TweenInfo.new(0.8, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
           Color = Color3.fromRGB(100, 100, 255):Lerp(Color3.fromRGB(150, 150, 255), 0.5), Thickness = 1.2, Transparency = 0.2
       })
       UIState.pulsationTweens[box]:Play()
   end)

   box.FocusLost:Connect(function()
       if UIState.pulsationTweens[box] then UIState.pulsationTweens[box]:Cancel() UIState.pulsationTweens[box] = nil end
       TweenService:Create(stroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = Color3.fromRGB(100, 100, 100), Thickness = 0.8, Transparency = 0.5 }):Play()
   end)

   return box, stroke, heading
end

partnerBox, partnerStroke = createSettingRow('Partner Username', CONFIG.PARTNER_NAME, controlFrame)
local acceptBox = createSettingRow('Accept Delay (s)', CONFIG.AUTO_ACCEPT_DELAY, controlFrame)
local confirmBox = createSettingRow('Confirm Delay (s)', CONFIG.AUTO_CONFIRM_DELAY, controlFrame)
spectatorBox = createSettingRow('Spectator Count', CONFIG.SPECTATOR_COUNT, controlFrame)
local requestDelayBox = createSettingRow('Request Delay (s)', CONFIG.TRADE_REQUEST_DELAY, controlFrame)

partnerBox.FocusLost:Connect(function() updatePartnerFromUsername(partnerBox.Text) end)
acceptBox.FocusLost:Connect(function()
   local value = tonumber(acceptBox.Text)
   if value and value >= 0 then CONFIG.AUTO_ACCEPT_DELAY = value else acceptBox.Text = tostring(CONFIG.AUTO_ACCEPT_DELAY) end
end)
confirmBox.FocusLost:Connect(function()
   local value = tonumber(confirmBox.Text)
   if value and value >= 0 then CONFIG.AUTO_CONFIRM_DELAY = value else confirmBox.Text = tostring(CONFIG.AUTO_CONFIRM_DELAY) end
end)
spectatorBox.FocusLost:Connect(function()
   local value = tonumber(spectatorBox.Text)
   if value and value >= 0 then
       CONFIG.SPECTATOR_COUNT = value
       ORIGINAL_SPECTATOR_COUNT = value
       if mockState.trade then
           mockState.trade.subscriber_count = value
           if TradeApp.refresh_all then TradeApp:refresh_all() FriendHighlight(true) end
       end
   else
       spectatorBox.Text = tostring(CONFIG.SPECTATOR_COUNT)
   end
end)
requestDelayBox.FocusLost:Connect(function()
   local value = tonumber(requestDelayBox.Text)
   if value and value >= 0 then CONFIG.TRADE_REQUEST_DELAY = value else requestDelayBox.Text = tostring(CONFIG.TRADE_REQUEST_DELAY) end
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

createSpacer(controlFrame, 4)

-- AUTO SPECTATE BUTTON WITH RANDOM VARIATION - PROMINENT PLACEMENT
local autoSpectateButton = Instance.new('TextButton')
autoSpectateButton.Size = UDim2.new(1, 0, 0, 32)
autoSpectateButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
autoSpectateButton.BackgroundTransparency = 0.1
autoSpectateButton.Text = '? Auto Spectate: OFF'
autoSpectateButton.Font = Enum.Font.FredokaOne
autoSpectateButton.TextSize = 13
autoSpectateButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoSpectateButton.Parent = controlFrame
local autoSpectateCorner = Instance.new('UICorner')
autoSpectateCorner.CornerRadius = UDim.new(0, 4)
autoSpectateCorner.Parent = autoSpectateButton
local autoSpectateStroke = Instance.new('UIStroke')
autoSpectateStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
autoSpectateStroke.Color = Color3.fromRGB(255, 100, 100)
autoSpectateStroke.Thickness = 1.5
autoSpectateStroke.Parent = autoSpectateButton

autoSpectateButton.MouseButton1Click:Connect(function()
   CONFIG.AUTO_SPECTATE_ENABLED = not CONFIG.AUTO_SPECTATE_ENABLED
   
   if CONFIG.AUTO_SPECTATE_ENABLED then
       autoSpectateButton.Text = '? Auto Spectate: ON (Random)'
       autoSpectateButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
       autoSpectateStroke.Color = Color3.fromRGB(100, 255, 100)
       
       -- Store the current spectator count as the base
       ORIGINAL_SPECTATOR_COUNT = CONFIG.SPECTATOR_COUNT
       
       -- Start the auto spectate loop
       startAutoSpectate()
       
       if HintApp then
           HintApp:hint({ text = 'Auto Spectate ON! Range: ' .. (ORIGINAL_SPECTATOR_COUNT + CONFIG.SPECTATOR_VARIATION_MIN) .. '-' .. (ORIGINAL_SPECTATOR_COUNT + CONFIG.SPECTATOR_VARIATION_MAX), length = 3, overridable = true })
       end
   else
       autoSpectateButton.Text = '? Auto Spectate: OFF'
       autoSpectateButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
       autoSpectateStroke.Color = Color3.fromRGB(255, 100, 100)
       
       stopAutoSpectate()
       
       if HintApp then
           HintApp:hint({ text = 'Auto Spectate OFF', length = 2, overridable = true })
       end
   end
end)

createSpacer(controlFrame)

createButton('Add Random Item', Color3.fromRGB(100, 50, 150), Color3.fromRGB(200, 100, 255), controlFrame, function()
   if mockState.active and mockState.trade then
       addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
   end
end)

createSpacer(controlFrame)

createButton('Clear Trade', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), controlFrame, function()
   if mockState.active and mockState.trade then
       mockState.trade.sender_offer.items = {}
       mockState.trade.recipient_offer.items = {}
       mockState.trade.sender_offer.negotiated = false
       mockState.trade.recipient_offer.negotiated = false
       mockState.trade.current_stage = 'negotiation'
       mockState.trade.offer_version = mockState.trade.offer_version + 1
       TradeApp:_overwrite_local_trade_state(mockState.trade)
   end
end)

createSpacer(controlFrame)

-- FIXED: Start Trade button now uses the direct function
createButton('Start Trade', Color3.fromRGB(50, 80, 60), Color3.fromRGB(0, 255, 100), controlFrame, function()
   if mockState.active or mockState.pendingTradeRequest then return end
   
   if CONFIG.SHOW_TRADE_REQUEST then
       task.spawn(showTradeRequest)
   else
       task.spawn(startMockTradeDirectly)
   end
end)

createButton('Block Player', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), controlFrame, function()
   local player = Players:FindFirstChild(partnerBox.Text)
   if player then BlockPlayer(player) end
end)

createSpacer(controlFrame)

function makePartnerAccept()
   if mockState.active and mockState.trade then
       if mockState.trade.current_stage == 'negotiation' then
           if not mockState.trade.recipient_offer.negotiated then
               mockState.trade.recipient_offer.negotiated = true
               if mockState.trade.sender_offer.negotiated then
                   mockState.trade.current_stage = 'confirmation'
                   mockState.trade.offer_version = mockState.trade.offer_version + 1
                   TradeApp:_overwrite_local_trade_state(mockState.trade)
                   if TradeApp._evaluate_trade_fairness then TradeApp:_evaluate_trade_fairness() end
                   if TradeApp._lock_trade_for_appropriate_time then TradeApp:_lock_trade_for_appropriate_time() end
               else
                   mockState.trade.offer_version = mockState.trade.offer_version + 1
                   TradeApp:_overwrite_local_trade_state(mockState.trade)
               end
           end
       elseif mockState.trade.current_stage == 'confirmation' then
           if not mockState.trade.recipient_offer.confirmed then
               mockState.trade.recipient_offer.confirmed = true
               mockState.trade.offer_version = mockState.trade.offer_version + 1
               TradeApp:_overwrite_local_trade_state(mockState.trade)
               if mockState.trade.sender_offer.confirmed and not mockState.tradeCompleting then
                   mockState.tradeCompleting = true
                   if TradeApp._set_confirmation_arrow_rotating then TradeApp:_set_confirmation_arrow_rotating(true) end
                   task.wait(3)
                   local historyRecord = createTradeHistoryRecord(mockState.trade)
                   appendToTradeHistory(historyRecord)
                   mockState.active = false
                   mockState.trade = nil
                   mockState.tradeCompleting = false
                   mockState.scamWarningShown = true
                   mockState.canShowTradeRequest = true
                   mockState.tradeRequestBlocked = false
                   UIManager.set_app_visibility('TradeApp', false)
                   task.wait(0.1)
                   showBlockedTradeRequests()
                   if HintApp then HintApp:hint({ text = 'The trade was successful!', length = 5, overridable = true }) end
                   if TradeHistoryApp and UIManager.is_visible('TradeHistoryApp') then TradeHistoryApp:_refresh() end
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
               TradeApp:_overwrite_local_trade_state(mockState.trade)
           end
       elseif mockState.trade.current_stage == 'confirmation' then
           if mockState.trade.recipient_offer.confirmed then
               mockState.trade.recipient_offer.confirmed = false
               mockState.trade.offer_version = mockState.trade.offer_version + 1
               TradeApp:_overwrite_local_trade_state(mockState.trade)
           end
       end
   end
end

createButton('Make Partner Accept', Color3.fromRGB(50, 150, 50), Color3.fromRGB(100, 255, 100), controlFrame, makePartnerAccept)

createSpacer(controlFrame)

local noclipButton, noclipStroke = createButton('Toggle Noclip: ON', Color3.fromRGB(80, 80, 180), Color3.fromRGB(100, 100, 255), controlFrame, function()
   UIState.noclipEnabled = not UIState.noclipEnabled
   if UIState.noclipEnabled then
       noclipButton.Text = 'Toggle Noclip: ON'
       noclipButton.BackgroundColor3 = Color3.fromRGB(80, 80, 180)
       noclipStroke.Color = Color3.fromRGB(100, 100, 255)
       enableNoclipForAllFakePlayers()
       enableNoclipForPets()
   else
       noclipButton.Text = 'Toggle Noclip: OFF'
       noclipButton.BackgroundColor3 = Color3.fromRGB(180, 80, 80)
       noclipStroke.Color = Color3.fromRGB(255, 100, 100)
   end
end)

createSpacer(controlFrame)

createButton('Make Partner Unaccept', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), controlFrame, makePartnerUnaccept)

createSpacer(controlFrame)

local petTypeContainer = Instance.new('Frame')
petTypeContainer.Size = UDim2.new(1, 0, 0, 24)
petTypeContainer.BackgroundTransparency = 1
petTypeContainer.Parent = controlFrame

local petTypeLabel = Instance.new('TextLabel')
petTypeLabel.Size = UDim2.new(0.4, 0, 1, 0)
petTypeLabel.BackgroundTransparency = 1
petTypeLabel.Text = 'Fake Player Pet:'
petTypeLabel.Font = Enum.Font.SourceSansSemibold
petTypeLabel.TextSize = 10
petTypeLabel.TextColor3 = Color3.fromRGB(180, 180, 180)
petTypeLabel.TextXAlignment = Enum.TextXAlignment.Left
petTypeLabel.Parent = petTypeContainer

local petTypeButtons = {}
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
   btn.Parent = petTypeContainer
   local corner = Instance.new('UICorner')
   corner.CornerRadius = UDim.new(0, 4)
   corner.Parent = btn
   petTypeButtons[pt.name] = btn
   btn.MouseButton1Click:Connect(function()
       currentFakePetType = pt.name
       for name, b in pairs(petTypeButtons) do
           b.BackgroundColor3 = name == pt.name and Color3.fromRGB(50, 150, 50) or Color3.fromRGB(60, 60, 70)
       end
   end)
end

createButton('Spawn fake player', Color3.fromRGB(65, 50, 150), Color3.fromRGB(74, 207, 255), controlFrame, function()
   local petData, petFlags = nil, nil
   if CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET then
       local highValuePet = getRandomHighValuePet()
       petFlags = { M = currentFakePetType == 'mega', N = currentFakePetType == 'neon', F = true, R = true }
       petData = { kind = GetKindPet(highValuePet) }
   end
   CreateFakePlayerCharacterFromPARTNER_NAME(CONFIG.PARTNER_NAME, Players:GetUserIdFromNameAsync(CONFIG.PARTNER_NAME), petData, petFlags)
end)

createSpacer(controlFrame)

local spawnWithPetsButton = Instance.new('TextButton')
spawnWithPetsButton.Size = UDim2.new(1, 0, 0, 14)
spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
spawnWithPetsButton.BackgroundTransparency = 0.2
spawnWithPetsButton.Text = 'Spawn with random pet: false'
spawnWithPetsButton.Font = Enum.Font.FredokaOne
spawnWithPetsButton.TextSize = 7
spawnWithPetsButton.TextColor3 = Color3.fromRGB(255, 255, 255)
spawnWithPetsButton.Parent = controlFrame
local spawnWithPetsCorner = Instance.new('UICorner')
spawnWithPetsCorner.CornerRadius = UDim.new(0, 3)
spawnWithPetsCorner.Parent = spawnWithPetsButton
local spawnWithPetsStroke = Instance.new('UIStroke')
spawnWithPetsStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
spawnWithPetsStroke.Color = Color3.fromRGB(255, 100, 100)
spawnWithPetsStroke.Thickness = 0.8
spawnWithPetsStroke.Transparency = 0.3
spawnWithPetsStroke.Parent = spawnWithPetsButton

spawnWithPetsButton.MouseButton1Click:Connect(function()
   CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET = not CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET
   spawnWithPetsButton.Text = 'Spawn with random pet: ' .. (CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET and 'true' or 'false')
   if CONFIG.SPAWN_FAKE_PLAYER_WITH_RANDOM_PET then
       spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
       spawnWithPetsStroke.Color = Color3.fromRGB(100, 255, 100)
   else
       spawnWithPetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
       spawnWithPetsStroke.Color = Color3.fromRGB(255, 100, 100)
   end
end)

createSpacer(controlFrame)

local deleteFakePlayerButton = Instance.new('TextButton')
deleteFakePlayerButton.Size = UDim2.new(1, 0, 0, 14)
deleteFakePlayerButton.BackgroundColor3 = Color3.fromRGB(157, 58, 0)
deleteFakePlayerButton.BackgroundTransparency = 0.2
deleteFakePlayerButton.Text = 'Delete all fake players'
deleteFakePlayerButton.Font = Enum.Font.FredokaOne
deleteFakePlayerButton.TextSize = 7
deleteFakePlayerButton.TextColor3 = Color3.fromRGB(255, 255, 255)
deleteFakePlayerButton.Parent = controlFrame
local deleteFakePlayerCorner = Instance.new('UICorner')
deleteFakePlayerCorner.CornerRadius = UDim.new(0, 3)
deleteFakePlayerCorner.Parent = deleteFakePlayerButton

deleteFakePlayerButton.MouseButton1Click:Connect(function()
   pcall(function()
       AnimationManager:Stop()
       for _, petData in ipairs(FakePetRegistry) do
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
       for _, folder in pairs(FakePlayers) do if folder and folder.Parent then folder:Destroy() end end
       FakePlayers = {}
       FakePetRegistry = {}
       fakePlayerIds = {}
       _G.fakePlayerIds = {}
       print('? All fake players and pets deleted successfully')
   end)
end)

createSpacer(controlFrame)

local removePetsButton, removePetsStroke = createButton('Remove Partner Pets: OFF', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), controlFrame, function()
   mockState.removePartnerPetsOnConfirm = not mockState.removePartnerPetsOnConfirm
   CONFIG.REMOVE_PARTNER_PETS_ON_CONFIRM = mockState.removePartnerPetsOnConfirm
   if mockState.removePartnerPetsOnConfirm then
       removePetsButton.Text = 'Remove Partner Pets: ON'
       removePetsButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
       removePetsStroke.Color = Color3.fromRGB(100, 255, 100)
   else
       removePetsButton.Text = 'Remove Partner Pets: OFF'
       removePetsButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
       removePetsStroke.Color = Color3.fromRGB(255, 100, 100)
   end
end)

-- ==================== PLAYERS TAB ====================
local playersFrame = tabFrames['Players']

local playerSearchBox = Instance.new('TextBox')
playerSearchBox.Size = UDim2.new(1, 0, 0, 26)
playerSearchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
playerSearchBox.BackgroundTransparency = 0.2
playerSearchBox.Text = ''
playerSearchBox.PlaceholderText = 'Search players...'
playerSearchBox.Font = Enum.Font.SourceSans
playerSearchBox.TextSize = 12
playerSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
playerSearchBox.ClearTextOnFocus = false
playerSearchBox.TextXAlignment = Enum.TextXAlignment.Left
playerSearchBox.Parent = playersFrame
Instance.new('UICorner', playerSearchBox).CornerRadius = UDim.new(0, 4)

local selectionControls = Instance.new('Frame')
selectionControls.Size = UDim2.new(1, 0, 0, 26)
selectionControls.Position = UDim2.new(0, 0, 0, 30)
selectionControls.BackgroundTransparency = 1
selectionControls.Parent = playersFrame

local selectPlayersButton = Instance.new('TextButton')
selectPlayersButton.Size = UDim2.new(0.48, 0, 1, 0)
selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
selectPlayersButton.BackgroundTransparency = 0.2
selectPlayersButton.Text = 'Select Players'
selectPlayersButton.Font = Enum.Font.FredokaOne
selectPlayersButton.TextSize = 10
selectPlayersButton.TextColor3 = Color3.fromRGB(255, 255, 255)
selectPlayersButton.Parent = selectionControls
Instance.new('UICorner', selectPlayersButton).CornerRadius = UDim.new(0, 4)
local selectPlayersStroke = Instance.new('UIStroke')
selectPlayersStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
selectPlayersStroke.Thickness = 1.0
selectPlayersStroke.Parent = selectPlayersButton

local blockSelectedButton = Instance.new('TextButton')
blockSelectedButton.Size = UDim2.new(0.48, 0, 1, 0)
blockSelectedButton.Position = UDim2.new(0.52, 0, 0, 0)
blockSelectedButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
blockSelectedButton.BackgroundTransparency = 0.2
blockSelectedButton.Text = 'Block Selected'
blockSelectedButton.Font = Enum.Font.FredokaOne
blockSelectedButton.TextSize = 10
blockSelectedButton.TextColor3 = Color3.fromRGB(255, 255, 255)
blockSelectedButton.Parent = selectionControls
Instance.new('UICorner', blockSelectedButton).CornerRadius = UDim.new(0, 4)

local playerListFrame = Instance.new('ScrollingFrame')
playerListFrame.Size = UDim2.new(1, 0, 0, 250)
playerListFrame.Position = UDim2.new(0, 0, 0, 60)
playerListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
playerListFrame.BackgroundTransparency = 0.5
playerListFrame.BorderSizePixel = 0
playerListFrame.ScrollBarThickness = 4
playerListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
playerListFrame.ScrollBarImageTransparency = 0.5
playerListFrame.Parent = playersFrame
Instance.new('UICorner', playerListFrame).CornerRadius = UDim.new(0, 4)

local playerListLayout = Instance.new('UIListLayout')
playerListLayout.SortOrder = Enum.SortOrder.LayoutOrder
playerListLayout.Padding = UDim.new(0, 3)
playerListLayout.Parent = playerListFrame

local playerListPadding = Instance.new('UIPadding')
playerListPadding.PaddingTop = UDim.new(0, 4)
playerListPadding.PaddingBottom = UDim.new(0, 4)
playerListPadding.PaddingLeft = UDim.new(0, 4)
playerListPadding.PaddingRight = UDim.new(0, 4)
playerListPadding.Parent = playerListFrame

-- ==================== TOP 35 RICHEST SECTION WITH AUTOMATIC REFRESH ====================
local richestHeading = Instance.new('TextLabel')
richestHeading.Size = UDim2.new(1, 0, 0, 18)
richestHeading.Position = UDim2.new(0, 0, 0, 315)
richestHeading.BackgroundTransparency = 1
richestHeading.Text = '? Top 35 Richest Players (Auto-Refresh)'
richestHeading.Font = Enum.Font.FredokaOne
richestHeading.TextSize = 11
richestHeading.TextColor3 = Color3.fromRGB(255, 215, 0)
richestHeading.TextXAlignment = Enum.TextXAlignment.Left
richestHeading.Parent = playersFrame

local autoRefreshButton = Instance.new('TextButton')
autoRefreshButton.Size = UDim2.new(0.3, 0, 0, 18)
autoRefreshButton.Position = UDim2.new(0.7, 0, 0, 315)
autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
autoRefreshButton.BackgroundTransparency = 0.2
autoRefreshButton.Text = 'Auto: ON'
autoRefreshButton.Font = Enum.Font.FredokaOne
autoRefreshButton.TextSize = 8
autoRefreshButton.TextColor3 = Color3.fromRGB(255, 255, 255)
autoRefreshButton.Parent = playersFrame
Instance.new('UICorner', autoRefreshButton).CornerRadius = UDim.new(0, 4)

local refreshRichestButton = Instance.new('TextButton')
refreshRichestButton.Size = UDim2.new(0.3, 0, 0, 18)
refreshRichestButton.Position = UDim2.new(0.35, 0, 0, 315)
refreshRichestButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
refreshRichestButton.BackgroundTransparency = 0.2
refreshRichestButton.Text = '? Manual'
refreshRichestButton.Font = Enum.Font.FredokaOne
refreshRichestButton.TextSize = 8
refreshRichestButton.TextColor3 = Color3.fromRGB(255, 255, 255)
refreshRichestButton.Parent = playersFrame
Instance.new('UICorner', refreshRichestButton).CornerRadius = UDim.new(0, 4)

local richestListFrame = Instance.new('ScrollingFrame')
richestListFrame.Size = UDim2.new(1, 0, 0, 320)
richestListFrame.Position = UDim2.new(0, 0, 0, 337)
richestListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
richestListFrame.BackgroundTransparency = 0.5
richestListFrame.BorderSizePixel = 0
richestListFrame.ScrollBarThickness = 4
richestListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
richestListFrame.ScrollBarImageTransparency = 0.5
richestListFrame.Parent = playersFrame
Instance.new('UICorner', richestListFrame).CornerRadius = UDim.new(0, 4)

local richestListLayout = Instance.new('UIListLayout')
richestListLayout.SortOrder = Enum.SortOrder.LayoutOrder
richestListLayout.Padding = UDim.new(0, 3)
richestListLayout.Parent = richestListFrame

local richestListPadding = Instance.new('UIPadding')
richestListPadding.PaddingTop = UDim.new(0, 4)
richestListPadding.PaddingBottom = UDim.new(0, 4)
richestListPadding.PaddingLeft = UDim.new(0, 4)
richestListPadding.PaddingRight = UDim.new(0, 4)
richestListPadding.Parent = richestListFrame

local RefreshState = {
   autoRefreshEnabled = true,
   playerCache = {},
   isRefreshing = false,
   lastRefreshTime = 0,
   REFRESH_COOLDOWN = 2,
   playerContainers = {}
}

local function getExistingPlayerNames()
   local names = {}
   for _, child in ipairs(richestListFrame:GetChildren()) do
       if child:IsA('Frame') and child.Name:sub(1, 14) == 'RichestPlayer_' then
           names[child.Name:sub(15)] = true
       end
   end
   return names
end

local function removePlayerFromList(playerName)
   for _, child in ipairs(richestListFrame:GetChildren()) do
       if child:IsA('Frame') and child.Name == 'RichestPlayer_' .. playerName then
           child:Destroy()
       end
   end
   RefreshState.playerContainers[playerName] = nil
   RefreshState.playerCache[playerName] = nil
   expandedPlayers[playerName] = nil
end

local function updateCanvasSize()
   task.wait(0.05)
   local totalHeight = 8
   for _, child in ipairs(richestListFrame:GetChildren()) do
       if child:IsA('Frame') then
           totalHeight = totalHeight + child.AbsoluteSize.Y + 3
       end
   end
   richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
end

local function createRichestPlayerButton(playerData, index)
   local container = Instance.new('Frame')
   container.Size = UDim2.new(1, -8, 0, 32)
   container.BackgroundColor3 = Color3.fromRGB(35, 35, 50)
   container.BackgroundTransparency = 0.1
   container.LayoutOrder = index
   container.Name = 'RichestPlayer_' .. playerData.playerName
   container.ClipsDescendants = true
   container.Parent = richestListFrame
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
   tradeButton.Text = '?'
   tradeButton.Font = Enum.Font.GothamBold
   tradeButton.TextSize = 12
   tradeButton.TextColor3 = Color3.fromRGB(255, 255, 255)
   tradeButton.Parent = container
   Instance.new('UICorner', tradeButton).CornerRadius = UDim.new(0, 6)

   tradeButton.MouseEnter:Connect(function()
       TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 160, 120) }):Play()
   end)
   
   tradeButton.MouseLeave:Connect(function()
       TweenService:Create(tradeButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(50, 130, 100) }):Play()
   end)

   tradeButton.MouseButton1Click:Connect(function()
       local targetPlayer = Players:FindFirstChild(playerData.playerName)
       if targetPlayer then
           sendTradeToPlayer(targetPlayer)
       else
           for _, player in ipairs(Players:GetPlayers()) do
               if player.Name == playerData.playerName then
                   sendTradeToPlayer(player)
                   return
               end
           end
           if HintApp then
               HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true })
           end
       end
   end)

   local profileButton = Instance.new('TextButton')
   profileButton.Size = UDim2.new(0, 32, 0, 22)
   profileButton.Position = UDim2.new(1, -38, 0, 5)
   profileButton.BackgroundColor3 = Color3.fromRGB(100, 70, 150)
   profileButton.BackgroundTransparency = 0.1
   profileButton.Text = '?'
   profileButton.Font = Enum.Font.GothamBold
   profileButton.TextSize = 12
   profileButton.TextColor3 = Color3.fromRGB(255, 255, 255)
   profileButton.Parent = container
   Instance.new('UICorner', profileButton).CornerRadius = UDim.new(0, 6)

   profileButton.MouseEnter:Connect(function()
       TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(130, 90, 180) }):Play()
   end)
   
   profileButton.MouseLeave:Connect(function()
       TweenService:Create(profileButton, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 70, 150) }):Play()
   end)

   profileButton.MouseButton1Click:Connect(function()
       local targetPlayer = Players:FindFirstChild(playerData.playerName)
       if targetPlayer then
           pcall(function()
               OpenProfile(targetPlayer.UserId)
           end)
       else
           for _, player in ipairs(Players:GetPlayers()) do
               if player.Name == playerData.playerName then
                   pcall(function()
                       OpenProfile(player.UserId)
                   end)
                   return
               end
           end
           if HintApp then
               HintApp:hint({ text = playerData.playerName .. ' is not in this server', length = 3, overridable = true })
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

   -- Pets section inside container
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
           
           -- Auto-close after 10 seconds
           task.spawn(function()
               task.wait(10)
               if isExpanded and expandId == currentExpandId then
                   isExpanded = false
                   petsSection.Visible = false
                   petsSection.Size = UDim2.new(1, -8, 0, 0)
                   container.Size = UDim2.new(1, -8, 0, 32)
                   
                   -- Update canvas size
                   task.wait(0.05)
                   local totalHeight = 8
                   for _, child in ipairs(richestListFrame:GetChildren()) do
                       if child:IsA('Frame') then
                           totalHeight = totalHeight + child.AbsoluteSize.Y + 3
                       end
                   end
                   richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
               end
           end)
       end

       -- Update canvas size
       task.wait(0.05)
       local totalHeight = 8
       for _, child in ipairs(richestListFrame:GetChildren()) do
           if child:IsA('Frame') then
               totalHeight = totalHeight + child.AbsoluteSize.Y + 3
           end
       end
       richestListFrame.CanvasSize = UDim2.new(0, 0, 0, totalHeight)
   end)

   return container
end

local function refreshRichestPlayers(forceRefresh)
   if RefreshState.isRefreshing then return end
   
   local currentTime = tick()
   if not forceRefresh and (currentTime - RefreshState.lastRefreshTime) < RefreshState.REFRESH_COOLDOWN then
       return
   end
   
   RefreshState.isRefreshing = true
   RefreshState.lastRefreshTime = currentTime
   
   local localPlayer = Players.LocalPlayer
   local currentPlayers = {}
   for _, player in ipairs(Players:GetPlayers()) do
       if player ~= localPlayer then
           currentPlayers[player.Name] = player
       end
   end
   
   local existingNames = getExistingPlayerNames()
   
   -- Remove players who left
   for playerName in pairs(existingNames) do
       if not currentPlayers[playerName] then
           removePlayerFromList(playerName)
           for i, data in ipairs(richestData) do
               if data.playerName == playerName then
                   table.remove(richestData, i)
                   break
               end
           end
       end
   end
   
   -- If force refresh, clear everything
   if forceRefresh then
       for _, child in ipairs(richestListFrame:GetChildren()) do
           if child:IsA('Frame') then child:Destroy() end
       end
       expandedPlayers = {}
       richestData = {}
       RefreshState.playerContainers = {}
       existingNames = {}
       
       local loadingLabel = Instance.new('TextLabel')
       loadingLabel.Size = UDim2.new(1, -8, 0, 30)
       loadingLabel.BackgroundTransparency = 1
       loadingLabel.Text = '? Scanning players...'
       loadingLabel.Font = Enum.Font.FredokaOne
       loadingLabel.TextSize = 11
       loadingLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
       loadingLabel.LayoutOrder = 0
       loadingLabel.Name = 'LoadingLabel'
       loadingLabel.Parent = richestListFrame
   end
   
   task.spawn(function()
       local playersToFetch = {}
       for playerName, player in pairs(currentPlayers) do
           if forceRefresh or not existingNames[playerName] then
               table.insert(playersToFetch, player)
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
           table.insert(richestData, playerData)
       end
       
       local loadingLabel = richestListFrame:FindFirstChild('LoadingLabel')
       if loadingLabel then loadingLabel:Destroy() end
       
       table.sort(richestData, function(a, b) return a.totalValue > b.totalValue end)
       
       local displayCount = math.min(#richestData, 35)
       local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
       
       for i = 1, displayCount do
           local data = richestData[i]
           local existingContainer = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
           
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
           end
       end
       
       for i = displayCount + 1, #richestData do
           local data = richestData[i]
           local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
           if container then container:Destroy() end
       end
       
       updateCanvasSize()
       
       if forceRefresh and HintApp then 
           HintApp:hint({ text = 'Updated ' .. #richestData .. ' players!', length = 2, overridable = true }) 
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
       task.wait(5)
       autoRefreshCheck()
   end
end)

refreshRichestButton.MouseButton1Click:Connect(function()
   refreshRichestPlayers(true)
end)

autoRefreshButton.MouseButton1Click:Connect(function()
   RefreshState.autoRefreshEnabled = not RefreshState.autoRefreshEnabled
   if RefreshState.autoRefreshEnabled then
       autoRefreshButton.Text = 'Auto: ON'
       autoRefreshButton.BackgroundColor3 = Color3.fromRGB(50, 150, 50)
       refreshRichestPlayers(true)
   else
       autoRefreshButton.Text = 'Auto: OFF'
       autoRefreshButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
   end
end)

Players.PlayerAdded:Connect(function(player)
   if RefreshState.autoRefreshEnabled then
       task.wait(1)
       if player ~= Players.LocalPlayer then
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
               table.insert(richestData, playerData)
               
               table.sort(richestData, function(a, b) return a.totalValue > b.totalValue end)
               
               local newIndex = 1
               for i, data in ipairs(richestData) do
                   if data.playerName == player.Name then newIndex = i break end
               end
               
               if newIndex <= 35 then
                   createRichestPlayerButton(playerData, newIndex)
                   RefreshState.playerContainers[player.Name] = true
                   
                   local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
                   for i, data in ipairs(richestData) do
                       if i <= 35 then
                           local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
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

Players.PlayerRemoving:Connect(function(player)
   if RefreshState.autoRefreshEnabled then
       removePlayerFromList(player.Name)
       
       for i, data in ipairs(richestData) do
           if data.playerName == player.Name then
               table.remove(richestData, i)
               break
           end
       end
       
       local rankColors = { [1] = Color3.fromRGB(255, 215, 0), [2] = Color3.fromRGB(192, 192, 192), [3] = Color3.fromRGB(205, 127, 50) }
       for i, data in ipairs(richestData) do
           if i <= 35 then
               local container = richestListFrame:FindFirstChild('RichestPlayer_' .. data.playerName)
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
   button.Parent = playerListFrame
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
   checkMark.Text = '?'
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
   button.Parent = playerListFrame
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
           local tradePart = Players.LocalPlayer.PlayerGui.TradeApp.Frame.NegotiationFrame.Header.PartnerFrame.NameLabel.Text
           for _, player in ipairs(Players:GetPlayers()) do
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
   for _, child in ipairs(playerListFrame:GetChildren()) do
       if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then child:Destroy() end
   end
   UIState.playerListButtons = {}

   local searchText = playerSearchBox.Text:lower()
   local filteredPlayers = {}
   for _, player in ipairs(Players:GetPlayers()) do
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
   playerListFrame.CanvasSize = UDim2.new(0, 0, 0, (#filteredPlayers * 36) + 40)
end

playerSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshPlayerList)

selectPlayersButton.MouseButton1Click:Connect(function()
   UIState.selectionMode = not UIState.selectionMode
   if UIState.selectionMode then
       selectPlayersButton.Text = 'Cancel Selection'
       selectPlayersButton.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
       selectPlayersStroke.Color = Color3.fromRGB(255, 100, 100)
   else
       selectPlayersButton.Text = 'Select Players'
       selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
       selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
       UIState.selectedPlayers = {}
   end
   for _, child in ipairs(playerListFrame:GetChildren()) do
       if child:IsA('TextButton') and child.Name ~= 'SelectFromTradeButton' then
           local checkBox = child:FindFirstChildOfClass('Frame')
           if checkBox then checkBox.Visible = UIState.selectionMode end
       end
   end
end)

blockSelectedButton.MouseButton1Click:Connect(function()
   if not UIState.selectionMode then return end
   local count = 0
   for playerName, isSelected in pairs(UIState.selectedPlayers) do
       if isSelected then
           local player = Players:FindFirstChild(playerName)
           if player then
               pcall(function() BlockPlayer(player) count = count + 1 end)
               task.wait(0.15)
           end
       end
   end
   UIState.selectionMode = false
   selectPlayersButton.Text = 'Select Players'
   selectPlayersButton.BackgroundColor3 = Color3.fromRGB(65, 65, 81)
   selectPlayersStroke.Color = Color3.fromRGB(159, 159, 159)
   UIState.selectedPlayers = {}
   refreshPlayerList()
   if HintApp then HintApp:hint({ text = 'Blocked ' .. count .. ' player(s)', length = 3, overridable = true }) end
end)

refreshPlayerList()
createSelectFromTradeButton()

Players.PlayerAdded:Connect(refreshPlayerList)
Players.PlayerRemoving:Connect(refreshPlayerList)

-- ==================== PETS TAB ====================
local petsFrame = tabFrames['Pets']

local petInputSection = Instance.new('Frame')
petInputSection.Size = UDim2.new(1, 0, 0, 190)
petInputSection.Position = UDim2.new(0, 0, 0, 0)
petInputSection.BackgroundTransparency = 1
petInputSection.Parent = petsFrame

local petNameHeading = Instance.new('TextLabel')
petNameHeading.Size = UDim2.new(1, 0, 0, 16)
petNameHeading.BackgroundTransparency = 1
petNameHeading.Text = 'Pet Name To Add'
petNameHeading.Font = Enum.Font.SourceSansSemibold
petNameHeading.TextSize = 11
petNameHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
petNameHeading.TextXAlignment = Enum.TextXAlignment.Left
petNameHeading.Parent = petInputSection

local petNameBox = Instance.new('TextBox')
petNameBox.Size = UDim2.new(1, 0, 0, 26)
petNameBox.Position = UDim2.new(0, 0, 0, 18)
petNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
petNameBox.BackgroundTransparency = 0.2
petNameBox.Text = ''
petNameBox.PlaceholderText = 'Enter pet name...'
petNameBox.Font = Enum.Font.FredokaOne
petNameBox.TextSize = 11
petNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
petNameBox.ClearTextOnFocus = false
petNameBox.Parent = petInputSection
Instance.new('UICorner', petNameBox).CornerRadius = UDim.new(0, 4)
local petNameStroke = Instance.new('UIStroke')
petNameStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
petNameStroke.Color = Color3.fromRGB(100, 100, 100)
petNameStroke.Thickness = 0.8
petNameStroke.Transparency = 0.5
petNameStroke.Parent = petNameBox

local propContainer = Instance.new('Frame')
propContainer.Size = UDim2.new(1, 0, 0, 26)
propContainer.Position = UDim2.new(0, 0, 0, 49)
propContainer.BackgroundTransparency = 1
propContainer.Parent = petInputSection

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
   prefixButton.Parent = propContainer
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
           TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = Color3.fromRGB(0, 255, 0), Thickness = 1.2, Transparency = 0.2 }):Play()
       else
           prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
           TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), { Color = prefixColors[prefix], Thickness = 1.0, Transparency = 0.5 }):Play()
       end
   end)
end

local addPetDelayText = Instance.new('TextLabel')
addPetDelayText.Size = UDim2.new(1, 0, 0, 14)
addPetDelayText.Position = UDim2.new(0, 0, 0, 68)
addPetDelayText.BackgroundTransparency = 1
addPetDelayText.Text = 'Add Pet Delay (s)'
addPetDelayText.Font = Enum.Font.SourceSansSemibold
addPetDelayText.TextSize = 10
addPetDelayText.TextColor3 = Color3.fromRGB(180, 180, 180)
addPetDelayText.TextXAlignment = Enum.TextXAlignment.Left
addPetDelayText.Parent = petInputSection

local requestAddPetBox = Instance.new('TextBox')
requestAddPetBox.Size = UDim2.new(1, 0, 0, 24)
requestAddPetBox.Position = UDim2.new(0, 0, 0, 82)
requestAddPetBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
requestAddPetBox.BackgroundTransparency = 0.2
requestAddPetBox.Text = tostring(CONFIG.ADD_PET_REQUEST_DELAY)
requestAddPetBox.Font = Enum.Font.SourceSans
requestAddPetBox.TextSize = 12
requestAddPetBox.TextColor3 = Color3.fromRGB(255, 255, 255)
requestAddPetBox.ClearTextOnFocus = false
requestAddPetBox.TextXAlignment = Enum.TextXAlignment.Center
requestAddPetBox.Parent = petInputSection
Instance.new('UICorner', requestAddPetBox).CornerRadius = UDim.new(0, 4)

requestAddPetBox.FocusLost:Connect(function()
   local value = tonumber(requestAddPetBox.Text)
   if value and value >= 0 then CONFIG.ADD_PET_REQUEST_DELAY = value else requestAddPetBox.Text = tostring(CONFIG.ADD_PET_REQUEST_DELAY) end
end)

local addPetButton = Instance.new('TextButton')
addPetButton.Size = UDim2.new(1, 0, 0, 26)
addPetButton.Position = UDim2.new(0, 0, 0, 114)
addPetButton.BackgroundColor3 = Color3.fromRGB(0, 100, 200)
addPetButton.BackgroundTransparency = 0.2
addPetButton.Text = 'Add Pet to Trade'
addPetButton.Font = Enum.Font.FredokaOne
addPetButton.TextSize = 12
addPetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
addPetButton.Parent = petInputSection
Instance.new('UICorner', addPetButton).CornerRadius = UDim.new(0, 4)

addPetButton.MouseButton1Click:Connect(function()
   local petName = petNameBox.Text
   if petName and petName ~= '' then addPetToPartnerOffer(petName, petSpawnState.activeFlags) end
end)

local removePetButton2 = Instance.new('TextButton')
removePetButton2.Size = UDim2.new(1, 0, 0, 26)
removePetButton2.Position = UDim2.new(0, 0, 0, 145)
removePetButton2.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
removePetButton2.BackgroundTransparency = 0.2
removePetButton2.Text = 'Remove Latest Pet'
removePetButton2.Font = Enum.Font.FredokaOne
removePetButton2.TextSize = 12
removePetButton2.TextColor3 = Color3.fromRGB(255, 255, 255)
removePetButton2.Parent = petInputSection
Instance.new('UICorner', removePetButton2).CornerRadius = UDim.new(0, 4)

removePetButton2.MouseButton1Click:Connect(removeLatestPetFromPartnerOffer)

local addRandomPetButton = Instance.new('TextButton')
addRandomPetButton.Size = UDim2.new(1, 0, 0, 26)
addRandomPetButton.Position = UDim2.new(0, 0, 0, 176)
addRandomPetButton.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
addRandomPetButton.BackgroundTransparency = 0.2
addRandomPetButton.Text = 'Add Random High-Value Pet'
addRandomPetButton.Font = Enum.Font.FredokaOne
addRandomPetButton.TextSize = 10
addRandomPetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
addRandomPetButton.Parent = petInputSection
Instance.new('UICorner', addRandomPetButton).CornerRadius = UDim.new(0, 4)

addRandomPetButton.MouseButton1Click:Connect(function()
   addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
end)

local petListSection = Instance.new('Frame')
petListSection.Size = UDim2.new(1, 0, 0, 400)
petListSection.Position = UDim2.new(0, 0, 0, 195)
petListSection.BackgroundTransparency = 1
petListSection.Parent = petsFrame

local petListHeading = Instance.new('TextLabel')
petListHeading.Size = UDim2.new(1, 0, 0, 16)
petListHeading.BackgroundTransparency = 1
petListHeading.Text = 'High-Value Pets (Balloon Unicorn+)'
petListHeading.Font = Enum.Font.SourceSansSemibold
petListHeading.TextSize = 11
petListHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
petListHeading.TextXAlignment = Enum.TextXAlignment.Left
petListHeading.Parent = petListSection

local petListFrame = Instance.new('ScrollingFrame')
petListFrame.Size = UDim2.new(1, 0, 0, 380)
petListFrame.Position = UDim2.new(0, 0, 0, 18)
petListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
petListFrame.BackgroundTransparency = 0.5
petListFrame.BorderSizePixel = 0
petListFrame.ScrollBarThickness = 4
petListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
petListFrame.ScrollBarImageTransparency = 0.5
petListFrame.Parent = petListSection
Instance.new('UICorner', petListFrame).CornerRadius = UDim.new(0, 4)

local petListLayout = Instance.new('UIListLayout')
petListLayout.SortOrder = Enum.SortOrder.LayoutOrder
petListLayout.Padding = UDim.new(0, 3)
petListLayout.Parent = petListFrame

local petListPadding2 = Instance.new('UIPadding')
petListPadding2.PaddingTop = UDim.new(0, 4)
petListPadding2.PaddingBottom = UDim.new(0, 4)
petListPadding2.PaddingLeft = UDim.new(0, 4)
petListPadding2.PaddingRight = UDim.new(0, 4)
petListPadding2.Parent = petListFrame

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
   button.Parent = petListFrame
   Instance.new('UICorner', button).CornerRadius = UDim.new(0, 6)
   
   local buttonStroke = Instance.new('UIStroke')
   buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
   buttonStroke.Color = Color3.fromRGB(255, 200, 50)
   buttonStroke.Thickness = 1.5
   buttonStroke.Transparency = 0.2
   buttonStroke.Parent = button

   button.MouseEnter:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
   end)
   
   button.MouseLeave:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
   end)

   button.MouseButton1Click:Connect(function()
       petNameBox.Text = petName
       TweenService:Create(petNameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Color = Color3.fromRGB(255, 200, 50), Thickness = 1.5 }):Play()
       task.wait(0.5)
       TweenService:Create(petNameStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quint, Enum.EasingDirection.Out), { Color = Color3.fromRGB(100, 100, 100), Thickness = 0.8 }):Play()
   end)
end

petListFrame.CanvasSize = UDim2.new(0,0, 0, (#completePetList * 31) + 8)

-- ==================== USERS TAB ====================
local usersFrame = tabFrames['Users']

local userSearchBox = Instance.new('TextBox')
userSearchBox.Size = UDim2.new(1, 0, 0, 26)
userSearchBox.Position = UDim2.new(0, 0, 0, 0)
userSearchBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
userSearchBox.BackgroundTransparency = 0.2
userSearchBox.Text = ''
userSearchBox.PlaceholderText = 'Search users...'
userSearchBox.Font = Enum.Font.SourceSans
userSearchBox.TextSize = 12
userSearchBox.TextColor3 = Color3.fromRGB(255, 255, 255)
userSearchBox.ClearTextOnFocus = false
userSearchBox.TextXAlignment = Enum.TextXAlignment.Left
userSearchBox.Parent = usersFrame
Instance.new('UICorner', userSearchBox).CornerRadius = UDim.new(0, 4)

local userListFrame = Instance.new('ScrollingFrame')
userListFrame.Size = UDim2.new(1, 0, 0, 180)
userListFrame.Position = UDim2.new(0, 0, 0, 30)
userListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
userListFrame.BackgroundTransparency = 0.5
userListFrame.BorderSizePixel = 0
userListFrame.ScrollBarThickness = 4
userListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
userListFrame.ScrollBarImageTransparency = 0.5
userListFrame.Parent = usersFrame
Instance.new('UICorner', userListFrame).CornerRadius = UDim.new(0, 4)

local userListLayout = Instance.new('UIListLayout')
userListLayout.SortOrder = Enum.SortOrder.LayoutOrder
userListLayout.Padding = UDim.new(0, 3)
userListLayout.Parent = userListFrame

local userListPadding = Instance.new('UIPadding')
userListPadding.PaddingTop = UDim.new(0, 4)
userListPadding.PaddingBottom = UDim.new(0, 4)
userListPadding.PaddingLeft = UDim.new(0, 4)
userListPadding.PaddingRight = UDim.new(0, 4)
userListPadding.Parent = userListFrame

local chatHeading = Instance.new('TextLabel')
chatHeading.Size = UDim2.new(1, 0, 0, 16)
chatHeading.Position = UDim2.new(0, 0, 0, 215)
chatHeading.BackgroundTransparency = 1
chatHeading.Text = 'Chat Messages'
chatHeading.Font = Enum.Font.SourceSansSemibold
chatHeading.TextSize = 11
chatHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
chatHeading.TextXAlignment = Enum.TextXAlignment.Left
chatHeading.Parent = usersFrame

local customMessageBox = Instance.new('TextBox')
customMessageBox.Size = UDim2.new(1, 0, 0, 26)
customMessageBox.Position = UDim2.new(0, 0, 0, 233)
customMessageBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
customMessageBox.BackgroundTransparency = 0.2
customMessageBox.Text = ''
customMessageBox.PlaceholderText = 'Enter custom message...'
customMessageBox.Font = Enum.Font.SourceSans
customMessageBox.TextSize = 12
customMessageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
customMessageBox.ClearTextOnFocus = false
customMessageBox.TextXAlignment = Enum.TextXAlignment.Left
customMessageBox.Parent = usersFrame
Instance.new('UICorner', customMessageBox).CornerRadius = UDim.new(0, 4)

local sendMessageButton = Instance.new('TextButton')
sendMessageButton.Size = UDim2.new(1, 0, 0, 26)
sendMessageButton.Position = UDim2.new(0, 0, 0, 263)
sendMessageButton.BackgroundColor3 = Color3.fromRGB(50, 120, 50)
sendMessageButton.BackgroundTransparency = 0.2
sendMessageButton.Text = 'Send Chat Message'
sendMessageButton.Font = Enum.Font.FredokaOne
sendMessageButton.TextSize = 12
sendMessageButton.TextColor3 = Color3.fromRGB(255, 255, 255)
sendMessageButton.Parent = usersFrame
Instance.new('UICorner', sendMessageButton).CornerRadius = UDim.new(0, 4)

sendMessageButton.MouseButton1Click:Connect(function()
   local message = customMessageBox.Text
   if message and message ~= '' then
       sendTradeChatMessage(message)
       customMessageBox.Text = ''
   end
end)

local chatListHeading = Instance.new('TextLabel')
chatListHeading.Size = UDim2.new(1, 0, 0, 16)
chatListHeading.Position = UDim2.new(0, 0, 0, 295)
chatListHeading.BackgroundTransparency = 1
chatListHeading.Text = 'Quick Messages'
chatListHeading.Font = Enum.Font.SourceSansSemibold
chatListHeading.TextSize = 11
chatListHeading.TextColor3 = Color3.fromRGB(180, 180, 180)
chatListHeading.TextXAlignment = Enum.TextXAlignment.Left
chatListHeading.Parent = usersFrame

local chatListFrame = Instance.new('ScrollingFrame')
chatListFrame.Size = UDim2.new(1, 0, 0, 300)
chatListFrame.Position = UDim2.new(0, 0, 0, 313)
chatListFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
chatListFrame.BackgroundTransparency = 0.5
chatListFrame.BorderSizePixel = 0
chatListFrame.ScrollBarThickness = 4
chatListFrame.ScrollBarImageColor3 = Color3.fromRGB(100, 100, 100)
chatListFrame.ScrollBarImageTransparency = 0.5
chatListFrame.Parent = usersFrame
Instance.new('UICorner', chatListFrame).CornerRadius = UDim.new(0, 4)

local chatListLayout = Instance.new('UIListLayout')
chatListLayout.SortOrder = Enum.SortOrder.LayoutOrder
chatListLayout.Padding = UDim.new(0, 3)
chatListLayout.Parent = chatListFrame

local chatListPadding = Instance.new('UIPadding')
chatListPadding.PaddingTop = UDim.new(0, 4)
chatListPadding.PaddingBottom = UDim.new(0, 4)
chatListPadding.PaddingLeft = UDim.new(0, 4)
chatListPadding.PaddingRight = UDim.new(0, 4)
chatListPadding.Parent = chatListFrame

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
   button.Parent = chatListFrame
   Instance.new('UICorner', button).CornerRadius = UDim.new(0, 5)
   
   local buttonStroke = Instance.new('UIStroke')
   buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
   buttonStroke.Color = Color3.fromRGB(255, 200, 50)
   buttonStroke.Thickness = 1.5
   buttonStroke.Transparency = 0.2
   buttonStroke.Parent = button

   button.MouseEnter:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
   end)
   
   button.MouseLeave:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.15), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
   end)

   button.MouseButton1Click:Connect(function()
       sendTradeChatMessage(message)
   end)
end

chatListFrame.CanvasSize = UDim2.new(0, 0, 0, (#CONFIG.CHAT_MESSAGES * 27) + 8)

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
   button.Parent = userListFrame
   Instance.new('UICorner', button).CornerRadius = UDim.new(0, 6)
   
   local buttonStroke = Instance.new('UIStroke')
   buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
   buttonStroke.Color = Color3.fromRGB(255, 200, 50)
   buttonStroke.Thickness = 1.5
   buttonStroke.Transparency = 0.2
   buttonStroke.Parent = button

   button.MouseEnter:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 220, 80), Transparency = 0 }):Play()
   end)
   
   button.MouseLeave:Connect(function()
       TweenService:Create(button, TweenInfo.new(0.2), { BackgroundColor3 = Color3.fromRGB(55, 50, 75) }):Play()
       TweenService:Create(buttonStroke, TweenInfo.new(0.2), { Color = Color3.fromRGB(255, 200, 50), Transparency = 0.2 }):Play()
   end)

   button.MouseButton1Click:Connect(function()
       setActiveTab('Control')
       partnerBox.Text = username
       updatePartnerFromUsername(username)
   end)

   return button
end

local function refreshUserList()
   for _, child in ipairs(userListFrame:GetChildren()) do
       if child:IsA('TextButton') then child:Destroy() end
   end
   UIState.userListButtons = {}

   local searchText = userSearchBox.Text:lower()
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
   userListFrame.CanvasSize = UDim2.new(0, 0, 0, (#filteredUsers * 29) + 8)
end

userSearchBox:GetPropertyChangedSignal("Text"):Connect(refreshUserList)
refreshUserList()

-- ==================== RGB STATE (defined early for Sets tab access) ====================
local RGBState = { hue = 0, speed = 0.5, enabled = true }

-- ==================== SETS TAB (KEYBINDS) ====================
local setsFrame = tabFrames['Sets']
local SetsUI = { keybindButtons = {}, currentScale = 1.0 }

do
   local layout = Instance.new('UIListLayout')
   layout.SortOrder = Enum.SortOrder.LayoutOrder
   layout.Padding = UDim.new(0, 6)
   layout.Parent = setsFrame
   
   local padding = Instance.new('UIPadding')
   padding.PaddingTop = UDim.new(0, 8)
   padding.PaddingLeft = UDim.new(0, 4)
   padding.PaddingRight = UDim.new(0, 4)
   padding.Parent = setsFrame
   
   local heading = Instance.new('TextLabel')
   heading.Size = UDim2.new(1, 0, 0, 20)
   heading.BackgroundTransparency = 1
   heading.Text = '?? Keybind Settings'
   heading.Font = Enum.Font.GothamBold
   heading.TextSize = 14
   heading.TextColor3 = Color3.fromRGB(255, 200, 50)
   heading.TextXAlignment = Enum.TextXAlignment.Center
   heading.LayoutOrder = 0
   heading.Parent = setsFrame
end

local function createKeybindRow(labelText, keybindKey, layoutOrder)
   local row = Instance.new('Frame')
   row.Size = UDim2.new(1, 0, 0, 36)
   row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
   row.BackgroundTransparency = 0.1
   row.LayoutOrder = layoutOrder
   row.Parent = setsFrame
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
           TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(90, 85, 120) }):Play()
       end
   end)
   btn.MouseLeave:Connect(function()
       if UIState.waitingForKeybind ~= keybindKey then
           TweenService:Create(btn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(70, 65, 95) }):Play()
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

-- RGB Speed Section (using do-end to limit scope)
do
   local spacer = Instance.new('Frame')
   spacer.Size = UDim2.new(1, 0, 0, 10)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = 10
   spacer.Parent = setsFrame
   
   local heading = Instance.new('TextLabel')
   heading.Size = UDim2.new(1, 0, 0, 18)
   heading.BackgroundTransparency = 1
   heading.Text = '? RGB Settings'
   heading.Font = Enum.Font.GothamBold
   heading.TextSize = 12
   heading.TextColor3 = Color3.fromRGB(255, 200, 50)
   heading.TextXAlignment = Enum.TextXAlignment.Center
   heading.LayoutOrder = 11
   heading.Parent = setsFrame
   
   local row = Instance.new('Frame')
   row.Size = UDim2.new(1, 0, 0, 36)
   row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
   row.BackgroundTransparency = 0.1
   row.LayoutOrder = 12
   row.Parent = setsFrame
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

-- Server Uptime Section (using do-end to limit scope)
do
   local spacer = Instance.new('Frame')
   spacer.Size = UDim2.new(1, 0, 0, 10)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = 13
   spacer.Parent = setsFrame
   
   local heading = Instance.new('TextLabel')
   heading.Size = UDim2.new(1, 0, 0, 18)
   heading.BackgroundTransparency = 1
   heading.Text = '? Server Info'
   heading.Font = Enum.Font.GothamBold
   heading.TextSize = 12
   heading.TextColor3 = Color3.fromRGB(255, 200, 50)
   heading.TextXAlignment = Enum.TextXAlignment.Center
   heading.LayoutOrder = 14
   heading.Parent = setsFrame
   
   local row = Instance.new('Frame')
   row.Size = UDim2.new(1, 0, 0, 36)
   row.BackgroundColor3 = Color3.fromRGB(55, 50, 75)
   row.BackgroundTransparency = 0.1
   row.LayoutOrder = 15
   row.Parent = setsFrame
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

-- Mobile GUI Size Section (using do-end to limit scope)
do
   local spacer = Instance.new('Frame')
   spacer.Size = UDim2.new(1, 0, 0, 10)
   spacer.BackgroundTransparency = 1
   spacer.LayoutOrder = 16
   spacer.Parent = setsFrame
   
   local heading = Instance.new('TextLabel')
   heading.Size = UDim2.new(1, 0, 0, 18)
   heading.BackgroundTransparency = 1
   heading.Text = '? GUI Size (Mobile)'
   heading.Font = Enum.Font.GothamBold
   heading.TextSize = 12
   heading.TextColor3 = Color3.fromRGB(255, 200, 50)
   heading.TextXAlignment = Enum.TextXAlignment.Center
   heading.LayoutOrder = 17
   heading.Parent = setsFrame
   
   local row = Instance.new('Frame')
   row.Size = UDim2.new(1, 0, 0, 40)
   row.BackgroundTransparency = 1
   row.LayoutOrder = 18
   row.Parent = setsFrame
   
   local smallBtn = Instance.new('TextButton')
   smallBtn.Size = UDim2.new(0.48, 0, 1, 0)
   smallBtn.Position = UDim2.new(0, 0, 0, 0)
   smallBtn.BackgroundColor3 = Color3.fromRGB(80, 60, 120)
   smallBtn.Text = '? Small'
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
   bigBtn.Text = '? Big'
   bigBtn.Font = Enum.Font.GothamBold
   bigBtn.TextSize = 12
   bigBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
   bigBtn.Parent = row
   Instance.new('UICorner', bigBtn).CornerRadius = UDim.new(0, 6)
   local bs = Instance.new('UIStroke', bigBtn)
   bs.Color = Color3.fromRGB(255, 200, 50)
   bs.Thickness = 1.5
   bs.Transparency = 0.2
   
   -- Create UIScale for proper scaling
   local uiScale = mainFrame:FindFirstChild('UIScale') or Instance.new('UIScale')
   uiScale.Name = 'UIScale'
   uiScale.Parent = mainFrame
   
   smallBtn.MouseButton1Click:Connect(function()
       SetsUI.currentScale = math.max(0.7, SetsUI.currentScale - 0.05)
       uiScale.Scale = SetsUI.currentScale
       if HintApp then HintApp:hint({ text = 'GUI Scale: ' .. string.format('%.0f%%', SetsUI.currentScale * 100), length = 1, overridable = true }) end
   end)
   
   bigBtn.MouseButton1Click:Connect(function()
       SetsUI.currentScale = math.min(1.3, SetsUI.currentScale + 0.05)
       uiScale.Scale = SetsUI.currentScale
       if HintApp then HintApp:hint({ text = 'GUI Scale: ' .. string.format('%.0f%%', SetsUI.currentScale * 100), length = 1, overridable = true }) end
   end)
   
   smallBtn.MouseEnter:Connect(function() TweenService:Create(smallBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(100, 80, 150) }):Play() end)
   smallBtn.MouseLeave:Connect(function() TweenService:Create(smallBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(80, 60, 120) }):Play() end)
   bigBtn.MouseEnter:Connect(function() TweenService:Create(bigBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(80, 150, 100) }):Play() end)
   bigBtn.MouseLeave:Connect(function() TweenService:Create(bigBtn, TweenInfo.new(0.15), { BackgroundColor3 = Color3.fromRGB(60, 120, 80) }):Play() end)
end

-- Pet Value Calculator Section
do
   local PVC = { state = { M = false, N = false, F = false, R = false }, btns = {} }
   local colors = { M = {Color3.fromRGB(170,0,255), Color3.fromRGB(80,60,100)}, N = {Color3.fromRGB(255,215,0), Color3.fromRGB(80,60,100)}, F = {Color3.fromRGB(0,200,255), Color3.fromRGB(80,60,100)}, R = {Color3.fromRGB(0,255,100), Color3.fromRGB(80,60,100)} }
   
   Instance.new('Frame', setsFrame).Size = UDim2.new(1,0,0,10); setsFrame:GetChildren()[#setsFrame:GetChildren()].BackgroundTransparency = 1; setsFrame:GetChildren()[#setsFrame:GetChildren()].LayoutOrder = 19
   
   local h = Instance.new('TextLabel', setsFrame)
   h.Size, h.BackgroundTransparency, h.Text, h.Font, h.TextSize, h.TextColor3, h.TextXAlignment, h.LayoutOrder = UDim2.new(1,0,0,18), 1, '? Pet Value Calculator', Enum.Font.GothamBold, 12, Color3.fromRGB(255,200,50), Enum.TextXAlignment.Center, 20
   
   local ir = Instance.new('Frame', setsFrame)
   ir.Size, ir.BackgroundColor3, ir.BackgroundTransparency, ir.LayoutOrder = UDim2.new(1,0,0,30), Color3.fromRGB(55,50,75), 0.1, 21
   Instance.new('UICorner', ir).CornerRadius = UDim.new(0,6)
   local irs = Instance.new('UIStroke', ir); irs.Color, irs.Thickness, irs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
   
   PVC.input = Instance.new('TextBox', ir)
   PVC.input.Size, PVC.input.Position, PVC.input.BackgroundTransparency, PVC.input.Text, PVC.input.PlaceholderText = UDim2.new(1,-16,1,-6), UDim2.new(0,8,0,3), 1, '', 'Enter pet name...'
   PVC.input.Font, PVC.input.TextSize, PVC.input.TextColor3, PVC.input.PlaceholderColor3, PVC.input.TextXAlignment, PVC.input.ClearTextOnFocus = Enum.Font.GothamMedium, 11, Color3.fromRGB(255,255,255), Color3.fromRGB(150,150,160), Enum.TextXAlignment.Left, false
   
   local pr = Instance.new('Frame', setsFrame)
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
   
   local cb = Instance.new('TextButton', setsFrame)
   cb.Size, cb.BackgroundColor3, cb.Text, cb.Font, cb.TextSize, cb.TextColor3, cb.LayoutOrder = UDim2.new(1,0,0,32), Color3.fromRGB(80,160,80), '? Calculate Value', Enum.Font.GothamBold, 12, Color3.fromRGB(255,255,255), 23
   Instance.new('UICorner', cb).CornerRadius = UDim.new(0,6)
   local cbs = Instance.new('UIStroke', cb); cbs.Color, cbs.Thickness, cbs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
   
   PVC.result = Instance.new('TextLabel', setsFrame)
   PVC.result.Size, PVC.result.BackgroundColor3, PVC.result.Text, PVC.result.Font, PVC.result.TextSize, PVC.result.TextColor3, PVC.result.LayoutOrder = UDim2.new(1,0,0,36), Color3.fromRGB(40,35,55), 'Value: --', Enum.Font.GothamBold, 14, Color3.fromRGB(100,255,150), 24
   Instance.new('UICorner', PVC.result).CornerRadius = UDim.new(0,6)
   local rs = Instance.new('UIStroke', PVC.result); rs.Color, rs.Thickness, rs.Transparency = Color3.fromRGB(255,200,50), 1.5, 0.2
   
   cb.MouseButton1Click:Connect(function()
       local sn = PVC.input.Text:lower():gsub('%s+', '')
       if sn == '' then PVC.result.Text, PVC.result.TextColor3 = 'Enter a pet name!', Color3.fromRGB(255,100,100) return end
       local fp, fk = nil, nil
       for k, pet in pairs(petsByName) do if k:lower():gsub('%s+','') == sn or k:lower():gsub('%s+',''):find(sn,1,true) then fp, fk = pet, k break end end
       if not fp then PVC.result.Text, PVC.result.TextColor3 = 'Pet not found!', Color3.fromRGB(255,100,100) return end
       local bk = PVC.state.M and "mvalue" or (PVC.state.N and "nvalue" or "rvalue")
       local sf = (PVC.state.R and PVC.state.F) and " - fly&ride" or (PVC.state.R and " - ride" or (PVC.state.F and " - fly" or " - nopotion"))
       local v = fp[bk..sf] or fp[bk] or 0
       local fv = v >= 1e9 and string.format('%.2fB',v/1e9) or (v >= 1e6 and string.format('%.2fM',v/1e6) or (v >= 1e3 and string.format('%.2fK',v/1e3) or tostring(v)))
       local ps = (PVC.state.M and 'Mega ' or '')..(PVC.state.N and 'Neon ' or '')..(PVC.state.F and 'F' or '')..(PVC.state.R and 'R' or ''); if ps == '' then ps = 'Normal' end
       PVC.result.Text, PVC.result.TextColor3 = fk..' ('..ps..'): '..fv, Color3.fromRGB(100,255,150)
   end)
   cb.MouseEnter:Connect(function() TweenService:Create(cb, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(100,180,100)}):Play() end)
   cb.MouseLeave:Connect(function() TweenService:Create(cb, TweenInfo.new(0.15), {BackgroundColor3=Color3.fromRGB(80,160,80)}):Play() end)
end

-- Keybind input handler
UserInputService.InputBegan:Connect(function(input, gameProcessed)
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
       if HintApp then HintApp:hint({ text = 'Keybind set to ' .. key.Name, length = 2, overridable = true }) end
       return
   end
   
   -- Handle keybind actions
   if input.UserInputType == Enum.UserInputType.Keyboard and not UIState.waitingForKeybind then
       local key = input.KeyCode
       
       -- Select Partner from Trade
       if key == UIState.keybinds.selectPartner then
           pcall(function()
               local partner = nil
               if mockState.active and mockState.trade then
                   partner = mockState.trade.recipient
               else
                   partner = TradeApp:_get_partner()
               end
               if partner and partner.Name then
                   partnerBox.Text = partner.Name
                   updatePartnerFromUsername(partner.Name)
                   if HintApp then
                       HintApp:hint({ text = 'Partner set to ' .. partner.Name, length = 2, overridable = true })
                   end
               end
           end)
       end
       
       -- Add Random Item
       if key == UIState.keybinds.addRandomItem then
           if mockState.active then
               addPetToPartnerOffer(getRandomHighValuePet(), generateRandomPetProperties())
           end
       end
       
       -- Start Trade
       if key == UIState.keybinds.startTrade then
           if not mockState.active then
               task.spawn(startMockTradeDirectly)
           end
       end
       
       -- Block Player
       if key == UIState.keybinds.blockPlayer then
           local player = Players:FindFirstChild(partnerBox.Text)
           if player then
               BlockPlayer(player)
           end
       end
   end
end)

-- ==================== FIXED DRAGGING SYSTEM ====================
local dragging = false
local dragInput, dragStart, startPos

mainFrame.InputBegan:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
       dragging = true
       dragStart = input.Position
       startPos = mainFrame.Position

       input.Changed:Connect(function()
           if input.UserInputState == Enum.UserInputState.End then
               dragging = false
           end
       end)
   end
end)

mainFrame.InputChanged:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
       dragInput = input
   end
end)

UserInputService.InputChanged:Connect(function(input)
   if input == dragInput and dragging then
       local delta = input.Position - dragStart
       mainFrame.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)
   end
end)

-- ==================== KEYBOARD SHORTCUTS ====================
UserInputService.InputBegan:Connect(function(input, gameProcessed)
   if gameProcessed then return end
   if input.KeyCode == Enum.KeyCode.F6 then
       mainFrame.Visible = not mainFrame.Visible
   end
end)

-- ==================== NOCLIP MAINTENANCE ====================
task.spawn(function()
   while true do
       task.wait(1)
       if UIState.noclipEnabled then
           enableNoclipForAllFakePlayers()
           enableNoclipForPets()
       end
   end
end)

-- ==================== INITIAL SETUP ====================
if UIState.activeTabPulseTween == nil then
   local data = tabButtons['Control']
   if data then
       UIState.activeTabPulseTween = TweenService:Create(data.stroke, TweenInfo.new(1.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
           Color = Color3.fromRGB(100, 100, 255):Lerp(Color3.fromRGB(255, 255, 255), 0.25), Thickness = 1.5
       })
       UIState.activeTabPulseTween:Play()
   end
end

task.wait(3)
refreshRichestPlayers(true)

-- ==================== AUTO PARTNER EMOJI ====================
_G.EmojiSystem = {
   running = false,
   reactions = load('SharedConstants').trade_spectate_reactions
}

_G.EmojiSystem.display = function(index)
   if not _G.EmojiSystem.reactions[index] then return end
   if not mockState.active or not mockState.trade then return end
   
   pcall(function()
       local tradeFrame = Players.LocalPlayer.PlayerGui.TradeApp.Frame
       
       local e = Instance.new('ImageLabel')
       e.Image = _G.EmojiSystem.reactions[index]
       e.BackgroundTransparency = 1
       e.ImageTransparency = 1
       e.Size = UDim2.fromOffset(40, 40)
       e.Position = UDim2.new(0.92 + math.random(-3, 3) / 100, 0, 0.95, 0)
       e.AnchorPoint = Vector2.new(0.5, 1)
       e.ZIndex = 100
       e.Parent = tradeFrame
       
       TweenService:Create(e, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
           ImageTransparency = 0, Size = UDim2.fromOffset(45, 45)
       }):Play()
       
       local st, dur, spd = tick(), math.random(18, 28) / 10, 0.18
       local c
       c = RunService.Heartbeat:Connect(function(dt)
           local el = tick() - st
           if el >= dur or not e.Parent then c:Disconnect() if e.Parent then e:Destroy() end return end
           local newY = e.Position.Y.Scale - spd * dt
           local drift = math.sin(el * 4) * dt * 0.0
           e.Position = UDim2.new(math.clamp(e.Position.X.Scale + drift, 0.85, 0.98), 0, newY, 0)
           if el >= dur * 0.5 then e.ImageTransparency = (el - dur * 0.5) / (dur * 0.5) end
       end)
   end)
end

createSpacer(controlFrame)

createButton('? Auto Partner Emoji: OFF', Color3.fromRGB(150, 50, 50), Color3.fromRGB(255, 100, 100), controlFrame, function()
   _G.EmojiSystem.running = not _G.EmojiSystem.running
   local btn
   for _, v in pairs(controlFrame:GetChildren()) do
       if v:IsA('TextButton') and v.Text:find('Emoji') then btn = v break end
   end
   
   if _G.EmojiSystem.running then
       btn.Text = '? Auto Partner Emoji: ON'
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
       btn.Text = '? Auto Partner Emoji: OFF'
       btn.BackgroundColor3 = Color3.fromRGB(150, 50, 50)
   end
end)

-- ==================== RGB CYCLING EFFECT ====================
task.spawn(function()
   while true do
       task.wait(0.03)
       if RGBState.enabled and mainStroke then
           RGBState.hue = (RGBState.hue + RGBState.speed) % 360
           local color = Color3.fromHSV(RGBState.hue / 360, 0.7, 1)
           mainStroke.Color = color
       end
   end
end)

print("hamsterz8 on discord made this script, for any other inquires please message me on discord.")
