
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")

local LocalPlayer = Players.LocalPlayer

-- Thread identity helper for different executors
local function set_thread_identity(level)
   if type(syn) == "table" and syn.set_thread_identity then
       return syn.set_thread_identity(level)
   elseif type(getthreadidentity) == "function" and type(setthreadidentity) == "function" then
       local current = getthreadidentity()
       setthreadidentity(level)
       return current
   elseif type(getthreadcontext) == "function" and type(setthreadcontext) == "function" then
       local current = getthreadcontext()
       setthreadcontext(level)
       return current
   end
   return 2 -- Default to 2 if no identity functions
end

-- Pet names list (capitalized properly)
local petNames = {
   "Bat Dragon", "Shadow Dragon", "Evil Unicorn", "Crow", "Giraffe", 
   "Parrot", "Diamond Butterfly", "Owl", "Frost Dragon", "Giant Panda", 
   "Balloon Unicorn", "Monkey King", "Arctic Reindeer", "Hedgehog", "Flamingo",
   "Turtle", "Kangaroo"
}

-- Toy names list
local toyNames = {
   "Rainbow Rattle", "Candy Cannon", "Witches Broomstick", "Tombstone Ghostify"
}

-- === GLOBAL SPAWNER SYSTEM ===
local spawnerSystemLoaded = false
local spawnerPets = {}
local equippedPet = nil
local mountedPet = nil
local currentMountTrack = nil

-- Make these functions global so they can be called from dialog
_G.createPet = nil
_G.equipPet = nil
_G.unequipPet = nil

-- Store the original dialog message
local originalDialogMessage = "An Adopt Me admin gave you: "
local currentDialogMessage = originalDialogMessage

-- Store selected toy
local selectedToy = ""

