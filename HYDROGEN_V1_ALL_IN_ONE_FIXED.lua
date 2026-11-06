--[[
    HYDROGEN Beta v1  (all-in-one background + switch fix)
    Chạy hub gốc từ link rồi chỉnh giao diện NGAY KHI hub dựng xong (không chờ vài giây):
      * Tên: "Chilli Hub V8 Pro" -> HYDROGEN Beta v1 (mọi chữ Chilli / Venyx -> HYDROGEN)
      * Logo: mọi chỗ có logo cũ (cạnh tiêu đề, đảo động phía trên, nút thu gọn...) -> logo Hydrogen
      * Nền cửa sổ: tạo lớp nền riêng phía sau nội dung, không ghi đè ảnh foreground
      * Thanh tab: nút tab dạng thẻ tím neon (nút đang chọn sáng hơn + thanh nhấn), icon quả egg -> trứng gà trắng nhỏ
      * Nút thu gọn: logo HÌNH TRÒN phủ kín nút; icon tiền/giây và các ảnh khác dùng chung ảnh với logo cũ KHÔNG bị đổi
      * Menu cổ điển màu đỏ (mở bằng nút "HYDROGEN"): không phủ nền, chỉ đổi đỏ -> tím (tên hub + nút tab), nền trong suốt giữ nguyên
      * Khung / thẻ trong menu hơi trong suốt (chỉ nền, chữ giữ nguyên)
      * Nút "Copy invite" Discord -> sao chép link Discord của bạn
    Ảnh logo + nền đã nhúng sẵn ở cuối file; được dựng thành file trước khi hub chạy nên hiện tức thì.
    Nếu bạn đăng lại hub này, nhớ ghi nguồn tác giả hub gốc.
]]

local CONFIG = {
    SOURCE = "https://raw.githubusercontent.com/napun67/stealanegg/refs/heads/main/chillihubv8.lua",

    -- Bấm nút "HYDROGEN V1" trên bảng điều khiển -> tải và chạy mã ở link này
    SWITCH_SOURCE = "https://raw.githubusercontent.com/ntkdgaming1234qx-prog/SOLIEY-HUB/refs/heads/main/HydrogenSwitch.lua",
    AUTO_RUN_ON_HYDROGEN = true, -- true: bấm HYDROGEN V1 là chạy mã ngay; false: dùng popup Switch dự phòng
    SWITCH_CLOSE_OLD = true,    -- true: đóng giao diện hub hiện tại trước khi chạy mã mới (tránh hai hub chồng nhau)
    NAME = "HYDROGEN BETA V1",
    HEADER_LOGO_NAMES = {},     -- (tuỳ chọn) tên đối tượng logo "V" ở thanh tiêu đề nếu muốn chỉ định tay
    TITLE = "HYDROGEN BETA V1",

    -- Nút "Copy invite" của hub sẽ sao chép link này. Thông báo "Copied discord.gg/..." cũng hiện link này.
    DISCORD_LINK = "https://discord.gg/fkswhfyqb",
    DISCORD_NAME = "SOLIEY Discord",                  -- tên hiện trên thẻ Discord của hub (thay cho "Chilli Hub Discord")
    DISCORD_SUB = "Bypass all and notifications",     -- thay dòng "Updates, keys, support" (lấy từ bản SOLIEY; để "" nếu muốn giữ nguyên)

    MENU_TRANSPARENCY = 0.35,   -- độ trong suốt của NỀN các khung/thẻ trong menu (0 = đặc, 1 = trong suốt hẳn; 0.25-0.45 là vừa). Chữ luôn giữ nguyên
    BG_DARKEN = 0.30,           -- độ phủ tối lên ảnh nền để chữ dễ đọc (0 = không phủ)

    -- true: dùng ảnh nhúng sẵn (đọc từ ổ đĩa nên hiện tức thì, cần executor có writefile + getcustomasset)
    -- false: ưu tiên ID Roblox bên dưới (phải tải qua mạng nên có thể hiện chậm)
    PREFER_EMBEDDED = true,
    LOGO_USE_ID = false,        -- true: LUÔN dùng ID LOGO_IMAGE cho logo. false: dùng ảnh nhúng (logo đầu lâu tím), ID chỉ là dự phòng
    BG_IMAGE = "rbxassetid://107298266965019",
    LOGO_IMAGE = "rbxassetid://137392525400802",

    -- Màu nền các nút tab: tím đen neon
    TAB_TOP = Color3.fromRGB(70, 20, 125),
    TAB_BOTTOM = Color3.fromRGB(10, 4, 20),
    TAB_NEON = Color3.fromRGB(176, 96, 255),
    TAB_ACCENT = Color3.fromRGB(240, 130, 255),          -- hồng tím: thanh nhấn + viền nút tab đang chọn
    TAB_ACTIVE_TOP = Color3.fromRGB(122, 54, 218),       -- nền nút tab đang chọn (trên)
    TAB_ACTIVE_BOTTOM = Color3.fromRGB(46, 16, 94),      -- nền nút tab đang chọn (dưới)
    TAB_EGG = true,                                      -- thay icon quả egg ở thanh tab bằng quả trứng gà trắng nhỏ
}

local CoreGui = game:GetService("CoreGui")
local TextService = game:GetService("TextService")
local RunService = game:GetService("RunService")
local ContentProvider = game:GetService("ContentProvider")

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

local function mk(class, props, parent)
    local o = Instance.new(class)
    o:SetAttribute("HYD_skip", true)                 -- đối tượng của script này: không đụng vào nữa
    for k, v in pairs(props or {}) do o[k] = v end
    o.Parent = parent
    return o
end

local globalZ = false                                  -- ScreenGui dùng ZIndexBehavior.Global?
local function Z(n) return globalZ and 0 or n end

-- ================= ẢNH NHÚNG: giải mã -> writefile -> getcustomasset (làm TRƯỚC khi hub chạy) =================
local DATA = {}               -- DATA.logo / DATA.bg: JPEG mã hoá base64 (gán ở cuối file)
local ASSET = {}              -- ASSET.logo / ASSET.bg: đường dẫn asset đã sẵn sàng

local function b64decode(s)
    local fns = {
        crypt and crypt.base64decode, crypt and crypt.base64 and crypt.base64.decode,
        crypt and crypt.base64_decode, base64_decode, base64 and base64.decode, base64 and base64.dec,
        syn and syn.crypt and syn.crypt.base64 and syn.crypt.base64.decode,
    }
    for i = 1, 7 do
        local fn = fns[i]
        if type(fn) == "function" then
            local ok, res = pcall(fn, s)
            if ok and type(res) == "string" and #res > 500
                and ((res:byte(1) == 255 and res:byte(2) == 216) or (res:byte(1) == 137 and res:byte(2) == 80)) then   -- JPEG hoặc PNG
                return res
            end
        end
    end
    local map = {}
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    for i = 1, 64 do map[chars:byte(i)] = i - 1 end
    local out, o, i, len = {}, 0, 1, #s
    while i <= len do
        local a, b, c, d = s:byte(i, i + 3)
        local n = (map[a] or 0) * 262144 + (map[b] or 0) * 4096 + (map[c] or 0) * 64 + (map[d] or 0)
        local b1 = math.floor(n / 65536)
        local b2 = math.floor(n / 256) % 256
        local b3 = n % 256
        o = o + 1
        if c == 61 then
            out[o] = string.char(b1)
        elseif d == 61 then
            out[o] = string.char(b1, b2)
        else
            out[o] = string.char(b1, b2, b3)
        end
        i = i + 4
        if o % 30000 == 0 then task.wait() end
    end
    return table.concat(out)
end

local function prepareAssets()
    local gca = getcustomasset or getsynasset
    local ids = { logo = CONFIG.LOGO_IMAGE, bg = CONFIG.BG_IMAGE }
    local embedded = {}
    if writefile and gca then
        for _, key in ipairs({ "logo", "bg", "egg" }) do
            if DATA[key] then
                local ok, res = pcall(function()
                    local data = b64decode(DATA[key])
                    local fname = "hydrogen_" .. key .. (key == "egg" and ".png" or ".jpg")
                    writefile(fname, data)
                    return gca(fname)
                end)
                if ok and res and res ~= "" then
                    embedded[key] = res
                else
                    warn("[HYDROGEN] không dựng được ảnh nhúng " .. key .. ":", res)
                end
            end
        end
    else
        warn("[HYDROGEN] executor không hỗ trợ writefile/getcustomasset: dùng ID Roblox (có thể hiện chậm hơn)")
    end
    for _, key in ipairs({ "logo", "bg" }) do
        local id = ids[key]
        local preferEmb = CONFIG.PREFER_EMBEDDED
        if key == "logo" and CONFIG.LOGO_USE_ID and id ~= "" then preferEmb = false end
        if preferEmb then
            ASSET[key] = embedded[key] or (id ~= "" and id or nil)
        else
            ASSET[key] = (id ~= "" and id or nil) or embedded[key]
        end
    end
    ASSET.egg = embedded.egg                          -- icon quả trứng gà trắng (chỉ có bản nhúng; không có thì tab dùng trứng vẽ bằng khung)
    -- nạp sẵn vào bộ nhớ để lúc đổi ảnh hiện ngay, không bị nháy trống
    local list = {}
    for _, key in ipairs({ "logo", "bg", "egg" }) do
        if ASSET[key] then table.insert(list, ASSET[key]) end
    end
    if #list > 0 then
        local done = false
        task.spawn(function()
            pcall(function() ContentProvider:PreloadAsync(list) end)
            done = true
        end)
        local t0 = os.clock()
        while not done and os.clock() - t0 < 1.5 do task.wait() end
    end
    print("[HYDROGEN] ảnh sẵn sàng: logo=" .. tostring(ASSET.logo ~= nil) .. ", nền=" .. tostring(ASSET.bg ~= nil))
end

-- ================= ĐỔI TÊN =================
local function brand(s)
    local T, N = CONFIG.TITLE, CONFIG.NAME
    -- thẻ Discord của hub: dòng phụ + tên (phải xử lý TRƯỚC khi đổi Chilli/Venyx thành HYDROGEN)
    if CONFIG.DISCORD_SUB ~= "" and #s <= 60 then
        local ls = s:lower()
        if ls:find("updates", 1, true) and ls:find("keys", 1, true) and ls:find("support", 1, true) then
            return CONFIG.DISCORD_SUB
        end
    end
    local DN = CONFIG.DISCORD_NAME
    for _, pat in ipairs({
        "%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s+[Hh][Uu][Bb]%s+[Dd][Ii][Ss][Cc][Oo][Rr][Dd]%f[%W]",
        "%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s+[Dd][Ii][Ss][Cc][Oo][Rr][Dd]%f[%W]",
        "%f[%w][Vv][Ee][Nn][Yy][Xx]%s+[Dd][Ii][Ss][Cc][Oo][Rr][Dd]%f[%W]",
        "%f[%w][Hh][Yy][Dd][Rr][Oo][Gg][Ee][Nn]%s+[Dd][Ii][Ss][Cc][Oo][Rr][Dd]%f[%W]",
    }) do
        s = s:gsub(pat, DN)
    end
    s = s:gsub("%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s+[Hh][Uu][Bb]%s*[Vv]8%s+[Pp][Rr][Oo]%f[%W]", T)
    s = s:gsub("%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s+[Hh][Uu][Bb]%s*[Vv]8%f[%W]", T)
    s = s:gsub("%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s+[Hh][Uu][Bb]%f[%W]", N)
    for _, sep in ipairs({ "×", "•", "[xX&%+]" }) do   -- "Venyx × Chilli" / "Chilli × Venyx" -> một tên
        s = s:gsub("%f[%w][Vv][Ee][Nn][Yy][Xx]%s*" .. sep .. "%s*[Cc][Hh][Ii][Ll][Ll][Ii]%f[%W]", N)
        s = s:gsub("%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%s*" .. sep .. "%s*[Vv][Ee][Nn][Yy][Xx]%f[%W]", N)
    end
    s = s:gsub("%f[%w][Vv][Ee][Nn][Yy][Xx]%f[%W]", N)
    s = s:gsub("%f[%w][Cc][Hh][Ii][Ll][Ll][Ii]%f[%W]", N)
    -- thông báo của hub ("Copied discord.gg/xxxx"): luôn hiện link Discord của bạn
    local code = CONFIG.DISCORD_LINK:match("discord%.gg/([%w_%-]+)")
    if code then
        s = s:gsub("discord%.gg/[%w_%-]+", "discord.gg/" .. code)
        s = s:gsub("dsc%.gg/[%w_%-]+", "discord.gg/" .. code)
        s = s:gsub("discord%.com/invite/[%w_%-]+", "discord.gg/" .. code)
    end
    return s
end

