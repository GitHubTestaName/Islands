-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

-- ========================================================
-- MOTOR DE VOO FISICO EMBUTIDO
-- ========================================================
local MoverConnection = nil
local AntiGravity = nil

local function PararVoo()
    if MoverConnection then MoverConnection:Disconnect(); MoverConnection = nil end
    if AntiGravity then AntiGravity:Destroy(); AntiGravity = nil end
    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then hrp.Anchored = false; hrp.Velocity = Vector3.zero end
    end
end

local function VoarParaFisico(destino)
    PararVoo()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    hrp.Anchored = false
    hum.PlatformStand = true
    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero
    AntiGravity.Parent = hrp

    local chegou = false
    local velocidade = State.FarmSettings.TweenSpeed or 25

    MoverConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarmingCrops or not hrp.Parent then PararVoo(); chegou = true return end
        local posAtual = hrp.Position
        local dist = (destino - posAtual).Magnitude

        if dist <= 1.5 then chegou = true; PararVoo() return end

        local step = velocidade * dt
        if step > dist then step = dist end
        local dir = (destino - posAtual).Unit
        local novaPos = posAtual + (dir * step)

        hrp.CFrame = CFrame.new(novaPos, novaPos + dir)
        hrp.Velocity = Vector3.zero
        hrp.RotVelocity = Vector3.zero
    end)

    while not chegou and State.AutoFarmingCrops do task.wait(0.05) end
    PararVoo()
end

-- ========================================================
-- HELPERS DE LEITURA INTELIGENTE DA FAZENDA
-- ========================================================
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

local function NomeCombina(root, culturaAlvo)
    if not culturaAlvo or culturaAlvo == "" then return true end
    if not root then return false end

    local nomeRoot = NormalizarNome(root.Name)
    if nomeRoot:find(culturaAlvo, 1, true) then return true end

    for _, desc in ipairs(root:GetDescendants()) do
        local nomeDesc = NormalizarNome(desc.Name)
        if nomeDesc:find(culturaAlvo, 1, true) then return true end
    end

    return false
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

local function ResolverCulturaDesejada(Manager)
    local prioridade = State.FarmSettings.PrioritizePlant
    if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
        return prioridade:gsub("Seeds", ""):gsub("seeds", ""), ObterNomeCultura(prioridade)
    end

    local stateSementes = State.SementeSelecionada
    if type(stateSementes) ~= "table" then stateSementes = { ["All"] = true } end

    local sementesNoInventario = Manager:GetInventoryTools("Seed")
    for _, sementeNome in ipairs(sementesNoInventario) do
        if sementeNome ~= "Nenhum item encontrado" and sementeNome ~= "None Found" then
            if stateSementes["All"] or stateSementes[sementeNome] then
                return sementeNome:gsub("Seeds", ""):gsub("seeds", ""), ObterNomeCultura(sementeNome)
            end
        end
    end

    return nil, nil
end

local prioridadeAcao = {
    Colher = 1,
    Plantar = 2,
    Arar = 3,
    ColocarGrama = 4
}

local function OrdenarTarefas(lista, posAtual)
    table.sort(lista, function(a, b)
        local pa = prioridadeAcao[a.acao] or 99
        local pb = prioridadeAcao[b.acao] or 99
        if pa ~= pb then return pa < pb end
        return (posAtual - a.pPlanta).Magnitude < (posAtual - b.pPlanta).Magnitude
    end)
end

-- ========================================================
-- LOGICA PRINCIPAL DO FARMER
-- ========================================================
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
                task.spawn(function()
                    pcall(function() Manager.PlowRemote:InvokeServer({ block = root }) end)
                end)
                task.wait(0.01)
            end
        end
    end)
end

