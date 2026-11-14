local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

repeat task.wait() until Players.LocalPlayer

local player = Players.LocalPlayer
local success, result = pcall(function()
    return player:GetMouse()
end)

local mouse = success and result or nil

-- ============================================================
--  OBSIDIAN UI (deividcomsono/Obsidian)
--  A small helper layer below maps Tabs.X:AddToggle / AddSlider /
--  AddDropdown ... onto Obsidian groupboxes.
-- ============================================================
local repo         = "https://raw.githubusercontent.com/deividcomsono/Obsidian/main/"
local Library      = loadstring(game:HttpGet(repo .. "Library.lua"))()
local ThemeManager = loadstring(game:HttpGet(repo .. "addons/ThemeManager.lua"))()
local SaveManager  = loadstring(game:HttpGet(repo .. "addons/SaveManager.lua"))()

local ObsidianWindow = Library:CreateWindow({
    Title = "Aotr:update5",
    Footer = "Attack on Titan: Revolution",
    NotifySide = "Right",
    ShowCustomCursor = false,
    Size = UDim2.fromOffset(640, 480),
    Center = true,
    AutoShow = true,
})

local Notifier = {}
function Notifier:Notify(o)
    pcall(function()
        Library:Notify({
            Title = o.Title or "",
            Description = o.Content or "",
            Time = o.Duration or 4,
        })
    end)
end

-- Tab wrapper -> Obsidian tab. Each AddSection() starts a new groupbox,
-- alternating left/right. Controls added before any section go in a groupbox
-- named after the tab.
local function MakeTab(rawTab, title)
    local tab = { _tab = rawTab, _count = 0, _box = nil }

    local function newBox(name)
        tab._count += 1
        if tab._count % 2 == 1 then
            tab._box = rawTab:AddLeftGroupbox(name)
        else
            tab._box = rawTab:AddRightGroupbox(name)
        end
        return tab._box
    end
    local function box() return tab._box or newBox(title) end
    local function note(o)
        if o.Description and o.Description ~= "" then box():AddLabel(o.Description, true) end
    end

    function tab:AddSection(name) newBox(name) end

    function tab:AddToggle(idx, o)
        local t = box():AddToggle(idx, { Text = o.Title, Default = o.Default or false, Callback = o.Callback })
        note(o)
        return t
    end

    function tab:AddSlider(idx, o)
        local s = box():AddSlider(idx, {
            Text = o.Title, Default = o.Default, Min = o.Min, Max = o.Max,
            Rounding = o.Rounding or 0, Callback = o.Callback,
        })
        note(o)
        return s
    end

    function tab:AddDropdown(idx, o)
        local multi = o.Multi == true
        local info = { Text = o.Title, Values = o.Values or {}, Multi = multi, Callback = o.Callback }
        if not multi then info.Default = o.Default end
        local dd = box():AddDropdown(idx, info)
        if multi and type(o.Default) == "table" then
            local map = {}
            for k, v in pairs(o.Default) do
                if type(k) == "number" then map[v] = true elseif v then map[k] = true end
            end
            if next(map) then pcall(function() dd:SetValue(map) end) end
        end
        note(o)
        return dd
    end

    function tab:AddInput(idx, o)
        return box():AddInput(idx, {
            Text = o.Title, Default = o.Default or "", Placeholder = o.Placeholder or "",
            Numeric = o.Numeric or false, Finished = o.Finished or false, Callback = o.Callback,
        })
    end

    function tab:AddButton(o)
        local b = box():AddButton({ Text = o.Title, Func = o.Callback })
        note(o)
        return b
    end

    function tab:AddColorpicker(idx, o)
        local lbl = box():AddLabel(o.Title or "Color")
        local picker = lbl:AddColorPicker(idx, { Default = o.Default or Color3.new(1, 1, 1), Title = o.Title })
        local wrap = { _p = picker }
        function wrap:OnChanged(fn)
            pcall(function() picker:OnChanged(fn) end)
        end
        function wrap:SetValueRGB(c)
            local ok = pcall(function() picker:SetValueRGB(c) end)
            if not ok then
                pcall(function() picker:SetValue({ Color3.toHSV(c) }) end)
            end
        end
        return wrap
    end

    -- Paragraph -> wrapped label (keeps :SetDesc / .DescLabel for the Account tab).
    function tab:AddParagraph(o)
        local ttl, content = o.Title or "", o.Content or ""
        local function render(c)
            if ttl == "" then return c end
            if c:find("\n") or #c > 40 then return ttl .. "\n" .. c end
            return ttl .. ": " .. c
        end
        local lbl = box():AddLabel(render(content), true)
        local p = { DescLabel = lbl and lbl.TextLabel }
        function p:SetDesc(c) pcall(function() lbl:SetText(render(tostring(c))) end) end
        function p:SetTitle(t) ttl = t end
        return p
    end

    return tab
end

local Window = {}
Window.Root = setmetatable({}, {
    __index = function(_, k) if k == "Visible" then return Library.Toggled end end,
    __newindex = function(_, k, v)
        if k == "Visible" and Library.Toggled ~= v then pcall(function() Library:Toggle() end) end
    end,
})
function Window:AddTab(o)
    local raw
    local icon = (o.Icon and o.Icon ~= "") and o.Icon or nil
    local ok = pcall(function() raw = ObsidianWindow:AddTab(o.Title, icon) end)
    if not ok or not raw then raw = ObsidianWindow:AddTab(o.Title) end
    return MakeTab(raw, o.Title)
end
function Window:Minimize(force)
    pcall(function()
        if force == true then
            if Library.Toggled then Library:Toggle() end
        else
            Library:Toggle()
        end
    end)
end
function Window:SelectTab(tab) pcall(function() tab._tab:Show() end) end

local TrayIcon = {}
TrayIcon.isVisible = true
TrayIcon.connection = nil

function TrayIcon:CreateIcon()
    local screenGui = Instance.new("ScreenGui")
    screenGui.Name = "TrayIconGui"
    screenGui.ResetOnSpawn = false
    screenGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
    screenGui.Parent = game:GetService("CoreGui")

    local iconFrame = Instance.new("Frame")
    iconFrame.Name = "TrayIcon"
    iconFrame.Size = UDim2.new(0, 50, 0, 50)
    iconFrame.Position = UDim2.new(1, -60, 0, 10)
    iconFrame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
    iconFrame.BorderSizePixel = 0
    iconFrame.Parent = screenGui

    local corner = Instance.new("UICorner")
    corner.CornerRadius = UDim.new(0.5, 0)
    corner.Parent = iconFrame

    local iconText = Instance.new("TextLabel")
    iconText.Size = UDim2.new(1, 0, 1, 0)
    iconText.Position = UDim2.new(0, 0, 0, 0)
    iconText.BackgroundTransparency = 1
    iconText.Text = "A"
    iconText.TextColor3 = Color3.fromRGB(255, 255, 255)
    iconText.TextScaled = true
    iconText.Font = Enum.Font.GothamBold
    iconText.Parent = iconFrame

    local hoverTween = nil
    iconFrame.MouseEnter:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 55, 0, 55), BackgroundColor3 = Color3.fromRGB(16, 110, 190)}
        )
        hoverTween:Play()
    end)

    iconFrame.MouseLeave:Connect(function()
        if hoverTween then hoverTween:Cancel() end
        hoverTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
            {Size = UDim2.new(0, 50, 0, 50), BackgroundColor3 = Color3.fromRGB(0, 120, 212)}
        )
        hoverTween:Play()
    end)

    local clickDetector = Instance.new("TextButton")
    clickDetector.Size = UDim2.new(1, 0, 1, 0)
    clickDetector.Position = UDim2.new(0, 0, 0, 0)
    clickDetector.BackgroundTransparency = 1
    clickDetector.Text = ""
    clickDetector.Parent = iconFrame

    clickDetector.MouseButton1Click:Connect(function()
        self:ToggleUI()
        local clickTween = TweenService:Create(iconFrame,
            TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
            {Size = UDim2.new(0, 45, 0, 45)}
        )
        clickTween:Play()
        clickTween.Completed:Connect(function()
            local returnTween = TweenService:Create(iconFrame,
                TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
                {Size = UDim2.new(0, 50, 0, 50)}
            )
            returnTween:Play()
        end)
    end)

    self.gui = screenGui
    self.frame = iconFrame
    self.text = iconText
    self:CreateTooltip()
end

function TrayIcon:CreateTooltip()
    local tooltip = Instance.new("Frame")
    tooltip.Name = "Tooltip"
    tooltip.Size = UDim2.new(0, 200, 0, 30)
    tooltip.Position = UDim2.new(1, -210, 0.5, -15)
    tooltip.BackgroundColor3 = Color3.fromRGB(32, 32, 32)
    tooltip.BorderSizePixel = 0
    tooltip.Visible = false
    tooltip.Parent = self.frame

    local tooltipCorner = Instance.new("UICorner")
    tooltipCorner.CornerRadius = UDim.new(0, 5)
    tooltipCorner.Parent = tooltip

    local tooltipText = Instance.new("TextLabel")
    tooltipText.Size = UDim2.new(1, -10, 1, 0)
    tooltipText.Position = UDim2.new(0, 5, 0, 0)
    tooltipText.BackgroundTransparency = 1
    tooltipText.Text = "Click to toggle UI visibility"
    tooltipText.TextColor3 = Color3.fromRGB(255, 255, 255)
    tooltipText.TextScaled = true
    tooltipText.Font = Enum.Font.Gotham
    tooltipText.Parent = tooltip

    self.frame.MouseEnter:Connect(function() tooltip.Visible = true end)
    self.frame.MouseLeave:Connect(function() tooltip.Visible = false end)
end

function TrayIcon:ToggleUI()
    if self.isVisible then self:HideUI() else self:ShowUI() end
end

function TrayIcon:HideUI()
    if Window and Window.Root then
        Window.Root.Visible = false
        self.isVisible = false
        self.text.Text = "H"
        self.frame.BackgroundColor3 = Color3.fromRGB(220, 53, 69)
        Notifier:Notify({ Title = "UI Hidden", Content = "Click the tray icon to show UI again", Duration = 3 })
    end
end

function TrayIcon:ShowUI()
    if Window and Window.Root then
        Window.Root.Visible = true
        self.isVisible = true
        self.text.Text = "A"
        self.frame.BackgroundColor3 = Color3.fromRGB(0, 120, 212)
        Notifier:Notify({ Title = "UI Shown", Content = "UI is now visible", Duration = 2 })
    end
end

TrayIcon:CreateIcon()

--//==============================\\--
--||         TABS SETUP           ||--
--\\==============================//--

local EarlyAccountTab = Window:AddTab({ Title = "Account", Icon = "user" })

local Tabs = {
    Main          = Window:AddTab({ Title = "Main(Risky)",               Icon = "swords" }),
    AutoJoin      = Window:AddTab({ Title = "Auto Join",                 Icon = "door-open" }),
    Servers       = Window:AddTab({ Title = "Servers",                   Icon = "server" }),
    Misc          = Window:AddTab({ Title = "Misc",                      Icon = "wrench" }),
    Esp           = Window:AddTab({ Title = "Titans Esp",                Icon = "eye" }),
    Webhook       = Window:AddTab({ Title = "Webhook",                   Icon = "webhook" }),
    Settings      = Window:AddTab({ Title = "Settings",                  Icon = "settings" }),
}

--//==============================\\--
--||         SETTINGS TAB         ||--
--\\==============================//--

Tabs.Settings:AddToggle("TrayIconToggle", {
    Title = "Show Tray Icon",
    Description = "Show/Hide the system tray icon",
    Default = true,
    Callback = function(state)
        if TrayIcon.gui then TrayIcon.gui.Enabled = state end
    end
})

Tabs.Settings:AddParagraph({
    Title = "Tray Icon Usage",
    Content = "• The tray icon appears in the top-right corner\n• Click it to hide/show the UI\n• Red icon = UI hidden, Blue icon = UI visible\n• Ctrl+H (keyboard) or double-tap the screen (mobile) also toggles the UI"
})

--//==============================\\--
--||       MAINMENU (PlaceId)     ||--
--\\==============================//--

local allowedPlaceId = 13379208636
if game.PlaceId == allowedPlaceId then
    Tabs.Mainmenu = Window:AddTab({ Title = "Mainmenu", Icon = "house" })
    Tabs.Mainmenu:AddToggle("AutoRollToggle", {
        Title = "Auto Roll",
        Default = false,
        Callback = function(state) ENABLED = state end
    })
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if gameProcessed then return end
    if input.KeyCode == Enum.KeyCode.H and UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) then
        TrayIcon:ToggleUI()
    end
end)

game.Players.PlayerRemoving:Connect(function(plr)
    if plr == player and TrayIcon.gui then TrayIcon.gui:Destroy() end
end)

--------------------------------------------------------------------------

local HttpService     = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInput    = game:GetService("VirtualInputManager")
local GuiService      = game:GetService("GuiService")
local TeleportService = game:GetService("TeleportService")

local char = player.Character or player.CharacterAdded:Wait()
local hrp  = char:WaitForChild("HumanoidRootPart")