-- === SPAWNER SYSTEM ===
local function loadSpawnerSystem()
   if spawnerSystemLoaded then return end
   
   local success, err = pcall(function()
       local oldIdentity = set_thread_identity(2)
       local Fsys = require(game.ReplicatedStorage:WaitForChild('Fsys'))
       local load = Fsys.load
       
       local clientData = load('ClientData')
       local items = load('KindDB')
       local router = load('RouterClient')
       local downloader = load('DownloadClient')
       local animationManager = load('AnimationManager')
       local petRigs = load('new:PetRigs')
       local UIManager = load('UIManager')
       
       set_thread_identity(oldIdentity)

       local petModels = {}

       local function updateData(key, action)
           local oldId = set_thread_identity(2)
           local data = clientData.get(key)
           local clonedData = table.clone(data)
           clientData.predict(key, action(clonedData))
           set_thread_identity(oldId)
       end

       local function getUniqueId()
           return HttpService:GenerateGUID(false)
       end

       local function getPetModel(kind)
           if petModels[kind] then
               return petModels[kind]:Clone()
           end

           local promise = downloader.promise_download_copy('Pets', kind)
           if promise then
               local streamed = promise:expect()
               petModels[kind] = streamed
               return streamed:Clone()
           end
           return nil
       end

       -- === PET CREATION ===
       _G.createPet = function(id, properties)
           local uniqueId = getUniqueId()
           local item = items[id]
           if not item then
               return nil
           end

           local oldId = set_thread_identity(2)
           local new_pet = {
               unique = uniqueId,
               category = 'pets',
               id = id,
               kind = item.kind,
               newness_order = math.random(1, 900000),
               properties = properties or {},
           }
           local inventory = clientData.get('inventory')
           inventory.pets[uniqueId] = new_pet
           set_thread_identity(oldId)
           
           spawnerPets[uniqueId] = {
               data = new_pet,
               model = nil,
           }
           
           return new_pet
       end

       -- === TOY CREATION ===
       _G.createToy = function(toyName, properties)
           local uniqueId = getUniqueId()
           
           local oldId = set_thread_identity(2)
           local InventoryDB = load('InventoryDB')
           
           -- Find toy ID by name
           local toyId
           for id, toy in pairs(InventoryDB.toys) do
               if toy.name:lower() == toyName:lower() then
                   toyId = id
                   break
               end
           end
           
           if not toyId then
               set_thread_identity(oldId)
               return nil
           end
           
           local item = items[toyId]
           if not item then
               set_thread_identity(oldId)
               return nil
           end

           local new_toy = {
               unique = uniqueId,
               category = 'toys',
               id = toyId,
               kind = item.kind,
               newness_order = math.random(1, 900000),
               properties = properties or {},
           }
           
           local inventory = clientData.get('inventory')
           inventory.toys[uniqueId] = new_toy
           set_thread_identity(oldId)
           
           return new_toy
       end

       local function neonify(model, entry)
           local petModel = model:FindFirstChild('PetModel')
           if not petModel then
               return
           end

           local oldId = set_thread_identity(2)
           local petRig = petRigs.get(petModel)
           set_thread_identity(oldId)
           
           if petRig and petRig.get_geo_part then
               for neonPart, configuration in pairs(entry.neon_parts) do
                   local trueNeonPart = petRig.get_geo_part(petModel, neonPart)
                   if trueNeonPart then
                       trueNeonPart.Material = configuration.Material
                       trueNeonPart.Color = configuration.Color
                   end
               end
           end
       end

       local function addPetWrapper(wrapper)
           updateData('pet_char_wrappers', function(petWrappers)
               wrapper.unique = #petWrappers + 1
               wrapper.index = #petWrappers + 1
               petWrappers[#petWrappers + 1] = wrapper
               return petWrappers
           end)
       end

       local function addPetState(state)
           updateData('pet_state_managers', function(petStates)
               petStates[#petStates + 1] = state
               return petStates
           end)
       end

       local function findIndex(array, finder)
           for index, value in pairs(array) do
               local isIt = finder(value, index)
               if isIt then
                   return index
               end
           end
           return nil
       end

       local function removePetWrapper(uniqueId)
           updateData('pet_char_wrappers', function(petWrappers)
               local index = findIndex(petWrappers, function(wrapper)
                   return wrapper.pet_unique == uniqueId
               end)

               if not index then
                   return petWrappers
               end

               table.remove(petWrappers, index)

               for wrapperIndex, wrapper in pairs(petWrappers) do
                   wrapper.unique = wrapperIndex
                   wrapper.index = wrapperIndex
               end

               return petWrappers
           end)
       end

       local function removePetState(uniqueId)
           local pet = spawnerPets[uniqueId]
           if not pet or not pet.model then
               return
           end

           updateData('pet_state_managers', function(petStates)
               local index = findIndex(petStates, function(state)
                   return state.char == pet.model
               end)

               if not index then
                   return petStates
               end

               table.remove(petStates, index)
               return petStates
           end)
       end

       -- === EQUIP/UNEQUIP SYSTEM ===
       _G.unequipPet = function(item)
           local pet = spawnerPets[item.unique]
           if not pet then 
               return 
           end

           removePetWrapper(item.unique)
           removePetState(item.unique)

           if pet.model then
               pet.model:Destroy()
               pet.model = nil
           end

           equippedPet = nil
       end

       _G.equipPet = function(item)
           if equippedPet then
               _G.unequipPet(equippedPet)
           end

           local petModel = getPetModel(item.kind)
           if not petModel then
               return
           end
           
           petModel.Parent = workspace
           spawnerPets[item.unique].model = petModel

           if item.properties.neon or item.properties.mega_neon then
               neonify(petModel, items[item.kind])
           end

           equippedPet = item
           
           local wrapper = {
               char = petModel,
               mega_neon = item.properties.mega_neon,
               neon = item.properties.neon,
               player = LocalPlayer,
               entity_controller = LocalPlayer,
               controller = LocalPlayer,
               rp_name = item.properties.rp_name or '',
               pet_trick_level = item.properties.pet_trick_level,
               pet_unique = item.unique,
               pet_id = item.id,
               location = {
                   full_destination_id = 'housing',
                   destination_id = 'housing',
                   house_owner = LocalPlayer,
               },
               pet_progression = {
                   age = math.random(1, 900000),
                   percentage = math.random(0.01, 0.99),
               },
               are_colors_sealed = false,
               is_pet = true,
           }
           
           addPetWrapper(wrapper)

           addPetState({
               char = petModel,
               player = LocalPlayer,
               store_key = 'pet_state_managers',
               is_sitting = false,
               chars_connected_to_me = {},
               states = {},
           })
       end

       -- Helper function to get pet by name
       local InventoryDB = load('InventoryDB')
       _G.GetPetByName = function(name)
           local oldId = set_thread_identity(2)
           for i, v in pairs(InventoryDB.pets) do
               if v.name:lower() == name:lower() then
                   set_thread_identity(oldId)
                   return v.id
               end
           end
           set_thread_identity(oldId)
           return false
       end

       -- Helper function to get toy by name
       _G.GetToyByName = function(name)
           local oldId = set_thread_identity(2)
           for i, v in pairs(InventoryDB.toys) do
               if v.name:lower() == name:lower() then
                   set_thread_identity(oldId)
                   return v.id
               end
           end
           set_thread_identity(oldId)
           return false
       end

       -- ROUTER.GET OVERRIDE
       local oldGet = router.get

       local function createRemoteFunctionMock(callback)
           return {
               InvokeServer = function(_, ...)
                   return callback(...)
               end,
           }
       end

       local function createRemoteEventMock(callback)
           return {
               FireServer = function(_, ...)
                   return callback(...)
               end,
           }
       end

       -- Helper functions for mounting
       local function clearPetState(uniqueId)
           local pet = spawnerPets[uniqueId]
           if not pet or not pet.model then return end

           updateData('pet_state_managers', function(states)
               local index = findIndex(states, function(state)
                   return state.char == pet.model
               end)
               if not index then return states end

               local clonedStates = table.clone(states)
               clonedStates[index] = table.clone(clonedStates[index])
               clonedStates[index].states = {}
               return clonedStates
           end)
       end

       local function setPetState(uniqueId, id)
           local pet = spawnerPets[uniqueId]
           if not pet or not pet.model then return end

           updateData('pet_state_managers', function(states)
               local index = findIndex(states, function(state)
                   return state.char == pet.model
               end)
               if not index then return states end

               local clonedStates = table.clone(states)
               clonedStates[index] = table.clone(clonedStates[index])
               clonedStates[index].states = {{ id = id }}
               return clonedStates
           end)
       end

       local function attachPlayerToPet(pet)
           local character = LocalPlayer.Character
           if not character or not character.PrimaryPart then return false end

           local ridePosition = pet:FindFirstChild('RidePosition', true)
           if not ridePosition then return false end

           local sourceAttachment = Instance.new('Attachment')
           sourceAttachment.Parent = ridePosition
           sourceAttachment.Position = Vector3.new(0, 1.237, 0)
           sourceAttachment.Name = 'SourceAttachment'

           local stateConnection = Instance.new('RigidConstraint')
           stateConnection.Name = 'StateConnection'
           stateConnection.Attachment0 = sourceAttachment
           stateConnection.Attachment1 = character.PrimaryPart.RootAttachment
           stateConnection.Parent = character

           return true
       end

       local function clearPlayerState()
           updateData('state_manager', function(state)
               local clonedState = table.clone(state)
               clonedState.states = {}
               clonedState.is_sitting = false
               return clonedState
           end)
       end

       local function setPlayerState(id)
           updateData('state_manager', function(state)
               local clonedState = table.clone(state)
               clonedState.states = {{ id = id }}
               clonedState.is_sitting = true
               return clonedState
           end)
       end

       local function unmount(uniqueId)
           local pet = spawnerPets[uniqueId]
           if not pet or not pet.model then return end

           if currentMountTrack then
               currentMountTrack:Stop()
               currentMountTrack:Destroy()
           end

           local sourceAttachment = pet.model:FindFirstChild('SourceAttachment', true)
           if sourceAttachment then
               sourceAttachment:Destroy()
           end

           if LocalPlayer.Character then
               for _, descendant in pairs(LocalPlayer.Character:GetDescendants()) do
                   if descendant:IsA('BasePart') and descendant:GetAttribute('HaveMass') then
                       descendant.Massless = false
                   end
               end
           end

           clearPetState(uniqueId)
           clearPlayerState()
           pet.model:ScaleTo(1)
           mountedPet = nil
       end

       local function mount(uniqueId, playerState, petState)
           local pet = spawnerPets[uniqueId]
           if not pet or not pet.model then return end

           local player = LocalPlayer
           if not player.Character or not player.Character.PrimaryPart then return end

           mountedPet = uniqueId

           setPetState(uniqueId, petState)
           setPlayerState(playerState)

           pet.model:ScaleTo(2)
           attachPlayerToPet(pet.model)

           currentMountTrack = player.Character.Humanoid.Animator:LoadAnimation(
               animationManager.get_track('PlayerRidingPet')
           )
           player.Character.Humanoid.Sit = true

           for _, descendant in pairs(player.Character:GetDescendants()) do
               if descendant:IsA('BasePart') and descendant.Massless == false then
                   descendant.Massless = true
                   descendant:SetAttribute('HaveMass', true)
               end
           end

           currentMountTrack:Play()
       end

       local function fly(uniqueId)
           mount(uniqueId, 'PlayerFlyingPet', 'PetBeingFlown')
       end

       local function ride(uniqueId)
           mount(uniqueId, 'PlayerRidingPet', 'PetBeingRidden')
       end

       -- Only intercept pet equips
       local equipRemote = createRemoteFunctionMock(function(uniqueId, metadata)
           local pet = spawnerPets[uniqueId]

           if pet then
               _G.equipPet(pet.data)
               return true, { action = 'equip', is_server = true }
           end

           -- Forward non-pet equips to original handler
           return oldGet('ToolAPI/Equip'):InvokeServer(uniqueId, metadata)
       end)

       -- Only intercept pet unequips
       local unequipRemote = createRemoteFunctionMock(function(uniqueId)
           local pet = spawnerPets[uniqueId]

           if pet then
               _G.unequipPet(pet.data)
               return true, { action = 'unequip', is_server = true }
           end

           -- Forward non-pet unequips to original handler
           return oldGet('ToolAPI/Unequip'):InvokeServer(uniqueId)
       end)

       -- Pet riding/flying remotes
       local rideRemote = createRemoteFunctionMock(function(item)
           ride(item.pet_unique)
       end)

       local flyRemote = createRemoteFunctionMock(function(item)
           fly(item.pet_unique)
       end)

       local unmountRemoteFunction = createRemoteFunctionMock(function()
           unmount(mountedPet)
       end)

       local unmountRemoteEvent = createRemoteEventMock(function()
           unmount(mountedPet)
       end)

       router.get = function(name)
           -- Only intercept pet-related calls
           if name == 'ToolAPI/Equip' then
               return equipRemote
           elseif name == 'ToolAPI/Unequip' then
               return unequipRemote
           elseif name == 'AdoptAPI/RidePet' then
               return rideRemote
           elseif name == 'AdoptAPI/FlyPet' then
               return flyRemote
           elseif name == 'AdoptAPI/ExitSeatStatesYield' then
               return unmountRemoteFunction
           elseif name == 'AdoptAPI/ExitSeatStates' then
               return unmountRemoteEvent
           end

           -- Pass through all other requests
           return oldGet(name)
       end

       spawnerSystemLoaded = true
   end)
   
   if not success then
       warn("Error loading spawner system:", err)
   end
end

-- === MAIN GUI ===
local screenGui = Instance.new("ScreenGui")
screenGui.Name = "PetDialogGui"
screenGui.ResetOnSpawn = false
screenGui.Parent = LocalPlayer:WaitForChild("PlayerGui")

local mainFrame = Instance.new("Frame")
mainFrame.Size = UDim2.new(0, 180, 0, 400) -- Increased height for toy dialog button
mainFrame.Position = UDim2.new(0.5, -90, 0.5, -200)
mainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
mainFrame.BackgroundTransparency = 0
mainFrame.BorderSizePixel = 0
mainFrame.ZIndex = 1
mainFrame.Active = true
mainFrame.Selectable = true
mainFrame.Parent = screenGui

local uiCorner = Instance.new("UICorner")
uiCorner.CornerRadius = UDim.new(0, 10)
uiCorner.Parent = mainFrame

local uiStroke = Instance.new("UIStroke")
uiStroke.Color = Color3.fromRGB(170, 0, 255)
uiStroke.Thickness = 3
uiStroke.Transparency = 0
uiStroke.Parent = mainFrame

local blackFrame = Instance.new("Frame")
blackFrame.Size = UDim2.new(0, 190, 0, 410)
blackFrame.BackgroundColor3 = Color3.new(0, 0, 0)
blackFrame.BackgroundTransparency = 0
blackFrame.BorderSizePixel = 0
blackFrame.ZIndex = 0
blackFrame.Parent = screenGui

local blackCorner = Instance.new("UICorner")
blackCorner.CornerRadius = UDim.new(0, 12)
blackCorner.Parent = blackFrame

mainFrame:GetPropertyChangedSignal("Position"):Connect(function()
   blackFrame.Position = UDim2.new(
       mainFrame.Position.X.Scale,
       mainFrame.Position.X.Offset - 5,
       mainFrame.Position.Y.Scale,
       mainFrame.Position.Y.Offset - 5
   )
end)

blackFrame.Position = UDim2.new(
   mainFrame.Position.X.Scale,
   mainFrame.Position.X.Offset - 5,
   mainFrame.Position.Y.Scale,
   mainFrame.Position.Y.Offset - 5
)

-- === COLOR ANIMATION ===
local colorPalette = {
   Color3.fromRGB(170, 0, 255), Color3.fromRGB(120, 0, 255),
   Color3.fromRGB(0, 100, 255), Color3.fromRGB(0, 200, 255),
   Color3.fromRGB(0, 255, 150), Color3.fromRGB(0, 255, 100),
   Color3.fromRGB(255, 100, 0), Color3.fromRGB(255, 50, 150)
}

local currentIndex = 1
local function animateToNextColor()
   local nextIndex = currentIndex % #colorPalette + 1
   TweenService:Create(uiStroke, TweenInfo.new(4, Enum.EasingStyle.Linear), {
       Color = colorPalette[nextIndex]
   }):Play()
   currentIndex = nextIndex
   wait(4)
   animateToNextColor()
end
coroutine.wrap(animateToNextColor)()

-- === TABS SYSTEM ===
local tabsContainer = Instance.new("Frame")
tabsContainer.Size = UDim2.new(1, 0, 0, 30)
tabsContainer.Position = UDim2.new(0, 0, 0, 40) -- Moved down to make room for title
tabsContainer.BackgroundTransparency = 1
tabsContainer.Parent = mainFrame

-- Create tabs
local mainTab = Instance.new("TextButton")
mainTab.Size = UDim2.new(0.4, 0, 1, 0)
mainTab.Position = UDim2.new(0.05, 0, 0, 0)
mainTab.Text = "Main"
mainTab.Font = Enum.Font.FredokaOne
mainTab.TextSize = 12
mainTab.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
mainTab.TextColor3 = Color3.fromRGB(215, 215, 255)
mainTab.AutoButtonColor = true
mainTab.Parent = tabsContainer

local editorTab = Instance.new("TextButton")
editorTab.Size = UDim2.new(0.4, 0, 1, 0)
editorTab.Position = UDim2.new(0.55, 0, 0, 0)
editorTab.Text = "Editor"
editorTab.Font = Enum.Font.FredokaOne
editorTab.TextSize = 12
editorTab.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
editorTab.TextColor3 = Color3.fromRGB(215, 215, 255)
editorTab.AutoButtonColor = true
editorTab.Parent = tabsContainer

local tabsCorner = Instance.new("UICorner")
tabsCorner.CornerRadius = UDim.new(0, 4)
tabsCorner.Parent = mainTab

local tabsCorner2 = Instance.new("UICorner")
tabsCorner2.CornerRadius = UDim.new(0, 4)
tabsCorner2.Parent = editorTab

-- === CONTENT FRAMES ===
local contentContainer = Instance.new("Frame")
contentContainer.Size = UDim2.new(1, 0, 1, -70) -- Adjusted for tabs and title
contentContainer.Position = UDim2.new(0, 0, 0, 70)
contentContainer.BackgroundTransparency = 1
contentContainer.Parent = mainFrame

-- Main content frame (default visible)
local mainContent = Instance.new("Frame")
mainContent.Size = UDim2.new(1, 0, 1, 0)
mainContent.BackgroundTransparency = 1
mainContent.Visible = true
mainContent.Parent = contentContainer

-- Editor content frame
local editorContent = Instance.new("Frame")
editorContent.Size = UDim2.new(1, 0, 1, 0)
editorContent.BackgroundTransparency = 1
editorContent.Visible = false
editorContent.Parent = contentContainer

-- === GUI ELEMENTS (NOW IN MAIN CONTENT) ===
local topLabel = Instance.new("TextLabel")
topLabel.Size = UDim2.new(1, 0, 0, 25)
topLabel.Position = UDim2.new(0, 0, 0, 5) -- Moved up higher
topLabel.BackgroundTransparency = 1
topLabel.Text = "ZetaScripts (last4zeta on tt)"
topLabel.Font = Enum.Font.FredokaOne
topLabel.TextSize = 14
topLabel.TextColor3 = Color3.fromRGB(240, 240, 255)
topLabel.Parent = mainFrame

-- === PET SECTION ===
local petNameLabel = Instance.new("TextLabel")
petNameLabel.Size = UDim2.new(0.6, 0, 0, 12)
petNameLabel.Position = UDim2.new(0.05, 0, 0, 0) -- Adjusted position for mainContent
petNameLabel.BackgroundTransparency = 1
petNameLabel.Text = "Pet Name"
petNameLabel.Font = Enum.Font.FredokaOne
petNameLabel.TextSize = 8
petNameLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
petNameLabel.TextXAlignment = Enum.TextXAlignment.Left
petNameLabel.Parent = mainContent

local petListBtn = Instance.new("TextButton")
petListBtn.Size = UDim2.new(0.3, 0, 0, 12)
petListBtn.Position = UDim2.new(0.65, 0, 0, 0) -- Adjusted position for mainContent
petListBtn.Text = "Pet list"
petListBtn.Font = Enum.Font.FredokaOne
petListBtn.TextSize = 8
petListBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
petListBtn.TextColor3 = Color3.fromRGB(215, 215, 255)
petListBtn.AutoButtonColor = true
petListBtn.Parent = mainContent

local uiCornerList = Instance.new("UICorner")
uiCornerList.CornerRadius = UDim.new(0, 4)
uiCornerList.Parent = petListBtn

local petNameBox = Instance.new("TextBox")
petNameBox.Size = UDim2.new(0.9, 0, 0, 20)
petNameBox.Position = UDim2.new(0.05, 0, 0.05, 0) -- Adjusted position for mainContent
petNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
petNameBox.BackgroundTransparency = 0.2
petNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
petNameBox.TextSize = 11
petNameBox.Font = Enum.Font.FredokaOne
petNameBox.PlaceholderText = "insert pet name"
petNameBox.Text = ""
petNameBox.ClearTextOnFocus = false
petNameBox.Parent = mainContent

Instance.new("UICorner", petNameBox).CornerRadius = UDim.new(0, 6)

local boxStroke = Instance.new("UIStroke", petNameBox)
boxStroke.Color = Color3.new(0, 0, 0)
boxStroke.Thickness = 1.2
boxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

local boxGlow = Instance.new("UIStroke", petNameBox)
boxGlow.Color = Color3.fromRGB(255, 255, 255)
boxGlow.Thickness = 2.2
boxGlow.Transparency = 0.25
boxGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- === PET SHOW DIALOG BUTTON ===
local petDialogBtn = Instance.new("TextButton")
petDialogBtn.Size = UDim2.new(0.9, 0, 0, 20)
petDialogBtn.Position = UDim2.new(0.05, 0, 0.12, 0) -- Adjusted position for mainContent
petDialogBtn.Text = "Show Pet Dialog"
petDialogBtn.Font = Enum.Font.FredokaOne
petDialogBtn.TextSize = 11
petDialogBtn.BackgroundColor3 = Color3.fromRGB(30, 105, 210)
petDialogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
petDialogBtn.AutoButtonColor = true
petDialogBtn.Parent = mainContent

Instance.new("UICorner", petDialogBtn).CornerRadius = UDim.new(0, 6)

-- === RANDOM PET BUTTON ===
local randomPetBtn = Instance.new("TextButton")
randomPetBtn.Size = UDim2.new(0.9, 0, 0, 18)
randomPetBtn.Position = UDim2.new(0.05, 0, 0.20, 0) -- Adjusted position for mainContent
randomPetBtn.Text = "Pick Random Pet"
randomPetBtn.Font = Enum.Font.FredokaOne
randomPetBtn.TextSize = 10
randomPetBtn.BackgroundColor3 = Color3.fromRGB(100, 50, 150)
randomPetBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
randomPetBtn.AutoButtonColor = true
randomPetBtn.Parent = mainContent

Instance.new("UICorner", randomPetBtn).CornerRadius = UDim.new(0, 6)

-- === POTION BUTTONS ===
local activeFlags = {F = false, R = false, N = false, M = false}
local flagColors = {
   M = Color3.fromRGB(170, 0, 255),
   N = Color3.fromRGB(0, 255, 100),
   F = Color3.fromRGB(0, 200, 255),
   R = Color3.fromRGB(255, 50, 150)
}

local prefixes = {"F", "R", "N", "M"}

for i, prefix in ipairs(prefixes) do
   local prefixButton = Instance.new("TextButton")
   prefixButton.Size = UDim2.new(0.18, 0, 0, 18)
   prefixButton.Position = UDim2.new(0.05 + (i-1)*0.23, 0, 0.28, 0) -- Adjusted position for mainContent
   prefixButton.Text = prefix
   prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
   prefixButton.BackgroundTransparency = 0.2
   prefixButton.Font = Enum.Font.FredokaOne
   prefixButton.TextColor3 = Color3.fromRGB(255, 255, 255)
   prefixButton.TextSize = 12
   prefixButton.AutoButtonColor = true
   prefixButton.Parent = mainContent

   Instance.new("UICorner", prefixButton).CornerRadius = UDim.new(0, 6)

   local buttonStroke = Instance.new("UIStroke", prefixButton)
   buttonStroke.Color = flagColors[prefix]
   buttonStroke.Thickness = 2
   buttonStroke.Transparency = 0.5
   buttonStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

   local textStroke = Instance.new("UIStroke", prefixButton)
   textStroke.Color = Color3.new(0, 0, 0)
   textStroke.Thickness = 1.5
   textStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

   local originalStroke = {
       Color = flagColors[prefix],
       Thickness = 2,
       Transparency = 0.5
   }

   prefixButton.MouseButton1Click:Connect(function()
       if prefix == "M" and activeFlags["N"] then return end
       if prefix == "N" and activeFlags["M"] then return end

       activeFlags[prefix] = not activeFlags[prefix]

       if activeFlags[prefix] then
           prefixButton.BackgroundColor3 = Color3.fromRGB(100, 100, 100)
           TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
               Color = Color3.fromRGB(0, 255, 0),
               Thickness = 3,
               Transparency = 0.2
           }):Play()
       else
           prefixButton.BackgroundColor3 = Color3.fromRGB(60, 60, 70)
           TweenService:Create(buttonStroke, TweenInfo.new(0.3, Enum.EasingStyle.Quad), {
               Color = originalStroke.Color,
               Thickness = originalStroke.Thickness,
               Transparency = originalStroke.Transparency
           }):Play()
       end
       updateInfoBox()
   end)