-- co cỡ chữ cho vừa nhãn (tên mới dài hơn tên cũ)
local fitCache = {}
local function fitText(obj)
    if obj.TextWrapped or obj.TextScaled then return end
    local w = obj.AbsoluteSize.X
    if w <= 8 then return end
    local base = obj:GetAttribute("HYD_basesize")
    if not base then
        base = obj.TextSize
        obj:SetAttribute("HYD_basesize", base)
    end
    local size, txt = base, obj.Text
    while size > 9 do
        local key = obj.Font.Name .. "|" .. size .. "|" .. txt
        local tw = fitCache[key]
        if not tw then
            local ok, b = pcall(function() return TextService:GetTextSize(txt, size, obj.Font, Vector2.new(10000, 10000)) end)
            if not ok then break end
            tw = b.X
            fitCache[key] = tw
        end
        if tw <= w - 4 then break end
        size = size - 1
    end
    if obj.TextSize ~= size then obj.TextSize = size end
end

-- ================= NÚT SAO CHÉP LỜI MỜI DISCORD =================
-- (lấy từ bản SOLIEY) Phủ một nút trong suốt lên đúng nút "Copy invite" của hub:
-- bấm vào sẽ sao chép link Discord của bạn (CONFIG.DISCORD_LINK). Nút phủ chặn cú bấm nên
-- chức năng sao chép link cũ của hub không chạy nữa; thông báo "Copied discord.gg/..." cũng đổi sang link của bạn.
local function nearestButton(obj)
    local p = obj
    for _ = 0, 4 do
        if not p or p:IsA("ScreenGui") then return nil end
        if p:IsA("TextButton") or p:IsA("ImageButton") then return p end
        p = p.Parent
    end
    return nil
end

local function waitSize(obj)
    local n = 0
    while obj.AbsoluteSize.X == 0 and n < 10 do
        task.wait(0.1)
        n = n + 1
    end
end

local function discordButtonTarget(obj)
    local b = nearestButton(obj)
    if b and b.AbsoluteSize.Y <= 80 and b.AbsoluteSize.X <= 450 then return b end
    local best, p = obj, obj.Parent
    while p and p:IsA("GuiObject") do
        local sz = p.AbsoluteSize
        if sz.Y > 60 or sz.X > 400 then break end
        best = p
        p = p.Parent
    end
    return best
end

local function hookDiscordCopy(target)
    if target:GetAttribute("HYD_dc") then return end
    target:SetAttribute("HYD_dc", true)

    -- nơi đặt nút phủ: tổ tiên không có layout tự xếp chỗ (tránh làm lệch giao diện)
    local par = target.Parent
    while par and par:IsA("GuiObject") and (par:FindFirstChildWhichIsA("UIListLayout") or par:FindFirstChildWhichIsA("UIGridLayout")
        or par:FindFirstChildWhichIsA("UIPageLayout") or par:FindFirstChildWhichIsA("UITableLayout")) do
        par = par.Parent
    end
    if not (par and par:IsA("GuiObject")) then par = target.Parent end
    if not par then return end

    local ov = mk("TextButton", {
        Name = "HYDROGEN_DiscordCopy", BackgroundTransparency = 1, BorderSizePixel = 0, Text = "",
        AutoButtonColor = false, Active = true, Size = UDim2.new(0, 100, 0, 30),
        Font = Enum.Font.GothamBold, TextSize = 13, TextColor3 = Color3.new(1, 1, 1),
        ZIndex = target.ZIndex + 50,
    }, par)
    local uc = Instance.new("UICorner", ov)
    uc.CornerRadius = UDim.new(0, 6)
    local srcCorner = target:FindFirstChildOfClass("UICorner")
    if srcCorner then uc.CornerRadius = srcCorner.CornerRadius end

    local sc = 1
    if ov.AbsoluteSize.X > 0 then sc = ov.AbsoluteSize.X / 100 end

    local function sync()
        if not (target.Parent and ov.Parent) then return end
        local tp, ts = target.AbsolutePosition, target.AbsoluteSize
        local base = par.AbsolutePosition
        ov.Size = UDim2.new(0, ts.X / sc, 0, ts.Y / sc)
        ov.Position = UDim2.new(0, (tp.X - base.X) / sc, 0, (tp.Y - base.Y) / sc)
        local ap = ov.AbsolutePosition                        -- sửa lệch do UIPadding...
        local dx, dy = tp.X - ap.X, tp.Y - ap.Y
        if math.abs(dx) > 0.5 or math.abs(dy) > 0.5 then
            ov.Position = UDim2.new(0, ov.Position.X.Offset + dx / sc, 0, ov.Position.Y.Offset + dy / sc)
        end
        ov.Visible = target.Visible and ts.X > 0
    end
    sync()
    target:GetPropertyChangedSignal("AbsolutePosition"):Connect(sync)
    target:GetPropertyChangedSignal("AbsoluteSize"):Connect(sync)
    target:GetPropertyChangedSignal("Visible"):Connect(sync)

    local busy = false
    ov.Activated:Connect(function()
        if busy then return end
        busy = true
        local fn = setclipboard or toclipboard or set_clipboard or (Clipboard and Clipboard.set)
        local ok = false
        if fn then
            ok = pcall(fn, CONFIG.DISCORD_LINK)
            task.delay(0.3, function() pcall(fn, CONFIG.DISCORD_LINK) end)     -- phòng hub gốc ghi đè sau cú bấm
        end
        local bgc = Color3.fromRGB(88, 101, 242)
        if target:IsA("GuiObject") and target.BackgroundTransparency < 1 then bgc = target.BackgroundColor3 end
        ov.BackgroundColor3 = bgc
        ov.BackgroundTransparency = 0
        ov.Text = ok and ("✓ " .. CONFIG.DISCORD_LINK:gsub("^https?://", "")) or "Lỗi"
        print("[HYDROGEN] đã sao chép link Discord:", CONFIG.DISCORD_LINK)
        task.wait(1.5)
        ov.Text = ""
        ov.BackgroundTransparency = 1
        busy = false
    end)
end



local STOPPED = false      -- true sau khi đã Switch: script này ngừng can thiệp giao diện
local SW = {}              -- hệ thống nút HYDROGEN -> Switch (định nghĩa bên dưới)

local function apply(obj)
    if STOPPED or not obj.Parent or obj:GetAttribute("HYD_skip") then return end
    if obj:GetAttribute("HYD_title") then              -- nhãn tiêu đề của hub: luôn là "HYDROGEN Beta v1"
        if obj.Text ~= CONFIG.TITLE then
            obj.Text = CONFIG.TITLE
            pcall(fitText, obj)
        end
        return
    end
    if obj:IsA("TextBox") then
        local ph = obj.PlaceholderText
        local r = brand(ph)
        if r ~= ph then obj.PlaceholderText = r end
        return
    end
    local raw = obj.Text
    local l = raw:lower()
    if not l:find("webhook", 1, true) and #raw <= 60 and not obj:GetAttribute("HYD_dcseen") then
        if l:find("invite", 1, true) or (l:find("copy", 1, true) and (l:find("link", 1, true) or l:find("discord", 1, true)))
            or (l:find("join", 1, true) and l:find("discord", 1, true)) then
            obj:SetAttribute("HYD_dcseen", true)
            task.spawn(function()                         -- chờ kích thước xong rồi mới gắn nút phủ
                waitSize(obj)
                local tgt = discordButtonTarget(obj)
                if tgt then pcall(hookDiscordCopy, tgt) end
            end)
        end
    end
    local r = brand(raw)
    if r ~= raw then
        obj.Text = r
        pcall(fitText, obj)
    end
    if SW.consider then pcall(SW.consider, obj, r) end
end

-- ================= HÀNG ĐỢI cho chữ đổi liên tục (đồng hồ, số...): tối đa ~4ms mỗi khung hình =================
local Q, Qhead, Qtail = {}, 1, 0
local queuedApply = setmetatable({}, { __mode = "k" })

local function pushApply(obj)
    if queuedApply[obj] then return end
    queuedApply[obj] = true
    Qtail = Qtail + 1
    Q[Qtail] = obj
end

RunService.Heartbeat:Connect(function()
    if STOPPED or Qhead > Qtail then return end
    local t0, n = os.clock(), 0
    while Qhead <= Qtail and n < 80 and os.clock() - t0 < 0.004 do
        local obj = Q[Qhead]
        Q[Qhead] = nil
        Qhead = Qhead + 1
        n = n + 1
        queuedApply[obj] = nil
        if obj.Parent then pcall(apply, obj) end
    end
    if Qhead > Qtail then Qhead, Qtail = 1, 0 end
end)

-- ================= GUI CỦA HUB =================
local containers = { CoreGui }
pcall(function() if gethui then table.insert(containers, gethui()) end end)
pcall(function()
    local pg = game:GetService("Players").LocalPlayer:FindFirstChildOfClass("PlayerGui")
    if pg then table.insert(containers, pg) end
end)

local existing = {}
for _, c in ipairs(containers) do
    for _, g in ipairs(c:GetChildren()) do existing[g] = true end
end

local watchUntil = math.huge
local targetSet = setmetatable({}, { __mode = "k" })

local function isTarget(gui)
    if STOPPED then return false end
    if not gui or not gui:IsA("ScreenGui") then return false end
    if targetSet[gui] then return true end
    local n = gui.Name:lower()
    if n:find("chilli", 1, true) or n:find("venyx", 1, true) or n:find("hydrogen", 1, true) then
        targetSet[gui] = true
        return true
    end
    if existing[gui] then return false end
    if gui.Parent and gui.Parent:IsA("PlayerGui") then return false end    -- GUI của game: không đụng vào
    if os.clock() <= watchUntil then
        targetSet[gui] = true
        return true
    end
    return false
end

-- ================= NÚT "HYDROGEN V1" -> CHẠY MÃ Ở CONFIG.SWITCH_SOURCE =================
-- Tạo nút HYDROGEN V1 mới phủ lên nút HYDROGEN cũ. Khi bấm nút mới, tải mã mới,
-- đóng giao diện hub hiện tại (nếu SWITCH_CLOSE_OLD), rồi mới chạy mã mới.
local switchArmedUntil = 0
local switchRunning = false
local hookedClicks = setmetatable({}, { __mode = "k" })
local promptGui
local trackedMainGui -- ScreenGui chứa cửa sổ chính, dùng để dọn đúng GUI khi Switch

local function plain(str) return trim((str:gsub("<[^>]+>", ""))) end

local function hookClick(target, fn)
    local set = hookedClicks[target]
    if not set then set = {}; hookedClicks[target] = set end
    if set[fn] then return end
    set[fn] = true
    if target:IsA("GuiButton") then
        target.Activated:Connect(function() pcall(fn) end)
    else
        target.InputBegan:Connect(function(i)
            if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
                pcall(fn)
            end
        end)
    end
end

-- thẻ/nút chứa nhãn: nút gần nhất, rồi leo lên các khung bao quanh còn nhỏ (<= 300x100) để bấm đâu trong thẻ cũng ăn
local function cardTarget(obj)
    local best = nearestButton(obj) or obj
    local p = best.Parent
    while p and p:IsA("GuiObject") do
        local s2 = p.AbsoluteSize
        if s2.X <= 0 or s2.X > 300 or s2.Y > 100 then break end
        best = p
        p = p.Parent
    end
    return best
end

local function closeOldHub()
    -- Ưu tiên ScreenGui thực sự chứa cửa sổ chính; không chỉ dựa vào tên ScreenGui.
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and g ~= promptGui then
                local n = g.Name:lower()
                if g == trackedMainGui or targetSet[g]
                    or n:find("chilli", 1, true) or n:find("venyx", 1, true) or n:find("hydrogen", 1, true) then
                    pcall(function()
                        g.Enabled = false
                        g:Destroy()
                    end)
                end
            end
        end
    end

    -- Dọn các lớp nền được đánh dấu nếu chúng vô tình nằm ngoài ScreenGui cũ.
    for _, c in ipairs(containers) do
        local descendants = {}
        pcall(function() descendants = c:GetDescendants() end)
        for _, d in ipairs(descendants) do
            local n = d.Name:lower()
            if d:GetAttribute("HYD_background") or n == "hydrogen_bg" or n == "hyd_darken" then
                pcall(function() d:Destroy() end)
            end
        end
    end
end

