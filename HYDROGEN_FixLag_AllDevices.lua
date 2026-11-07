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