local retryRemote = ReplicatedStorage:WaitForChild("Assets"):WaitForChild("Remotes"):WaitForChild("GET")

local isFlying   = false
local bodyPos
local LocalPlayer = Players.LocalPlayer
local startDelay  = 0
local flyHeight   = 250

--//==============================\\--
--||      👑 AUTO KILL TITANS     ||--
--\\==============================//--

local Services = {
    Players         = game:GetService("Players"),
    RunService      = game:GetService("RunService"),
    ReplicatedStorage = game:GetService("ReplicatedStorage"),
    TweenService    = game:GetService("TweenService"),
    CoreGui         = game:GetService("CoreGui")
}

local Player = {
    self      = Services.Players.LocalPlayer,
    character = nil,
    hrp       = nil,
    gui       = nil
}

local Config = {
    flySpeed              = 250,
    canHit                = true,
    isFlying              = false,
    moveMode              = "Teleportation",
    notificationsEnabled  = true,
    startDelay            = 0,
    flyHeight             = 250,
    titanKillCount        = 0,
    autoRefill            = false,
    lastBladesEmpty       = false,
    lastSpearsEmpty       = false
}

local Data = {
    notified    = {},
    activeNotifs = {},
    POST        = nil,
    refill      = nil
}

Player.character = Player.self.Character or Player.self.CharacterAdded:Wait()
Player.hrp       = Player.character:WaitForChild("HumanoidRootPart")
Player.gui       = Player.self:WaitForChild("PlayerGui")

task.spawn(function()
    local success2, result2 = pcall(function()
        return Services.ReplicatedStorage:WaitForChild("Assets", 10):WaitForChild("Remotes", 10):WaitForChild("POST", 10)
    end)
    Data.POST = success2 and result2 or nil
end)

