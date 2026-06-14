-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

local ALCANCE_COLETA = 36 -- Alcance conservador e seguro (o máximo do servidor é ~40)
local ALTURA_PAIRANDO = 10
local PLANTIO_COOLDOWN = 8

local MoverConnection = nil
local AntiGravity = nil
local PlantiosRecentes = {}
local VizuParada = {}

local function LimparVizuParada()
    for _, obj in ipairs(VizuParada) do
        if obj then obj:Destroy() end
    end
    VizuParada = {}
end

local function AtualizarVizuParada(posicao)
    LimparVizuParada()
    if not State.FarmSettings.ShowStopViz then return end

    local area = Instance.new("Part")
    area.Name = "IslandsFarm_StopArea"
    area.Anchored = true
    area.CanCollide = false
    area.CanTouch = false
    area.CanQuery = false
    area.Transparency = 0.82
    area.Color = Color3.fromRGB(255, 210, 40)
    area.Material = Enum.Material.Neon
    area.Size = Vector3.new(ALCANCE_COLETA * 2, 0.18, ALCANCE_COLETA * 2)
    area.Position = Vector3.new(posicao.X, posicao.Y - ALTURA_PAIRANDO + 0.35, posicao.Z)
    area.Parent = workspace
    table.insert(VizuParada, area)

    local center = Instance.new("Part")
    center.Name = "IslandsFarm_StopCenter"
    center.Shape = Enum.PartType.Ball
    center.Anchored = true
    center.CanCollide = false
    center.CanTouch = false
    center.CanQuery = false
    center.Transparency = 0.25
    center.Color = Color3.fromRGB(0, 180, 255)
    center.Material = Enum.Material.Neon
    center.Size = Vector3.new(1.5, 1.5, 1.5)
    center.Position = posicao
    center.Parent = workspace
    table.insert(VizuParada, center)
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

local function VoarParaFisico(destino, manterPairando)
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
    local velocidade = State.FarmSettings.TweenSpeed or 25

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

    if manterPairando and State.AutoFarmingCrops then
        PairarEm(destino)
        return true
    end

    PararVoo(true)
    return State.AutoFarmingCrops
end

local function IrParaParada(posicao)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return false end

    AtualizarVizuParada(posicao)

    if State.FarmSettings.TweenToTarget then
        return VoarParaFisico(posicao, true)
    end

    PairarEm(posicao)
    return true
end

