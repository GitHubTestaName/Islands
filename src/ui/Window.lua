-- src/ui/Window.lua
local UI = {}
local Bot = _G.IslandsBot
local State = Bot.State

local CoreGui = game:GetService("CoreGui")
local UserInputService = game:GetService("UserInputService")
local TweenService = game:GetService("TweenService")

if CoreGui:FindFirstChild("IslandsCustomUI") then CoreGui.IslandsCustomUI:Destroy() end

local ScreenGui = Instance.new("ScreenGui")
ScreenGui.Name = "IslandsCustomUI"
ScreenGui.ResetOnSpawn = false
ScreenGui.Parent = CoreGui

local MainFrame = Instance.new("Frame", ScreenGui)
MainFrame.Name = "MainFrame"
MainFrame.Size = UDim2.new(0, 650, 0, 500) 
MainFrame.Position = UDim2.new(0.5, -325, 0.5, -250)
MainFrame.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
MainFrame.BorderSizePixel = 0
MainFrame.ClipsDescendants = true
Instance.new("UICorner", MainFrame).CornerRadius = UDim.new(0, 8)

-- ================= HOTKEY E ARRASTO (CHASSI) =================
State.HideKey = Enum.KeyCode.V
State.IsListeningForKey = false

UserInputService.InputBegan:Connect(function(input, gameProcessed)
    if State.IsListeningForKey then
        if input.UserInputType == Enum.UserInputType.Keyboard then
            State.HideKey = input.KeyCode
            State.IsListeningForKey = false
            if State.UpdateKeybindButton then State.UpdateKeybindButton() end
        end
        return 
    end
    
    if not gameProcessed and input.UserInputType == Enum.UserInputType.Keyboard and input.KeyCode == State.HideKey then
        if ScreenGui:FindFirstChild("MainFrame") then
            ScreenGui.MainFrame.Visible = not ScreenGui.MainFrame.Visible
        end
    end
end)

local TopBar = Instance.new("Frame", MainFrame)
TopBar.Size = UDim2.new(1, 0, 0, 35)
TopBar.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TopBar.BorderSizePixel = 0
TopBar.Active = true
TopBar.ZIndex = 5000
Instance.new("UICorner", TopBar).CornerRadius = UDim.new(0, 8)

local TopBarBase = Instance.new("Frame", TopBar)
TopBarBase.Size = UDim2.new(1, 0, 0, 8)
TopBarBase.Position = UDim2.new(0, 0, 1, -8)
TopBarBase.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
TopBarBase.BorderSizePixel = 0
TopBarBase.ZIndex = 5000

local dragToggle, dragStart, startPos
TopBar.InputBegan:Connect(function(input)
    if (input.UserInputType == Enum.UserInputType.MouseButton1) then 
        dragToggle = true; dragStart = input.Position; startPos = MainFrame.Position
        input.Changed:Connect(function() if input.UserInputState == Enum.UserInputState.End then dragToggle = false end end)
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseMovement and dragToggle then
        local delta = input.Position - dragStart
        TweenService:Create(MainFrame, TweenInfo.new(0.1), {Position = UDim2.new(startPos.X.Scale, startPos.X.Offset + delta.X, startPos.Y.Scale, startPos.Y.Offset + delta.Y)}):Play()
    end
end)

local WindowResizeHandle = Instance.new("TextButton", MainFrame)
WindowResizeHandle.Size = UDim2.new(0, 20, 0, 20)
WindowResizeHandle.Position = UDim2.new(1, -20, 1, -20)
WindowResizeHandle.BackgroundTransparency = 1
WindowResizeHandle.Text = "◢"
WindowResizeHandle.TextColor3 = Color3.fromRGB(150, 150, 150)
WindowResizeHandle.TextSize = 16
WindowResizeHandle.ZIndex = 5000

local draggingWindow, winDragStartPos, winStartSize
WindowResizeHandle.InputBegan:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then
        draggingWindow = true; winDragStartPos = input.Position; winStartSize = MainFrame.AbsoluteSize
    end
end)
UserInputService.InputChanged:Connect(function(input)
    if draggingWindow and input.UserInputType == Enum.UserInputType.MouseMovement then
        local delta = input.Position - winDragStartPos
        MainFrame.Size = UDim2.new(0, math.max(550, winStartSize.X + delta.X), 0, math.max(400, winStartSize.Y + delta.Y))
    end
end)
UserInputService.InputEnded:Connect(function(input)
    if input.UserInputType == Enum.UserInputType.MouseButton1 then draggingWindow = false end
end)

local Title = Instance.new("TextLabel", TopBar)
Title.Size = UDim2.new(0.5, 0, 1, 0)
Title.Position = UDim2.new(0, 15, 0, 0)
Title.BackgroundTransparency = 1
Title.Text = "Islands Automation PRO"
Title.TextColor3 = Color3.fromRGB(240, 240, 240)
Title.TextXAlignment = Enum.TextXAlignment.Left
Title.Font = Enum.Font.SourceSansBold
Title.TextSize = 16
Title.ZIndex = 5001