local function runSwitchScript()
    if switchRunning then return end
    switchRunning = true
    if promptGui then pcall(function() promptGui:Destroy() end); promptGui = nil end
    task.spawn(function()
        local okG, src = pcall(function() return game:HttpGet(CONFIG.SWITCH_SOURCE) end)
        if not okG or type(src) ~= "string" or #src == 0 then
            warn("[HYDROGEN] Switch: không tải được mã từ link:", src)
            switchRunning = false
            return
        end
        -- ALL-IN-ONE PATCH: inject the background fix into the downloaded Switch loader.
        -- The loader applies it to its own remote style source before compiling that source.
        local switchPatch = [====[
source = replaceOnce(
    source,
    "local function findMainWindow%(%).-local function depthOf",
    [[local function findMainWindow()
    local cands = {}
    local function collect(o, depth, screen)
        for _, ch in ipairs(o:GetChildren()) do
            if ch:IsA("GuiObject") and not ch:GetAttribute("HYD_skip") then
                local s = ch.AbsoluteSize
                local fullScreen = screen.X > 0 and s.X >= screen.X * 0.9 and s.Y >= screen.Y * 0.9
                -- Wallpaper/illustration ImageLabels are not window containers.
                local isWindowContainer = ch:IsA("Frame") or ch:IsA("ScrollingFrame") or ch:IsA("CanvasGroup")
                if isWindowContainer and ch.Visible and s.X >= 300 and s.Y >= 200 and not fullScreen then
                    table.insert(cands, { object = ch, area = s.X * s.Y, depth = depth })
                end
                if depth < 3 then collect(ch, depth + 1, screen) end
            end
        end
    end
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and isTarget(g) and not isClassicGui(g) and (not hadMain or guiSettled(g)) then
                collect(g, 0, g.AbsoluteSize)
            end
        end
    end
    local best
    for _, item in ipairs(cands) do
        if not best or item.area > best.area
            or (item.area == best.area and item.depth < best.depth) then
            best = item
        end
    end
    return best and best.object or nil
end
local function depthOf]],
    "main-window container detection"
)

-- 2) Never overwrite an arbitrary large foreground image with the wallpaper.
--    Build a separate low-ZIndex background and make only old full-window
--    background surfaces transparent.
source = replaceOnce(
    source,
    "    if swapBackgroundImage%(main%) then.-    end\n    softenAll%(main%)",
    [[    clearOldBackgrounds(main)
    buildBackground(main)
    print("[HYDROGEN] da tao lop nen rieng phia sau noi dung")
    softenAll(main)]],
    "dedicated background layer"
)
]====]
        if not src:find("HYDROGEN PRO V1 - BACKGROUND LAYER FIX", 1, true) then
            local marker = "local injection ="
            local at = src:find(marker, 1, true)
            if at then
                src = src:sub(1, at - 1) .. "\n-- HYDROGEN PRO V1 - BACKGROUND LAYER FIX (embedded)\n" .. switchPatch .. "\n\n" .. src:sub(at)
                print("[HYDROGEN] Switch: da tich hop ban va nen vao loader")
            else
                warn("[HYDROGEN] Switch: khong tim thay diem chen patch trong loader; se chay ban goc")
            end
        end
        local fn, err = loadstring(src)
        if not fn then
            warn("[HYDROGEN] Switch: mã tải về bị lỗi cú pháp:", err)
            switchRunning = false
            return
        end
        if CONFIG.SWITCH_CLOSE_OLD then
            STOPPED = true                      -- ngừng chỉnh giao diện để không chồng lên hub mới
            closeOldHub()
            task.wait(0.3)
        end
        print("[HYDROGEN] Switch: đang chạy mã mới")
        local ok, e = pcall(fn)
        if not ok then warn("[HYDROGEN] Switch: lỗi khi chạy mã mới:", e) end
        if not STOPPED then task.delay(3, function() switchRunning = false end) end
    end)
end

local function isSwitchText(txt)
    local t = plain(txt):lower()
    return t == "switch" or t == "swicth"
end

local function hookSwitchObj(d)
    if d:GetAttribute("HYD_swhooked") then return true end
    local tgt = nearestButton(d) or cardTarget(d)
    if not tgt then return false end
    d:SetAttribute("HYD_swhooked", true)
    hookClick(tgt, runSwitchScript)
    local btn = nearestButton(d)
    if btn and btn ~= tgt then hookClick(btn, runSwitchScript) end
    print("[HYDROGEN] đã gắn nút Switch:", d:GetFullName())
    return true
end

local function showSwitchPrompt()
    if STOPPED or (promptGui and promptGui.Parent) then return end
    local parent
    pcall(function() if gethui then parent = gethui() end end)
    parent = parent or CoreGui
    local g = Instance.new("ScreenGui")
    g.Name = "SW_Prompt" .. tostring(math.random(1000, 9999))
    g.ResetOnSpawn = false
    g.DisplayOrder = 999999
    g.IgnoreGuiInset = true
    g:SetAttribute("HYD_skip", true)
    existing[g] = true                                   -- không coi là GUI của hub
    g.Parent = parent
    promptGui = g

    local box = mk("Frame", {
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0, 300, 0, 140),
        BackgroundColor3 = Color3.fromRGB(14, 8, 26), BackgroundTransparency = 0.04, BorderSizePixel = 0, Active = true,
    }, g)
    mk("UICorner", { CornerRadius = UDim.new(0, 12) }, box)
    mk("UIStroke", { Color = Color3.fromRGB(190, 55, 255), Thickness = 2, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, box)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 10), Size = UDim2.new(1, -52, 0, 24),
        Font = Enum.Font.GothamBold, TextSize = 17, TextColor3 = Color3.new(1, 1, 1),
        TextXAlignment = Enum.TextXAlignment.Left, Text = "HYDROGEN",
    }, box)
    mk("TextLabel", {
        BackgroundTransparency = 1, Position = UDim2.new(0, 14, 0, 38), Size = UDim2.new(1, -28, 0, 36),
        Font = Enum.Font.Gotham, TextSize = 13, TextColor3 = Color3.fromRGB(205, 190, 235), TextWrapped = true,
        TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top,
        Text = "Bấm Switch để chuyển sang HYDROGEN PRO V1.",
    }, box)
    local sw = mk("TextButton", {
        Position = UDim2.new(0, 14, 1, -52), Size = UDim2.new(1, -28, 0, 38), BackgroundColor3 = Color3.fromRGB(122, 54, 218),
        BorderSizePixel = 0, AutoButtonColor = true, Font = Enum.Font.GothamBold, TextSize = 15,
        TextColor3 = Color3.new(1, 1, 1), Text = "Switch",
    }, box)
    mk("UICorner", { CornerRadius = UDim.new(0, 8) }, sw)
    local x = mk("TextButton", {
        AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -8, 0, 8), Size = UDim2.new(0, 26, 0, 26),
        BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = 16, TextColor3 = Color3.fromRGB(205, 190, 235), Text = "✕",
    }, box)
    sw.Activated:Connect(function() runSwitchScript() end)
    x.Activated:Connect(function()
        pcall(function() g:Destroy() end)
        promptGui = nil
    end)
end

local lastHydClick = 0
local function scanForSwitch()
    local found = false
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            local inPlayerGui = g.Parent and g.Parent:IsA("PlayerGui")
            if g:IsA("ScreenGui") and g ~= promptGui and (targetSet[g] or (not existing[g] and not inPlayerGui)) then
                for _, d in ipairs(g:GetDescendants()) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("HYD_skip") and isSwitchText(d.Text) then
                        if hookSwitchObj(d) then found = true end
                    end
                end
            end
        end
    end
    return found
end

local function onHydrogenClick()
    if STOPPED or os.clock() - lastHydClick < 0.6 then return end
    lastHydClick = os.clock()
    if CONFIG.AUTO_RUN_ON_HYDROGEN then
        runSwitchScript()                       -- tải mã -> tắt menu hiện tại -> chạy mã / hiện menu mới
        return
    end
    switchArmedUntil = os.clock() + 120
    task.spawn(function()
        local t0, found = os.clock(), false
        while os.clock() - t0 < 6 and not STOPPED do
            task.wait(0.5)
            if scanForSwitch() then found = true end
        end
        if not found and not STOPPED then showSwitchPrompt() end     -- không thấy nút Switch nào: hiện bảng có sẵn nút Switch
    end)
end

-- gọi từ apply(): nhận ra nút "HYDROGEN" (nằm trong một nút nhỏ, không phải tiêu đề) và nhãn "Switch" xuất hiện sau khi đã bấm HYDROGEN
local function createHydrogenOverlay(textObj, target)
    if not target or not target:IsA("GuiButton") then return false end
    if target:GetAttribute("HYD_overlay_ready") then return true end

    -- Nút mới nằm ngay trong nút cũ, phủ kín vùng bấm; phần nền/icon cũ vẫn được giữ lại.
    local topZ = target.ZIndex
    for _, child in ipairs(target:GetDescendants()) do
        if child:IsA("GuiObject") then topZ = math.max(topZ, child.ZIndex) end
    end

    local overlay = Instance.new("TextButton")
    overlay.Name = "HYDROGEN_V1_OverlayButton"
    overlay:SetAttribute("HYD_skip", true)
    overlay.BackgroundTransparency = 1
    overlay.BorderSizePixel = 0
    overlay.AutoButtonColor = false
    overlay.Active = true
    overlay.Selectable = true
    overlay.Text = ""
    overlay.Position = UDim2.fromScale(0, 0)
    overlay.Size = UDim2.fromScale(1, 1)
    overlay.ZIndex = topZ + 20
    overlay.Parent = target

    local label = Instance.new("TextLabel")
    label.Name = "HYDROGEN_V1_OverlayText"
    label:SetAttribute("HYD_skip", true)
    label.BackgroundTransparency = 1
    label.BorderSizePixel = 0
    label.Text = "HYDROGEN V1"
    label.TextColor3 = textObj.TextColor3
    label.Font = textObj.Font
    label.TextSize = textObj.TextSize
    label.TextScaled = textObj.TextScaled
    label.TextWrapped = textObj.TextWrapped
    label.TextXAlignment = textObj.TextXAlignment
    label.TextYAlignment = textObj.TextYAlignment
    label.TextStrokeColor3 = textObj.TextStrokeColor3
    label.TextStrokeTransparency = textObj.TextStrokeTransparency
    label.RichText = textObj.RichText
    label.ZIndex = overlay.ZIndex + 1
    label.Parent = overlay

    local function syncLabel()
        if not (overlay.Parent and target.Parent and textObj.Parent) then return end
        local targetSize = target.AbsoluteSize
        if targetSize.X <= 0 or targetSize.Y <= 0 then return end
        if textObj == target then
            label.Position = UDim2.fromScale(0, 0)
            label.Size = UDim2.fromScale(1, 1)
        else
            local targetPos = target.AbsolutePosition
            local textPos = textObj.AbsolutePosition
            local textSize = textObj.AbsoluteSize
            label.Position = UDim2.fromScale(
                (textPos.X - targetPos.X) / targetSize.X,
                (textPos.Y - targetPos.Y) / targetSize.Y
            )
            label.Size = UDim2.fromScale(
                textSize.X / targetSize.X,
                textSize.Y / targetSize.Y
            )
        end
    end

    -- Ẩn chữ cũ nhưng giữ nguyên nút, nền, icon, viền và bố cục gốc.
    pcall(function() textObj.TextTransparency = 1 end)
    pcall(function() textObj.TextStrokeTransparency = 1 end)
    textObj:GetPropertyChangedSignal("TextTransparency"):Connect(function()
        if textObj.Parent and textObj.TextTransparency < 1 then
            textObj.TextTransparency = 1
        end
    end)
    textObj:GetPropertyChangedSignal("Text"):Connect(function()
        if label.Parent then label.Text = "HYDROGEN V1" end
        if textObj.Parent and textObj.TextTransparency < 1 then
            textObj.TextTransparency = 1
        end
    end)

    target:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncLabel)
    target:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncLabel)
    textObj:GetPropertyChangedSignal("AbsolutePosition"):Connect(syncLabel)
    textObj:GetPropertyChangedSignal("AbsoluteSize"):Connect(syncLabel)
    syncLabel()

    overlay.Activated:Connect(function()
        if not switchRunning and not STOPPED then
            runSwitchScript()
        end
    end)

    target:SetAttribute("HYD_overlay_ready", true)
    print("[HYDROGEN] đã tạo nút HYDROGEN V1 phủ lên nút cũ:", target:GetFullName())
    return true
end

-- Tìm đúng nút nhanh cũ, tạo một nút mới phủ kín lên nó.
SW.consider = function(obj, r)
    if STOPPED or not (obj:IsA("TextLabel") or obj:IsA("TextButton")) then return end
    if obj:GetAttribute("HYD_swseen") then return end
    local t = plain(r):lower()
    if t == "hydrogen" or t == "hydrogen v1" then
        task.spawn(function()
            waitSize(obj)
            if STOPPED or not obj.Parent then return end
            local btn = nearestButton(obj)
            if not btn then return end
            local bs = btn.AbsoluteSize
            if bs.Y > 90 or bs.X > 300 or bs.X <= 0 or bs.Y <= 0 then return end
            if createHydrogenOverlay(obj, btn) then
                obj:SetAttribute("HYD_swseen", true)
            end
        end)
    elseif isSwitchText(r) and os.clock() <= switchArmedUntil then
        obj:SetAttribute("HYD_swseen", true)
        task.spawn(function()
            waitSize(obj)
            if not STOPPED and obj.Parent then hookSwitchObj(obj) end
        end)
    end
end

