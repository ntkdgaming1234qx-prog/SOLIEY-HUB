--[[
    HYDROGEN PRO V1 - IN-MENU SWITCH INTERCEPTOR

    Run this once while the old Hydrogen dashboard is open.
    It places an invisible click-catcher over the existing "HYDROGEN" dashboard
    button. Clicking that button opens a confirmation dialog. Only after SWITCH
    is confirmed does this script close the old hub UI/background and execute
    the Neon Background loader.

    The original dashboard button's action is intercepted and does not run.
]]

local NEON_LOADER_URL = "https://raw.githubusercontent.com/ntkdgaming1234qx-prog/SOLIEY-HUB/refs/heads/main/HYDROGEN_PRO_V1_Neon_Background.lua"

local Players = game:GetService("Players")
local CoreGui = game:GetService("CoreGui")
local LocalPlayer = Players.LocalPlayer

local env = _G
pcall(function()
    if type(getgenv) == "function" then
        local sharedEnv = getgenv()
        if type(sharedEnv) == "table" then env = sharedEnv end
    end
end)

if env.__HYDROGEN_INMENU_SWITCH_ACTIVE then
    warn("[HYDROGEN SWITCH] Switch button is already installed.")
    return
end
env.__HYDROGEN_INMENU_SWITCH_ACTIVE = true

local hosts, hostSet = {}, {}
local function addHost(obj)
    if obj and not hostSet[obj] then
        hostSet[obj] = true
        table.insert(hosts, obj)
    end
end

pcall(function() if type(gethui) == "function" then addHost(gethui()) end end)
pcall(function() addHost(CoreGui) end)
pcall(function()
    if LocalPlayer then addHost(LocalPlayer:FindFirstChildOfClass("PlayerGui")) end
end)

local function trim(s)
    return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalizedText(s)
    return trim(s):gsub("<[^>]->", ""):upper()
end

local function hasLayout(guiObject)
    return guiObject:FindFirstChildWhichIsA("UIListLayout")
        or guiObject:FindFirstChildWhichIsA("UIGridLayout")
        or guiObject:FindFirstChildWhichIsA("UIPageLayout")
        or guiObject:FindFirstChildWhichIsA("UITableLayout")
end

local function findButtonFromText(textObject)
    local p = textObject
    for _ = 1, 7 do
        if not p then break end
        if p:IsA("TextButton") or p:IsA("ImageButton") then
            return p
        end
        p = p.Parent
    end
    return nil
end

local function findTargetButton()
    local exactCandidates = {}
    for _, hostObject in ipairs(hosts) do
        local descendants = {}
        pcall(function() descendants = hostObject:GetDescendants() end)
        for _, obj in ipairs(descendants) do
            if obj:IsA("TextButton") and normalizedText(obj.Text) == "HYDROGEN" then
                table.insert(exactCandidates, obj)
            elseif obj:IsA("TextLabel") and normalizedText(obj.Text) == "HYDROGEN" then
                local button = findButtonFromText(obj)
                if button then table.insert(exactCandidates, button) end
            end
        end
    end

    local best, bestScore
    for _, button in ipairs(exactCandidates) do
        if button.Parent and button.Visible and button.AbsoluteSize.X >= 70 and button.AbsoluteSize.Y >= 22
            and button.AbsoluteSize.X <= 520 and button.AbsoluteSize.Y <= 160
            and not button:GetAttribute("HYDROGEN_SWITCH_INTERCEPTED") then
            local score = 0
            local size = button.AbsoluteSize
            -- The marked dashboard card in the reference image is a medium-width button.
            if size.X >= 90 and size.X <= 330 then score = score + 3 end
            if size.Y >= 30 and size.Y <= 100 then score = score + 2 end
            local screen = button:FindFirstAncestorOfClass("ScreenGui")
            if screen then
                local screenName = screen.Name:lower()
                if screenName:find("hydrogen", 1, true) or screenName:find("chilli", 1, true)
                    or screenName:find("venyx", 1, true) or screenName:find("soliey", 1, true) then
                    score = score + 4
                end
            end
            if not bestScore or score > bestScore then
                best, bestScore = button, score
            end
        end
    end
    return best