local StatusLabel = Instance.new("TextLabel", TopBar)
StatusLabel.Size = UDim2.new(0.5, -15, 1, 0)
StatusLabel.Position = UDim2.new(0.5, 0, 0, 0)
StatusLabel.BackgroundTransparency = 1
StatusLabel.Text = "Status: Ocioso"
StatusLabel.TextColor3 = Color3.fromRGB(0, 180, 255)
StatusLabel.TextXAlignment = Enum.TextXAlignment.Right
StatusLabel.Font = Enum.Font.SourceSansSemibold
StatusLabel.TextSize = 14
StatusLabel.ZIndex = 5001
function UI:SetStatusText(texto) StatusLabel.Text = "Status: " .. tostring(texto) end

-- ================= ESTRUTURA DE ABAS (SIDEBAR) =================
local Sidebar = Instance.new("Frame", MainFrame)
Sidebar.Size = UDim2.new(0, 140, 1, -35)
Sidebar.Position = UDim2.new(0, 0, 0, 35)
Sidebar.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
Sidebar.BorderSizePixel = 0

local SidebarLayout = Instance.new("UIListLayout", Sidebar)
SidebarLayout.Padding = UDim.new(0, 6)
SidebarLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
Instance.new("UIPadding", Sidebar).PaddingTop = UDim.new(0, 10)

local ContentContainer = Instance.new("Frame", MainFrame)
ContentContainer.Size = UDim2.new(1, -140, 1, -35)
ContentContainer.Position = UDim2.new(0, 140, 0, 35)
ContentContainer.BackgroundTransparency = 1
ContentContainer.ClipsDescendants = true 

local Paginas, BotoesAba = {}, {}

function UI:CriarAba(nome, id)
    local btn = Instance.new("TextButton", Sidebar)
    btn.Size = UDim2.new(0.9, 0, 0, 34)
    btn.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
    btn.BorderSizePixel = 0
    btn.Text = nome
    btn.TextColor3 = Color3.fromRGB(150, 150, 150)
    btn.Font = Enum.Font.SourceSansBold
    btn.TextSize = 14
    Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 6)
    
    local stroke = Instance.new("UIStroke", btn)
    stroke.Color = Color3.fromRGB(0, 150, 255)
    stroke.Thickness = 1.5
    stroke.Transparency = 1
    
    local pg = Instance.new("ScrollingFrame", ContentContainer)
    pg.Size = UDim2.new(1, 0, 1, -5)
    pg.Position = UDim2.new(0, 0, 0, 5)
    pg.BackgroundTransparency = 1
    pg.BorderSizePixel = 0
    pg.ScrollBarThickness = 5
    pg.Visible = false
    pg.ClipsDescendants = true 
    
    local layout = Instance.new("UIListLayout", pg)
    layout.FillDirection = Enum.FillDirection.Horizontal
    layout.Wraps = true
    layout.Padding = UDim.new(0, 10)
    layout.HorizontalAlignment = Enum.HorizontalAlignment.Left
    layout.VerticalAlignment = Enum.VerticalAlignment.Top
    layout.SortOrder = Enum.SortOrder.LayoutOrder
    
    local padding = Instance.new("UIPadding", pg)
    padding.PaddingLeft = UDim.new(0, 10)
    padding.PaddingTop = UDim.new(0, 10)
    padding.PaddingBottom = UDim.new(0, 250) 

    layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
        pg.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 260)
    end)
    
    Paginas[id], BotoesAba[id] = pg, btn
    btn.MouseButton1Click:Connect(function()
        for k, v in pairs(Paginas) do v.Visible = (k == id) end
        for k, v in pairs(BotoesAba) do 
            local isAtivo = (k == id)
            v.TextColor3 = isAtivo and Color3.fromRGB(255, 255, 255) or Color3.fromRGB(150, 150, 150)
            v.BackgroundColor3 = isAtivo and Color3.fromRGB(0, 100, 200) or Color3.fromRGB(30, 30, 30)
            v.UIStroke.Transparency = isAtivo and 0 or 1
        end
    end)
    
    

    return pg
end

-- ================= INICIALIZAÇÃO DE GAVETAS (TABS) =================
local pageGeral = UI:CriarAba("Geral (Azul)", "seletor")
local pageFazenda = UI:CriarAba("Fazenda (Verde)", "fazenda")
local pageWild = UI:CriarAba("Wild Mine (Global)", "wild") -- <--- ADICIONE ESTA LINHA!
local pageSistema = UI:CriarAba("Sistema", "sistema")

-- Ativa a Fazenda por padrão
BotoesAba["fazenda"].TextColor3 = Color3.fromRGB(255, 255, 255)
BotoesAba["fazenda"].BackgroundColor3 = Color3.fromRGB(0, 100, 200)
BotoesAba["fazenda"].UIStroke.Transparency = 0
Paginas["fazenda"].Visible = true

-- INJEÇÃO PROFISSIONAL: Delega o desenho de cada tela para o seu respetivo ficheiro!
task.spawn(function()
    if Bot.Modules.GeralTab then Bot.Modules.GeralTab:Construir(pageGeral) end
    if Bot.Modules.FazendaTab then Bot.Modules.FazendaTab:Construir(pageFazenda) end
    if Bot.Modules.WildTab then Bot.Modules.WildTab:Construir(pageWild) end -- <--- ADICIONE ESTA LINHA!
    if Bot.Modules.SistemaTab then Bot.Modules.SistemaTab:Construir(pageSistema) end
end)
return UI