end

-- === INFO BOX ===
local infoBox = Instance.new("Frame")
infoBox.Size = UDim2.new(0.9, 0, 0, 22)
infoBox.Position = UDim2.new(0.05, 0, 0.38, 0) -- Adjusted position for mainContent
infoBox.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
infoBox.BackgroundTransparency = 0.5
infoBox.Parent = mainContent

Instance.new("UICorner", infoBox).CornerRadius = UDim.new(0, 6)

local infoBoxStroke = Instance.new("UIStroke", infoBox)
infoBoxStroke.Color = Color3.fromRGB(255, 255, 255)
infoBoxStroke.Thickness = 1.2
infoBoxStroke.Transparency = 0.7

local infoTextContainer = Instance.new("Frame", infoBox)
infoTextContainer.Size = UDim2.new(1, 0, 1, 0)
infoTextContainer.BackgroundTransparency = 1

local uiListLayout = Instance.new("UIListLayout", infoTextContainer)
uiListLayout.FillDirection = Enum.FillDirection.Horizontal
uiListLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
uiListLayout.VerticalAlignment = Enum.VerticalAlignment.Center
uiListLayout.Padding = UDim.new(0, 4)

-- === INFO BOX UPDATE FUNCTION ===
local function updateInfoBox()
   for _, child in ipairs(infoTextContainer:GetChildren()) do
       if child:IsA("TextLabel") then
           child:Destroy()
       end
   end
   
   if activeFlags["M"] then
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0, 0, 1, 0)
       label.AutomaticSize = Enum.AutomaticSize.X
       label.BackgroundTransparency = 1
       label.Text = "Mega Neon"
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 10
       label.TextColor3 = flagColors.M
       label.Parent = infoTextContainer
   elseif activeFlags["N"] then
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0, 0, 1, 0)
       label.AutomaticSize = Enum.AutomaticSize.X
       label.BackgroundTransparency = 1
       label.Text = "Neon"
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 10
       label.TextColor3 = flagColors.N
       label.Parent = infoTextContainer
   end
   
   if activeFlags["F"] then
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0, 0, 1, 0)
       label.AutomaticSize = Enum.AutomaticSize.X
       label.BackgroundTransparency = 1
       label.Text = activeFlags["N"] or activeFlags["M"] and " Fly" or "Fly"
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 10
       label.TextColor3 = flagColors.F
       label.Parent = infoTextContainer
   end
   
   if activeFlags["R"] then
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0, 0, 1, 0)
       label.AutomaticSize = Enum.AutomaticSize.X
       label.BackgroundTransparency = 1
       label.Text = (activeFlags["N"] or activeFlags["M"] or activeFlags["F"]) and " Ride" or "Ride"
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 10
       label.TextColor3 = flagColors.R
       label.Parent = infoTextContainer
   end
   
   if not (activeFlags["M"] or activeFlags["N"] or activeFlags["F"] or activeFlags["R"]) then
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0, 0, 1, 0)
       label.AutomaticSize = Enum.AutomaticSize.X
       label.BackgroundTransparency = 1
       label.Text = "Normal"
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 10
       label.TextColor3 = Color3.fromRGB(255, 255, 255)
       label.Parent = infoTextContainer
       infoBoxStroke.Color = Color3.fromRGB(255, 255, 255)
       infoBoxStroke.Thickness = 1.2
       infoBoxStroke.Transparency = 0.7
   end
