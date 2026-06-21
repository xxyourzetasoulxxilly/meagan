-- ULTRA-FAST Player Blocker Script - Instant Block
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

-- Configuration
local PLAYER_BLOCKER_CONFIG = {
    BLOCK_KEYWORDS = {
        "free", "hack", "cheat", "exploit", "SCAMMER", "scammed", "toook","SCAM","scammer","scam"
    },
    GUI_POSITION = UDim2.new(0, 10, 0, 50),
    AUTO_BLOCK_ENABLED = true
}

-- State
local playerBlockerState = {
    blockedPlayers = {}
}

-- Use your existing BlockPlayer function
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

-- Create the GUI
local PlayerBlockerGUI = Instance.new("ScreenGui")
PlayerBlockerGUI.Name = "PlayerBlockerGUI"
PlayerBlockerGUI.ResetOnSpawn = false
PlayerBlockerGUI.ZIndexBehavior = Enum.ZIndexBehavior.Sibling

local MainFrame = Instance.new("Frame")
MainFrame.Size = UDim2.new(0, 300, 0, 200)
MainFrame.Position = PLAYER_BLOCKER_CONFIG.GUI_POSITION
MainFrame.BackgroundColor3 = Color3.fromRGB(30, 30, 40)
MainFrame.BorderSizePixel = 0
MainFrame.Parent = PlayerBlockerGUI

local Corner = Instance.new("UICorner")
Corner.CornerRadius = UDim.new(0, 8)
Corner.Parent = MainFrame

local Stroke = Instance.new("UIStroke")
Stroke.Color = Color3.fromRGB(100, 100, 255)
Stroke.Thickness = 2
Stroke.Parent = MainFrame

-- Title
local Title = Instance.new("TextLabel")
Title.Size = UDim2.new(1, 0, 0, 40)
Title.Position = UDim2.new(0, 0, 0, 0)
Title.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
Title.BackgroundTransparency = 0
Title.Text = "ZetaScripts(last4zeta on tt)"
Title.Font = Enum.Font.FredokaOne
Title.TextSize = 18
Title.TextColor3 = Color3.fromRGB(255, 255, 255)
Title.Parent = MainFrame

local TitleCorner = Instance.new("UICorner")
TitleCorner.CornerRadius = UDim.new(0, 8)
TitleCorner.Parent = Title

-- Status Section
local StatusSection = Instance.new("Frame")
StatusSection.Size = UDim2.new(1, -20, 0, 80)
StatusSection.Position = UDim2.new(0, 10, 0, 50)
StatusSection.BackgroundTransparency = 1
StatusSection.Parent = MainFrame

