--[[
    HYDROGEN V1 - ALL-IN-ONE FIXED V2
    Tải file gốc HYDROGEN_V1_ALL_IN_ONE_FIXED.lua (giữ nguyên trên GitHub, KHÔNG ghi đè), sửa code của nó
    trong bộ nhớ rồi chạy. Ảnh nhúng (logo + nền) vẫn lấy từ file gốc nên không cần dán lại.

    Thay đổi so với bản gốc:
      1) Nút nổi "HYDROGEN PRO" phủ kín nút "HYDROGEN" dưới khung Discord.
         Bấm vào -> popup tiếng Anh "Do you want to change to another hub?" với 2 nút SWITCH / CANCEL.
         SWITCH -> chạy HydrogenSwitch.lua (đóng hub hiện tại trước, như bản gốc). CANCEL -> đóng popup.
      2) Sửa lỗi nền của menu 1 bị dính sang menu 2 (menu đỏ cổ điển) và che nửa màn hình:
         - nhận diện menu cổ điển bằng cả tên tab (Farm/Event/Player/Predictor/Server/Misc/Auto Hop) lẫn màu đỏ,
           không còn bị "khoá" sai 2 giây sau lần kiểm tra đầu;
         - bất kỳ lớp nền HYDROGEN_BG / HYD_Darken nào lọt vào menu cổ điển đều bị xoá ngay;
         - cửa sổ chính bị chọn nhầm nằm trong menu cổ điển sẽ bị bỏ chọn.
]]

local ORIGINAL = "https://raw.githubusercontent.com/ntkdgaming1234qx-prog/SOLIEY-HUB/refs/heads/main/HYDROGEN_V1_ALL_IN_ONE_FIXED.lua"

local ok, src = pcall(function() return game:HttpGet(ORIGINAL) end)
if not ok or type(src) ~= "string" or #src < 1000 then
    warn("[HYDROGEN V2] không tải được file gốc:", src)
    return
end

