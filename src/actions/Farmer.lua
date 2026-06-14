-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

local ALCANCE_COLETA = 30 -- Reduzido para 30 para ter 100% de garantia do Servidor (Segurança máxima)
local ALTURA_PAIRANDO = 8

local MoverConnection = nil
local AntiGravity = nil
local VizuParada = {}

-- ==========================================
-- 🛠️ SISTEMA DE FILA (WORKER THREAD PREMIUM)
-- ==========================================
local FilaAcoes = {}
local EmProcessamento = {}
local WorkerAtivo = false

local function IniciarWorker(Manager)
    if WorkerAtivo then return end
    WorkerAtivo = true

    task.spawn(function()
        while State.AutoFarmingCrops do
            if #FilaAcoes > 0 then
                local tarefa = table.remove(FilaAcoes, 1)
                local char = LocalPlayer.Character
                local hrp = char and char:FindFirstChild("HumanoidRootPart")
                
                if hrp then
                    -- Confirma a distância uma última vez antes de atirar no servidor
                    local dist = (hrp.Position - tarefa.posAtual).Magnitude
                    if dist <= ALCANCE_COLETA + 5 then 
                        if tarefa.acao == "Colher" then
                            local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = tarefa.obj }
                            pcall(function() Manager.HarvestRemote:InvokeServer(payload) end)
                            
                        elseif tarefa.acao == "Plantar" then
                            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(tarefa.posGrid), blockType = tarefa.semente, upperBlock = false }
                            pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
                        end
                        
                        -- Este delay é o SEGREDO! Impede o "Network Choking" e o spam no rspy.
                        task.wait(0.03) 
                    else
                        -- Se ficou muito longe, tira do processamento para ser escaneado de novo depois
                        EmProcessamento[tarefa.key] = nil
                    end
                end
            else
                -- Fila vazia, respira
                task.wait(0.1)
            end
        end
        WorkerAtivo = false
    end)
end

-- ==========================================
-- ✈️ FÍSICA E VOO
-- ==========================================
local function LimparVizuParada()
    for _, obj in ipairs(VizuParada) do if obj then obj:Destroy() end end
    VizuParada = {}
end

local function AtualizarVizu(posicao)
    LimparVizuParada()
    if not State.FarmSettings.ShowStopViz then return end

    local area = Instance.new("Part")
    area.Name = "IslandsFarm_Aura"
    area.Shape = Enum.PartType.Cylinder
    area.Anchored = true; area.CanCollide = false; area.CanTouch = false; area.CanQuery = false
    area.Transparency = 0.85; area.Color = Color3.fromRGB(0, 255, 100); area.Material = Enum.Material.Neon
    area.Size = Vector3.new(0.5, ALCANCE_COLETA * 2, ALCANCE_COLETA * 2)
    area.CFrame = CFrame.new(posicao.X, posicao.Y - ALTURA_PAIRANDO + 0.5, posicao.Z) * CFrame.Angles(0, 0, math.rad(90))
    area.Parent = workspace
    table.insert(VizuParada, area)
end

local function PararVoo(limparVizu)
    if MoverConnection then MoverConnection:Disconnect(); MoverConnection = nil end
    if AntiGravity then AntiGravity:Destroy(); AntiGravity = nil end
    if limparVizu then LimparVizuParada() end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then hrp.Anchored = false; hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero end
    end
end

local function PairarEm(posicao)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    PararVoo(false)
    hum.PlatformStand = true; hrp.Anchored = false
    hrp.CFrame = CFrame.new(posicao)
    hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero

    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero
    AntiGravity.Parent = hrp
end