end

local function makeLabel(parent, name, text, position, size, fontSize, color, align)
    local label = Instance.new("TextLabel")
    label.Name = name
    label.BackgroundTransparency = 1
    label.Position = position
    label.Size = size
    label.Font = Enum.Font.GothamBold
    label.Text = text
    label.TextSize = fontSize
    label.TextColor3 = color
    label.TextWrapped = true
    label.TextXAlignment = align or Enum.TextXAlignment.Left
    label.Parent = parent
    return label
end

local function getNextDisplayOrder(container)
    local order = 1000
    pcall(function()
        for _, child in ipairs(container:GetChildren()) do
            if child:IsA("ScreenGui") then
                order = math.max(order, child.DisplayOrder + 1)
            end
        end
    end)
    return order + 100
end

local function makeSwitchPrompt(targetScreen, onConfirm)
    local prompt = Instance.new("ScreenGui")
    prompt.Name = "HydrogenSwitchPrompt"
    prompt.ResetOnSpawn = false
    if targetScreen then
        prompt.IgnoreGuiInset = targetScreen.IgnoreGuiInset
    else
        prompt.IgnoreGuiInset = true
    end
    prompt.DisplayOrder = getNextDisplayOrder((targetScreen and targetScreen.Parent) or hosts[1])
    prompt.ZIndexBehavior = Enum.ZIndexBehavior.Global
    prompt.Parent = (targetScreen and targetScreen.Parent) or hosts[1]

    local shade = Instance.new("Frame")
    shade.Name = "DimBackground"
    shade.Size = UDim2.fromScale(1, 1)
    shade.BackgroundColor3 = Color3.fromRGB(3, 2, 10)
    shade.BackgroundTransparency = 0.30
    shade.BorderSizePixel = 0
    shade.Active = true
    shade.Parent = prompt

    local card = Instance.new("Frame")
    card.Name = "ConfirmCard"
    card.AnchorPoint = Vector2.new(0.5, 0.5)
    card.Position = UDim2.fromScale(0.5, 0.5)
    card.Size = UDim2.new(0.88, 0, 0, 218)
    card.BackgroundColor3 = Color3.fromRGB(12, 7, 24)
    card.BackgroundTransparency = 0.02
    card.BorderSizePixel = 0
    card.Parent = shade
    local constraint = Instance.new("UISizeConstraint")
    constraint.MinSize = Vector2.new(275, 218)
    constraint.MaxSize = Vector2.new(410, 218)
    constraint.Parent = card
    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0, 15)
    corner.Parent = card
    local stroke = Instance.new("UIStroke")
    stroke.Color = Color3.fromRGB(192, 75, 255)
    stroke.Thickness = 2.5
    stroke.Parent = card
    local gradient = Instance.new("UIGradient")
    gradient.Color = ColorSequence.new({
        ColorSequenceKeypoint.new(0, Color3.fromRGB(31, 8, 68)),
        ColorSequenceKeypoint.new(0.5, Color3.fromRGB(9, 5, 20)),
        ColorSequenceKeypoint.new(1, Color3.fromRGB(36, 5, 48)),
    })
    gradient.Rotation = 15
    gradient.Parent = card

    makeLabel(card, "Title", "CONFIRM SWITCH", UDim2.new(0, 22, 0, 18), UDim2.new(1, -44, 0, 34), 20, Color3.fromRGB(250, 243, 255))
    makeLabel(card, "Description",
        "Menu cũ và background sẽ được tắt hoàn toàn trước khi mở HYDROGEN PRO V1 mới.",
        UDim2.new(0, 23, 0, 67), UDim2.new(1, -46, 0, 66), 14, Color3.fromRGB(219, 211, 235))

    local cancel = Instance.new("TextButton")
    cancel.Name = "CancelButton"
    cancel.Position = UDim2.new(0, 22, 1, -58)
    cancel.Size = UDim2.new(0.42, -9, 0, 40)
    cancel.BackgroundColor3 = Color3.fromRGB(38, 29, 54)
    cancel.BorderSizePixel = 0
    cancel.AutoButtonColor = true
    cancel.Font = Enum.Font.GothamBold
    cancel.Text = "CANCEL"
    cancel.TextSize = 14
    cancel.TextColor3 = Color3.fromRGB(231, 222, 244)
    cancel.Parent = card
    local cancelCorner = Instance.new("UICorner")
    cancelCorner.CornerRadius = UDim.new(0, 8)
    cancelCorner.Parent = cancel

    local confirm = Instance.new("TextButton")
    confirm.Name = "SwitchButton"
    confirm.Position = UDim2.new(0.42, 8, 1, -58)
    confirm.Size = UDim2.new(0.58, -30, 0, 40)
    confirm.BackgroundColor3 = Color3.fromRGB(111, 26, 196)
    confirm.BorderSizePixel = 0
    confirm.AutoButtonColor = true
    confirm.Font = Enum.Font.GothamBlack
    confirm.Text = "SWITCH"
    confirm.TextSize = 15
    confirm.TextColor3 = Color3.fromRGB(255, 255, 255)
    confirm.Parent = card
    local confirmCorner = Instance.new("UICorner")
    confirmCorner.CornerRadius = UDim.new(0, 8)
    confirmCorner.Parent = confirm
    local confirmStroke = Instance.new("UIStroke")
    confirmStroke.Color = Color3.fromRGB(225, 112, 255)
    confirmStroke.Thickness = 1.5
    confirmStroke.Parent = confirm

    local busy = false
    cancel.Activated:Connect(function()
        if busy then return end
        prompt:Destroy()
    end)
    confirm.Activated:Connect(function()
        if busy then return end
        busy = true
        confirm.Text = "SWITCHING..."
        confirm.Active = false
        cancel.Active = false
        task.spawn(onConfirm, prompt)
    end)
    return prompt
