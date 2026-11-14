--[[
    KROBUS HUB v1.7.2  |  Throw Food for Animals
    Menu ngang kiểu Venyx. Tab chỉ có icon, mỗi trang có tên riêng.
      Tab 1 (ngôi nhà viền)  : Player Info
      Tab 2 (miếng thịt viền): Auto Farm  -> Pull-up Exercises / Throw / Auto Update / Auto Sell
      Tab 3 (bánh răng)      : Settings   -> Language / Boost FPS and Fix Lag

    v1.7.2:
      - Auto throw: chọn đúng sàn ném (bỏ qua tường), không thấy "Nhấn để ném" sau 4s thì loại điểm đó và thử điểm khác.
      - Vào chỗ ném 1.158s thì bấm màn hình 1 lần (Hub.Targets.PressDelay), không đuổi theo thanh sức mạnh nữa.
      - Bỏ danh sách Animation: luôn là "Không hoạt ảnh", camera đứng yên tại người chơi.
      - Thấy chữ "bỏ qua / skip" thì bấm màn hình 5 lần.
      - Sau khi nhận pet tự Equip best. Auto pull-up bật => tập xà nhanh x5 (Hub.Targets.PullSpeed).
      - Auto upgrade bar / food: đọc tiền chắc hơn, dịch chuyển tới bục nâng cấp rồi quay về, mở Food Shop đúng cách và mua / trang bị món mới.
      - Vật ném bay đến cuối biome Eclipse Kingdom (tự tìm khu Eclipse lớn nhất).

    LƯU Ý: script tìm xà ngang, chỗ ném, thanh sức mạnh, nút nâng cấp, Food Shop bằng cách
    dò tên trong Workspace/PlayerGui. Nếu game đặt tên khác, sửa Hub.Targets / Hub.Hooks:
        getgenv().KROBUS_HUB.Targets.PullUpBar = {"tên part của xà"}
        getgenv().KROBUS_HUB.Targets.PullUpBarOverride = function() return workspace.X.Y end
        getgenv().KROBUS_HUB.Targets.ThrowSpotOverride = function() return workspace.X.Y end   -- sàn ném đúng (giữa 2 bờ tường)
        getgenv().KROBUS_HUB.Hooks.GetMoney = function() return số_tiền end
        getgenv().KROBUS_HUB.Hooks.GetUpgradeCost = function() return giá_nâng_cấp_xà end
        getgenv().KROBUS_HUB.Hooks.BuyFood = function(tênThứcĂn) ... end
        getgenv().KROBUS_HUB.Hooks.SellPets = function(maxRate) ... end   -- tự viết cách bán pet có $/s <= maxRate
        getgenv().KROBUS_HUB.Hooks.GetPower = function() return giá_trị_thanh_hiện_tại_0_đến_20 end
        getgenv().KROBUS_HUB.Targets.EclipsePos = Vector3.new(x, y, z)   -- điểm CUỐI biome Eclipse Kingdom nếu script không tự tìm được
        getgenv().KROBUS_HUB.Targets.Flight = { {khoảng_cách, tốc_độ}, ... }   -- bảng tốc độ vật ném (mặc định tối đa 2200 stud/s)
        getgenv().KROBUS_HUB.Targets.CruiseHeight / SlideDist = 50 / 1000   -- độ cao bay và quãng đường cầu trượt hạ xuống đất
        getgenv().KROBUS_HUB.Targets.PressDelay = 1.158   -- giây từ lúc vào chỗ ném đến lúc bấm
        getgenv().KROBUS_HUB.Targets.PullSpeed = 5        -- hệ số tăng tốc tập xà
]]

local getgenv = getgenv or function() return _G end
local env = getgenv()
if env.KROBUS_HUB and env.KROBUS_HUB.Unload then pcall(env.KROBUS_HUB.Unload) end

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UIS = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Stats = game:GetService("Stats")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")
local GuiService = game:GetService("GuiService")
local Lighting = game:GetService("Lighting")
local VirtualUser = game:GetService("VirtualUser")
local VIM = game:GetService("VirtualInputManager")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

-- ====================== CẤU HÌNH ======================
local HUB_NAME, VERSION, GAME_NAME = "KROBUS", "1.7.2", "Throw Food for Animals"
local LOGO = "rbxassetid://137392525400802"
local BG = "rbxassetid://107298266965019"
local DISCORD_LINK = "https://discord.gg/fkswhfyqb"
local DISCORD_NAME = "SOLIEY DISCORD"

local C = {
	bg = Color3.fromRGB(16, 16, 20), panel = Color3.fromRGB(24, 24, 30), panel2 = Color3.fromRGB(36, 36, 45),
	field = Color3.fromRGB(38, 38, 48), stroke = Color3.fromRGB(56, 56, 70), text = Color3.fromRGB(238, 238, 244),
	sub = Color3.fromRGB(148, 148, 164), accent = Color3.fromRGB(176, 150, 255), on = Color3.fromRGB(214, 214, 226),
	off = Color3.fromRGB(58, 58, 72), good = Color3.fromRGB(80, 220, 140), warn = Color3.fromRGB(255, 190, 80),
	border = Color3.fromRGB(120, 120, 128), -- viền xám của các khung tính năng
}
local F = { black = Enum.Font.GothamBlack, bold = Enum.Font.GothamBold, med = Enum.Font.GothamMedium }

-- Danh sách thức ăn (tên, giá). Shank chưa có giá nên bỏ qua.
local FOODS = {
	{ "Carrot", "0" }, { "Apple", "$30" }, { "Banana", "$150" }, { "Toast", "$4K" }, { "Orange", "$20K" },
	{ "Pear", "$200K" }, { "Cheese", "$1M" }, { "Bread Loaf", "$12M" }, { "Watermelon", "$60M" },
	{ "Croissant", "$650M" }, { "Chocolate", "$3.2B" }, { "Mushroom", "$30B" }, { "Bacon", "$150B" },
	{ "Burger", "$1.3T" }, { "Fillet", "$57T" }, { "Steak", "$1.5Qa" }, { "Royal Steak", "$50Qa" },
	{ "Golden Apple", "$120Qa" }, { "Crystal Melon", "$4Qi" }, { "Ember Bacon", "$18Qi" },
	{ "Lava Steak", "$120Qi" }, { "Elder Strawberry", "$700Qi" }, { "Phoenix Fillet", "$4Sx" },
	{ "Star Jelly", "$27Sx" }, { "Dragon's Apple", "$180Sx" }, { "Starlight Donut", "$450Sx" },
	{ "Glowshroom", "$1.4Sp" }, { "Sunday Tower", "$3.5Sp" }, { "Golden Corn", "$2.5Oc" },
	{ "Roast Turkey", "$28Oc" }, { "Caramel Apple", "$250Oc" }, { "Candy Corn", "$750No" },
	{ "Hot Cider", "$8.5Dc" }, { "Golden Pumpkin", "$75Dc" }, { "Ghost Chowder", "$18Ud" },
	{ "Calamari Rings", "$200Ud" }, { "Phantom Lobster", "$1.8Dd" },
}
local MONEY_SUFFIXES = {
    "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd",
    "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg", "Uvg", "Dvg", "Tvg",
    "Qavg", "Qivg", "Sxvg", "Spvg", "Ocvg", "Novg", "Tg", "Utg", "Dtg", "Ttg",
    "Qatg", "Qitg", "Sxtg", "Sptg", "Octg", "Notg", "Qdg",
}
local SUF = {}
for i, suffix in ipairs(MONEY_SUFFIXES) do
    local value = 10 ^ (i * 3)
    SUF[suffix] = value
    SUF[suffix:lower()] = value
end
local function parseMoney(s)
	s = tostring(s):gsub(",", "")
	local n, suf = s:match("%$?%s*([%d%.]+)%s*(%a*)")
	n = tonumber(n)
	if not n then return nil end
	if suf ~= "" then
		local m = SUF[suf] or SUF[suf:lower()]
		if not m then return nil end
		n = n * m
	end
	return n
end

-- Auto Sell: chỉ bán pet có thu nhập BẰNG HOẶC THẤP HƠN ngưỡng đã chọn.
-- Danh sách đúng thứ tự người dùng cung cấp: $500/s, $1K/s, $1M/s, ... đến $1Qdg/s.
local SELL_STEPS = { { "$500/s", 500 } }
for _, suffix in ipairs(MONEY_SUFFIXES) do
	SELL_STEPS[#SELL_STEPS + 1] = { "$1" .. suffix .. "/s", SUF[suffix] }
end
local SELL_OPTIONS, SELL_LIMITS = {}, {}
for _, st in ipairs(SELL_STEPS) do
	local k = "<= " .. st[1]
	SELL_OPTIONS[#SELL_OPTIONS + 1] = k; SELL_LIMITS[k] = st[2]
end

-- ====================== NGÔN NGỮ ======================
local Strings = {
	en = {
		player_info = "Player Info", auto_farm = "Auto Farm", settings = "Settings",
		welcome = "Welcome back", discord_sub = "Updates, keys, support", copy_invite = "Copy invite", copied_discord = "Discord link copied",
		rejoin = "Rejoin", server_hop = "Server hop", copy_job = "Copy Job ID", unload = "Unload hub", copied_job = "Job ID copied",
		no_clip = "Executor can't copy", hopping = "Switching server...", no_server = "No suitable server found",
		session = "Session", fps = "FPS", ping = "Ping", players = "Players", session_time = "Session time", server_time = "Server time",
		account_age = "Account age", days = "days",
		pullup = "Pull-up Exercises", auto_pullup = "Auto pull-ups", move_mode = "Move to bar", auto_x2 = "Auto click x2",
		walk = "Walk", teleport = "Teleport",
		throw = "Throw", auto_throw = "Auto throw", animation = "Animation", anim_on = "With animation", anim_off = "No animation",
		auto_update = "Auto Update", up_bar = "Auto upgrade bar", up_food = "Auto upgrade food",
		language = "Language", boost_card = "Boost FPS and Fix Lag", boost_fps = "Boost FPS", fix_lag = "Fix lag",
		interface = "Interface", notifications = "Notifications", toggle_key = "Toggle key", bg_opacity = "Background opacity",
		search = "Search", copy_link = "Copy Discord link", loaded = "loaded", idle = "Idle", running = "Running",
		no_bar = "Pull-up bar not found", no_spot = "Throw spot not found", no_shop = "Food Shop not found - open it once by hand",
		food_target = "Food to buy", food_best = "Best affordable", no_cost = "Upgrade cost not found (set Hooks.GetUpgradeCost)", no_gauge = "Power bar not found (set Hooks.GetPower)",
		no_money = "Can't read your money (set Hooks.GetMoney)",
		set_eclipse = "Save Eclipse point (stand at the end)", eclipse_saved = "Eclipse point saved",
		auto_sell = "Auto sell", auto_sell_pets = "Auto sell pets", sell_max = "Max $/s", no_sell = "Sell button/pets not found - open the Animals panel",
	},
	vi = {
		player_info = "Thông tin Player", auto_farm = "Tự động farm", settings = "Cài đặt",
		welcome = "Chào mừng trở lại", discord_sub = "Cập nhật, key, hỗ trợ", copy_invite = "Copy link mời", copied_discord = "Đã copy link Discord",
		rejoin = "Vào lại", server_hop = "Đổi server", copy_job = "Copy Job ID", unload = "Tắt hub", copied_job = "Đã copy Job ID",
		no_clip = "Executor không hỗ trợ copy", hopping = "Đang chuyển server...", no_server = "Không tìm được server phù hợp",
		session = "Phiên chơi", fps = "FPS", ping = "Ping", players = "Người chơi", session_time = "Thời gian chơi", server_time = "Thời gian server",
		account_age = "Tuổi tài khoản", days = "ngày",
		pullup = "Bài tập xà đơn", auto_pullup = "Tự động tập xà", move_mode = "Cách đi đến xà", auto_x2 = "Tự bấm x2",
		walk = "Đi bộ", teleport = "Dịch chuyển",
		throw = "Ném thức ăn", auto_throw = "Tự động ném", animation = "Hoạt ảnh", anim_on = "Có hoạt ảnh", anim_off = "Không hoạt ảnh",
		auto_update = "Tự động nâng cấp", up_bar = "Tự nâng cấp xà", up_food = "Tự nâng cấp thức ăn",
		language = "Ngôn ngữ", boost_card = "Tăng FPS và giảm lag", boost_fps = "Tăng FPS", fix_lag = "Giảm lag",
		interface = "Giao diện", notifications = "Thông báo", toggle_key = "Phím mở menu", bg_opacity = "Độ rõ nền",
		search = "Tìm kiếm", copy_link = "Copy link Discord", loaded = "đã tải", idle = "Chờ", running = "Đang chạy",
		no_bar = "Không tìm thấy xà ngang", no_spot = "Không tìm thấy chỗ ném", no_shop = "Không thấy Food Shop - hãy tự mở 1 lần",
		food_target = "Món cần mua", food_best = "Tốt nhất mua được", no_cost = "Không đọc được giá nâng cấp (đặt Hooks.GetUpgradeCost)", no_gauge = "Không thấy thanh sức mạnh (đặt Hooks.GetPower)",
		no_money = "Không đọc được tiền (đặt Hooks.GetMoney)",
		set_eclipse = "Lưu điểm Eclipse (đứng ở cuối biome)", eclipse_saved = "Đã lưu điểm Eclipse",
		auto_sell = "Tự động bán", auto_sell_pets = "Tự động bán pets", sell_max = "Tối đa $/s", no_sell = "Không thấy nút bán/pets - hãy mở bảng Động vật",
	},
}
local Lang = "en"
local function tr(k) return (Strings[Lang] and Strings[Lang][k]) or Strings.en[k] or k end

local Hub = { Name = HUB_NAME, Version = VERSION, Config = {}, Features = {}, Alive = true, Hooks = {}, BadSpots = {},
	Targets = {
		PullUpBar = { "pullup", "pull-up", "pull_up", "pull up", "chinup", "chin-up", "horizontalbar", "crossbar" },
		ThrowSpot = { "throwspot", "throw_spot", "throw spot", "throwzone", "throw zone", "throwpad", "throwarea", "throw", "launch", "runway", "ném" },
		WallWords = { "wall", "tường", "fence", "barrier", "border", "rail", "bờ" }, -- tên chứa các từ này không phải sàn ném
		EclipseKingdom = { "eclipse" },
		UpgradePad = { "upgradepad", "upgrade_pad", "upgrade pad", "upgradebutton", "upgrade" },
		ThrowHold = 1.4, MaxPower = 20, BoostSpeed = 450,
		PressDelay = 1.158, -- giây: vào chỗ ném được chừng này thì bấm màn hình 1 lần
		PullSpeed = 5, -- hệ số tăng tốc tập xà khi Auto pull-up bật (cơ chế ẩn)
		MoveSpeed = 45, -- studs/giây khi tự đi đến xà ngang và chỗ ném (tắt tính năng là về tốc độ bình thường)
		Projectile = { "food", "throw", "projectile", "thrown" }, -- tên vật ném (chỉ cần khi vật ném bị anchor); tên các món ăn được thêm bên dưới
		PressLead = 0.05,
		Flight = { { 5000, 2200 }, { 1500, 2200 }, { 1000, 1500 }, { 700, 1000 }, { 400, 650 }, { 200, 350 }, { 80, 150 }, { 30, 45 }, { 0, 0 } },
		CruiseHeight = 50, SlideDist = 1000, -- bay cao 50 stud; hãm tốc và hạ dần trong 1000 stud cuối biome
		-- Flight: { khoảng cách còn lại (stud), tốc độ ngang (stud/s) }
	} }
for _, f in ipairs(FOODS) do table.insert(Hub.Targets.Projectile, f[1]:lower()) end
env.KROBUS_HUB = Hub
local Config, conns, Bound, Internal = Hub.Config, {}, {}, {}
Config.throwAnim = "anim_off" -- luôn là "Không hoạt ảnh"
local function bind(signal, fn) local c = signal:Connect(fn); table.insert(conns, c); return c end
local function bt(inst, prop, fn) table.insert(Bound, { inst = inst, prop = prop, fn = fn }); inst[prop] = fn(); return inst end

-- ====================== HELPER UI ======================
local function new(class, props)
	local o = Instance.new(class)
	for k, v in pairs(props or {}) do o[k] = v end
	return o
end
local function corner(o, r) return new("UICorner", { CornerRadius = UDim.new(0, r), Parent = o }) end
local function plainStroke(o, color, th) -- viền tĩnh (dùng cho icon, cần đổi màu trực tiếp)
	return new("UIStroke", { Color = color, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function stroke(o, color, th) -- viền tĩnh (không animation để đỡ lag)
	return new("UIStroke", { Color = color, Thickness = th or 1, ApplyStrokeMode = Enum.ApplyStrokeMode.Border, Parent = o })
end
local function tween(o, t, props)
	TweenService:Create(o, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), props):Play()
end
local function label(parent, text, size, font, color, props)
	local l = new("TextLabel", { BackgroundTransparency = 1, Text = text, TextSize = size, Font = font, TextColor3 = color,
		TextXAlignment = Enum.TextXAlignment.Left, Parent = parent })
	for k, v in pairs(props or {}) do l[k] = v end
	return l
end
local function tlabel(parent, key, size, font, color, props, upper)
	local l = label(parent, "", size, font, color, props)
	bt(l, "Text", function() local s = tr(key); return (upper and Lang == "en") and s:upper() or s end)
	return l
end
local function pad(o, t, b, l, r)
	return new("UIPadding", { PaddingTop = UDim.new(0, t), PaddingBottom = UDim.new(0, b), PaddingLeft = UDim.new(0, l), PaddingRight = UDim.new(0, r), Parent = o })
end
local function list(o, padding, dir)
	return new("UIListLayout", { Padding = UDim.new(0, padding), SortOrder = Enum.SortOrder.LayoutOrder, FillDirection = dir or Enum.FillDirection.Vertical, Parent = o })
end
local function safeCall(fn, ...) local ok, err = pcall(fn, ...); if not ok then warn("[KROBUS] " .. tostring(err)) end return ok end
local function copy(text)
	local fn = setclipboard or toclipboard
	if fn then return pcall(fn, text) end
	return false
end
local function getParent()
	local ok, ui = pcall(function() return gethui and gethui() end)
	if ok and ui then return ui end
	local ok2, core = pcall(function() return game:GetService("CoreGui") end)
	if ok2 and core then
		local probe = Instance.new("Folder")
		local okp = pcall(function() probe.Parent = core end)
		probe:Destroy()
		if okp then return core end
	end
	return PlayerGui
end

-- Tải ảnh (ID là Image): đặt thẳng rbxassetid, KHÔNG bao giờ xoá ảnh. Nếu sau 6s vẫn chưa tải được thì báo lý do
-- thật (AssetFetchStatus) bằng thông báo và hiện chữ K dự phòng; ảnh tải xong sau đó thì chữ K tự mất.
local ContentProvider = game:GetService("ContentProvider")
local function logoFallback(parent)
	local t = new("TextLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(1, 1),
		BackgroundTransparency = 1, Text = "K", Font = Enum.Font.GothamBlack, TextScaled = true, TextColor3 = Color3.fromRGB(255, 205, 0),
		ZIndex = parent.ZIndex + 1, Parent = parent })
	new("UIStroke", { Color = Color3.fromRGB(120, 30, 0), Thickness = 1.2, Parent = t })
	return t
end
local function resolveDecal(id) -- ID là Decal (không hiện được trên ImageLabel): lấy ID ảnh thật bên trong
	local num = tostring(id):match("%d+")
	if not num then return nil end
	local ok, objs = pcall(function() return game:GetObjects("rbxassetid://" .. num) end)
	if ok and type(objs) == "table" and objs[1] then
		local o, tex = objs[1], nil
		if o:IsA("Decal") or o:IsA("Texture") then tex = o.Texture
		elseif o:IsA("ImageLabel") or o:IsA("ImageButton") then tex = o.Image end
		pcall(function() o:Destroy() end)
		if tex and tex ~= "" then return tex end
	end
	return nil
end
local function loadImage(img, id, showK, name)
	img.Image = id
	task.spawn(function()
		for _ = 1, 25 do
			if not img.Parent then return end
			if img.IsLoaded then return end
			task.wait(0.1)
		end
		if not img.Parent then return end
		local tex = resolveDecal(id)
		if tex then
			img.Image = tex
			for _ = 1, 50 do
				if not img.Parent then return end
				if img.IsLoaded then return end
				task.wait(0.1)
			end
		end
		local status = "?"
		pcall(function() ContentProvider:PreloadAsync({ img }, function(_, st) status = tostring(st) end) end)
		if Hub.Notify then Hub.Notify("Ảnh " .. name .. " chưa tải: " .. status) end
		if showK then
			local k = logoFallback(img)
			img:GetPropertyChangedSignal("IsLoaded"):Connect(function() if img.IsLoaded and k.Parent then k:Destroy() end end)
		end
	end)
end

-- Icon vẽ bằng đường kẻ / viền, không tô màu
local function line(parent, x1, y1, x2, y2, color, parts)
	local dx, dy = x2 - x1, y2 - y1
	local f = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset((x1 + x2) / 2, (y1 + y2) / 2),
		Size = UDim2.fromOffset(math.sqrt(dx * dx + dy * dy) + 1, 1.8), Rotation = math.deg(math.atan2(dy, dx)),
		BackgroundColor3 = color, BorderSizePixel = 0, Parent = parent })
	corner(f, 1)
	if parts then table.insert(parts, { inst = f }) end
	return f
