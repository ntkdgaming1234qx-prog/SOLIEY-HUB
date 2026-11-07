--[[
    HYDROGEN V1 - ALL-IN-ONE FIXED V3 (V2 + đổi icon tab + dọn nền + sửa menu cổ điển; FixLag tách riêng)
    Thứ tự: 1) hub V2 (tải file gốc HYDROGEN_V1_ALL_IN_ONE_FIXED.lua, vá và chạy)  ->  2) đổi icon tab + dọn nền  ->  3) FixLag (file riêng HYDROGEN_FixLag.lua, tuỳ chọn qua FIXLAG_URL).
    Lưu ý: vẫn cần giữ nguyên file gốc HYDROGEN_V1_ALL_IN_ONE_FIXED.lua trên GitHub (lấy ảnh nhúng từ đó).
    Mỗi phần nằm trong hàm riêng nên lỗi ở phần này không làm phần kia dừng.
]]

local FIXLAG_URL = ""     -- link raw tới HYDROGEN_FixLag.lua (để trống = không tự chạy FixLag)
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

-- ======================= PHẦN 3: ĐỔI ICON TAB + DỌN NỀN + SỬA MENU CỔ ĐIỂN =======================
-- Chạy độc lập với phần 1 (không cần biết code file gốc), quét giao diện lúc đang chạy:
--   (a) Thanh tab bên trái của menu chính: icon quả trứng trắng (tab 3) -> chuyển sang tab 2, tab 3 bị xoá icon.
--   (b) Sau khi bấm SWITCH: mọi lớp nền/ảnh nền của menu chính còn sót lại trong menu cổ điển bị xoá.
--   (c) Menu cổ điển: logo V -> logo HYDROGEN, ẩn khung Try ngay, thay khung mã loadstring bằng khung
--       "Quay lại giao diện cũ" (SWITCH: tắt menu cổ điển và chạy lại menu cũ).
local function runTabAndBgFix()
    local Players = game:GetService("Players")
    local CoreGui = game:GetService("CoreGui")
    local Workspace = game:GetService("Workspace")

    local CFG = {
        TAB3_IMAGE = "",            -- để trống = tab 3 không có icon. Muốn icon khác: "rbxassetid://123456"
        AGGRESSIVE_BG_CLEAN = true, -- xoá cả ảnh rất lớn (>=30% chiều rộng, >=35% chiều cao màn hình) lọt vào menu cổ điển
        TICK = 0.5,
        HIDE_PROMO_CARD = true,     -- true = ẩn cả khung logo V + nút "Try ngay"; false = chỉ ẩn nút Try (khung giữ lại với logo HYDROGEN)
        LOGO_IMAGE = "",            -- để trống = tự lấy logo HYDROGEN từ menu chính. Muốn chỉ định: "rbxassetid://123456"
        BACK_URL = "https://raw.githubusercontent.com/ntkdgaming1234qx-prog/SOLIEY-HUB/refs/heads/main/HYDROGEN_V1_ALL_IN_ONE_FIXED_V3.lua",  -- SWITCH sẽ tải lại link này (menu cũ)
        BACK_CLEAR_GLOBALS = {},    -- tên biến getgenv() cần xoá thêm trước khi chạy lại menu cũ (nếu hub gốc chặn chạy lần 2)
        DRY_RUN = false,            -- true = chỉ in log những gì SẼ dọn, không xoá/ẩn gì cả (để kiểm tra trước)
    }

    local function getContainers()
        local list = {}
        local hui
        pcall(function() if gethui then hui = gethui() end end)
        if hui then
            list[1] = hui
        else
            list[1] = CoreGui
            pcall(function()
                local lp = Players.LocalPlayer
                local pg = lp and lp:FindFirstChildOfClass("PlayerGui")
                if pg then list[#list + 1] = pg end
            end)
        end
        return list
    end

    local function eachGui(fn)
        for _, c in ipairs(getContainers()) do
            local ok, kids = pcall(function() return c:GetChildren() end)
            if ok then
                for _, g in ipairs(kids) do
                    if g:IsA("ScreenGui") then pcall(fn, g) end
                end
            end
        end
    end

    local function plainText(s)
        s = tostring(s or ""):gsub("<[^>]+>", "")
        return (s:gsub("^%s+", ""):gsub("%s+$", ""):lower())
    end

    -- ---------- tìm cột nút tab vuông xếp dọc (thanh tab trái) ----------
    local function getTabButtons(g)
        local groups = {}
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
                local s, p = d.AbsoluteSize, d.AbsolutePosition
                if s.X >= 16 and s.X <= 140 and math.abs(s.X - s.Y) <= math.max(3, s.X * 0.12) then
                    local found
                    for _, grp in ipairs(groups) do
                        if math.abs(grp.x - p.X) <= 3 and math.abs(grp.size - s.X) <= 4 then
                            found = grp
                            break
                        end
                    end
                    if not found then
                        found = { x = p.X, size = s.X, items = {}, ys = {} }
                        groups[#groups + 1] = found
                    end
                    local yk = math.floor(p.Y / 6)
                    if not found.ys[yk] then
                        found.ys[yk] = true
                        found.items[#found.items + 1] = d
                    end
                end
            end
        end
        local best
        for _, grp in ipairs(groups) do
            if #grp.items >= 4 and (not best or grp.x < best.x) then best = grp end
        end
        if not best then return nil end
        table.sort(best.items, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
        return best.items
    end

    local function getIcon(b)
        for _, d in ipairs(b:GetDescendants()) do
            if d:GetAttribute("HYD_tabfix_hidden") then return d end
        end
        if b:GetAttribute("HYD_tabfix_hidden") then return b end
        local best, bestScore
        local bs = b.AbsoluteSize
        local function consider(d)
            local isImg = (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= ""
            local isTxt = (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= ""
            if not (isImg or isTxt) then return end
            local s = d.AbsoluteSize
            local c = (d.AbsolutePosition + s / 2) - (b.AbsolutePosition + bs / 2)
            local score = c.Magnitude
            if d ~= b and (s.X > bs.X * 0.9 or s.X < bs.X * 0.2) then score = score + 1000 end
            if d.Name:lower():find("icon", 1, true) then score = score - 50 end
            if not bestScore or score < bestScore then best, bestScore = d, score end
        end
        consider(b)
        for _, d in ipairs(b:GetDescendants()) do consider(d) end
        return best
    end

    local function isImg(d) return d:IsA("ImageLabel") or d:IsA("ImageButton") end
    local function isTxt(d) return d:IsA("TextLabel") or d:IsA("TextButton") end

    local function snapshot(d)
        if isImg(d) then
            return { kind = "img", Image = d.Image, Off = d.ImageRectOffset, Size = d.ImageRectSize }
        end
        return { kind = "txt", Text = d.Text, Font = d.Font }
    end

    local function applySnap(d, s)
        if s.kind == "img" and isImg(d) then
            if d.Image ~= s.Image then d.Image = s.Image end
            if d.ImageRectOffset ~= s.Off then d.ImageRectOffset = s.Off end
            if d.ImageRectSize ~= s.Size then d.ImageRectSize = s.Size end
            return true
        elseif s.kind == "txt" and isTxt(d) then
            if d.Text ~= s.Text then d.Text = s.Text end
            if d.Font ~= s.Font then d.Font = s.Font end
            return true
        end
        return false
    end

    local function hideIcon(i3, tabBtn)
        i3:SetAttribute("HYD_tabfix_hidden", true)
        if CFG.TAB3_IMAGE ~= "" and isImg(i3) then
            i3.Visible = true
            i3.ImageTransparency = 0
            i3.Image = CFG.TAB3_IMAGE
            i3.ImageRectOffset = Vector2.new(0, 0)
            i3.ImageRectSize = Vector2.new(0, 0)
        elseif i3 == tabBtn then
            if isImg(i3) then i3.ImageTransparency = 1 else i3.TextTransparency = 1 end
        else
            if i3.Visible then i3.Visible = false end
        end
    end

    -- ---------- nhận diện menu cổ điển (menu 2) ----------
    local WORDS = { ["farm"] = true, ["event"] = true, ["player"] = true, ["predictor"] = true,
        ["server"] = true, ["misc"] = true, ["auto hop"] = true }

    local function countWords(g)
        local seen, n = {}, 0
        for _, d in ipairs(g:GetDescendants()) do
            if isTxt(d) then
                local t = plainText(d.Text)
                if WORDS[t] and not seen[t] then seen[t] = true; n = n + 1 end
            end
        end
        return n
    end

    local classicCache = setmetatable({}, { __mode = "k" })
    local function isClassic(g)
        if g:GetAttribute("HYD_classic") then return true end
        local c = classicCache[g]
        if c and (c.v or os.clock() - c.t < 3) then return c.v end
        local v = false
        if not g:GetAttribute("HYD_skip") and countWords(g) >= 4 and not getTabButtons(g) then v = true end
        classicCache[g] = { v = v, t = os.clock() }
        return v
    end

    -- ---------- nền của menu chính ----------
    local bgImages = {}

    local function learnBackgrounds(g)
        for _, d in ipairs(g:GetDescendants()) do
            if isImg(d) and d.Image ~= "" then
                if d.Name == "HYDROGEN_BG" or d:GetAttribute("HYD_background") or d.AbsoluteSize.X >= 300 then
                    bgImages[d.Image] = true
                end
            end
        end
    end

    -- ---------- HÀM HỖ TRỢ CHỐNG XOÁ NHẦM ----------
    -- Quy tắc: không bao giờ đụng vào UI thật (có chữ / nút / ô nhập / khung cuộn), thứ được đánh dấu giữ lại,
    -- hay popup xác nhận. Khớp chắc chắn (tên / thuộc tính / ảnh nền đã học) mới được Destroy;
    -- khớp theo kích thước chỉ ẩn đi (khôi phục được); nếu có UI thật bên trong thì chỉ làm trong suốt phần nền.
    local restoreLog = {}   -- danh sách hành động có thể hoàn tác
    local loggedOnce = setmetatable({}, { __mode = "k" })

    local function note(d, why)
        if loggedOnce[d] then return end
        loggedOnce[d] = true
        local name = "?"
        pcall(function() name = d:GetFullName() end)
        print("[HYDROGEN] dọn nền" .. (CFG.DRY_RUN and " (DRY_RUN, chưa xoá)" or "") .. ": " .. name .. " [" .. why .. "]")
    end

    -- true nếu d chứa UI thật bên trong (không tính chính d)
    local function hasRealUI(d)
        for _, c in ipairs(d:GetDescendants()) do
            if c:IsA("TextButton") or c:IsA("TextBox") or c:IsA("ScrollingFrame") or c:IsA("ImageButton")
                or (c:IsA("TextLabel") and c.Text ~= "") then
                return true
            end
        end
        return false
    end

    -- true nếu tuyệt đối không được đụng vào d
    local function isProtected(d, g)
        if d == g or not d.Parent then return true end
        local cur = d
        while cur and cur ~= game do
            if cur:GetAttribute("HYD_skip") or cur:GetAttribute("HYD_keep") then return true end
            if tostring(cur.Name):find("SW_ConfirmHub", 1, true) then return true end
            cur = cur.Parent
        end
        return false
    end

    local recorded = setmetatable({}, { __mode = "k" })
    local function remember(d, props)
        if recorded[d] then return end   -- chỉ ghi giá trị gốc lần đầu để hoàn tác đúng
        recorded[d] = true
        local rec = { inst = d, old = {} }
        for _, p in ipairs(props) do
            local ok, v = pcall(function() return d[p] end)
            if ok then rec.old[p] = v end
        end
        restoreLog[#restoreLog + 1] = rec
    end

    -- mode: "strong" (khớp chắc chắn) hoặc "heuristic" (đoán theo kích thước)
    local function safeRemove(d, g, mode, why)
        if isProtected(d, g) then return false end
        note(d, why or mode)
        if CFG.DRY_RUN then return false end
        if hasRealUI(d) then
            -- bên trong có UI thật: chỉ làm trong suốt phần nền, giữ nguyên nội dung
            if isImg(d) then
                remember(d, { "ImageTransparency", "BackgroundTransparency" })
                d.ImageTransparency = 1
                d.BackgroundTransparency = 1
            elseif d:IsA("GuiObject") then
                remember(d, { "BackgroundTransparency" })
                d.BackgroundTransparency = 1
            end
            return true
        end
        if mode == "strong" then
            pcall(function() d:Destroy() end)
        elseif d:IsA("GuiObject") then
            remember(d, { "Visible" })
            d.Visible = false
        end
        return true
    end

    -- khung cha chỉ còn lại các UI-modifier (rỗng thật sự) mới được ẩn theo
    local function isEmptyShell(p, g)
        if not p or p == g or not p.Parent or not p:IsA("Frame") then return false end
        if isProtected(p, g) then return false end
        for _, c in ipairs(p:GetChildren()) do
            if not (c:IsA("UICorner") or c:IsA("UIStroke") or c:IsA("UIGradient")
                or c:IsA("UIAspectRatioConstraint") or c:IsA("UIPadding")) then
                return false
            end
        end
        return true
    end

    -- hoàn tác mọi thứ đã ẩn / làm trong suốt:  getgenv().HYDROGEN_RESTORE_HIDDEN()
    local function restoreAll()
        for _, rec in ipairs(restoreLog) do
            if rec.inst and rec.inst.Parent then
                for p, v in pairs(rec.old) do pcall(function() rec.inst[p] = v end) end
            end
        end
        restoreLog = {}
    end
    pcall(function() if getgenv then getgenv().HYDROGEN_RESTORE_HIDDEN = restoreAll end end)

    local function purgeClassic(g)
        local cam = Workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        for _, d in ipairs(g:GetDescendants()) do
            if d.Parent and not isProtected(d, g) then
                local mode, why
                if d.Name == "HYDROGEN_BG" or d.Name == "HYD_Darken" or d:GetAttribute("HYD_background") then
                    mode, why = "strong", "tên/thuộc tính nền"
                elseif isImg(d) and d.Image ~= "" then
                    if bgImages[d.Image] then
                        mode, why = "strong", "ảnh nền đã học"
                    elseif CFG.AGGRESSIVE_BG_CLEAN and d.AbsoluteSize.X >= vp.X * 0.3 and d.AbsoluteSize.Y >= vp.Y * 0.35 then
                        mode, why = "heuristic", "ảnh quá lớn"
                    end
                end
                if mode then
                    local parent = d.Parent
                    if safeRemove(d, g, mode, why) and isEmptyShell(parent, g) then
                        safeRemove(parent, g, "heuristic", "khung rỗng sau khi bỏ nền")
                    end
                end
            end
        end
    end

    -- ScreenGui riêng chỉ chứa nền (không có chữ/nút) còn sót sau khi hub chính đã đóng -> chỉ tắt (Enabled=false)
    local function purgeStrayBgGui(g)
        if isProtected(g, nil) then return end
        local hasBg = false
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ScrollingFrame") or d:IsA("ImageButton")
                or (d:IsA("TextLabel") and d.Text ~= "") then
                return
            end
            if d.Name == "HYDROGEN_BG" or d:GetAttribute("HYD_background") or (isImg(d) and bgImages[d.Image]) then
                hasBg = true
            end
        end
        if hasBg then
            if not g.Enabled then return end
            note(g, "ScreenGui nền mồ côi")
            if CFG.DRY_RUN then return end
            remember(g, { "Enabled" })
            g.Enabled = false
        end
    end

    -- ---------- QUÉT KIỂM TRA SAU KHI TẢI + XOÁ DỰ PHÒNG ----------
    -- Sau khi menu cổ điển xuất hiện, quét lại theo lịch (2s, 5s, 10s, 20s, 40s rồi mỗi 10s).
    -- "Lớp che" = ảnh lớn đang hiện, không chứa UI thật, đè lên các nút của menu cổ điển
    -- (nằm trong menu cổ điển, hoặc là ScreenGui riêng chỉ chứa ảnh nền).
    -- Lần đầu thì ẩn đi (hoàn tác được); nếu sau 3 vòng vẫn bị tạo lại thì xoá hẳn.
    local mainRef = nil                       -- menu chính hiện tại (được vòng lặp cập nhật), tuyệt đối không dọn
    local verifyState = setmetatable({}, { __mode = "k" })
    local VERIFY_AT = { 2, 5, 10, 20, 40 }

    local function rectsOverlap(a, b)
        local ap, as, bp, bs = a.AbsolutePosition, a.AbsoluteSize, b.AbsolutePosition, b.AbsoluteSize
        return ap.X < bp.X + bs.X and bp.X < ap.X + as.X and ap.Y < bp.Y + bs.Y and bp.Y < ap.Y + as.Y
    end

    local function isBigImage(d, vp)
        return isImg(d) and d.Image ~= "" and d.Visible
            and d.AbsoluteSize.X >= vp.X * 0.25 and d.AbsoluteSize.Y >= vp.Y * 0.3
    end

    -- trả về danh sách { inst = ..., kind = "item" | "gui" }
    local function findCovers(g)
        local cam = Workspace.CurrentCamera
        local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
        local covers = {}

        -- các nút thật của menu cổ điển (để kiểm tra có bị đè hay không)
        local btns = {}
        for _, d in ipairs(g:GetDescendants()) do
            if d:IsA("TextButton") and d.Visible and d.AbsoluteSize.X > 20 and d.AbsoluteSize.Y > 10 then
                btns[#btns + 1] = d
                if #btns >= 40 then break end
            end
        end
        if #btns == 0 then return covers end

        local function overlapsButtons(d)
            for _, b in ipairs(btns) do
                if rectsOverlap(d, b) then return true end
            end
            return false
        end

        for _, d in ipairs(g:GetDescendants()) do
            if isBigImage(d, vp) and not isProtected(d, g) and not hasRealUI(d) and overlapsButtons(d) then
                covers[#covers + 1] = { inst = d, kind = "item" }
            end
        end

        -- ScreenGui khác chỉ chứa ảnh nền, không có UI thật
        eachGui(function(o)
            if o == g or o == mainRef or not o.Enabled or isProtected(o, nil) or isClassic(o) then return end
            local big = nil
            for _, d in ipairs(o:GetDescendants()) do
                if d:IsA("TextButton") or d:IsA("TextBox") or d:IsA("ScrollingFrame") or d:IsA("ImageButton")
                    or (d:IsA("TextLabel") and d.Text ~= "") then
                    return
                end
                if not big and isBigImage(d, vp) and overlapsButtons(d) then big = d end
            end
            if big then covers[#covers + 1] = { inst = o, kind = "gui" } end
        end)
        return covers
    end

    local function fallbackClean(g, covers, escalate)
        local n = 0
        for _, c in ipairs(covers) do
            local d = c.inst
            if d and d.Parent then
                if c.kind == "gui" then
                    note(d, "dự phòng: ScreenGui che menu")
                    if not CFG.DRY_RUN then
                        if escalate then
                            pcall(function() d:Destroy() end)
                        else
                            remember(d, { "Enabled" })
                            d.Enabled = false
                        end
                        n = n + 1
                    end
                else
                    local parent = d.Parent
                    if safeRemove(d, g, escalate and "strong" or "heuristic", "dự phòng: ảnh che menu") then
                        n = n + 1
                        if isEmptyShell(parent, g) then
                            safeRemove(parent, g, "heuristic", "dự phòng: khung rỗng")
                        end
                    end
                end
            end
        end
        return n
    end

    -- kiểm tra lần nữa sau khi dọn để đưa ra kết luận (và dọn cứng lần cuối nếu vẫn còn)
    local concluding = setmetatable({}, { __mode = "k" })
    local function setStatus(clean, remaining)
        pcall(function()
            if getgenv then getgenv().HYDROGEN_BG_STATUS = { clean = clean, remaining = remaining, at = os.clock() } end
        end)
    end

    local function concludeClean(g)
        if concluding[g] then return end
        concluding[g] = true
        task.spawn(function()
            task.wait(1.2)                                   -- chờ hub có cơ hội tạo lại nền
            if not g.Parent then concluding[g] = nil return end
            local left = findCovers(g)
            if #left == 0 then
                print("[HYDROGEN] KẾT LUẬN: menu cổ điển sạch, không còn lớp che.")
                setStatus(true, 0)
                concluding[g] = nil
                return
            end
            print("[HYDROGEN] kiểm tra lại: còn " .. #left .. " lớp che -> xoá cứng lần cuối")
            fallbackClean(g, left, true)
            task.wait(1.2)
            if not g.Parent then concluding[g] = nil return end
            local final = findCovers(g)
            if #final == 0 then
                print("[HYDROGEN] KẾT LUẬN: đã dọn sạch sau lần xoá cứng cuối.")
                setStatus(true, 0)
            else
                print("[HYDROGEN] KẾT LUẬN: vẫn còn " .. #final .. " lớp che (hub có thể tạo lại liên tục)."
                    .. " Gửi log này để chỉnh đúng chỗ. Đặt getgenv().HYDROGEN_FORCE_CLEAN(true) để thử xoá tay.")
                for _, c in ipairs(final) do
                    local nm = "?"
                    pcall(function() nm = c.inst:GetFullName() end)
                    print("  - còn sót: " .. nm)
                end
                setStatus(false, #final)
            end
            concluding[g] = nil
        end)
    end

    -- gọi trong vòng lặp cho mỗi menu cổ điển
    local function verifyClassic(g)
        local st = verifyState[g]
        local now = os.clock()
        if not st then
            st = { since = now, step = 1, rounds = 0 }
            verifyState[g] = st
        end
        local due = st.since + (VERIFY_AT[st.step] or (VERIFY_AT[#VERIFY_AT] + (st.step - #VERIFY_AT) * 10))
        if now < due then return end
        st.step = st.step + 1

        local covers = findCovers(g)
        if #covers > 0 then
            st.rounds = st.rounds + 1
            print("[HYDROGEN] quét sau khi tải: còn " .. #covers .. " lớp che -> xoá dự phòng (vòng " .. st.rounds .. ")")
            fallbackClean(g, covers, st.rounds >= 3)
            concludeClean(g)
        elseif not st.reportedClean then
            st.reportedClean = true
            print("[HYDROGEN] quét sau khi tải: sạch, không có lớp che.")
            setStatus(true, 0)
        end
    end

    -- chạy tay ngay:  getgenv().HYDROGEN_FORCE_CLEAN()
    pcall(function()
        if getgenv then
            getgenv().HYDROGEN_FORCE_CLEAN = function(escalate)
                eachGui(function(g)
                    if g ~= mainRef and isClassic(g) then
                        local covers = findCovers(g)
                        print("[HYDROGEN] FORCE_CLEAN: " .. #covers .. " lớp che")
                        fallbackClean(g, covers, escalate == true)
                        concludeClean(g)
                    end
                end)
            end
        end
    end)

    -- ---------- MENU CỔ ĐIỂN: logo HYDROGEN, ẩn khung Try, khung "Quay lại giao diện cũ" ----------
    -- Quét lúc đang chạy (không cần biết code menu cổ điển):
    --   * khung có chữ "Smoother, faster..." + nút "Try ngay" -> ẩn (logo V trong đó cũng được đổi sang logo HYDROGEN)
    --   * khung mã loadstring + nút "Sao chép" -> ẩn, thay bằng khung "Quay lại giao diện cũ" có nút SWITCH
    --   * SWITCH: đóng menu cổ điển rồi chạy lại menu cũ (tải lại BACK_URL)
    local logoImage = (CFG.LOGO_IMAGE ~= "" and CFG.LOGO_IMAGE) or nil

    local function isTextual(d) return d:IsA("TextLabel") or d:IsA("TextButton") or d:IsA("TextBox") end

    local function isSquareImg(d, lo, hi)
        if not isImg(d) or d.Image == "" then return false end
        local s = d.AbsoluteSize
        return s.X >= lo and s.X <= hi and math.abs(s.X - s.Y) <= math.max(3, s.X * 0.12)
    end

    local function lcaOf(a, b)
        local set, cur = {}, a
        while cur do set[cur] = true; cur = cur.Parent end
        cur = b
        while cur do
            if set[cur] then return cur end
            cur = cur.Parent
        end
        return nil
    end

    local function isAncestorOrSelf(a, d) return d == a or d:IsDescendantOf(a) end

    local function countButtons(root)
        local n = 0
        for _, c in ipairs(root:GetDescendants()) do
            if c:IsA("TextButton") or c:IsA("ImageButton") then n = n + 1 end
        end
        return n
    end

    -- học logo HYDROGEN từ menu chính: ảnh vuông nhỏ nằm cao nhất rồi trái nhất (logo ở góc trái thanh tiêu đề)
    local function learnLogo(g)
        if logoImage then return end
        local best
        for _, d in ipairs(g:GetDescendants()) do
            if isSquareImg(d, 20, 90) and d.Visible and not bgImages[d.Image] then
                local p = d.AbsolutePosition
                if not best or p.Y < best.y - 6 or (math.abs(p.Y - best.y) <= 6 and p.X < best.x) then
                    best = { img = d.Image, x = p.X, y = p.Y }
                end
            end
        end
        if best then
            logoImage = best.img
            print("[HYDROGEN] đã học logo HYDROGEN từ menu chính")
        end
    end

    -- dự phòng khi chưa từng thấy menu chính: ảnh vuông xuất hiện >= 2 lần ở các GUI ngoài menu cổ điển (logo nổi bên trái/phải)
    local lastFallback = 0
    local function fallbackLogo()
        if logoImage or os.clock() - lastFallback < 3 then return end
        lastFallback = os.clock()
        local counts = {}
        eachGui(function(o)
            if o:GetAttribute("HYD_skip") or isClassic(o) then return end
            for _, d in ipairs(o:GetDescendants()) do
                if isSquareImg(d, 28, 140) and not bgImages[d.Image] then
                    counts[d.Image] = (counts[d.Image] or 0) + 1
                end
            end
        end)
        local bestImg, bestN
        for img, n in pairs(counts) do
            if n >= 2 and (not bestN or n > bestN) then bestImg, bestN = img, n end
        end
        if bestImg then
            logoImage = bestImg
            print("[HYDROGEN] dùng logo dự phòng (ảnh vuông lặp lại). Có thể đặt CFG.LOGO_IMAGE để chỉ định chính xác.")
        end
    end

    local function newInst(class, props, parent)
        local o = Instance.new(class)
        for k, v in pairs(props) do o[k] = v end
        o:SetAttribute("HYD_skip", true)   -- hub gốc và bộ dọn nền đều bỏ qua đối tượng này
        o:SetAttribute("HYD_keep", true)
        o.Parent = parent
        return o
    end

    local function hideObj(d, g, why)
        if not d or not d.Parent or isProtected(d, g) then return end
        if d:IsA("GuiObject") and d.Visible then
            note(d, why)
            remember(d, { "Visible" })
            d.Visible = false
        end
    end

    local function setLogo(img)
        if not logoImage or img.Image == logoImage then return end
        remember(img, { "Image", "ImageRectOffset", "ImageRectSize", "ImageColor3", "ScaleType" })
        img.Image = logoImage
        img.ImageRectOffset = Vector2.new(0, 0)
        img.ImageRectSize = Vector2.new(0, 0)
        img.ImageColor3 = Color3.new(1, 1, 1)
        img.ScaleType = Enum.ScaleType.Fit
        note(img, "đổi logo V -> logo HYDROGEN")
    end

    -- ---------- SWITCH: tắt menu cổ điển + chạy lại menu cũ ----------
    local KEEP_GLOBALS = { HYDROGEN_FIXLAG = true, HYDROGEN_FIXLAG_CONFIG = true, HYDROGEN_BG_STATUS = true,
        HYDROGEN_FORCE_CLEAN = true, HYDROGEN_RESTORE_HIDDEN = true, HYDROGEN_GUARD_STOP = true,
        HYDROGEN_BACK_TO_OLD = true }

    -- xoá các cờ kiểu "đã tải/đang chạy" của hub (nếu có) để hub cũ chịu chạy lại
    local function resetHubFlags()
        local env = getgenv and getgenv()
        if not env then return end
        local names = {}
        for k in pairs(env) do
            if type(k) == "string" and not KEEP_GLOBALS[k] then
                local u = k:upper()
                local isHub = u:find("HYDROGEN", 1, true) or u:find("SOLIEY", 1, true) or u:find("VENYX", 1, true)
                local isFlag = u:find("LOAD", 1, true) or u:find("RUN", 1, true) or u:find("ACTIVE", 1, true)
                    or u:find("EXEC", 1, true) or u:find("STARTED", 1, true)
                if isHub and isFlag then names[#names + 1] = k end
            end
        end
        for _, k in ipairs(CFG.BACK_CLEAR_GLOBALS) do names[#names + 1] = k end
        for _, k in ipairs(names) do
            pcall(function() env[k] = nil end)
            print("[HYDROGEN] reset cờ toàn cục: " .. tostring(k))
        end
    end

    local switching = false
    local function backToOldMenu()
        if switching then return end
        switching = true
        print("[HYDROGEN] quay lại giao diện cũ: đóng menu này và chạy lại menu cũ")
        pcall(function() if getgenv then getgenv().HYDROGEN_GUARD_STOP = true end end)   -- vòng bảo vệ hiện tại tự dừng

        eachGui(function(g)
            if g ~= mainRef and (g:GetAttribute("HYD_classic") or isClassic(g)) then
                pcall(function() g:Destroy() end)
            end
        end)
        resetHubFlags()

        task.spawn(function()
            task.wait(CFG.TICK * 2 + 0.3)                    -- cho vòng bảo vệ cũ thoát hẳn
            pcall(function() if getgenv then getgenv().HYDROGEN_GUARD_STOP = false end end)
            local ok, src = pcall(function() return game:HttpGet(CFG.BACK_URL) end)
            if not ok or type(src) ~= "string" or #src < 1000 then
                warn("[HYDROGEN] không tải được menu cũ từ BACK_URL:", src)
                switching = false
                return
            end
            local fn, err = loadstring(src)
            if not fn then
                warn("[HYDROGEN] menu cũ bị lỗi cú pháp:", err)
                switching = false
                return
            end
            local okRun, errRun = pcall(fn)
            if not okRun then warn("[HYDROGEN] lỗi khi chạy lại menu cũ:", errRun) end
            switching = false
        end)
    end
    pcall(function() if getgenv then getgenv().HYDROGEN_BACK_TO_OLD = backToOldMenu end end)

    -- ---------- khung "Quay lại giao diện cũ" ----------
    local function buildBackPanel(container)
        local maxZ = container.ZIndex
        for _, d in ipairs(container:GetDescendants()) do
            if d:IsA("GuiObject") and d.ZIndex > maxZ then maxZ = d.ZIndex end
        end
        local holder = newInst("Frame", {
            Name = "HYD_BackPanel", BackgroundTransparency = 1, BorderSizePixel = 0,
            Size = UDim2.new(1, 0, 1, 0), ZIndex = maxZ + 1,
        }, container)
        local title = newInst("TextLabel", {
            Name = "Title", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 0.5),
            Position = UDim2.new(0, 14, 0.5, 0), Size = UDim2.new(1, -176, 0, 28),
            Font = Enum.Font.GothamBold, Text = "Quay lại giao diện cũ", TextColor3 = Color3.fromRGB(245, 225, 255),
            TextScaled = true, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left, ZIndex = maxZ + 2,
        }, holder)
        newInst("UITextSizeConstraint", { MaxTextSize = 18, MinTextSize = 10 }, title)
        local btn = newInst("TextButton", {
            Name = "SwitchBtn", AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -14, 0.5, 0),
            Size = UDim2.new(0, 140, 0, 40), BackgroundColor3 = Color3.fromRGB(122, 54, 218), BorderSizePixel = 0,
            AutoButtonColor = true, Font = Enum.Font.GothamBold, TextSize = 15, Text = "SWITCH",
            TextColor3 = Color3.new(1, 1, 1), ZIndex = maxZ + 2,
        }, holder)
        newInst("UICorner", { CornerRadius = UDim.new(0, 9) }, btn)
        btn.Activated:Connect(backToOldMenu)
        return holder
    end

    -- ---------- tìm các thành phần cần sửa ----------
    local function findWidgets(g)
        local w, copies = {}, {}
        for _, d in ipairs(g:GetDescendants()) do
            if isTextual(d) then
                local t = plainText(d.Text)
                if t ~= "" then
                    if not w.codeText and t:find("loadstring", 1, true) then
                        w.codeText = d
                    elseif d:IsA("TextButton") and (t == "sao chép" or t == "sao chep" or t == "copy" or t == "copied") then
                        copies[#copies + 1] = d
                    elseif not w.tryBtn and d:IsA("TextButton") and (t == "try ngay" or t == "try now" or t:find("^try ") or t:find("^thử ")) then
                        w.tryBtn = d
                    elseif not w.promoText and t:find("smoother, faster", 1, true) then
                        w.promoText = d
                    end
                end
            end
        end

        -- nút "Sao chép" gần khung mã nhất (điểm chung sâu nhất)
        if w.codeText and #copies > 0 then
            local bestB, bestDepth
            for _, b in ipairs(copies) do
                local l, depth = lcaOf(w.codeText, b), 0
                local cur = l
                while cur do depth = depth + 1; cur = cur.Parent end
                if not bestDepth or depth > bestDepth then bestB, bestDepth = b, depth end
            end
            w.copyBtn = bestB
        end

        -- khung logo V + chữ + nút Try
        if w.tryBtn and w.promoText then
            local card = lcaOf(w.promoText, w.tryBtn)
            local function okCard(c)
                return c and c ~= g and c:IsA("GuiObject") and not c:IsA("ScrollingFrame")
                    and not (w.codeText and isAncestorOrSelf(c, w.codeText))
                    and countButtons(c) <= 2
            end
            if okCard(card) then
                -- leo lên khi logo nằm ngoài khung nhỏ nhất, nhưng không gộp sang khung khác (giới hạn theo chiều cao)
                local base = card.AbsoluteSize.Y
                while card.Parent and okCard(card.Parent) and card.Parent.AbsoluteSize.Y <= base * 1.5 do
                    card = card.Parent
                end
                w.card = card
                for _, d in ipairs(card:GetDescendants()) do
                    if isSquareImg(d, 24, 200) then w.logo = d break end
                end
            end
        end
        return w
    end

    local classicState = setmetatable({}, { __mode = "k" })

    local function ensureBackPanel(g, st, w)
        if st.holder and st.holder.Parent then
            for _, b in ipairs(st.branches or {}) do
                if b.Parent and b.Visible then b.Visible = false end   -- hub vẽ lại thì ẩn lại
            end
            return
        end
        local container = lcaOf(w.codeText, w.copyBtn or w.codeText)
        local branches = {}
        local safe = container and container ~= g and container:IsA("GuiObject") and container ~= w.codeText
            and container.AbsoluteSize.Y <= 160 and countButtons(container) <= 2
        if safe then
            for _, c in ipairs(container:GetChildren()) do
                if c:IsA("GuiObject") and (isAncestorOrSelf(c, w.codeText) or (w.copyBtn and isAncestorOrSelf(c, w.copyBtn))) then
                    branches[#branches + 1] = c
                end
            end
            if #branches == 0 then safe = false end
        end
        if not safe then
            container = w.codeText.Parent
            branches = { w.codeText }
            if w.copyBtn then branches[#branches + 1] = w.copyBtn end
        end
        if not container or container == g or not container:IsA("GuiObject") then return end

        for _, b in ipairs(branches) do hideObj(b, g, "ẩn khung mã loadstring / Sao chép") end
        st.holder = buildBackPanel(container)
        st.branches = branches
        print("[HYDROGEN] đã thay khung mã loadstring bằng khung 'Quay lại giao diện cũ'")
    end

    local function reviseClassic(g)
        local st = classicState[g]
        if not st then st = { last = 0 }; classicState[g] = st end
        local now = os.clock()
        if now - st.last < (st.holder and 2 or 1) then return end
        st.last = now

        if not logoImage then fallbackLogo() end
        local w = findWidgets(g)

        -- logo V -> logo HYDROGEN (mọi ảnh trùng với logo V trong khung Try)
        if w.logo and not st.vImage and w.logo.Image ~= logoImage then st.vImage = w.logo.Image end
        if logoImage and st.vImage then
            for _, d in ipairs(g:GetDescendants()) do
                if isImg(d) and d.Image == st.vImage then setLogo(d) end
            end
        end

        -- ẩn khung có nút Try (hoặc chỉ nút Try nếu không xác định được khung)
        if w.tryBtn then
            if CFG.HIDE_PROMO_CARD and w.card then
                hideObj(w.card, g, "ẩn khung logo V + nút Try")
            else
                hideObj(w.tryBtn, g, "ẩn nút Try")
            end
        end

        -- thay khung mã loadstring
        if w.codeText then ensureBackPanel(g, st, w) end
    end

    -- ---------- vòng lặp chính ----------
    task.spawn(function()
        local t0 = os.clock()
        local mainGui, tabs, tabsAt, snap
        local hadMain, lastSeen = false, os.clock()
        local lastLearn, logged = 0, false

        while not (getgenv and getgenv().HYDROGEN_GUARD_STOP) do
            task.wait(CFG.TICK)

            if mainGui and not mainGui.Parent then mainGui, tabs = nil, nil end

            if not mainGui then
                eachGui(function(g)
                    if mainGui or g:GetAttribute("HYD_skip") or isClassic(g) then return end
                    local hasText = false
                    for _, d in ipairs(g:GetDescendants()) do
                        if isTxt(d) and plainText(d.Text):find("hydrogen beta v1", 1, true) then hasText = true break end
                    end
                    if hasText then
                        local tb = getTabButtons(g)
                        if tb then mainGui, tabs, tabsAt = g, tb, os.clock() end
                    end
                end)
                if mainGui then hadMain = true end
            end

            mainRef = mainGui
            local anyClassic = false

            if mainGui then
                lastSeen = os.clock()
                -- (a) icon tab
                local okT, errT = pcall(function()
                    local valid = tabs and os.clock() - tabsAt < 3
                    if valid then
                        for i = 1, 3 do if not (tabs[i] and tabs[i].Parent) then valid = false break end end
                    end
                    if not valid then tabs, tabsAt = getTabButtons(mainGui), os.clock() end
                    if not tabs or #tabs < 3 then return end
                    local b2, b3 = tabs[2], tabs[3]
                    local i2, i3 = getIcon(b2), getIcon(b3)
                    if not i2 or not i3 then return end
                    if not snap then
                        if i3:GetAttribute("HYD_tabfix_hidden") then return end
                        snap = snapshot(i3)
                    end
                    if applySnap(i2, snap) then
                        hideIcon(i3, b3)
                        if not logged then
                            logged = true
                            print("[HYDROGEN] icon trứng trắng: tab 3 -> tab 2 (" .. b2:GetFullName() .. ")")
                        end
                    end
                end)
                if not okT then warn("[HYDROGEN] tab fix:", errT) end

                -- học ảnh nền của menu chính
                if os.clock() - lastLearn > 2 then
                    lastLearn = os.clock()
                    pcall(learnBackgrounds, mainGui)
                    pcall(learnLogo, mainGui)
                end
            end

            -- (b) dọn nền sót trong menu cổ điển / ScreenGui nền mồ côi
            eachGui(function(g)
                if g == mainGui then return end
                if isClassic(g) then
                    anyClassic = true
                    purgeClassic(g)
                    verifyClassic(g)
                    local okR, errR = pcall(reviseClassic, g)
                    if not okR then warn("[HYDROGEN] sửa menu cổ điển:", errR) end
                elseif hadMain and not mainGui and g.Name ~= "SW_ConfirmHub" then
                    purgeStrayBgGui(g)
                end
            end)
            if anyClassic then lastSeen = os.clock() end

            if hadMain then
                if os.clock() - lastSeen > 60 then return end
            elseif os.clock() - t0 > 900 then
                return
            end
        end
    end)
end

local okHub, errHub = pcall(runHub)
if not okHub then warn("[HYDROGEN] lỗi phần hub:", errHub) end

-- phần 3: đổi icon tab + dọn nền (chạy ngay, không chờ FixLag)
task.spawn(function()
    local okFix, errFix = pcall(runTabAndBgFix)
    if not okFix then warn("[HYDROGEN] lỗi phần sửa tab/nền:", errFix) end
end)

-- ======================= FIXLAG (file riêng) =======================
-- FixLag đã tách thành file HYDROGEN_FixLag.lua. Điền link raw của file đó (GitHub...) vào FIXLAG_URL để tự chạy sau hub.
if FIXLAG_URL ~= "" then
    task.wait(FIXLAG_DELAY)
    local okLag, errLag = pcall(function()
        local code = game:HttpGet(FIXLAG_URL)
        local fn, perr = loadstring(code)
        if not fn then error(perr) end
        fn()
    end)
    if not okLag then warn("[HYDROGEN] không chạy được FixLag:", errLag) end
end