end

-- Initialize info box
updateInfoBox()

-- === TOY SECTION ===
local toyListLabel = Instance.new("TextLabel")
toyListLabel.Size = UDim2.new(0.6, 0, 0, 12)
toyListLabel.Position = UDim2.new(0.05, 0, 0.50, 0)
toyListLabel.BackgroundTransparency = 1
toyListLabel.Text = "Toy List"
toyListLabel.Font = Enum.Font.FredokaOne
toyListLabel.TextSize = 8
toyListLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
toyListLabel.TextXAlignment = Enum.TextXAlignment.Left
toyListLabel.Parent = mainContent

local toyListBtn = Instance.new("TextButton")
toyListBtn.Size = UDim2.new(0.3, 0, 0, 12)
toyListBtn.Position = UDim2.new(0.65, 0, 0.50, 0)
toyListBtn.Text = "Toy list"
toyListBtn.Font = Enum.Font.FredokaOne
toyListBtn.TextSize = 8
toyListBtn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
toyListBtn.TextColor3 = Color3.fromRGB(215, 215, 255)
toyListBtn.AutoButtonColor = true
toyListBtn.Parent = mainContent

local toyListCorner = Instance.new("UICorner")
toyListCorner.CornerRadius = UDim.new(0, 4)
toyListCorner.Parent = toyListBtn

local toyNameBox = Instance.new("TextBox")
toyNameBox.Size = UDim2.new(0.9, 0, 0, 20)
toyNameBox.Position = UDim2.new(0.05, 0, 0.56, 0)
toyNameBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
toyNameBox.BackgroundTransparency = 0.2
toyNameBox.TextColor3 = Color3.fromRGB(255, 255, 255)
toyNameBox.TextSize = 11
toyNameBox.Font = Enum.Font.FredokaOne
toyNameBox.PlaceholderText = "selected toy appears here"
toyNameBox.Text = ""
toyNameBox.ClearTextOnFocus = false
toyNameBox.Parent = mainContent

Instance.new("UICorner", toyNameBox).CornerRadius = UDim.new(0, 6)

local toyBoxStroke = Instance.new("UIStroke", toyNameBox)
toyBoxStroke.Color = Color3.new(0, 0, 0)
toyBoxStroke.Thickness = 1.2
toyBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

local toyBoxGlow = Instance.new("UIStroke", toyNameBox)
toyBoxGlow.Color = Color3.fromRGB(255, 180, 0)
toyBoxGlow.Thickness = 2.2
toyBoxGlow.Transparency = 0.25
toyBoxGlow.ApplyStrokeMode = Enum.ApplyStrokeMode.Border

-- === TOY SHOW DIALOG BUTTON ===
local toyDialogBtn = Instance.new("TextButton")
toyDialogBtn.Size = UDim2.new(0.9, 0, 0, 20)
toyDialogBtn.Position = UDim2.new(0.05, 0, 0.63, 0)
toyDialogBtn.Text = "Show Toy Dialog"
toyDialogBtn.Font = Enum.Font.FredokaOne
toyDialogBtn.TextSize = 11
toyDialogBtn.BackgroundColor3 = Color3.fromRGB(210, 105, 30) -- Orange color for toy button
toyDialogBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
toyDialogBtn.AutoButtonColor = true
toyDialogBtn.Parent = mainContent

Instance.new("UICorner", toyDialogBtn).CornerRadius = UDim.new(0, 6)

-- === SPAM POP-UPS TOGGLE ===
local spamActive = false
local spamCoroutine = nil
local spamSpeed = 0.01 -- ULTRA FAST: 0.01 seconds = 100 dialogs per second

local spamContainer = Instance.new("Frame")
spamContainer.Size = UDim2.new(0.9, 0, 0, 20)
spamContainer.Position = UDim2.new(0.05, 0, 0.70, 0) -- Adjusted position for mainContent
spamContainer.BackgroundTransparency = 1
spamContainer.Parent = mainContent

local spamLabel = Instance.new("TextLabel")
spamLabel.Size = UDim2.new(0.6, 0, 1, 0)
spamLabel.Position = UDim2.new(0, 0, 0, 0)
spamLabel.BackgroundTransparency = 1
spamLabel.Text = "SPAM POP-UPS"
spamLabel.Font = Enum.Font.FredokaOne
spamLabel.TextSize = 10
spamLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
spamLabel.TextXAlignment = Enum.TextXAlignment.Left
spamLabel.Parent = spamContainer

local spamToggle = Instance.new("TextButton")
spamToggle.Size = UDim2.new(0.3, 0, 0.7, 0)
spamToggle.Position = UDim2.new(0.65, 0, 0.15, 0)
spamToggle.Text = ""
spamToggle.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
spamToggle.AutoButtonColor = false
spamToggle.Parent = spamContainer

local toggleCorner = Instance.new("UICorner")
toggleCorner.CornerRadius = UDim.new(0, 10)
toggleCorner.Parent = spamToggle

local toggleCircle = Instance.new("Frame")
toggleCircle.Size = UDim2.new(0.45, 0, 0.7, 0)
toggleCircle.Position = UDim2.new(0, 2, 0.15, 0)
toggleCircle.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
toggleCircle.Parent = spamToggle

local circleCorner = Instance.new("UICorner")
circleCorner.CornerRadius = UDim.new(0, 10)
circleCorner.Parent = toggleCircle

-- === SPAM STATUS ===
local spamStatus = Instance.new("TextLabel")
spamStatus.Size = UDim2.new(0.9, 0, 0, 15)
spamStatus.Position = UDim2.new(0.05, 0, 0.75, 0) -- Adjusted position for mainContent
spamStatus.BackgroundTransparency = 1
spamStatus.Text = "Status: OFF (Speed: 100/sec)"
spamStatus.Font = Enum.Font.FredokaOne
spamStatus.TextSize = 9
spamStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
spamStatus.Parent = mainContent

-- === ADD TO INVENTORY BUTTON ===
local addToInventoryBtn = Instance.new("TextButton")
addToInventoryBtn.Size = UDim2.new(0.9, 0, 0, 20)
addToInventoryBtn.Position = UDim2.new(0.05, 0, 0.85, 0)
addToInventoryBtn.Text = "Add to Inventory"
addToInventoryBtn.Font = Enum.Font.FredokaOne
addToInventoryBtn.TextSize = 11
addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
addToInventoryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
addToInventoryBtn.AutoButtonColor = true
addToInventoryBtn.Parent = mainContent

Instance.new("UICorner", addToInventoryBtn).CornerRadius = UDim.new(0, 6)

-- === EDITOR TAB CONTENT ===
-- Custom Dialog Message TextBox
local editorTitle = Instance.new("TextLabel")
editorTitle.Size = UDim2.new(0.9, 0, 0, 20)
editorTitle.Position = UDim2.new(0.05, 0, 0, 0)
editorTitle.BackgroundTransparency = 1
editorTitle.Text = "Custom Dialog Message:"
editorTitle.Font = Enum.Font.FredokaOne
editorTitle.TextSize = 11
editorTitle.TextColor3 = Color3.fromRGB(240, 240, 255)
editorTitle.TextXAlignment = Enum.TextXAlignment.Left
editorTitle.Parent = editorContent

