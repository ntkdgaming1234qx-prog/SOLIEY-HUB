--[[
    HYDROGEN V3 (tải từ link GitHub) + FixLag v2 - gộp 1 file
    Không cần sửa file trên GitHub: file này tải HYDROGEN_V1_ALL_IN_ONE_FIXED_V3.lua từ link bên dưới,
    chạy nó, rồi chạy FixLag v2 (nằm sẵn trong file này) sau FIXLAG_DELAY giây.
    Mỗi phần nằm trong pcall riêng nên lỗi ở phần này không làm phần kia dừng.
]]

local V3_URL = "https://raw.githubusercontent.com/ntkdgaming1234qx-prog/SOLIEY-HUB/refs/heads/main/HYDROGEN_V1_ALL_IN_ONE_FIXED_V3.lua"
local FIXLAG_DELAY = 6   -- giây chờ sau khi hub khởi động để hub dựng xong giao diện rồi mới chạy FixLag

-- ======================= PHẦN 1: TẢI VÀ CHẠY HUB V3 TỪ LINK =======================
local function runV3()
    local ok, src = pcall(function() return game:HttpGet(V3_URL) end)
    if not ok or type(src) ~= "string" or #src < 1000 then
        warn("[HYDROGEN] không tải được V3 từ link:", src)
        return
    end
    local fn, err = loadstring(src)
    if not fn then
        warn("[HYDROGEN] V3 bị lỗi cú pháp:", err)
        return
    end
    local okRun, errRun = pcall(fn)
    if not okRun then warn("[HYDROGEN] lỗi khi chạy V3:", errRun) end
end