-- ==========================================
-- 🧠 FILTROS E UTILIDADES
-- ==========================================
local function LimparNomeSemente(nome)
    return tostring(nome or ""):gsub("Seeds", ""):gsub("seeds", ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function NormalizarNome(nome)
    return tostring(nome or ""):lower():gsub("seeds", ""):gsub("seed", ""):gsub("sapling", ""):gsub("spore", ""):gsub("crop", ""):gsub("plant", ""):gsub("%s+", ""):gsub("_", ""):gsub("%-", "")
end

local function ObterNomeCultura(nome)
    local normalizado = NormalizarNome(nome)
    return normalizado ~= "" and normalizado or nil
end

local function EhSolo(nome)
    local n = tostring(nome or ""):lower()
    return n:find("grass") or n:find("dirt") or n:find("soil") or n:find("plowed") or n:find("farm")
end

local function EhAravel(nome)
    local n = tostring(nome or ""):lower()
    return n:find("grass") or n:find("dirt")
end

local function EhSoloPlantavel(nome)
    local n = tostring(nome or ""):lower()
    return n:find("soil") or n:find("plowed") or n:find("farm")
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

local function DistanciaXZ(a, b)
    local dx = a.X - b.X
    local dz = a.Z - b.Z
    return math.sqrt((dx * dx) + (dz * dz))
end

local function ObterPastaBlocks()
    local islands = workspace:FindFirstChild("Islands")
    if not islands then return nil end
    for _, island in ipairs(islands:GetChildren()) do
        local blocks = island:FindFirstChild("Blocks")
        if blocks then return blocks end
    end
    return nil
end

local function ObterPartesDoSeletor(scanner)
    local blocks = ObterPastaBlocks()
    local params = nil
    if blocks then
        params = OverlapParams.new()
        params.FilterDescendantsInstances = { blocks }
        params.FilterType = Enum.RaycastFilterType.Include
    end
    local querySize = scanner.AncoraPart.Size - Vector3.new(0.2, 0.2, 0.2)
    return workspace:GetPartBoundsInBox(scanner.AncoraPart.CFrame, querySize, params)
end

local function ObterSementesParaPlantio(Manager)
    local stateSementes = State.SementeSelecionada
    if type(stateSementes) ~= "table" then stateSementes = { ["All"] = true } end

    local prioridade = State.FarmSettings.PrioritizePlant
    local prioridadeNorm = nil
    if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
        prioridadeNorm = ObterNomeCultura(prioridade)
    end

    local selecionadas = {}
    local jaFoi = {}
    local prioridadeItem = nil

    for _, sementeNome in ipairs(Manager:GetInventoryTools("Seed")) do
        if sementeNome ~= "Nenhum item encontrado" and sementeNome ~= "None Found" then
            if stateSementes["All"] or stateSementes[sementeNome] then
                local limpa = LimparNomeSemente(sementeNome)
                local normalizada = ObterNomeCultura(sementeNome)
                if prioridadeNorm and normalizada == prioridadeNorm then
                    prioridadeItem = limpa
                elseif not jaFoi[limpa] then
                    table.insert(selecionadas, limpa)
                    jaFoi[limpa] = true
                end
            end
        end
    end

    if prioridadeItem then table.insert(selecionadas, 1, prioridadeItem) end
    return selecionadas
end

local function EscolherSementeParaPlantio(Manager)
    local sementes = ObterSementesParaPlantio(Manager)
    return sementes[1]
end

local function MapearFazenda(Scanner, Manager)
    local scan = { solos = {}, plantas = {}, soloOcupado = {} }
    local processados = {}
    local bounds = ObterPartesDoSeletor(Scanner)

    for _, p in ipairs(bounds) do
        local root = Manager:ObterBlocoRaiz(p)
        if root and not processados[root] and root.Name ~= "SelectionAnchor_Script" then
            processados[root] = true
            local n = root.Name:lower()

            if n ~= "trunk" and n ~= "top" then
                local pos = ObterPosicao(root)
                if pos then
                    local posGrid = Scanner:AlinharParaGrid(pos)
                    local key = CriarKey(posGrid)

                    if EhSolo(root.Name) then
                        scan.solos[key] = root
                    else
                        local keySolo = CriarKey(posGrid - Vector3.new(0, Config.BLOCK_SIZE, 0))
                        scan.plantas[key] = root
                        scan.soloOcupado[keySolo] = root
                    end
                end
            end
        end
    end
    return scan
end

-- ==========================================
-- 🛠️ COMUNICAÇÃO SEGURA COM O SERVIDOR
-- ==========================================
local function DispararRemoteSeguro(remote, payload)
    -- Usa task.spawn para garantir que o script principal (loops e espiral) NÃO trave se o servidor demorar
    task.spawn(function()
        pcall(function()
            if remote:IsA("RemoteEvent") then
                remote:FireServer(payload)
            elseif remote:IsA("RemoteFunction") then
                remote:InvokeServer(payload)
            end
        end)
    end)
end

local function DispararTarefa(Manager, char, tarefa)
    if tarefa.acao == "Colher" then
        if tarefa.objP and tarefa.objP:IsDescendantOf(workspace) then
            local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = tarefa.objP }
            DispararRemoteSeguro(Manager.HarvestRemote, payload)
            return true
        end
    elseif tarefa.acao == "Arar" then
        if tarefa.objS and tarefa.objS:IsDescendantOf(workspace) then
            DispararRemoteSeguro(Manager.PlowRemote, { block = tarefa.objS })
            return true
        end
    elseif tarefa.acao == "Plantar" then
        local sementeNomeReal = EscolherSementeParaPlantio(Manager)
        if sementeNomeReal and not PlantiosRecentes[tarefa.key] then
            PlantiosRecentes[tarefa.key] = os.clock()
            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(tarefa.pos), blockType = sementeNomeReal, upperBlock = false }
            DispararRemoteSeguro(Manager.PlaceRemote, payload)
            return true
        end
    elseif tarefa.acao == "ColocarGrama" then
        local blockGrass = LocalPlayer.Backpack:FindFirstChild("grass") or char:FindFirstChild("grass")
        if blockGrass then
            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(tarefa.posSolo), blockType = blockGrass.Name, upperBlock = false }
            DispararRemoteSeguro(Manager.PlaceRemote, payload)
            return true
        end
    end
    return false
end