local dialogMessageBox = Instance.new("TextBox")
dialogMessageBox.Size = UDim2.new(0.9, 0, 0, 50)
dialogMessageBox.Position = UDim2.new(0.05, 0, 0.08, 0)
dialogMessageBox.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
dialogMessageBox.BackgroundTransparency = 0.2
dialogMessageBox.TextColor3 = Color3.fromRGB(255, 255, 255)
dialogMessageBox.TextSize = 11
dialogMessageBox.Font = Enum.Font.FredokaOne
dialogMessageBox.PlaceholderText = "Enter custom dialog message here..."
dialogMessageBox.Text = originalDialogMessage
dialogMessageBox.ClearTextOnFocus = false
dialogMessageBox.TextWrapped = true
dialogMessageBox.Parent = editorContent

Instance.new("UICorner", dialogMessageBox).CornerRadius = UDim.new(0, 6)

local messageBoxStroke = Instance.new("UIStroke", dialogMessageBox)
messageBoxStroke.Color = Color3.new(0, 0, 0)
messageBoxStroke.Thickness = 1.2
messageBoxStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual

-- Presets Scrollbox
local presetsTitle = Instance.new("TextLabel")
presetsTitle.Size = UDim2.new(0.9, 0, 0, 15)
presetsTitle.Position = UDim2.new(0.05, 0, 0.28, 0)
presetsTitle.BackgroundTransparency = 1
presetsTitle.Text = "Presets:"
presetsTitle.Font = Enum.Font.FredokaOne
presetsTitle.TextSize = 10
presetsTitle.TextColor3 = Color3.fromRGB(200, 200, 255)
presetsTitle.TextXAlignment = Enum.TextXAlignment.Left
presetsTitle.Parent = editorContent

local presetsScroll = Instance.new("ScrollingFrame")
presetsScroll.Size = UDim2.new(0.9, 0, 0, 100)
presetsScroll.Position = UDim2.new(0.05, 0, 0.35, 0)
presetsScroll.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
presetsScroll.BackgroundTransparency = 0.2
presetsScroll.ScrollBarThickness = 6
presetsScroll.CanvasSize = UDim2.new(0, 0, 0, 200)
presetsScroll.BorderSizePixel = 0
presetsScroll.Parent = editorContent

Instance.new("UICorner", presetsScroll).CornerRadius = UDim.new(0, 6)

local scrollStroke = Instance.new("UIStroke", presetsScroll)
scrollStroke.Color = Color3.fromRGB(170, 0, 255)
scrollStroke.Thickness = 2
scrollStroke.Transparency = 0.3

local presetsLayout = Instance.new("UIListLayout")
presetsLayout.Padding = UDim.new(0, 5)
presetsLayout.SortOrder = Enum.SortOrder.LayoutOrder
presetsLayout.Parent = presetsScroll

-- Preset buttons
local presets = {
   "Adopt Me! Has partnered with Starpets and given you:",
   "Thank you for buying from the tropicaljules shop! Heres your pet:",
   "JesseRaen and NewFissy have given you a PERMANENT:"
}

-- Add original as first preset
table.insert(presets, 1, originalDialogMessage)

for i, presetText in ipairs(presets) do
   local presetButton = Instance.new("TextButton")
   presetButton.Size = UDim2.new(0.95, 0, 0, 40)
   presetButton.Position = UDim2.new(0, 5, 0, (i-1)*45)
   presetButton.Text = presetText
   presetButton.Font = Enum.Font.FredokaOne
   presetButton.TextSize = 9
   presetButton.TextColor3 = Color3.fromRGB(255, 255, 255)
   presetButton.BackgroundColor3 = Color3.fromRGB(60, 60, 80)
   presetButton.AutoButtonColor = true
   presetButton.TextWrapped = true
   presetButton.LayoutOrder = i
   presetButton.Parent = presetsScroll
   
   Instance.new("UICorner", presetButton).CornerRadius = UDim.new(0, 6)
   
   local presetStroke = Instance.new("UIStroke", presetButton)
   presetStroke.Color = Color3.fromRGB(120, 0, 255)
   presetStroke.Thickness = 2
   presetStroke.Transparency = 0.5
   
   presetButton.MouseButton1Click:Connect(function()
       dialogMessageBox.Text = presetText
   end)
end

-- Update canvas size
task.spawn(function()
   wait()
   presetsScroll.CanvasSize = UDim2.new(0, 0, 0, presetsLayout.AbsoluteContentSize.Y)
end)

-- Apply and Revert Buttons
local applyButton = Instance.new("TextButton")
applyButton.Size = UDim2.new(0.4, 0, 0, 20)
applyButton.Position = UDim2.new(0.05, 0, 0.78, 0)
applyButton.Text = "Apply"
applyButton.Font = Enum.Font.FredokaOne
applyButton.TextSize = 11
applyButton.BackgroundColor3 = Color3.fromRGB(30, 170, 80)
applyButton.TextColor3 = Color3.fromRGB(255, 255, 255)
applyButton.AutoButtonColor = true
applyButton.Parent = editorContent

Instance.new("UICorner", applyButton).CornerRadius = UDim.new(0, 6)

local revertButton = Instance.new("TextButton")
revertButton.Size = UDim2.new(0.4, 0, 0, 20)
revertButton.Position = UDim2.new(0.55, 0, 0.78, 0)
revertButton.Text = "Revert"
revertButton.Font = Enum.Font.FredokaOne
revertButton.TextSize = 11
revertButton.BackgroundColor3 = Color3.fromRGB(170, 30, 30)
revertButton.TextColor3 = Color3.fromRGB(255, 255, 255)
revertButton.AutoButtonColor = true
revertButton.Parent = editorContent

Instance.new("UICorner", revertButton).CornerRadius = UDim.new(0, 6)

-- Apply Button Function
applyButton.MouseButton1Click:Connect(function()
   local newMessage = dialogMessageBox.Text
   if newMessage ~= "" then
       currentDialogMessage = newMessage
       -- Show confirmation
       local oldText = applyButton.Text
       applyButton.Text = "? Applied!"
       applyButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
       wait(1)
       applyButton.Text = oldText
       applyButton.BackgroundColor3 = Color3.fromRGB(30, 170, 80)
       print("Dialog message updated to: " .. currentDialogMessage)
   end
end)

-- Revert Button Function
revertButton.MouseButton1Click:Connect(function()
   currentDialogMessage = originalDialogMessage
   dialogMessageBox.Text = originalDialogMessage
   -- Show confirmation
   local oldText = revertButton.Text
   revertButton.Text = "? Reverted!"
   revertButton.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
   wait(1)
   revertButton.Text = oldText
   revertButton.BackgroundColor3 = Color3.fromRGB(170, 30, 30)
   print("Dialog message reverted to original")
end)

-- === PET LIST POPUP ===
local petListFrame = Instance.new("Frame")
petListFrame.Size = UDim2.new(0, 200, 0, 220)
petListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
petListFrame.Visible = false
petListFrame.ZIndex = 100
petListFrame.Parent = screenGui

Instance.new("UICorner", petListFrame).CornerRadius = UDim.new(0, 8)

local petListStroke = Instance.new("UIStroke", petListFrame)
petListStroke.Color = Color3.fromRGB(110, 0, 255)
petListStroke.Thickness = 2
petListStroke.Parent = petListFrame

