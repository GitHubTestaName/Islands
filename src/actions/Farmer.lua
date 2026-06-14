-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

-- ==========================================
-- ⚙️ CONFIGURAÇÕES DA AURA E LIMITES REAIS
-- ==========================================
local RAIO_AURA = 32 -- O alcance legítimo validado para não falhar no servidor
local ALTURA_PAIRANDO = 10
local PLANTIO_COOLDOWN = 3 -- Tempo de memória para não espamar o mesmo bloco com lag

local MoverConnection = nil
local AntiGravity = nil
local VizuParada = {}
local VizuAura = nil

local MemoriaPlantio = {}
local MemoriaColheita = {}

local function LimparVizuParada()
    for _, obj in ipairs(VizuParada) do
        if obj then obj:Destroy() end
    end
    VizuParada = {}
    if VizuAura then VizuAura:Destroy(); VizuAura = nil end
end

local function AtualizarVizuAura(posicao)
    LimparVizuParada()
    if not State.FarmSettings.ShowStopViz then return end

    -- Cilindro mostrando a Aura real do bot
    VizuAura = Instance.new("Part")
    VizuAura.Name = "IslandsFarm_Aura"
    VizuAura.Shape = Enum.PartType.Cylinder
    VizuAura.Anchored = true
    VizuAura.CanCollide = false
    VizuAura.CanTouch = false
    VizuAura.CanQuery = false
    VizuAura.Transparency = 0.85
    VizuAura.Color = Color3.fromRGB(0, 255, 100)
    VizuAura.Material = Enum.Material.Neon
    -- Rotaciona o cilindro para deitar no chão
    VizuAura.Size = Vector3.new(0.5, RAIO_AURA * 2, RAIO_AURA * 2)
    VizuAura.CFrame = CFrame.new(posicao.X, posicao.Y - ALTURA_PAIRANDO + 0.5, posicao.Z) * CFrame.Angles(0, 0, math.rad(90))
    VizuAura.Parent = workspace
    table.insert(VizuParada, VizuAura)

    local center = Instance.new("Part")
    center.Name = "IslandsFarm_StopCenter"
    center.Shape = Enum.PartType.Ball
    center.Anchored = true
    center.CanCollide = false
    center.CanTouch = false
    center.Transparency = 0.2
    center.Color = Color3.fromRGB(255, 255, 255)
    center.Material = Enum.Material.Neon
    center.Size = Vector3.new(1.5, 1.5, 1.5)
    center.Position = posicao
    center.Parent = workspace
    table.insert(VizuParada, center)
end

-- ==========================================
-- ✈️ FÍSICA E VOO
-- ==========================================
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
    hum.PlatformStand = true
    hrp.Anchored = false
    hrp.CFrame = CFrame.new(posicao)
    hrp.Velocity = Vector3.zero
    hrp.RotVelocity = Vector3.zero

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

    hrp.Anchored = false
    hum.PlatformStand = true

    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero
    AntiGravity.Parent = hrp

    local chegou = false
    local velocidade = State.FarmSettings.TweenSpeed or 30

    MoverConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarmingCrops or not hrp.Parent then PararVoo(true); chegou = true return end

        local posAtual = hrp.Position
        local dist = (destino - posAtual).Magnitude
        if dist <= 1.5 then chegou = true return end

        local step = math.min(velocidade * dt, dist)
        local dir = (destino - posAtual).Unit
        local novaPos = posAtual + (dir * step)

        hrp.CFrame = CFrame.new(novaPos, novaPos + dir)
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)

    while not chegou and State.AutoFarmingCrops do task.wait(0.05) end

    if State.AutoFarmingCrops then PairarEm(destino); return true end
    PararVoo(true)
    return false
end

-- ==========================================
-- 🧠 FILTROS E UTILIDADES DO JOGO
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

local function ObterNomeCulturaReal(Manager)
    local prioridade = State.FarmSettings.PrioritizePlant
    if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
        return prioridade:gsub("Seeds", ""):gsub("seeds", ""):gsub("%s+", "")
    end
    -- Pega a primeira do inventário filtrada
    for _, semente in ipairs(Manager:GetInventoryTools("Seed")) do
        if semente ~= "Nenhum item encontrado" and semente ~= "None Found" then
            if not State.SementeSelecionada or State.SementeSelecionada["All"] or State.SementeSelecionada[semente] then
                return semente:gsub("Seeds", ""):gsub("seeds", ""):gsub("%s+", "")
            end
        end
    end
    return nil
end

local function DispararRemoteSeguro(remote, payload)
    task.spawn(function()
        pcall(function()
            if remote:IsA("RemoteEvent") then remote:FireServer(payload)
            elseif remote:IsA("RemoteFunction") then remote:InvokeServer(payload) end
        end)
    end)
end

