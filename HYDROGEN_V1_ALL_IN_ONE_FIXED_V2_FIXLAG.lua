--[[
    HYDROGEN V1 - ALL-IN-ONE FIXED V2 + FixLag (gộp 1 file)
    Thứ tự: 1) hub V2 (tải file gốc HYDROGEN_V1_ALL_IN_ONE_FIXED.lua, vá và chạy)  ->  2) FixLag chạy sau.
    Lưu ý: vẫn cần giữ nguyên file gốc HYDROGEN_V1_ALL_IN_ONE_FIXED.lua trên GitHub (lấy ảnh nhúng từ đó).
    Mỗi phần nằm trong hàm riêng nên lỗi ở phần này không làm phần kia dừng.
]]

local FIXLAG_DELAY = 6   -- giây chờ sau khi hub khởi động để hub dựng xong giao diện rồi mới chạy FixLag

-- ======================= PHẦN 1: HUB V2 =======================
local function runHub()
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

end

-- ======================= PHẦN 2: FIXLAG =======================
local function runFixLag()
--[[
    HYDROGEN FixLag - All Devices
    Giảm lag phía client cho mọi thiết bị (điện thoại, tablet, PC). Chỉ đổi cách HIỂN THỊ trên máy bạn,
    không xoá object nào và không đụng vào GUI (CoreGui / PlayerGui), nên ESP và hub không bị ảnh hưởng.
    Mọi thay đổi đều được ghi nhớ và khôi phục được.

    Cấp độ:
      1 = Nhẹ    : tắt bóng đổ toàn cục, hiệu ứng Bloom/Blur/SunRays/DepthOfField, tắt particle/trail/beam/lửa/khói, chất lượng đồ hoạ Level05
      2 = Vừa    : + tắt đổ bóng từng part, bỏ phản chiếu, nước & terrain nhẹ hơn, chất lượng Level03
      3 = Tối đa : + vật liệu SmoothPlastic, mesh RenderFidelity=Performance, ẩn Decal/Texture, chất lượng Level01
    LEVEL = "auto": điện thoại bắt đầu ở cấp 2, PC ở cấp 1; nếu FPS vẫn thấp hơn TARGET_FPS thì tự tăng cấp (tối đa 3).

    Điều khiển sau khi chạy (tuỳ chọn):
      getgenv().HYDROGEN_FIXLAG.SetLevel(3)   -- đặt cấp cố định (tắt tự tăng cấp)
      getgenv().HYDROGEN_FIXLAG.Restore()     -- khôi phục mọi thứ như ban đầu
      getgenv().HYDROGEN_FIXLAG.GetFPS()      -- FPS trung bình gần nhất
]]

local CONFIG = {
    LEVEL = "auto",          -- "auto" hoặc 1 / 2 / 3
    TARGET_FPS = 40,         -- (auto) dưới mức này thì tăng cấp
    SAMPLE_SECONDS = 4,      -- (auto) đo FPS trung bình mỗi bấy nhiêu giây
    COOLDOWN_SECONDS = 12,   -- (auto) tối thiểu giữa hai lần tăng cấp
    FRAME_BUDGET_MS = 3,     -- thời gian tối đa mỗi khung hình dành cho việc tối ưu (tránh giật khi quét)
    NOTIFY = true,           -- hiện thông báo nhỏ khi áp dụng
}

local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Workspace = game:GetService("Workspace")

local ENV = (getgenv and getgenv()) or _G

-- chạy lại file: khôi phục bản cũ trước để ghi nhớ đúng giá trị gốc
if type(ENV.HYDROGEN_FIXLAG) == "table" and type(ENV.HYDROGEN_FIXLAG.Stop) == "function" then
    pcall(ENV.HYDROGEN_FIXLAG.Stop)
end

local Terrain = Workspace:FindFirstChildOfClass("Terrain")

-- ================= GHI NHỚ GIÁ TRỊ GỐC =================
local originals = {}            -- originals[instance][property] = giá trị gốc
local hiddenOriginals = {}      -- thuộc tính ẩn (cần gethiddenproperty / sethiddenproperty)
local originalQuality
local stopped = false
local connections = {}
local level = 0
local sweepGen = 0
local lastFps = 0
local lastChange = os.clock()

local function setProp(inst, prop, value)
    local okRead, current = pcall(function() return inst[prop] end)
    if not okRead or current == value then return end
    local rec = originals[inst]
    if not rec then
        rec = {}
        originals[inst] = rec
    end
    if rec[prop] == nil then rec[prop] = current end
    pcall(function() inst[prop] = value end)
end

local function setHidden(inst, prop, value)
    if not (sethiddenproperty and gethiddenproperty) then return end
    local ok, current = pcall(gethiddenproperty, inst, prop)
    if not ok then return end
    local key = inst:GetFullName() .. "." .. prop
    if not hiddenOriginals[key] then hiddenOriginals[key] = { inst = inst, prop = prop, value = current } end
    pcall(sethiddenproperty, inst, prop, value)
end

-- ================= TỪNG OBJECT =================
local EFFECTS = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
local POST = { BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true }

local function optimize(inst, lv)
    local cls = inst.ClassName
    if EFFECTS[cls] then
        setProp(inst, "Enabled", false)
        return
    end
    if lv < 2 then return end
    if inst:IsA("BasePart") then
        if cls == "Terrain" then return end
        setProp(inst, "CastShadow", false)
        if inst.Reflectance ~= 0 then setProp(inst, "Reflectance", 0) end
        if lv >= 3 then
            setProp(inst, "Material", Enum.Material.SmoothPlastic)
            if cls == "MeshPart" then setProp(inst, "RenderFidelity", Enum.RenderFidelity.Performance) end
        end
    elseif lv >= 3 and (cls == "Decal" or cls == "Texture") then
        setProp(inst, "Transparency", 1)
    end