-- ================= MENU CỔ ĐIỂN MÀU ĐỎ (mở bằng nút "HYDROGEN" trên bảng điều khiển) =================
-- Không coi là cửa sổ chính: không phủ ảnh nền / làm trong suốt / đổi logo lên nó. Chỉ đổi đỏ -> tím (recolorClassic).
local mainWindow                                          -- cửa sổ chính của hub (gán trong setupMain)
local hadMain = false                                     -- đã từng có cửa sổ chính (biết khi hub bị đóng / đổi menu)
local guiBorn = setmetatable({}, { __mode = "k" })
local guiAdded = setmetatable({}, { __mode = "k" })
local classicSet = setmetatable({}, { __mode = "k" })
local classicChecked = setmetatable({}, { __mode = "k" })

local function isRedColor(c)
    local h, s, v = c:ToHSV()
    return (h <= 0.04 or h >= 0.96) and s >= 0.5 and v >= 0.3
end

local function isClassicGui(g)
    if classicSet[g] then return true end
    if mainWindow and mainWindow.Parent and g == mainWindow:FindFirstAncestorOfClass("ScreenGui") then return false end
    local t = classicChecked[g]
    if t and os.clock() - t < 2 then return false end
    classicChecked[g] = os.clock()
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
                    classicSet[g] = true
                    return true
                end
            end
        end
    end
    return false
end

-- GUI mới xuất hiện sau khi cửa sổ chính đã mất: đợi nó dựng xong (yên ~1.2s) rồi mới xét, để không nhận nhầm
local function guiSettled(g)
    local b = guiBorn[g]
    if not b then return true end
    local now = os.clock()
    return now - b > 8 or now - (guiAdded[g] or b) > 1.2
end

-- ================= NHẬN DIỆN CỬA SỔ CHÍNH =================
local function findMainWindow()
    local cands = {}
    local function collect(o, depth, screen)
        for _, ch in ipairs(o:GetChildren()) do
            if ch:IsA("GuiObject") and not ch:GetAttribute("HYD_skip") then
                local s = ch.AbsoluteSize
                local fullScreen = screen.X > 0 and s.X >= screen.X * 0.9 and s.Y >= screen.Y * 0.9
                -- Chỉ nhận Frame/ScrollingFrame làm khung cửa sổ. ImageLabel lớn thường là
                -- wallpaper/ảnh trang trí; chọn nhầm nó sẽ biến ảnh nền thành một lớp phủ.
                local isWindowContainer = ch:IsA("Frame") or ch:IsA("ScrollingFrame") or ch:IsA("CanvasGroup")
                if isWindowContainer and ch.Visible and s.X >= 300 and s.Y >= 200 and not fullScreen then
                    table.insert(cands, { object = ch, area = s.X * s.Y, depth = depth })
                end
                if depth < 3 then collect(ch, depth + 1, screen) end
            end
        end
    end
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and isTarget(g) and not isClassicGui(g) and (not hadMain or guiSettled(g)) then
                collect(g, 0, g.AbsoluteSize)
            end
        end
    end
    local best
    for _, item in ipairs(cands) do
        if not best or item.area > best.area
            or (item.area == best.area and item.depth < best.depth) then
            best = item
        end
    end
    return best and best.object or nil
end

local function depthOf(obj, gui)
    local d, p = 0, obj.Parent
    while p and p ~= gui do d = d + 1; p = p.Parent end
    if p == gui then return d end
    return 99
end

local function isAvatarLike(d)
    local function bad(str)
        local l = str:lower()
        return l:find("rbxthumb", 1, true) or l:find("headshot", 1, true) or l:find("avatar", 1, true) or l:find("profile", 1, true)
    end
    if bad(d.Name) then return true end
    if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and bad(d.Image) then return true end
    for _, c in ipairs(d:GetDescendants()) do
        if (c:IsA("ImageLabel") or c:IsA("ImageButton")) and bad(c.Image) then return true end
    end
    return false
end

-- ================= LOGO: đổi TRỰC TIẾP ảnh của mọi chỗ có logo cũ =================
local oldLogoSet = {}           -- chuỗi Image của các logo cũ đã nhận diện
local swappedCount = 0

local function applyLogo(img)
    if not ASSET.logo then return end
    if img.Image ~= ASSET.logo then img.Image = ASSET.logo end
    img.ImageRectOffset = Vector2.new(0, 0)             -- bỏ cắt sprite-sheet của ảnh cũ
    img.ImageRectSize = Vector2.new(0, 0)
    img.ImageColor3 = Color3.new(1, 1, 1)
    img.ScaleType = Enum.ScaleType.Crop
end

local function swapLogo(img)
    local s = img.Image
    if s ~= "" and s ~= ASSET.logo and s ~= ASSET.bg then oldLogoSet[s] = true end
    if not img:GetAttribute("HYD_logo") then
        img:SetAttribute("HYD_logo", true)
        swappedCount = swappedCount + 1
        img:GetPropertyChangedSignal("Image"):Connect(function()      -- hub đặt lại ảnh cũ -> đổi lại ngay
            local cur = img.Image
            if cur ~= ASSET.logo and oldLogoSet[cur] then applyLogo(img) end
        end)
    end
    applyLogo(img)
end

local function squareish(s)
    return s.X >= 18 and s.Y >= 18 and math.abs(s.X - s.Y) <= math.max(6, 0.2 * math.max(s.X, s.Y))
end

local function stripTags(t) return (t:gsub("<[^>]+>", "")) end

-- vị trí của một logo: góc trái trên thanh tiêu đề cửa sổ, hoặc nằm ngoài cửa sổ (đảo động, nút thu gọn nổi...)
local function logoLocation(d, s, gui, main, mp)
    if d:IsDescendantOf(main) then
        local p = d.AbsolutePosition
        return s.X <= 56 and (p.X - mp.X) <= 90 and (p.Y - mp.Y) <= 56
    end
    return depthOf(d, gui) <= 2 and s.X >= 30 and s.X <= 160
end

-- logo vẽ bằng CHỮ (ví dụ chữ "V" kèm "×"): xoá chữ và đặt ảnh logo mới vào đúng khung đó
local function swapTextLogo(obj)
    if obj:GetAttribute("HYD_logo") or not ASSET.logo then return end
    obj:SetAttribute("HYD_logo", true)
    swappedCount = swappedCount + 1
    obj.Text = ""
    mk("ImageLabel", {
        Name = "HYD_LogoImg", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), Image = ASSET.logo,
        ScaleType = Enum.ScaleType.Crop, ZIndex = obj.ZIndex + 1, Active = false,
    }, obj)
    local par = obj.Parent
    if par then
        for _, sib in ipairs(par:GetChildren()) do          -- dấu "×" nhỏ đi kèm chữ V
            if sib ~= obj and (sib:IsA("TextLabel") or sib:IsA("TextButton")) and not sib:GetAttribute("HYD_skip") then
                local t = trim(stripTags(sib.Text))
                if (t == "×" or t == "x" or t == "X" or t == "✕") and sib.AbsoluteSize.X <= 30 then sib.Text = "" end
            end
        end
    end
    obj:GetPropertyChangedSignal("Text"):Connect(function()
        if obj.Text ~= "" then obj.Text = "" end
    end)
end

local function detectLogos(guis, main)
    local mp = main.AbsolutePosition
    for _, gui in ipairs(guis) do
        for _, d in ipairs(gui:GetDescendants()) do
            if not d:GetAttribute("HYD_skip") then
                if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" then
                    local img = d.Image
                    if img == ASSET.logo or img == ASSET.bg then
                        -- đã là ảnh của mình
                    elseif oldLogoSet[img] then
                        -- cùng ảnh với logo cũ nhưng chỉ đổi khi đúng chỗ của logo (góc tiêu đề / nút nổi) và cỡ logo:
                        -- các icon dùng chung ảnh (tiền/giây...) và ảnh lớn của menu khác KHÔNG bị đổi
                        local s = d.AbsoluteSize
                        local nm = d.Name:lower()
                        if s.X > 0 and s.X <= 160 and s.Y <= 160 and not isAvatarLike(d) and not d:GetAttribute("HYD_plate")
                            and (nm:find("logo", 1, true) or nm:find("brand", 1, true) or logoLocation(d, s, gui, main, mp)) then
                            swapLogo(d)
                        end
                    else
                        local s = d.AbsoluteSize
                        local nm = d.Name:lower()
                        if s.X > 0 and s.X <= 220 and (nm:find("logo", 1, true) or nm:find("brand", 1, true)) and not isAvatarLike(d) then
                            swapLogo(d)                                    -- đối tượng tên "Logo"/"Brand"
                        elseif s.X > 0 and squareish(s) and not isAvatarLike(d) and not d:GetAttribute("HYD_plate") then
                            if logoLocation(d, s, gui, main, mp) then swapLogo(d) end
                        end
                    end
                elseif ASSET.logo and (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("HYD_logo") then
                    local t = trim(stripTags(d.Text))
                    if #t >= 1 and #t <= 3 and t:sub(1, 1):lower() == "v" and not t:find("%d") then
                        local s = d.AbsoluteSize
                        if s.X > 0 and s.X <= 160 and logoLocation(d, s, gui, main, mp) then swapTextLogo(d) end
                    end
                end
            end
        end
    end
end

-- ================= LOGO "V" CẠNH TÊN + NÚT NỔI (cơ chế lấy từ bản SOLIEY, dùng logo Hydrogen) =================
-- Vòng lặp riêng (chạy mỗi giây từ lúc khởi động): tìm chữ tên hub ở thanh tiêu đề -> đổi logo "V" sát bên;
-- nếu không bắt được thì ẩn mọi vật nhỏ bên trái tên hub rồi đặt logo Hydrogen vào đúng chỗ. Nút nổi: quét nút nhỏ sát gốc GUI.
local SYMBOLS = { ["-"]=true, ["_"]=true, ["–"]=true, ["−"]=true, ["—"]=true, ["≡"]=true, ["☰"]=true, ["▲"]=true, ["▼"]=true }

-- đặt ảnh logo Hydrogen vào đúng khung `parent` (dùng cho chữ "V" / khung vẽ tay)
local function makeLogo(parent, z)
    return mk("ImageLabel", {
        Name = "HYD_LogoImg", BackgroundTransparency = 1, Active = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0), SizeConstraint = Enum.SizeConstraint.RelativeYY,
        Image = ASSET.logo or "", ScaleType = Enum.ScaleType.Crop, ZIndex = z,
    }, parent)
end

-- ảnh "V" của hub -> đổi thẳng sang ảnh logo Hydrogen (swapLogo còn đổi lại nếu hub đặt lại ảnh cũ)
local function ninja(img)
    if img:GetAttribute("HYD_logo") then return end
    swapLogo(img)
end
local function lockLogoHidden(d) end

-- đối tượng có thể là logo "V" của hub (ảnh / chữ "V" / khung vuông nếu allowFrame)
local function isLogoCandidate(d, allowFrame)
    if d:GetAttribute("HYD_skip") or d:GetAttribute("HYD_logo") then return false end
    for _, nm in ipairs(CONFIG.HEADER_LOGO_NAMES) do
        if d.Name == nm then return true end
    end
    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
        return d.Image ~= "" and d.ImageTransparency < 1
    elseif d:IsA("TextLabel") or d:IsA("TextButton") then
        return trim(d.Text):upper() == "V"
    elseif allowFrame and d:IsA("Frame") then
        local s = d.AbsoluteSize
        return d.BackgroundTransparency < 1 and math.abs(s.X - s.Y) <= 6
    end
    return false
end

-- tìm dòng chữ tên hub (HYDROGEN...) ở thanh tiêu đề của menu
local function findTitle(main)
    local mp = main.AbsolutePosition
    local best, bestY
    for _, d in ipairs(main:GetDescendants()) do
        if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("HYD_skip") and d.AbsoluteSize.X > 0 then
            if d.Text:upper():find("HYDROGEN", 1, true) then
                local y = d.AbsolutePosition.Y - mp.Y
                if y >= -4 and y <= 60 and (not bestY or y < bestY) then best, bestY = d, y end
            end
        end
    end
    return best
end

-- vùng chữ thật sự của tiêu đề (trái, phải) theo căn lề
local function titleSpan(title)
    local tp, ts = title.AbsolutePosition, title.AbsoluteSize
    local tb = math.min(title.TextBounds.X, ts.X)
    local al = title.TextXAlignment
    if al == Enum.TextXAlignment.Left then return tp.X, tp.X + tb end
    if al == Enum.TextXAlignment.Right then return tp.X + ts.X - tb, tp.X + ts.X end
    local l = tp.X + (ts.X - tb) / 2
    return l, l + tb
end

-- dự phòng: không tìm được logo "V" để thay -> tự đặt logo HYDROGEN ở góc trái, ngay cạnh chữ HYDROGEN
-- tìm dòng chữ HYDROGEN ở trên cùng trong mọi GUI của hub (không phụ thuộc cửa sổ nào là "chính")
local function findTitleGlobal()
    local best, bestY
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and isTarget(g) and not isClassicGui(g) then
                for _, d in ipairs(g:GetDescendants()) do
                    if (d:IsA("TextLabel") or d:IsA("TextButton")) and not d:GetAttribute("HYD_skip") then
                        local t = d.Text
                        if #t <= 40 and d.AbsoluteSize.X > 0 and t:upper():find("HYDROGEN", 1, true) then
                            local y = d.AbsolutePosition.Y
                            if not bestY or y < bestY then best, bestY = d, y end
                        end
                    end
                end
            end
        end
    end
    return best