local petListScroll = Instance.new("ScrollingFrame")
petListScroll.Size = UDim2.new(1, -10, 1, -10)
petListScroll.Position = UDim2.new(0, 5, 0, 5)
petListScroll.BackgroundTransparency = 1
petListScroll.ScrollBarThickness = 6
petListScroll.CanvasSize = UDim2.new(0, 0, 0, #petNames * 20 + 10)
petListScroll.BorderSizePixel = 0
petListScroll.ZIndex = 101
petListScroll.Parent = petListFrame

local petListLayout = Instance.new("UIListLayout")
petListLayout.Padding = UDim.new(0, 2)
petListLayout.SortOrder = Enum.SortOrder.LayoutOrder
petListLayout.Parent = petListScroll

for i, pet in ipairs(petNames) do
   local btn = Instance.new("TextButton")
   btn.Size = UDim2.new(1, -10, 0, 18)
   btn.Text = pet
   btn.Font = Enum.Font.FredokaOne
   btn.TextSize = 10
   btn.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
   btn.TextColor3 = Color3.fromRGB(215, 215, 255)
   btn.LayoutOrder = i
   btn.BorderSizePixel = 0
   btn.TextXAlignment = Enum.TextXAlignment.Left
   btn.TextTruncate = Enum.TextTruncate.None
   btn.AutoButtonColor = true
   btn.ZIndex = 102
   btn.Parent = petListScroll
   
   Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
   
   local textPadding = Instance.new("UIPadding")
   textPadding.PaddingLeft = UDim.new(0, 5)
   textPadding.PaddingRight = UDim.new(0, 5)
   textPadding.Parent = btn
   
   btn.MouseButton1Click:Connect(function()
       petNameBox.Text = pet
       petListFrame.Visible = false
   end)
end

-- === TOY LIST POPUP ===
local toyListFrame = Instance.new("Frame")
toyListFrame.Size = UDim2.new(0, 200, 0, 120)
toyListFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
toyListFrame.Visible = false
toyListFrame.ZIndex = 100
toyListFrame.Parent = screenGui

Instance.new("UICorner", toyListFrame).CornerRadius = UDim.new(0, 8)

local toyListStroke = Instance.new("UIStroke", toyListFrame)
toyListStroke.Color = Color3.fromRGB(255, 180, 0)
toyListStroke.Thickness = 2
toyListStroke.Parent = toyListFrame

local toyListScroll = Instance.new("ScrollingFrame")
toyListScroll.Size = UDim2.new(1, -10, 1, -10)
toyListScroll.Position = UDim2.new(0, 5, 0, 5)
toyListScroll.BackgroundTransparency = 1
toyListScroll.ScrollBarThickness = 6
toyListScroll.CanvasSize = UDim2.new(0, 0, 0, #toyNames * 20 + 10)
toyListScroll.BorderSizePixel = 0
toyListScroll.ZIndex = 101
toyListScroll.Parent = toyListFrame

local toyListLayout = Instance.new("UIListLayout")
toyListLayout.Padding = UDim.new(0, 2)
toyListLayout.SortOrder = Enum.SortOrder.LayoutOrder
toyListLayout.Parent = toyListScroll

for i, toy in ipairs(toyNames) do
   local btn = Instance.new("TextButton")
   btn.Size = UDim2.new(1, -10, 0, 18)
   btn.Text = toy
   btn.Font = Enum.Font.FredokaOne
   btn.TextSize = 10
   btn.BackgroundColor3 = Color3.fromRGB(80, 60, 40)
   btn.TextColor3 = Color3.fromRGB(255, 220, 180)
   btn.LayoutOrder = i
   btn.BorderSizePixel = 0
   btn.TextXAlignment = Enum.TextXAlignment.Left
   btn.TextTruncate = Enum.TextTruncate.None
   btn.AutoButtonColor = true
   btn.ZIndex = 102
   btn.Parent = toyListScroll
   
   Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
   
   local textPadding = Instance.new("UIPadding")
   textPadding.PaddingLeft = UDim.new(0, 5)
   textPadding.PaddingRight = UDim.new(0, 5)
   textPadding.Parent = btn
   
   btn.MouseButton1Click:Connect(function()
       toyNameBox.Text = toy
       selectedToy = toy
       toyListFrame.Visible = false
   end)
end

-- === UPDATE LIST POSITIONS ===
local function updatePetListPosition()
   if petListFrame.Visible then
       local mfPos = mainFrame.AbsolutePosition
       local mfSize = mainFrame.AbsoluteSize
       petListFrame.Position = UDim2.new(0, mfPos.X + mfSize.X + 5, 0, mfPos.Y + 70)
   end
end

local function updateToyListPosition()
   if toyListFrame.Visible then
       local mfPos = mainFrame.AbsolutePosition
       local mfSize = mainFrame.AbsoluteSize
       toyListFrame.Position = UDim2.new(0, mfPos.X + mfSize.X + 5, 0, mfPos.Y + 200)
   end
end

petListBtn.MouseButton1Click:Connect(function()
   petListFrame.Visible = not petListFrame.Visible
   toyListFrame.Visible = false
   if petListFrame.Visible then
       updatePetListPosition()
   end
end)

toyListBtn.MouseButton1Click:Connect(function()
   toyListFrame.Visible = not toyListFrame.Visible
   petListFrame.Visible = false
   if toyListFrame.Visible then
       updateToyListPosition()
   end
end)

mainFrame:GetPropertyChangedSignal("Position"):Connect(function()
   if petListFrame.Visible then
       updatePetListPosition()
   end
   if toyListFrame.Visible then
       updateToyListPosition()
   end
end)

-- === TAB FUNCTIONALITY ===
local function switchToTab(tabName)
   if tabName == "Main" then
       mainContent.Visible = true
       editorContent.Visible = false
       mainTab.BackgroundColor3 = Color3.fromRGB(70, 60, 100)
       editorTab.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
   elseif tabName == "Editor" then
       mainContent.Visible = false
       editorContent.Visible = true
       mainTab.BackgroundColor3 = Color3.fromRGB(50, 40, 80)
       editorTab.BackgroundColor3 = Color3.fromRGB(70, 60, 100)
   end
end

mainTab.MouseButton1Click:Connect(function()
   switchToTab("Main")
end)

editorTab.MouseButton1Click:Connect(function()
   switchToTab("Editor")
end)

-- Initialize with Main tab active
switchToTab("Main")

-- === RANDOM PET FUNCTION ===
randomPetBtn.MouseButton1Click:Connect(function()
   local randomIndex = math.random(1, #petNames)
   local randomPet = petNames[randomIndex]
   petNameBox.Text = randomPet
   
   local randomOption = math.random(1, 3)
   
   for _, prefix in ipairs(prefixes) do
       activeFlags[prefix] = false
   end
   
   if randomOption == 1 then
       activeFlags["M"] = true
   elseif randomOption == 2 then
       activeFlags["N"] = true
   end
   
   updateInfoBox()
end)

-- === ADD TO INVENTORY FUNCTION ===
local function addToInventory()
   local selectedPet = petNameBox.Text
   local selectedToyText = toyNameBox.Text
   
   if selectedPet == "" and selectedToyText == "" then
       -- Show error message
       local oldText = addToInventoryBtn.Text
       addToInventoryBtn.Text = "Select something!"
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
       wait(1)
       addToInventoryBtn.Text = oldText
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
       return
   end
   
   -- Load spawner system if not loaded
   if not spawnerSystemLoaded then
       loadSpawnerSystem()
       wait(0.5)
   end
   
   local oldIdentity = set_thread_identity(2)
   
   local success, err = pcall(function()
       local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
       local load = Fsys.load
       
       -- Add pet if selected
       if selectedPet ~= "" then
           -- Get pet ID
           local petId
           if _G.GetPetByName then
               petId = _G.GetPetByName(selectedPet)
           else
               local InventoryDB = load('InventoryDB')
               for id, pet in pairs(InventoryDB.pets) do
                   if pet.name:lower() == selectedPet:lower() then
                       petId = id
                       break
                   end
               end
           end
           
           if petId and _G.createPet then
               local petProperties = {
                   pet_trick_level = math.random(1, 5),
                   neon = activeFlags["N"],
                   mega_neon = activeFlags["M"],
                   rideable = activeFlags["R"],
                   flyable = activeFlags["F"],
                   age = math.random(1, 900000),
                   ailments_completed = 0,
                   rp_name = ""
               }
               _G.createPet(petId, petProperties)
               print("Added pet to inventory: " .. selectedPet)
           end
       end
       
       -- Add toy if selected
       if selectedToyText ~= "" then
           if _G.createToy then
               local toyProperties = {
                   durability = 100,
                   last_used = os.time()
               }
               _G.createToy(selectedToyText, toyProperties)
               print("Added toy to inventory: " .. selectedToyText)
           else
               -- Fallback method for toys
               local InventoryDB = load('InventoryDB')
               for id, toy in pairs(InventoryDB.toys) do
                   if toy.name:lower() == selectedToyText:lower() then
                       -- Use createPet function as fallback for toys
                       local toyProperties = {
                           durability = 100,
                           last_used = os.time()
                       }
                       _G.createPet(id, toyProperties)
                       print("Added toy to inventory (fallback): " .. selectedToyText)
                       break
                   end
               end
           end
       end
   end)
   
   set_thread_identity(oldIdentity)
   
   if success then
       -- Show success message
       local oldText = addToInventoryBtn.Text
       addToInventoryBtn.Text = "? Added!"
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(0, 200, 0)
       wait(1)
       addToInventoryBtn.Text = oldText
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
       
       print("Successfully added items to inventory!")
   else
       warn("Error adding to inventory:", err)
       local oldText = addToInventoryBtn.Text
       addToInventoryBtn.Text = "Error!"
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
       wait(1)
       addToInventoryBtn.Text = oldText
       addToInventoryBtn.BackgroundColor3 = Color3.fromRGB(0, 150, 80)
   end
end

addToInventoryBtn.MouseButton1Click:Connect(addToInventory)

-- === FIXED ULTRA-FAST SPAM FUNCTION (WITH PET ICONS) ===
local function ultraFastSpam()
   while spamActive do
       -- Ensure spawner system is loaded
       if not spawnerSystemLoaded then
           loadSpawnerSystem()
       end
       
       -- Use your dialog system directly with random values
       local oldIdentity = set_thread_identity(2)
       
       local success, err = pcall(function()
           local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
           local load = Fsys.load
           
           -- Random pet from list
           local randomPet = petNames[math.random(1, #petNames)]
           
           -- Get pet ID using the proper method
           local petId = false
           if _G.GetPetByName then
               petId = _G.GetPetByName(randomPet)
           end
           
           if not petId then
               -- Try alternative method
               local InventoryDB = load('InventoryDB')
               for id, pet in pairs(InventoryDB.pets) do
                   if pet.name:lower() == randomPet:lower() then
                       petId = id
                       break
                   end
               end
           end
           
           if petId then
               -- Random version pattern
               local versionPattern = math.random(1, 12)
               local neon = false
               local mega_neon = false
               local rideable = false
               local flyable = false
               
               if versionPattern == 1 then       -- MFR (Mega Neon, Flyable, Rideable)
                   mega_neon = true
                   flyable = true
                   rideable = true
               elseif versionPattern == 2 then   -- MR (Mega Neon, Rideable)
                   mega_neon = true
                   rideable = true
               elseif versionPattern == 3 then   -- MF (Mega Neon, Flyable)
                   mega_neon = true
                   flyable = true
               elseif versionPattern == 4 then   -- M (Mega Neon)
                   mega_neon = true
               elseif versionPattern == 5 then   -- NFR (Neon, Flyable, Rideable)
                   neon = true
                   flyable = true
                   rideable = true
               elseif versionPattern == 6 then   -- NF (Neon, Flyable)
                   neon = true
                   flyable = true
               elseif versionPattern == 7 then   -- NR (Neon, Rideable)
                   neon = true
                   rideable = true
               elseif versionPattern == 8 then   -- N (Neon)
                   neon = true
               elseif versionPattern == 9 then   -- FR (Flyable, Rideable)
                   flyable = true
                   rideable = true
               elseif versionPattern == 10 then  -- F (Flyable)
                   flyable = true
               elseif versionPattern == 11 then  -- R (Rideable)
                   rideable = true
               end
               -- versionPattern == 12 is Normal (No Pot)
               
               local petProperties = {
                   pet_trick_level = math.random(1, 5),
                   neon = neon,
                   mega_neon = mega_neon,
                   rideable = rideable,
                   flyable = flyable,
                   age = math.random(1, 900000),
                   ailments_completed = 0,
                   rp_name = ""
               }
               
               -- Load items database to get pet kind
               local items = load('KindDB')
               local petItem = items[petId]
               
               if not petItem then
                   set_thread_identity(oldIdentity)
                   RunService.Heartbeat:Wait()
                   return
               end
               
               -- Use game's dialog system (YOUR EXACT DIALOG) WITH CUSTOM MESSAGE AND PROPER ITEM DATA
               local UIManager = load('UIManager')
               local DialogApp = UIManager.apps.DialogApp
               
               if DialogApp and DialogApp.dialog then
                   local dialogParams = {
                       dialog_type = "ItemPreviewDialog",
                       text = currentDialogMessage .. randomPet, -- USING CUSTOM MESSAGE HERE
                       item = {
                           id = petId,
                           name = randomPet,
                           category = "pets",
                           kind = petItem.kind, -- IMPORTANT: This is needed for the icon
                           properties = petProperties
                       },
                       button = "Okay!",
                       yields = true
                   }
                   
                   -- Show the dialog
                   local response = DialogApp:dialog(dialogParams)
                   
                   if response == "Okay!" and _G.createPet then
                       _G.createPet(petId, petProperties)
                   end
               else
                   -- Fallback to alternative dialog method if DialogApp not available
                   local messageGui = Instance.new("ScreenGui")
                   messageGui.Name = "SpamDialog"
                   messageGui.ResetOnSpawn = false
                   messageGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
                   
                   local frame = Instance.new("Frame")
                   frame.Size = UDim2.new(0, 250, 0, 120)
                   frame.Position = UDim2.new(0.5, -125, 0.5, -60)
                   frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
                   frame.BackgroundTransparency = 0.1
                   frame.Parent = messageGui
                   
                   Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
                   
                   local label = Instance.new("TextLabel")
                   label.Size = UDim2.new(0.9, 0, 0.6, 0)
                   label.Position = UDim2.new(0.05, 0, 0.1, 0)
                   label.Text = currentDialogMessage .. randomPet
                   label.Font = Enum.Font.FredokaOne
                   label.TextSize = 12
                   label.TextColor3 = Color3.fromRGB(255, 255, 255)
                   label.BackgroundTransparency = 1
                   label.TextWrapped = true
                   label.Parent = frame
                   
                   local okButton = Instance.new("TextButton")
                   okButton.Size = UDim2.new(0.6, 0, 0.25, 0)
                   okButton.Position = UDim2.new(0.2, 0, 0.65, 0)
                   okButton.Text = "Okay!"
                   okButton.Font = Enum.Font.FredokaOne
                   okButton.TextSize = 12
                   okButton.BackgroundColor3 = Color3.fromRGB(30, 105, 210)
                   okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
                   okButton.AutoButtonColor = true
                   okButton.Parent = frame
                   
                   Instance.new("UICorner", okButton).CornerRadius = UDim.new(0, 6)
                   
                   okButton.MouseButton1Click:Connect(function()
                       messageGui:Destroy()
                       if _G.createPet then
                           _G.createPet(petId, petProperties)
                       end
                   end)
                   
                   -- Auto-remove after 0.5 seconds (fast spam)
                   task.delay(0.5, function()
                       if messageGui then
                           messageGui:Destroy()
                       end
                       if _G.createPet then
                           _G.createPet(petId, petProperties)
                       end
                   end)
               end
           end
       end)
       
       if not success then
           warn("Spam dialog error:", err)
       end
       
       set_thread_identity(oldIdentity)
       
       -- NO WAIT - SPAM AS FAST AS POSSIBLE
       -- This will spam dialogs instantly
       RunService.Heartbeat:Wait() -- Only wait one frame to prevent crashing
   end
end

-- === SPAM TOGGLE FUNCTION ===
spamToggle.MouseButton1Click:Connect(function()
   spamActive = not spamActive
   
   if spamActive then
       -- Ensure spawner system is loaded before starting spam
       if not spawnerSystemLoaded then
           loadSpawnerSystem()
           wait(0.5)
       end
       
       -- Turn ON
       TweenService:Create(spamToggle, TweenInfo.new(0.1), {
           BackgroundColor3 = Color3.fromRGB(0, 170, 0)
       }):Play()
       
       TweenService:Create(toggleCircle, TweenInfo.new(0.1), {
           Position = UDim2.new(0.53, 0, 0.15, 0)
       }):Play()
       
       spamLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
       spamStatus.Text = "Status: SPAMMING (Speed: 100+/sec)"
       spamStatus.TextColor3 = Color3.fromRGB(100, 255, 100)
       
       -- Start ULTRA-FAST spam loop
       spamCoroutine = task.spawn(ultraFastSpam)
       
       print("ULTRA-FAST SPAM ENABLED - Spamming at MAXIMUM SPEED!")
       print("Using custom dialog message: " .. currentDialogMessage)
       print("Pet icons should now load properly!")
   else
       -- Turn OFF
       TweenService:Create(spamToggle, TweenInfo.new(0.1), {
           BackgroundColor3 = Color3.fromRGB(80, 0, 0)
       }):Play()
       
       TweenService:Create(toggleCircle, TweenInfo.new(0.1), {
           Position = UDim2.new(0, 2, 0.15, 0)
       }):Play()
       
       spamLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
       spamStatus.Text = "Status: OFF (Speed: 100/sec)"
       spamStatus.TextColor3 = Color3.fromRGB(255, 100, 100)
       
       print("SPAM DISABLED")
   end
end)

-- === MODIFIED FIXED DIALOG FUNCTION FOR PETS (USES CUSTOM MESSAGE AND PROPER ITEM DATA) ===
local function showPetDialog()
   local selectedPet = petNameBox.Text
   if selectedPet == "" or selectedPet == "insert pet name" then
       return
   end
   
   -- Load spawner system if not loaded
   if not spawnerSystemLoaded then
       loadSpawnerSystem()
       wait(0.5) -- Give time to load
   end
   
   -- Use game's DialogApp with proper thread identity
   local oldIdentity = set_thread_identity(2)
   
   local success, result = pcall(function()
       local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
       local load = Fsys.load
       
       -- Get pet ID
       local petId
       if _G.GetPetByName then
           petId = _G.GetPetByName(selectedPet)
       else
           local InventoryDB = load('InventoryDB')
           for id, pet in pairs(InventoryDB.pets) do
               if pet.name:lower() == selectedPet:lower() then
                   petId = id
                   break
               end
           end
       end
       
       if not petId then
           return false
       end
       
       local items = load('KindDB')
       local petItemData = items[petId]
       
       if not petItemData then
           return false
       end
       
       local petProperties = {
           pet_trick_level = math.random(1, 5),
           neon = activeFlags["N"],
           mega_neon = activeFlags["M"],
           rideable = activeFlags["R"],
           flyable = activeFlags["F"],
           age = math.random(1, 900000),
           ailments_completed = 0,
           rp_name = ""
       }
       
       -- Use game's dialog system WITH CUSTOM MESSAGE AND PROPER ITEM DATA
       local UIManager = load('UIManager')
       local DialogApp = UIManager.apps.DialogApp
       
       if DialogApp and DialogApp.dialog then
           local response = DialogApp:dialog({
               dialog_type = "ItemPreviewDialog",
               text = currentDialogMessage .. selectedPet, -- USING CUSTOM MESSAGE HERE
               item = {
                   id = petId,
                   name = selectedPet,
                   category = "pets",
                   kind = petItemData.kind, -- IMPORTANT: This loads the pet icon
                   properties = petProperties
               },
               button = "Okay!",
               yields = true
           })
           
           if response == "Okay!" and _G.createPet then
               _G.createPet(petId, petProperties)
               return true
           end
       end
       
       return false
   end)
   
   set_thread_identity(oldIdentity)
   
   -- If game dialog failed, show simple message
   if not success or not result then
       -- Simple success message
       local messageGui = Instance.new("ScreenGui")
       messageGui.Name = "SuccessMessage"
       messageGui.ResetOnSpawn = false
       messageGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
       
       local frame = Instance.new("Frame")
       frame.Size = UDim2.new(0, 200, 0, 100)
       frame.Position = UDim2.new(0.5, -100, 0.5, -50)
       frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
       frame.BackgroundTransparency = 0.1
       frame.Parent = messageGui
       
       Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
       
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0.9, 0, 0.6, 0)
       label.Position = UDim2.new(0.05, 0, 0.1, 0)
       label.Text = "Pet Spawned: " .. selectedPet
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 14
       label.TextColor3 = Color3.fromRGB(255, 255, 255)
       label.BackgroundTransparency = 1
       label.Parent = frame
       
       local okButton = Instance.new("TextButton")
       okButton.Size = UDim2.new(0.6, 0, 0.25, 0)
       okButton.Position = UDim2.new(0.2, 0, 0.65, 0)
       okButton.Text = "Okay!"
       okButton.Font = Enum.Font.FredokaOne
       okButton.TextSize = 12
       okButton.BackgroundColor3 = Color3.fromRGB(30, 105, 210)
       okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
       okButton.AutoButtonColor = true
       okButton.Parent = frame
       
       Instance.new("UICorner", okButton).CornerRadius = UDim.new(0, 6)
       
       okButton.MouseButton1Click:Connect(function()
           messageGui:Destroy()
           if _G.createPet then
               local oldId = set_thread_identity(2)
               local InventoryDB = require(ReplicatedStorage:WaitForChild('Fsys')).load('InventoryDB')
               local petId
               for id, pet in pairs(InventoryDB.pets) do
                   if pet.name:lower() == selectedPet:lower() then
                       petId = id
                       break
                   end
               end
               
               if petId then
                   local petProperties = {
                       pet_trick_level = math.random(1, 5),
                       neon = activeFlags["N"],
                       mega_neon = activeFlags["M"],
                       rideable = activeFlags["R"],
                       flyable = activeFlags["F"],
                       age = math.random(1, 900000),
                       ailments_completed = 0,
                       rp_name = ""
                   }
                   _G.createPet(petId, petProperties)
               end
               set_thread_identity(oldId)
           end
       end)
       
       -- Auto-remove after 5 seconds
       task.delay(5, function()
           if messageGui then
               messageGui:Destroy()
           end
       end)
   end
end

-- === TOY DIALOG FUNCTION ===
local function showToyDialog()
   local selectedToyText = toyNameBox.Text
   if selectedToyText == "" or selectedToyText == "selected toy appears here" then
       return
   end
   
   -- Load spawner system if not loaded
   if not spawnerSystemLoaded then
       loadSpawnerSystem()
       wait(0.5) -- Give time to load
   end
   
   -- Use game's DialogApp with proper thread identity
   local oldIdentity = set_thread_identity(2)
   
   local success, result = pcall(function()
       local Fsys = require(ReplicatedStorage:WaitForChild('Fsys'))
       local load = Fsys.load
       
       -- Get toy ID
       local toyId
       if _G.GetToyByName then
           toyId = _G.GetToyByName(selectedToyText)
       else
           local InventoryDB = load('InventoryDB')
           for id, toy in pairs(InventoryDB.toys) do
               if toy.name:lower() == selectedToyText:lower() then
                   toyId = id
                   break
               end
           end
       end
       
       if not toyId then
           return false
       end
       
       local items = load('KindDB')
       local toyItemData = items[toyId]
       
       if not toyItemData then
           return false
       end
       
       local toyProperties = {
           durability = 100,
           last_used = os.time()
       }
       
       -- Use game's dialog system WITH CUSTOM MESSAGE AND PROPER ITEM DATA
       local UIManager = load('UIManager')
       local DialogApp = UIManager.apps.DialogApp
       
       if DialogApp and DialogApp.dialog then
           local response = DialogApp:dialog({
               dialog_type = "ItemPreviewDialog",
               text = currentDialogMessage .. selectedToyText, -- USING CUSTOM MESSAGE HERE
               item = {
                   id = toyId,
                   name = selectedToyText,
                   category = "toys",
                   kind = toyItemData.kind, -- IMPORTANT: This loads the toy icon
                   properties = toyProperties
               },
               button = "Okay!",
               yields = true
           })
           
           if response == "Okay!" and _G.createToy then
               _G.createToy(selectedToyText, toyProperties)
               return true
           elseif response == "Okay!" and _G.createPet then
               -- Fallback to pet creation if toy function doesn't exist
               _G.createPet(toyId, toyProperties)
               return true
           end
       end
       
       return false
   end)
   
   set_thread_identity(oldIdentity)
   
   -- If game dialog failed, show simple message
   if not success or not result then
       -- Simple success message
       local messageGui = Instance.new("ScreenGui")
       messageGui.Name = "ToySuccessMessage"
       messageGui.ResetOnSpawn = false
       messageGui.Parent = LocalPlayer:WaitForChild("PlayerGui")
       
       local frame = Instance.new("Frame")
       frame.Size = UDim2.new(0, 200, 0, 100)
       frame.Position = UDim2.new(0.5, -100, 0.5, -50)
       frame.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
       frame.BackgroundTransparency = 0.1
       frame.Parent = messageGui
       
       Instance.new("UICorner", frame).CornerRadius = UDim.new(0, 8)
       
       local label = Instance.new("TextLabel")
       label.Size = UDim2.new(0.9, 0, 0.6, 0)
       label.Position = UDim2.new(0.05, 0, 0.1, 0)
       label.Text = "Toy Spawned: " .. selectedToyText
       label.Font = Enum.Font.FredokaOne
       label.TextSize = 14
       label.TextColor3 = Color3.fromRGB(255, 255, 255)
       label.BackgroundTransparency = 1
       label.Parent = frame
       
       local okButton = Instance.new("TextButton")
       okButton.Size = UDim2.new(0.6, 0, 0.25, 0)
       okButton.Position = UDim2.new(0.2, 0, 0.65, 0)
       okButton.Text = "Okay!"
       okButton.Font = Enum.Font.FredokaOne
       okButton.TextSize = 12
       okButton.BackgroundColor3 = Color3.fromRGB(210, 105, 30) -- Orange color for toy
       okButton.TextColor3 = Color3.fromRGB(255, 255, 255)
       okButton.AutoButtonColor = true
       okButton.Parent = frame
       
       Instance.new("UICorner", okButton).CornerRadius = UDim.new(0, 6)
       
       okButton.MouseButton1Click:Connect(function()
           messageGui:Destroy()
           if _G.createToy then
               local oldId = set_thread_identity(2)
               local toyProperties = {
                   durability = 100,
                   last_used = os.time()
               }
               _G.createToy(selectedToyText, toyProperties)
               set_thread_identity(oldId)
           elseif _G.createPet then
               -- Fallback method
               local oldId = set_thread_identity(2)
               local InventoryDB = require(ReplicatedStorage:WaitForChild('Fsys')).load('InventoryDB')
               local toyId
               for id, toy in pairs(InventoryDB.toys) do
                   if toy.name:lower() == selectedToyText:lower() then
                       toyId = id
                       break
                   end
               end
               
               if toyId then
                   local toyProperties = {
                       durability = 100,
                       last_used = os.time()
                   }
                   _G.createPet(toyId, toyProperties)
               end
               set_thread_identity(oldId)
           end
       end)
       
       -- Auto-remove after 5 seconds
       task.delay(5, function()
           if messageGui then
               messageGui:Destroy()
           end
       end)
   end
end

-- Connect buttons to their functions
petDialogBtn.MouseButton1Click:Connect(showPetDialog)
toyDialogBtn.MouseButton1Click:Connect(showToyDialog)

-- === DRAGGABLE GUI ===
local dragging, dragStart, startPos

mainFrame.InputBegan:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 or 
      input.UserInputType == Enum.UserInputType.Touch then
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
   if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or 
                    input.UserInputType == Enum.UserInputType.Touch) then
       local delta = input.Position - dragStart
       mainFrame.Position = UDim2.new(
           startPos.X.Scale,
           startPos.X.Offset + delta.X,
           startPos.Y.Scale,
           startPos.Y.Offset + delta.Y
       )
   end
end)

-- Close popups when clicking outside
UserInputService.InputBegan:Connect(function(input)
   if input.UserInputType == Enum.UserInputType.MouseButton1 then
       local mousePos = input.Position
       
       -- Check pet list
       if petListFrame.Visible then
           local listAbsPos = petListFrame.AbsolutePosition
           local listSize = petListFrame.AbsoluteSize
           local mainAbsPos = mainFrame.AbsolutePosition
           local mainSize = mainFrame.AbsoluteSize
           
           local isInPetList = (mousePos.X >= listAbsPos.X and mousePos.X <= listAbsPos.X + listSize.X and
                               mousePos.Y >= listAbsPos.Y and mousePos.Y <= listAbsPos.Y + listSize.Y)
           
           local isInMainFrame = (mousePos.X >= mainAbsPos.X and mousePos.X <= mainAbsPos.X + mainSize.X and
                                 mousePos.Y >= mainAbsPos.Y and mousePos.Y <= mainAbsPos.Y + mainSize.Y)
           
           if not isInPetList and not isInMainFrame then
               petListFrame.Visible = false
           end
       end
       
       -- Check toy list
       if toyListFrame.Visible then
           local listAbsPos = toyListFrame.AbsolutePosition
           local listSize = toyListFrame.AbsoluteSize
           local mainAbsPos = mainFrame.AbsolutePosition
           local mainSize = mainFrame.AbsoluteSize
           
           local isInToyList = (mousePos.X >= listAbsPos.X and mousePos.X <= listAbsPos.X + listSize.X and
                               mousePos.Y >= listAbsPos.Y and mousePos.Y <= listAbsPos.Y + listSize.Y)
           
           local isInMainFrame = (mousePos.X >= mainAbsPos.X and mousePos.X <= mainAbsPos.X + mainSize.X and
                                 mousePos.Y >= mainAbsPos.Y and mousePos.Y <= mainAbsPos.Y + mainSize.Y)
           
           if not isInToyList and not isInMainFrame then
               toyListFrame.Visible = false
           end
       end
   end
end)

-- Auto-start spawner system
task.spawn(function()
   wait(1)
   loadSpawnerSystem()
   print("Spawner system loaded. Pet icons should work properly!")
   print("Toy system loaded: Rainbow Rattle, Candy Cannon, Witches Broomstick, Tombstone Ghostify")
   print("NEW: Added 'Show Toy Dialog' button with orange styling!")
end)

print("=" .. string.rep("=", 50))
print("ULTRA-FAST PET & TOY SPAWNER LOADED!")
print("Features:")
print("1. Show Pet Dialog (Blue button) - Spawns selected pet with dialog")
print("2. Show Toy Dialog (Orange button) - Spawns selected toy with dialog")
print("3. SPAM POP-UPS toggle - Spams ~100+ dialogs per second!")
print("4. All pet versions: MFR, MR, MF, M, NFR, NF, NR, N, FR, F, R, No Pot")
print("5. EDITOR TAB: Customize dialog messages with 4 presets!")
print("6. TOY SYSTEM: 4 premium toys with inventory support!")
print("=" .. string.rep("=", 50))