end

-- ================= HÀNG ĐỢI CHO OBJECT MỚI + ĐO FPS =================
local queue, qHead, qTail = {}, 1, 0

local function enqueue(inst)
    qTail = qTail + 1
    queue[qTail] = inst
end

-- ================= ÁP DỤNG THEO CẤP =================
local QUALITY = { [1] = Enum.QualityLevel.Level05, [2] = Enum.QualityLevel.Level03, [3] = Enum.QualityLevel.Level01 }

local function applyGlobal(lv)
    setProp(Lighting, "GlobalShadows", false)
    for _, e in ipairs(Lighting:GetChildren()) do
        if POST[e.ClassName] then setProp(e, "Enabled", false) end
    end
    if lv >= 2 and Terrain then
        setProp(Terrain, "WaterWaveSize", 0)
        setProp(Terrain, "WaterWaveSpeed", 0)
        setProp(Terrain, "WaterReflectance", 0)
        setHidden(Terrain, "Decoration", false)
    end
    pcall(function()
        local rendering = settings().Rendering
        if originalQuality == nil then originalQuality = rendering.QualityLevel end
        rendering.QualityLevel = QUALITY[lv]
    end)
end

local function sweep(lv)
    sweepGen = sweepGen + 1
    local gen = sweepGen
    task.spawn(function()
        local list = Workspace:GetDescendants()
        local t0 = os.clock()
        for i = 1, #list do
            if stopped or gen ~= sweepGen then return end
            local inst = list[i]
            if inst.Parent then pcall(optimize, inst, lv) end
            if (os.clock() - t0) * 1000 >= CONFIG.FRAME_BUDGET_MS then
                task.wait()
                t0 = os.clock()
            end
        end
    end)
end

local function notify(text)
    if not CONFIG.NOTIFY then return end
    pcall(function()
        StarterGui:SetCore("SendNotification", { Title = "HYDROGEN FixLag", Text = text, Duration = 4 })
    end)
end

local function setLevel(lv)
    lv = math.clamp(math.floor(lv), 1, 3)
    if lv == level then return end
    level = lv
    lastChange = os.clock()
    applyGlobal(lv)
    sweep(lv)
    local names = { "Light", "Medium", "Max" }
    print("[HYDROGEN FixLag] level " .. lv .. " (" .. names[lv] .. ")")
    notify("Level " .. lv .. " (" .. names[lv] .. ") applied")
end

local function restore()
    sweepGen = sweepGen + 1                 -- dừng lượt quét đang chạy
    for inst, rec in pairs(originals) do
        for prop, value in pairs(rec) do
            pcall(function() inst[prop] = value end)
        end
    end
    originals = {}
    for _, h in pairs(hiddenOriginals) do
        if sethiddenproperty then pcall(sethiddenproperty, h.inst, h.prop, h.value) end
    end
    hiddenOriginals = {}
    if originalQuality ~= nil then
        pcall(function() settings().Rendering.QualityLevel = originalQuality end)
        originalQuality = nil
    end
    queue, qHead, qTail = {}, 1, 0
    level = 0
end

local function stop()
    if stopped then return end
    stopped = true
    for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
    connections = {}
    restore()
end

-- ================= CHỌN CẤP BAN ĐẦU + VÒNG LẶP =================
local autoMode = CONFIG.LEVEL == "auto"
local startLevel
if autoMode then
    local mobile = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled
    startLevel = mobile and 2 or 1
else
    startLevel = tonumber(CONFIG.LEVEL) or 2
end

table.insert(connections, Workspace.DescendantAdded:Connect(function(inst)
    if level > 0 then enqueue(inst) end
end))

local acc, frames = 0, 0
table.insert(connections, RunService.Heartbeat:Connect(function(dt)
    -- object mới sinh ra trong game (trứng, hiệu ứng...) được xử lý dần, không dồn vào một khung hình
    if qHead <= qTail then
        local t0 = os.clock()
        while qHead <= qTail and (os.clock() - t0) * 1000 < CONFIG.FRAME_BUDGET_MS do
            local inst = queue[qHead]
            queue[qHead] = nil
            qHead = qHead + 1
            if inst and inst.Parent then pcall(optimize, inst, level) end
        end
        if qHead > qTail then queue, qHead, qTail = {}, 1, 0 end
    end

    acc = acc + dt
    frames = frames + 1
    if acc >= CONFIG.SAMPLE_SECONDS then
        lastFps = frames / acc
        acc, frames = 0, 0
        if autoMode and level > 0 and level < 3 and lastFps < CONFIG.TARGET_FPS
            and os.clock() - lastChange >= CONFIG.COOLDOWN_SECONDS then
            setLevel(level + 1)
        end
    end
end))

ENV.HYDROGEN_FIXLAG = {
    SetLevel = function(lv)
        autoMode = false                    -- đặt tay thì tắt tự tăng cấp
        setLevel(lv)
    end,
    Restore = restore,
    Stop = stop,
    GetFPS = function() return lastFps end,
    GetLevel = function() return level end,
}

setLevel(startLevel)

end

local okHub, errHub = pcall(runHub)
if not okHub then warn("[HYDROGEN] lỗi phần hub:", errHub) end

task.wait(FIXLAG_DELAY)

local okLag, errLag = pcall(runFixLag)
if not okLag then warn("[HYDROGEN] lỗi phần FixLag:", errLag) end
