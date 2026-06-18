-- src/ui/tabs/FazendaTab.lua
local FazendaTab = {}

function FazendaTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents

    Componentes:ResetOrder()

    if not State.FarmSettings.FarmMode then State.FarmSettings.FarmMode = "Snake Farm" end
    if not State.FarmSettings.HarvestMethod then State.FarmSettings.HarvestMethod = "Foice-Auto" end
    if not State.FarmSettings.PlantMethod then State.FarmSettings.PlantMethod = "Plant-All" end
    if State.FarmSettings.SmartRouting == nil then State.FarmSettings.SmartRouting = true end
    if State.FarmSettings.FillEmptySoils == nil then State.FarmSettings.FillEmptySoils = true end

    -- ================= BLOCO 1: MAIN FARM =================
    local cFarm, zFarm = Componentes:CriarCard("MAIN FARM", paginaPai)
    
    Componentes:CriarToggleLargo("▶ Auto-Farm", cFarm, State, "AutoFarmingCrops", zFarm, function(v) 
        if Bot.Modules.Farmer then Bot.Modules.Farmer:AlternarAutoFazenda(v) end 
    end)
    
    local DropdownModo = Componentes:CriarDropdown("🔄 Rota Principal", cFarm, State.FarmSettings, "FarmMode", false, zFarm, false)
    DropdownModo:Refresh({"Snake Farm", "Wait First Plot", "Nearest Plot", "Only Fully Growth Plot"})
    
    Componentes:CriarSubtitulo("Configurações do Solo:", cFarm, zFarm)
    local rFarm1 = Componentes:CriarGridDupla(cFarm, zFarm)
    Componentes:CriarCheckboxMetade("🚜 Arar Grama", rFarm1, State.FarmSettings, "PlowGrass", zFarm)
    Componentes:CriarCheckboxMetade("🌱 Preencher Vazios", rFarm1, State.FarmSettings, "FillEmptySoils", zFarm)
    
    local rFarm2 = Componentes:CriarGridDupla(cFarm, zFarm)
    Componentes:CriarCheckboxMetade("📍 Rota Dinâmica", rFarm2, State.FarmSettings, "SmartRouting", zFarm)

    -- ================= BLOCO 2: MÉTODOS DE AÇÃO =================
    local cAdv, zAdv = Componentes:CriarCard("ADVANCED METHODS", paginaPai)
    
    local DropHarvMode = Componentes:CriarDropdown("🔪 Harvest Mode", cAdv, State.FarmSettings, "HarvestMethod", false, zAdv, false)
    DropHarvMode:Refresh({"Foice-Auto", "Foice-Batch"})
    
    local DropPlanMode = Componentes:CriarDropdown("🌱 Plant Mode", cAdv, State.FarmSettings, "PlantMethod", false, zAdv, false)
    DropPlanMode:Refresh({"Plant-All", "Plant-Batch"})

    -- ================= BLOCO 3: SEEDS =================
    local cSeed, zSeed = Componentes:CriarCard("SEEDS", paginaPai)
    
    local DropdownSementes = Componentes:CriarDropdown("🎒 Permitidas", cSeed, State, "SementeSelecionada", true, zSeed, true)
    local PriorizeDropdown = Componentes:CriarDropdown("🌍 Prioridade", cSeed, State.FarmSettings, "PrioritizePlant", false, zSeed, true)
    
    Componentes:CriarBotaoEstilizado("🔄 Sincronizar", cSeed, zSeed, function()
        if Bot.Modules.Manager then 
            pcall(function()
                DropdownSementes:Refresh(Bot.Modules.Manager:GetInventoryTools("Seed"))
                PriorizeDropdown:Refresh(Bot.Modules.Manager:GetAllSeedsInGame())
            end)
        end
    end)

    -- ================= BLOCO 4: CONFIG, DELAY & VISUALS =================
    local cDelay, zDelay = Componentes:CriarCard("CONFIG & DELAY", paginaPai)
    
    Componentes:CriarSubtitulo("Action Delays:", cDelay, zDelay)
    local rDelay1 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarInputMetade("⏱️ Harvest:", rDelay1, State.FarmSettings, "HarvestDelay", 0.1, zDelay)
    Componentes:CriarInputMetade("⏱️ Plant:", rDelay1, State.FarmSettings, "PlantDelay", 0.05, zDelay)
    
    Componentes:CriarSubtitulo("Batch Size (Lotes):", cDelay, zDelay)
    local rBatch = Componentes:CriarGridDupla(cDelay, zDelay)
    local inpHarv = Componentes:CriarInputMetade("📦 Colher:", rBatch, State.FarmSettings, "HarvestBatch", 5, zDelay)
    local inpPlan = Componentes:CriarInputMetade("📦 Plantar:", rBatch, State.FarmSettings, "PlantBatch", 5, zDelay)
    
    task.spawn(function()
        while task.wait(0.2) do
            if State.FarmSettings.HarvestMethod == "Foice-Auto" then
                inpHarv.TextEditable = false; inpHarv.BackgroundColor3 = Color3.fromRGB(30, 30, 30); inpHarv.TextColor3 = Color3.fromRGB(100, 100, 100)
            else
                inpHarv.TextEditable = true; inpHarv.BackgroundColor3 = Componentes.Theme.InputBG; inpHarv.TextColor3 = Componentes.Theme.AccentBlue
            end

            if State.FarmSettings.PlantMethod == "Plant-All" then
                inpPlan.TextEditable = false; inpPlan.BackgroundColor3 = Color3.fromRGB(30, 30, 30); inpPlan.TextColor3 = Color3.fromRGB(100, 100, 100)
            else
                inpPlan.TextEditable = true; inpPlan.BackgroundColor3 = Componentes.Theme.InputBG; inpPlan.TextColor3 = Componentes.Theme.AccentBlue
            end
        end
    end)
    
    Componentes:CriarSubtitulo("Movement & Performance:", cDelay, zDelay)
    local rDelay2 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarCheckboxMetade("✈️ Tween", rDelay2, State.FarmSettings, "TweenToTarget", zDelay)
    Componentes:CriarInputMetade("💨 Speed:", rDelay2, State.FarmSettings, "TweenSpeed", 30, zDelay)
    
    local rDelay3 = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarCheckboxMetade("Hide Numbers", rDelay3, State.ScannerFazenda, "HideNumbers", zDelay, function()
        if State.ScannerFazenda and type(State.ScannerFazenda.EscanearArea) == "function" then State.ScannerFazenda:EscanearArea() end
    end)

    -- Visual Settings acoplado
    Componentes:CriarSubtitulo("Visual Settings:", cDelay, zDelay)
    local rVis1F = Componentes:CriarGridDupla(cDelay, zDelay)
    Componentes:CriarCheckboxMetade("Esconder Cubo", rVis1F, State.ScannerFazenda, "EsconderSeletor", zDelay, function()
        if State.ScannerFazenda then State.ScannerFazenda:AtualizarVisuais() end
    end)
    Componentes:CriarCheckboxMetade("Aplicar Outline", rVis1F, State.ScannerFazenda, "MostrarOutline", zDelay, function()
        if State.ScannerFazenda then State.ScannerFazenda:AtualizarVisuais() end
    end)
    
    local rVis2F = Componentes:CriarGridDupla(cDelay, zDelay)
    local inpTranspF = Componentes:CriarInputMetade("Transparência:", rVis2F, State.ScannerFazenda, "Transparencia", 0.7, zDelay)
    inpTranspF.FocusLost:Connect(function()
        task.wait(0.05) -- Aguarda o componente interno salvar o valor
        if State.ScannerFazenda then State.ScannerFazenda:AtualizarVisuais() end
    end)
    
    -- ================= BLOCO 5: SELECTOR & SAVES =================
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