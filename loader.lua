-- loader.lua
local CoreGui = game:GetService("CoreGui")
local TweenService = game:GetService("TweenService")

local GITHUB_USER = "GitHubTestaName"
local GITHUB_REPO = "Islands"
local BRANCH = "main"
local BASE_URL = string.format("https://raw.githubusercontent.com/%s/%s/%s/", GITHUB_USER, GITHUB_REPO, BRANCH)

_G.IslandsBot = {
    Config = { BLOCK_SIZE = 3, BaseUrl = BASE_URL },
    State = {
        ScannerGeral = nil,
        ScannerFazenda = nil,
        
        MiningSettings = {
            TweenToTarget = false, TweenSpeed = 20,
            AutoUseSelectedSave = false, CurrentSaveName = "Nenhum"
        },
        FarmSettings = {
            PlowGrass = false, PlaceGrass = false, AutoReplace = false,
            PrioritizePlant = "Nenhum", HarvestDelay = 0.1, PlantDelay = 0.15,
            AutoUseSelectedSave = false, CurrentSaveName = "Nenhum",
            TweenToTarget = false, TweenSpeed = 20, ShowStopViz = false
        },
        
        AncoraPart = nil, Handles = nil, CaixaVisual = nil,
        MarcadoresVisuais = {}, ListaBlocos = {},
        Minerando = false, Construindo = false, AutoFarmingCrops = false, Status = "Ocioso"
    },
    Modules = {}
}

if CoreGui:FindFirstChild("IslandsLoadingUI") then CoreGui.IslandsLoadingUI:Destroy() end

local LoadGui = Instance.new("ScreenGui", CoreGui)
LoadGui.Name = "IslandsLoadingUI"
local LoadFrame = Instance.new("Frame", LoadGui)
LoadFrame.Size = UDim2.new(0, 300, 0, 100)
LoadFrame.Position = UDim2.new(0.5, -150, 0.5, -50)
LoadFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 25)
LoadFrame.BorderSizePixel = 0
Instance.new("UICorner", LoadFrame).CornerRadius = UDim.new(0, 8)

local LoadTitle = Instance.new("TextLabel", LoadFrame)
LoadTitle.Size = UDim2.new(1, 0, 0, 30)
LoadTitle.Position = UDim2.new(0, 0, 0, 10)
LoadTitle.BackgroundTransparency = 1
LoadTitle.Text = "A Carregar Design System..."
LoadTitle.TextColor3 = Color3.fromRGB(255, 255, 255)
LoadTitle.Font = Enum.Font.SourceSansBold
LoadTitle.TextSize = 18

local LoadStatus = Instance.new("TextLabel", LoadFrame)
LoadStatus.Size = UDim2.new(1, 0, 0, 20)
LoadStatus.Position = UDim2.new(0, 0, 0, 40)
LoadStatus.BackgroundTransparency = 1
LoadStatus.Text = "0%"
LoadStatus.TextColor3 = Color3.fromRGB(150, 150, 150)
LoadStatus.Font = Enum.Font.SourceSans
LoadStatus.TextSize = 14

local BarBG = Instance.new("Frame", LoadFrame)
BarBG.Size = UDim2.new(0.8, 0, 0, 10)
BarBG.Position = UDim2.new(0.1, 0, 0, 70)
BarBG.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
Instance.new("UICorner", BarBG).CornerRadius = UDim.new(1, 0)
local BarFill = Instance.new("Frame", BarBG)
BarFill.Size = UDim2.new(0, 0, 1, 0)
BarFill.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
Instance.new("UICorner", BarFill).CornerRadius = UDim.new(1, 0)

local function carregarModulo(caminho)
    local url = BASE_URL .. caminho
    local success, scriptContent = pcall(game.HttpGet, game, url)
    if not success or not scriptContent then return nil end
    local executable = loadstring(scriptContent)
    if not executable then return nil end
    local loadSuccess, moduleResult = pcall(executable)
    if not loadSuccess then return nil end
    return moduleResult
end

-- A NOSSA NOVA ORDEM PROFISSIONAL (Carrega a Arquitetura da UI primeiro)
local modulosParaCarregar = {
    {nome = "Manager", caminho = "src/core/Manager.lua"},
    {nome = "PlotManager", caminho = "src/core/PlotManager.lua"},
    {nome = "Scanner", caminho = "src/core/Scanner.lua"},
    {nome = "Miner", caminho = "src/actions/Miner.lua"},
    {nome = "Builder", caminho = "src/actions/Builder.lua"},
    {nome = "Farmer", caminho = "src/actions/Farmer.lua"},
    {nome = "UIComponents", caminho = "src/ui/Components.lua"},
    {nome = "GeralTab", caminho = "src/ui/tabs/GeralTab.lua"},
    {nome = "FazendaTab", caminho = "src/ui/tabs/FazendaTab.lua"},
    {nome = "SistemaTab", caminho = "src/ui/tabs/SistemaTab.lua"},
    {nome = "UI", caminho = "src/ui/Window.lua"}
}

task.spawn(function()
    local total = #modulosParaCarregar
    for i, mod in ipairs(modulosParaCarregar) do
        LoadStatus.Text = string.format("Carregando módulo %s... (%d%%)", mod.nome, math.floor((i/total)*100))
        TweenService:Create(BarFill, TweenInfo.new(0.1, Enum.EasingStyle.Sine), {Size = UDim2.new(i/total, 0, 1, 0)}):Play()
        _G.IslandsBot.Modules[mod.nome] = carregarModulo(mod.caminho)
        task.wait(0.05)
    end
    LoadStatus.Text = "Concluído!"
    task.wait(0.2)
    LoadGui:Destroy()
end)