end
local function outline(parent, x, y, w, h, color, parts, roundScale)
	local f = new("Frame", { Position = UDim2.fromOffset(x, y), Size = UDim2.fromOffset(w, h), BackgroundTransparency = 1, Parent = parent })
	local s = plainStroke(f, color, 1.8)
	if roundScale then new("UICorner", { CornerRadius = UDim.new(roundScale, 0), Parent = f }) end
	if parts then table.insert(parts, { inst = f, stroke = s }) end
	return f
end
local function drawIcon(kind, parent, color)
	local box = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(20, 20),
		BackgroundTransparency = 1, Parent = parent })
	local parts = {}
	if kind == "house" then
		line(box, 2, 10, 10, 2, color, parts); line(box, 10, 2, 18, 10, color, parts)
		line(box, 4, 8, 4, 18, color, parts); line(box, 16, 8, 16, 18, color, parts)
		line(box, 4, 18, 16, 18, color, parts); outline(box, 8, 12, 4, 6, color, parts)
	elseif kind == "meat" then -- đùi thịt: phần thịt tròn + xương + hai đầu xương
		outline(box, 7, 1, 12, 11, color, parts, 0.5)
		line(box, 9, 11, 4, 16, color, parts)
		outline(box, 0.5, 14, 4.5, 4.5, color, parts, 0.5)
		outline(box, 3.5, 17, 4.5, 3, color, parts, 0.5)
		line(box, 11, 5, 14, 4, color, parts)
	elseif kind == "gear" then
		outline(box, 3, 3, 14, 14, color, parts, 0.5); outline(box, 7, 7, 6, 6, color, parts, 0.5)
		line(box, 10, 0.5, 10, 3, color, parts); line(box, 10, 17, 10, 19.5, color, parts)
		line(box, 0.5, 10, 3, 10, color, parts); line(box, 17, 10, 19.5, 10, color, parts)
	end
	return function(c)
		for _, p in ipairs(parts) do
			if p.stroke then p.stroke.Color = c else p.inst.BackgroundColor3 = c end
		end
	end
end
local function chevron(parent, color)
	local box = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(10, 6),
		BackgroundTransparency = 1, Parent = parent })
	line(box, 0.5, 0.5, 5, 5, color); line(box, 5, 5, 9.5, 0.5, color)
end

-- ====================== GUI GỐC ======================
local Gui = new("ScreenGui", { Name = "KROBUS_HUB", ResetOnSpawn = false, IgnoreGuiInset = true,
	ZIndexBehavior = Enum.ZIndexBehavior.Sibling, DisplayOrder = 999 })
pcall(function() if syn and syn.protect_gui then syn.protect_gui(Gui) end end)
Gui.Parent = getParent()

local vp = (workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize) or Vector2.new(1280, 720)
local W, H = math.clamp(vp.X - 140, 380, 600), math.clamp(vp.Y - 60, 220, 390)

local Main = new("Frame", { Name = "Main", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(W, H), BackgroundColor3 = C.bg, ClipsDescendants = true, Parent = Gui })
corner(Main, 20); stroke(Main, C.stroke, 1.4)
local BgImage = new("ImageLabel", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Crop,
	ImageTransparency = 0.15, ImageColor3 = Color3.fromRGB(170, 170, 180), ZIndex = 0, Parent = Main })
corner(BgImage, 20)
loadImage(BgImage, BG, false, "nền")
-- nền gradient luôn có sẵn phía sau, nên menu vẫn có nền đẹp dù ảnh nền không tải được
new("UIGradient", { Rotation = 35, Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, Color3.fromRGB(34, 18, 46)),
	ColorSequenceKeypoint.new(0.55, Color3.fromRGB(16, 16, 22)), ColorSequenceKeypoint.new(1, Color3.fromRGB(46, 14, 18)) }), Parent = Main })

local Top = new("Frame", { Size = UDim2.new(1, 0, 0, 46), BackgroundTransparency = 1, Parent = Main })
local TopLogo = new("ImageLabel", { Position = UDim2.fromOffset(10, 9), Size = UDim2.fromOffset(28, 28), BackgroundTransparency = 1,
	ScaleType = Enum.ScaleType.Fit, Parent = Top })
loadImage(TopLogo, LOGO, true, "logo")
local TitleBox = new("Frame", { Position = UDim2.fromOffset(46, 0), Size = UDim2.new(1, -230, 1, 0), BackgroundTransparency = 1, Parent = Top })
list(TitleBox, 8, Enum.FillDirection.Horizontal).VerticalAlignment = Enum.VerticalAlignment.Center
local TitleLabel = label(TitleBox, HUB_NAME, 18, F.black, C.text, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20) })
local function pill(parent, text, color)
	local p = label(parent, text, 11, F.bold, color, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20),
		BackgroundTransparency = 0.1, BackgroundColor3 = C.field, TextXAlignment = Enum.TextXAlignment.Center })
	corner(p, 10); pad(p, 0, 0, 9, 9)
	return p
end
label(TitleBox, "/ " .. GAME_NAME, 12, F.med, C.sub, { AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 20), TextTruncate = Enum.TextTruncate.AtEnd })
pill(TitleBox, "v" .. VERSION, C.text)
local StatusPill = pill(TitleBox, "", C.sub)
local statusRunning = false
bt(StatusPill, "Text", function() return tr(statusRunning and "running" or "idle") end)
local function refreshStatus()
	local run = Config.autoPullup or Config.autoThrow or Config.upBar or Config.upFood or Config.autoSellPets
	statusRunning = run and true or false
	StatusPill.Text = tr(statusRunning and "running" or "idle")
	StatusPill.TextColor3 = statusRunning and C.good or C.sub
end

local SearchWrap = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -44, 0.5, 0), Size = UDim2.fromOffset(150, 28),
	BackgroundColor3 = C.field, BackgroundTransparency = 0.15, Parent = Top })
corner(SearchWrap, 14); stroke(SearchWrap, C.stroke, 1)
local SearchBox = new("TextBox", { Size = UDim2.new(1, -20, 1, 0), Position = UDim2.fromOffset(12, 0), BackgroundTransparency = 1, Text = "",
	PlaceholderColor3 = C.sub, TextColor3 = C.text, Font = F.med, TextSize = 12, TextXAlignment = Enum.TextXAlignment.Left,
	ClearTextOnFocus = false, Parent = SearchWrap })
bt(SearchBox, "PlaceholderText", function() return tr("search") end)

local MinBtn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -10, 0.5, 0), Size = UDim2.fromOffset(28, 28),
	BackgroundColor3 = C.field, BackgroundTransparency = 0.15, Text = "", AutoButtonColor = false, Parent = Top })
corner(MinBtn, 14); stroke(MinBtn, C.stroke, 1)
new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(10, 2),
	BackgroundColor3 = C.text, BorderSizePixel = 0, Parent = MinBtn })

-- Thanh tab: chỉ có icon, không chữ
local Sidebar = new("Frame", { Position = UDim2.fromOffset(8, 52), Size = UDim2.new(0, 46, 1, -60), BackgroundColor3 = C.panel,
	BackgroundTransparency = 0.2, Parent = Main })
corner(Sidebar, 12); stroke(Sidebar, C.stroke, 1); pad(Sidebar, 6, 6, 4, 4)
list(Sidebar, 6).HorizontalAlignment = Enum.HorizontalAlignment.Center
local Content = new("Frame", { Position = UDim2.fromOffset(62, 52), Size = UDim2.new(1, -70, 1, -60), BackgroundTransparency = 1, Parent = Main })

-- ====================== THÔNG BÁO ======================
local function notify(text)
	if Config.notifications == false then return end
	local t = label(Gui, text, 13, F.med, C.text, { AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, 30),
		AutomaticSize = Enum.AutomaticSize.X, Size = UDim2.fromOffset(0, 34), BackgroundColor3 = C.panel, BackgroundTransparency = 0.05,
		TextXAlignment = Enum.TextXAlignment.Center, ZIndex = 100 })
	corner(t, 10); stroke(t, C.stroke, 1); pad(t, 0, 0, 16, 16)
	tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, -24) })
	task.delay(2.4, function()
		if t.Parent then tween(t, 0.25, { Position = UDim2.new(0.5, 0, 1, 40) }); task.wait(0.3); t:Destroy() end
	end)
end
Hub.Notify = notify
local warned = {}
local function warnOnce(key) if not warned[key] then warned[key] = true; notify(tr(key)) end end

-- ====================== THÀNH PHẦN ======================
local Rows = {}
local function applySearch()
	local q = SearchBox.Text:lower()
	for _, r in ipairs(Rows) do r.frame.Visible = (q == "" or r.label.Text:lower():find(q, 1, true) ~= nil) end
end
bind(SearchBox:GetPropertyChangedSignal("Text"), applySearch)
local function refreshLang()
	for _, b in ipairs(Bound) do if b.inst.Parent then b.inst[b.prop] = b.fn() end end
	applySearch()