end

-- ẩn vĩnh viễn một vật nhỏ (hub bật lại thì ẩn lại)
local function keepHidden(d)
    pcall(function()
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
            d.ImageTransparency = 1
            d:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
                if d.ImageTransparency ~= 1 then d.ImageTransparency = 1 end
            end)
        elseif d:IsA("TextLabel") or d:IsA("TextButton") then
            d.Text = ""
            d:GetPropertyChangedSignal("Text"):Connect(function()
                if d.Text ~= "" then d.Text = "" end
            end)
        end
        d.Visible = false
        d:GetPropertyChangedSignal("Visible"):Connect(function()
            if d.Visible then d.Visible = false end
        end)
    end)
end

-- dự phòng chắc chắn: ẩn MỌI vật nhỏ nằm bên trái chữ HYDROGEN (cùng hàng) rồi đặt logo HYDROGEN vào đúng chỗ đó
local function placeTitleLogo(main, title)
    local scope = (title and title:FindFirstAncestorOfClass("ScreenGui")) or main:FindFirstAncestorOfClass("ScreenGui") or main
    if scope:FindFirstChild("HYD_TitleLogo", true) then return true end
    local mp = main.AbsolutePosition
    local ts, tL, tcy, band
    if title then
        ts = title.AbsoluteSize
        tL = titleSpan(title)
        tcy = title.AbsolutePosition.Y + ts.Y / 2
        band = math.max(24, ts.Y / 2 + 14)
    end

    local minX, maxH, sumY, n = nil, 0, 0, 0
    for _, d in ipairs(scope:GetDescendants()) do
        if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") and not d:GetAttribute("HYD_vhid") then
            local related = title and (d == title or d:IsAncestorOf(title) or title:IsAncestorOf(d))
            if not related then
                local p, sz = d.AbsolutePosition, d.AbsoluteSize
                if sz.X >= 4 and sz.X <= 64 and sz.Y >= 4 and sz.Y <= 64 then
                    local cx, cyy = p.X + sz.X / 2, p.Y + sz.Y / 2
                    local inZone
                    if title then
                        inZone = math.abs(cyy - tcy) <= band and cx < tL + 30 and cx > tL - 120
                    else
                        inZone = cx >= mp.X and cx - mp.X <= 80 and cyy >= mp.Y and cyy - mp.Y <= 58
                    end
                    if inZone then
                        local hid = false
                        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                            hid = true
                        elseif d:IsA("TextLabel") or d:IsA("TextButton") then
                            hid = trim(d.Text) ~= ""
                        else
                            hid = true
                        end
                        if hid then
                            d:SetAttribute("HYD_vhid", true)
                            keepHidden(d)
                            minX = math.min(minX or p.X, p.X)
                            maxH = math.max(maxH, sz.Y)
                            sumY = sumY + cyy
                            n = n + 1
                        end
                    end
                end
            end
        end
    end
    if not title and n == 0 then return false end

    local cy = title and tcy or (sumY / n)
    local size = math.clamp(math.floor(maxH > 0 and maxH or (ts and ts.Y or 28)), 18, 32)
    local x = minX or (tL - size - 6)

    -- nơi đặt logo: tổ tiên của chữ không có UIListLayout/UIGridLayout (tránh bị layout xếp lại)
    local par = title and title.Parent or main
    while par and par:IsA("GuiObject") and (par:FindFirstChildWhichIsA("UIListLayout") or par:FindFirstChildWhichIsA("UIGridLayout")) do
        par = par.Parent
    end
    if not (par and par:IsA("GuiObject")) then par = main end
    local base = par.AbsolutePosition

    local holder = mk("Frame", {
        Name = "HYD_TitleLogo", BackgroundTransparency = 1, Active = false,
        Size = UDim2.new(0, size, 0, size), ZIndex = ((title and title.ZIndex) or main.ZIndex) + 2,
    }, par)
    local sc = 1
    local aw = holder.AbsoluteSize.X
    if aw > 0 then sc = aw / size end
    holder.Size = UDim2.new(0, size / sc, 0, size / sc)

    if not minX and title and x < base.X + 2 and title.TextXAlignment == Enum.TextXAlignment.Left then
        x = base.X + 6                                -- không đủ chỗ bên trái chữ: dời chữ sang phải
        local pos = title.Position
        title.Position = UDim2.new(pos.X.Scale, pos.X.Offset + (size + 10) / sc, pos.Y.Scale, pos.Y.Offset)
    end
    holder.Position = UDim2.new(0, (x - base.X) / sc, 0, (cy - size / 2 - base.Y) / sc)
    makeLogo(holder, holder.ZIndex + 1)
    return true
end

-- logo "V" ngay cạnh tên HYDROGEN trên menu -> logo HYDROGEN (chạy lặp lại cho tới khi tìm thấy)
local function headerLogo(main, allowFrame)
    local mp = main.AbsolutePosition
    local title = findTitleGlobal() or findTitle(main)
    local tL, tR, tCY
    if title then
        tL, tR = titleSpan(title)
        tCY = title.AbsolutePosition.Y + title.AbsoluteSize.Y / 2
    end
    local best, bestKey
    for _, d in ipairs(main:GetDescendants()) do
        if d ~= title and isLogoCandidate(d, allowFrame) then
            local p, s = d.AbsolutePosition, d.AbsoluteSize
            if s.X >= 6 and s.X <= 64 and s.Y >= 6 and s.Y <= 64 then
                local key
                if title then
                    -- nằm cùng hàng với tên và sát bên chữ (tối đa 90px)
                    local gap = math.max(tL - (p.X + s.X), p.X - tR, 0)
                    if math.abs(p.Y + s.Y / 2 - tCY) <= math.max(22, title.AbsoluteSize.Y / 2 + 14) and gap <= 90 then
                        key = gap * 1000 + (p.Y - mp.Y)
                    end
                elseif p.X - mp.X <= 120 and p.Y - mp.Y <= 40 then
                    key = (p.Y - mp.Y) * 1000 + (p.X - mp.X)
                end
                if key and (not bestKey or key < bestKey) then best, bestKey = d, key end
            end
        end
    end
    if not best then
        if CONFIG.DEBUG then
            local n = 0
            for _, d in ipairs(main:GetDescendants()) do
                if n < 10 and d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
                    local p, s = d.AbsolutePosition, d.AbsoluteSize
                    if s.X > 0 and s.X <= 64 and p.Y - mp.Y <= 50 and p.X - mp.X <= 200 then
                        n = n + 1
                        print("[HYDROGEN] logo menu? ->", d.ClassName, d:GetFullName())
                    end
                end
            end
        end
        if allowFrame then return placeTitleLogo(main, title) end
        return false
    end
    if CONFIG.DEBUG then print("[HYDROGEN] logo menu ->", best:GetFullName()) end
    if best:IsA("ImageLabel") or best:IsA("ImageButton") then
        ninja(best)
        lockLogoHidden(best)
    else
        best:SetAttribute("HYD_skip", true)
        best:SetAttribute("HYD_logo", true)
        if best:IsA("TextLabel") or best:IsA("TextButton") then
            best.Text = ""
            best:GetPropertyChangedSignal("Text"):Connect(function()
                if best.Text ~= "" then best.Text = "" end
            end)
        else
            for _, c in ipairs(best:GetChildren()) do          -- khung huy hiệu: ẩn nét "V" bên trong
                if c:IsA("GuiObject") and not c:GetAttribute("HYD_skip") then c.Visible = false end
            end
        end
        makeLogo(best, best.ZIndex + 1)
    end
    return true
end

-- ---------- logo nút nổi (nút thu gọn/mở menu): quét nhanh mọi nút nhỏ nằm sát gốc GUI của hub ----------
-- Logo mới là MỘT ảnh TRÒN phủ kín cả nút (bo tròn theo nút), nằm trên cùng; ảnh/chữ "V" cũ bên trong được ẩn đi.
local function quiet(d)                                    -- ẩn ảnh / chữ cũ (hub đặt lại thì ẩn lại) mà không đụng tới Visible
    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
        d.ImageTransparency = 1
        d:GetPropertyChangedSignal("ImageTransparency"):Connect(function()
            if d.ImageTransparency ~= 1 then d.ImageTransparency = 1 end
        end)
    elseif d:IsA("TextLabel") or d:IsA("TextButton") then
        d.TextTransparency = 1
        d:GetPropertyChangedSignal("TextTransparency"):Connect(function()
            if d.TextTransparency ~= 1 then d.TextTransparency = 1 end
        end)
    end
end

local function launcherReplace(o)
    if o:FindFirstChild("HYD_LauncherLogo") then return true end
    local found, maxZ = false, o.ZIndex
    local function try(d, inner)
        if d:GetAttribute("HYD_logo") or d:GetAttribute("HYD_skip") then return end
        if d:IsA("GuiObject") and d.ZIndex > maxZ then maxZ = d.ZIndex end
        if d:IsA("ImageLabel") or d:IsA("ImageButton") then
            if d.Image ~= "" and (not inner or d.AbsoluteSize.X <= 120) then
                d:SetAttribute("HYD_logo", true)
                quiet(d)
                found = true
            end
        elseif d:IsA("TextLabel") or d:IsA("TextButton") then
            local tx = trim(d.Text)
            if tx:upper() == "V" or SYMBOLS[tx] then
                d:SetAttribute("HYD_logo", true)
                d.TextScaled = false
                quiet(d)
                found = true
            end
        end
    end
    try(o, false)
    local ok, list = pcall(function() return o:GetDescendants() end)
    if ok and #list <= 80 then
        for _, d in ipairs(list) do try(d, true) end
    end
    if not found then return false end
    local sz = o.AbsoluteSize
    local img = mk("ImageLabel", {
        Name = "HYD_LauncherLogo", BackgroundTransparency = 1, BorderSizePixel = 0, Active = false,
        AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(1, 0, 1, 0),
        SizeConstraint = (sz.X <= sz.Y) and Enum.SizeConstraint.RelativeXX or Enum.SizeConstraint.RelativeYY,
        Image = ASSET.logo or "", ScaleType = Enum.ScaleType.Crop, ZIndex = maxZ + 5,
    }, o)
    mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, img)       -- hình tròn
    swappedCount = swappedCount + 1
    return true
end

local function launcherScan(parent)
    local any = false
    for _, o in ipairs(parent:GetChildren()) do
        if o:IsA("GuiObject") and not o:GetAttribute("HYD_skip") and not o:GetAttribute("HYD_ldone") then
            local s = o.AbsoluteSize
            if s.X > 0 and s.Y > 0 and s.X <= 140 and s.Y <= 140 then
                local n = (o:GetAttribute("HYD_ltry") or 0) + 1
                o:SetAttribute("HYD_ltry", n)
                local ok, did = pcall(launcherReplace, o)
                if ok and did then
                    o:SetAttribute("HYD_ldone", true)
                    any = true
                elseif n >= 40 then
                    o:SetAttribute("HYD_ldone", true)
                end
            end
        elseif o:GetAttribute("HYD_ldone") then
            any = true
        end
    end
    return any
end

local function launcherLogo()
    local any = false
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and isTarget(g) and not isClassicGui(g) then
                if launcherScan(g) then any = true end
                for _, h in ipairs(g:GetChildren()) do      -- khung chứa trong suốt phủ cả màn hình: nút nổi có thể nằm trong đó
                    if h:IsA("GuiObject") and h.BackgroundTransparency >= 1 and not h:GetAttribute("HYD_skip")
                        and h.AbsoluteSize.X > 140 and #h:GetChildren() <= 12 then
                        if launcherScan(h) then any = true end
                    end
                end
            end
        end
    end
    return any
end

-- In MỘT LẦN (sau ~6 giây) danh sách đối tượng ở 2 vùng logo để biết hub gốc vẽ chữ "V" bằng cái gì
local zonesDumped = false
local function dumpZones(guis, main)
    local mp = main.AbsolutePosition
    local n = 0
    print("[HYDROGEN][DEBUG] ===== đối tượng ở vùng logo (gửi các dòng này cho mình) =====")
    for _, gui in ipairs(guis) do
        print("[HYDROGEN][DEBUG] ScreenGui: " .. gui.Name .. " | ZIndexBehavior=" .. tostring(gui.ZIndexBehavior))
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
                local s, p = d.AbsoluteSize, d.AbsolutePosition
                local inside = d:IsDescendantOf(main)
                local inHeader = inside and (p.X - mp.X) <= 100 and (p.Y - mp.Y) <= 64 and s.X <= 140 and s.X > 0
                local outside = (not inside) and s.X >= 20 and s.X <= 200 and s.Y >= 20 and s.Y <= 200 and depthOf(d, gui) <= 3
                if inHeader or outside then
                    local extra = ""
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        extra = " Image=" .. tostring(d.Image) .. " ImgTr=" .. tostring(d.ImageTransparency)
                    end
                    if d:IsA("TextLabel") or d:IsA("TextButton") then
                        extra = " Text=" .. tostring(d.Text)
                    end
                    print(("  [%s] %s %s %dx%d @%d,%d Z=%d Vis=%s%s"):format(inside and "in" or "out", d.ClassName, d:GetFullName(),
                        math.floor(s.X), math.floor(s.Y), math.floor(p.X - mp.X), math.floor(p.Y - mp.Y), d.ZIndex, tostring(d.Visible), extra))
                    n = n + 1
                    if n >= 45 then return end
                end
            end
        end
    end