-- thay đoạn nằm giữa hai mốc (mốc ở dạng chuỗi thường, không dùng pattern)
local function between(s, a, b, replacement, label)
    local i = s:find(a, 1, true)
    local j = i and s:find(b, i + #a, 1, true)
    if not (i and j) then
        warn("[HYDROGEN V2] không áp dụng được bản vá: " .. label)
        return s
    end
    return s:sub(1, i - 1) .. replacement .. s:sub(j)
end

local function replaceOnce(s, a, b, label)
    local i, j = s:find(a, 1, true)
    if not i then
        warn("[HYDROGEN V2] không áp dụng được bản vá: " .. label)
        return s
    end
    return s:sub(1, i - 1) .. b .. s:sub(j + 1)
end

-- ============ BẢN VÁ A: nhận diện menu cổ điển + dọn nền bị dính sang menu 2 ============
local PATCH_A = [====[
local CLASSIC_WORDS = {
    ["farm"] = true, ["event"] = true, ["player"] = true, ["predictor"] = true,
    ["server"] = true, ["misc"] = true, ["auto hop"] = true,
}

-- xoá mọi lớp nền của menu 1 nằm trong ScreenGui `g` (dùng cho menu cổ điển)
local function purgeStrayBackground(g)
    for _, d in ipairs(g:GetDescendants()) do
        if d:GetAttribute("HYD_background") or d.Name == "HYDROGEN_BG" or d.Name == "HYD_Darken" then
            pcall(function() d:Destroy() end)
        end
    end
    -- cửa sổ chính bị chọn nhầm nằm trong menu cổ điển -> bỏ chọn để lần quét sau tìm lại đúng cửa sổ
    if mainWindow and (mainWindow == g or mainWindow:IsDescendantOf(g)) then
        mainWindow = nil
    end
end

local function countClassicWords(g)
    local seen, n = {}, 0
    for _, d in ipairs(g:GetDescendants()) do
        if (d:IsA("TextButton") or d:IsA("TextLabel")) and not d:GetAttribute("HYD_skip") then
            local t = plain(d.Text):lower()
            if CLASSIC_WORDS[t] and not seen[t] and d.AbsoluteSize.X >= 40 then
                seen[t] = true
                n = n + 1
            end
        end
    end
    return n
end

local function isClassicGui(g)
    if classicSet[g] then return true end
    local ownMain = mainWindow and mainWindow.Parent and g == mainWindow:FindFirstAncestorOfClass("ScreenGui")
    local t = classicChecked[g]
    if t and os.clock() - t < (ownMain and 3 or 1) then return false end
    classicChecked[g] = os.clock()

    local flagged = countClassicWords(g) >= 5
    if not flagged and not ownMain then
        local n = 0
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
                local s = d.AbsoluteSize
                local red = false
                if s.X >= 80 and s.Y >= 24 then
                    if d.BackgroundTransparency < 0.5 and isRedColor(d.BackgroundColor3) then
                        red = true
                    elseif (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.ImageTransparency < 0.5 and isRedColor(d.ImageColor3) then
                        red = true
                    end
                end
                if red then
                    n = n + 1
                    if n >= 4 then
                        flagged = true
                        break
                    end
                end
            end
        end
    end

    if flagged then
        classicSet[g] = true
        g:SetAttribute("HYD_classic", true)
        purgeStrayBackground(g)
        return true
    end
    return false
end

]====]

-- ============ BẢN VÁ B: nút nổi HYDROGEN PRO + popup xác nhận ============
local PATCH_B = [====[
local confirmGui

local function closeConfirm()
    if confirmGui then pcall(function() confirmGui:Destroy() end) end
    confirmGui = nil
end

local function showHubConfirm()
    if STOPPED or switchRunning or (confirmGui and confirmGui.Parent) then return end
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    parent = parent or CoreGui

    local g = Instance.new("ScreenGui")
    g.Name = "SW_ConfirmHub" .. tostring(math.random(1000, 9999))
    g.ResetOnSpawn = false
    g.DisplayOrder = 1000000
    g.IgnoreGuiInset = true
    g.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    g:SetAttribute("HYD_skip", true)
    existing[g] = true                                   -- không coi là GUI của hub
    g.Parent = parent
    confirmGui = g

    -- lớp tối phủ màn hình: chặn bấm xuyên xuống menu phía sau
    mk("TextButton", {
        Name = "Dim", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 0.45, BorderSizePixel = 0, Text = "", AutoButtonColor = false, ZIndex = 1,
    }, g)

    local box = mk("Frame", {
        Name = "Box", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0),
        Size = UDim2.new(0, 330, 0, 168), BackgroundColor3 = Color3.fromRGB(14, 8, 26),
        BorderSizePixel = 0, Active = true, ZIndex = 2,
    }, g)
    mk("UICorner", { CornerRadius = UDim.new(0, 14) }, box)
    mk("UIStroke", { Color = Color3.fromRGB(176, 96, 255), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)

    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 12), Size = UDim2.new(1, -32, 0, 20),
        Font = Enum.Font.GothamBold, TextSize = 14, TextColor3 = Color3.fromRGB(240, 130, 255),
        TextXAlignment = Enum.TextXAlignment.Left, Text = "HYDROGEN PRO", ZIndex = 3,
    }, box)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 16, 0, 40), Size = UDim2.new(1, -32, 0, 56),
        Font = Enum.Font.GothamMedium, TextSize = 17, TextColor3 = Color3.new(1, 1, 1), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Center, TextYAlignment = Enum.TextYAlignment.Center,
        Text = "Do you want to change to another hub?", ZIndex = 3,
    }, box)

    local sw = mk("TextButton", {
        Name = "Switch", Position = UDim2.new(0, 16, 1, -58), Size = UDim2.new(0.5, -22, 0, 42),
        BackgroundColor3 = Color3.fromRGB(122, 54, 218), BorderSizePixel = 0, AutoButtonColor = true,
        Font = Enum.Font.GothamBold, TextSize = 15, TextColor3 = Color3.new(1, 1, 1), Text = "SWITCH", ZIndex = 3,
    }, box)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, sw)

    local cancel = mk("TextButton", {
        Name = "Cancel", AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -16, 1, -58),
        Size = UDim2.new(0.5, -22, 0, 42), BackgroundColor3 = Color3.fromRGB(34, 22, 52), BorderSizePixel = 0,
        AutoButtonColor = true, Font = Enum.Font.GothamBold, TextSize = 15,
        TextColor3 = Color3.fromRGB(215, 200, 240), Text = "CANCEL", ZIndex = 3,
    }, box)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, cancel)
    mk("UIStroke", { Color = Color3.fromRGB(110, 70, 170), Thickness = 1.2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, cancel)

    sw.Activated:Connect(function()
        closeConfirm()
        runSwitchScript()                                -- tải HydrogenSwitch.lua, đóng hub hiện tại rồi chạy
    end)
    cancel.Activated:Connect(closeConfirm)               -- huỷ: chỉ đóng popup
end

-- Nút nổi "HYDROGEN PRO": nằm trong nút "HYDROGEN" cũ, đặc và phủ kín nên che hẳn nút cũ.
-- Vì là nút con ở lớp cao hơn nên cú bấm không lọt xuống nút cũ (menu đỏ không còn tự mở).
local function createHydrogenOverlay(textObj, target)
    if not target or not target:IsA("GuiButton") then return false end
    if target:GetAttribute("HYD_overlay_ready") then return true end
    local gui = target:FindFirstAncestorOfClass("ScreenGui")
    if gui and gui:GetAttribute("HYD_classic") then return false end    -- không gắn vào menu cổ điển

    local topZ = target.ZIndex
    for _, child in ipairs(target:GetDescendants()) do
        if child:IsA("GuiObject") then topZ = math.max(topZ, child.ZIndex) end
    end
    local srcCorner = target:FindFirstChildOfClass("UICorner")

    local overlay = mk("TextButton", {
        Name = "HYDROGEN_PRO_Overlay", Position = UDim2.new(0, 0, 0, 0), Size = UDim2.new(1, 0, 1, 0),
        BackgroundColor3 = Color3.fromRGB(34, 12, 66), BackgroundTransparency = 0, BorderSizePixel = 0,
        AutoButtonColor = false, Active = true, Selectable = true, Text = "HYDROGEN PRO",
        Font = Enum.Font.GothamBold, TextSize = 13, TextScaled = true,
        TextColor3 = Color3.fromRGB(245, 225, 255), ZIndex = topZ + 20, ClipsDescendants = true,
    }, target)
    mk("UICorner", { CornerRadius = srcCorner and srcCorner.CornerRadius or UDim.new(0, 10) }, overlay)
    mk("UIStroke", { Color = CONFIG.TAB_NEON, Thickness = 1.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, overlay)
    mk("UITextSizeConstraint", { MaxTextSize = 14, MinTextSize = 8 }, overlay)
    mk("UIPadding", { PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 6) }, overlay)

    overlay.Activated:Connect(showHubConfirm)

    target:SetAttribute("HYD_overlay_ready", true)
    print("[HYDROGEN] đã tạo nút HYDROGEN PRO phủ lên nút cũ:", target:GetFullName())
    return true
end

]====]

-- áp dụng các bản vá
src = between(src, "local function isClassicGui(g)", "local function guiSettled(g)", PATCH_A, "A: nhận diện menu cổ điển")
src = between(src, "local function createHydrogenOverlay(textObj, target)", "SW.consider = function(obj, r)", PATCH_B, "B: nút HYDROGEN PRO + popup")
src = replaceOnce(src, 'if t == "hydrogen" or t == "hydrogen v1" then',
    'if t == "hydrogen" or t == "hydrogen v1" or t == "hydrogen pro" then', "C: nhận diện nút HYDROGEN")
src = replaceOnce(src, "local okC, errC = pcall(recolorClassic, g)",
    "pcall(purgeStrayBackground, g)\n        local okC, errC = pcall(recolorClassic, g)", "D: dọn nền trong menu cổ điển mỗi lần quét")

local fn, err = loadstring(src)
if not fn then
    warn("[HYDROGEN V2] mã sau khi vá bị lỗi cú pháp:", err)
    return
end
local okRun, errRun = pcall(fn)
if not okRun then warn("[HYDROGEN V2] lỗi khi chạy:", errRun) end