function showKillNotification(count)
    if not Config.notificationsEnabled then return end
    local gui = Instance.new("ScreenGui")
    gui.Name = "TN_" .. tick()
    gui.ResetOnSpawn = false
    gui.IgnoreGuiInset = true
    gui.Parent = Services.CoreGui
    local frame = Instance.new("Frame", gui)
    frame.Size = UDim2.new(0, 190, 0, 75)
    frame.Position = UDim2.new(1, 20, 0, 10 + (#Data.activeNotifs * 80))
    frame.BackgroundColor3 = Color3.fromRGB(15, 15, 15)
    frame.BorderSizePixel = 2
    frame.BorderColor3 = Color3.fromRGB(184, 164, 101)
    local label = Instance.new("TextLabel", frame)
    label.Size = UDim2.new(0.65, 0, 1, 0)
    label.Position = UDim2.new(0, 5, 0, 0)
    label.BackgroundTransparency = 1
    label.Text = "Successfully\nHit:"
    label.TextColor3 = Color3.fromRGB(184, 164, 101)
    label.Font = Enum.Font.Fantasy
    label.TextScaled = true
    local counter = Instance.new("TextLabel", frame)
    counter.Size = UDim2.new(0, 60, 0.5, 0)
    counter.Position = UDim2.new(1, -65, 0, 0)
    counter.BackgroundTransparency = 1
    counter.Text = tostring(count)
    counter.TextColor3 = Color3.fromRGB(255, 255, 255)
    counter.Font = Enum.Font.Fantasy
    counter.TextScaled = true
    table.insert(Data.activeNotifs, gui)
    Services.TweenService:Create(frame, TweenInfo.new(0.35), {
        Position = UDim2.new(1, -210, 0, 10 + ((#Data.activeNotifs - 1) * 80))
    }):Play()
    task.delay(5, function()
        gui:Destroy()
        for i, v in ipairs(Data.activeNotifs) do
            if v == gui then table.remove(Data.activeNotifs, i) break end
        end
    end)
end

local TITAN_PRIORITY = { "Attack_Titan", "Female_Titan", "Armored_Titan" }

local function napeOf(titan)
    local hb = titan:FindFirstChild("Hitboxes")
    local hit = hb and hb:FindFirstChild("Hit")
    return hit and hit:FindFirstChild("Nape")
end

local function isAlive(titan)
    local h = titan:FindFirstChildWhichIsA("Humanoid")
    return h and h.Health > 0
end

-- keep the character reference fresh after respawn (the old code kept a dead HRP)
Player.self.CharacterAdded:Connect(function(c)
    Player.character = c
    Player.hrp = c:WaitForChild("HumanoidRootPart")
end)

local targetList, lastScan = {}, 0

local function scanTargets()
    table.clear(targetList)
    local folder = workspace:FindFirstChild("Titans")
    if not folder or not Player.hrp then return end
    local pos = Player.hrp.Position
    for _, name in ipairs(TITAN_PRIORITY) do
        local t = folder:FindFirstChild(name)
        if t and isAlive(t) then
            local n = napeOf(t)
            if n then targetList[#targetList + 1] = n end
        end
    end
    local others = {}
    for _, t in ipairs(folder:GetChildren()) do
        if not table.find(TITAN_PRIORITY, t.Name) and isAlive(t) then
            local n = napeOf(t)
            if n then others[#others + 1] = { n, (pos - n.Position).Magnitude } end
        end
    end
    table.sort(others, function(a, b) return a[2] < b[2] end)
    for _, o in ipairs(others) do targetList[#targetList + 1] = o[1] end
end

-- target list is rebuilt at most 10x/second instead of every frame
function getClosestValidNape()
    local first = targetList[1]
    if os.clock() - lastScan > 0.1 or not first or not first.Parent then
        scanTargets()
        lastScan = os.clock()
    end
    return targetList[1]
end

Config.hitCooldown = 0.12   -- seconds between hit bursts (was 0.25)
Config.multiHit    = 8      -- napes hit per burst (was 3)
Config.hitAll      = false  -- true = every alive titan gets hit in the same burst

local killConnection
local killStartAt = 0

Config.baseStartDelay = 5   -- fixed 5 second wait before farming begins (slider adds on top)

function killFromAbove()
    if game.PlaceId == 14916516914 then Config.isFlying = false return end -- never farm in the Lobby
    killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
    if killConnection then return end -- one connection only (old code stacked a new one on every toggle)
    killConnection = Services.RunService.Heartbeat:Connect(function()
        if not Config.isFlying or Config.missionDone or os.clock() < killStartAt then return end
        local hrp = Player.hrp
        if not hrp or not hrp.Parent then return end
        local nape = getClosestValidNape()
        if not nape then return end
        local targetPos = nape.Position + Vector3.new(0, Config.flyHeight, 0)
        if Config.moveMode == "Gliding" then
            local delta = targetPos - hrp.Position
            if delta.Magnitude > 1 then hrp.AssemblyLinearVelocity = delta.Unit * Config.flySpeed end
        else
            hrp.CFrame = CFrame.new(targetPos)
        end
        if Config.canHit and (hrp.Position - nape.Position).Magnitude <= 1520 then
            Config.canHit = false
            task.spawn(function()
                local post = Data.POST
                local count = Config.hitAll and #targetList or math.min(Config.multiHit, #targetList)
                for i = 1, count do
                    local n = targetList[i]
                    if n and n.Parent then
                        if post then
                            post:FireServer("Hitboxes", "Register", n, math.random(200, 300), math.random(20, 30) / 100)
                            post:FireServer("Attacks", "Slash", true)
                        end
                        local id = tostring(n:GetDebugId())
                        if not Data.notified[id] then
                            Data.notified[id] = true
                            Config.titanKillCount = Config.titanKillCount + 1
                            showKillNotification(Config.titanKillCount)
                        end
                    end
                end
                if Config.onKillBurst then task.spawn(Config.onKillBurst) end
                task.wait(Config.hitCooldown)
                Config.canHit = true
            end)
        end
    end)
end

--//==============================\\--
--||   👑 REFILL / RELOAD SYSTEM  ||--
--\\==============================//--

local BladeUI_S2       = nil
local Gradient_S2      = nil
local SetsLabel_S2     = nil
local autoBladeRunning = false

pcall(function()
    BladeUI_S2    = player.PlayerGui.Interface.HUD.Main.Top["7"].Blades
    Gradient_S2   = BladeUI_S2.Inner.Bar.Gradient
    SetsLabel_S2  = BladeUI_S2.Sets
end)

local function TweenTo_S2(cf, speed)
    local charRef = player.Character if not charRef then return end
    local hrpRef  = charRef:FindFirstChild("HumanoidRootPart")
    local humRef  = charRef:FindFirstChild("Humanoid")
    if not hrpRef or not humRef or humRef.Health <= 0 then return end
    local distance = (hrpRef.Position - cf.Position).Magnitude
    local t        = distance / speed
    local tween    = TweenService:Create(hrpRef, TweenInfo.new(t, Enum.EasingStyle.Linear), {CFrame = cf})
    tween:Play()
    return tween
end

local refillParts, refillScanAt = nil, 0

local function FindRefillPart()
    -- scan the whole workspace once, then only re-check the cached parts
    local stale = os.clock() - refillScanAt
    if not refillParts or stale > 30 or (#refillParts == 0 and stale > 3) then
        refillParts = {}
        for _, v in pairs(workspace:GetDescendants()) do
            if v:IsA("BasePart") then
                local name = v.Name:lower()
                if name:find("refill") or name:find("fill") then
                    refillParts[#refillParts + 1] = v
                end
            end
        end
        refillScanAt = os.clock()
    end
    for _, v in ipairs(refillParts) do
        if v.Parent then
            local display = v:FindFirstChild("Display")
            if display then
                local ok, title = pcall(function() return display.Main.Top.Title.Text end)
                if ok and title ~= "REFILLS: 0 / 3 [R]" then return v end
            end
        end
    end
    return nil
end

local function Refill_S2()
    local refillPart = FindRefillPart()
    if not refillPart then return end
    TweenTo_S2(refillPart.CFrame, 6000)
    pcall(function()
        ReplicatedStorage.Assets.Remotes.POST:FireServer("Attacks", "Reload", refillPart)
    end)
end

local function ChangeBlade_S2()
    pcall(function()
        ReplicatedStorage.Assets.Remotes.GET:InvokeServer("Blades", "Reload")
    end)
end

local function CheckBlade_S2()
    if not Gradient_S2 then return false end
    local x = Gradient_S2.Offset.X
    if x < 0 then
        local bladeOk = false
        pcall(function()
            local rig = workspace.Characters[player.Name]["Rig_" .. player.Name]
            local blade = rig.LeftHand.Blade_1
            if blade.Transparency == 0 then bladeOk = true end
        end)
        if bladeOk then return false end
        if SetsLabel_S2 and SetsLabel_S2.Text == "0 / 3" then
            Refill_S2()
        else
            ChangeBlade_S2()
        end
        return true
    end
    return false
end

if Gradient_S2 then
    Gradient_S2:GetPropertyChangedSignal("Offset"):Connect(function()
        if autoBladeRunning then CheckBlade_S2() end
    end)
end

local bladeLoopToken = 0
local function StartBladeLoop()
    if game.PlaceId == 14916516914 then autoBladeRunning = false return end -- no blade refill in the Lobby
    bladeLoopToken = bladeLoopToken + 1
    local my = bladeLoopToken
    autoBladeRunning = true
    task.spawn(function()
        while autoBladeRunning and bladeLoopToken == my do
            CheckBlade_S2()
            task.wait(0.2)
        end
    end)
end

-- Lobby: farm toggles start OFF here (they only make sense inside a mission)
local IN_LOBBY = (game.PlaceId == 14916516914)

Tabs.Main:AddSection("Auto Farm")

local BladeToggle = Tabs.Main:AddToggle("AutoBladeReload", {
    Title = "Auto Reload / Refill Blades",
    Description = "Switches blade sets automatically; teleports to refill station when all sets are empty",
    Default = not IN_LOBBY,
    Callback = function(state)
        if state then
            StartBladeLoop()
        else
            autoBladeRunning = false
            bladeLoopToken = bladeLoopToken + 1
        end
    end
})
-- callbacks don't fire on creation, so start it for the default-on state
if BladeToggle.Value then StartBladeLoop() end

--//==============================\\--
--||        👑 AUTO CLICK M1       ||--
--\\==============================//--

local autoM1Running = false
local autoM1Token   = 0
local M1_DELAY       = 0.25
local M1Toggle

local RESULT_TITLES_M1 = { ["MISSION COMPLETED"] = true, ["RAID COMPLETED"] = true }

local function GuiVisibleM1(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return true
end

local function MissionCompleted()
    local ok, res = pcall(function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return false end
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                t = t:gsub("^%s+", ""):gsub("%s+$", "")
                if RESULT_TITLES_M1[t:upper()] and GuiVisibleM1(d) then return true end
            end
        end
        return false
    end)
    return ok and res
end

--//==============================\\--
--||     SLOW LAND AFTER MISSION  ||--
--\\==============================//--

Config.missionDone = false
Config.landSpeed   = 15   -- studs per second (lower = slower)

do
    local landed = false

    -- watch for the MISSION / RAID COMPLETED screen (polled, not every frame)
    task.spawn(function()
        while true do
            local done = MissionCompleted()
            if done and not Config.missionDone then
                Config.missionDone = true
                landed = false
            elseif not done and Config.missionDone then
                Config.missionDone = false  -- new mission / retry: farm resumes
                killStartAt = os.clock() + Config.baseStartDelay + Config.startDelay
                landed = false
            end
            task.wait(0.5)
        end
    end)

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true

    RunService.Heartbeat:Connect(function(dt)
        if not Config.missionDone or landed then return end
        local char = player.Character
        local hrp  = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not hrp or not hum or hum.Health <= 0 then return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local hit = workspace:Raycast(hrp.Position, Vector3.new(0, -5000, 0), rayParams)
        if not hit then landed = true return end -- nothing below: let normal physics take over

        -- stand height = ground + hip height + half the root part (never lower than this = no clipping)
        local standY = hit.Position.Y + hum.HipHeight + hrp.Size.Y / 2 + 0.2
        local y = hrp.Position.Y

        hrp.AssemblyLinearVelocity  = Vector3.zero
        hrp.AssemblyAngularVelocity = Vector3.zero

        if y <= standY + 0.3 then
            landed = true
            return
        end

        local newY = math.max(standY, y - Config.landSpeed * dt)
        local pos  = hrp.Position
        hrp.CFrame = CFrame.new(pos.X, newY, pos.Z) * (hrp.CFrame - hrp.CFrame.Position)
    end)
end

local cachedAttackBtn
local function FindAttackButton()
    if cachedAttackBtn and cachedAttackBtn.Parent and cachedAttackBtn.Visible then return cachedAttackBtn end
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return nil end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiButton") and d.Visible then
            local n = d.Name:lower()
            if n == "attack" or n == "m1" or n == "slash" then cachedAttackBtn = d return d end
        end
    end
    return nil
end

local function ClickM1()
    -- real mouse click in the screen centre (M1)
    pcall(function()
        local cam = workspace.CurrentCamera
        local size = cam and cam.ViewportSize or Vector2.new(800, 600)
        local x, y = size.X / 2, size.Y / 2
        VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0)
        task.wait(0.03)
        VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0)
    end)
    -- on-screen attack button (mobile layout), if one exists
    pcall(function()
        local btn = FindAttackButton()
        if btn then
            if firesignal then
                firesignal(btn.MouseButton1Down)
                firesignal(btn.MouseButton1Up)
                firesignal(btn.MouseButton1Click)
                firesignal(btn.Activated)
            else
                local pos, sz = btn.AbsolutePosition, btn.AbsoluteSize
                local inset = GuiService:GetGuiInset()
                local cx, cy = pos.X + sz.X / 2, pos.Y + sz.Y / 2 + inset.Y
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, true, game, 0)
                task.wait(0.03)
                VirtualInput:SendMouseButtonEvent(cx, cy, 0, false, game, 0)
            end
        end
    end)
end

-- M1 no longer spams on its own: it only clicks when Auto Kill actually fires a hit burst
local M1Enabled = true
local lastM1 = 0

Config.onKillBurst = function()
    if not M1Enabled then return end
    if os.clock() - lastM1 < M1_DELAY then return end
    lastM1 = os.clock()
    ClickM1()
end

M1Toggle = Tabs.Main:AddToggle("AutoClickM1", {
    Title = "Auto Click M1 (only while killing)",
    Description = "Clicks M1 only when Auto Kill is hitting titans. Follows the Auto Kill switch",
    Default = not IN_LOBBY,
    Callback = function(state)
        M1Enabled = state and true or false
    end
})
if M1Toggle and M1Toggle.Value ~= nil then M1Enabled = M1Toggle.Value and true or false end

Tabs.Main:AddSlider("M1ClickDelay", {
    Title = "M1 Click Delay (seconds)",
    Description = "Time between M1 clicks. Clicks only fire with Auto Kill bursts, so the real floor is the burst cooldown (~0.12s)",
    Default = M1_DELAY,
    Min = 0.05,
    Max = 2,
    Rounding = 2,
    Callback = function(v) M1_DELAY = tonumber(v) or M1_DELAY end,
})

local KillToggle = Tabs.Main:AddToggle("AutoKillTitans", {
    Title = "Auto Kill Titans",
    Description = "Don't Finish the mission under 17 sec",
    Default = not IN_LOBBY,
    Callback = function(state)
        Config.isFlying = state
        if state then task.spawn(killFromAbove) end
        -- M1 setting turns on/off together with Auto Kill
        if M1Toggle and M1Toggle.SetValue then pcall(function() M1Toggle:SetValue(state and true or false) end) end
    end
})
if KillToggle.Value then Config.isFlying = true task.spawn(killFromAbove) end

--//==============================\\--
--||   SMOOTH CAMERA WHILE FARMING ||--
--\\==============================//--
-- Keeps your camera angle fixed and only glides the camera position after
-- you, so the view doesn't whip around when Auto Kill teleports you.

Config.lockCamera = true

do
    local SMOOTHNESS = 10      -- higher = camera catches up faster
    local locked, savedType, savedRot, dist = false, nil, nil, 20

    local function farming()
        return Config.lockCamera and Config.isFlying and not Config.missionDone
            and os.clock() >= killStartAt
    end

    RunService:BindToRenderStep("AotrSmoothCam", Enum.RenderPriority.Camera.Value + 1, function(dt)
        local cam = workspace.CurrentCamera
        local root = Player.hrp
        if not cam then return end

        if farming() and root and root.Parent then
            if not locked then
                locked    = true
                savedType = cam.CameraType
                savedRot  = cam.CFrame.Rotation
                dist      = math.clamp((cam.CFrame.Position - root.Position).Magnitude, 8, 40)
                cam.CameraType = Enum.CameraType.Scriptable
            end
            local goal  = root.Position - savedRot.LookVector * dist
            local alpha = 1 - math.exp(-SMOOTHNESS * dt)
            cam.CFrame  = CFrame.new(cam.CFrame.Position:Lerp(goal, alpha)) * savedRot
        elseif locked then
            locked = false
            cam.CameraType = savedType or Enum.CameraType.Custom
        end
    end)
end

Tabs.Main:AddToggle("SmoothCameraLock", {
    Title = "Smooth Camera While Farming",
    Description = "Keeps the camera angle steady and follows you smoothly instead of snapping around",
    Default = not IN_LOBBY,
    Callback = function(state) Config.lockCamera = state and true or false end
})

Tabs.Main:AddDropdown("MoveMode", {
    Title = "Movement Mode",
    Values = {"Teleportation", "Gliding"},
    Default = 1,
    Callback = function(option) Config.moveMode = option end
})

Tabs.Main:AddSlider("StartDelaySlider", {
    Title = "Farm Delay",
    Description = "Extra seconds added on top of the fixed 5 second start delay",
    Default = 0,
    Min = 0,
    Max = 50,
    Rounding = 0,
    Callback = function(value) Config.startDelay = value end
})

Tabs.Main:AddSlider("LandSpeedSlider", {
    Title = "Landing Speed (after mission)",
    Description = "How slowly you descend once the mission is complete",
    Default = 15,
    Min = 5,
    Max = 60,
    Rounding = 0,
    Callback = function(value) Config.landSpeed = value end
})

Tabs.Main:AddSlider("FlySpeedSlider", {
    Title = "Gliding Speed",
    Default = 300,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.flySpeed = value end
})

Tabs.Main:AddSlider("FlyHeightSlider", {
    Title = "Float Height",
    Default = 250,
    Min = 50,
    Max = 300,
    Rounding = 0,
    Callback = function(value) Config.flyHeight = value end
})

Tabs.Main:AddSlider("HitSpeedSlider", {
    Title = "Hit Interval (ms) - lower = faster",
    Default = 120,
    Min = 50,
    Max = 500,
    Rounding = 0,
    Callback = function(value) Config.hitCooldown = value / 1000 end
})

Tabs.Main:AddSlider("MultiHitSlider", {
    Title = "Titans Hit Per Burst",
    Default = 8,
    Min = 1,
    Max = 20,
    Rounding = 0,
    Callback = function(value) Config.multiHit = value end
})

Tabs.Main:AddToggle("HitAllTitans", {
    Title = "Hit All Titans At Once",
    Description = "Every alive titan gets hit in the same burst (ignores Titans Hit Per Burst)",
    Default = false,
    Callback = function(state) Config.hitAll = state end
})

local _Remotes = game:GetService("ReplicatedStorage").Assets.Remotes
local GET, POST = _Remotes.GET, _Remotes.POST

--//==============================\\--
--||        👑 AUTO Retry         ||--
--\\==============================//--

local VIM = game:GetService("VirtualInputManager")

local interface = player:FindFirstChild("PlayerGui")
    and player.PlayerGui:FindFirstChild("Interface")

local rewards     = interface and interface:FindFirstChild("Rewards")
local rewardsMain = rewards and rewards:FindFirstChild("Main")
local retryBtn    = rewardsMain
    and rewardsMain:FindFirstChild("Info")
    and rewardsMain.Info:FindFirstChild("Main")
    and rewardsMain.Info.Main:FindFirstChild("Buttons")
    and rewardsMain.Info.Main.Buttons:FindFirstChild("Retry")

local autoRetryEnabled = false

local function showDebugDot(x, y)
    local dot = Instance.new("Frame")
    dot.Size = UDim2.new(0, 10, 0, 10)
    dot.Position = UDim2.new(0, x - 5, 0, y - 5)
    dot.BackgroundColor3 = Color3.new(1, 0, 0)
    dot.BorderSizePixel = 0
    dot.ZIndex = 10000
    dot.Name = "DebugDot"
    pcall(function() dot.Parent = game:GetService("CoreGui") end)
    game:GetService("Debris"):AddItem(dot, 2)
end

local function Retryshi()
    local pos  = retryBtn.AbsolutePosition
    local size = retryBtn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2 + 20
    local y
    if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
        y = pos.Y + size.Y / 2 + 60
    else
        y = pos.Y + size.Y / 2 + inset.Y
    end
    showDebugDot(x, y)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
end

local function shouldClickRetry()
    return retryBtn
        and rewards and rewards.Visible
        and rewardsMain and rewardsMain.Visible
        and retryBtn.Visible
        and retryBtn.AbsoluteSize.Magnitude > 10
end

task.spawn(function()
    while true do
        if autoRetryEnabled and shouldClickRetry() then
            task.wait(0.3)
            if shouldClickRetry() then
                Retryshi()
                task.wait(2)
            end
        end
        task.wait(0.25)
    end
end)

Tabs.Main:AddSection("Utilities")

Tabs.Main:AddToggle("AutoRetryToggle", {
    Title = "Auto Retry",
    Default = false,
    Callback = function(state) autoRetryEnabled = state end
})

--//==============================\\--
--||     AUTO SKIP CUTSCENES      ||--
--\\==============================//--

do
local autoSkipRunning = false
local autoSkipToken   = 0
local skipState       = setmetatable({}, { __mode = "k" }) -- [target] = { last = clock, tries = n }

local function Clean(s)
    return (tostring(s or ""):gsub("<[^>]->", ""):lower())
end

-- visible = every parent visible/enabled, has a real size and sits on screen
local function ShownOnScreen(obj)
    local cur = obj
    while cur and cur ~= game do
        if cur:IsA("GuiObject") then
            if not cur.Visible then return false end
            if cur:IsA("CanvasGroup") and cur.GroupTransparency >= 0.99 then return false end
        elseif cur:IsA("ScreenGui") then
            if not cur.Enabled then return false end
        end
        cur = cur.Parent
    end
    if not obj:IsA("GuiObject") then return false end
    local sz, pos = obj.AbsoluteSize, obj.AbsolutePosition
    if sz.X < 2 or sz.Y < 2 then return false end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(800, 600)
    return pos.X + sz.X > 0 and pos.Y + sz.Y > 0 and pos.X < vp.X and pos.Y < vp.Y
end

-- anything called "Skip", or a short label/button whose text says skip
local function IsSkipObject(obj)
    if obj.Name:lower():find("skip", 1, true) then return true end
    if obj:IsA("TextButton") or obj:IsA("TextLabel") then
        local t = Clean(obj.Text)
        if #t <= 40 and t:find("skip", 1, true) then return true end
    end
    return false
end

-- the thing we actually press: the button itself, a button around it, or a button inside it
local function ResolveTarget(obj)
    if obj:IsA("GuiButton") then return obj end
    local up = obj.Parent
    for _ = 1, 3 do
        if up and up:IsA("GuiButton") then return up end
        up = up and up.Parent
    end
    for _, c in ipairs(obj:GetDescendants()) do
        if c:IsA("GuiButton") and ShownOnScreen(c) then return c end
    end
    return obj
end

-- method 1: fire the button's own signals
local function SignalPress(btn)
    if getconnections then
        for _, sig in ipairs({ btn.Activated, btn.MouseButton1Down, btn.MouseButton1Up, btn.MouseButton1Click }) do
            local ok, conns = pcall(getconnections, sig)
            if ok and type(conns) == "table" then
                for _, c in ipairs(conns) do
                    local fired = pcall(function() c:Fire() end)
                    -- some executors only run the handler through .Function
                    if not fired then pcall(function() c.Function() end) end
                end
            end
        end
    end
    if firesignal then
        pcall(firesignal, btn.Activated)
        pcall(firesignal, btn.MouseButton1Click)
    end
end

-- method 2: a real mouse + touch tap in the middle of the button
local function ClickCenter(obj)
    local pos, sz = obj.AbsolutePosition, obj.AbsoluteSize
    local sg = obj:FindFirstAncestorWhichIsA("ScreenGui")
    local inset = (sg and sg.IgnoreGuiInset) and Vector2.new(0, 0) or GuiService:GetGuiInset()
    local x = pos.X + sz.X / 2 + inset.X
    local y = pos.Y + sz.Y / 2 + inset.Y
    pcall(function() VirtualInput:SendMouseMoveEvent(x, y, game) end)
    task.wait(0.05)
    pcall(function() VirtualInput:SendMouseButtonEvent(x, y, 0, true, game, 0) end)
    task.wait(0.05)
    pcall(function() VirtualInput:SendMouseButtonEvent(x, y, 0, false, game, 0) end)
    pcall(function() VirtualInput:SendTouchEvent(1, 0, x, y) end)
    task.wait(0.05)
    pcall(function() VirtualInput:SendTouchEvent(1, 2, x, y) end)
end

-- method 3: select the button and hit Enter
local function SelectPress(obj)
    pcall(function()
        GuiService.SelectedObject = obj
        task.wait(0.05)
        VirtualInput:SendKeyEvent(true, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        VirtualInput:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
        task.wait(0.05)
        GuiService.SelectedObject = nil
    end)
end

-- hint like "[F] Skip", "Press SPACE to skip" or "Hold E to skip" -> that key
local function KeyFromHint(obj)
    local nodes = { obj }
    local up = obj.Parent
    if up then nodes[#nodes + 1] = up end
    for _, n in ipairs(nodes) do
        for _, d in ipairs(n:GetDescendants()) do
            if d:IsA("TextLabel") or d:IsA("TextButton") then
                local t = tostring(d.Text or ""):gsub("<[^>]->", "")
                if t:lower():find("skip", 1, true) or d == obj then
                    local k = t:match("%[(%w+)%]") or t:lower():match("press%s+(%w+)") or t:lower():match("hold%s+(%w+)")
                    if k then
                        local ok, code = pcall(function() return Enum.KeyCode[k:upper()] or Enum.KeyCode[k] end)
                        if ok and code then return code end
                    end
                end
            end
        end
    end
    return nil
end

local function HoldKey(code, secs)
    pcall(function()
        VirtualInput:SendKeyEvent(true, code, false, game)
        task.wait(secs or 0.25)
        VirtualInput:SendKeyEvent(false, code, false, game)
    end)
end

-- if the skip button is still on screen after an attempt, the next attempt uses a different method
local function TrySkip(target)
    local st = skipState[target]
    if not st then st = { last = 0, tries = 0 } skipState[target] = st end
    if os.clock() - st.last < 1.2 then return false end
    if os.clock() - st.last > 10 then st.tries = 0 end
    st.last = os.clock()
    st.tries += 1
    local hint = KeyFromHint(target)
    if hint then HoldKey(hint, st.tries > 1 and 1.2 or 0.25) end
    local m = (st.tries - 1) % 3
    if m == 0 then
        if target:IsA("GuiButton") then SignalPress(target) end
        task.wait(0.25)
        if target.Parent and ShownOnScreen(target) then ClickCenter(target) end -- signals did nothing -> real tap
    elseif m == 1 then
        ClickCenter(target)
    else
        SelectPress(target)
    end
    return true
end

local function SkipCutscenesOnce()
    local pg = player:FindFirstChild("PlayerGui")
    if not pg then return end
    for _, d in ipairs(pg:GetDescendants()) do
        if d:IsA("GuiObject") and IsSkipObject(d) and ShownOnScreen(d) then
            local target = ResolveTarget(d)
            if ShownOnScreen(target) and TrySkip(target) then return end
        end
    end
end

local function StartSkipLoop()
    autoSkipToken += 1
    local my = autoSkipToken
    autoSkipRunning = true
    task.spawn(function()
        while autoSkipRunning and autoSkipToken == my do
            pcall(SkipCutscenesOnce)
            task.wait(0.3)
        end
    end)
end

Tabs.Main:AddButton({
    Title = "Debug: print Skip buttons",
    Description = "Press while a cutscene is playing. Lists every skip-like object (path, class, visible) in the console (F9).",
    Callback = function()
        local pg = player:FindFirstChild("PlayerGui")
        if not pg then return end
        local n = 0
        for _, d in ipairs(pg:GetDescendants()) do
            if d:IsA("GuiObject") and IsSkipObject(d) then
                n += 1
                print(("[Aotr:update5] skip? %s [%s] visible=%s onscreen=%s"):format(
                    d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", ""), d.ClassName, tostring(d.Visible), tostring(ShownOnScreen(d))))
            end
        end
        Notifier:Notify({ Title = "Skip debug", Content = n .. " skip-like objects printed to console", Duration = 4 })
    end
})

local SkipToggle = Tabs.Main:AddToggle("AutoSkipCutscenes", {
    Title = "Auto Skip Cutscenes",
    Description = "Presses the Skip button as soon as a cutscene shows one (retries with different methods if it doesn't go away)",
    Default = true,
    Callback = function(state)
        if state then
            StartSkipLoop()
        else
            autoSkipRunning = false
            autoSkipToken += 1
        end
    end
})
if SkipToggle.Value then StartSkipLoop() end
end

--//==============================\\--
--||        👑 AUTO Escape        ||--
--\\==============================//--

local escapeRunning    = false
local escapeThread     = nil
local cleanGUIThread   = nil
local lastEscapeButton = nil

Tabs.Main:AddToggle("Escape", {
    Title = "Auto Escape",
    Default = false,
    Callback = function(Value)
        escapeRunning = Value
        if not Value then lastEscapeButton = nil return end
        escapeThread = task.spawn(function()
            local pg = player:WaitForChild("PlayerGui")
            while escapeRunning do
                local iface   = pg:FindFirstChild("Interface")
                local buttons = iface and iface:FindFirstChild("Buttons")
                if buttons then
                    local list = buttons:GetChildren()
                    if #list > 0 then
                        POST:FireServer("Attacks", "Slash_Escape")
                        for _, b in ipairs(list) do b:Destroy() end
                    end
                end
                task.wait(0.05)
            end
        end)
    end
})

--//==============================\\--
--||         👑 Auto Roll         ||--
--\\==============================//--

local CLICK_DELAY = 0.2
local WAIT_DELAY  = 1
local ENABLED     = false

local function canClick(btn)
    return btn and btn.Visible and btn.AbsoluteSize.Magnitude > 10
end

local function isActuallyVisible(obj)
    if not obj then return false end
    local current = obj
    local Gui = player:WaitForChild("PlayerGui")
    while current and current ~= Gui do
        local success3, result3 = pcall(function() return current.Visible end)
        if success3 and not result3 then return false end
        current = current.Parent
    end
    return obj.AbsoluteSize.Magnitude > 10
end

local function clickButton(btn)
    if not btn then return false end
    local pos  = btn.AbsolutePosition
    local size = btn.AbsoluteSize
    local inset = GuiService:GetGuiInset()
    local x = pos.X + size.X / 2
    local y = pos.Y + size.Y / 2 + inset.Y
    VIM:SendMouseMoveEvent(x, y, game)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, true, game, 0)
    task.wait(0.05)
    VIM:SendMouseButtonEvent(x, y, 0, false, game, 0)
    return true
end

local function findButton(parent, buttonName)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj.Name == buttonName and obj:IsA("GuiButton") then return obj end
        for _, child in pairs(obj:GetChildren()) do
            local result4 = searchRecursive(child)
            if result4 then return result4 end
        end
        return nil
    end
    return searchRecursive(parent)
end

local function findButtonByText(parent, text)
    if not parent then return nil end
    local function searchRecursive(obj)
        if obj:IsA("GuiButton") or obj:IsA("TextButton") then
            local hasText = obj:FindFirstChild("Text") or obj.Text
            if hasText and string.find(string.lower(tostring(hasText)), string.lower(text)) then return obj end
        end
        for _, child in pairs(obj:GetChildren()) do
            local result5 = searchRecursive(child)
            if result5 then return result5 end
        end
        return nil
    end
    return searchRecursive(parent)
end

task.spawn(function()
    local Gui = player:WaitForChild("PlayerGui")
    local interface2 = Gui:WaitForChild("Interface", 10)
    if not interface2 then return end
    local rollButton = nil
    local searchPaths = {"Customisation.Family.Buttons_2.Roll", "Roll", "RollButton"}
    for _, path in pairs(searchPaths) do
        local pathParts = string.split(path, ".")
        local current = interface2
        for _, part in pairs(pathParts) do
            if current then current = current:FindFirstChild(part) end
        end
        if current and current:IsA("GuiButton") then rollButton = current break end
    end
    if not rollButton then rollButton = findButton(interface2, "Roll") end
    if not rollButton then rollButton = findButtonByText(interface2, "roll") end
    if not rollButton then return end
    while true do
        if ENABLED then
            if canClick(rollButton) and isActuallyVisible(rollButton) then
                clickButton(rollButton)
                task.wait(CLICK_DELAY)
            else task.wait(WAIT_DELAY) end
        else task.wait(1) end
    end
end)

--//==============================\\--
--||        AUTO JOIN TAB         ||--
--\\==============================//--

local Difficulties      = {"Best For You","Easy","Normal","Hard","Severe","Aberrant"}
local DifficultiesRaids = {"Best For You","Hard","Severe","Aberrant"}
local ModifiersList     = {"No Perks","No Skills","No Memories","Nightmare","Oddball","Injury Prone","Chronic Injuries","Fog","Glass Cannon","Time Trial","Boring","Simple"}
local MissionMaps       = {"Shiganshina","Trost","Outskirts","Forest","Utgard","Docks","Stohess","Chapel"}
local MissionObjectives = {
    ["Shiganshina"]={"Skirmish","Breach","Random"},
    ["Trost"]      ={"Skirmish","Protect","Random"},
    ["Outskirts"]  ={"Skirmish","Escort","Random"},
    ["Forest"]     ={"Skirmish","Guard","Random"},
    ["Utgard"]     ={"Skirmish","Defend","Random"},
    ["Docks"]      ={"Skirmish","Stall","Random"},
    ["Stohess"]    ={"Skirmish","Random"},
    ["Chapel"]     ={"Skirmish","Random"},
}
local RaidMaps      = {"Shiganshina","Trost","Stohess"}
local RaidObjectives= {["Shiganshina"]={"Armored Titan","Colossal Titan"},["Trost"]={"Attack Titan"},["Stohess"]={"Female Titan"}}
local WaveMaps      = {"Trost"}

_G.AJ = {
    SelectMissionMap        = MissionMaps[1],
    SelectMissionObjective  = MissionObjectives[MissionMaps[1]][1],
    SelectMissionDifficulty = "Easy",
    SelectMissionModifiers  = {},
    SelectRaidMap           = RaidMaps[1],
    SelectRaidObjective     = RaidObjectives[RaidMaps[1]][1],
    SelectRaidDifficulty    = "Hard",  -- "Easy" is not a raid difficulty, raids never started with it
    ModifierFormat          = "Dictionary",
    SelectRaidModifiers     = {},
    SelectWaveMap           = WaveMaps[1],
    AutoJoinMission         = false,
    AutoJoinMissionBoost    = false,
    AutoJoinRaid            = false,
    AutoJoinWaves           = false,
}

local function PressButton(d)
    game:GetService("GuiService").SelectedObject = d
    VIM:SendKeyEvent(true,  Enum.KeyCode.Return, false, game)
    task.wait(0.05)
    VIM:SendKeyEvent(false, Enum.KeyCode.Return, false, game)
end


-- Turns the dropdown's {Name = true} table into exactly what the server gets:
-- only selected + valid modifiers, in a stable order, as a dictionary or a list.
local function FormatModifiers(raw)
    local picked = {}
    if type(raw) == "table" then
        for k, v in pairs(raw) do
            if type(k) == "number" and type(v) == "string" then picked[v] = true
            elseif type(k) == "string" and v then picked[k] = true end
        end
    end
    local list, dict = {}, {}
    for _, name in ipairs(ModifiersList) do
        if picked[name] then list[#list + 1] = name dict[name] = true end
    end
    return (_G.AJ and _G.AJ.ModifierFormat == "List") and list or dict
end

local function CreateAndStart(data)
    data.Modifiers = FormatModifiers(data.Modifiers)
    if game.PlaceId == 14916516914 then
        local ok, res = pcall(function() return GET:InvokeServer("S_Missions","Create",data) end)
        if ok and typeof(res) == "Instance" then
            task.wait(1)
            pcall(function() return GET:InvokeServer("S_Missions","Start") end)
            return true
        end
        return false
    end
end

-- Mission section
Tabs.AutoJoin:AddSection("Auto Join Missions")

local MissionObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_MissionMap", {
    Title = "Select Map",
    Values = MissionMaps,
    Default = _G.AJ.SelectMissionMap,
    Callback = function(v)
        _G.AJ.SelectMissionMap = v
        local objs = MissionObjectives[v]
        if objs then _G.AJ.SelectMissionObjective = objs[1] end
        if MissionObjectiveDropdown2 then
            MissionObjectiveDropdown2:SetValues(MissionObjectives[v] or {})
            pcall(function() MissionObjectiveDropdown2:SetValue(_G.AJ.SelectMissionObjective) end)
        end
    end
})

MissionObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_MissionObjective", {
    Title = "Select Objective",
    Values = MissionObjectives[_G.AJ.SelectMissionMap] or {},
    Default = _G.AJ.SelectMissionObjective,
    Callback = function(v) _G.AJ.SelectMissionObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionDifficulty", {
    Title = "Select Difficulty",
    Values = Difficulties,
    Default = _G.AJ.SelectMissionDifficulty,
    Callback = function(v) _G.AJ.SelectMissionDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_MissionModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectMissionModifiers,
    Callback = function(v) _G.AJ.SelectMissionModifiers = v end
})

Tabs.AutoJoin:AddDropdown("AJ_ModifierFormat", {
    Title = "Modifier Format",
    Description = "If modifiers don't apply in the lobby, switch this to List",
    Values = {"Dictionary", "List"},
    Default = "Dictionary",
    Callback = function(v) _G.AJ.ModifierFormat = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMission", {
    Title = "Auto Join Mission",
    Description = "Automatically joins missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMission = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission then
            CreateAndStart({Name=_G.AJ.SelectMissionMap,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=_G.AJ.SelectMissionObjective,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

Tabs.AutoJoin:AddToggle("AJ_AutoJoinMissionBoost", {
    Title = "Auto Join Mission (Rewards Boost)",
    Description = "Automatically joins boosted missions",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinMissionBoost = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMissionBoost then
            local boosted = game:GetService("Workspace"):GetAttribute("Boosted_Map")
            local obj = _G.AJ.SelectMissionObjective
            local valid = MissionObjectives[boosted]
            if valid and not table.find(valid, obj) then obj = valid[1] end -- objective must exist on the boosted map
            CreateAndStart({Name=boosted,Type="Missions",Difficulty=_G.AJ.SelectMissionDifficulty,Objective=obj,Modifiers=_G.AJ.SelectMissionModifiers,Limit=8})
        end
    end
end)

-- Raids section
Tabs.AutoJoin:AddSection("Auto Join Raids")

local RaidObjectiveDropdown2

Tabs.AutoJoin:AddDropdown("AJ_RaidMap", {
    Title = "Select Raid Map",
    Values = RaidMaps,
    Default = _G.AJ.SelectRaidMap,
    Callback = function(v)
        _G.AJ.SelectRaidMap = v
        local objs = RaidObjectives[v]
        if objs then _G.AJ.SelectRaidObjective = objs[1] end
        if RaidObjectiveDropdown2 then
            RaidObjectiveDropdown2:SetValues(RaidObjectives[v] or {})
            pcall(function() RaidObjectiveDropdown2:SetValue(_G.AJ.SelectRaidObjective) end)
        end
    end
})

RaidObjectiveDropdown2 = Tabs.AutoJoin:AddDropdown("AJ_RaidObjective", {
    Title = "Select Raid Boss",
    Values = RaidObjectives[_G.AJ.SelectRaidMap] or {},
    Default = _G.AJ.SelectRaidObjective,
    Callback = function(v) _G.AJ.SelectRaidObjective = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidDifficulty", {
    Title = "Select Difficulty",
    Values = DifficultiesRaids,
    Default = _G.AJ.SelectRaidDifficulty,
    Callback = function(v) _G.AJ.SelectRaidDifficulty = v end
})

Tabs.AutoJoin:AddDropdown("AJ_RaidModifiers", {
    Title = "Select Modifiers",
    Values = ModifiersList,
    Multi = true,
    Default = _G.AJ.SelectRaidModifiers,
    Callback = function(v) _G.AJ.SelectRaidModifiers = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinRaid", {
    Title = "Auto Join Raid",
    Description = "Automatically joins raids",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinRaid = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinRaid then
            CreateAndStart({Name=_G.AJ.SelectRaidMap,Type="Raids",Difficulty=_G.AJ.SelectRaidDifficulty,Objective=_G.AJ.SelectRaidObjective,Modifiers=_G.AJ.SelectRaidModifiers,Limit=8})
        end
    end
end)

-- Waves section
Tabs.AutoJoin:AddSection("Auto Join Waves")

Tabs.AutoJoin:AddDropdown("AJ_WaveMap", {
    Title = "Select Wave Map",
    Values = WaveMaps,
    Default = _G.AJ.SelectWaveMap,
    Callback = function(v) _G.AJ.SelectWaveMap = v end
})

Tabs.AutoJoin:AddToggle("AJ_AutoJoinWaves", {
    Title = "Auto Join Waves",
    Description = "Automatically joins waves",
    Default = false,
    Callback = function(v) _G.AJ.AutoJoinWaves = v end
})

task.spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinWaves then
            CreateAndStart({Name=_G.AJ.SelectWaveMap,Type="Waves",Difficulty="Easy",Objective="Waves",Limit=8})
        end
    end
end)

-- Leave wrong mission auto-correct
spawn(function()
    while task.wait(0.1) do
        if _G.AJ.AutoJoinMission or _G.AJ.AutoJoinMissionBoost or _G.AJ.AutoJoinRaid or _G.AJ.AutoJoinWaves then
            for _, v in pairs(game:GetService("ReplicatedStorage").Missions:GetChildren()) do
                if v.Leader.Value == player.Name then
                    local Target = nil
                    if _G.AJ.AutoJoinMission then Target = _G.AJ.SelectMissionMap
                    elseif _G.AJ.AutoJoinMissionBoost then Target = game:GetService("Workspace"):GetAttribute("Boosted_Map")
                    elseif _G.AJ.AutoJoinRaid then Target = _G.AJ.SelectRaidMap
                    elseif _G.AJ.AutoJoinWaves then Target = _G.AJ.SelectWaveMap end
                    if v.Name ~= Target then
                        GET:InvokeServer("S_Missions","Leave")
                    end
                end
            end
        end
    end
end)

--//==============================\\--
--||        SERVERS TAB           ||--
--\\==============================//--

local TPS = TeleportService

Tabs.Servers:AddSection("Server")

Tabs.Servers:AddInput("JobIDInput", {
    Title = "JobID",
    Placeholder = "Paste Job ID here",
    Callback = function(x) _G.JobId_Textbox = x end
})

Tabs.Servers:AddToggle("AutoJoinJobID", {
    Title = "Auto Join JobID",
    Default = false,
    Callback = function(v)
        _G.AutoJoinJobID = v
        if v then
            task.spawn(function()
                while _G.AutoJoinJobID do
                    if _G.JobId_Textbox and _G.JobId_Textbox ~= "" then
                        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
                        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
                    else
                        warn("Please enter a JobID before enabling Auto Join JobID")
                        _G.AutoJoinJobID = false break
                    end
                    task.wait(1)
                end
            end)
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Join JobID",
    Callback = function()
        TPS:TeleportToPlaceInstance(game.PlaceId, _G.JobId_Textbox, player)
        Notifier:Notify({ Title="Aotr:update5", Content="Joining JobID... Please wait.", Duration=3 })
    end
})

Tabs.Servers:AddButton({
    Title = "Copy JobID",
    Callback = function()
        setclipboard(game.JobId)
        Notifier:Notify({ Title="Aotr:update5", Content="Copied JobID!", Duration=3 })
    end
})

Tabs.Servers:AddSection("Basic")

Tabs.Servers:AddButton({
    Title = "Rejoin",
    Description = "Re-enter the same server",
    Callback = function() TeleportService:Teleport(game.PlaceId, player) end
})

getgenv().ServerHop = function()
    local url = "https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?sortOrder=Asc&limit=100"
    local data = HttpService:JSONDecode(game:HttpGet(url))
    for _, v in ipairs(data.data or {}) do
        if v.playing < v.maxPlayers then
            TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, Players.LocalPlayer) return
        end
    end
end

Tabs.Servers:AddButton({
    Title = "Server Hop",
    Description = "Move to new server",
    Callback = function() getgenv().ServerHop() end
})

Tabs.Servers:AddSection("Smart Server")

Tabs.Servers:AddSlider("MaxPlayersFilter", {
    Title = "Max Players Filter",
    Min = 1,
    Max = 20,
    Default = 5,
    Rounding = 0,
    Callback = function(v) _G.SetP = v end
})

Tabs.Servers:AddButton({
    Title = "Smart Hop",
    Description = "Find server with fewest players",
    Callback = function()
        local limit = _G.SetP
        local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
        for _, v in ipairs(body.data or {}) do
            if v.playing <= limit then TeleportService:TeleportToPlaceInstance(game.PlaceId, v.id, player) break end
        end
    end
})

Tabs.Servers:AddButton({
    Title = "Low Ping Hop",
    Description = "Find lowest ping server",
    Callback = function()
        pcall(function()
            local bestServer, lowestPing = nil, math.random(50, 200)
            local body = HttpService:JSONDecode(game:HttpGet("https://games.roblox.com/v1/games/"..game.PlaceId.."/servers/Public?limit=100"))
            for _, v in ipairs(body.data or {}) do
                local ping = tonumber(v.ping)
                if ping and ping < lowestPing then lowestPing = ping bestServer = v.id end
            end
            if bestServer then TeleportService:TeleportToPlaceInstance(game.PlaceId, tostring(bestServer), player) end
        end)
    end
})

--//==============================\\--
--||           MISC TAB           ||--
--\\==============================//--

getgenv().AutoHideAfterDelay = false

Tabs.Misc:AddSection("Interface")

Tabs.Misc:AddToggle("AutoHideAfter10s", {
    Title = "Auto Hide UI (5s)",
    Default = false,
    Callback = function(state)
        getgenv().AutoHideAfterDelay = state
        if state then
            task.delay(5, function()
                if not getgenv().AutoHideAfterDelay then return end
                getgenv().AutoHideUI = true
                Window:Minimize(true)
            end)
        end
    end
})

local lastTap = 0
local function toggleUI()
    Window:Minimize()
end

UserInputService.TouchTap:Connect(function(_, gameProcessed)
    if gameProcessed then return end
    local now = tick()
    if now - lastTap <= 0.4 then toggleUI() end
    lastTap = now
end)

Tabs.Misc:AddToggle("ToggleNotifications", {
    Title = "Notifications",
    Default = false,
    Callback = function(value) Config.notificationsEnabled = value end
})

Tabs.Misc:AddSection("Game")

local delaySeconds = 180
local toggleActive = false

Tabs.Misc:AddToggle("ForceRetryToggle", {
    Title = "Fail Safe",
    Default = false,
    Callback = function(state)
        toggleActive = state
        if state then
            task.delay(delaySeconds, function()
                if toggleActive then
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            end)
        end
    end
})

-- Auto Force Retry: fires 15s after the MISSION / RAID COMPLETED screen appears
do
    local AUTO_FORCE_RETRY_DELAY = 15
    local autoForceRetry = true
    Tabs.Misc:AddToggle("AutoForceRetry15", {
        Title = "Auto Force Retry (15s)",
        Description = "Automatically Force Retry 15 seconds after a mission is completed.",
        Default = true,
        Callback = function(state) autoForceRetry = state end
    })
    task.spawn(function()
        local shownAt, fired = nil, false
        while true do
            task.wait(0.5)
            if autoForceRetry and MissionCompleted() then
                shownAt = shownAt or os.clock()
                if not fired and os.clock() - shownAt >= AUTO_FORCE_RETRY_DELAY then
                    fired = true
                    pcall(function() retryRemote:InvokeServer("Functions", "Retry", "Add") end)
                end
            else
                shownAt, fired = nil, false
            end
        end
    end)
end

-- Damage Text
local iface2 = player:WaitForChild("PlayerGui"):WaitForChild("Interface")
local damageConnection

Tabs.Misc:AddToggle("dmg", {
    Title = "Remove Dmg Text",
    Default = false,
    Callback = function(state)
        if state then
            for _, obj in pairs(iface2:GetDescendants()) do
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end
            damageConnection = iface2.DescendantAdded:Connect(function(obj)
                if obj:IsA("TextLabel") and obj.Name == "Number" then obj.Visible = false end
            end)
        else
            if damageConnection then damageConnection:Disconnect() damageConnection = nil end
        end
    end
})

-- Noclip: walk through walls, but the ground stays solid (no sinking into the floor / falling into the void)
do
    local noclipOn      = false
    local noclipChanged = setmetatable({}, { __mode = "k" }) -- parts we turned CanCollide off on
    local lastFloorY    = nil
    local lastSafeCF    = nil -- last position that had real ground right under it
    local lastPos       = nil

    local rayParams = RaycastParams.new()
    rayParams.FilterType = Enum.RaycastFilterType.Exclude
    rayParams.RespectCanCollide = true
    rayParams.IgnoreWater = true

    local function RestoreCollision()
        for part in pairs(noclipChanged) do
            if part and part.Parent then part.CanCollide = true end
            noclipChanged[part] = nil
        end
    end

    -- 1) every physics step: switch off collision on our character
    RunService.Stepped:Connect(function()
        if not noclipOn then return end
        local char = player.Character
        if not char then return end
        for _, p in ipairs(char:GetDescendants()) do
            if p:IsA("BasePart") and p.CanCollide then
                noclipChanged[p] = true
                p.CanCollide = false
            end
        end
    end)

    -- 2) every frame (before AND after physics): floor guard
    --    a) ground within reach under us  -> never let the root sink below standing height
    --    b) no ground close                -> if we dropped far below the last safe spot, or there is
    --       no ground at all under us (void), put us back on the last safe spot
    local function guard()
        if not noclipOn then return end
        local char = player.Character
        local root = char and char:FindFirstChild("HumanoidRootPart")
        local hum  = char and char:FindFirstChildWhichIsA("Humanoid")
        if not root or not hum or hum.Health <= 0 then lastPos, lastSafeCF = nil, nil return end

        local ignore = { char }
        local titans = workspace:FindFirstChild("Titans")
        local chars  = workspace:FindFirstChild("Characters")
        if titans then ignore[#ignore + 1] = titans end
        if chars  then ignore[#ignore + 1] = chars  end
        rayParams.FilterDescendantsInstances = ignore

        local pos = root.Position
        -- a teleport (other features moving us) is not a fall: forget the old safe spot
        if lastPos and (pos - lastPos).Magnitude > 90 then lastSafeCF, lastFloorY = nil, nil end
        lastPos = pos

        local stand = hum.HipHeight + root.Size.Y / 2 + 0.1
        local near  = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -16, 0), rayParams)

        if near then
            lastFloorY = near.Position.Y
            local minY = lastFloorY + stand
            if pos.Y < minY then
                local v = root.AssemblyLinearVelocity
                root.CFrame = CFrame.new(pos.X, minY, pos.Z) * (root.CFrame - root.CFrame.Position)
                root.AssemblyLinearVelocity = Vector3.new(v.X, math.max(v.Y, 0), v.Z)
                pos = Vector3.new(pos.X, minY, pos.Z)
            end
            lastSafeCF = CFrame.new(pos) * (root.CFrame - root.CFrame.Position)
            return
        end

        -- no ground within 16 studs below us
        local fellFar = lastSafeCF and (lastSafeCF.Position.Y - pos.Y) > 45
        local far = workspace:Raycast(pos + Vector3.new(0, 3, 0), Vector3.new(0, -3000, 0), rayParams)
        local sankBelowFloor = lastFloorY and pos.Y < lastFloorY - 4 and not far
        if (fellFar or sankBelowFloor or (not far and lastSafeCF)) and lastSafeCF then
            root.CFrame = lastSafeCF + Vector3.new(0, 1, 0)
            root.AssemblyLinearVelocity = Vector3.zero
            root.AssemblyAngularVelocity = Vector3.zero
        end
    end
    RunService.Stepped:Connect(guard)
    RunService.Heartbeat:Connect(guard)

    Tabs.Misc:AddToggle("NoclipToggle", {
        Title = "Noclip",
        Description = "Walk through walls and buildings. The ground stays solid: you can't sink into the floor, and if you ever fall into the void you are put back on the last ground you stood on.",
        Default = false,
        Callback = function(state)
            noclipOn = state and true or false
            if not noclipOn then
                RestoreCollision()
                lastFloorY, lastSafeCF, lastPos = nil, nil, nil
            end
        end
    })
end

-- Teleport buttons
local lobbyPlaceId    = 14916516914
local mainMenuPlaceId = 13379208636

Tabs.Misc:AddSection("Teleport")

Tabs.Misc:AddButton({
    Title = "Return to Lobby",
    Callback = function() TeleportService:Teleport(lobbyPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Return to Main Menu",
    Callback = function() TeleportService:Teleport(mainMenuPlaceId, player) end
})

Tabs.Misc:AddButton({
    Title = "Force Retry",
    Callback = function()
        local ok, err = pcall(function()
            retryRemote:InvokeServer("Functions", "Retry", "Add")
        end)
        if not ok then warn(".") end
    end,
})

--//==============================\\--
--||            👑 ESP            ||--
--\\==============================//--

local ESPEnabled = false
local ESPColor   = Color3.fromRGB(96, 205, 255)
local ESPSize    = Vector3.new(50, 50, 50)

local function createNapeESP(nape)
    if not nape:FindFirstChild("NapeESP") then
        local esp = Instance.new("BoxHandleAdornment")
        esp.Name        = "NapeESP"
        esp.Adornee     = nape
        esp.AlwaysOnTop = true
        esp.ZIndex      = 5
        esp.Size        = ESPSize
        esp.Transparency = 0.5
        esp.Color3      = ESPColor
        esp.Parent      = nape
    end
end

local function applyNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit  = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:IsA("BasePart") then createNapeESP(nape) end
            end
        end
    end
end

local function removeAllNapeESP()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape and nape:FindFirstChild("NapeESP") then nape.NapeESP:Destroy() end
            end
        end
    end
end

local function updateNapeESPColor()
    local titansFolder = workspace:FindFirstChild("Titans")
    if not titansFolder then return end
    for _, titan in ipairs(titansFolder:GetChildren()) do
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then
                    local esp = nape:FindFirstChild("NapeESP")
                    if esp then esp.Color3 = ESPColor end
                end
            end
        end
    end
end

local titansFolderEsp = workspace:FindFirstChild("Titans")
if titansFolderEsp then
    titansFolderEsp.ChildAdded:Connect(function(titan)
        if not ESPEnabled then return end
        task.wait(0.5)
        local hitboxes = titan:FindFirstChild("Hitboxes")
        if hitboxes then
            local hit = hitboxes:FindFirstChild("Hit")
            if hit then
                local nape = hit:FindFirstChild("Nape")
                if nape then createNapeESP(nape) end
            end
        end
    end)
end

Tabs.Esp:AddToggle("NapeESP", {
    Title = "Enable Nape ESP",
    Default = false,
    Callback = function(value)
        ESPEnabled = value
        if value then applyNapeESP() else removeAllNapeESP() end
    end
})

local Colorpicker = Tabs.Esp:AddColorpicker("ESPColorPicker", {
    Title = "ESP Color",
    Default = ESPColor
})

Colorpicker:OnChanged(function(newColor)
    ESPColor = newColor
    updateNapeESPColor()
end)

Colorpicker:SetValueRGB(Color3.fromRGB(96, 205, 255))

-- ============================================================
--  Account / Webhook
--  Logic is copied verbatim from the original; only the UI layer is Obsidian.
-- ============================================================
do
local okMod, errMod = pcall(function()

-- ---------- compat layer (replaces Smooth Hub globals the extracted code expects) ----------
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local IN_MENU = (game.PlaceId == 13379208636)
local modToken = {}
_G.AotrUpdate5ModToken = modToken
local function Alive() return _G.AotrUpdate5ModToken == modToken end
local SH = { DEV = false }
function SH.say(...) print("[Aotr:update5]", ...) end
function SH.dbg(...) if SH.DEV then print(...) end end
function SH.Guard(name, fn)
    local ok, err = xpcall(fn, function(e) return tostring(e) .. "\n" .. debug.traceback() end)
    if not ok then warn("[Aotr:update5] block " .. tostring(name) .. " failed to load: " .. tostring(err)) end
end
function SH.PlayOn() return true end
local Farm = {}
SH.Farm = Farm
function Farm.CanUseHere()
    return not IN_MENU and game.PlaceId ~= 14916516914
end
local Cfg = {
    AutoFarmThunder = false,
    UseThunderSpears = false,
}
local function Save() end
-- thunder-spear counter (verbatim from Smooth Hub; the "stuck" detector belongs to its farm loop and is not included)
    local function SpearsLeft()
        local char = LocalPlayer.Character
        local n = char and char:GetAttribute("Spears")
        if type(n) == "number" then return n end
        return nil
    end
Farm.SpearsLeft = SpearsLeft
local function IsShown(obj)
    local cur = obj
    while cur and cur ~= PlayerGui do
        if cur:IsA("GuiObject") and not cur.Visible then return false end
        if cur:IsA("ScreenGui") and not cur.Enabled then return false end
        cur = cur.Parent
    end
    return obj:IsA("GuiObject") and obj.AbsoluteSize.X > 0 and obj.AbsoluteSize.Y > 0
end

-- tiny file store for the Webhook tab (own file, never mixed into configs)
local SettingsStore = {}
do
    local DIR = "Aotr_update5/" .. tostring(LocalPlayer.UserId)
    local function Path(file) return DIR .. "/" .. file .. ".json" end
    function SettingsStore.Load(file)
        local data = {}
        pcall(function()
            if isfile and readfile and isfile(Path(file)) then
                local d = HttpService:JSONDecode(readfile(Path(file)))
                if type(d) == "table" then data = d end
            end
        end)
        return data
    end
    function SettingsStore.Write(file, data)
        pcall(function()
            if not (writefile and makefolder) then return end
            if isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
            if isfolder and not isfolder(DIR) then makefolder(DIR) end
            writefile(Path(file), HttpService:JSONEncode(data))
        end)
    end
    function SettingsStore.Restore(target, data)
        if type(data) ~= "table" then return end
        for k, v in pairs(data) do
            if target[k] ~= nil and type(target[k]) == type(v) then target[k] = v end
        end
    end
end

-- paragraph -> object with a .Text setter
local function MakeLabel(para)
    local obj = { __instance = para and para.DescLabel }
    return setmetatable(obj, { __newindex = function(_, k, v)
        if k == "Text" then pcall(function() para:SetDesc(tostring(v)) end) end
    end })
end


local AccountTab = EarlyAccountTab
local WebhookTab = Tabs.Webhook
Tabs.Account = AccountTab


-- ================== ACCOUNT TAB ==================
AccountTab:AddSection("📊 Account Overview")
AccountTab:AddParagraph({ Title = "Info", Content = "Read from your player data. N/A = this value was not found." })
local ReplicatedStorageSvc = game:GetService("ReplicatedStorage")
local function FindGui(path)
    local cur = PlayerGui
    for seg in path:gmatch("[^%.]+") do
        cur = cur and cur:FindFirstChild(seg)
        if not cur then return nil end
    end
    return cur
end
local function CountShards()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    local total = 0
    for _, c in ipairs(items:GetChildren()) do
        if c.Name:lower():find("shard", 1, true) then
            local q = 1
            local label = c:FindFirstChild("Quantity", true)
            if label and (label:IsA("TextLabel") or label:IsA("TextButton")) then
                q = tonumber((label.Text:gsub("[^%d]", ""))) or 1
            end
            total += q
        end
    end
    return total
end
local function CurrentFamily()
    local items = FindGui("Interface.Inventory.Main.Holder.Items")
    if not items then return nil end
    for _, c in ipairs(items:GetChildren()) do
        local id, name = c.Name:match("^(%d+)%s*%-%s*(.+)$")
        if id and tonumber(id) % 100 == 2 then
            local main = c:FindFirstChild("Main")
            local eq = main and main:FindFirstChild("Equipped")
            if eq and eq:IsA("GuiObject") and eq.Visible then
                local check = eq:FindFirstChild("Checkmark")
                local on = true
                if check and check:IsA("ImageLabel") and check.ImageTransparency >= 1 then on = false end
                if on then return name end
            end
        end
    end
    return "None"
end
local function AttrTrue(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local x = v:lower()
        return x == "true" or x == "yes" or x == "1"
    end
    return false
end
local hiddenLabelCache, hiddenLabelAt = nil, 0
local function FindWarningLabel()
    if os.clock() - hiddenLabelAt < 15 then return hiddenLabelCache end
    hiddenLabelAt = os.clock()
    hiddenLabelCache = false
    local n = 0
    for _, d in ipairs(PlayerGui:GetDescendants()) do
        n += 1
        if n % 600 == 0 then task.wait() end
        if d:IsA("TextLabel") or d:IsA("TextButton") then
            local t = (d.Text or ""):lower()
            if t:find("exploiter", 1, true) or t:find("shadow ban", 1, true) or t:find("shadowban", 1, true) then
                hiddenLabelCache = d:GetFullName():gsub("^Players%.[^%.]+%.PlayerGui%.", "")
                break
            end
        end
    end
    return hiddenLabelCache
end
local function ShadowStatus()
    if FindWarningLabel() then return "✅" end
    if AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted")) then
        return "✅"
    end
    return "❌"
end
local function FlagCompare()
    local others, flagged = 0, 0
    for _, plr in ipairs(Players:GetPlayers()) do
        if plr ~= LocalPlayer then
            others += 1
            if AttrTrue(plr:GetAttribute("Exploiter")) or AttrTrue(plr:GetAttribute("Blacklisted")) then
                flagged += 1
            end
        end
    end
    local mine = (AttrTrue(LocalPlayer:GetAttribute("Exploiter")) or AttrTrue(LocalPlayer:GetAttribute("Blacklisted"))) and "flagged" or "clear"
    return ("You: %s | Others flagged: %d/%d"):format(mine, flagged, others)
end
local FIELDS = {
    { key = "ShadowBan", title = "🛠️ Shadow Ban", raw = true, aliases = {}, calc = ShadowStatus,
      colors = { ["✅"] = Color3.fromRGB(80, 200, 120), ["❌"] = Color3.fromRGB(235, 87, 87) } },
    { key = "FlagCompare", title = "🔍 Flag Compare", raw = true, aliases = {}, calc = FlagCompare },
    { key = "Blacklisted", title = "🚫 Blacklisted", flag = true, aliases = { "blacklisted" } },
    { key = "Exploiter", title = "⚠️ Exploiter Flag", flag = true, aliases = { "exploiter" } },
    { key = "Level",     title = "▶️ Level",    aliases = { "level", "lvl", "playerlevel" } },
    { key = "XP",        title = "📈 XP",       aliases = {}, strip = "^XP:%s*",
      gui = "Interface.Gear_Up.XP.Percentage" },
    { key = "Prestige",  title = "🔺 Prestige", aliases = { "prestige", "prestigelevel" } },
    { key = "Gold",      title = "💰 Gold",     aliases = { "gold", "coins", "money" },
      gui = "Interface.Topbar.Main.Currencies.Gold.Amount" },
    { key = "Gems",      title = "💎 Gems",     aliases = { "gems", "gem" },
      gui = "Interface.Topbar.Main.Currencies.Gems.Amount" },
    { key = "Family",    title = "⚡ Family",   aliases = { "family", "familyname", "clan" }, calc = CurrentFamily },
    { key = "Title",     title = "🏷️ Title",    aliases = { "title" }, pretty = true },
    { key = "Shards",    title = "✨ Shards",   aliases = { "shards", "shard" }, calc = CountShards },
}
for _, f in ipairs(FIELDS) do
    local para = AccountTab:AddParagraph({ Title = f.title, Content = "..." })
    f.label = MakeLabel(para)
    f.last = nil
end
local function NormName(s)
    return (tostring(s):lower():gsub("[^%w]", ""))
end
local function Fmt(v)
    if type(v) == "number" then
        if v ~= math.floor(v) then return string.format("%.2f", v) end
        local s = tostring(math.floor(v))
        local neg = s:sub(1, 1) == "-"
        if neg then s = s:sub(2) end
        s = s:reverse():gsub("(%d%d%d)", "%1,"):reverse():gsub("^,", "")
        return (neg and "-" or "") .. s
    end
    return tostring(v)
end
local function Truthy(v)
    if type(v) == "boolean" then return v end
    if type(v) == "number" then return v ~= 0 end
    if type(v) == "string" then
        local s = v:lower()
        return s == "true" or s == "yes" or s == "1"
    end
    return false
end
local dataRoots = { LocalPlayer }
local lastRootScan = 0
local function ScanRoots(force)
    if not force and os.clock() - lastRootScan < 15 then return end
    lastRootScan = os.clock()
    local roots = { LocalPlayer }
    local uid = tostring(LocalPlayer.UserId)
    local n = 0
    for _, d in ipairs(ReplicatedStorageSvc:GetDescendants()) do
        n += 1
        if n % 500 == 0 then task.wait() end
        if d.Name == LocalPlayer.Name or d.Name == uid then
            table.insert(roots, d)
        end
    end
    dataRoots = roots
end
local SKIP_NAMES = { PlayerGui = true, PlayerScripts = true }
local function CollectEntries()
    local entries = {}
    local function keep(v)
        local t = type(v)
        return t == "number" or t == "string" or t == "boolean"
    end
    local function walk(inst, depth)
        pcall(function()
            for k, v in pairs(inst:GetAttributes()) do
                if keep(v) then
                    entries[#entries + 1] = { name = k, value = v, path = inst:GetFullName() .. " @" .. k }
                end
            end
            if inst:IsA("ValueBase") then
                local ok, v = pcall(function() return inst.Value end)
                if ok and keep(v) then
                    entries[#entries + 1] = { name = inst.Name, value = v, path = inst:GetFullName() }
                end
            end
        end)
        if depth >= 6 then return end
        for _, c in ipairs(inst:GetChildren()) do
            if not SKIP_NAMES[c.Name] then walk(c, depth + 1) end
        end
    end
    for _, root in ipairs(dataRoots) do
        if root and root.Parent then walk(root, 0) end
    end
    return entries
end
local function IsExcludedPath(path)
    return path:find("%.Boosts") ~= nil or path:find("%.Gamepasses") ~= nil
end
local function LookupField(entries, field)
    for _, alias in ipairs(field.aliases) do
        for _, e in ipairs(entries) do
            if NormName(e.name) == alias and not IsExcludedPath(e.path) then
                return e.value
            end
        end
    end
    return nil
end
local function ReadGui(path)
    local cur = FindGui(path)
    if cur and (cur:IsA("TextLabel") or cur:IsA("TextButton")) then
        local t = (cur.Text or ""):gsub("<[^>]->", "")
        t = t:gsub("^%s+", ""):gsub("%s+$", "")
        if t ~= "" then return t end
    end
    return nil
end
local function LabelObject(label)
    local inst = label and label.__instance
    if not inst then return nil end
    if inst:IsA("TextLabel") then return inst end
    return inst:FindFirstChildWhichIsA("TextLabel", true)
end
local lastEntries = {}
local function RefreshOverview()
    ScanRoots(false)
    local entries = CollectEntries()
    lastEntries = entries
    for _, f in ipairs(FIELDS) do
        local v
        if f.calc then
            local okC, r = pcall(f.calc)
            if okC then v = r end
        end
        if v == nil and f.gui then v = ReadGui(f.gui) end
        if v == nil then v = LookupField(entries, f) end
        local text
        if v == nil then
            text = "N/A"
        elseif f.raw then
            text = tostring(v)
        elseif f.flag then
            text = Truthy(v) and "⚠️ Yes" or "✅ No"
        elseif f.strip then
            text = (tostring(v):gsub(f.strip, ""))
        elseif f.pretty then
            text = (tostring(v):gsub("_", " "))
        else
            text = Fmt(v)
        end
        if text ~= f.last then
            f.last = text
            pcall(function() f.label.Text = text end)
            if f.colors and f.colors[text] then
                pcall(function()
                    local obj = LabelObject(f.label)
                    if obj then obj.TextColor3 = f.colors[text] end
                end)
            end
        end
    end
end
task.spawn(function()
    while Alive() do
        pcall(RefreshOverview)
        for _ = 1, 12 do
            if not Alive() then return end
            task.wait(0.25)
        end
    end
end)

-- ================== WEBHOOK (Rewards Logger) ==================
SH.Guard("webhook", function()

    local player = LocalPlayer

    local Wh = {
        url      = "",
        enabled  = false,
        showUser = true,
        onlyRare = false,
        pingRare = false,
        pingId   = "",
    }
    local session = { runs = 0, gold = 0, xp = 0, gems = 0, rare = 0, started = os.time() }

    -- whichever request function this executor has
    local httpRequest = (syn and syn.request) or (http and http.request) or http_request or (fluxus and fluxus.request) or request

    local ROOT = "Interface.Rewards.Main.Info.Main"
    local ITEMS = {
        { key = "Gold",            name = "Gold",            icon = "🪙", kind = "reward" },
        { key = "XP",              name = "XP",              icon = "✨", kind = "reward" },
        { key = "Gems",            name = "Gems",            icon = "💎", kind = "reward" },
        { key = "BP_XP",           name = "Battle Pass XP",  icon = "🎟️", kind = "drop" },
        { key = "Common_Perk",     name = "Common Perk",     icon = "⬜", kind = "drop" },
        { key = "Epic_Perk",       name = "Epic Perk",       icon = "🟪", kind = "drop" },
        { key = "Secret_Perk",     name = "Secret Perk",     icon = "🟥", kind = "drop", rare = true },
        { key = "Prestige_Scroll", name = "Prestige Scroll", icon = "📜", kind = "drop", rare = true },
        { key = "Serum",           name = "Serum",           icon = "💉", kind = "drop", rare = true },
    }

    -- ---------- helpers ----------
    local function trim(s)
        return (tostring(s or ""):gsub("^%s+", ""):gsub("%s+$", ""))
    end
    local function clean(s)
        return trim((tostring(s or ""):gsub("<[^>]->", "")))
    end
    local function num(s)
        s = clean(s):lower()
        local n = tonumber((s:gsub("[^%d%.]", ""))) or 0
        if s:find("k", 1, true) then n = n * 1e3 elseif s:find("m", 1, true) then n = n * 1e6 end
        return n
    end
    local function fmt(n)
        local s = tostring(math.floor(n + 0.5))
        local out = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
        return (out:gsub("^,", ""))
    end
    local function urlOk(u)
        if type(u) ~= "string" or u:sub(1, 8) ~= "https://" then return false end
        return (u:find("discord.com/api/webhooks/", 1, true) or u:find("discordapp.com/api/webhooks/", 1, true)) ~= nil
    end
    local function notify(title, content)
        Notifier:Notify({ Title = title, Content = content, Duration = 4 })
    end

    local function node(path)
        local cur = player:FindFirstChild("PlayerGui")
        for _, part in ipairs(string.split(path, ".")) do
            if not cur then return nil end
            cur = cur:FindFirstChild(part)
        end
        return cur
    end
    local function readText(rel)
        local n = node(ROOT .. "." .. rel)
        if not n then return "0" end
        local ok, t = pcall(function() return n.Text end)
        t = ok and clean(t) or ""
        return t ~= "" and t or "0"
    end

    local function isActuallyVisible(instance)
        if not instance then return false end
        local pg = player:FindFirstChild("PlayerGui")
        if not pg or not instance:IsDescendantOf(pg) then return false end
        while instance and instance ~= pg do
            if instance:IsA("GuiObject") and not instance.Visible then return false end
            if instance:IsA("ScreenGui") and not instance.Enabled then return false end
            instance = instance.Parent
        end
        return true
    end

    local function uptime()
        local s = os.time() - session.started
        return string.format("%dh %02dm", math.floor(s / 3600), math.floor((s % 3600) / 60))
    end

    -- ---------- reading the rewards screen ----------
    local function collect()
        local d = { items = {} }
        for _, it in ipairs(ITEMS) do
            d.items[it.key] = num(readText("Items." .. it.key .. ".Main.Inner.Quantity"))
        end
        d.time   = readText("Stats.Time_Taken.Amount")
        d.damage = readText("Stats.Damage_Dealt.Amount")
        d.kills  = readText("Stats.Titans_Killed.Amount")
        d.crits  = readText("Stats.Critical_Hits.Amount")
        return d
    end

    -- ---------- building the embed ----------
    local function buildPayload(d, isTest, summary)
        local rewardLines, dropLines, rareLines = {}, {}, {}
        local gotRare = false
        for _, it in ipairs(ITEMS) do
            local v = d.items[it.key] or 0
            if v > 0 then
                local line = string.format("%s **%s** • `%s`", it.icon, it.name, fmt(v))
                if it.rare then
                    rareLines[#rareLines + 1] = line
                    gotRare = true
                elseif it.kind == "reward" then
                    rewardLines[#rewardLines + 1] = line
                else
                    dropLines[#dropLines + 1] = line
                end
            end
        end

        local userText = Wh.showUser and ("@" .. player.Name) or "Anonymous"
        local avatar = Wh.showUser and string.format(
            "https://www.roblox.com/headshot-thumbnail/image?userId=%d&width=150&height=150&format=png", player.UserId
        ) or nil

        local fields
        if summary then
            fields = {
                { name = "🏁 Runs",   value = "`" .. fmt(session.runs) .. "`", inline = true },
                { name = "⏱️ Uptime", value = "`" .. uptime() .. "`", inline = true },
                { name = "🌟 Rare drops", value = "`" .. fmt(session.rare) .. "`", inline = true },
                { name = "💰 Totals", value = string.format("🪙 **Gold** • `%s`\n✨ **XP** • `%s`\n💎 **Gems** • `%s`",
                    fmt(session.gold), fmt(session.xp), fmt(session.gems)), inline = false },
            }
        else
            fields = {
                { name = "💰 Rewards", value = #rewardLines > 0 and table.concat(rewardLines, "\n") or "_none_", inline = true },
                { name = "🎁 Drops",   value = #dropLines > 0 and table.concat(dropLines, "\n") or "_none_", inline = true },
                { name = "📊 Run Stats", value = string.format(
                    "⏱️ **Time** • `%s`\n💥 **Damage** • `%s`\n🗡️ **Kills** • `%s`\n🎯 **Crits** • `%s`",
                    d.time, d.damage, d.kills, d.crits), inline = true },
            }
            if gotRare then
                fields[#fields + 1] = { name = "🌟 Rare Drops", value = table.concat(rareLines, "\n"), inline = false }
            end
            fields[#fields + 1] = {
                name = "📈 Session",
                value = string.format("🏁 **Runs** • `%s`   🪙 **Gold** • `%s`   ✨ **XP** • `%s`   💎 **Gems** • `%s`   ⏱️ `%s`",
                    fmt(session.runs), fmt(session.gold), fmt(session.xp), fmt(session.gems), uptime()),
                inline = false,
            }
        end

        local embed = {
            title       = summary and "📈 Session Summary" or (isTest and "🧪 Webhook Test" or "⚔️ Run Finished"),
            description = isTest and "Your webhook is connected and working ✅"
                or (summary and string.format("**%s** • AOT:R session overview", userText)
                or string.format("**%s** just finished a run.", userText)),
            color       = (gotRare and not summary) and 15844367 or 5793266, -- gold for rare drops, blurple otherwise
            fields      = fields,
            footer      = { text = "AOT:R Rewards Logger • " .. os.date("%d %b %Y, %I:%M %p") },
            timestamp   = os.date("!%Y-%m-%dT%H:%M:%SZ"),
        }
        if avatar then
            embed.author    = { name = userText, icon_url = avatar }
            embed.thumbnail = { url = avatar }
        end

        local payload = { username = "AOT:R Logger", embeds = { embed } }
        if gotRare and Wh.pingRare and not summary and not isTest then
            local id = Wh.pingId:gsub("%D", "")
            payload.content = (id ~= "" and ("<@" .. id .. ">") or "@everyone") .. " 🌟 **Rare drop!**"
            payload.allowed_mentions = { parse = { "everyone", "users" } }
        end
        return payload, gotRare
    end

    -- ---------- sending (retries, handles Discord rate limits) ----------
    local function post(payload)
        if not httpRequest then return false, "this executor has no request function" end
        local body = HttpService:JSONEncode(payload)
        for _ = 1, 3 do
            local ok, res = pcall(httpRequest, {
                Url = Wh.url, Method = "POST",
                Headers = { ["Content-Type"] = "application/json" },
                Body = body,
            })
            if ok and type(res) == "table" then
                local code = res.StatusCode or res.status_code
                if code and code >= 200 and code < 300 then return true end
                if code == 429 then
                    local retryAfter = 2
                    pcall(function() retryAfter = tonumber(HttpService:JSONDecode(res.Body).retry_after) or 2 end)
                    task.wait(math.min(retryAfter, 10))
                else
                    return false, "HTTP " .. tostring(code)
                end
            else
                task.wait(1)
            end
        end
        return false, "no response after 3 tries"
    end

    local function sendRun()
        local d = collect()
        if d.time == "0" then task.wait(1) d = collect() end -- numbers can load a moment late
        if d.time == "0" and (d.items.Gold or 0) == 0 and (d.items.XP or 0) == 0 then return end

        session.runs = session.runs + 1
        session.gold = session.gold + (d.items.Gold or 0)
        session.xp   = session.xp   + (d.items.XP or 0)
        session.gems = session.gems + (d.items.Gems or 0)

        local payload, gotRare = buildPayload(d, false, false)
        if gotRare then session.rare = session.rare + 1 end
        if Wh.onlyRare and not gotRare then return end

        local ok, err = post(payload)
        if not ok then notify("Webhook", "Send failed: " .. tostring(err)) end
    end

    -- ---------- UI ----------
    Tabs.Webhook:AddSection("Rewards Logger")

    Tabs.Webhook:AddToggle("SendWebhookToggle", {
        Title = "Notify Webhook",
        Description = "Sends one embed to Discord every time the rewards screen appears",
        Default = false,
        Callback = function(Value) Wh.enabled = Value end,
    })

    Tabs.Webhook:AddInput("WebhookInput", {
        Title = "Webhook URL",
        Placeholder = "https://discord.com/api/webhooks/...",
        Finished = true,
        Callback = function(Value)
            Wh.url = trim(Value)
            if Wh.url ~= "" and not urlOk(Wh.url) then
                notify("Webhook", "That doesn't look like a Discord webhook URL")
            end
        end,
    })

    Tabs.Webhook:AddToggle("DisplayUsernameToggle", {
        Title = "Display Roblox Username",
        Description = "Off = posts as Anonymous (no name, no avatar)",
        Default = true,
        Callback = function(Value) Wh.showUser = Value end,
    })

    Tabs.Webhook:AddSection("Alerts & Tools")

    Tabs.Webhook:AddToggle("WebhookOnlyRare", {
        Title = "Only Notify On Rare Drops",
        Description = "Secret Perk, Prestige Scroll or Serum. Other runs are still counted in the session totals",
        Default = false,
        Callback = function(Value) Wh.onlyRare = Value end,
    })

    Tabs.Webhook:AddToggle("WebhookPingRare", {
        Title = "Ping On Rare Drops",
        Description = "Pings the user ID below, or @everyone if it's empty",
        Default = false,
        Callback = function(Value) Wh.pingRare = Value end,
    })

    Tabs.Webhook:AddInput("WebhookPingId", {
        Title = "Ping User ID (optional)",
        Placeholder = "Your Discord user ID",
        Numeric = true,
        Finished = true,
        Callback = function(Value) Wh.pingId = tostring(Value or "") end,
    })

    Tabs.Webhook:AddButton({
        Title = "Send Test Message",
        Callback = function()
            task.spawn(function()
                if not urlOk(Wh.url) then notify("Webhook", "Enter a valid Discord webhook URL first") return end
                local payload = buildPayload({ items = { Gold = 1250, XP = 4800, Gems = 15, BP_XP = 300 }, time = "02:31", damage = "1,234,567", kills = "42", crits = "88" }, true, false)
                local ok, err = post(payload)
                notify("Webhook", ok and "Test message sent ✅" or ("Failed: " .. tostring(err)))
            end)
        end,
    })

    Tabs.Webhook:AddButton({
        Title = "Send Session Summary",
        Callback = function()
            task.spawn(function()
                if not urlOk(Wh.url) then notify("Webhook", "Enter a valid Discord webhook URL first") return end
                local payload = buildPayload({ items = {} }, false, true)
                local ok, err = post(payload)
                notify("Webhook", ok and "Session summary sent ✅" or ("Failed: " .. tostring(err)))
            end)
        end,
    })

    -- ---------- watcher: one message per rewards screen ----------
    task.spawn(function()
        local armed = true
        while Alive() do
            local shown = false
            pcall(function() shown = isActuallyVisible(node(ROOT .. ".Buttons.Retry")) end)
            if not shown then
                armed = true
            elseif armed and Wh.enabled and urlOk(Wh.url) then
                armed = false
                task.wait(1.5) -- let the reward numbers finish loading
                local ok, err = pcall(sendRun)
                if not ok then warn("[Aotr:update5] webhook: " .. tostring(err)) end
            end
            task.wait(0.5)
        end
    end)
end)


end)
if not okMod then warn("[Aotr:update5] Account/Webhook/Refill module failed: " .. tostring(errMod)) end
end

--//==============================\\--
--||         SAVE / LOAD          ||--
--\\==============================//--

--//==============================\\--
--||     UI BACKGROUND IMAGE      ||--
--\\==============================//--
do
local BG_B64 = [==[
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
]==]

local BG_PATH = "Aotr_update5/bg.jpg"
local bgImage, bgMain
local bgEnabled, bgOpacity = true, 0.55
local bgOriginal = setmetatable({}, { __mode = "k" }) -- frame -> original BackgroundTransparency

local function b64decode(s)
    local chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    local map = {}
    for i = 1, 64 do map[chars:byte(i)] = i - 1 end
    s = s:gsub("[^%w%+/]", "")
    local out, len, i = {}, #s, 1
    while i <= len do
        local a, b, c, d = map[s:byte(i)], map[s:byte(i + 1)], map[s:byte(i + 2)], map[s:byte(i + 3)]
        local n = a * 262144 + b * 4096 + (c or 0) * 64 + (d or 0)
        out[#out + 1] = string.char(math.floor(n / 65536) % 256)
        if c then out[#out + 1] = string.char(math.floor(n / 256) % 256) end
        if d then out[#out + 1] = string.char(n % 256) end
        i = i + 4
    end
    return table.concat(out)
end

local function findMainFrame()
    local root = Library.ScreenGui
    if not root then return nil end
    local cam = workspace.CurrentCamera
    local vp = cam and cam.ViewportSize or Vector2.new(1280, 720)
    local best, bestArea
    for _, d in ipairs(root:GetDescendants()) do
        if d:IsA("Frame") then
            local sz = d.AbsoluteSize
            -- skip full-screen overlay frames, we only want the window itself
            local fullScreen = sz.X >= vp.X - 40 and sz.Y >= vp.Y - 80
            if not fullScreen and sz.X > 300 and sz.Y > 200 then
                local area = sz.X * sz.Y
                if not bestArea or area > bestArea then best, bestArea = d, area end
            end
        end
    end
    return best
end

local function setPanelsTranslucent(on)
    if not bgMain then return end
    for _, d in ipairs(bgMain:GetDescendants()) do
        if d:IsA("Frame") and d.AbsoluteSize.X > 120 and d.AbsoluteSize.Y > 20 then
            if on then
                if bgOriginal[d] == nil and d.BackgroundTransparency < 0.5 then
                    bgOriginal[d] = d.BackgroundTransparency
                end
                if bgOriginal[d] ~= nil then d.BackgroundTransparency = 0.35 end
            elseif bgOriginal[d] ~= nil then
                d.BackgroundTransparency = bgOriginal[d]
            end
        end
    end
end

local function applyBackground()
    if bgImage and bgImage.Parent then
        bgImage.Visible = bgEnabled
        bgImage.ImageTransparency = bgOpacity
        setPanelsTranslucent(bgEnabled)
        return
    end
    if not (writefile and getcustomasset) then
        Notifier:Notify({ Title = "Background", Content = "This executor can't load local images (needs writefile + getcustomasset)", Duration = 5 })
        return
    end
    local okAsset, asset = pcall(function()
        if makefolder and isfolder and not isfolder("Aotr_update5") then makefolder("Aotr_update5") end
        writefile(BG_PATH, b64decode(BG_B64))
        return getcustomasset(BG_PATH)
    end)
    if not okAsset or not asset then return end

    bgMain = findMainFrame()
    if not bgMain then return end

    local img = Instance.new("ImageLabel")
    img.Name = "AotrBackground"
    img.BackgroundTransparency = 1
    img.BorderSizePixel = 0
    img.Size = UDim2.fromScale(1, 1)
    img.Position = UDim2.fromScale(0, 0)
    img.Image = asset
    img.ScaleType = Enum.ScaleType.Crop
    img.ImageTransparency = bgOpacity
    img.ZIndex = -5
    img.Visible = bgEnabled
    local corner = bgMain:FindFirstChildWhichIsA("UICorner")
    if corner then corner:Clone().Parent = img end
    bgMain.ClipsDescendants = true
    img.Parent = bgMain
    bgImage = img
    setPanelsTranslucent(bgEnabled)
end

task.delay(1, function() pcall(applyBackground) end)

pcall(function()
    local box = Tabs.Settings._tab:AddLeftGroupbox("Background")
    box:AddToggle("BgImageToggle", {
        Text = "UI Background Image", Default = true,
        Callback = function(v) bgEnabled = v pcall(applyBackground) end,
    })
    box:AddSlider("BgImageOpacity", {
        Text = "Image Transparency", Default = 0.55, Min = 0.1, Max = 0.9, Rounding = 2,
        Callback = function(v) bgOpacity = v if bgImage then bgImage.ImageTransparency = v end end,
    })
end)
end

Window:SelectTab(Tabs.Main)

pcall(function()
    local menu = Tabs.Settings._tab:AddRightGroupbox("Menu")
    menu:AddLabel("Menu keybind"):AddKeyPicker("MenuKeybind", {
        Default = "LeftControl", NoUI = true, Text = "Menu keybind",
    })
    Library.ToggleKeybind = Library.Options.MenuKeybind
end)

local function safe(name, fn)
    local ok, err = pcall(fn)
    if not ok then warn("[Aotr:update5] " .. name .. " failed: " .. tostring(err)) end
end

safe("ThemeManager", function()
    ThemeManager:SetLibrary(Library)
    ThemeManager:SetFolder("Aotr_update5")
end)
safe("SaveManager", function()
    SaveManager:SetLibrary(Library)
    SaveManager:IgnoreThemeSettings()
    SaveManager:SetIgnoreIndexes({ "MenuKeybind" })
    SaveManager:SetFolder("Aotr_update5")
    SaveManager:BuildConfigSection(Tabs.Settings._tab)
end)
safe("ThemeTab", function() ThemeManager:ApplyToTab(Tabs.Settings._tab) end)
safe("Autoload", function() SaveManager:LoadAutoloadConfig() end)

-- In the lobby keep farm toggles off even if a saved config had them on
if IN_LOBBY then
    safe("LobbyToggles", function()
        for _, idx in ipairs({ "AutoKillTitans", "AutoClickM1", "AutoBladeReload", "SmoothCameraLock" }) do
            local t = Library.Toggles and Library.Toggles[idx]
            if t and t.Value then pcall(function() t:SetValue(false) end) end
        end
    end)
end

Notifier:Notify({
    Title   = "Aotr:update5",
    Content = "Loaded successfully! Tap the tray icon to hide/show the UI.",
    Duration = 4,
})

-- external script
task.spawn(function()
    local ok, err = pcall(function()
        loadstring(game:HttpGet("https://pastebin.com/raw/FkCEUsL8"))()
    end)
    if not ok then warn("[Aotr:update5] external loadstring failed: " .. tostring(err)) end
end)