end

local function isHubScreen(screen, targetScreen)
    if not screen or not screen:IsA("ScreenGui") then return false end
    if screen.Name == "HydrogenSwitchOverlay" or screen.Name == "HydrogenSwitchPrompt" then return false end
    if screen == targetScreen then return true end

    local name = screen.Name:lower()
    if name:find("chilli", 1, true) or name:find("venyx", 1, true)
        or name:find("hydrogen", 1, true) or name:find("soliey", 1, true) then
        return true
    end

    local descendants = {}
    pcall(function() descendants = screen:GetDescendants() end)
    for _, item in ipairs(descendants) do
        if item:GetAttribute("HYD_main") or item:GetAttribute("HYD_title")
            or item:GetAttribute("HYD_vhid") or item:GetAttribute("HYD_background") then
            return true
        end
        local n = item.Name:lower()
        if n == "hydrogen_background" or n == "hydrogenbackground" or n == "hyd_bg" then
            return true
        end
    end
    return false
end

local function closeOldHub(targetScreen)
    local removed = 0
    for _, container in ipairs(hosts) do
        local children = {}
        pcall(function() children = container:GetChildren() end)
        for _, child in ipairs(children) do
            if isHubScreen(child, targetScreen) then
                pcall(function()
                    child.Enabled = false
                    child:Destroy()
                end)
                removed = removed + 1
            end
        end
    end

    -- Also remove marked background layers that may be sibling GUI objects.
    for _, container in ipairs(hosts) do
        local descendants = {}
        pcall(function() descendants = container:GetDescendants() end)
        for _, item in ipairs(descendants) do
            local name = item.Name:lower()
            if item:GetAttribute("HYD_background") or name == "hydrogen_background"
                or name == "hydrogenbackground" or name == "hyd_bg" then
                pcall(function() item:Destroy() end)
            end
        end
    end
    print("[HYDROGEN SWITCH] closed old hub ScreenGui count: " .. tostring(removed))