end

local dumpedLogos = false
local function dumpLogoCandidates(guis, main)
    dumpedLogos = true
    local mp, n = main.AbsolutePosition, 0
    print("[HYDROGEN] chưa đổi được logo nào. Các đối tượng ứng viên (hãy gửi các dòng này để chỉnh tiếp):")
    for _, gui in ipairs(guis) do
        for _, d in ipairs(gui:GetDescendants()) do
            if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
                local s, p = d.AbsoluteSize, d.AbsolutePosition
                local inside = d:IsDescendantOf(main)
                local inHeader = inside and (p.X - mp.X) <= 100 and (p.Y - mp.Y) <= 64 and s.X <= 64 and s.X > 0
                local outside = (not inside) and depthOf(d, gui) <= 2 and s.X >= 30 and s.X <= 160 and s.Y <= 160
                if inHeader or outside then
                    local extra = ""
                    if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                        extra = " Image=" .. tostring(d.Image)
                    elseif d:IsA("TextLabel") or d:IsA("TextButton") then
                        extra = " Text=" .. tostring(d.Text)
                    end
                    print("  " .. d.ClassName .. " " .. d:GetFullName() .. " " .. math.floor(s.X) .. "x" .. math.floor(s.Y) .. extra)
                    n = n + 1
                    if n >= 16 then return end
                end
            end
        end
    end
end

-- ================= NỀN MỚI CHO CỬA SỔ =================
local function buildBackground(main)                   -- phương án dự phòng: khung nền phủ lên cửa sổ
    local uc = main:FindFirstChildOfClass("UICorner")
    local cr = uc and uc.CornerRadius or UDim.new(0, 12)
    local holder = mk("Frame", {
        Name = "HYDROGEN_BG", BackgroundColor3 = Color3.fromRGB(8, 4, 16), BorderSizePixel = 0,
        Size = UDim2.new(1, 0, 1, 0), ZIndex = 0, Active = false, ClipsDescendants = true,
    }, main)
    holder:SetAttribute("HYD_background", true)
    mk("UICorner", { CornerRadius = cr }, holder)
    local function glow(r, px, py, col, tr)
        local f = mk("Frame", {
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(px, 0, py, 0), Size = UDim2.new(r, 0, r, 0),
            SizeConstraint = Enum.SizeConstraint.RelativeXX, BackgroundColor3 = col, BackgroundTransparency = tr,
            BorderSizePixel = 0, ZIndex = Z(1), Active = false,
        }, holder)
        mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, f)
    end
    glow(1.1, 0.85, 0.2, Color3.fromRGB(70, 20, 140), 0.86)
    glow(0.6, 0.85, 0.2, Color3.fromRGB(120, 50, 210), 0.84)
    glow(0.9, 0.1, 0.9, Color3.fromRGB(60, 15, 120), 0.88)
    if ASSET.bg then
        local img = mk("ImageLabel", {
            Name = "Image", BackgroundTransparency = 1, Size = UDim2.new(1, 0, 1, 0), ZIndex = Z(2), Active = false,
            ScaleType = Enum.ScaleType.Crop, Image = ASSET.bg,
        }, holder)
        mk("UICorner", { CornerRadius = cr }, img)
    end
    mk("Frame", {
        Name = "Darken", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1 - math.clamp(CONFIG.BG_DARKEN, 0, 0.9), BorderSizePixel = 0, ZIndex = Z(3), Active = false,
    }, holder)
end

local function clearOldBackgrounds(main)
    local ms = main.AbsoluteSize
    local function walk(o, depth)
        for _, ch in ipairs(o:GetChildren()) do
            if ch:IsA("GuiObject") and not ch:GetAttribute("HYD_skip") then
                local s = ch.AbsoluteSize
                if s.X >= ms.X * 0.92 and s.Y >= ms.Y * 0.92 then
                    if (ch:IsA("ImageLabel") or ch:IsA("ImageButton")) and ch.Image ~= "" then ch.ImageTransparency = 1 end
                    if ch.BackgroundTransparency < 1 and (ch:IsA("Frame") or ch:IsA("ScrollingFrame")) then ch.BackgroundTransparency = 1 end
                    ch:SetAttribute("HYD_soft", true)
                end
                if depth < 3 then walk(ch, depth + 1) end
            end
        end
    end
    walk(main, 0)
end

-- đổi TRỰC TIẾP ảnh nền cũ (ImageLabel lớn phủ cửa sổ) sang ảnh nền mới
local function swapBackgroundImage(main)
    if not ASSET.bg then return false end
    local ms = main.AbsoluteSize
    local best, bestA = nil, 0
    local function consider(d)
        if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and not d:GetAttribute("HYD_skip") and d.Image ~= "" then
            local s = d.AbsoluteSize
            if s.X >= ms.X * 0.6 and s.Y >= ms.Y * 0.6 and s.X * s.Y > bestA then best, bestA = d, s.X * s.Y end
        end
    end
    consider(main)
    for _, d in ipairs(main:GetDescendants()) do consider(d) end
    if not best then return false end
    best:SetAttribute("HYD_soft", true)
    best:SetAttribute("HYD_bgimg", true)
    local function put()
        if best.Image ~= ASSET.bg then best.Image = ASSET.bg end
        best.ImageRectOffset = Vector2.new(0, 0)
        best.ImageRectSize = Vector2.new(0, 0)
        best.ImageColor3 = Color3.new(1, 1, 1)
        best.ScaleType = Enum.ScaleType.Crop
        if best.ImageTransparency > 0.1 then best.ImageTransparency = 0.05 end
    end
    put()
    best:GetPropertyChangedSignal("Image"):Connect(put)
    local uc = best:FindFirstChildOfClass("UICorner")
    local dk = mk("Frame", {                                -- phủ tối nhẹ để chữ dễ đọc
        Name = "HYD_Darken", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(0, 0, 0),
        BackgroundTransparency = 1 - math.clamp(CONFIG.BG_DARKEN, 0, 0.9), BorderSizePixel = 0, Active = false, ZIndex = Z(1),
    }, best)
    if uc then mk("UICorner", { CornerRadius = uc.CornerRadius }, dk) end
    return true
end

-- làm NỀN các khung / thẻ / nút lớn trong menu hơi trong suốt (chỉ đổi BackgroundTransparency / ImageTransparency
-- của nền; chữ trong đó giữ nguyên, TextTransparency không bị đụng tới)
local function keepFloor(o, prop, floor)
    o:GetPropertyChangedSignal(prop):Connect(function()    -- hub tween hover / đặt lại -> không cho đặc hơn mức sàn
        if o[prop] < floor then o[prop] = floor end
    end)
end

local function softenOne(o)
    if not o.Parent or o:GetAttribute("HYD_skip") or o:GetAttribute("HYD_soft") or o:GetAttribute("HYD_plate") then return end
    local T = CONFIG.MENU_TRANSPARENCY
    local s = o.AbsoluteSize
    if s.X < 60 or s.Y < 14 then return end            -- bỏ qua nút gạt, thanh trượt, icon nhỏ
    if o:IsA("Frame") or o:IsA("ScrollingFrame") or o:IsA("TextButton") then
        if o.BackgroundTransparency < 0.9 then
            o:SetAttribute("HYD_soft", true)
            o.BackgroundTransparency = math.max(o.BackgroundTransparency, T)
            keepFloor(o, "BackgroundTransparency", T)
        end
    elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then
        local touched = false
        if o.ScaleType == Enum.ScaleType.Slice and o.ImageTransparency < 0.9 then
            o.ImageTransparency = math.max(o.ImageTransparency, T)
            keepFloor(o, "ImageTransparency", T)
            touched = true
        end
        if o.BackgroundTransparency < 0.9 then
            o.BackgroundTransparency = math.max(o.BackgroundTransparency, T)
            keepFloor(o, "BackgroundTransparency", T)
            touched = true
        end
        if touched then o:SetAttribute("HYD_soft", true) end
    end
end

local function softenAll(main)
    for _, d in ipairs(main:GetDescendants()) do pcall(softenOne, d) end
end

-- ================= THANH TAB: thẻ nút tab tím neon + quả trứng gà trắng nhỏ =================
local tabCards = {}          -- mỗi nút tab: { grad, stroke, accent, sources, sel }

local function visibleBg(o)                                -- nền (của hub) đang hiện -> nút đang được chọn / hover
    if o.ClassName == "Frame" or o:IsA("GuiButton") or o:IsA("ImageLabel") then
        if (o:IsA("ImageLabel") or o:IsA("ImageButton")) and o.ScaleType == Enum.ScaleType.Slice and o.ImageTransparency < 0.97 then
            return true
        end
        return o.BackgroundTransparency < 0.97
    end
    return false
end

local function setTabSel(t, sel)
    if t.sel == sel then return end
    t.sel = sel
    t.grad.Color = ColorSequence.new(sel and CONFIG.TAB_ACTIVE_TOP or CONFIG.TAB_TOP, sel and CONFIG.TAB_ACTIVE_BOTTOM or CONFIG.TAB_BOTTOM)
    t.stroke.Thickness = sel and 1.8 or 1.2
    t.stroke.Transparency = sel and 0 or 0.4
    t.accent.Visible = sel
end

local function refreshTabs()
    local n, cnt, states = #tabCards, 0, {}
    for i, t in ipairs(tabCards) do
        local s = false
        for _, o in ipairs(t.sources) do
            if o.Parent and visibleBg(o) then
                s = true
                break
            end
        end
        states[i] = s
        if s then cnt = cnt + 1 end
    end
    local trust = cnt < math.ceil(n / 2)                   -- quá nửa nút "đang chọn" -> cách đoán này không đúng, bỏ qua
    for i, t in ipairs(tabCards) do setTabSel(t, trust and states[i]) end
end

-- quả trứng gà trắng nhỏ (ảnh nhúng; nếu executor không dựng được ảnh thì vẽ bằng khung bo tròn)
local function makeEgg(parent, z)
    local holder = mk("Frame", {
        Name = "HYD_Egg", BackgroundTransparency = 1, Active = false, AnchorPoint = Vector2.new(0.5, 0.5),
        Position = UDim2.new(0.5, 0, 0.5, 0), Size = UDim2.new(0.52, 0, 0.52, 0),
        SizeConstraint = Enum.SizeConstraint.RelativeYY, ZIndex = z,
    }, parent)
    if ASSET.egg then
        mk("ImageLabel", {
            BackgroundTransparency = 1, Active = false, Size = UDim2.new(1, 0, 1, 0), Image = ASSET.egg,
            ScaleType = Enum.ScaleType.Fit, ZIndex = z,
        }, holder)
    else
        local e = mk("Frame", {
            BackgroundColor3 = Color3.fromRGB(250, 248, 255), BorderSizePixel = 0, Active = false,
            AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, 0, 0.52, 0),
            Size = UDim2.new(0.62, 0, 0.8, 0), ZIndex = z,
        }, holder)
        mk("UICorner", { CornerRadius = UDim.new(0.5, 0) }, e)
        mk("UIGradient", { Rotation = 60, Color = ColorSequence.new(Color3.new(1, 1, 1), Color3.fromRGB(212, 206, 236)) }, e)
    end
    return holder
end

local function hideIcon(ic)                                -- ẩn icon cũ (hub tween lại thì ẩn tiếp)
    local prop = (ic:IsA("ImageLabel") or ic:IsA("ImageButton")) and "ImageTransparency" or "TextTransparency"
    ic[prop] = 1
    ic:GetPropertyChangedSignal(prop):Connect(function()
        if ic[prop] < 1 then ic[prop] = 1 end
    end)
end

