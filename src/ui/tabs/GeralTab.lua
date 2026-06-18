-- src/ui/tabs/GeralTab.lua
local GeralTab = {}

function GeralTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents

    Componentes:ResetOrder()

    -- ================= BLOCO 1: MINER & BUILDER =================
    local cMiner, zMiner = Componentes:CriarCard("MINER & BUILDER", paginaPai)
    
    Componentes:CriarToggleLargo("Mine", cMiner, State, "Minerando", zMiner, function(v) 
        if Bot.Modules.Miner then Bot.Modules.Miner:Alternar(v) end 
    end)
    
    Componentes:CriarBotaoEstilizado("Fill With Block", cMiner, zMiner, function() 
        if Bot.Modules.Builder then Bot.Modules.Builder:ColocarAreaMarcada() end 
    end)

    local DropdownBlocos = Componentes:CriarDropdown("🎒 Inventory", cMiner, State, "BlocoSelecionado", false, zMiner, true)
    
    Componentes:CriarBotaoEstilizado("🔄 Sync", cMiner, zMiner, function() 
        if Bot.Modules.Manager then DropdownBlocos:Refresh(Bot.Modules.Manager:GetInventoryTools("Block")) end 
    end)

    -- ================= BLOCO 2: CONFIG & DELAY =================
    local cMinerCfg, zMinerCfg = Componentes:CriarCard("CONFIG & DELAY", paginaPai, 205)
    
    Componentes:CriarSubtitulo("Movement & Performance:", cMinerCfg, zMinerCfg)
    local rMinerDelay1 = Componentes:CriarGridDupla(cMinerCfg, zMinerCfg)
    Componentes:CriarCheckboxMetade("Tween", rMinerDelay1, State.MiningSettings, "TweenToTarget", zMinerCfg)
    Componentes:CriarInputMetade("Speed:", rMinerDelay1, State.MiningSettings, "TweenSpeed", 20, zMinerCfg)
    
    local rMinerDelay2 = Componentes:CriarGridDupla(cMinerCfg, zMinerCfg)
    Componentes:CriarInputMetade("Hit Delay:", rMinerDelay2, State.MiningSettings, "HitDelay", 0.15, zMinerCfg)
    Componentes:CriarCheckboxMetade("Hide Nums", rMinerDelay2, State.ScannerGeral, "HideNumbers", zMinerCfg, function()
        if State.ScannerGeral and type(State.ScannerGeral.EscanearArea) == "function" then State.ScannerGeral:EscanearArea() end
    end)

    -- ================= BLOCO 3: SELECTOR & SAVES =================
    local cSelAzul, zSelAzul = Componentes:CriarCard("SELECTOR & SAVES", paginaPai, nil, 480)
    
    Componentes:CriarBotaoEstilizado("👁️ Spawn Selector", cSelAzul, zSelAzul, function() 
        if State.ScannerGeral and type(State.ScannerGeral.CriarSeletorFrontal) == "function" then State.ScannerGeral:CriarSeletorFrontal() end 
    end)
    
    Componentes:CriarControlesEspaciais(cSelAzul, zSelAzul, "ScannerGeral")

    Componentes:CriarSubtitulo("Area Management:", cSelAzul, zSelAzul)
    local rSaveNomeM = Instance.new("Frame", cSelAzul)
    rSaveNomeM.Name = "Row_SavePlotName"
    rSaveNomeM.Size = UDim2.new(0.95, 0, 0, 32); rSaveNomeM.BackgroundTransparency = 1
    rSaveNomeM.ZIndex = zSelAzul + 2; rSaveNomeM.LayoutOrder = Componentes:GetInnerOrder()
    
    local inputPlotMining = Componentes:CriarInputLargo("Plot:", rSaveNomeM, zSelAzul)
    
    local btnSavePlotMining = Instance.new("TextButton", rSaveNomeM)
    btnSavePlotMining.Name = "TriggerSavePlot"
    btnSavePlotMining.Size = UDim2.new(0.35, 0, 1, 0); btnSavePlotMining.Position = UDim2.new(0.65, 5, 0, 0)
    btnSavePlotMining.BackgroundColor3 = Color3.fromRGB(0, 160, 220); btnSavePlotMining.Text = "💾 Save"
    btnSavePlotMining.TextColor3 = Color3.fromRGB(255, 255, 255); btnSavePlotMining.Font = Enum.Font.SourceSansBold
    btnSavePlotMining.TextSize = 13; btnSavePlotMining.ZIndex = zSelAzul + 3
    Instance.new("UICorner", btnSavePlotMining).CornerRadius = UDim.new(0, 4)

    local plotDropdownMining = Componentes:CriarDropdown("Select Save", cSelAzul, State.MiningSettings, "CurrentSaveName", false, zSelAzul, false)

    local function AtualizarListaSavesMining()
        if Bot.Modules.PlotManager and plotDropdownMining then
            pcall(function()
                local plots = Bot.Modules.PlotManager:ObterTodos()
                local lista = {}
                for nome, _ in pairs(plots) do if nome:sub(1, 7) == "Mining_" then table.insert(lista, nome:sub(8)) end end
                plotDropdownMining:Refresh(lista)
            end)
        end
    end

    btnSavePlotMining.MouseButton1Click:Connect(function()
        local cubo = State.ScannerGeral and State.ScannerGeral.AncoraPart
        if inputPlotMining.Text ~= "" and cubo then
            Bot.Modules.PlotManager:SalvarPlot("Mining_" .. inputPlotMining.Text, cubo.Position, cubo.Size)
            AtualizarListaSavesMining(); inputPlotMining.Text = ""
        end
    end)

    local rAcoesM = Componentes:CriarGridTripla(cSelAzul, zSelAzul)
    Componentes:CriarBotaoPequeno("Load", Color3.fromRGB(40, 150, 80), rAcoesM, zSelAzul, function()
        local sn = State.MiningSettings.CurrentSaveName
        if sn and sn ~= "None" and Bot.Modules.PlotManager then
            local p = Bot.Modules.PlotManager:ObterTodos()["Mining_" .. sn]
            if p and State.ScannerGeral then State.ScannerGeral:CarregarPlot(Vector3.new(p.PosX, p.PosY, p.PosZ), Vector3.new(p.SizeX, p.SizeY, p.SizeZ)) end
        end
    end)
    Componentes:CriarBotaoPequeno("Rewrite", Color3.fromRGB(200, 120, 20), rAcoesM, zSelAzul, function()
        local sn = State.MiningSettings.CurrentSaveName; local cubo = State.ScannerGeral and State.ScannerGeral.AncoraPart
        if sn and sn ~= "None" and cubo then Bot.Modules.PlotManager:SalvarPlot("Mining_" .. sn, cubo.Position, cubo.Size) end
    end)
    Componentes:CriarBotaoPequeno("Delete", Color3.fromRGB(200, 50, 50), rAcoesM, zSelAzul, function()
        local sn = State.MiningSettings.CurrentSaveName
        if sn and sn ~= "None" then
            Bot.Modules.PlotManager:DeletarPlot("Mining_" .. sn); State.MiningSettings.CurrentSaveName = "None"
            AtualizarListaSavesMining()
        end
    end)
    
    local rSave2M = Componentes:CriarGridDupla(cSelAzul, zSelAzul)
    Componentes:CriarCheckboxMetade("🚀 Auto-Load", rSave2M, State.MiningSettings, "AutoUseSelectedSave", zSelAzul)

    -- ================= BLOCO 4: VISUAL SETTINGS =================
    local cVisGeral, zVisGeral = Componentes:CriarCard("VISUAL SETTINGS", paginaPai, nil)
    
    local rVis1G = Componentes:CriarGridDupla(cVisGeral, zVisGeral)
    Componentes:CriarCheckboxMetade("Esconder Cubo", rVis1G, State.ScannerGeral, "EsconderSeletor", zVisGeral, function()
        if State.ScannerGeral then State.ScannerGeral:AtualizarVisuais() end
    end)
    Componentes:CriarCheckboxMetade("Aplicar Outline", rVis1G, State.ScannerGeral, "MostrarOutline", zVisGeral, function()
        if State.ScannerGeral then State.ScannerGeral:AtualizarVisuais() end
    end)
    
    local rVis2G = Componentes:CriarGridDupla(cVisGeral, zVisGeral)
    local inpTransp = Componentes:CriarInputMetade("Transparência:", rVis2G, State.ScannerGeral, "Transparencia", 0.7, zVisGeral)
    inpTransp.FocusLost:Connect(function()
        task.wait(0.05) -- Aguarda o componente interno salvar o valor
        if State.ScannerGeral then State.ScannerGeral:AtualizarVisuais() end
    end)

    task.spawn(function()
        task.wait(1.5); pcall(function() AtualizarListaSavesMining() end)
    end)
end

return GeralTab