-- ======================= PHẦN 2: FIXLAG v2 =======================
local function runFixLag()
    --[[
        HYDROGEN FixLag v2 - All Devices (file riêng)
        Giảm lag phía client cho điện thoại, tablet, PC. Chỉ đổi cách HIỂN THỊ trên máy bạn, không xoá object nào,
        không đụng vào GUI (CoreGui / PlayerGui) nên hub và ESP không bị ảnh hưởng. Mọi thay đổi đều khôi phục được.

        Cấp độ:
          1 = Nhẹ    : tắt bóng đổ toàn cục, Bloom/Blur/SunRays/DepthOfField, particle/trail/beam/lửa/khói, chất lượng Level05
          2 = Vừa    : + tắt đèn (Point/Spot/Surface), bóng từng part, phản chiếu, Atmosphere, nước & terrain nhẹ, chất lượng Level03
          3 = Tối đa : + vật liệu SmoothPlastic, mesh RenderFidelity=Performance, ẩn Decal/Texture, Lighting=Compatibility, Level01
        LEVEL = "auto": điện thoại bắt đầu ở cấp 2, PC ở cấp 1; nếu FPS vẫn thấp hơn TARGET_FPS thì tự tăng cấp (tối đa 3).

        Mới so với bản cũ:
          - Bảo vệ: không đụng nhân vật của bạn (PROTECT_OWN_CHARACTER) và các object có tên trong PROTECT_NAMES (cả cây con).
          - Hạ cấp được: SetLevel(thấp hơn) tự khôi phục rồi áp lại đúng cấp.
          - Đo FPS trước/sau và in KẾT LUẬN (có cải thiện hay chưa).
          - Tuỳ chọn giới hạn FPS (FPS_CAP) nếu executor có setfpscap.
          - Ghi đè cấu hình không cần sửa file:
                getgenv().HYDROGEN_FIXLAG_CONFIG = { LEVEL = 3, PROTECT_NAMES = {"Pet", "Egg"} }   -- đặt TRƯỚC khi chạy file

        Điều khiển sau khi chạy:
          getgenv().HYDROGEN_FIXLAG.SetLevel(3)    -- cấp cố định (tắt tự tăng cấp)
          getgenv().HYDROGEN_FIXLAG.Restore()      -- khôi phục mọi thứ như ban đầu
          getgenv().HYDROGEN_FIXLAG.Stop()         -- khôi phục + dừng hẳn
          getgenv().HYDROGEN_FIXLAG.GetFPS()       -- FPS trung bình gần nhất
          getgenv().HYDROGEN_FIXLAG.GetReport()    -- bảng kết luận gần nhất
    ]]

    local DEFAULTS = {
        LEVEL = "auto",              -- "auto" hoặc 1 / 2 / 3
        TARGET_FPS = 40,             -- (auto) dưới mức này thì tăng cấp
        SAMPLE_SECONDS = 4,          -- (auto) đo FPS trung bình mỗi bấy nhiêu giây
        COOLDOWN_SECONDS = 12,       -- (auto) tối thiểu giữa hai lần tăng cấp
        FRAME_BUDGET_MS = 3,         -- thời gian tối đa mỗi khung hình dành cho tối ưu (tránh giật khi quét)
        NOTIFY = true,               -- thông báo nhỏ
        PROTECT_OWN_CHARACTER = true,
        PROTECT_NAMES = {},          -- tên object (khớp chính xác) cần bỏ qua, gồm cả con cháu
        FPS_CAP = 0,                 -- >0: giới hạn FPS (cần setfpscap); Restore trả về 60
        BASELINE_SECONDS = 2,        -- đo FPS trước khi áp dụng
        REPORT_AFTER = 6,            -- đợi bao lâu sau khi áp dụng thì đo lại và kết luận
    }

    local Lighting = game:GetService("Lighting")
    local RunService = game:GetService("RunService")
    local UserInputService = game:GetService("UserInputService")
    local StarterGui = game:GetService("StarterGui")
    local Players = game:GetService("Players")
    local Workspace = game:GetService("Workspace")

    local ENV = (getgenv and getgenv()) or _G

    -- chạy lại file: dừng và khôi phục bản cũ trước để ghi nhớ đúng giá trị gốc
    if type(ENV.HYDROGEN_FIXLAG) == "table" and type(ENV.HYDROGEN_FIXLAG.Stop) == "function" then
        pcall(ENV.HYDROGEN_FIXLAG.Stop)
    end

    local CONFIG = {}
    for k, v in pairs(DEFAULTS) do CONFIG[k] = v end
    if type(ENV.HYDROGEN_FIXLAG_CONFIG) == "table" then
        for k, v in pairs(ENV.HYDROGEN_FIXLAG_CONFIG) do CONFIG[k] = v end
    end

    local Terrain = Workspace:FindFirstChildOfClass("Terrain")
    local LocalPlayer = Players.LocalPlayer

    local protectSet = {}
    for _, n in ipairs(CONFIG.PROTECT_NAMES) do protectSet[n] = true end

    -- ================= GHI NHỚ GIÁ TRỊ GỐC =================
    local originals = {}            -- originals[instance][property] = giá trị gốc
    local hiddenOriginals = {}
    local originalQuality
    local capApplied = false
    local stopped = false
    local connections = {}
    local level = 0
    local sweepGen = 0
    local lastFps = 0
    local lastChange = os.clock()
    local report

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

    -- ================= BẢO VỆ =================
    local function isProtected(inst)
        if CONFIG.PROTECT_OWN_CHARACTER then
            local char = LocalPlayer and LocalPlayer.Character
            if char and inst:IsDescendantOf(char) then return true end
        end
        if next(protectSet) then
            local cur = inst
            while cur and cur ~= Workspace do
                if protectSet[cur.Name] then return true end
                cur = cur.Parent
            end
        end
        return false
    end

    -- ================= TỪNG OBJECT =================
    local EFFECTS = { ParticleEmitter = true, Trail = true, Beam = true, Smoke = true, Fire = true, Sparkles = true }
    local LIGHTS = { PointLight = true, SpotLight = true, SurfaceLight = true }
    local POST = { BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true }

    local function optimize(inst, lv)
        local cls = inst.ClassName
        if EFFECTS[cls] then
            if not isProtected(inst) then setProp(inst, "Enabled", false) end
            return
        end
        if lv < 2 then return end
        if LIGHTS[cls] then
            if not isProtected(inst) then setProp(inst, "Enabled", false) end
            return
        end
        if inst:IsA("BasePart") then
            if cls == "Terrain" or isProtected(inst) then return end
            setProp(inst, "CastShadow", false)
            if inst.Reflectance ~= 0 then setProp(inst, "Reflectance", 0) end
            if lv >= 3 then
                setProp(inst, "Material", Enum.Material.SmoothPlastic)
                if cls == "MeshPart" then setProp(inst, "RenderFidelity", Enum.RenderFidelity.Performance) end
            end
        elseif lv >= 3 and (cls == "Decal" or cls == "Texture") then
            if not isProtected(inst) then setProp(inst, "Transparency", 1) end
        end
    end

    -- ================= HÀNG ĐỢI CHO OBJECT MỚI =================
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
            if POST[e.ClassName] then
                setProp(e, "Enabled", false)
            elseif lv >= 2 and e:IsA("Atmosphere") then
                setProp(e, "Density", 0)
                setProp(e, "Haze", 0)
            end
        end
        if lv >= 2 and Terrain then
            setProp(Terrain, "WaterWaveSize", 0)
            setProp(Terrain, "WaterWaveSpeed", 0)
            setProp(Terrain, "WaterReflectance", 0)
            setHidden(Terrain, "Decoration", false)
        end
        if lv >= 3 then
            setHidden(Lighting, "Technology", Enum.Technology.Compatibility)
        end
        pcall(function()
            local rendering = settings().Rendering
            if originalQuality == nil then originalQuality = rendering.QualityLevel end
            rendering.QualityLevel = QUALITY[lv]
        end)
        if CONFIG.FPS_CAP and CONFIG.FPS_CAP > 0 and setfpscap then
            pcall(setfpscap, CONFIG.FPS_CAP)
            capApplied = true
        end
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

    local function countChanged()
        local n = 0
        for _ in pairs(originals) do n = n + 1 end
        return n
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
        if capApplied and setfpscap then
            pcall(setfpscap, 60)
            capApplied = false
        end
        queue, qHead, qTail = {}, 1, 0
        level = 0
    end

    local function setLevel(lv)
        lv = math.clamp(math.floor(lv), 1, 3)
        if lv == level then return end
        if level > 0 and lv < level then restore() end   -- hạ cấp: khôi phục rồi áp lại từ đầu
        level = lv
        lastChange = os.clock()
        applyGlobal(lv)
        sweep(lv)
        local names = { "Light", "Medium", "Max" }
        print("[HYDROGEN FixLag] level " .. lv .. " (" .. names[lv] .. ")")
        notify("Level " .. lv .. " (" .. names[lv] .. ") applied")
    end

    local function stop()
        if stopped then return end
        stopped = true
        for _, c in ipairs(connections) do pcall(function() c:Disconnect() end) end
        connections = {}
        restore()
    end

    -- ================= ĐO FPS + KẾT LUẬN =================
    local function measure(seconds)
        local acc, n = 0, 0
        local conn = RunService.Heartbeat:Connect(function(dt)
            acc = acc + dt
            n = n + 1
        end)
        task.wait(seconds)
        conn:Disconnect()
        return acc > 0 and n / acc or 0
    end

    local function buildReport(before, after)
        local gain = before > 0 and (after - before) / before * 100 or 0
        local verdict
        if after >= before * 1.05 then
            verdict = "Có cải thiện"
        elseif after >= before * 0.97 then
            verdict = "Chưa cải thiện rõ (có thể máy đang bị giới hạn FPS hoặc nút thắt không nằm ở đồ hoạ)"
        else
            verdict = "FPS không tăng; thử SetLevel(3) hoặc Restore()"
        end
        report = {
            level = level,
            fpsBefore = math.floor(before * 10) / 10,
            fpsAfter = math.floor(after * 10) / 10,
            gainPercent = math.floor(gain * 10) / 10,
            changedObjects = countChanged(),
            verdict = verdict,
        }
        print(string.format("[HYDROGEN FixLag] KẾT LUẬN: cấp %d | FPS %.1f -> %.1f (%+.1f%%) | %d đối tượng đã đổi | %s",
            level, before, after, gain, report.changedObjects, verdict))
        notify(string.format("FPS %.0f -> %.0f: %s", before, after, verdict))
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
        -- object mới sinh ra (trứng, hiệu ứng...) được xử lý dần, không dồn vào một khung hình
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
        GetReport = function() return report end,
    }

    -- đo trước -> áp dụng -> đo sau -> kết luận
    task.spawn(function()
        local before = measure(CONFIG.BASELINE_SECONDS)
        if stopped then return end
        setLevel(startLevel)
        task.wait(CONFIG.REPORT_AFTER)
        if stopped then return end
        local after = measure(3)
        if stopped then return end
        buildReport(before, after)
    end)
end

local okV3, errV3 = pcall(runV3)
if not okV3 then warn("[HYDROGEN] lỗi phần V3:", errV3) end

task.wait(FIXLAG_DELAY)   -- chờ hub dựng xong giao diện rồi mới chạy FixLag
local okLag, errLag = pcall(runFixLag)
if not okLag then warn("[HYDROGEN] lỗi phần FixLag:", errLag) end