end

local function fire(key, value)
	local fn = Internal[key]
	if fn then task.spawn(safeCall, fn, value) end
	local hook = Hub.Features[key]
	if hook then task.spawn(safeCall, hook, value) end
	refreshStatus()
end

local function createPage(name)
	local sf = new("ScrollingFrame", { Name = name, Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0,
		ScrollBarThickness = 3, ScrollBarImageColor3 = C.stroke, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
		Visible = false, Parent = Content })
	pad(sf, 0, 8, 0, 6); list(sf, 8)
	return sf
end
local function pageHeader(page, key)
	local h = new("Frame", { Size = UDim2.new(1, 0, 0, 34), BackgroundTransparency = 1, LayoutOrder = 1, Parent = page })
	tlabel(h, key, 20, F.bold, C.text, { Size = UDim2.new(1, 0, 1, 0) })
	return h
end
local function columns(parent, ratio)
	ratio = ratio or 0.5
	local row = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 2, Parent = parent })
	local l = new("Frame", { Size = UDim2.new(ratio, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = row })
	local r = new("Frame", { Position = UDim2.new(ratio, 4, 0, 0), Size = UDim2.new(1 - ratio, -4, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Parent = row })
	list(l, 8); list(r, 8)
	return l, r
end
local function card(parent, titleKey, dotColor)
	local f = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundColor3 = C.panel,
		BackgroundTransparency = 0.18, Parent = parent })
	corner(f, 12); stroke(f, C.border, 1.5); pad(f, 8, 10, 12, 12); list(f, 4)
	if titleKey then
		local h = new("Frame", { Size = UDim2.new(1, 0, 0, 22), BackgroundTransparency = 1, LayoutOrder = -1, Parent = f })
		corner(new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 0, 0.5, 0), Size = UDim2.fromOffset(7, 7),
			BackgroundColor3 = dotColor or C.accent, BorderSizePixel = 0, Parent = h }), 4)
		tlabel(h, titleKey, 11, F.bold, C.sub, { Position = UDim2.fromOffset(16, 0), Size = UDim2.new(1, -16, 1, 0) }, true)
	end
	return f
end
local function row(cardF, key, reserve)
	local r = new("Frame", { Size = UDim2.new(1, 0, 0, 30), BackgroundTransparency = 1, Parent = cardF })
	local l = tlabel(r, key, 13, F.med, C.text, { Size = UDim2.new(1, -(reserve or 50), 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	table.insert(Rows, { frame = r, label = l })
	return r
end

local function addToggle(cardF, key, cfgKey, default)
	local r = row(cardF, key, 50)
	Config[cfgKey] = default or false
	local track = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(38, 20),
		Text = "", AutoButtonColor = false, BackgroundColor3 = C.off, Parent = r })
	corner(track, 10)
	local knob = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(0, 3, 0.5, 0), Size = UDim2.fromOffset(14, 14),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track })
	corner(knob, 7)
	local function render()
		local on = Config[cfgKey]
		tween(track, 0.15, { BackgroundColor3 = on and C.on or C.off })
		tween(knob, 0.15, { Position = on and UDim2.new(1, -17, 0.5, 0) or UDim2.new(0, 3, 0.5, 0),
			BackgroundColor3 = on and Color3.fromRGB(40, 40, 52) or Color3.new(1, 1, 1) })
	end
	render()
	bind(track.MouseButton1Click, function() Config[cfgKey] = not Config[cfgKey]; render(); fire(cfgKey, Config[cfgKey]) end)
end

local Popup
local Overlay = new("Frame", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Visible = false, ZIndex = 20, Parent = Main })
local Blocker = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 20, Parent = Overlay })
local function closePopup() if Popup then Popup:Destroy(); Popup = nil end Overlay.Visible = false end
bind(Blocker.MouseButton1Click, closePopup)
local function openPopup(anchor, options, current, onPick)
	closePopup()
	Overlay.Visible = true
	local h = math.min(#options * 26 + 8, 170)
	local rel = anchor.AbsolutePosition - Main.AbsolutePosition
	local y = rel.Y + anchor.AbsoluteSize.Y + 2
	if y + h > Main.AbsoluteSize.Y - 4 then y = rel.Y - h - 2 end
	Popup = new("ScrollingFrame", { Position = UDim2.fromOffset(rel.X, y), Size = UDim2.fromOffset(math.max(anchor.AbsoluteSize.X, 118), h),
		BackgroundColor3 = C.panel2, BorderSizePixel = 0, ScrollBarThickness = 2, CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y, ZIndex = 21, Parent = Overlay })
	corner(Popup, 14); stroke(Popup, C.stroke, 1); pad(Popup, 4, 4, 4, 4); list(Popup, 2)
	for _, opt in ipairs(options) do
		local sel = (opt == current)
		local b = new("TextButton", { Size = UDim2.new(1, 0, 0, 24), BackgroundColor3 = C.field, BackgroundTransparency = sel and 0.2 or 1,
			Text = tr(opt), Font = F.med, TextSize = 12, TextColor3 = sel and C.accent or C.text, AutoButtonColor = false, ZIndex = 22, Parent = Popup })
		corner(b, 12)
		bind(b.MouseEnter, function() b.BackgroundTransparency = 0.2 end)
		bind(b.MouseLeave, function() b.BackgroundTransparency = sel and 0.2 or 1 end)
		bind(b.MouseButton1Click, function() closePopup(); onPick(opt) end)
	end
end
-- Danh sách chọn dạng viên thuốc, thu gọn
local function addDropdown(cardF, key, cfgKey, options, default)
	local r = row(cardF, key, 126)
	Config[cfgKey] = default or options[1]
	local btn = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(118, 26),
		BackgroundColor3 = C.field, BackgroundTransparency = 0.1, Text = "", AutoButtonColor = false, Parent = r })
	corner(btn, 13); stroke(btn, C.stroke, 1)
	local val = label(btn, "", 12, F.med, C.text, { Position = UDim2.fromOffset(12, 0), Size = UDim2.new(1, -32, 1, 0), TextTruncate = Enum.TextTruncate.AtEnd })
	bt(val, "Text", function() return tr(Config[cfgKey]) end)
	chevron(btn, C.sub)
	bind(btn.MouseButton1Click, function()
		openPopup(btn, options, Config[cfgKey], function(v) Config[cfgKey] = v; val.Text = tr(v); fire(cfgKey, v) end)
	end)
end

local function addSlider(cardF, key, cfgKey, min, max, default, fmt)
	local r = row(cardF, key, 150)
	fmt = fmt or tostring
	local off = new("TextButton", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, 0, 0.5, 0), Size = UDim2.fromOffset(46, 24),
		BackgroundColor3 = C.field, BackgroundTransparency = 0.1, Font = F.med, TextSize = 12, TextColor3 = C.text, AutoButtonColor = false, Text = "Off", Parent = r })
	corner(off, 12); stroke(off, C.stroke, 1)
	local hit = new("Frame", { AnchorPoint = Vector2.new(1, 0.5), Position = UDim2.new(1, -54, 0.5, 0), Size = UDim2.fromOffset(92, 22), BackgroundTransparency = 1, Parent = r })
	local track = new("Frame", { AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.new(1, 0, 0, 4),
		BackgroundColor3 = C.off, BorderSizePixel = 0, Parent = hit })
	corner(track, 2)
	local fill = new("Frame", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = C.on, BorderSizePixel = 0, Parent = track })
	corner(fill, 2)
	local knob = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(12, 12),
		BackgroundColor3 = Color3.new(1, 1, 1), BorderSizePixel = 0, Parent = track })
	corner(knob, 6)
	local function setVal(v, silent)
		v = math.clamp(math.floor(v + 0.5), min, max)
		Config[cfgKey] = v
		local f = (v - min) / (max - min)
		fill.Size = UDim2.fromScale(f, 1); knob.Position = UDim2.fromScale(f, 0.5)
		off.Text = (v <= min) and "Off" or fmt(v)
		if not silent then fire(cfgKey, v) end
	end
	setVal(default or min, true)
	local dragging = false
	local function fromX(x) setVal(min + math.clamp((x - track.AbsolutePosition.X) / track.AbsoluteSize.X, 0, 1) * (max - min)) end
	bind(hit.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = true; fromX(i.Position.X) end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then fromX(i.Position.X) end
	end)
	bind(UIS.InputEnded, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then dragging = false end
	end)
	bind(off.MouseButton1Click, function() setVal(min) end)
end

local function addButton(parent, key, cb, accent)
	local b = new("TextButton", { BackgroundColor3 = accent and C.accent or C.field, BackgroundTransparency = 0.1, Font = F.bold, TextSize = 12,
		TextColor3 = accent and Color3.fromRGB(20, 18, 30) or C.text, AutoButtonColor = false, Size = UDim2.new(1, 0, 0, 30), Text = "", Parent = parent })
	bt(b, "Text", function() return tr(key) end)
	corner(b, 15)
	if not accent then stroke(b, C.stroke, 1) end
	bind(b.MouseEnter, function() tween(b, 0.12, { BackgroundTransparency = 0 }) end)
	bind(b.MouseLeave, function() tween(b, 0.12, { BackgroundTransparency = 0.1 }) end)
	bind(b.MouseButton1Click, function() safeCall(cb) end)
	return b
end

-- ====================== TAB ======================
local Pages, TabButtons = {}, {}
local function selectTab(name)
	closePopup()
	for n, p in pairs(Pages) do p.Visible = (n == name) end
	for n, t in pairs(TabButtons) do
		local on = (n == name)
		tween(t.btn, 0.15, { BackgroundTransparency = on and 0.1 or 1 })
		t.recolor(on and C.accent or C.sub)
	end
	applySearch()
end
local function addTab(name, icon)
	local btn = new("TextButton", { Size = UDim2.fromOffset(36, 36), BackgroundColor3 = C.field, BackgroundTransparency = 1, Text = "",
		AutoButtonColor = false, Parent = Sidebar })
	corner(btn, 10); stroke(btn, C.border, 1.5)
	TabButtons[name] = { btn = btn, recolor = drawIcon(icon, btn, C.sub) }
	Pages[name] = createPage(name)
	bind(btn.MouseButton1Click, function() selectTab(name) end)
	return Pages[name]
end

-- ---------- Tab 1: Player Info (icon ngôi nhà viền) ----------
local statLabels = {}
do
	local page = addTab("info", "house")
	pageHeader(page, "player_info")
	local l, r = columns(page, 0.6)
	local wc = card(l, nil)
	local wrow = new("Frame", { Size = UDim2.new(1, 0, 0, 56), BackgroundTransparency = 1, Parent = wc })
	local av = new("ImageLabel", { Position = UDim2.fromOffset(0, 4), Size = UDim2.fromOffset(48, 48), BackgroundColor3 = C.field, Parent = wrow })
	corner(av, 24); stroke(av, C.accent, 1.5)
	task.spawn(function()
		local ok, img = pcall(Players.GetUserThumbnailAsync, Players, LocalPlayer.UserId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size100x100)
		if ok and av.Parent then av.Image = img end
	end)
	tlabel(wrow, "welcome", 11, F.med, C.sub, { Position = UDim2.fromOffset(58, 6), Size = UDim2.new(1, -58, 0, 14) })
	label(wrow, LocalPlayer.DisplayName, 18, F.bold, C.text, { Position = UDim2.fromOffset(58, 20), Size = UDim2.new(1, -58, 0, 22), TextTruncate = Enum.TextTruncate.AtEnd })
	local tags = new("Frame", { Size = UDim2.new(1, 0, 0, 20), BackgroundTransparency = 1, Parent = wc })
	list(tags, 6, Enum.FillDirection.Horizontal)
	pill(tags, "Throw Food", C.text); pill(tags, "@" .. LocalPlayer.Name, C.sub)

	local dc = card(r, nil)
	label(dc, DISCORD_NAME, 14, F.bold, C.text, { Size = UDim2.new(1, 0, 0, 20) })
	tlabel(dc, "discord_sub", 11, F.med, C.sub, { Size = UDim2.new(1, 0, 0, 16) })
	addButton(dc, "copy_invite", function()
		if copy(DISCORD_LINK) then notify(tr("copied_discord")) else notify(DISCORD_LINK) end
	end, true)

	local ac = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, LayoutOrder = 3, Parent = page })
	new("UIGridLayout", { CellSize = UDim2.new(0.25, -6, 0, 30), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = ac })
	addButton(ac, "rejoin", function() TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer) end)
	addButton(ac, "server_hop", function()
		local ok, res = pcall(function()
			return HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"))
		end)
		if ok and res and res.data then
			for _, s in ipairs(res.data) do
				if s.id ~= game.JobId and s.playing < s.maxPlayers then
					notify(tr("hopping"))
					TeleportService:TeleportToPlaceInstance(game.PlaceId, s.id, LocalPlayer)
					return
				end
			end
		end
		notify(tr("no_server"))
	end)
	addButton(ac, "copy_job", function() notify(copy(game.JobId) and tr("copied_job") or tr("no_clip")) end)
	addButton(ac, "unload", function() Hub.Unload() end)

	local sc = card(page, "session", C.good)
	sc.LayoutOrder = 4
	local grid = new("Frame", { Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, BackgroundTransparency = 1, Parent = sc })
	new("UIGridLayout", { CellSize = UDim2.new(0.3333, -6, 0, 44), CellPadding = UDim2.fromOffset(8, 8), SortOrder = Enum.SortOrder.LayoutOrder, Parent = grid })
	for _, k in ipairs({ "fps", "ping", "players", "session_time", "server_time", "account_age" }) do
		local t = new("Frame", { BackgroundColor3 = C.field, BackgroundTransparency = 0.25, Parent = grid })
		corner(t, 10); pad(t, 5, 5, 10, 10)
		tlabel(t, k, 10, F.med, C.sub, { Size = UDim2.new(1, 0, 0, 14) })
		statLabels[k] = label(t, "-", 15, F.bold, C.text, { Position = UDim2.fromOffset(0, 16), Size = UDim2.new(1, 0, 0, 20) })
	end
end