local function styleTab(btn, icon, isEgg)
    btn:SetAttribute("HYD_plate", true)
    icon:SetAttribute("HYD_plate", true)
    local cornerObj = btn:FindFirstChildOfClass("UICorner")
    local radius = cornerObj and cornerObj.CornerRadius or UDim.new(0, 12)

    if btn == icon then
        -- icon vẽ ngay trên nút: chỉ tô nền tím + viền neon (không phủ khung con lên trên icon)
        local mid = Color3.fromRGB(38, 15, 72)
        btn.BackgroundColor3 = mid
        btn.BackgroundTransparency = 0.05
        btn:GetPropertyChangedSignal("BackgroundColor3"):Connect(function()
            if btn.BackgroundColor3 ~= mid then btn.BackgroundColor3 = mid end
        end)
        if not btn:FindFirstChildOfClass("UICorner") then mk("UICorner", { CornerRadius = radius }, btn) end
        if not btn:FindFirstChildOfClass("UIStroke") then
            mk("UIStroke", { Color = CONFIG.TAB_NEON, Thickness = 1.3, Transparency = 0.25, ApplyStrokeMode = Enum.ApplyStrokeMode.Border }, btn)
        end
        if isEgg then
            hideIcon(btn)
            makeEgg(btn, btn.ZIndex + 1)
        end
        return
    end

    -- thứ tự lớp: thẻ nằm DƯỚI icon của hub
    local baseZ
    if globalZ then
        baseZ = btn.ZIndex
        for _, d in ipairs(btn:GetDescendants()) do
            if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then d.ZIndex = d.ZIndex + 4 end
        end
    else
        local minZ = btn.ZIndex
        local first = true
        for _, c in ipairs(btn:GetChildren()) do
            if c:IsA("GuiObject") and not c:GetAttribute("HYD_skip") then
                if first or c.ZIndex < minZ then minZ = c.ZIndex end
                first = false
            end
        end
        baseZ = minZ - 4
    end

    -- các nền của hub (đang hiện khi nút được chọn) -> chỉ để đọc trạng thái "đang chọn"
    local sources = { btn }
    local bs = btn.AbsoluteSize
    for _, c in ipairs(btn:GetChildren()) do
        if (c:IsA("Frame") or c:IsA("ImageLabel")) and not c:GetAttribute("HYD_skip") and c ~= icon and not icon:IsDescendantOf(c)
            and c.AbsoluteSize.X >= bs.X * 0.85 and c.AbsoluteSize.Y >= bs.Y * 0.85 then
            table.insert(sources, c)
        end
    end

    local card = mk("Frame", {
        Name = "HYD_TabCard", Size = UDim2.new(1, 0, 1, 0), BackgroundColor3 = Color3.new(1, 1, 1),
        BackgroundTransparency = 0.06, BorderSizePixel = 0, Active = false, ZIndex = baseZ,
    }, btn)
    mk("UICorner", { CornerRadius = radius }, card)
    local grad = mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(CONFIG.TAB_TOP, CONFIG.TAB_BOTTOM) }, card)
    local stroke = mk("UIStroke", {
        Color = Color3.new(1, 1, 1), Thickness = 1.2, Transparency = 0.4, ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
    }, card)
    mk("UIGradient", { Rotation = 90, Color = ColorSequence.new(CONFIG.TAB_NEON, CONFIG.TAB_ACCENT) }, stroke)

    local gloss = mk("Frame", {                            -- ánh kính mờ nửa trên
        Name = "HYD_TabGloss", BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Active = false,
        Position = UDim2.new(0, 3, 0, 2), Size = UDim2.new(1, -6, 0.46, 0), ZIndex = baseZ + 1,
    }, btn)
    mk("UICorner", { CornerRadius = UDim.new(0, 9) }, gloss)
    mk("UIGradient", { Rotation = 90, Transparency = NumberSequence.new(0.86, 1) }, gloss)

    local accent = mk("Frame", {                           -- thanh nhấn bên trái khi nút đang chọn
        Name = "HYD_TabAccent", AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 2, 0.5, 0),
        Size = UDim2.new(0, 3, 0.46, 0), BackgroundColor3 = CONFIG.TAB_ACCENT, BorderSizePixel = 0,
        Active = false, Visible = false, ZIndex = baseZ + 2,
    }, btn)
    mk("UICorner", { CornerRadius = UDim.new(1, 0) }, accent)

    local t = { grad = grad, stroke = stroke, accent = accent, sources = sources, sel = false }
    table.insert(tabCards, t)
    for _, o in ipairs(sources) do
        o:GetPropertyChangedSignal("BackgroundTransparency"):Connect(refreshTabs)
        if o:IsA("ImageLabel") or o:IsA("ImageButton") then
            o:GetPropertyChangedSignal("ImageTransparency"):Connect(refreshTabs)
        end
    end

    if isEgg then
        hideIcon(icon)
        makeEgg(btn, baseZ + 10)
    end
end

-- chọn cột dọc gần mép trái có >= 4 phần tử (các icon / nút của thanh tab), xếp từ trên xuống
local function pickColumn(cands)
    local function cx(d) return d.AbsolutePosition.X + d.AbsoluteSize.X / 2 end
    table.sort(cands, function(a, b) return cx(a) < cx(b) end)
    local clusters, cur, prevX = {}, {}, nil
    for _, d in ipairs(cands) do
        local x = cx(d)
        if prevX and math.abs(x - prevX) > 10 then
            table.insert(clusters, cur)
            cur = {}
        end
        table.insert(cur, d)
        prevX = x
    end
    if #cur > 0 then table.insert(clusters, cur) end
    local best
    for _, c in ipairs(clusters) do
        if not best or #c > #best then best = c end
    end
    if not best or #best < 4 then return {} end
    table.sort(best, function(a, b) return a.AbsolutePosition.Y < b.AbsolutePosition.Y end)
    return best
end

local function inStrip(d, mp, ms)
    local p = d.AbsolutePosition
    return (p.X - mp.X) <= ms.X * 0.2 and (p.Y - mp.Y) >= 44 and (p.Y - mp.Y) <= ms.Y - 4
end

-- icon của thanh tab: các icon nhỏ, vuông, xếp thành một cột sát mép trái cửa sổ (bỏ qua avatar)
local function findTabIcons(main)
    local mp, ms = main.AbsolutePosition, main.AbsoluteSize
    local cands = {}
    for _, d in ipairs(main:GetDescendants()) do
        if d:IsA("GuiObject") and d.Visible and not d:GetAttribute("HYD_skip") and not d:GetAttribute("HYD_plate") then
            local isIcon = false
            if d:IsA("ImageLabel") or d:IsA("ImageButton") then
                isIcon = d.Image ~= "" and d.ScaleType ~= Enum.ScaleType.Slice and d.ImageTransparency < 1
            elseif d:IsA("TextLabel") or d:IsA("TextButton") then
                isIcon = d.Text ~= "" and #d.Text <= 6 and d.TextTransparency < 1
            end
            if isIcon then
                local s = d.AbsoluteSize
                if s.X >= 12 and s.X <= 60 and s.Y >= 12 and s.Y <= 60 and math.abs(s.X - s.Y) <= 10
                    and inStrip(d, mp, ms) and not isAvatarLike(d) then
                    table.insert(cands, d)
                end
            end
        end
    end
    return pickColumn(cands)
end

