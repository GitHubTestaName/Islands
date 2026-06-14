-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

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
                    pcall(function() Manager.PlowRemote:InvokeServer({ block = root }) end)
                    task.wait(0.05)
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
            -- 1. IDENTIFICAR SEMENTES NO INVENTÁRIO
            -- ========================================
            local stateSementes = State.SementeSelecionada
            if type(stateSementes) ~= "table" then stateSementes = {["All"] = true} end
            
            local sementesNoInventario = Manager:GetInventoryTools("Seed")
            local sementesDisponiveis = {}
            
            for _, sementeNome in ipairs(sementesNoInventario) do
                if sementeNome ~= "Nenhum item encontrado" and sementeNome ~= "None Found" then
                    if stateSementes["All"] or stateSementes[sementeNome] then
                        table.insert(sementesDisponiveis, sementeNome)
                    end
                end
            end

            local prioridade = State.FarmSettings.PrioritizePlant
            if prioridade and prioridade ~= "Nenhum" and prioridade ~= "None" then
                table.sort(sementesDisponiveis, function(a, b) return a == prioridade end)
            end

            local toolEmUso = nil
            for _, semente in ipairs(sementesDisponiveis) do
                toolEmUso = char:FindFirstChild(semente) or LocalPlayer.Backpack:FindFirstChild(semente)
                if toolEmUso then
                    if toolEmUso.Parent == LocalPlayer.Backpack then
                        char.Humanoid:EquipTool(toolEmUso)
                        task.wait(0.2)
                    end
                    break
                end
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
            local step = 30 -- Lotes Gigantes para aproveitar o range de 45 studs do player

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
                            elseif (nSolo:find("soil") or nSolo:find("plowed") or nSolo:find("farm")) and State.FarmSettings.AutoReplace and toolEmUso and not plantaObj then
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
            -- 4. O ASPIRADOR MULTITHREAD (AURA)
            -- ========================================
            while #listaSetores > 0 and State.AutoFarmingCrops do
                local hrp = char.HumanoidRootPart
                local posAtual = hrp.Position

                -- Vai no Lote (Chunk) mais próximo do player primeiro
                table.sort(listaSetores, function(a, b)
                    return (posAtual - a.centro).Magnitude < (posAtual - b.centro).Magnitude
                end)

                local setorAtual = table.remove(listaSetores, 1)

                -- INICIA O VOO EM BACKGROUND (NÃO TRAVA O SCRIPT!)
                if State.FarmSettings.TweenToTarget then
                    task.spawn(function()
                        local alvoVoo = setorAtual.centro + Vector3.new(0, 10, 0) -- Voa 10 studs acima do centro
                        if Bot.Modules.Navigator then
                            Bot.Modules.Navigator:IrPara(alvoVoo, State.FarmSettings.TweenSpeed or 25, "AutoFarmingCrops")
                        end
                    end)
                end

                if Manager then Manager:AtualizarStatus("Limpando Lote: " .. #setorAtual.tarefas .. " ações") end

                local tarefasNoChunk = setorAtual.tarefas

                -- ENQUANTO VOA, A AURA DETECTA TUDO NO CAMINHO E COLHE EM ESPIRAL
                while #tarefasNoChunk > 0 and State.AutoFarmingCrops do
                    posAtual = hrp.Position
                    
                    -- A MÁGICA DA ESPIRAL: Ordena constantemente para agir no que está logo abaixo do boneco
                    table.sort(tarefasNoChunk, function(a, b)
                        return (posAtual - a.pPlanta).Magnitude < (posAtual - b.pPlanta).Magnitude
                    end)
                    
                    local maisProximo = tarefasNoChunk[1]
                    local dist = (posAtual - maisProximo.pPlanta).Magnitude
                    
                    -- SE ENTROU NO RAIO SEGURO DE 38 STUDS (O limite do jogo é 45)
                    if dist <= 38 then
                        table.remove(tarefasNoChunk, 1) -- Tira da fila
                        
                        -- EXECUTA A AÇÃO NO AR!
                        if maisProximo.acao == "Colher" then
                            if maisProximo.objP and maisProximo.objP.Parent then
                                local payload = { dZnpyRtxna = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nsDahbvdxZludavlcoipDDMYasPlcm", player = LocalPlayer, model = maisProximo.objP }
                                pcall(function() Manager.HarvestRemote:InvokeServer(payload) end)
                                task.wait(State.FarmSettings.HarvestDelay or 0.1)
                            end
                            
                        elseif maisProximo.acao == "Arar" then
                            if maisProximo.objS and maisProximo.objS.Parent then
                                pcall(function() Manager.PlowRemote:InvokeServer({ block = maisProximo.objS }) end)
                                task.wait(0.1)
                            end
                            
                        elseif maisProximo.acao == "Plantar" then
                            local blockTypeReal = toolEmUso.Name:gsub("Seeds", ""):gsub("seeds", "")
                            local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(maisProximo.pPlanta), blockType = blockTypeReal, upperBlock = false }
                            pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
                            task.wait(State.FarmSettings.PlantDelay or 0.15)
                            
                        elseif maisProximo.acao == "ColocarGrama" then
                            local blockGrass = LocalPlayer.Backpack:FindFirstChild("grass") or char:FindFirstChild("grass")
                            if blockGrass then
                                local payload = { uwhiHAMdjExWka = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU", cframe = CFrame.new(maisProximo.pSolo), blockType = blockGrass.Name, upperBlock = false }
                                pcall(function() Manager.PlaceRemote:InvokeServer(payload) end)
                                task.wait(0.15)
                            end
                        end
                    else
                        -- Se o mais próximo estiver a mais de 38 studs, significa que o boneco
                        -- ainda está a voar para lá. Aguarda um pouco e mede a distância de novo.
                        task.wait(0.05)
                    end
                end
            end
            
            if Manager then Manager:AtualizarStatus("Escaneando novamente...") end
            task.wait(1)
        end
        
        if Manager then Manager:AtualizarStatus("Auto-Fazenda Desligada") end
    end)
end

return Farmer