local function VoarParaFisico(destino)
    PararVoo(false)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    hrp.Anchored = false; hum.PlatformStand = true
    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero; AntiGravity.Parent = hrp

    local chegou = false
    local velocidade = State.FarmSettings.TweenSpeed or 35

    MoverConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarmingCrops or not hrp.Parent then PararVoo(true); chegou = true return end

        local posAtual = hrp.Position
        local dist = (destino - posAtual).Magnitude
        if dist <= 1.5 then chegou = true return end

        local step = math.min(velocidade * dt, dist)
        local dir = (destino - posAtual).Unit
        local novaPos = posAtual + (dir * step)

        hrp.CFrame = CFrame.new(novaPos, novaPos + dir)
        hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero
    end)

    while not chegou and State.AutoFarmingCrops do task.wait(0.05) end

    if State.AutoFarmingCrops then 
        PairarEm(destino)
        task.wait(0.25) -- O SEGREDO DO DESYNC! Dá tempo para o servidor confirmar que você chegou.
        return true 
    end
    PararVoo(true)
    return false
end

-- ==========================================
-- 🧠 FILTROS E UTILIDADES
-- ==========================================
local function ObterPastaBlocks()
    local islands = workspace:FindFirstChild("Islands")
    if not islands then return nil end
    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then return blocks end
    end
    return nil
end

local function ObterPosicao(root)
    if not root then return nil end
    if root:IsA("Model") then return root:GetPivot().Position end
    if root:IsA("BasePart") then return root.Position end
    return nil
end

local function CriarKey(pos)
    return string.format("%.1f_%.1f_%.1f", pos.X, pos.Y, pos.Z)
end

local function EhSolo(nome)
    local n = tostring(nome or ""):lower()
    return n:find("grass") or n:find("dirt") or n:find("soil") or n:find("plowed") or n:find("farm")
end

local function ObterSementeEmUso(Manager)
    local prioridade = State.FarmSettings.PrioritizePlant
    if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
        return prioridade:gsub("Seeds", ""):gsub("seeds", ""):gsub("%s+", "")
    end
    for _, semente in ipairs(Manager:GetInventoryTools("Seed")) do
        if semente ~= "Nenhum item encontrado" and semente ~= "None Found" then
            if not State.SementeSelecionada or State.SementeSelecionada["All"] or State.SementeSelecionada[semente] then
                return semente:gsub("Seeds", ""):gsub("seeds", ""):gsub("%s+", "")
            end
        end
    end
    return nil
end

