-- src/ui/tabs/FazendaTab.lua
local FazendaTab = {}

function FazendaTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents

    Componentes:ResetOrder()

    -- ================= BLOCO 1: MAIN FARM =================
    local cFarm, zFarm = Componentes:CriarCard("MAIN FARM", paginaPai)
    
    Componentes:CriarToggleLargo("▶ Auto-Farm", cFarm, State, "AutoFarmingCrops", zFarm, function(v) 
        if Bot.Modules.Farmer then Bot.Modules.Farmer:AlternarAutoFazenda(v) end 
    end)
    
    Componentes:CriarSubtitulo("Soil Settings:", cFarm, zFarm)
    local rFarm1 = Componentes:CriarGridDupla(cFarm, zFarm)
    Componentes:CriarCheckboxMetade("🚜 Plow Grass", rFarm1, State.FarmSettings, "PlowGrass", zFarm)
    Componentes:CriarCheckboxMetade("🌱 Place Grass", rFarm1, State.FarmSettings, "PlaceGrass", zFarm)
    
    local rFarm2 = Componentes:CriarGridDupla(cFarm, zFarm)
    Componentes:CriarCheckboxMetade("♻️ Auto Replace", rFarm2, State.FarmSettings, "AutoReplace", zFarm)

    -- ================= BLOCO 2: SEEDS =================
    local cSeed, zSeed = Componentes:CriarCard("SEEDS", paginaPai)
    
    local DropdownSementes = Componentes:CriarDropdown("🎒 Inventory", cSeed, State, "SementeSelecionada", true, zSeed, true)
    local PriorizeDropdown = Componentes:CriarDropdown("🌍 Priorize", cSeed, State.FarmSettings, "PrioritizePlant", false, zSeed, true)
    
    Componentes:CriarBotaoEstilizado("🔄 Sync", cSeed, zSeed, function()
        if Bot.Modules.Manager then 
            pcall(function()
                DropdownSementes:Refresh(Bot.Modules.Manager:GetInventoryTools("Seed"))
                PriorizeDropdown:Refresh(Bot.Modules.Manager:GetAllSeedsInGame())
            end)
        end
    end)

