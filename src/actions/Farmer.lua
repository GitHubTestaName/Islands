-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

local ALCANCE_COLETA = 37
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

    if MoverConnection then MoverConnection:Disconnect(); MoverConnection = nil end
    if AntiGravity then AntiGravity:Destroy(); AntiGravity = nil end

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

local function LimparNomeSemente(nome)
    return tostring(nome or "")
        :gsub("Seeds", "")
        :gsub("seeds", "")
        :gsub("^%s+", "")
        :gsub("%s+$", "")
end

local function NormalizarNome(nome)
    return tostring(nome or "")
        :lower()
        :gsub("seeds", "")
        :gsub("seed", "")
        :gsub("sapling", "")
        :gsub("spore", "")
        :gsub("crop", "")
        :gsub("plant", "")
        :gsub("%s+", "")
        :gsub("_", "")
        :gsub("%-", "")
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
            local entra = stateSementes["All"] or stateSementes[sementeNome]
            if entra then
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

    if prioridadeItem then
        table.insert(selecionadas, 1, prioridadeItem)
    end

    return selecionadas
end

local function EscolherSementeParaPlantio(Manager)
    local sementes = ObterSementesParaPlantio(Manager)
    return sementes[1]
end

local function LimparPlantiosRecentes()
    local agora = os.clock()
    for key, instante in pairs(PlantiosRecentes) do
        if agora - instante > PLANTIO_COOLDOWN then
            PlantiosRecentes[key] = nil
        end
    end
end

local function MapearFazenda(Scanner, Manager)
    local scan = {
        solos = {},
        plantas = {},
        soloOcupado = {}
    }

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

local function EscolherMelhorParada(tarefas, posAtual)
    local melhor = nil
    local melhorQtd = -1
    local melhorDist = math.huge

    for _, candidata in ipairs(tarefas) do
        local qtd = 0
        for _, tarefa in ipairs(tarefas) do
            if DistanciaXZ(candidata.pos, tarefa.pos) <= ALCANCE_COLETA then
                qtd += 1
            end
        end

        local dist = DistanciaXZ(posAtual, candidata.pos)
        if qtd > melhorQtd or (qtd == melhorQtd and dist < melhorDist) then
            melhor = candidata
            melhorQtd = qtd
            melhorDist = dist
        end
    end

    if not melhor then return nil, 0 end
    return melhor.pos + Vector3.new(0, ALTURA_PAIRANDO, 0), melhorQtd
end

local function DispararTarefa(Manager, char, tarefa)
    if tarefa.acao == "Colher" then
        if tarefa.objP and tarefa.objP:IsDescendantOf(workspace) then
            local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = tarefa.objP }
            pcall(function() Manager.HarvestRemote:InvokeServer(payload) end)
            return true
        end
    elseif tarefa.acao == "Arar" then
        if tarefa.objS and tarefa.objS:IsDescendantOf(workspace) then
            pcall(function() Manager.PlowRemote:InvokeServer({ block = tarefa.objS }) end)
            return true
        end
    elseif tarefa.acao == "Plantar" then
        local sementeNomeReal = EscolherSementeParaPlantio(Manager)
        if sementeNomeReal and not PlantiosRecentes[tarefa.key] then
            PlantiosRecentes[tarefa.key] = os.clock()
            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(tarefa.pos), blockType = sementeNomeReal, upperBlock = false }
            pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
            return true
        end
    elseif tarefa.acao == "ColocarGrama" then
        local blockGrass = LocalPlayer.Backpack:FindFirstChild("grass") or char:FindFirstChild("grass")
        if blockGrass then
            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(tarefa.posSolo), blockType = blockGrass.Name, upperBlock = false }
            pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
            return true
        end
    end

    return false
end

local function ProcessarTarefasPorParada(Manager, char, tarefas, rotulo)
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    if not hrp then return end

    local totalInicial = #tarefas
    local concluidas = 0
    local paradaIndex = 0

    while #tarefas > 0 and State.AutoFarmingCrops do
        paradaIndex += 1
        local alvo, alcancePrevisto = EscolherMelhorParada(tarefas, hrp.Position)
        if not alvo then break end

        if Manager then
            Manager:AtualizarStatus(rotulo .. " | parada " .. paradaIndex .. " | alcance: " .. alcancePrevisto)
        end

        if not IrParaParada(alvo) then break end
        task.wait(0.15)

        local restantes = {}
        local disparadasNestaParada = 0

        for _, tarefa in ipairs(tarefas) do
            if DistanciaXZ(alvo, tarefa.pos) <= ALCANCE_COLETA then
                if DispararTarefa(Manager, char, tarefa) then
                    concluidas += 1
                    disparadasNestaParada += 1
                    if Manager then
                        Manager:AtualizarStatus(rotulo .. " | " .. concluidas .. "/" .. totalInicial .. " no seletor")
                    end

                    if tarefa.acao == "Colher" then
                        task.wait(State.FarmSettings.HarvestDelay or 0.08)
                    elseif tarefa.acao == "Plantar" then
                        task.wait(State.FarmSettings.PlantDelay or 0.12)
                    else
                        task.wait(0.05)
                    end
                end
            else
                table.insert(restantes, tarefa)
            end
        end

        tarefas = restantes

        if disparadasNestaParada == 0 then
            task.wait(0.2)
        else
            task.wait(0.35)
        end
    end
end

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
                pcall(function() Manager.PlowRemote:InvokeServer({ block = root }) end)
                task.wait(0.05)
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

            LimparPlantiosRecentes()
            if not State.FarmSettings.ShowStopViz then LimparVizuParada() end

            local scan = MapearFazenda(Scanner, Manager)
            local tarefasColheita = {}

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
                ProcessarTarefasPorParada(Manager, char, tarefasColheita, "Coletando seletor: " .. #tarefasColheita .. " colheitas")
                if Manager then Manager:AtualizarStatus("Conferindo colheita...") end
                task.wait(0.8)
                continue
            end

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
                        acao = "Arar",
                        key = keySolo,
                        pos = posSolo,
                        objS = blocoSolo
                    })
                elseif EhSoloPlantavel(nSolo) and State.FarmSettings.AutoReplace and #sementesPlantio > 0 then
                    if not scan.soloOcupado[keySolo] and not PlantiosRecentes[keyPlanta] and not plantiosPlanejados[keyPlanta] then
                        plantiosPlanejados[keyPlanta] = true
                        table.insert(tarefasManutencao, {
                            acao = "Plantar",
                            key = keyPlanta,
                            pos = posPlanta,
                            posSolo = posSolo,
                            objS = blocoSolo
                        })
                    end
                end
            end

            if #tarefasManutencao > 0 then
                ProcessarTarefasPorParada(Manager, char, tarefasManutencao, "Arrumando seletor: " .. #tarefasManutencao .. " acoes")
                if Manager then Manager:AtualizarStatus("Conferindo plantio...") end
                task.wait(0.8)
            else
                if Manager then Manager:AtualizarStatus("Nada pronto no seletor. Aguardando...") end
                task.wait(1)
            end
        end

        PararVoo(true)
        if Manager then Manager:AtualizarStatus("Auto-Fazenda Desligada") end
    end)
end

return Farmer