-- ---------- Tab 2: Auto Farm (icon miếng thịt viền) ----------
do
	local page = addTab("farm", "meat")
	pageHeader(page, "auto_farm")
	local l, r = columns(page)
	local pu = card(l, "pullup", C.accent)
	addToggle(pu, "auto_pullup", "autoPullup", false)
	addDropdown(pu, "move_mode", "moveMode", { "walk", "teleport" }, "walk")
	addToggle(pu, "auto_x2", "autoX2", true)

	local up = card(l, "auto_update", C.warn)
	addToggle(up, "up_bar", "upBar", false)
	addToggle(up, "up_food", "upFood", false)
	local foodOptions = { "food_best" }
	for _, f in ipairs(FOODS) do if f[2] ~= "0" then foodOptions[#foodOptions + 1] = f[1] end end
	addDropdown(up, "food_target", "foodTarget", foodOptions, "food_best")

	local th = card(r, "throw", C.good)
	addToggle(th, "auto_throw", "autoThrow", false)
	addButton(th, "set_eclipse", function()
		local ch = LocalPlayer.Character
		local r = ch and ch:FindFirstChild("HumanoidRootPart")
		if r then Hub.Targets.EclipsePos = r.Position; Hub.Notify(tr("eclipse_saved")) end
	end)

	local sl = card(r, "auto_sell", C.warn)
	addToggle(sl, "auto_sell_pets", "autoSellPets", false)
	addDropdown(sl, "sell_max", "sellMax", SELL_OPTIONS, SELL_OPTIONS[1])
end

-- ---------- Tab 3: Settings (icon bánh răng) ----------
do
	local page = addTab("settings", "gear")
	pageHeader(page, "settings")
	local l, r = columns(page)
	local lg = card(l, "language", C.accent)
	addDropdown(lg, "language", "language", { "English", "Tiếng Việt" }, "English")
	Internal.language = function(v) Lang = (v == "Tiếng Việt") and "vi" or "en"; refreshLang(); refreshStatus() end
	local ui = card(l, "interface", C.sub)
	addToggle(ui, "notifications", "notifications", true)
	addDropdown(ui, "toggle_key", "toggleKey", { "RightShift", "RightControl", "Insert", "K", "M" }, "RightShift")
	addSlider(ui, "bg_opacity", "bgOpacity", 0, 100, 85, function(v) return v .. "%" end)
	Internal.bgOpacity = function(v) BgImage.ImageTransparency = 1 - (v / 100) end
	BgImage.ImageTransparency = 1 - (Config.bgOpacity / 100)

	local bf = card(r, "boost_card", C.good)
	addToggle(bf, "boost_fps", "boostFps", true)
	addToggle(bf, "fix_lag", "fixLag", true)
end

-- ====================== NÚT THU GỌN TRÒN 1:1 ======================
local BS = 84 -- nút luôn là hình vuông 1:1 nên bo tròn hoàn toàn
local GOLD = Color3.fromRGB(255, 205, 0)
local BubbleHolder = new("Frame", { Name = "BubbleHolder", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0, 60, 0.5, 0),
	Size = UDim2.fromOffset(BS, BS), BackgroundTransparency = 1, ZIndex = 5, Parent = Gui })
new("UIAspectRatioConstraint", { AspectRatio = 1, Parent = BubbleHolder })
-- Nền tròn đỏ (màu cờ Việt Nam) + viền vàng động
local Ring = new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(62, 62), BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 5, Parent = BubbleHolder })
new("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = Ring })
stroke(Ring, GOLD, 2)

-- Hai lá cờ Việt Nam hai bên viền logo (tĩnh, không hoạt ảnh)
local RED = Color3.fromRGB(218, 37, 29)
local function vnFlag(parent, poleX, toRight)
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromOffset(poleX, BS / 2 + 2), Size = UDim2.fromOffset(2, 22),
		BackgroundColor3 = Color3.fromRGB(235, 235, 235), BorderSizePixel = 0, ZIndex = 7, Parent = parent })
	local f = new("Frame", { AnchorPoint = Vector2.new(toRight and 0 or 1, 0), Position = UDim2.fromOffset(poleX + (toRight and 1 or -1), BS / 2 - 9),
		Size = UDim2.fromOffset(13, 9), BackgroundColor3 = RED, BorderSizePixel = 0, ZIndex = 7, Parent = parent })
	new("UIStroke", { Color = GOLD, Thickness = 0.7, Parent = f })
	label(f, "★", 8, Enum.Font.Arial, GOLD, { Size = UDim2.fromScale(1, 1), TextXAlignment = Enum.TextXAlignment.Center,
		TextYAlignment = Enum.TextYAlignment.Center, ZIndex = 8 })
end
vnFlag(BubbleHolder, 4, true)
vnFlag(BubbleHolder, BS - 4, false)

local Bubble = new("ImageButton", { Name = "Bubble", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromOffset(52, 52), BackgroundColor3 = C.bg, ScaleType = Enum.ScaleType.Crop, AutoButtonColor = false, ZIndex = 8, Parent = BubbleHolder })
corner(Bubble, 26); stroke(Bubble, C.accent, 1.8)
local BubbleLogo = new("ImageLabel", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(0.62, 0.62),
	BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit, ZIndex = 9, Parent = Bubble })
loadImage(Bubble, BG, false, "nút")
loadImage(BubbleLogo, LOGO, true, "logo nút")
-- Vùng bấm phủ toàn bộ nút (kể cả phần rồng) để chạm đâu cũng mở/kéo được
local Hit = new("TextButton", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, Text = "", ZIndex = 60, Parent = BubbleHolder })

local function setMenu(v) closePopup(); Main.Visible = v end
local function makeDraggable(handle, target, onClick)
	local dragging, moved, startMouse, startPos = false, false, nil, nil
	bind(handle.InputBegan, function(i)
		if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
			dragging, moved, startMouse, startPos = true, false, i.Position, target.Position
			local c
			c = i.Changed:Connect(function()
				if i.UserInputState == Enum.UserInputState.End then
					dragging = false; c:Disconnect()
					if not moved and onClick then onClick() end
				end
			end)
		end
	end)
	bind(UIS.InputChanged, function(i)
		if dragging and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
			local d = i.Position - startMouse
			if d.Magnitude > 5 then moved = true end
			if moved then target.Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + d.X, startPos.Y.Scale, startPos.Y.Offset + d.Y) end
		end
	end)
end
makeDraggable(Top, Main)
makeDraggable(Hit, BubbleHolder, function() setMenu(not Main.Visible) end)
bind(MinBtn.MouseButton1Click, function() setMenu(false) end)
bind(UIS.InputBegan, function(input, processed)
	if processed or UIS:GetFocusedTextBox() then return end
	local ok, code = pcall(function() return Enum.KeyCode[Config.toggleKey or "RightShift"] end)
	if ok and input.KeyCode == code then setMenu(not Main.Visible) end
end)

-- ====================== THANH FPS / MS / PING (Boost FPS) ======================
local StatBar = new("Frame", { AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(270, 32),
	BackgroundColor3 = C.panel, BackgroundTransparency = 0.1, Visible = false, ZIndex = 50, Parent = Gui })
corner(StatBar, 16); stroke(StatBar, C.accent, 1.2)
local function statCell(idx, text, color)
	return label(StatBar, text, 13, F.bold, color, { Position = UDim2.new((idx - 1) / 3, 0, 0, 0), Size = UDim2.new(1 / 3, 0, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Center, TextWrapped = false, ZIndex = 51 })
end
local barFps = statCell(1, "FPS 0", C.good)
local barMs = statCell(2, "0 ms", C.text)
local barPing = statCell(3, "Ping 0", C.warn)
for i = 1, 2 do -- vạch ngăn giữa các ô
	new("Frame", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(i / 3, 0, 0.5, 0), Size = UDim2.fromOffset(1, 16),
		BackgroundColor3 = C.stroke, BorderSizePixel = 0, ZIndex = 51, Parent = StatBar })
end
local bubbleHomePosition = UDim2.new(0, 60, 0.5, 0)
local lastStatBarTap = 0
makeDraggable(StatBar, StatBar, function()
	local now = os.clock()
	if now - lastStatBarTap <= 0.4 then
		BubbleHolder.Position = bubbleHomePosition
		lastStatBarTap = 0
	else
		lastStatBarTap = now
	end
end)
local startClock, fpsSmooth, acc = os.clock(), 60, 0
local function fmtTime(s)
	s = math.floor(s)
	return string.format("%02d:%02d:%02d", math.floor(s / 3600), math.floor(s / 60) % 60, s % 60)
end
bind(RunService.Heartbeat, function(dt)
	fpsSmooth = fpsSmooth + (1 / math.max(dt, 1e-3) - fpsSmooth) * 0.1
	acc = acc + dt
	if acc < 0.5 then return end
	acc = 0
	local ok, v = pcall(function() return Stats.Network.ServerStatsItem["Data Ping"]:GetValue() end)
	local ping = ok and v or (LocalPlayer:GetNetworkPing() * 1000)
	local fps = math.floor(fpsSmooth + 0.5)
	if StatBar.Visible then
		barFps.Text = "FPS " .. fps; barMs.Text = string.format("%.0f ms", 1000 / math.max(fps, 1)); barPing.Text = "Ping " .. math.floor(ping)
	end
	if Main.Visible then
		statLabels.fps.Text = tostring(fps)
		statLabels.ping.Text = math.floor(ping) .. " ms"
		statLabels.players.Text = #Players:GetPlayers() .. "/" .. Players.MaxPlayers
		statLabels.session_time.Text = fmtTime(os.clock() - startClock)
		statLabels.server_time.Text = fmtTime(workspace.DistributedGameTime)
		statLabels.account_age.Text = LocalPlayer.AccountAge .. " " .. tr("days")
	end
end)

