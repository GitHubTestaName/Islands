-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

-- ========================================================
-- ✈️ MOTOR DE VOO FÍSICO EMBUTIDO (GARANTIA DE FUNCIONAMENTO)
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
-- 🚜 LÓGICA PRINCIPAL DO FARMER
-- ========================================================
function Farmer:ArarTerra()
    local Manager = Bot.Modules.Manager
    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then return end
    local bounds = workspace:GetPartBoundsInBox(Scanner.AncoraPart.CFrame, Scanner.AncoraPart.Size)
    task.spawn(function()
        for _, p in ipairs(bounds) do
            local n = p.Name:lower()
            if n:find("grass") or n:find("dirt") then
                local root = Manager:ObterBlocoRaiz(p)
                if root then
                    -- Dispara rápido (Assíncrono)
                    task.spawn(function()
                        pcall(function() Manager.PlowRemote:InvokeServer({ block = root }) end)
                    end)
                    task.wait(0.01)
                end
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
            
            -- ========================================
            -- 1. IDENTIFICAR SEMENTES (SEM EQUIPAR NA MÃO!)
            -- ========================================
            local sementeNomeReal = nil
            local stateSementes = State.SementeSelecionada
            if type(stateSementes) ~= "table" then stateSementes = {["All"] = true} end
            
            local sementesNoInventario = Manager:GetInventoryTools("Seed")
            for _, sementeNome in ipairs(sementesNoInventario) do
                if sementeNome ~= "Nenhum item encontrado" and sementeNome ~= "None Found" then
                    if stateSementes["All"] or stateSementes[sementeNome] then
                        sementeNomeReal = sementeNome:gsub("Seeds", ""):gsub("seeds", "")
                        break
                    end
                end
            end

            -- Sobrepõe com o Priorize Plant, se existir
            local prioridade = State.FarmSettings.PrioritizePlant
            if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
                sementeNomeReal = prioridade:gsub("Seeds", ""):gsub("seeds", "")
            end

            -- ========================================
            -- 2. MAPEAMENTO DA FAZENDA
            -- ========================================
            local cacheSolos = {}
            local cachePlantas = {}
            local bounds = workspace:GetPartBoundsInBox(Scanner.AncoraPart.CFrame, Scanner.AncoraPart.Size)
            
            for _, p in ipairs(bounds) do
                local root = Manager:ObterBlocoRaiz(p)
                if root and root.Name ~= "SelectionAnchor_Script" then
                    local n = root.Name:lower()
                    if n ~= "trunk" and n ~= "top" then
                        local pos = root:IsA("Model") and root:GetPivot().Position or root.Position
                        local posGrid = Scanner:AlinharParaGrid(pos)
                        local key = string.format("%.1f_%.1f_%.1f", posGrid.X, posGrid.Y, posGrid.Z)
                        
                        if n:find("grass") or n:find("dirt") or n:find("soil") or n:find("plowed") or n:find("farm") then
                            cacheSolos[key] = root
                        else
                            cachePlantas[key] = root
                        end
                    end
                end
            end

            -- ========================================
            -- 3. ALGORITMO CHUNKING (FATIAMENTO 30x30)
            -- ========================================
            local minCoord = Scanner.AncoraPart.Position - (Scanner.AncoraPart.Size / 2)
            local maxCoord = Scanner.AncoraPart.Position + (Scanner.AncoraPart.Size / 2)
            
            local setores = {}
            local step = 30 -- Fatias de 30 blocos para cobrir 100% do range do player (que é 45)

            for y = minCoord.Y + (Config.BLOCK_SIZE/2), maxCoord.Y, Config.BLOCK_SIZE do
                for x = minCoord.X + (Config.BLOCK_SIZE/2), maxCoord.X, Config.BLOCK_SIZE do
                    for z = minCoord.Z + (Config.BLOCK_SIZE/2), maxCoord.Z, Config.BLOCK_SIZE do
                        
                        local posPlanta = Vector3.new(x, y, z)
                        local posSolo = posPlanta - Vector3.new(0, Config.BLOCK_SIZE, 0)
                        
                        local keyPlanta = string.format("%.1f_%.1f_%.1f", posPlanta.X, posPlanta.Y, posPlanta.Z)
                        local keySolo = string.format("%.1f_%.1f_%.1f", posSolo.X, posSolo.Y, posSolo.Z)
                        
                        local plantaObj = cachePlantas[keyPlanta]
                        local blocoSolo = cacheSolos[keySolo]
                        
                        local acao = nil

                        if plantaObj and plantaObj:FindFirstChild("Harvestable", true) then
                            acao = "Colher"
                        elseif blocoSolo then
                            local nSolo = blocoSolo.Name:lower()
                            if (nSolo:find("grass") or nSolo:find("dirt")) and State.FarmSettings.PlowGrass then
                                acao = "Arar"
                            elseif (nSolo:find("soil") or nSolo:find("plowed") or nSolo:find("farm")) and State.FarmSettings.AutoReplace and sementeNomeReal and not plantaObj then
                                acao = "Plantar"
                            end
                        elseif not blocoSolo and State.FarmSettings.PlaceGrass then
                            acao = "ColocarGrama"
                        end

                        if acao then
                            local sx = math.floor((x - minCoord.X) / step) * step + minCoord.X + step/2
                            local sz = math.floor((z - minCoord.Z) / step) * step + minCoord.Z + step/2
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

            -- ========================================
            -- 4. O ASPIRADOR MULTITHREAD RÁPIDO
            -- ========================================
            while #listaSetores > 0 and State.AutoFarmingCrops do
                local hrp = char.HumanoidRootPart
                local posAtual = hrp.Position

                table.sort(listaSetores, function(a, b)
                    return (posAtual - a.centro).Magnitude < (posAtual - b.centro).Magnitude
                end)

                local setorAtual = table.remove(listaSetores, 1)
                local tarefasNoChunk = setorAtual.tarefas

                local voando = false
                if State.FarmSettings.TweenToTarget then
                    voando = true
                    task.spawn(function()
                        local alvoVoo = setorAtual.centro + Vector3.new(0, 10, 0)
                        VoarParaFisico(alvoVoo)
                        voando = false
                    end)
                end

                if Manager then Manager:AtualizarStatus("Limpando Lote: " .. #tarefasNoChunk .. " ações") end

                while #tarefasNoChunk > 0 and State.AutoFarmingCrops do
                    posAtual = hrp.Position
                    
                    table.sort(tarefasNoChunk, function(a, b)
                        return (posAtual - a.pPlanta).Magnitude < (posAtual - b.pPlanta).Magnitude
                    end)
                    
                    local maisProximo = tarefasNoChunk[1]
                    local dist = (posAtual - maisProximo.pPlanta).Magnitude
                    
                    if dist <= 38 then
                        table.remove(tarefasNoChunk, 1)
                        
                        -- Disparo Metralhadora (Spawn não trava o loop!)
                        if maisProximo.acao == "Colher" then
                            task.spawn(function()
                                local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = maisProximo.objP }
                                pcall(function() Manager.HarvestRemote:InvokeServer(payload) end)
                            end)
                            task.wait(State.FarmSettings.HarvestDelay or 0.05)
                            
                        elseif maisProximo.acao == "Arar" then
                            task.spawn(function()
                                pcall(function() Manager.PlowRemote:InvokeServer({ block = maisProximo.objS }) end)
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
                        -- Correção do loop infinito invisível
                        if not voando then
                            if State.FarmSettings.TweenToTarget then
                                -- O alvo está a mais de 38 studs. Voa especificamente para ele!
                                voando = true
                                task.spawn(function()
                                    VoarParaFisico(maisProximo.pPlanta + Vector3.new(0, 10, 0))
                                    voando = false
                                end)
                            else
                                -- O alvo está longe e o Tween está DESLIGADO. 
                                -- Aborta a planta para não travar o script.
                                table.remove(tarefasNoChunk, 1)
                            end
                        else
                            task.wait(0.05) -- Continua esperando o voo chegar perto
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