-- ==========================================
-- 🎯 ALGORITMO PREMIUM: CHUNKING MATEMÁTICO E ESPIRAL DE COLHEITA
-- ==========================================
local function ExecutarParadasEstrategicas(Manager, char, tarefasGerais, rotulo, Scanner)
    if #tarefasGerais == 0 then return end

    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    -- 1. Chunking 2D Cartesian (Divisão Geográfica de Alta Eficiência)
    local paradas = {}
    local passo = 45 -- O alcance máximo é ~38. 45 studs entre centros garante sobreposição quase perfeita
    local ancPos = Scanner.AncoraPart.Position
    local ancSize = Scanner.AncoraPart.Size
    
    local minX = ancPos.X - (ancSize.X / 2)
    local maxX = ancPos.X + (ancSize.X / 2)
    local minZ = ancPos.Z - (ancSize.Z / 2)
    local maxZ = ancPos.Z + (ancSize.Z / 2)

    -- Se o plot for pequeno, fica exatamente no meio e pega tudo de uma vez (A Posição 23 do seu exemplo!)
    if ancSize.X <= passo and ancSize.Z <= passo then
        table.insert(paradas, ancPos + Vector3.new(0, ALTURA_PAIRANDO, 0))
    else
        for x = minX + (passo/2), maxX + (passo/2), passo do
            for z = minZ + (passo/2), maxZ + (passo/2), passo do
                local cx = math.min(x, maxX)
                local cz = math.min(z, maxZ)
                table.insert(paradas, Vector3.new(cx, ancPos.Y + ALTURA_PAIRANDO, cz))
            end
        end
    end

    local totalInicial = #tarefasGerais
    local concluidas = 0

    -- 2. Otimização de Rota (Viaja para as zonas mais perto primeiro)
    table.sort(paradas, function(a, b)
        return (hrp.Position - a).Magnitude < (hrp.Position - b).Magnitude
    end)

    for i, alvoParada in ipairs(paradas) do
        if not State.AutoFarmingCrops then break end
        if #tarefasGerais == 0 then break end

        -- 3. Identifica as tarefas que podem ser colhidas DESTA parada
        local tarefasDestaParada = {}
        local tarefasRestantes = {}

        for _, t in ipairs(tarefasGerais) do
            if DistanciaXZ(alvoParada, t.pos) <= ALCANCE_COLETA then
                table.insert(tarefasDestaParada, t)
            else
                table.insert(tarefasRestantes, t)
            end
        end

        tarefasGerais = tarefasRestantes -- Passa o resto para a próxima zona analisar

        if #tarefasDestaParada > 0 then
            if Manager then Manager:AtualizarStatus(rotulo .. " | Voando p/ Zona " .. i .. "/" .. #paradas) end
            
            -- Voa pro centro do Chunk (Ex: Posição 23)
            if not IrParaParada(alvoParada) then break end
            task.wait(0.15) -- Respira 150ms para a física do boneco estabilizar no servidor
            
            -- 4. O CONTORNO EM ESPIRAL!
            -- Organiza as plantas do centro (debaixo do seu pé) em direção às bordas.
            table.sort(tarefasDestaParada, function(a, b)
                return DistanciaXZ(alvoParada, a.pos) < DistanciaXZ(alvoParada, b.pos)
            end)

            -- Inicia a varredura espiral
            for _, tarefa in ipairs(tarefasDestaParada) do
                if not State.AutoFarmingCrops then break end
                
                if DispararTarefa(Manager, char, tarefa) then
                    concluidas += 1
                    if Manager then
                        Manager:AtualizarStatus(string.format("%s | %d/%d (Zona %d)", rotulo, concluidas, totalInicial, i))
                    end

                    -- Os tempos de cooldown da UI (ex: 0.001) funcionam muito bem agora!
                    if tarefa.acao == "Colher" then
                        task.wait(State.FarmSettings.HarvestDelay or 0.02)
                    elseif tarefa.acao == "Plantar" then
                        task.wait(State.FarmSettings.PlantDelay or 0.05)
                    else
                        task.wait(0.02)
                    end
                end
            end
            
            -- Descansa levemente antes de voar para a próxima "Casa 28"
            task.wait(0.1)
        end
    end
end

-- ==========================================
-- 🚜 LÓGICA EXTERNA DO FARMER
-- ==========================================
function Farmer:ArarTerra()
    local Manager = Bot.Modules.Manager
    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then return end

    local bounds = ObterPartesDoSeletor(Scanner)
    task.spawn(function()
        local processados = {}
        for _, p in ipairs(bounds) do
            local root = Manager:ObterBlocoRaiz(p)
            if root and not processados[root] and EhAravel(root.Name) then
                processados[root] = true
                DispararRemoteSeguro(Manager.PlowRemote, { block = root })
                task.wait(0.02)
            end
        end
    end)
end

function Farmer:AlternarAutoFazenda(valor)
    State.AutoFarmingCrops = valor
    local Manager = Bot.Modules.Manager

    if not valor then
        if Manager then Manager:AtualizarStatus("Ocioso") end
        PararVoo(true)
        return
    end

    if State.FarmSettings.AutoUseSelectedSave and State.FarmSettings.CurrentSaveName then
        local PlotManager = Bot.Modules.PlotManager
        local plots = PlotManager:ObterTodos()
        local plot = plots["Farming_" .. State.FarmSettings.CurrentSaveName]
        if plot and State.ScannerFazenda then
            State.ScannerFazenda:CarregarPlot(Vector3.new(plot.PosX, plot.PosY, plot.PosZ), Vector3.new(plot.SizeX, plot.SizeY, plot.SizeZ))
        end
    end

    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then
        State.AutoFarmingCrops = false
        return
    end

    task.spawn(function()
        while State.AutoFarmingCrops do
            if not Scanner.AncoraPart then break end

            local char = LocalPlayer.Character
            if not char or not char:FindFirstChild("HumanoidRootPart") then task.wait(1) continue end

            -- Limpa a lista anti-spam de plantar para a nova rodada
            local agora = os.clock()
            for key, instante in pairs(PlantiosRecentes) do
                if agora - instante > PLANTIO_COOLDOWN then PlantiosRecentes[key] = nil end
            end
            if not State.FarmSettings.ShowStopViz then LimparVizuParada() end

            -- 1. Scanneia toda a Fazenda Verde
            local scan = MapearFazenda(Scanner, Manager)
            local tarefasColheita = {}

            -- 2. Tabela de Colheita
            for key, plantaObj in pairs(scan.plantas) do
                if plantaObj and plantaObj:FindFirstChild("Harvestable", true) then
                    local pos = ObterPosicao(plantaObj)
                    if pos then
                        table.insert(tarefasColheita, {
                            acao = "Colher",
                            key = key,
                            pos = Scanner:AlinharParaGrid(pos),
                            objP = plantaObj
                        })
                    end
                end
            end

            if #tarefasColheita > 0 then
                -- Chama o algoritmo mestre de Espiral + Chunking!
                ExecutarParadasEstrategicas(Manager, char, tarefasColheita, "Coletando", Scanner)
                if Manager then Manager:AtualizarStatus("Conferindo plantio novo...") end
                task.wait(0.3)
                continue
            end

            -- 3. Tabela de Manutenção (Plantar/Arar)
            local sementesPlantio = ObterSementesParaPlantio(Manager)
            local tarefasManutencao = {}
            local plantiosPlanejados = {}

            for keySolo, blocoSolo in pairs(scan.solos) do
                local posSolo = Scanner:AlinharParaGrid(ObterPosicao(blocoSolo))
                local posPlanta = posSolo + Vector3.new(0, Config.BLOCK_SIZE, 0)
                local keyPlanta = CriarKey(posPlanta)
                local nSolo = blocoSolo.Name

                if EhAravel(nSolo) and State.FarmSettings.PlowGrass then
                    table.insert(tarefasManutencao, {
                        acao = "Arar", key = keySolo, pos = posSolo, objS = blocoSolo
                    })
                elseif EhSoloPlantavel(nSolo) and State.FarmSettings.AutoReplace and #sementesPlantio > 0 then
                    if not scan.soloOcupado[keySolo] and not PlantiosRecentes[keyPlanta] and not plantiosPlanejados[keyPlanta] then
                        plantiosPlanejados[keyPlanta] = true
                        table.insert(tarefasManutencao, {
                            acao = "Plantar", key = keyPlanta, pos = posPlanta, posSolo = posSolo, objS = blocoSolo
                        })
                    end
                end
            end

            if #tarefasManutencao > 0 then
                ExecutarParadasEstrategicas(Manager, char, tarefasManutencao, "Arrumando Solo", Scanner)
                if Manager then Manager:AtualizarStatus("Conferindo ciclo...") end
                task.wait(0.3)
            else
                if Manager then Manager:AtualizarStatus("Fazenda 100% otimizada! Aguardando...") end
                task.wait(1)
            end
        end

        PararVoo(true)
        if Manager then Manager:AtualizarStatus("Auto-Fazenda Desligada") end
    end)
end

return Farmer