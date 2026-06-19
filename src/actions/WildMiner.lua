-- src/actions/WildMiner.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local WildMiner = {
    CacheBlocos = {},
    CachePortais = {},
    ActiveTween = nil
}

local Bot = _G.IslandsBot
local LocalPlayer = Players.LocalPlayer

-- Obtém ou cria a pasta de ESP
local function GetEspFolder()
    local cg = pcall(function() return game:GetService("CoreGui").Name end) and game:GetService("CoreGui") or LocalPlayer:WaitForChild("PlayerGui")
    local folder = cg:FindFirstChild("WildernessEsp") or Instance.new("Folder", cg)
    folder.Name = "WildernessEsp"
    return folder
end

local HIT_KEY = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nohIstskUiftvgjy"

local function GetIslandCategory(rawName)
    if rawName == "" then return "Mundo Aberto" end
    local prefix = string.match(rawName, "^[a-z]+")
    if not prefix then return rawName end
    if prefix == "hub" then return "HUB" end
    return prefix:gsub("^%l", string.upper)
end

function WildMiner:MapearMundo()
    self.CacheBlocos = {}
    self.CachePortais = {}
    local WildernessBlocks = Workspace:FindFirstChild("WildernessBlocks")
    
    local attrId = LocalPlayer:GetAttribute("OwnedIslandsID")
    if attrId then
        local myIslandPortal = Workspace:FindFirstChild("Islands") 
            and Workspace.Islands:FindFirstChild(attrId .. "-island")
            and Workspace.Islands[attrId .. "-island"]:FindFirstChild("Blocks")
            and Workspace.Islands[attrId .. "-island"].Blocks:FindFirstChild("portalToSpawn")
        if myIslandPortal then self.CachePortais["1. 🏠 Minha Ilha (Voltar pro HUB)"] = myIslandPortal end
    else
        local islandsFolder = Workspace:FindFirstChild("Islands")
        if islandsFolder then
            for _, island in ipairs(islandsFolder:GetChildren()) do
                local blocksFolder = island:FindFirstChild("Blocks")
                if blocksFolder and blocksFolder:FindFirstChild("portalToSpawn") then
                    self.CachePortais["1. 🏠 Minha Ilha (Voltar pro HUB)"] = blocksFolder.portalToSpawn
                    break
                end
            end
        end
    end
    
    local hubPortal = Workspace:FindFirstChild("spawnPrefabs")
        and Workspace.spawnPrefabs:FindFirstChild("WildIslands")
        and Workspace.spawnPrefabs.WildIslands:FindFirstChild("hub")
        and Workspace.spawnPrefabs.WildIslands.hub:FindFirstChild("portalToIsland")
    if hubPortal then self.CachePortais["2. 🌐 HUB Principal (Ir pra Ilha)"] = hubPortal end

    if WildernessBlocks then
        for _, obj in ipairs(WildernessBlocks:GetChildren()) do
            if obj.Name == "portal" then
                local destVal = obj:FindFirstChild("WildDestination")
                if destVal and destVal:IsA("StringValue") and destVal.Value ~= "" then
                    self.CachePortais["🌍 " .. destVal.Value] = obj
                end
            end

            local health = obj:FindFirstChild("Health")
            if health and health.Value > 0 then
                local regen = obj:FindFirstChild("RegenBlockTable")
                local rawRegionName = (regen and regen:IsA("StringValue") and regen.Value ~= "") and regen.Value or "Mundo Aberto"
                local islandCategory = GetIslandCategory(rawRegionName)
                
                if not self.CacheBlocos[islandCategory] then self.CacheBlocos[islandCategory] = {} end
                if not self.CacheBlocos[islandCategory][rawRegionName] then self.CacheBlocos[islandCategory][rawRegionName] = {} end
                if not self.CacheBlocos[islandCategory][rawRegionName][obj.Name] then self.CacheBlocos[islandCategory][rawRegionName][obj.Name] = {} end
                
                table.insert(self.CacheBlocos[islandCategory][rawRegionName][obj.Name], obj)
            end
        end
    end
end

function WildMiner:GetIlhasDisponiveis()
    local list = {}
    for k, _ in pairs(self.CacheBlocos) do table.insert(list, k) end
    table.sort(list)
    return list
end

function WildMiner:GetPortaisDisponiveis()
    local list = {}
    for k, _ in pairs(self.CachePortais) do table.insert(list, k) end
    table.sort(list)
    return list
end