-- ====================== BOOST FPS / FIX LAG ======================
local BF = { orig = {}, conns = {}, add = nil }
local function bfSet(inst, prop, val)
	local ok, old = pcall(function() return inst[prop] end)
	if ok and old ~= val then
		BF.orig[#BF.orig + 1] = { inst, prop, old }
		pcall(function() inst[prop] = val end)
	end
end
local function isPlayerModel(inst)
	local m = inst:FindFirstAncestorOfClass("Model")
	return m and Players:GetPlayerFromCharacter(m) ~= nil
end
local function bfObj(d) -- tắt chữ nổi trên đầu thú (BillboardGui) và hoạt ảnh của thú/NPC: hai nguồn tốn FPS lớn nhất ở map này
	if d:IsA("BillboardGui") then
		if not isPlayerModel(d) then bfSet(d, "Enabled", false) end
	elseif d:IsA("Animator") then
		if not isPlayerModel(d) then
			pcall(function() for _, t in ipairs(d:GetPlayingAnimationTracks()) do t:Stop(0) end end)
			BF.conns[#BF.conns + 1] = d.AnimationPlayed:Connect(function(t) pcall(function() t:Stop(0) end) end)
		end
	end
end
Internal.boostFps = function(on)
	StatBar.Visible = on
	if setfpscap then pcall(setfpscap, on and 144 or 60) end
	if on then
		pcall(function()
			local t = workspace.Terrain
			bfSet(t, "Decoration", false); bfSet(t, "WaterWaveSize", 0); bfSet(t, "WaterReflectance", 0)
		end)
		if BF.add then BF.add:Disconnect() end
		BF.add = workspace.DescendantAdded:Connect(bfObj)
		table.insert(conns, BF.add)
		task.spawn(function() -- quét theo từng đợt, không đứng hình
			for i, d in ipairs(workspace:GetDescendants()) do
				if not Hub.Alive or not Config.boostFps then return end
				bfObj(d)
				if i % 400 == 0 then task.wait() end
			end
		end)
	else
		if BF.add then BF.add:Disconnect(); BF.add = nil end
		for _, c in ipairs(BF.conns) do pcall(function() c:Disconnect() end) end
		BF.conns = {}
		for _, o in ipairs(BF.orig) do pcall(function() o[1][o[2]] = o[3] end) end
		BF.orig = {}
	end
end
local FL = { orig = {}, conn = nil, quality = nil, states = {}, charConn = nil }
local function flSet(inst, prop, val)
	local ok, old = pcall(function() return inst[prop] end)
	if ok and old ~= val then
		FL.orig[#FL.orig + 1] = { inst, prop, old }
		pcall(function() inst[prop] = val end)
	end
end
local function flObj(d)
	if d:IsA("ParticleEmitter") or d:IsA("Trail") or d:IsA("Beam") or d:IsA("Smoke") or d:IsA("Fire") or d:IsA("Sparkles") or d:IsA("PostEffect") then
		flSet(d, "Enabled", false)
	end
end
local function tuneChar(c) -- nhân vật mượt hơn: bỏ bảng tên/máu, tắt trạng thái ragdoll gây giật
	local h = c and (c:FindFirstChildOfClass("Humanoid") or c:WaitForChild("Humanoid", 3))
	if not h then return end
	flSet(h, "DisplayDistanceType", Enum.HumanoidDisplayDistanceType.None)
	flSet(h, "HealthDisplayType", Enum.HumanoidHealthDisplayType.AlwaysOff)
	if c == LocalPlayer.Character then
		for _, st in ipairs({ Enum.HumanoidStateType.FallingDown, Enum.HumanoidStateType.Ragdoll, Enum.HumanoidStateType.GettingUp }) do
			local ok, was = pcall(function() return h:GetStateEnabled(st) end)
			if ok and was then FL.states[#FL.states + 1] = { h, st }; pcall(function() h:SetStateEnabled(st, false) end) end
		end
	end
end
Internal.fixLag = function(on)
	if on then
		pcall(function() FL.quality = settings().Rendering.QualityLevel; settings().Rendering.QualityLevel = Enum.QualityLevel.Level01 end)
		flSet(Lighting, "GlobalShadows", false)
		flSet(Lighting, "FogEnd", 1e9)
		for _, pl in ipairs(Players:GetPlayers()) do if pl.Character then task.spawn(tuneChar, pl.Character) end end
		if FL.charConn then FL.charConn:Disconnect() end
		FL.charConn = LocalPlayer.CharacterAdded:Connect(function(c) task.spawn(tuneChar, c) end)
		table.insert(conns, FL.charConn)
		if FL.conn then FL.conn:Disconnect() end
		FL.conn = workspace.DescendantAdded:Connect(flObj)
		table.insert(conns, FL.conn)
		task.spawn(function() -- quét theo từng đợt để không tự gây giật
			local all = workspace:GetDescendants()
			for i, d in ipairs(all) do
				if not Hub.Alive or not Config.fixLag then return end
				flObj(d)
				if i % 250 == 0 then task.wait() end
			end
			for _, d in ipairs(Lighting:GetDescendants()) do flObj(d) end
		end)
	else
		if FL.conn then FL.conn:Disconnect(); FL.conn = nil end
		for _, o in ipairs(FL.orig) do pcall(function() o[1][o[2]] = o[3] end) end
		FL.orig = {}
		if FL.charConn then FL.charConn:Disconnect(); FL.charConn = nil end
		for _, o in ipairs(FL.states) do pcall(function() o[1]:SetStateEnabled(o[2], true) end) end
		FL.states = {}
		if FL.quality then pcall(function() settings().Rendering.QualityLevel = FL.quality end) end
	end
end

-- ====================== TIỆN ÍCH GAME ======================
local function root() local c = LocalPlayer.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = LocalPlayer.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function matches(name, pats)
	name = name:lower()
	for _, p in ipairs(pats) do if name:find(p, 1, true) then return true end end
	return false
end
local function posOf(inst) return inst:IsA("Model") and inst:GetPivot().Position or inst.Position end
local targetCache, missT = {}, {}
local homePos
local function setHome() local r = root(); if r then homePos = r.Position end end
task.defer(function() task.wait(1.5); setHome() end)
bind(LocalPlayer.CharacterAdded, function() task.wait(2.5); if not (Config.autoPullup or Config.autoThrow) then setHome() end end)
local function ownedByMe(inst) -- đồ thuộc khu đất của chính mình (tên / thuộc tính / ObjectValue Owner)
	local nm1, nm2, uid = LocalPlayer.Name:lower(), LocalPlayer.DisplayName:lower(), tostring(LocalPlayer.UserId)
	local o, n = inst, 0
	while o and o ~= workspace and n < 8 do
		local nm = o.Name:lower()
		if nm:find(nm1, 1, true) or nm:find(uid, 1, true) or (#nm2 >= 4 and nm:find(nm2, 1, true)) then return true end
		for _, a in ipairs({ "Owner", "OwnerId", "OwnerName", "OwnerUserId", "Player", "UserId" }) do
			local v = o:GetAttribute(a)
			if v ~= nil then
				v = tostring(v):lower()
				if v == nm1 or v == nm2 or v == uid then return true end
			end
		end
		for _, c in ipairs(o:GetChildren()) do
			if c:IsA("ObjectValue") and c.Value == LocalPlayer then return true end
			if (c:IsA("StringValue") or c:IsA("IntValue")) and matches(c.Name, { "owner", "player" }) then
				local v = tostring(c.Value):lower()
				if v == nm1 or v == nm2 or v == uid then return true end
			end
		end
		o = o.Parent; n = n + 1
	end
	return false
end
local function findTarget(kind)
	local ov = Hub.Targets[kind .. "Override"]
	if type(ov) == "function" then
		local ok, res = pcall(ov)
		if ok and res then return res end
	end
	-- sàn ném đã xác nhận (đứng đó thì game hiện "Nhấn để ném!") thì dùng luôn, không dò lại
	if kind == "ThrowSpot" and Hub.GoodSpot and Hub.GoodSpot.Parent then return Hub.GoodSpot end
	local c = targetCache[kind]
	if c and c.inst.Parent and os.clock() - c.t < 120 then return c.inst end
	if missT[kind] and os.clock() - missT[kind] < 20 then return nil end -- vừa tìm không thấy: chờ 20s rồi mới quét lại (đỡ lag)
	local r0 = root()
	local ref = homePos or (r0 and r0.Position) or Vector3.new(0, 0, 0)
	local ownerKind = (kind == "PullUpBar" or kind == "ThrowSpot" or kind == "UpgradePad")
	local bestO, bdO, best, bd, fbO, fbOd, fb, fbd
	local ch, checks = LocalPlayer.Character, 0
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 1500 == 0 then task.wait() end -- chia nhỏ: không đứng hình khi quét map lớn
		if (d:IsA("BasePart") or d:IsA("Model")) and not (ch and d:IsDescendantOf(ch)) then
			local isPart = d:IsA("BasePart")
			local byName = matches(d.Name, Hub.Targets[kind]) and not (kind == "ThrowSpot" and isPart and not d.Anchored)
			if byName and kind == "ThrowSpot" then
				-- sàn ném là mặt phẳng thấp: loại tường (tên có "wall"... hoặc khối cao/mỏng) và điểm đã bị loại
				if Hub.BadSpots[d] or matches(d.Name, Hub.Targets.WallWords) then
					byName = false
				elseif isPart and (d.Size.Y > 8 or d.Size.Y > math.max(d.Size.X, d.Size.Z) * 0.8 or d.Size.X * d.Size.Z < 9) then
					byName = false
				end
			end
			local byColor = false
			if not byName and kind == "ThrowSpot" and isPart and d.Anchored and not Hub.BadSpots[d] then -- dự phòng: sàn màu cam của làn ném
				local c3 = d.Color
				byColor = c3.R > 0.9 and c3.G > 0.45 and c3.G < 0.76 and c3.B < 0.4 and d.Size.X * d.Size.Z > 50 and d.Size.Y <= 8
			end
			if byName or byColor then
				local dist = (posOf(d) - ref).Magnitude
				local mine = false
				if ownerKind then
					checks = checks + 1
					if checks % 40 == 0 then task.wait() end
					mine = ownedByMe(d)
				end
				if byName then
					if mine then if not bdO or dist < bdO then bestO, bdO = d, dist end
					elseif not bd or dist < bd then best, bd = d, dist end
				else
					if mine then if not fbOd or dist < fbOd then fbO, fbOd = d, dist end
					elseif not fbd or dist < fbd then fb, fbd = d, dist end
				end
			end
		end
	end
	local found = bestO or best or fbO or fb
	if found then targetCache[kind] = { inst = found, t = os.clock() } else missT[kind] = os.clock() end
	return found
end
local Mover = { target = nil, untilT = 0 }
bind(RunService.Heartbeat, function(dt) -- đi thẳng với tốc độ MoveSpeed studs/s, mượt, không bị MoveTo ngắt quãng
	if not Mover.target or os.clock() > Mover.untilT then return end
	local r, h = root(), hum()
	if not r or not h or h.Health <= 0 then return end
	local dx, dz = Mover.target.X - r.Position.X, Mover.target.Z - r.Position.Z
	local d = math.sqrt(dx * dx + dz * dz)
	if d < 3 then Mover.target = nil; return end
	local step = math.min(d, Hub.Targets.MoveSpeed * dt)
	local nx, nz = dx / d, dz / d
	local np = r.Position + Vector3.new(nx * step, 0, nz * step)
	r.CFrame = CFrame.new(np, np + Vector3.new(nx, 0, nz))
	local v = r.AssemblyLinearVelocity
	r.AssemblyLinearVelocity = Vector3.new(0, v.Y, 0)
end)
local function goTo(pos, mode)
	local h, r = hum(), root()
	if not h or not r then return false end
	local flat = Vector3.new(pos.X - r.Position.X, 0, pos.Z - r.Position.Z).Magnitude
	if flat < 6 then return true end
	if mode == "teleport" then
		r.CFrame = CFrame.new(pos.X, r.Position.Y, pos.Z)
	else
		Mover.target = Vector3.new(pos.X, 0, pos.Z); Mover.untilT = os.clock() + 1.2
	end
	return false
end

local guiTexts, guiButtons, guiCompactT = {}, {}, os.clock()
local function trackGui(d)
	if d:IsA("TextLabel") then guiTexts[#guiTexts + 1] = d
	elseif d:IsA("TextButton") then guiTexts[#guiTexts + 1] = d; guiButtons[#guiButtons + 1] = d
	elseif d:IsA("ImageButton") then guiButtons[#guiButtons + 1] = d end
end
task.spawn(function() -- quét ban đầu theo đợt; sau đó chỉ cập nhật theo sự kiện, không quét lại cả cây UI (nguồn giật chính trước đây)
	for i, d in ipairs(PlayerGui:GetDescendants()) do
		trackGui(d)
		if i % 300 == 0 then task.wait() end
	end
end)
bind(PlayerGui.DescendantAdded, trackGui)
local function compactGui()
	if os.clock() - guiCompactT < 15 then return end
	guiCompactT = os.clock()
	local function pack(t) local o = {} for _, d in ipairs(t) do if d.Parent then o[#o + 1] = d end end return o end
	guiTexts, guiButtons = pack(guiTexts), pack(guiButtons)
end
local function guiList() compactGui(); return guiTexts end
local function guiTextList() compactGui(); return guiTexts end
local function guiButtonList() compactGui(); return guiButtons end
local function chainMatches(d, pats) -- thay GetFullName (tạo chuỗi dài, rất tốn): chỉ xét tên d và vài tầng cha
	local o, n = d, 0
	while o and o ~= PlayerGui and n < 6 do
		if matches(o.Name, pats) then return true end
		o = o.Parent; n = n + 1
	end
	return false
end
local function visible(g)
	if not g:IsDescendantOf(PlayerGui) then return false end
	local o = g
	while o and o ~= PlayerGui do
		if o:IsA("GuiObject") and not o.Visible then return false end
		if o:IsA("LayerCollector") and not o.Enabled then return false end
		o = o.Parent
	end
	return true
end
local ftCache = setmetatable({}, { __mode = "k" })
local function fullText(b) -- gộp chữ của nút và các con, nhớ kết quả 0.25s để khỏi GetDescendants liên tục
	local c = ftCache[b]
	if c and os.clock() - c.t < 0.25 then return c.s end
	local t = b:IsA("TextButton") and b.Text or ""
	for _, d in ipairs(b:GetDescendants()) do if d:IsA("TextLabel") or d:IsA("TextButton") then t = t .. " " .. d.Text end end
	t = t:lower()
	ftCache[b] = { t = os.clock(), s = t }
	return t
end
local function findButtons(pred)
	local out = {}
	for _, d in ipairs(guiButtonList()) do
		if visible(d) and not Gui:IsAncestorOf(d) and pred(fullText(d), d) then out[#out + 1] = d end
	end
	return out
end
local function clickGui(g) -- bấm bằng chuột thật vào giữa phần tử (cả khi đó là Frame chứ không phải nút)
	local p = g.AbsolutePosition + g.AbsoluteSize / 2
	local sg = g:FindFirstAncestorWhichIsA("ScreenGui")
	local y = p.Y + ((sg and sg.IgnoreGuiInset) and 0 or GuiService:GetGuiInset().Y)
	pcall(function() VIM:SendMouseButtonEvent(p.X, y, 0, true, game, 0); VIM:SendMouseButtonEvent(p.X, y, 0, false, game, 0) end)
end
local function press(b)
	if firesignal and b:IsA("GuiButton") then
		pcall(firesignal, b.MouseButton1Click); pcall(firesignal, b.Activated)
	else
		clickGui(b)
	end
end
local function isPowerTextObject(d)
	return d and (d:IsA("TextLabel") or d:IsA("TextButton"))
end
local moneyLabel, moneyScanT = nil, -99
local function moneyOf(d, loose) -- nhãn tiền HUD kiểu "$808M" (loại "$12/s"); loose=true cho phép không có "$" (nhãn tên cash/money/coin)
	local t = d.Text
	if t:find("/", 1, true) then return nil end
	if not (loose or t:find("^%s*%$")) then return nil end
	return parseMoney(t)
end
local MONEY_NAMES = { "cash", "money", "coin", "gold", "currency", "balance" }
local function getMoney()
	if Hub.Hooks.GetMoney then
		local ok, v = pcall(Hub.Hooks.GetMoney)
		if ok and tonumber(v) then return tonumber(v) end
	end
	local ls = LocalPlayer:FindFirstChild("leaderstats")
	if ls then
		for _, v in ipairs(ls:GetChildren()) do
			if v:IsA("ValueBase") and matches(v.Name, MONEY_NAMES) and typeof(v.Value) == "number" then return v.Value end
		end
	end
	for name, val in pairs(LocalPlayer:GetAttributes()) do
		if type(val) == "number" and matches(name, MONEY_NAMES) then return val end
	end
	for _, grp in ipairs(LocalPlayer:GetChildren()) do -- thư mục dữ liệu kiểu Data/Stats/Values
		if grp:IsA("Folder") or grp:IsA("Configuration") then
			for _, v in ipairs(grp:GetChildren()) do
				if v:IsA("ValueBase") and matches(v.Name, MONEY_NAMES) and typeof(v.Value) == "number" then return v.Value end
			end
		end
	end
	if moneyLabel and moneyLabel.Parent and visible(moneyLabel) then
		local v = moneyOf(moneyLabel, Hub._ml)
		if v then return v end
	end
	if os.clock() - moneyScanT > 3 then
		moneyScanT = os.clock()
		local cam = workspace.CurrentCamera
		local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
		local best, bs, bestLoose
		for _, d in ipairs(guiTextList()) do
			if isPowerTextObject(d) and d.Text ~= "" and not Gui:IsAncestorOf(d) and d:IsDescendantOf(PlayerGui) then
				local named = chainMatches(d, MONEY_NAMES)
				local v = moneyOf(d, named)
				if v and visible(d) then
					local ap = d.AbsolutePosition
					if named or (ap.X < vs.X * 0.4 and ap.Y > vs.Y * 0.5) then -- nhãn tiền không tên nằm góc dưới-trái màn hình
						local score = named and 0 or (1 + (vs.Y - (ap.Y + d.AbsoluteSize.Y)) / math.max(vs.Y, 1))
						if not bs or score < bs then best, bs, bestLoose = d, score, named end
					end
				end
			end
		end
		if best then moneyLabel = best; Hub._ml = bestLoose; return moneyOf(best, bestLoose) end
	end
	return nil
end
local function loopWhile(flag, interval, fn)
	task.spawn(function()
		while Hub.Alive do
			if Config[flag] then safeCall(fn) end
			task.wait(interval)
		end
	end)
end

-- ====================== ANTI-AFK (cơ chế ẩn khi đang tập / ném) ======================
local function farming() return Config.autoPullup or Config.autoThrow end
local function nudge()
	pcall(function() VirtualUser:CaptureController(); VirtualUser:ClickButton2(Vector2.new(0, 0)) end)
end
bind(LocalPlayer.Idled, function() if farming() then nudge() end end)
task.spawn(function()
	while Hub.Alive do
		task.wait(540) -- 9 phút, trước mốc 10 phút
		if farming() then nudge() end
	end
end)

local busyUntil = 0 -- đang đi nâng cấp xà: các vòng farm tạm dừng di chuyển
-- Dịch chuyển tạm tới pos, làm việc rồi quay về chỗ cũ (các vòng farm tự nghỉ trong lúc đó)
Hub.runTask = function(pos, fn)
	local r = root()
	if not r then return end
	local back = r.CFrame
	busyUntil = os.clock() + 8
	Mover.target = nil
	r.CFrame = CFrame.new(pos + Vector3.new(0, 3, 0))
	task.wait(0.4)
	pcall(fn)
	task.wait(0.5)
	local r2 = root()
	if r2 then r2.CFrame = back end
	busyUntil = os.clock() + 0.3
end

-- ====================== PULL-UP EXERCISES ======================
-- Auto pull-up bật => cơ chế ẩn tập xà nhanh gấp PullSpeed (5) lần: tăng tốc animation tập + bấm prompt của xà liên tục.
do
	local FX = { conn = nil, hold = {}, prompts = {}, pbar = nil, near = false }
	Hub.PullFx = FX
	local function speedTracks(sp)
		local h = hum()
		local an = h and h:FindFirstChildOfClass("Animator")
		if not an then return end
		for _, t in ipairs(an:GetPlayingAnimationTracks()) do pcall(function() t:AdjustSpeed(sp) end) end
	end
	FX.reset = function()
		if FX.conn then FX.conn:Disconnect(); FX.conn = nil end
		for p, hd in pairs(FX.hold) do pcall(function() p.HoldDuration = hd end) end
		FX.hold, FX.prompts, FX.pbar, FX.near = {}, {}, nil, false
		if not Config.autoPullup then speedTracks(1) end
	end
	local function collectPrompts(bar)
		if FX.pbar == bar then return end
		FX.pbar, FX.prompts = bar, {}
		local roots = { bar }
		local par = bar.Parent
		if par and par ~= workspace and (par:IsA("Model") or par:IsA("Folder")) and #par:GetChildren() < 60 then roots[2] = par end
		for _, rt in ipairs(roots) do
			for _, d in ipairs(rt:GetDescendants()) do
				if d:IsA("ProximityPrompt") and FX.hold[d] == nil then
					FX.hold[d] = d.HoldDuration
					FX.prompts[#FX.prompts + 1] = d
					pcall(function() d.HoldDuration = 0 end)
				end
			end
		end
	end
	bind(LocalPlayer.CharacterAdded, function() task.wait(1); if Hub.Alive then FX.reset() end end)

	loopWhile("autoPullup", 0.6, function()
		if os.clock() < busyUntil then return end
		local bar = findTarget("PullUpBar")
		if not bar then warnOnce("no_bar"); return end
		FX.near = goTo(posOf(bar), Config.moveMode) and true or false
		if FX.near then collectPrompts(bar) end
		if Config.autoX2 then
			for _, b in ipairs(findButtons(function(t) return t:find("x2", 1, true) ~= nil or t:find("2x", 1, true) ~= nil end)) do press(b) end
		end
	end)
	loopWhile("autoPullup", 0.12, function() -- vòng nhanh: x5 tốc độ tập
		if not FX.near or os.clock() < busyUntil then return end
		if not FX.conn then
			local h = hum()
			local an = h and h:FindFirstChildOfClass("Animator")
			if an then
				FX.conn = an.AnimationPlayed:Connect(function(t)
					if FX.near then pcall(function() t:AdjustSpeed(Hub.Targets.PullSpeed) end) end
				end)
			end
		end
		speedTracks(Hub.Targets.PullSpeed)
		if fireproximityprompt then
			for _, p in ipairs(FX.prompts) do
				if p.Parent and p.Enabled then pcall(fireproximityprompt, p) end
			end
		end
	end)
end

-- Shared throw state is stored in one table to keep local-variable usage low.
local ThrowState = { lastThrow = 0, launchCount = 0, noHideUntil = 0, busy = false }
-- ====================== THROW ======================

do -- power gauge helpers
-- Thanh sức mạnh: thanh màu dọc, vạch trắng chạy LÊN XUỐNG, số "+13" hiện cạnh vạch (tối đa +20)
local gauge, gaugeScanT = nil, -99
local function parsePower(t)
	t = tostring(t or ""):gsub(",", "")
	local n = t:match("^%s*%+%s*(%d+)%s*$")
		or t:lower():match("power%s*[:=]?%s*%+?(%d+)")
		or t:lower():match("strength%s*[:=]?%s*%+?(%d+)")
		or t:lower():match("sức mạnh%s*[:=]?%s*%+?(%d+)")
	return n and tonumber(n) or nil
end
local function readPower() -- đọc vạch sức mạnh dạng +N, kể cả khi game dùng TextButton
	if Hub.Hooks.GetPower then
		local ok, v = pcall(Hub.Hooks.GetPower)
		if ok and tonumber(v) then return math.clamp(tonumber(v), 0, Hub.Targets.MaxPower) end
	end
	if gauge and gauge.Parent and isPowerTextObject(gauge) then
		local n = parsePower(gauge.Text)
		if not n and chainMatches(gauge, { "power", "strength", "sức mạnh", "gauge" }) then
			n = tonumber(gauge.Text:match("^%s*(%d+)%s*$"))
		end
		if n and n <= Hub.Targets.MaxPower + 5 and visible(gauge) then return n end
	end
	gauge = nil
	if os.clock() - gaugeScanT < 0.06 then return nil end
	gaugeScanT = os.clock()
	local cam = workspace.CurrentCamera
	local vs = cam and cam.ViewportSize or Vector2.new(1280, 720)
	local best, bestScore, bestValue = nil, math.huge, nil
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and not Gui:IsAncestorOf(d) and visible(d) then
			local n = parsePower(d.Text)
			if not n and chainMatches(d, { "power", "strength", "sức mạnh", "gauge" }) then
				n = tonumber(d.Text:match("^%s*(%d+)%s*$"))
			end
			if n and n >= 0 and n <= Hub.Targets.MaxPower + 5 then
				local cx = d.AbsolutePosition.X + d.AbsoluteSize.X / 2
				local cy = d.AbsolutePosition.Y + d.AbsoluteSize.Y / 2
				local centerPenalty = math.abs(cx - vs.X * 0.5) / math.max(vs.X, 1)
				local verticalPenalty = math.abs(cy - vs.Y * 0.5) / math.max(vs.Y, 1)
				local named = chainMatches(d, { "power", "strength", "sức mạnh", "gauge" }) and 0.5 or 0
				local score = centerPenalty + verticalPenalty * 0.15 - named
				if centerPenalty < 0.42 and score < bestScore then
					best, bestScore, bestValue = d, score, n
				end
			end
		end
	end
	if best then gauge = best; return bestValue end
	return nil
end
local function findResultPower() -- chữ "+17 Sức mạnh" hiện sau khi ném
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and d.Text:sub(1, 1) == "+" and not Gui:IsAncestorOf(d) then
			local t = d.Text:lower()
			local n = t:match("^%+(%d+)%s*sức mạnh") or t:match("^%+(%d+)%s*strength") or t:match("^%+(%d+)%s*power")
			if n and visible(d) then return tonumber(n) end
		end
	end
	return nil
end
ThrowState.readPower = readPower
ThrowState.findResultPower = findResultPower
end -- power gauge helpers

do -- throw position and input helpers
local spotLabel, spotT = nil, -99
local function isSpotText(t)
	t = t:lower()
	return t:find("nhấn để ném", 1, true) or t:find("tap to throw", 1, true) or t:find("click to throw", 1, true) or t:find("press to throw", 1, true)
end
local function atThrowSpot() -- game đang hiện "Nhấn để ném!" nghĩa là đã đứng đúng chỗ ném
	if spotLabel and spotLabel.Parent and isSpotText(spotLabel.Text) and visible(spotLabel) then return true end
	spotLabel = nil
	if os.clock() - spotT < 0.5 then return false end
	spotT = os.clock()
	for _, d in ipairs(guiTextList()) do
		if d:IsA("TextLabel") and d.Text ~= "" and not Gui:IsAncestorOf(d) and isSpotText(d.Text) and visible(d) then spotLabel = d; return true end
	end
	return false
end
local function throwPoint() -- nút Throw trên màn hình nếu có, không thì giữa màn hình
	for _, b in ipairs(findButtons(function(t) return t:find("throw", 1, true) or t:find("ném", 1, true) end)) do
		local c = b.AbsolutePosition + b.AbsoluteSize / 2
		local sg = b:FindFirstAncestorWhichIsA("ScreenGui")
		return c.X, c.Y + ((sg and sg.IgnoreGuiInset) and 0 or GuiService:GetGuiInset().Y)
	end
	local v = workspace.CurrentCamera.ViewportSize
	return v.X / 2, v.Y / 2
end
local function tapAt(x, y)
	VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
	VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

ThrowState.atThrowSpot = atThrowSpot
ThrowState.throwPoint = throwPoint
ThrowState.tapAt = tapAt
end -- throw position and input helpers

do -- camera đứng yên + tự bấm bỏ qua
-- Luôn là "Không hoạt ảnh": camera khóa tại chỗ người chơi (không bay theo vật ném / cảnh nhận pet)
local camRel, camRot, camLocked = nil, nil, false
local function captureCam()
	local cam, r = workspace.CurrentCamera, root()
	if cam and r then camRel = cam.CFrame.Position - r.Position; camRot = cam.CFrame.Rotation end
end
local function releaseCam()
	camRel = nil
	if camLocked then
		camLocked = false
		local cam, h = workspace.CurrentCamera, hum()
		if cam and h then cam.CameraType = Enum.CameraType.Custom; cam.CameraSubject = h end
	end
end
pcall(function() RunService:UnbindFromRenderStep("KROBUS_CAM") end)
RunService:BindToRenderStep("KROBUS_CAM", Enum.RenderPriority.Camera.Value + 1, function()
	local cam, r = workspace.CurrentCamera, root()
	if Config.autoThrow and camRel and cam and r then
		camLocked = true
		cam.CameraType = Enum.CameraType.Scriptable
		cam.CFrame = CFrame.new(r.Position + camRel) * camRot
	elseif camLocked and not Config.autoThrow then
		releaseCam()
	end
end)

-- Thấy chữ "nhấn để bỏ qua / tap to skip" thì bấm màn hình 5 lần
local function skipVisible()
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and d.Text ~= "" and not Gui:IsAncestorOf(d) then
			local t = d.Text:lower()
			if (t:find("bỏ qua", 1, true) or t:find("skip", 1, true)) and visible(d) then return d end
		end
	end
	return nil
end
ThrowState.findSkip = skipVisible

-- Không có hoạt ảnh ném: dừng mọi animation mới của nhân vật trong vài giây sau khi bấm
local animConn
ThrowState.suppressAnim = function(sec)
	local h = hum()
	local an = h and h:FindFirstChildOfClass("Animator")
	if not an then return end
	local base = {}
	for _, t in ipairs(an:GetPlayingAnimationTracks()) do base[t] = true end
	if animConn then animConn:Disconnect() end
	local untilT = os.clock() + sec
	local c
	c = an.AnimationPlayed:Connect(function(t)
		if os.clock() <= untilT and not base[t] then pcall(function() t:Stop(0) end) end
	end)
	animConn = c
	task.delay(sec, function() c:Disconnect(); if animConn == c then animConn = nil end end)
end
local lastSkip = 0
loopWhile("autoThrow", 0.25, function()
	if os.clock() - ThrowState.lastThrow > 45 or os.clock() - lastSkip < 1.5 then return end -- chỉ xét trong 45s sau khi ném (đỡ tốn)
	local sk = skipVisible()
	if sk then
		lastSkip = os.clock()
		local v = workspace.CurrentCamera.ViewportSize
		for _ = 1, 5 do
			clickGui(sk) -- bấm thẳng vào dòng chữ bỏ qua
			pcall(ThrowState.tapAt, v.X / 2, v.Y / 2)
			task.wait(0.08)
		end
	end
end)

ThrowState.captureCam = captureCam
ThrowState.releaseCam = releaseCam
end -- camera đứng yên + tự bấm bỏ qua

do -- throw input
-- Vào chỗ ném được PressDelay (1.158s) thì bấm màn hình đúng 1 lần rồi dừng.
local function throwOnce(enterT)
	local delay = Hub.Targets.PressDelay
	local start = enterT or os.clock()
	while Hub.Alive and Config.autoThrow and os.clock() - start < delay do
		RunService.Heartbeat:Wait()
	end
	if not (Hub.Alive and Config.autoThrow) then return false end
	ThrowState.lastThrow = os.clock()
	ThrowState.suppressAnim(4)
	local x, y = ThrowState.throwPoint() -- lấy lại tọa độ ngay trước lúc bấm
	pcall(ThrowState.tapAt, x, y)
	return true
end

ThrowState.throwOnce = throwOnce
end -- throw input

do -- projectile trajectory controller

-- Cơ chế ẩn: vật ném bay đến cuối biome Eclipse Kingdom, tối đa 2200 stud/s rồi giảm tốc và hạ độ cao
local launching = {}
local function flightSpeed(d) -- nội suy theo bảng Hub.Targets.Flight: giảm tốc mượt, không giật
	local P = Hub.Targets.Flight
	if d >= P[1][1] then return P[1][2] end
	for i = 2, #P do
		local d0, v0, d1, v1 = P[i - 1][1], P[i - 1][2], P[i][1], P[i][2]
		if d >= d1 then return v1 + (v0 - v1) * (d - d1) / (d0 - d1) end
	end
	return 0
end
-- Tìm khu Eclipse Kingdom: lấy vật tên "eclipse" có diện tích lớn nhất (tránh nhầm biển hiệu nhỏ)
local function boundsOf(inst)
	if inst:IsA("Model") then
		local ok, cf, size = pcall(function() return inst:GetBoundingBox() end)
		if ok then return cf, size end
		return nil
	end
	if inst:IsA("BasePart") then return inst.CFrame, inst.Size end
	local mn, mx, n = nil, nil, 0
	for _, q in ipairs(inst:GetDescendants()) do
		if q:IsA("BasePart") then
			local p = q.Position
			if mn then
				mn = Vector3.new(math.min(mn.X, p.X), math.min(mn.Y, p.Y), math.min(mn.Z, p.Z))
				mx = Vector3.new(math.max(mx.X, p.X), math.max(mx.Y, p.Y), math.max(mx.Z, p.Z))
			else
				mn, mx = p, p
			end
			n = n + 1
			if n > 3000 then break end
		end
	end
	if not mn then return nil end
	return CFrame.new((mn + mx) / 2), (mx - mn)
end
local eclipseCache = { t = -99 }
local eclipseScanning = false
local function findEclipse()
	if eclipseScanning then return end
	eclipseScanning = true
	local best, ba
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 1500 == 0 then task.wait() end
		if (d:IsA("Model") or d:IsA("Folder") or d:IsA("BasePart")) and matches(d.Name, Hub.Targets.EclipseKingdom) then
			local cf, sz = boundsOf(d)
			if cf then
				local a = sz.X * sz.Z
				if not ba or a > ba then best, ba = d, a end
			end
		end
	end
	eclipseCache = { t = os.clock(), inst = best }
	eclipseScanning = false
end
local function aimPoint(from)
	if Hub.Targets.EclipsePos then return Hub.Targets.EclipsePos end
	local t = eclipseCache.inst
	if not (t and t.Parent) or os.clock() - eclipseCache.t > 180 then
		task.spawn(findEclipse) -- quét nền cho lần ném sau
		if not (t and t.Parent) then return nil end
	end
	local cf, size = boundsOf(t)
	if not cf then return nil end
	local best, bd = cf.Position, -1
	for sx = -1, 1, 2 do
		for sz = -1, 1, 2 do -- 4 góc cùng độ cao: chọn góc xa người ném nhất = "cuối biome"
			local c = (cf * CFrame.new(size.X / 2 * sx * 0.9, 0, size.Z / 2 * sz * 0.9)).Position
			local d = (c - from).Magnitude
			if d > bd then best, bd = c, d end
		end
	end
	return best
end
local function launch(obj) -- obj: BasePart hoặc Model nhỏ là vật ném
	if launching[obj] then return end
	launching[obj] = true
	ThrowState.launchCount = ThrowState.launchCount + 1
	task.spawn(function()
		local T = Hub.Targets
		local isModel = obj:IsA("Model")
		local parts = {}
		if isModel then
			for _, q in ipairs(obj:GetDescendants()) do if q:IsA("BasePart") then parts[#parts + 1] = q end end
		else
			parts[1] = obj
		end
		if #parts == 0 then launching[obj] = nil; return end
		local function pos() return isModel and obj:GetPivot().Position or obj.Position end
		local anchored = parts[1].Anchored -- vật bị anchor (game tự tween) thì dịch bằng CFrame
		local half = math.max(parts[1].Size.Y / 2, 0.5)
		local r = root()
		local dir0 = r and r.CFrame.LookVector or Vector3.new(0, 0, -1)
		local aim = aimPoint(pos()) or (pos() + dir0 * 3000)
		local rp = RaycastParams.new()
		rp.FilterType = Enum.RaycastFilterType.Exclude
		rp.RespectCanCollide = true
		rp.FilterDescendantsInstances = { obj, LocalPlayer.Character }
		local lastGroundScan, groundYCache = -1, pos().Y - 3
		local function groundY(pp)
			if os.clock() - lastGroundScan >= 0.1 then
				lastGroundScan = os.clock()
				local res = workspace:Raycast(Vector3.new(pp.X, pp.Y + 300, pp.Z), Vector3.new(0, -1500, 0), rp)
				if res and (res.Instance.Anchored or res.Instance:IsA("Terrain")) then groundYCache = res.Position.Y end
			end
			return groundYCache
		end
		local cc, moverStates, velocityMovers = {}, {}, {}
		local velocityRoots, seenRoots = {}, {}
		for _, q in ipairs(parts) do
			local assembly = q.AssemblyRootPart or q
			if not seenRoots[assembly] then
				seenRoots[assembly] = true
				velocityRoots[#velocityRoots + 1] = assembly
			end
		end
		for i, q in ipairs(parts) do
			cc[i] = q.CanCollide
			pcall(function() q.CanCollide = false end)
			for _, mover in ipairs(q:GetDescendants()) do
				if mover:IsA("BodyVelocity") or mover:IsA("LinearVelocity") then
					velocityMovers[#velocityMovers + 1] = mover
				elseif mover:IsA("VectorForce") or mover:IsA("AlignPosition") or mover:IsA("AlignOrientation") then
					local ok, was = pcall(function() return mover.Enabled end)
					if ok then moverStates[#moverStates + 1] = { mover, was }; pcall(function() mover.Enabled = false end) end
				end
			end
		end
		local t0, frame, arrivedAt = os.clock(), 0, nil
		while obj.Parent and Config.autoThrow and os.clock() - t0 < 30 do
			local dt = RunService.Heartbeat:Wait()
			local pp = pos()
			local hv = Vector3.new(aim.X - pp.X, 0, aim.Z - pp.Z)
			local d = hv.Magnitude -- khoảng cách NGANG còn lại tới cuối biome
			local gy = groundY(pp)
			-- Độ cao mong muốn: 50 studs trên mặt đất khi còn xa, hạ dần trong SlideDist cuối
			local slideAlpha = math.clamp(d / math.max(T.SlideDist, 1), 0, 1)
			local hgt = T.CruiseHeight * slideAlpha
			local ty = gy + half + hgt
			local v
			if d > 3 then
				local sp = math.max(flightSpeed(d), 6) -- tốc độ tối thiểu để chắc chắn tới nơi
				sp = math.min(sp, d / math.max(dt, 1 / 60)) -- không vượt quá khoảng cách còn lại trong 1 khung hình
				local hd = hv.Unit * sp
				local vy = math.clamp((ty - pp.Y) * 8, -400, 600) -- leo lên / hạ xuống độ cao mong muốn mượt
				v = Vector3.new(hd.X, vy, hd.Z)
			else
				local vy = math.clamp((gy + half - pp.Y) * 8, -200, 200) -- tới nơi: hạ nốt xuống chạm đất
				v = Vector3.new(0, vy, 0)
			end
			if d < 40 and pp.Y <= gy + half + 1.5 and pp.Y >= gy + half - 4 then
				arrivedAt = arrivedAt or os.clock()
				v = Vector3.zero
			end -- chạm mặt đất: dừng
			frame = frame + 1
			pcall(function()
				for _, assembly in ipairs(velocityRoots) do
					if assembly.Parent then
						assembly.AssemblyLinearVelocity = v
						assembly.AssemblyAngularVelocity = Vector3.zero
					end
				end
				-- Ghi đè BodyVelocity/LinearVelocity mỗi frame.
				for _, mover in ipairs(velocityMovers) do
					if mover.Parent then
						if mover:IsA("BodyVelocity") then
							mover.Velocity = v
							mover.MaxForce = Vector3.new(1e9, 1e9, 1e9)
							mover.P = 1e6
						elseif mover:IsA("LinearVelocity") then
							mover.VectorVelocity = v
							pcall(function() mover.MaxForce = 1e9 end)
						end
					end
				end
				if anchored then
					local step = v * dt
					if isModel then obj:PivotTo(obj:GetPivot() + step) else obj.CFrame = obj.CFrame + step end
				end
			end)
			if arrivedAt and os.clock() - arrivedAt > 0.5 then break end -- giữ yên 0,5 giây rồi thả
		end
		for i, q in ipairs(parts) do pcall(function() q.CanCollide = cc[i] end) end
		for _, state in ipairs(moverStates) do
			local mover, was = state[1], state[2]
			if mover and mover.Parent then pcall(function() mover.Enabled = was end) end
		end
		launching[obj] = nil
	end)
end
local function scanProjectiles() -- dự phòng khi không bắt được vật ném mới sinh ra
	local r = root()
	if not r then return end
	local ok, found = pcall(function()
		local ps = OverlapParams.new()
		ps.FilterType = Enum.RaycastFilterType.Exclude
		ps.FilterDescendantsInstances = { LocalPlayer.Character }
		return workspace:GetPartBoundsInRadius(r.Position, 120, ps)
	end)
	if not ok then return end
	local n = 0
	for _, q in ipairs(found) do
		if not q.Anchored and not launching[q] and q.AssemblyLinearVelocity.Magnitude > 8 then
			local m = q:FindFirstAncestorOfClass("Model")
			if not (m and m:FindFirstChildOfClass("Humanoid")) then launch(q); n = n + 1; if n >= 3 then break end end
		end
	end
end

ThrowState.launch = launch
ThrowState.scanProjectiles = scanProjectiles
ThrowState.warmEclipse = function() task.spawn(findEclipse) end
end -- projectile trajectory controller

do -- pet receive and equip-best handling

-- Khi nhận pet: tự mở bảng Động vật nếu cần rồi bấm Equip best
local equipBusy = false
local function petReceived()
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and d.Text ~= "" and visible(d) and not Gui:IsAncestorOf(d) then
			local t = d.Text:lower()
			if t:find("you got", 1, true) or t:find("you received", 1, true) or t:find("new pet", 1, true)
				or t:find("bạn nhận", 1, true) or t:find("nhận được", 1, true) or t:find("received", 1, true) then return true end
		end
	end
	return false
end
local function equipBest()
	ThrowState.noHideUntil = os.clock() + 18
	local function findEquip()
		return findButtons(function(t) return t:find("equip best", 1, true) or t:find("trang bị tốt nhất", 1, true) end)
	end
	local opener, openedByUs, deadline = nil, false, os.clock() + 4
	while Hub.Alive and os.clock() < deadline do
		local list = findEquip()
		if #list > 0 then
			press(list[1])
			task.wait(0.35)
			if openedByUs and opener and opener.Parent then press(opener) end
			return true
		end
		if not opener then
			for _, b in ipairs(findButtons(function(t) return t:find("động vật", 1, true) or t:find("animals", 1, true) or t == "pets" or t == "pet" end)) do
				opener = b
				break
			end
			if opener then press(opener); openedByUs = true end
		end
		task.wait(0.25)
	end
	if openedByUs and opener and opener.Parent then press(opener) end
	return false
end
local function afterThrow()
	if equipBusy then return end
	equipBusy = true
	task.spawn(function()
		local t0, got = os.clock(), false
		-- 1) chờ cảnh nhận pet hiện ra (chữ "bỏ qua" hoặc chữ nhận pet); không có pet thì thôi
		while Hub.Alive and Config.autoThrow and os.clock() - t0 < 10 do
			if ThrowState.findSkip() or petReceived() then got = true; break end
			task.wait(0.2)
		end
		if got then
			-- 2) vòng bỏ qua tự bấm; chờ chữ bỏ qua biến mất (đã nhận xong)
			local t1 = os.clock()
			while Hub.Alive and Config.autoThrow and os.clock() - t1 < 10 and ThrowState.findSkip() do task.wait(0.2) end
			task.wait(0.6)
		end
		if got and Config.autoThrow then -- 3) nhận xong mới Equip best
			for attempt = 1, 3 do
				local ok, done = pcall(equipBest)
				if ok and done then break end
				task.wait(0.6)
			end
		end
		equipBusy = false
	end)
end

ThrowState.afterThrow = afterThrow
end -- pet receive and equip-best handling

do -- auto-throw feature wiring

local function stopMoverIfIdle() -- tắt tính năng là dừng ngay đi 45 stud/s, nhân vật về tốc độ bình thường
	if not (Config.autoPullup or Config.autoThrow or Config.upBar) then Mover.target = nil end
end
Internal.autoPullup = function()
	targetCache.PullUpBar = nil
	if Hub.PullFx then Hub.PullFx.reset() end
	stopMoverIfIdle()
end
local projConn
Internal.autoThrow = function(on)
	if projConn then projConn:Disconnect(); projConn = nil end
	stopMoverIfIdle()
	if on then
		targetCache.ThrowSpot = nil
		missT.ThrowSpot = nil
		ThrowState.captureCam()
		ThrowState.warmEclipse()
	else
		ThrowState.releaseCam()
		return
	end
	projConn = workspace.DescendantAdded:Connect(function(d)
		if not d:IsA("BasePart") or os.clock() - ThrowState.lastThrow > 6 then return end
		local r, ch = root(), LocalPlayer.Character
		if not r or (ch and d:IsDescendantOf(ch)) then return end
		local distanceFromPlayer = (d.Position - r.Position).Magnitude
		local namedProjectile = matches(d.Name, Hub.Targets.Projectile)
		if distanceFromPlayer > (namedProjectile and 1200 or 120) then return end
		local m = d:FindFirstAncestorOfClass("Model")
		if m and m:FindFirstChildOfClass("Humanoid") then return end
		local small = m and m ~= workspace and #m:GetChildren() <= 20 -- chỉ coi cả Model là vật ném khi nó nhỏ (tránh kéo cả khu đất)
		if d.Anchored and not namedProjectile and not (small and matches(m.Name, Hub.Targets.Projectile)) then return end
		ThrowState.launch(small and m or d)
	end)
	table.insert(conns, projConn)
end

-- Vòng ném: đứng đúng sàn ném (giữa 2 bờ tường), vào chỗ ném 1.158s thì bấm 1 lần.
local noPrompt, nearSince, enterT, wasAt = 0, nil, nil, false
loopWhile("autoThrow", 0.15, function()
	if os.clock() < busyUntil then return end
	local spot = findTarget("ThrowSpot")
	local at = ThrowState.atThrowSpot()
	if at ~= wasAt then wasAt = at; enterT = at and os.clock() or nil end
	if at then
		nearSince = nil
		local r = root()
		if spot and r then
			local sp = posOf(spot)
			if Vector3.new(sp.X - r.Position.X, 0, sp.Z - r.Position.Z).Magnitude < 15 then Hub.GoodSpot = spot end
		end
	elseif spot then
		if not goTo(posOf(spot), Config.moveMode) then nearSince = nil; return end -- chưa tới: đi tiếp
		nearSince = nearSince or os.clock()
		if os.clock() - nearSince > 4 and not ThrowState.readPower() then
			-- đã tới nhưng game không hiện "Nhấn để ném!": đây là điểm sai (tường...), loại và thử điểm khác
			Hub.BadSpots[spot] = true
			Hub.GoodSpot = nil
			targetCache.ThrowSpot = nil; missT.ThrowSpot = nil
			nearSince = nil
			local n = 0
			for _ in pairs(Hub.BadSpots) do n = n + 1 end
			if n > 8 then Hub.BadSpots = {} end
			return
		end
	else
		warnOnce("no_spot")
	end
	if at or ThrowState.readPower() then
		noPrompt = 0
		ThrowState.busy = true
		local ok, err = pcall(function()
			enterT = enterT or os.clock()
			ThrowState.throwOnce(enterT)
			enterT = nil
			local before = ThrowState.launchCount
			for _ = 1, 15 do -- tìm vật ném tối đa 1.5s sau khi bấm
				if ThrowState.launchCount > before or not Config.autoThrow then break end
				task.wait(0.1)
				ThrowState.scanProjectiles()
			end
			ThrowState.afterThrow()
			task.wait(0.6) -- chờ game hồi lại lượt ném
		end)
		ThrowState.busy = false
		if not ok then warn("[KROBUS] " .. tostring(err)) end
	else
		noPrompt = noPrompt + 1
		if noPrompt > 40 then -- 6s không thấy lời nhắc "Nhấn để ném!": thử một lần
			noPrompt = 0
			ThrowState.busy = true
			pcall(ThrowState.throwOnce, os.clock())
			ThrowState.busy = false
		end
	end
end)

end -- auto-throw feature wiring

-- ====================== AUTO UPDATE ======================
local function costNear(inst) -- giá nâng cấp đọc từ chữ "$..." gắn với bục
	if Hub.Hooks.GetUpgradeCost then
		local ok, v = pcall(Hub.Hooks.GetUpgradeCost)
		if ok and tonumber(v) then return tonumber(v) end
	end
	local scope = { inst }
	local m = inst:FindFirstAncestorOfClass("Model")
	if m then scope[#scope + 1] = m end
	local par = inst.Parent
	if par and par ~= workspace and par ~= m and (par:IsA("Model") or par:IsA("Folder")) and #par:GetChildren() < 40 then scope[#scope + 1] = par end
	for _, r_ in ipairs(scope) do
		for _, d in ipairs(r_:GetDescendants()) do
			if isPowerTextObject(d) then
				local t = d.Text:match("%$[%d%.,]+%s*%a*")
				local v = t and parseMoney(t)
				if v then return v end
			end
		end
	end
	return nil
end
local costCache = { t = -99 }
local function worldCost(pos) -- bảng giá gần bục nhất trong bán kính 40 studs
	if os.clock() - costCache.t < 10 then return costCache.v end
	local best, bd
	for i, d in ipairs(workspace:GetDescendants()) do
		if i % 1500 == 0 then task.wait() end
		if isPowerTextObject(d) then
			local t = d.Text:match("%$[%d%.,]+%s*%a*")
			local gui = t and d:FindFirstAncestorWhichIsA("LayerCollector")
			if gui and (gui:IsA("SurfaceGui") or gui:IsA("BillboardGui")) then
				local part = gui.Adornee or gui.Parent
				if part and part:IsA("Attachment") then part = part.Parent end
				if part and part:IsA("BasePart") then
					local dist = (part.Position - pos).Magnitude
					local v = parseMoney(t)
					if v and dist < 40 and (not bd or dist < bd) then best, bd = v, dist end
				end
			end
		end
	end
	costCache = { t = os.clock(), v = best }
	return best
end
local padCache = { t = -99 }
local function findUpgradePad() -- theo tên (ưu tiên của mình); nếu không có thì tìm đĩa vàng gần xà ngang của mình
	local named = findTarget("UpgradePad")
	if named then return named end
	if padCache.inst and padCache.inst.Parent and os.clock() - padCache.t < 60 then return padCache.inst end
	local bar = findTarget("PullUpBar")
	if not bar then return nil end
	local bp = posOf(bar)
	local ok, found = pcall(function() return workspace:GetPartBoundsInRadius(bp, 40) end)
	local best, bd
	if ok then
		for _, q in ipairs(found) do
			if q.Anchored and q.Transparency < 0.5 then
				local c3 = q.Color
				if c3.R > 0.85 and c3.G > 0.65 and c3.B < 0.35 and q.Size.X * q.Size.Z < 400 then
					local d = (q.Position - bp).Magnitude
					if not bd or d < bd then best, bd = q, d end
				end
			end
		end
	end
	padCache = { t = os.clock(), inst = best }
	return best
end
local lastUpgradeAction = 0
local function activateUpgradePad(pad)
	if not pad or os.clock() - lastUpgradeAction < 1.2 then return false end
	local objects = { pad }
	for _, d in ipairs(pad:GetDescendants()) do objects[#objects + 1] = d end
	for _, d in ipairs(objects) do
		if d:IsA("ProximityPrompt") and d.Enabled then
			local promptPart = d.Parent
			if promptPart and promptPart:IsA("Attachment") then promptPart = promptPart.Parent end
			local r = root()
			if r and promptPart and promptPart:IsA("BasePart")
				and (r.Position - promptPart.Position).Magnitude <= d.MaxActivationDistance + 6 then
				lastUpgradeAction = os.clock()
				if fireproximityprompt then
					local ok = pcall(fireproximityprompt, d)
					return ok
				else
					pcall(function()
						local promptKey = d.KeyboardKeyCode ~= Enum.KeyCode.Unknown and d.KeyboardKeyCode or Enum.KeyCode.E
						VIM:SendKeyEvent(true, promptKey, false, game)
						task.wait(math.max(d.HoldDuration, 0.1))
						VIM:SendKeyEvent(false, promptKey, false, game)
					end)
					return true
				end
			end
		elseif d:IsA("ClickDetector") then
			if fireclickdetector then
				lastUpgradeAction = os.clock()
				return pcall(fireclickdetector, d)
			end
		end
	end
	local r = root()
	local targetPart = pad:IsA("BasePart") and pad or pad:FindFirstChildWhichIsA("BasePart", true)
	if r and targetPart and (r.Position - targetPart.Position).Magnitude <= 12 and firetouchinterest then
		lastUpgradeAction = os.clock()
		pcall(function() firetouchinterest(r, targetPart, 0); firetouchinterest(r, targetPart, 1) end)
		return true
	end
	for _, b in ipairs(findButtons(function(t) return t:find("upgrade", 1, true) or t:find("nâng cấp", 1, true) end)) do
		local priceText = fullText(b):match("%$[%d%.,]+%s*%a*")
		local price = priceText and parseMoney(priceText)
		local currentMoney = getMoney()
		if not price or not currentMoney or currentMoney >= price then
			lastUpgradeAction = os.clock()
			press(b)
			return true
		end
	end
	return false
end
Hub._lbu = -99
loopWhile("upBar", 1.5, function()
	if ThrowState.busy or os.clock() < busyUntil then return end
	local money = getMoney()
	local pad = findUpgradePad() -- bục vàng nâng cấp trong thế giới
	if pad then
		local pos = posOf(pad)
		local cost = costNear(pad) or worldCost(pos)
		if money and cost then
			if money < cost then return end -- biết cả tiền lẫn giá: chỉ nâng cấp khi đủ tiền
		elseif os.clock() - Hub._lbu < 20 then
			return -- không đọc được tiền/giá: cứ thử mỗi 20 giây (server tự kiểm tra tiền)
		end
		Hub._lbu = os.clock()
		Hub.runTask(pos, function() activateUpgradePad(pad) end) -- dịch chuyển tới bục, nâng cấp, rồi quay về
		return
	end
	for _, b in ipairs(findButtons(function(t) return t:find("upgrade", 1, true) or t:find("nâng cấp", 1, true) end)) do
		local price = parseMoney((fullText(b):match("%$[%d%.,]+%s*%a*")) or "")
		if not price and Hub.Hooks.GetUpgradeCost then
			local ok, v = pcall(Hub.Hooks.GetUpgradeCost)
			price = ok and tonumber(v) or nil
		end
		if not money or not price or money >= price then press(b) end
	end
end)
local boughtAt, skipUntilMoney = {}, 0
local function shopWindow() -- Food Shop đang mở = thấy >= 3 thẻ món ăn (không phụ thuộc tên tiêu đề / nút mở shop luôn hiện trên HUD)
	if not Hub.FoodSet then
		Hub.FoodSet = {}
		for _, f in ipairs(FOODS) do Hub.FoodSet[f[1]:lower()] = true end
	end
	local count, first = 0, nil
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and d.Parent and Hub.FoodSet[d.Text:lower()] and not Gui:IsAncestorOf(d) and d:IsDescendantOf(PlayerGui) and visible(d) then
			count = count + 1
			first = first or d
			if count >= 3 then return first end
		end
	end
	return nil
end
local function openFoodShop()
	local w = shopWindow()
	if w then return w end
	ThrowState.noHideUntil = os.clock() + 6
	local function tryOpen(pred)
		for _, b in ipairs(findButtons(pred)) do press(b); break end
		for _ = 1, 8 do task.wait(0.25); w = shopWindow(); if w then return w end end
		return nil
	end
	if tryOpen(function(t) return (t:find("food", 1, true) and t:find("shop", 1, true)) or t:find("thức ăn", 1, true) end) then return w end
	if tryOpen(function(t) return t:find("cửa hàng", 1, true) or t:find("shop", 1, true) or t:find("store", 1, true) end) then return w end
	if tryOpen(function(t) return t:find("food", 1, true) ~= nil end) then return w end
	return nil
end
local function closeFoodShop(w)
	local sg = w and w:FindFirstAncestorWhichIsA("ScreenGui")
	if not sg then return end
	for _, b in ipairs(guiButtonList()) do
		if b:IsDescendantOf(sg) and visible(b) then
			local t = (fullText(b):gsub("%s", ""))
			if t == "x" or t == "×" or t == "✕" or t == "✖" then press(b); return end
		end
	end
end
local function scrollIntoView(g) -- thẻ món nằm ngoài khung cuộn thì cuộn tới trước khi bấm
	local sf = g:FindFirstAncestorWhichIsA("ScrollingFrame")
	if not sf then return end
	pcall(function()
		local dx = (g.AbsolutePosition.X + g.AbsoluteSize.X / 2) - (sf.AbsolutePosition.X + sf.AbsoluteSize.X / 2)
		local dy = (g.AbsolutePosition.Y + g.AbsoluteSize.Y / 2) - (sf.AbsolutePosition.Y + sf.AbsoluteSize.Y / 2)
		sf.CanvasPosition = sf.CanvasPosition + Vector2.new(dx, dy)
	end)
end
local function pressEquipIn(cardF) -- bấm nút Equip / Trang bị / Select của thẻ món (bỏ qua chữ "Equipped" = đang dùng)
	for _, x in ipairs(cardF:GetDescendants()) do
		if x:IsA("TextButton") or x:IsA("ImageButton") then
			local t = (fullText(x):gsub("%s", ""))
			if t == "equip" or t == "trangbị" or t == "select" or t == "chọn" or t == "use" or t == "dùng" then press(x); return true end
		end
	end
	return false
end
local function buyFoodCard(name, price) -- trả về "bought", "owned" hoặc nil (không thấy thẻ)
	local lname = name:lower()
	for _, d in ipairs(guiTextList()) do
		if isPowerTextObject(d) and d.Parent and d.Text:lower() == lname and not Gui:IsAncestorOf(d) and d:IsDescendantOf(PlayerGui) then
			local cardF, priceObj = d.Parent, nil
			for _ = 1, 3 do -- đi lên tối đa 3 tầng đến khi thẻ chứa nhãn giá của món
				if not cardF then break end
				for _, x in ipairs(cardF:GetDescendants()) do
					if (x:IsA("TextLabel") or x:IsA("TextButton")) and x.Text:find("^%s*%$") and not x.Text:find("/", 1, true) then
						local v = parseMoney(x.Text)
						if v and math.abs(v - price) / price < 0.01 then priceObj = x; break end
					end
				end
				if priceObj then break end
				cardF = cardF.Parent
			end
			if priceObj then
				local all = ""
				for _, x in ipairs(cardF:GetDescendants()) do if x:IsA("TextLabel") or x:IsA("TextButton") then all = all .. " " .. x.Text end end
				all = all:lower()
				if all:find("owned", 1, true) or all:find("equipped", 1, true) or all:find("sở hữu", 1, true) or all:find("đã mua", 1, true) then
					pressEquipIn(cardF) -- đã có: bảo đảm đang được chọn dùng
					return "owned"
				end
				scrollIntoView(priceObj)
				task.wait(0.15)
				local buyButton = priceObj:FindFirstAncestorWhichIsA("GuiButton")
				if buyButton then press(buyButton) else clickGui(priceObj) end
				task.wait(0.5)
				pressEquipIn(cardF) -- vừa mua: chọn dùng món mới
				return "bought"
			end
		end
	end
	return nil
end
Internal.foodTarget = function() skipUntilMoney = 0 end
Internal.upFood = function() skipUntilMoney = 0 end
loopWhile("upFood", 2, function()
	if ThrowState.busy then return end
	local money = getMoney()
	if not money then
		if Config.foodTarget == "food_best" then warnOnce("no_money"); return end
		money = math.huge -- chọn sẵn 1 món: cứ thử mua, server tự kiểm tra tiền
	end
	if money < skipUntilMoney then return end
	local sorted = {}
	for _, f in ipairs(FOODS) do
		local p = parseMoney(f[2])
		if p and p > 0 and p <= money and (Config.foodTarget == "food_best" or Config.foodTarget == f[1]) then sorted[#sorted + 1] = { f[1], p } end
	end
	table.sort(sorted, function(a, b) return a[2] > b[2] end)
	if #sorted == 0 then return end -- chưa đủ tiền cho món đã chọn
	if Hub.Hooks.BuyFood then
		if os.clock() - (boughtAt[sorted[1][1]] or -99) > 10 then boughtAt[sorted[1][1]] = os.clock(); pcall(Hub.Hooks.BuyFood, sorted[1][1]) end
		return
	end
	local w = shopWindow()
	local opened = false
	if not w then w = openFoodShop(); opened = w ~= nil end
	if not w then warnOnce("no_shop"); return end
	for _, f in ipairs(sorted) do
		if os.clock() - (boughtAt[f[1]] or -99) > 10 then
			local res = buyFoodCard(f[1], f[2])
			if res == "bought" then boughtAt[f[1]] = os.clock(); break
			elseif res == "owned" then
				-- món tốt nhất mua được đã có rồi: chờ đến khi đủ tiền cho món đắt hơn kế tiếp rồi mới mở shop lại
				local nextP = math.huge
				for _, g in ipairs(FOODS) do
					local pp = parseMoney(g[2])
					if pp and pp > f[2] and pp < nextP and Config.foodTarget == "food_best" then nextP = pp end
				end
				skipUntilMoney = nextP
				break
			end
		end
	end
	if opened then task.wait(0.4); closeFoodShop(w) end
end)

-- ====================== AUTO SELL PETS ======================
-- Bán pet có thu nhập ($/s) <= mức đã chọn. Thứ tự thử:
--  0) Hooks.SellPets(maxRate) nếu bạn tự viết;
--  1) bảng pet trên màn hình: mỗi thẻ pet có chữ "$x/s" và đúng 1 nút Bán/Sell -> bấm nút của thẻ đủ điều kiện;
--  2) pet dạng Tool trong Backpack (đọc $/s từ tên/thuộc tính): cầm lên rồi bấm nút Bán/Sell trên màn hình.
-- Không bao giờ bấm nút "bán tất cả" / "sell all".
local function petRate(text) -- nhận cả "$500/s" và "500$/s"; không đọc được thì KHÔNG bán pet đó
	local normalized = tostring(text):gsub(",", ""):gsub("%$", "")
	local a = normalized:match("([%d%.]+%s*%a*)%s*/%s*[sS]")
	return a and parseMoney(a) or nil
end
local function isSellText(t)
	if not (t:find("bán", 1, true) or t:find("bÁn", 1, true) or t:find("sell", 1, true)) then return false end
	return not (t:find("all", 1, true) or t:find("tất cả", 1, true) or t:find("hết", 1, true) or t:find("everything", 1, true))
end
local function pressConfirm()
	task.wait(0.4)
	for _, b in ipairs(findButtons(function(t) return t == "yes" or t == "có" or t:find("confirm", 1, true) or t:find("xác nhận", 1, true) or t:find("đồng ý", 1, true) end)) do press(b) end
end
local function sellFromUI(limit) -- nil: không có nút bán | false: có nhưng chưa pet nào đủ điều kiện | true: đã bán
	local btns = findButtons(isSellText)
	if #btns == 0 then return nil end
	for _, b in ipairs(btns) do
		local o = b.Parent
		for _ = 1, 4 do
			if not o or o == PlayerGui then break end
			local rate
			for _, d in ipairs(o:GetDescendants()) do
				if isPowerTextObject(d) then
					rate = petRate(d.Text)
					if rate then break end
				end
			end
			if rate then -- thẻ này phải chỉ có đúng 1 nút bán, nếu không là đang xét nhầm cả danh sách
				local n = 0
				for _, d in ipairs(o:GetDescendants()) do
					if (d:IsA("TextButton") or d:IsA("ImageButton")) and isSellText(fullText(d)) then n = n + 1 end
				end
				if n == 1 and rate <= limit and Config.autoSellPets then press(b); pressConfirm(); return true end
				break
			end
			o = o.Parent
		end
	end
	return false
end
local lastEquip = 0
local function sellFromTools(limit)
	local bp, h = LocalPlayer:FindFirstChildOfClass("Backpack"), hum()
	if not (bp and h) then return nil end
	local seen = false
	for _, tool in ipairs(bp:GetChildren()) do
		if tool:IsA("Tool") then
			local rate = petRate(tool.Name)
			if not rate then
				for k, v in pairs(tool:GetAttributes()) do
					if type(v) == "string" then rate = petRate(v)
					elseif type(v) == "number" and matches(k, { "income", "persec", "per_sec", "earn", "mps" }) then rate = v end
					if rate then break end
				end
			end
			if rate then
				seen = true
				if rate <= limit and Config.autoSellPets and os.clock() - lastEquip > 3 then
					local btns = findButtons(isSellText)
					if #btns == 0 then return nil end
					lastEquip = os.clock()
					pcall(function() h:EquipTool(tool) end)
					task.wait(0.4)
					for _, b in ipairs(btns) do press(b) end
					pressConfirm()
					return true
				end
			end
		end
	end
	return seen and false or nil
end
local sellMiss = 0
loopWhile("autoSellPets", 1.5, function()
	local limit = SELL_LIMITS[Config.sellMax] or SELL_STEPS[1][2]
	if Hub.Hooks.SellPets then pcall(Hub.Hooks.SellPets, limit); return end
	local r = sellFromUI(limit)
	if r == nil then r = sellFromTools(limit) end
	if r == nil then
		sellMiss = sellMiss + 1
		if sellMiss >= 20 then warnOnce("no_sell") end -- ~30s không thấy gì để bán
	else
		sellMiss = 0
	end
end)

-- ====================== UNLOAD ======================
function Hub.Unload()
	Hub.Alive = false
	Config.autoThrow = false
	Config.autoPullup = false
	Mover.target = nil
	pcall(ThrowState.releaseCam)
	if Hub.PullFx then pcall(Hub.PullFx.reset) end
	pcall(function() RunService:UnbindFromRenderStep("KROBUS_CAM") end)
	pcall(function() Internal.boostFps(false) end)
	Internal.fixLag(false)
	if setfpscap then pcall(setfpscap, 60) end
	for _, c in ipairs(conns) do pcall(function() c:Disconnect() end) end
	table.clear(conns)
	if Gui then Gui:Destroy() end
	if env.KROBUS_HUB == Hub then env.KROBUS_HUB = nil end
end

selectTab("info")
fire("boostFps", true) -- mặc định bật
fire("fixLag", true)   -- mặc định bật
refreshStatus()
notify(HUB_NAME .. " " .. tr("loaded"))
return Hub