function Farmer:AlternarAutoFazenda(valor)
    State.AutoFarmingCrops = valor
    local Manager = Bot.Modules.Manager

    if not valor then
        if Manager then Manager:AtualizarStatus("Ocioso") end
        PararVoo()
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

            local sementeNomeReal, culturaAlvo = ResolverCulturaDesejada(Manager)
            local somenteCulturaAlvo = culturaAlvo ~= nil

            local cacheSolos = {}
            local cachePlantas = {}
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
                                cacheSolos[key] = root
                            else
                                cachePlantas[key] = root
                            end
                        end
                    end
                end
            end

            local minCoord = Scanner.AncoraPart.Position - (Scanner.AncoraPart.Size / 2)
            local maxCoord = Scanner.AncoraPart.Position + (Scanner.AncoraPart.Size / 2)
            local setores = {}
            local step = 30

            for y = minCoord.Y + (Config.BLOCK_SIZE / 2), maxCoord.Y, Config.BLOCK_SIZE do
                for x = minCoord.X + (Config.BLOCK_SIZE / 2), maxCoord.X, Config.BLOCK_SIZE do
                    for z = minCoord.Z + (Config.BLOCK_SIZE / 2), maxCoord.Z, Config.BLOCK_SIZE do
                        local posPlanta = Vector3.new(x, y, z)
                        local posSolo = posPlanta - Vector3.new(0, Config.BLOCK_SIZE, 0)

                        local plantaObj = cachePlantas[CriarKey(posPlanta)]
                        local blocoSolo = cacheSolos[CriarKey(posSolo)]
                        local acao = nil

                        if plantaObj and plantaObj:FindFirstChild("Harvestable", true) then
                            if not somenteCulturaAlvo or NomeCombina(plantaObj, culturaAlvo) then
                                acao = "Colher"
                            end
                        elseif blocoSolo then
                            local nSolo = blocoSolo.Name
                            if EhAravel(nSolo) and State.FarmSettings.PlowGrass then
                                acao = "Arar"
                            elseif EhSoloPlantavel(nSolo) and State.FarmSettings.AutoReplace and sementeNomeReal and not plantaObj then
                                acao = "Plantar"
                            end
                        elseif not blocoSolo and State.FarmSettings.PlaceGrass then
                            acao = "ColocarGrama"
                        end

                        if acao then
                            local sx = math.floor((x - minCoord.X) / step) * step + minCoord.X + (step / 2)
                            local sz = math.floor((z - minCoord.Z) / step) * step + minCoord.Z + (step / 2)
                            local sKey = string.format("%.1f_%.1f", sx, sz)

                            if not setores[sKey] then setores[sKey] = { centro = Vector3.new(sx, y, sz), tarefas = {} } end

                            table.insert(setores[sKey].tarefas, {
                                acao = acao,
                                pPlanta = posPlanta,
                                pSolo = posSolo,
                                objP = plantaObj,
                                objS = blocoSolo
                            })
                        end
                    end
                end
            end

            local listaSetores = {}
            for _, s in pairs(setores) do table.insert(listaSetores, s) end

            while #listaSetores > 0 and State.AutoFarmingCrops do
                local hrp = char.HumanoidRootPart
                local posAtual = hrp.Position

                table.sort(listaSetores, function(a, b)
                    return (posAtual - a.centro).Magnitude < (posAtual - b.centro).Magnitude
                end)

                local setorAtual = table.remove(listaSetores, 1)
                local tarefasNoChunk = setorAtual.tarefas

                OrdenarTarefas(tarefasNoChunk, posAtual)

                local voando = false
                if State.FarmSettings.TweenToTarget then
                    voando = true
                    task.spawn(function()
                        local alvoVoo = setorAtual.centro + Vector3.new(0, 10, 0)
                        VoarParaFisico(alvoVoo)
                        voando = false
                    end)
                end

                if Manager then
                    local alvoTxt = culturaAlvo and (" | alvo: " .. culturaAlvo) or ""
                    Manager:AtualizarStatus("Limpando Seletor: " .. #tarefasNoChunk .. " acoes" .. alvoTxt)
                end

                while #tarefasNoChunk > 0 and State.AutoFarmingCrops do
                    posAtual = hrp.Position
                    OrdenarTarefas(tarefasNoChunk, posAtual)

                    local maisProximo = tarefasNoChunk[1]
                    local dist = (posAtual - maisProximo.pPlanta).Magnitude

                    if dist <= 38 then
                        table.remove(tarefasNoChunk, 1)

                        if maisProximo.acao == "Colher" then
                            task.spawn(function()
                                if maisProximo.objP and maisProximo.objP:IsDescendantOf(workspace) then
                                    local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = maisProximo.objP }
                                    pcall(function() Manager.HarvestRemote:InvokeServer(payload) end)
                                end
                            end)
                            task.wait(State.FarmSettings.HarvestDelay or 0.05)

                        elseif maisProximo.acao == "Arar" then
                            task.spawn(function()
                                if maisProximo.objS and maisProximo.objS:IsDescendantOf(workspace) then
                                    pcall(function() Manager.PlowRemote:InvokeServer({ block = maisProximo.objS }) end)
                                end
                            end)
                            task.wait(0.05)

                        elseif maisProximo.acao == "Plantar" then
                            task.spawn(function()
                                local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(maisProximo.pPlanta), blockType = sementeNomeReal, upperBlock = false }
                                pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
                            end)
                            task.wait(State.FarmSettings.PlantDelay or 0.05)

                        elseif maisProximo.acao == "ColocarGrama" then
                            task.spawn(function()
                                local blockGrass = LocalPlayer.Backpack:FindFirstChild("grass") or char:FindFirstChild("grass")
                                if blockGrass then
                                    local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(maisProximo.pSolo), blockType = blockGrass.Name, upperBlock = false }
                                    pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
                                end
                            end)
                            task.wait(0.05)
                        end
                    else
                        if not voando then
                            if State.FarmSettings.TweenToTarget then
                                voando = true
                                task.spawn(function()
                                    VoarParaFisico(maisProximo.pPlanta + Vector3.new(0, 10, 0))
                                    voando = false
                                end)
                            else
                                table.remove(tarefasNoChunk, 1)
                            end
                        else
                            task.wait(0.05)
                        end
                    end
                end
            end

            if Manager then Manager:AtualizarStatus("Escaneando novamente...") end
            task.wait(1)
        end

        PararVoo()
        if Manager then Manager:AtualizarStatus("Auto-Fazenda Desligada") end
    end)
end

return Farmer