-- dự phòng: không thấy icon rời -> tìm các NÚT vuông xếp thành cột (icon là con bên trong, hoặc chính nút)
local function findTabButtons(main)
    local mp, ms = main.AbsolutePosition, main.AbsoluteSize
    local cands = {}
    for _, d in ipairs(main:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible and not d:GetAttribute("HYD_skip") and not d:GetAttribute("HYD_plate") then
            local s = d.AbsoluteSize
            if s.X >= 28 and s.X <= 64 and s.Y >= 28 and s.Y <= 64 and math.abs(s.X - s.Y) <= 10
                and inStrip(d, mp, ms) and not isAvatarLike(d) then
                table.insert(cands, d)
            end
        end
    end
    return pickColumn(cands)
end

-- nút bấm chứa icon: tổ tiên gần nhất lớn hơn icon một chút (và không quá 64px)
local function tabButtonOf(icon, main)
    local is = icon.AbsoluteSize
    local p = icon.Parent
    while p and p ~= main and p:IsA("GuiObject") do
        local s = p.AbsoluteSize
        if s.X > 64 or s.Y > 64 then break end
        if s.X >= is.X * 1.1 and s.Y >= is.Y * 1.1 then return p end
        p = p.Parent
    end
    return icon
end

local function iconInside(btn)
    for _, d in ipairs(btn:GetDescendants()) do
        if not d:GetAttribute("HYD_skip") and d.Visible ~= false then
            if (d:IsA("ImageLabel") or d:IsA("ImageButton")) and d.Image ~= "" and d.ScaleType ~= Enum.ScaleType.Slice then return d end
            if (d:IsA("TextLabel") or d:IsA("TextButton")) and d.Text ~= "" and #d.Text <= 6 then return d end
        end
    end
    return nil
end

local tabsDumped = false
local function dumpStrip(main)                             -- in MỘT LẦN các đối tượng ở cột trái để biết hub vẽ nút tab bằng gì
    if tabsDumped then return end
    tabsDumped = true
    local mp, ms = main.AbsolutePosition, main.AbsoluteSize
    local n = 0
    print("[HYDROGEN][DEBUG] ===== cột tab bên trái (gửi các dòng này cho mình nếu nút tab chưa đổi) =====")
    for _, d in ipairs(main:GetDescendants()) do
        if d:IsA("GuiObject") and not d:GetAttribute("HYD_skip") then
            local s, p = d.AbsoluteSize, d.AbsolutePosition
            if s.X > 0 and s.X <= 90 and s.Y <= 90 and inStrip(d, mp, ms) then
                local extra = ""
                if d:IsA("ImageLabel") or d:IsA("ImageButton") then extra = " Image=" .. tostring(d.Image) end
                if d:IsA("TextLabel") or d:IsA("TextButton") then extra = " Text=" .. tostring(d.Text) end
                print(("  %s %s %dx%d @%d,%d Vis=%s%s"):format(d.ClassName, d:GetFullName(), math.floor(s.X), math.floor(s.Y),
                    math.floor(p.X - mp.X), math.floor(p.Y - mp.Y), tostring(d.Visible), extra))
                n = n + 1
                if n >= 40 then return end
            end
        end
    end
end

local function styleTabs(main)
    local items = {}
    for _, ic in ipairs(findTabIcons(main)) do
        table.insert(items, { btn = tabButtonOf(ic, main), icon = ic })
    end
    if #items < 4 then
        items = {}
        for _, b in ipairs(findTabButtons(main)) do
            table.insert(items, { btn = b, icon = iconInside(b) or b })
        end
    end
    if #items < 4 then return 0 end
    local eggIdx
    if CONFIG.TAB_EGG then
        for i, it in ipairs(items) do
            local nm = (it.icon.Name .. " " .. it.btn.Name):lower()
            if nm:find("egg", 1, true) then
                eggIdx = i
                break
            end
        end
        if not eggIdx and #items >= 5 then eggIdx = 2 end     -- tab thứ 2 từ trên xuống là quả egg
    end
    local n = 0
    for i, it in ipairs(items) do
        local ok, err = pcall(styleTab, it.btn, it.icon, i == eggIdx)
        if ok then
            n = n + 1
        else
            warn("[HYDROGEN] lỗi tô nút tab " .. i .. ":", err)
        end
    end
    refreshTabs()
    return n
end

-- ================= MENU CỔ ĐIỂN MÀU ĐỎ: đỏ -> tím (chỉ các nền màu đỏ: tên hub + nút tab; nền trong suốt giữ nguyên) =================
local function mapRed(c)
    local h, s, v = c:ToHSV()
    if (h <= 0.04 or h >= 0.96) and s >= 0.5 and v >= 0.3 then
        return Color3.fromHSV(0.76, math.clamp(s * 0.85, 0.5, 0.88), math.clamp(v * 0.92, 0.3, 0.95))
    end
    return nil
end

local function repaint(o, prop)
    local ok, m = pcall(function() return mapRed(o[prop]) end)
    if ok and m then o[prop] = m end
end

local function recolorOne(o)
    if o:GetAttribute("HYD_skip") or o:GetAttribute("HYD_rc") then return end
    o:SetAttribute("HYD_rc", true)
    local props
    if o:IsA("GuiObject") then
        props = { "BackgroundColor3", "BorderColor3" }
        if o:IsA("ImageLabel") or o:IsA("ImageButton") then table.insert(props, "ImageColor3") end
    elseif o:IsA("UIStroke") then
        props = { "Color" }
    end
    if props then
        for _, prop in ipairs(props) do
            if mapRed(o[prop]) then
                repaint(o, prop)
                o:GetPropertyChangedSignal(prop):Connect(function() repaint(o, prop) end)     -- hub tween / đặt lại màu đỏ -> đổi lại
            end
        end
    elseif o:IsA("UIGradient") then
        local function fix()
            local kps, changed, new = o.Color.Keypoints, false, {}
            for i, kp in ipairs(kps) do
                local m = mapRed(kp.Value)
                if m then changed = true end
                new[i] = ColorSequenceKeypoint.new(kp.Time, m or kp.Value)
            end
            if changed then o.Color = ColorSequence.new(new) end
        end
        fix()
        o:GetPropertyChangedSignal("Color"):Connect(fix)
    end
end

local function recolorClassic(g)
    for _, d in ipairs(g:GetDescendants()) do pcall(recolorOne, d) end
end

-- ================= THIẾT LẬP KHI TÌM THẤY CỬA SỔ =================
local function setupMain(main)
    mainWindow = main
    hadMain = true
    local gui = main:FindFirstAncestorOfClass("ScreenGui")
    trackedMainGui = gui
    if main:GetAttribute("HYD_main") then return end
    main:SetAttribute("HYD_main", true)
    globalZ = gui ~= nil and gui.ZIndexBehavior == Enum.ZIndexBehavior.Global
    print("[HYDROGEN] tìm thấy cửa sổ hub: " .. main:GetFullName() .. " (" .. math.floor(main.AbsoluteSize.X) .. "x" .. math.floor(main.AbsoluteSize.Y) .. ")")
    -- Không thay ImageLabel lớn nhất nữa: nó có thể là ảnh ở lớp trước của menu.
    -- Dùng một lớp nền riêng ở ZIndex thấp, sau đó làm trong suốt nền cũ.
    clearOldBackgrounds(main)
    buildBackground(main)
    print("[HYDROGEN] đã tạo nền riêng phía sau nội dung cửa sổ")
    softenAll(main)
    main.DescendantAdded:Connect(function(d)
        if d:IsA("GuiObject") then task.delay(0.3, softenOne, d) end
    end)
end

-- ================= THEO DÕI NGAY KHI ĐỐI TƯỢNG ĐƯỢC TẠO (không chờ vòng quét) =================
local dirty = false
local hubSeen                                           -- thời điểm thấy giao diện hub đầu tiên
local handled = setmetatable({}, { __mode = "k" })

local function handleAdded(obj)
    if STOPPED then return end
    if obj:IsA("TextLabel") or obj:IsA("TextButton") then
        if not handled[obj] then
            handled[obj] = true
            obj:GetPropertyChangedSignal("Text"):Connect(function() pushApply(obj) end)
        end
        apply(obj)                                       -- đổi tên NGAY lúc đối tượng xuất hiện
    elseif obj:IsA("TextBox") then
        apply(obj)
    elseif obj:IsA("ImageLabel") or obj:IsA("ImageButton") then
        if not obj:GetAttribute("HYD_skip") and oldLogoSet[obj.Image] then
            local nm = obj.Name:lower()
            if nm:find("logo", 1, true) or nm:find("brand", 1, true) then swapLogo(obj) end   -- còn lại để vòng quét xét vị trí / kích thước
        end
        dirty = true
    elseif obj:IsA("GuiObject") then
        dirty = true
    end
end

local watching = setmetatable({}, { __mode = "k" })
local function watchGui(gui)
    if watching[gui] or not isTarget(gui) then return end
    watching[gui] = true
    guiBorn[gui] = os.clock()
    hubSeen = hubSeen or os.clock()
    local gn = brand(gui.Name)
    if gn ~= gui.Name then gui.Name = gn end
    gui.DescendantAdded:Connect(function(d)
        guiAdded[gui] = os.clock()
        pcall(handleAdded, d)
    end)
    for _, d in ipairs(gui:GetDescendants()) do pcall(handleAdded, d) end
    dirty = true
end

for _, c in ipairs(containers) do
    c.ChildAdded:Connect(function(g)
        if g:IsA("ScreenGui") then watchGui(g) end
    end)
    for _, g in ipairs(c:GetChildren()) do
        if g:IsA("ScreenGui") then watchGui(g) end
    end
end

-- ================= QUÉT THEO KHUNG HÌNH: xử lý phần cần kích thước (logo, nền, tab) ngay khi bố cục sẵn sàng =================
-- nhãn tên hub ở thanh tiêu đề cửa sổ -> "HYDROGEN Beta v1" (các chỗ khác như "SOLIEY Discord" giữ tên riêng)
local function markTitle(main)
    local mp = main.AbsolutePosition
    local best
    for _, d in ipairs(main:GetDescendants()) do
        if d:IsA("TextLabel") and not d:GetAttribute("HYD_skip") then
            local t = trim(stripTags(d.Text)):upper()
            if t == CONFIG.NAME:upper() or t == CONFIG.TITLE:upper() then
                local p, s = d.AbsolutePosition, d.AbsoluteSize
                if s.X > 0 and (p.Y - mp.Y) <= 60 and (p.X - mp.X) <= 320 then
                    if not best or p.X < best.AbsolutePosition.X then best = d end
                end
            end
        end
    end
    if best and not best:GetAttribute("HYD_title") then
        best:SetAttribute("HYD_title", true)
        best.Text = CONFIG.TITLE
        pcall(fitText, best)
        print("[HYDROGEN] đã đặt tên hub: " .. CONFIG.TITLE)
    end
    return best ~= nil
end

local platesDone, warnedPlates, warnedMain, titleDone = false, false, false, false

local function scanAll()
    local guis, classics = {}, {}
    for _, c in ipairs(containers) do
        for _, g in ipairs(c:GetChildren()) do
            if g:IsA("ScreenGui") and isTarget(g) then
                watchGui(g)
                if isClassicGui(g) then table.insert(classics, g) else table.insert(guis, g) end
            end
        end
    end
    for _, g in ipairs(classics) do                       -- menu cổ điển màu đỏ: chỉ đổi đỏ -> tím
        local okC, errC = pcall(recolorClassic, g)
        if not okC and not _G.__HYD_rcwarned then _G.__HYD_rcwarned = true; warn("[HYDROGEN] lỗi recolorClassic:", errC) end
    end
    if #guis == 0 then return end
    if not mainWindow or not mainWindow.Parent then
        mainWindow = nil
        local m = findMainWindow()
        if m then pcall(setupMain, m) end
    end
    local main = mainWindow
    if not main then
        if hubSeen and os.clock() - hubSeen > 20 and not warnedMain then
            warnedMain = true
            warn("[HYDROGEN] sau 20 giây vẫn chưa tìm thấy cửa sổ hub: logo, nền và nút tab chưa được đổi")
        end
        return
    end
    if not titleDone then titleDone = markTitle(main) end
    local before = swappedCount
    local okD, errD = pcall(detectLogos, guis, main)
    if not okD then warn("[HYDROGEN] lỗi detectLogos:", errD) end
    if hubSeen and os.clock() - hubSeen > 6 and not zonesDumped then
        zonesDumped = true
        print("[HYDROGEN][DEBUG] cửa sổ hub = " .. main:GetFullName() .. " | logo đã đổi = " .. swappedCount
            .. " | ASSET.logo = " .. tostring(ASSET.logo))
        pcall(dumpZones, guis, main)
    end
    if swappedCount ~= before then print("[HYDROGEN] đã đổi " .. swappedCount .. " logo") end
    if swappedCount == 0 and not dumpedLogos and hubSeen and os.clock() - hubSeen > 8 then
        pcall(dumpLogoCandidates, guis, main)
    end
    if not platesDone then
        local okT, n = pcall(styleTabs, main)
        if not okT then warn("[HYDROGEN] lỗi styleTabs:", n); n = 0 end
        if n >= 4 then
            platesDone = true
            print("[HYDROGEN] đã làm đẹp " .. n .. " nút tab")
        elseif hubSeen and os.clock() - hubSeen > 15 and not warnedPlates then
            warnedPlates = true
            warn("[HYDROGEN] chưa nhận ra thanh tab bên trái nên chưa tô màu các nút tab")
            pcall(dumpStrip, main)
        end
    end
    if hubSeen and os.clock() - hubSeen < 60 then softenAll(main) end
end

local frameN, lastScan = 0, 0
RunService.RenderStepped:Connect(function()
    if STOPPED then return end
    frameN = frameN + 1
    if not hubSeen then return end
    local since = os.clock() - hubSeen
    local gap = (since < 3) and 2 or ((since < 10) and 8 or 30)       -- số khung hình tối thiểu giữa hai lần quét
    local due = frameN - lastScan
    if (dirty and due >= gap) or due >= 600 then
        dirty = false
        lastScan = frameN
        local okS, errS = pcall(scanAll)
        if not okS and not _G.__HYD_scanwarned then _G.__HYD_scanwarned = true; warn("[HYDROGEN] lỗi scanAll:", errS) end
    end
end)

-- ================= CHẶN LINK DISCORD CŨ KHI SAO CHÉP (lấy từ bản SOLIEY) =================
-- Hub gốc tự gọi setclipboard với link Discord của họ (kể cả khi nút bị phủ). Bọc các hàm clipboard lại:
-- bất kỳ link Discord nào hub định sao chép đều được đổi thành CONFIG.DISCORD_LINK. Phải cài TRƯỚC khi hub chạy.
local clipboardGuarded = false
local function installClipboardGuard()
    if clipboardGuarded then return end
    clipboardGuarded = true
    local function fix(txt)
        if type(txt) == "string" then
            local l = txt:lower()
            if l:find("discord.gg", 1, true) or l:find("discord.com/invite", 1, true)
                or l:find("discordapp.com/invite", 1, true) or l:find("dsc.gg", 1, true) then
                if txt ~= CONFIG.DISCORD_LINK then print("[HYDROGEN] đã chặn link Discord cũ:", txt, "->", CONFIG.DISCORD_LINK) end
                return CONFIG.DISCORD_LINK
            end
        end
        return txt
    end
    local ok, env = pcall(function() return (getgenv and getgenv()) or _G end)
    if not ok or type(env) ~= "table" then env = _G end
    for _, n in ipairs({ "setclipboard", "toclipboard", "set_clipboard", "writeclipboard" }) do
        local orig = env[n]
        if type(orig) == "function" then
            pcall(function()
                env[n] = function(txt, ...) return orig(fix(txt), ...) end
            end)
        end
    end
    pcall(function()
        if type(Clipboard) == "table" and type(Clipboard.set) == "function" then
            local orig = Clipboard.set
            Clipboard.set = function(txt, ...) return orig(fix(txt), ...) end
        end
    end)
end

-- ================= KHỞI ĐỘNG =================
local started = false
local function start()
    if started then return end
    started = true
    watchUntil = os.clock() + 180

    -- tải mã hub gốc song song với việc dựng ảnh, rồi chạy ngay khi ảnh đã sẵn sàng
    local src
    task.spawn(function()
        local ok, res = pcall(function() return game:HttpGet(CONFIG.SOURCE) end)
        if ok and type(res) == "string" and #res > 0 then
            src = res
        else
            src = false
            warn("[HYDROGEN] không tải được hub gốc:", res)
        end
    end)
    pcall(installClipboardGuard)
    pcall(prepareAssets)

    -- vòng lặp riêng: tên menu + logo "V" cạnh tên + logo nút nổi (chạy ngay từ đầu, tối đa 15 phút)
    task.spawn(function()
        local t0 = os.clock()
        local logoDone, launcherAt, seen = false, nil, 0
        while not STOPPED and os.clock() - t0 < 900 do
            local el0 = os.clock() - t0
            task.wait((el0 < 60 and 1) or (el0 < 120 and 2) or 4)
            if ASSET.logo then
                local main = findMainWindow()
                if main then
                    seen = seen + 1
                    if not titleDone then titleDone = markTitle(main) end
                    if not platesDone then
                        local okT, nT = pcall(styleTabs, main)
                        if okT and nT >= 4 then
                            platesDone = true
                            print("[HYDROGEN] đã làm đẹp " .. nT .. " nút tab")
                        elseif not okT then
                            warn("[HYDROGEN] lỗi styleTabs:", nT)
                        end
                    end
                    if not logoDone then
                        local okL, resL = pcall(headerLogo, main, seen >= 3)
                        if not okL then warn("[HYDROGEN] lỗi headerLogo:", resL) end
                        logoDone = okL and resL == true
                        if logoDone then print("[HYDROGEN] đã đổi logo cạnh tên menu") end
                    end
                end
                local okF, resF = pcall(launcherLogo)
                if not okF then warn("[HYDROGEN] lỗi launcherLogo:", resF) end
                if okF and resF and not launcherAt then
                    launcherAt = os.clock()
                    print("[HYDROGEN] đã đổi logo nút thu gọn")
                end
            end
            if titleDone and logoDone and launcherAt and platesDone and os.clock() - t0 > 60 then break end
        end
    end)
    local t0 = os.clock()
    while src == nil and os.clock() - t0 < 20 do task.wait() end

    if type(src) == "string" then
        task.spawn(function()
            local ok, err = pcall(function() loadstring(src)() end)
            if not ok then warn("[HYDROGEN] lỗi khi chạy hub gốc:", err) end
            watchUntil = math.max(watchUntil, os.clock() + 30)
        end)
    end
end

-- ================= ẢNH NHÚNG (JPEG base64): logo tròn + nền — đừng sửa =================
DATA.logo = table.concat({
"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",
})

DATA.bg = table.concat({
"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",
"kYOtNEyhR//Z",
})


DATA.egg = table.concat({
"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",
"YII=",
})


start()