end

local function runNeonLoader()
    local ok, result = pcall(function()
        local source = game:HttpGet(NEON_LOADER_URL)
        if type(source) ~= "string" or #source < 1000 then
            error("Neon loader source is empty or too short")
        end
        local compiler = loadstring or load
        if type(compiler) ~= "function" then
            error("This environment does not provide loadstring/load")
        end
        local chunk, compileError = compiler(source)
        if not chunk then error(compileError or "Lua compile failed") end
        chunk()
    end)
    if not ok then
        warn("[HYDROGEN SWITCH] Could not start Neon loader: " .. tostring(result))
    end
end

local function installInterceptor(target)
    local targetScreen = target:FindFirstAncestorOfClass("ScreenGui")
    local container = (targetScreen and targetScreen.Parent) or hosts[1]
    if not container then return false end

    local overlay = Instance.new("ScreenGui")
    overlay.Name = "HydrogenSwitchOverlay"
    overlay.ResetOnSpawn = false
    if targetScreen then
        overlay.IgnoreGuiInset = targetScreen.IgnoreGuiInset
    else
        overlay.IgnoreGuiInset = true
    end
    overlay.DisplayOrder = getNextDisplayOrder(container)
    overlay.ZIndexBehavior = Enum.ZIndexBehavior.Global
    overlay.Parent = container

    local catcher = Instance.new("TextButton")
    catcher.Name = "HydrogenSwitchClickCatcher"
    catcher.BackgroundTransparency = 1
    catcher.BorderSizePixel = 0
    catcher.AutoButtonColor = false
    catcher.Text = ""
    catcher.Active = true
    catcher.AnchorPoint = Vector2.new(0, 0)
    catcher.ZIndex = 10000
    catcher.Parent = overlay

    local function sync()
        if not target.Parent or not overlay.Parent then return end
        local pos = target.AbsolutePosition
        local size = target.AbsoluteSize
        catcher.Position = UDim2.fromOffset(pos.X, pos.Y)
        catcher.Size = UDim2.fromOffset(size.X, size.Y)
        catcher.Visible = target.Visible and size.X > 0 and size.Y > 0
    end
    sync()
    target:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync)
    target:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
    target:GetPropertyChangedSignal("Visible"):Connect(sync)
    target.AncestryChanged:Connect(function(_, parent)
        if not parent and overlay.Parent then overlay:Destroy() end
    end)

    local promptOpen = false
    catcher.Activated:Connect(function()
        if promptOpen or not target.Parent then return end
        promptOpen = true
        local prompt
        prompt = makeSwitchPrompt(targetScreen, function(promptGui)
            closeOldHub(targetScreen)
            task.wait(0.25)
            if promptGui and promptGui.Parent then promptGui:Destroy() end
            if overlay and overlay.Parent then overlay:Destroy() end
            task.wait(0.1)
            runNeonLoader()
        end)
        prompt.Destroying:Connect(function() promptOpen = false end)
    end)

    target:SetAttribute("HYDROGEN_SWITCH_INTERCEPTED", true)
    print("[HYDROGEN SWITCH] Interceptor installed on the existing HYDROGEN dashboard button.")
    return true
end

-- Wait for the existing dashboard control to finish rendering, then cover only that button.
task.spawn(function()
    local startedAt = os.clock()
    while os.clock() - startedAt < 240 do
        local target = findTargetButton()
        if target and installInterceptor(target) then
            return
        end
        task.wait(0.5)
    end
    env.__HYDROGEN_INMENU_SWITCH_ACTIVE = nil
    warn("[HYDROGEN SWITCH] Could not find a visible button whose text is exactly 'HYDROGEN'. No menu was changed.")
end)