function WildMiner:AtualizarESP()
    local folder = GetEspFolder()
    folder:ClearAllChildren()
    local State = Bot.State
    if not State.WildSettings then return end
    
    for islandCat, subRegions in pairs(self.CacheBlocos) do
        for subRegName, blocksMap in pairs(subRegions) do
            for blockName, blockList in pairs(blocksMap) do
                local key = subRegName .. "|" .. blockName
                local isTargetBlock = State.WildSettings.SelectedBlocks[key]
                
                if State.WildSettings.EspGeral or (State.WildSettings.EspSpecific and isTargetBlock) then
                    for _, block in ipairs(blockList) do
                        if block and block.Parent and block:FindFirstChild("Health") and block.Health.Value > 0 then
                            local hl = Instance.new("Highlight")
                            hl.Adornee = block
                            hl.FillTransparency = 0.8; hl.OutlineTransparency = 0
                            hl.FillColor = isTargetBlock and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(150, 150, 150)
                            hl.OutlineColor = isTargetBlock and Color3.fromRGB(0, 255, 0) or Color3.fromRGB(200, 200, 200)
                            hl.Parent = folder

                            local basePart = block:IsA("Model") and block.PrimaryPart or block:FindFirstChildWhichIsA("BasePart", true) or block
                            if basePart then
                                local bb = Instance.new("BillboardGui")
                                bb.Adornee = basePart; bb.Size = UDim2.new(0, 120, 0, 30)
                                bb.StudsOffset = Vector3.new(0, 3, 0); bb.AlwaysOnTop = true
                                
                                local txt = Instance.new("TextLabel", bb)
                                txt.Size = UDim2.new(1, 0, 1, 0); txt.BackgroundTransparency = 1
                                txt.Text = blockName
                                txt.TextColor3 = isTargetBlock and Color3.fromRGB(0, 255, 100) or Color3.fromRGB(255, 255, 255)
                                txt.Font = Enum.Font.SourceSansBold; txt.TextSize = 14; txt.TextStrokeTransparency = 0 
                                txt.Parent = bb; bb.Parent = folder
                            end
                        end
                    end
                end
            end
        end
    end
end

function WildMiner:UsarPortal(destName)
    local portal = self.CachePortais[destName]
    if not portal then return end
    
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local State = Bot.State
    if State.WildSettings then State.WildSettings.IsMining = false end
    if self.ActiveTween then self.ActiveTween:Cancel(); self.ActiveTween = nil end
    
    local targetPart = nil
    for _, desc in ipairs(portal:GetDescendants()) do
        if desc:IsA("TouchTransmitter") and desc.Parent and desc.Parent:IsA("BasePart") then
            targetPart = desc.Parent
            break
        end
    end
    
    if not targetPart then targetPart = portal:FindFirstChild("Frame", true) or portal:FindFirstChildWhichIsA("BasePart", true) end
    if not targetPart and portal:IsA("BasePart") then targetPart = portal end
    if not targetPart then return end

    if firetouchinterest then
        firetouchinterest(hrp, targetPart, 0)
        task.wait(0.1)
        firetouchinterest(hrp, targetPart, 1)
        if Bot.Modules.Manager then Bot.Modules.Manager:AtualizarStatus("Teleportando via TouchInterest...") end
    end
end

local function EquipPickaxe()
    local char = LocalPlayer.Character
    if not char then return end
    if char:FindFirstChildWhichIsA("Tool") then return end 
    local backpack = LocalPlayer:FindFirstChild("Backpack")
    if backpack then
        for _, tool in ipairs(backpack:GetChildren()) do
            local lName = tool.Name:lower()
            if lName:find("axe") or lName:find("pickaxe") or lName:find("hammer") then
                char.Humanoid:EquipTool(tool); task.wait(0.2); return
            end
        end
    end
end

local function AtivarFantasma(char)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end
    local bv = hrp:FindFirstChild("BotHoverVel") or Instance.new("BodyVelocity")
    bv.Name = "BotHoverVel"; bv.MaxForce = Vector3.new(math.huge, math.huge, math.huge); bv.Velocity = Vector3.zero; bv.Parent = hrp
end