-- ==========================================
-- 🎯 O CORAÇÃO DO HARVEST AURA
-- ==========================================
local function LimparAura(Manager, char, Scanner, centroAura)
    local hrp = char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local sementeNome = ObterNomeCulturaReal(Manager)
    local pastaBlocks = ObterPastaBlocks()
    if not pastaBlocks then return end

    local params = OverlapParams.new()
    params.FilterDescendantsInstances = { pastaBlocks }
    params.FilterType = Enum.RaycastFilterType.Include

    local areaLimpa = false
    local tentativas = 0

    -- O LOOP IMPLACÁVEL: Só sai daqui quando a região estiver estéril de ações
    while not areaLimpa and State.AutoFarmingCrops do
        tentativas += 1
        if tentativas > 15 then break end -- Prevenção de loop infinito por bug do servidor

        -- 1. Faz um SCAN "AO VIVO" apenas na área da Aura
        local boxSize = Vector3.new(RAIO_AURA * 2, 40, RAIO_AURA * 2)
        local blocosNaAura = workspace:GetPartBoundsInBox(CFrame.new(centroAura) * CFrame.new(0, -10, 0), boxSize, params)
        
        local solos = {}
        local plantasOcupando = {}
        local tarefas = {}

        local tempoAtual = os.clock()

        -- 2. Separa a Realidade Atual
        for _, p in ipairs(blocosNaAura) do
            local root = Manager:ObterBlocoRaiz(p)
            if root and root.Name ~= "SelectionAnchor_Script" then
                local pos = ObterPosicao(root)
                if pos and (pos - centroAura).Magnitude <= RAIO_AURA then
                    local posGrid = Scanner:AlinharParaGrid(pos)
                    local key = CriarKey(posGrid)
                    local nome = root.Name:lower()

                    if nome ~= "trunk" and nome ~= "top" then
                        if EhSolo(nome) then
                            solos[key] = root
                        else
                            plantasOcupando[key] = true -- Marca a posição XYZ da planta
                            -- Se é planta e está madura
                            if root:FindFirstChild("Harvestable", true) then
                                -- Verifica cooldown anti-spam
                                if not MemoriaColheita[key] or (tempoAtual - MemoriaColheita[key] > 1) then
                                    table.insert(tarefas, { acao = "Colher", obj = root, pos = posGrid, key = key })
                                end
                            end
                        end
                    end
                end
            end
        end

        -- 3. Verifica Solos Vazios (A prova de fogo)
        if State.FarmSettings.AutoReplace and sementeNome then
            for keySolo, objSolo in pairs(solos) do
                local posSolo = Scanner:AlinharParaGrid(ObterPosicao(objSolo))
                local posPlantaCima = posSolo + Vector3.new(0, Config.BLOCK_SIZE, 0)
                local keyPlantaCima = CriarKey(posPlantaCima)

                -- Se a posição exatamente ACIMA do solo não tem planta, o buraco está VAZIO
                if not plantasOcupando[keyPlantaCima] then
                    if not MemoriaPlantio[keyPlantaCima] or (tempoAtual - MemoriaPlantio[keyPlantaCima] > PLANTIO_COOLDOWN) then
                        table.insert(tarefas, { acao = "Plantar", pos = posPlantaCima, key = keyPlantaCima })
                    end
                end
            end
        end

        -- 4. O Critério Absoluto de Mudança de Posição
        if #tarefas == 0 then
            areaLimpa = true
            break -- A Aura está 100% limpa! Vai para a próxima.
        end

        Manager:AtualizarStatus(string.format("Aura Ativa | Processando %d ações...", #tarefas))

        -- 5. Executa as Ações Assincronamente
        for _, t in ipairs(tarefas) do
            if not State.AutoFarmingCrops then break end

            if t.acao == "Colher" then
                MemoriaColheita[t.key] = tempoAtual
                local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = t.obj }
                DispararRemoteSeguro(Manager.HarvestRemote, payload)
                task.wait(State.FarmSettings.HarvestDelay or 0.01)

            elseif t.acao == "Plantar" then
                MemoriaPlantio[t.key] = tempoAtual
                local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(t.pos), blockType = sementeNome, upperBlock = false }
                DispararRemoteSeguro(Manager.PlaceRemote, payload)
                task.wait(State.FarmSettings.PlantDelay or 0.02)
            end
        end

        -- Respira para o Servidor atualizar os blocos no mundo antes de re-escanear
        task.wait(0.4) 
    end
end

-- ==========================================
-- 🚜 LÓGICA EXTERNA DO FARMER
-- ==========================================
function Farmer:AlternarAutoFazenda(valor)
    State.AutoFarmingCrops = valor
    local Manager = Bot.Modules.Manager

    if not valor then
        if Manager then Manager:AtualizarStatus("Ocioso") end
        PararVoo(true)
        return
    end

    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then
        State.AutoFarmingCrops = false; return
    end

    task.spawn(function()
        while State.AutoFarmingCrops do
            if not Scanner.AncoraPart then break end
            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then task.wait(1) continue end

            MemoriaPlantio = {}
            MemoriaColheita = {}
            if not State.FarmSettings.ShowStopViz then LimparVizuParada() end

            -- 1. Cria a Grade Absoluta do Seletor (Centros de Aura)
            local ancPos = Scanner.AncoraPart.Position
            local ancSize = Scanner.AncoraPart.Size
            local passoGrid = 45 -- Permite sobreposição perfeita de auras de raio 32
            
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

            -- 2. Ordena os centros para o mais próximo de onde você está agora
            table.sort(centrosAura, function(a, b)
                return (char.HumanoidRootPart.Position - a).Magnitude < (char.HumanoidRootPart.Position - b).Magnitude
            end)

            -- 3. Visita e Limpa cada Aura
            for i, centro in ipairs(centrosAura) do
                if not State.AutoFarmingCrops then break end
                
                Manager:AtualizarStatus(string.format("Indo p/ Aura %d/%d", i, #centrosAura))
                AtualizarVizuAura(centro)

                if State.FarmSettings.TweenToTarget then
                    VoarParaFisico(centro)
                else
                    PairarEm(centro)
                end
                
                task.wait(0.2) -- Estabiliza a física

                -- O ASPIRADOR ABSOLUTO
                LimparAura(Manager, char, Scanner, centro)
            end

            Manager:AtualizarStatus("Fazenda Otimizada! Aguardando Crescimento...")
            task.wait(1.5)
        end
        PararVoo(true)
    end)
end

return Farmer