local StatusLabel = Instance.new("TextLabel")
StatusLabel.Size = UDim2.new(1, 0, 0, 20)
StatusLabel.Position = UDim2.new(0, 0, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: 🟢 ACTIVE"
StatusLabel.Font = Enum.Font.SourceSansSemibold
StatusLabel.TextSize = 14
StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Left
StatusLabel.Parent = StatusSection

local BlockedLabel = Instance.new("TextLabel")
BlockedLabel.Size = UDim2.new(1, 0, 0, 20)
BlockedLabel.Position = UDim2.new(0, 0, 0, 25)
BlockedLabel.BackgroundTransparency = 1
BlockedLabel.Text = "Blocked: 0"
StatusLabel.Font = Enum.Font.SourceSansSemibold
BlockedLabel.TextSize = 14
BlockedLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
BlockedLabel.TextXAlignment = Enum.TextXAlignment.Left
BlockedLabel.Parent = StatusSection

local LastBlockLabel = Instance.new("TextLabel")
LastBlockLabel.Size = UDim2.new(1, 0, 0, 20)
LastBlockLabel.Position = UDim2.new(0, 0, 0, 50)
LastBlockLabel.BackgroundTransparency = 1
LastBlockLabel.Text = "Last: None"
LastBlockLabel.Font = Enum.Font.SourceSans
LastBlockLabel.TextSize = 12
LastBlockLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
LastBlockLabel.TextXAlignment = Enum.TextXAlignment.Left
LastBlockLabel.Parent = StatusSection

-- Toggle Section
local ToggleSection = Instance.new("Frame")
ToggleSection.Size = UDim2.new(1, -20, 0, 40)
ToggleSection.Position = UDim2.new(0, 10, 0, 140)
ToggleSection.BackgroundTransparency = 1
ToggleSection.Parent = MainFrame

local ToggleButton = Instance.new("TextButton")
ToggleButton.Size = UDim2.new(1, 0, 1, 0)
ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
ToggleButton.BackgroundTransparency = 0
ToggleButton.Text = "🟢 INSTANT BLOCK: ON"
ToggleButton.Font = Enum.Font.FredokaOne
ToggleButton.TextSize = 14
ToggleButton.TextColor3 = Color3.fromRGB(255, 255, 255)
ToggleButton.Parent = ToggleSection

local ToggleCorner = Instance.new("UICorner")
ToggleCorner.CornerRadius = UDim.new(0, 6)
ToggleCorner.Parent = ToggleButton

-- Ultra-Fast Blocking Functions
local blockedCount = 0
local lastBlockedPlayer = "None"

local function updateStats()
    BlockedLabel.Text = "Blocked: " .. blockedCount
    LastBlockLabel.Text = "Last: " .. lastBlockedPlayer
end

-- Simple detection that checks if letters can form keywords
local function canSpellKeyword(text, keyword)
    local lowerText = string.lower(text)
    local lowerKeyword = string.lower(keyword)
    
    -- Count letters in the text
    local textCount = {}
    for i = 1, #lowerText do
        local char = string.sub(lowerText, i, i)
        if string.match(char, "%a") then -- Only count letters
            textCount[char] = (textCount[char] or 0) + 1
        end
    end
    
    -- Count letters needed for keyword
    local keywordCount = {}
    for i = 1, #lowerKeyword do
        local char = string.sub(lowerKeyword, i, i)
        keywordCount[char] = (keywordCount[char] or 0) + 1
    end
    
    -- Check if text has enough of each letter to spell the keyword
    for char, needed in pairs(keywordCount) do
        if (textCount[char] or 0) < needed then
            return false
        end
    end
    
    return true
end

local function containsKeyword(message, keywords)
    for _, keyword in ipairs(keywords) do
        if canSpellKeyword(message, keyword) then
            return true, keyword
        end
    end
    return false, nil
end

-- ULTRA-FAST BLOCK FUNCTION - No delays, instant execution
local function instantBlockPlayer(player, keyword, message)
    if not player then
        return false
    end
    
    -- INSTANT BLOCK - No waiting, no delays
    pcall(function()
        BlockPlayer(player)
    end)
    
    -- Update stats immediately
    blockedCount = blockedCount + 1
    lastBlockedPlayer = player.Name
    updateStats()
    
    -- Instant console notification
    print("⚡ INSTANT BLOCK: " .. player.Name .. " for: " .. keyword)
    print("📝 Original message: " .. message)
    
    return true
end

-- ULTRA-FAST Chat Detection - Minimal processing
local function onPlayerChatted(player, message)
    -- Skip if player is yourself or blocking is off
    if player == Players.LocalPlayer or ToggleButton.Text:find("OFF") then
        return
    end
    
    -- Ultra-fast keyword check
    local hasKeyword, foundKeyword = containsKeyword(message, PLAYER_BLOCKER_CONFIG.BLOCK_KEYWORDS)
    if hasKeyword then
        -- INSTANT BLOCK - No delays, no waiting
        instantBlockPlayer(player, foundKeyword, message)
    end
end

-- Toggle Button Event
ToggleButton.MouseButton1Click:Connect(function()
    if ToggleButton.Text:find("ON") then
        ToggleButton.Text = "🔴 INSTANT BLOCK: OFF"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(200, 60, 60)
        StatusLabel.Text = "Status: 🔴 INACTIVE"
        StatusLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
        print("❌ Instant blocking DISABLED")
    else
        ToggleButton.Text = "🟢 INSTANT BLOCK: ON"
        ToggleButton.BackgroundColor3 = Color3.fromRGB(60, 200, 60)
        StatusLabel.Text = "Status: 🟢 ACTIVE"
        StatusLabel.TextColor3 = Color3.fromRGB(100, 255, 100)
        print("✅ Instant blocking ENABLED")
    end
end)

-- ULTRA-FAST Chat Monitoring - No unnecessary processing
local function monitorChat()
    -- Monitor existing players - ULTRA FAST
    for i, player in pairs(Players:GetPlayers()) do
        player.Chatted:Connect(function(msg)
            onPlayerChatted(player, msg)
        end)
    end
    
    -- Monitor new players - ULTRA FAST
    Players.PlayerAdded:Connect(function(player)
        player.Chatted:Connect(function(msg)
            onPlayerChatted(player, msg)
        end)
    end)
end

-- Initialize - FAST STARTUP
PlayerBlockerGUI.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
monitorChat()
updateStats()

print("⚡ ULTRA-FAST Instant Blocker LOADED!")
print("✅ Keywords: " .. table.concat(PLAYER_BLOCKER_CONFIG.BLOCK_KEYWORDS, ", "))
print("🚀 Players will be INSTANTLY blocked when they say keywords!")
print("🛡️ Advanced detection active - detects any text that can spell keywords!")

-- Drag functionality
local dragging = false
local dragStart, startPos

Title.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = true
        dragStart = input.Position
        startPos = MainFrame.Position
    end
end)

UserInputService.InputChanged:Connect(function(input)
    if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - dragStart
        MainFrame.Position = UDim2.new(
            startPos.X.Scale,
            startPos.X.Offset + delta.X,
            startPos.Y.Scale,
            startPos.Y.Offset + delta.Y
        )
    end
end)

UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        dragging = false
    end
end)