function WildMiner:BotMinerLoop()
    local State = Bot.State
    local Manager = Bot.Modules.Manager

    while State.WildSettings.IsMining do
        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not hrp then task.wait(1); continue end

        AtivarFantasma(char)
        self:MapearMundo() 
        self:AtualizarESP()

        local validTargets = {}
        for islandCat, subRegions in pairs(self.CacheBlocos) do
            for subRegName, blocksMap in pairs(subRegions) do
                for blockName, blockList in pairs(blocksMap) do
                    local key = subRegName .. "|" .. blockName
                    if State.WildSettings.SelectedBlocks[key] then
                        for _, block in ipairs(blockList) do
                            if block and block.Parent and block:FindFirstChild("Health") and block.Health.Value > 0 then
                                table.insert(validTargets, block)
                            end
                        end
                    end
                end
            end
        end

        if #validTargets == 0 then 
            if Manager then Manager:AtualizarStatus("Aguardando Spawn de Minérios Wild...") end
            task.wait(1); continue 
        end

        table.sort(validTargets, function(a, b)
            local posA = a:IsA("Model") and a:GetPivot().Position or a.Position
            local posB = b:IsA("Model") and b:GetPivot().Position or b.Position
            return (hrp.Position - posA).Magnitude < (hrp.Position - posB).Magnitude
        end)

        local targetBlock = validTargets[1]
        local basePos = targetBlock:IsA("Model") and targetBlock:GetPivot().Position or targetBlock.Position
        local targetCFrame = CFrame.new(basePos + Vector3.new(0, 4, 0))

        local dist = (hrp.Position - basePos).Magnitude
        if dist > 3 then
            local tempo = dist / State.WildSettings.TweenSpeed
            self.ActiveTween = TweenService:Create(hrp, TweenInfo.new(tempo, Enum.EasingStyle.Linear), {CFrame = targetCFrame})
            self.ActiveTween:Play()
            
            if Manager then Manager:AtualizarStatus("✈️ Voando para " .. targetBlock.Name) end

            while self.ActiveTween and self.ActiveTween.PlaybackState == Enum.PlaybackState.Playing do
                if not State.WildSettings.IsMining then self.ActiveTween:Cancel(); break end
                RunService.Heartbeat:Wait()
            end
            if not State.WildSettings.IsMining then break end
        end

        EquipPickaxe()

        while State.WildSettings.IsMining and targetBlock and targetBlock.Parent do
            local healthVal = targetBlock:FindFirstChild("Health")
            if not healthVal or healthVal.Value <= 0 then break end

            local stage = targetBlock:FindFirstChild("RockStage")
            local stageStr = stage and tostring(stage.Value) or "0"
            local hitPart = targetBlock:FindFirstChild(stageStr) or targetBlock:FindFirstChildWhichIsA("MeshPart")

            if hitPart then
                local hitPos = hitPart.Position
                local payload = {
                    Xoeoxuqilfgenamojfjmj = HIT_KEY,
                    part = hitPart,
                    block = targetBlock,
                    norm = hitPos,
                    pos = Vector3.new(0, 1, 0)
                }
                if Manager and Manager.HitRemote then
                    pcall(function() Manager.HitRemote:InvokeServer(payload) end)
                end
            else
                break 
            end
            task.wait(State.WildSettings.HitCooldown)
        end
        task.wait(0.1) 
    end

    local charEnd = LocalPlayer.Character
    local hrpEnd = charEnd and charEnd:FindFirstChild("HumanoidRootPart")
    if hrpEnd and hrpEnd:FindFirstChild("BotHoverVel") then hrpEnd.BotHoverVel:Destroy() end
    self.ActiveTween = nil
    if Manager then Manager:AtualizarStatus("Wild Miner Ocioso") end
end

-- Limpeza Nuclear para fechamento seguro da GUI
function WildMiner:LimparTudo()
    local State = Bot.State
    if State.WildSettings then State.WildSettings.IsMining = false end
    if self.ActiveTween then self.ActiveTween:Cancel(); self.ActiveTween = nil end
    
    local charEnd = LocalPlayer.Character
    local hrpEnd = charEnd and charEnd:FindFirstChild("HumanoidRootPart")
    if hrpEnd and hrpEnd:FindFirstChild("BotHoverVel") then hrpEnd.BotHoverVel:Destroy() end
    
    -- Busca e destrói de TODAS as camadas da interface
    local cg = pcall(function() return game:GetService("CoreGui").Name end) and game:GetService("CoreGui")
    local pg = LocalPlayer:FindFirstChild("PlayerGui")
    if cg and cg:FindFirstChild("WildernessEsp") then cg.WildernessEsp:Destroy() end
    if pg and pg:FindFirstChild("WildernessEsp") then pg.WildernessEsp:Destroy() end
end

function WildMiner:Alternar(valor)
    local State = Bot.State
    State.WildSettings.IsMining = valor
    
    if valor then
        if Bot.Modules.Miner then Bot.Modules.Miner:Alternar(false) end
        if Bot.Modules.Farmer then Bot.Modules.Farmer:AlternarAutoFazenda(false) end
        task.spawn(function() self:BotMinerLoop() end)
    else
        self:LimparTudo()
    end
end

return WildMiner