-- ==========================================
-- 🎯 SCANNER E PROCESSADOR DA AURA
-- ==========================================
local function LimparAura(Manager, char, Scanner, centroAura)
    local sementeNome = ObterSementeEmUso(Manager)
    local pastaBlocks = ObterPastaBlocks()
    if not pastaBlocks then return end

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { pastaBlocks }
    params.FilterType = Enum.RaycastFilterType.Include

    local boxSize = Vector3.new(ALCANCE_COLETA * 2, 40, ALCANCE_COLETA * 2)
    local posAtualizado = CFrame.new(centroAura) * CFrame.new(0, -10, 0)
    
    local áreaAindaTemTrabalho = true
    local ciclosVazios = 0

    while áreaAindaTemTrabalho and State.AutoFarmingCrops do
        local blocosNaAura = workspace:GetPartBoundsInBox(posAtualizado, boxSize, params)
        local solos = {}
        local plantasOcupando = {}
        local itensDescobertos = 0

        for _, p in ipairs(blocosNaAura) do
            local root = Manager:ObterBlocoRaiz(p)
            if root and root.Name ~= "SelectionAnchor_Script" then
                local pos = ObterPosicao(root)
                if pos and (pos - centroAura).Magnitude <= ALCANCE_COLETA then
                    local posGrid = Scanner:AlinharParaGrid(pos)
                    local key = CriarKey(posGrid)
                    local nome = root.Name:lower()

                    if nome ~= "trunk" and nome ~= "top" then
                        if EhSolo(nome) then
                            solos[key] = root
                        else
                            plantasOcupando[key] = true
                            if root:FindFirstChild("Harvestable", true) then
                                if not EmProcessamento[key] then
                                    EmProcessamento[key] = true
                                    table.insert(FilaAcoes, { acao = "Colher", obj = root, posAtual = pos, posGrid = posGrid, key = key })
                                    itensDescobertos += 1
                                end
                            end
                        end
                    end
                end
            end
        end

        if State.FarmSettings.AutoReplace and sementeNome then
            for keySolo, objSolo in pairs(solos) do
                local posSoloReal = ObterPosicao(objSolo)
                local posSoloGrid = Scanner:AlinharParaGrid(posSoloReal)
                local posPlantaCima = posSoloGrid + Vector3.new(0, Config.BLOCK_SIZE, 0)
                local keyPlantaCima = CriarKey(posPlantaCima)

                if not plantasOcupando[keyPlantaCima] and not EmProcessamento[keyPlantaCima] then
                    EmProcessamento[keyPlantaCima] = true
                    table.insert(FilaAcoes, { acao = "Plantar", semente = sementeNome, posAtual = posPlantaCima, posGrid = posPlantaCima, key = keyPlantaCima })
                    itensDescobertos += 1
                end
            end
        end

        -- Se a fila interna está esvaziando e não achamos itens novos, a área está limpa!
        if itensDescobertos == 0 and #FilaAcoes == 0 then
            ciclosVazios += 1
            if ciclosVazios > 1 then
                áreaAindaTemTrabalho = false
            end
        else
            ciclosVazios = 0
            Manager:AtualizarStatus(string.format("Aura Ativa | Processando %d itens...", #FilaAcoes))
        end

        task.wait(0.5) -- O Scanner respira enquanto o Worker Thread trabalha na fila
    end
end

-- ==========================================
-- 🚜 LÓGICA EXTERNA
-- ==========================================
function Farmer:AlternarAutoFazenda(valor)
    State.AutoFarmingCrops = valor
    local Manager = Bot.Modules.Manager

    if not valor then
        if Manager then Manager:AtualizarStatus("Ocioso") end
        PararVoo(true)
        FilaAcoes = {}
        EmProcessamento = {}
        return
    end

    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then
        State.AutoFarmingCrops = false; return
    end

    IniciarWorker(Manager)

    task.spawn(function()
        while State.AutoFarmingCrops do
            if not Scanner.AncoraPart then break end
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then task.wait(1) continue end

            FilaAcoes = {}
            EmProcessamento = {}
            if not State.FarmSettings.ShowStopViz then LimparVizuParada() end

            local ancPos = Scanner.AncoraPart.Position
            local ancSize = Scanner.AncoraPart.Size
            local passoGrid = 35 
            
            local centrosAura = {}
            local minX, maxX = ancPos.X - (ancSize.X / 2), ancPos.X + (ancSize.X / 2)
            local minZ, maxZ = ancPos.Z - (ancSize.Z / 2), ancPos.Z + (ancSize.Z / 2)

            if ancSize.X <= passoGrid and ancSize.Z <= passoGrid then
                table.insert(centrosAura, ancPos + Vector3.new(0, ALTURA_PAIRANDO, 0))
            else
                for x = minX + (passoGrid/2), maxX + (passoGrid/2), passoGrid do
                    for z = minZ + (passoGrid/2), maxZ + (passoGrid/2), passoGrid do
                        table.insert(centrosAura, Vector3.new(math.min(x, maxX), ancPos.Y + ALTURA_PAIRANDO, math.min(z, maxZ)))
                    end
                end
            end

            table.sort(centrosAura, function(a, b)
                return (char.HumanoidRootPart.Position - a).Magnitude < (char.HumanoidRootPart.Position - b).Magnitude
            end)

            for i, centro in ipairs(centrosAura) do
                if not State.AutoFarmingCrops then break end
                
                Manager:AtualizarStatus(string.format("Indo p/ Aura %d/%d", i, #centrosAura))
                AtualizarVizu(centro)

                if State.FarmSettings.TweenToTarget then
                    VoarParaFisico(centro)
                else
                    PairarEm(centro)
                end

                LimparAura(Manager, char, Scanner, centro)
            end

            Manager:AtualizarStatus("Fazenda Otimizada! Aguardando Crescimento...")
            task.wait(1.5)
        end
        PararVoo(true)
    end)
end

return Farmer