-- ================= BLOCO 3: CONFIG & DELAY =================
    local cDelay, zDelay = Componentes:CriarCard("CONFIG & DELAY", paginaPai)
    
    Componentes:CriarSubtitulo("Action Delays:", cDelay, zDelay)
    local rDelay1 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarInputMetade("⏱️ Harvest:", rDelay1, State.FarmSettings, "HarvestDelay", 0.1, zDelay)
    Componentes:CriarInputMetade("⏱️ Plant:", rDelay1, State.FarmSettings, "PlantDelay", 0.15, zDelay)
    
    -- NOVOS INPUTS: Quantidade de colheita/plantio simultâneo
    Componentes:CriarSubtitulo("Batch Size (Qtd de Lote):", cDelay, zDelay)
    local rBatch = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarInputMetade("📦 Colher:", rBatch, State.FarmSettings, "HarvestBatch", 5, zDelay)
    Componentes:CriarInputMetade("📦 Plantar:", rBatch, State.FarmSettings, "PlantBatch", 5, zDelay)
    
    Componentes:CriarSubtitulo("Movement & Performance:", cDelay, zDelay)
    local rDelay2 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarCheckboxMetade("✈️ Smooth Flight", rDelay2, State.FarmSettings, "TweenToTarget", zDelay)
    Componentes:CriarInputMetade("💨 Speed:", rDelay2, State.FarmSettings, "TweenSpeed", 20, zDelay)
    
    local rDelay3 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarCheckboxMetade("Vizu Parada", rDelay3, State.FarmSettings, "ShowStopViz", zDelay)
    Componentes:CriarCheckboxMetade("Hide Numbers", rDelay3, State.ScannerFazenda, "HideNumbers", zDelay, function()
        if State.ScannerFazenda and type(State.ScannerFazenda.EscanearArea) == "function" then State.ScannerFazenda:EscanearArea() end
    end)
    
    -- ================= BLOCO 4: SELECTOR & SAVES (WIDTH APLICADO = 480) =================
    -- Alteração cirúrgica: nil (para não fixar a altura), 480 (para forçar a largura)
    local cSave, zSave = Componentes:CriarCard("SELECTOR & SAVES", paginaPai, nil, 480)
    
    Componentes:CriarBotaoEstilizado("👁️ Spawn Selector", cSave, zSave, function() 
        if State.ScannerFazenda and type(State.ScannerFazenda.CriarSeletorFrontal) == "function" then State.ScannerFazenda:CriarSeletorFrontal() end 
    end)
    
    Componentes:CriarControlesEspaciais(cSave, zSave, "ScannerFazenda")

    Componentes:CriarSubtitulo("Area Management:", cSave, zSave)
    local rSaveNome = Instance.new("Frame", cSave)
    rSaveNome.Name = "Row_SavePlotName"
    rSaveNome.Size = UDim2.new(0.95, 0, 0, 32); rSaveNome.BackgroundTransparency = 1
    rSaveNome.ZIndex = zSave + 2; rSaveNome.LayoutOrder = Componentes:GetInnerOrder()
    
    local inputPlotFazenda = Componentes:CriarInputLargo("Plot:", rSaveNome, zSave)
    
    local btnSavePlotFazenda = Instance.new("TextButton", rSaveNome)
    btnSavePlotFazenda.Name = "TriggerSavePlot"
    btnSavePlotFazenda.Size = UDim2.new(0.35, 0, 1, 0); btnSavePlotFazenda.Position = UDim2.new(0.65, 5, 0, 0)
    btnSavePlotFazenda.BackgroundColor3 = Color3.fromRGB(0, 160, 220); btnSavePlotFazenda.Text = "💾 Save"
    btnSavePlotFazenda.TextColor3 = Color3.fromRGB(255, 255, 255); btnSavePlotFazenda.Font = Enum.Font.SourceSansBold
    btnSavePlotFazenda.TextSize = 13; btnSavePlotFazenda.ZIndex = zSave + 3
    Instance.new("UICorner", btnSavePlotFazenda).CornerRadius = UDim.new(0, 4)

    local plotDropdownFazenda = Componentes:CriarDropdown("Select Save", cSave, State.FarmSettings, "CurrentSaveName", false, zSave, false)

    local function AtualizarListaSavesFazenda()
        if Bot.Modules.PlotManager and plotDropdownFazenda then
            pcall(function()
                local plots = Bot.Modules.PlotManager:ObterTodos()
                local lista = {}
                for nome, _ in pairs(plots) do if nome:sub(1, 8) == "Farming_" then table.insert(lista, nome:sub(9)) end end
                plotDropdownFazenda:Refresh(lista)
            end)
        end
    end

    btnSavePlotFazenda.MouseButton1Click:Connect(function()
        local cubo = State.ScannerFazenda and State.ScannerFazenda.AncoraPart
        if inputPlotFazenda.Text ~= "" and cubo then
            Bot.Modules.PlotManager:SalvarPlot("Farming_" .. inputPlotFazenda.Text, cubo.Position, cubo.Size)
            AtualizarListaSavesFazenda(); inputPlotFazenda.Text = ""
        end
    end)

    local rAcoesF = Componentes:CriarGridTripla(cSave, zSave)
    Componentes:CriarBotaoPequeno("Load", Color3.fromRGB(40, 150, 80), rAcoesF, zSave, function()
        local sn = State.FarmSettings.CurrentSaveName
        if sn and sn ~= "None" and Bot.Modules.PlotManager then
            local p = Bot.Modules.PlotManager:ObterTodos()["Farming_" .. sn]
            if p and State.ScannerFazenda then State.ScannerFazenda:CarregarPlot(Vector3.new(p.PosX, p.PosY, p.PosZ), Vector3.new(p.SizeX, p.SizeY, p.SizeZ)) end
        end
    end)
    Componentes:CriarBotaoPequeno("Rewrite", Color3.fromRGB(200, 120, 20), rAcoesF, zSave, function()
        local sn = State.FarmSettings.CurrentSaveName; local cubo = State.ScannerFazenda and State.ScannerFazenda.AncoraPart
        if sn and sn ~= "None" and cubo then Bot.Modules.PlotManager:SalvarPlot("Farming_" .. sn, cubo.Position, cubo.Size) end
    end)
    Componentes:CriarBotaoPequeno("Delete", Color3.fromRGB(200, 50, 50), rAcoesF, zSave, function()
        local sn = State.FarmSettings.CurrentSaveName
        if sn and sn ~= "None" then
            Bot.Modules.PlotManager:DeletarPlot("Farming_" .. sn); State.FarmSettings.CurrentSaveName = "None"
            AtualizarListaSavesFazenda()
        end
    end)
    
    local rSave2F = Componentes:CriarGridDupla(cSave, zSave)
    Componentes:CriarCheckboxMetade("🚀 Auto-Load", rSave2F, State.FarmSettings, "AutoUseSelectedSave", zSave)

    task.spawn(function()
        task.wait(1.5); pcall(function() AtualizarListaSavesFazenda() end)
        if Bot.Modules.Manager then
            pcall(function()
                DropdownSementes:Refresh(Bot.Modules.Manager:GetInventoryTools("Seed"))
                PriorizeDropdown:Refresh(Bot.Modules.Manager:GetAllSeedsInGame())
            end)
        end
    end)
end

return FazendaTab