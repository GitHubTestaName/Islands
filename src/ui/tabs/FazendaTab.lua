-- src/ui/tabs/FazendaTab.lua
local FazendaTab = {}

function FazendaTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents

    Componentes:ResetOrder()

    -- Inicializa variáveis V16
    State.FarmSettings = State.FarmSettings or {}
    State.FarmSettings.HarvestDelay = State.FarmSettings.HarvestDelay or 0.3
    State.FarmSettings.PlantDelay = State.FarmSettings.PlantDelay or 0.2
    State.FarmSettings.BatchSize = State.FarmSettings.BatchSize or 5
    State.FarmSettings.SickleName = State.FarmSettings.SickleName or "sickleStone"
    if State.FarmSettings.EnablePlanting == nil then State.FarmSettings.EnablePlanting = true end
    State.FarmSettings.PrioritySeed = State.FarmSettings.PrioritySeed or "None"
    State.FarmSettings.PermittedSeeds = State.FarmSettings.PermittedSeeds or {}
    State.FarmSettings.CurrentSaveName = State.FarmSettings.CurrentSaveName or "None"

    -- ================= NOVO SISTEMA DE LAYOUT SEGURO (SEM QUEBRAR O RESTO) =================
    -- A largura padrão usada no seu projeto é ~480. Vamos dividir em duas colunas de 235px.

    -- 1. LINHA SUPERIOR (Vai conter a Coluna Esquerda e Direita)
    local LinhaTopo = Instance.new("Frame", paginaPai)
    LinhaTopo.Name = "Fazenda_LinhaTopo"
    LinhaTopo.Size = UDim2.new(0, 480, 0, 300) 
    LinhaTopo.BackgroundTransparency = 1
    LinhaTopo.LayoutOrder = Componentes:GetInnerOrder()

    local ColunaEsq = Instance.new("Frame", LinhaTopo)
    ColunaEsq.Size = UDim2.new(0, 235, 1, 0)
    ColunaEsq.BackgroundTransparency = 1
    local LayoutEsq = Instance.new("UIListLayout", ColunaEsq)
    LayoutEsq.SortOrder = Enum.SortOrder.LayoutOrder
    LayoutEsq.Padding = UDim.new(0, 10)

    local ColunaDir = Instance.new("Frame", LinhaTopo)
    ColunaDir.Size = UDim2.new(0, 235, 1, 0)
    ColunaDir.Position = UDim2.new(0, 245, 0, 0) -- Distanciamento exato para a coluna da direita
    ColunaDir.BackgroundTransparency = 1
    local LayoutDir = Instance.new("UIListLayout", ColunaDir)
    LayoutDir.SortOrder = Enum.SortOrder.LayoutOrder
    LayoutDir.Padding = UDim.new(0, 10)

    -- 2. LINHA INFERIOR (Vai conter o Seletor e os Saves alinhados lado a lado)
    local LinhaBase = Instance.new("Frame", paginaPai)
    LinhaBase.Name = "Fazenda_LinhaBase"
    LinhaBase.Size = UDim2.new(0, 480, 0, 170)
    LinhaBase.BackgroundTransparency = 1
    LinhaBase.LayoutOrder = Componentes:GetInnerOrder()
    local LayoutBase = Instance.new("UIListLayout", LinhaBase)
    LayoutBase.FillDirection = Enum.FillDirection.Horizontal
    LayoutBase.SortOrder = Enum.SortOrder.LayoutOrder
    LayoutBase.Padding = UDim.new(0, 10)

    -- ================= COLUNA ESQUERDA: MOTOR E CONFIG =================
    -- O '235' força os cartões a ficarem exatamente do tamanho da coluna
    local cMotor, zMotor = Componentes:CriarCard("⚙️ FARM CONTROLS", ColunaEsq, nil, 235)
    Componentes:CriarToggleLargo("Ativar Auto-Farming", cMotor, State, "AutoFarmingCrops", zMotor, function(v) 
        if Bot.Modules.Farmer then Bot.Modules.Farmer:AlternarAutoFazenda(v) end 
    end)
    local rowFarmCheck = Componentes:CriarGridDupla(cMotor, zMotor)
    Componentes:CriarCheckboxMetade("Plantar Sementes", rowFarmCheck, State.FarmSettings, "EnablePlanting", zMotor)

    local cCfg, zCfg = Componentes:CriarCard("⏱️ DELAYS E CONFIG", ColunaEsq, nil, 235)
    local r1 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarInputMetade("Delay Foice:", r1, State.FarmSettings, "HarvestDelay", "0.3", zCfg)
    Componentes:CriarInputMetade("Delay Plantio:", r1, State.FarmSettings, "PlantDelay", "0.2", zCfg)
    
    local r2 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarInputMetade("Qtd Lote:", r2, State.FarmSettings, "BatchSize", "5", zCfg)
    
    local frameFoice = Instance.new("Frame", r2)
    frameFoice.Size = UDim2.new(0.5, -2.5, 1, 0)
    frameFoice.BackgroundColor3 = Componentes.Theme.PanelBG
    Instance.new("UICorner", frameFoice).CornerRadius = UDim.new(0, 4)
    local lblF = Instance.new("TextLabel", frameFoice)
    lblF.Size = UDim2.new(0.4, 0, 1, 0); lblF.Position = UDim2.new(0, 5, 0, 0)
    lblF.BackgroundTransparency = 1; lblF.Text = "Foice:"
    lblF.TextColor3 = Componentes.Theme.TextDimmed; lblF.Font = Enum.Font.SourceSansSemibold
    lblF.TextSize = 13; lblF.TextXAlignment = Enum.TextXAlignment.Left
    local inputF = Instance.new("TextBox", frameFoice)
    inputF.Size = UDim2.new(0.6, 0, 0.8, 0); inputF.Position = UDim2.new(0.4, 0, 0.1, 0)
    inputF.BackgroundColor3 = Componentes.Theme.InputBG; inputF.TextColor3 = Componentes.Theme.AccentBlue
    inputF.Text = State.FarmSettings.SickleName or "sickleStone"
    inputF.Font = Enum.Font.SourceSansBold; inputF.TextSize = 13
    Instance.new("UICorner", inputF).CornerRadius = UDim.new(0, 4)
    inputF.FocusLost:Connect(function() State.FarmSettings.SickleName = inputF.Text end)


    -- ================= COLUNA DIREITA: SEMENTES =================
    local cSeed, zSeed = Componentes:CriarCard("🌱 GESTÃO DE SEMENTES", ColunaDir, 280, 235)
    
    local priorityDrop = Componentes:CriarDropdown("Prioridade", cSeed, State.FarmSettings, "PrioritySeed", false, zSeed + 10, true)
    
    Componentes:CriarSubtitulo("Sementes Permitidas:", cSeed, zSeed)
    
    local scrollSeeds = Instance.new("ScrollingFrame", cSeed)
    scrollSeeds.Name = "MultiSelectSeeds"
    scrollSeeds.Size = UDim2.new(0.95, 0, 0, 140) 
    scrollSeeds.BackgroundTransparency = 1
    scrollSeeds.ScrollBarThickness = 4
    scrollSeeds.LayoutOrder = Componentes:GetInnerOrder()
    
    local listLayout = Instance.new("UIListLayout", scrollSeeds)
    listLayout.SortOrder = Enum.SortOrder.LayoutOrder
    listLayout.Padding = UDim.new(0, 4)

    local function AtualizarListasDeSementes()
        if not Bot.Modules.Manager then return end
        local invSeeds = Bot.Modules.Manager:GetInventorySeedsWithQuantity()
        
        local dropList = {"None"}
        for seedType, _ in pairs(invSeeds) do table.insert(dropList, seedType) end
        if priorityDrop then priorityDrop:Refresh(dropList) end

        for _, child in ipairs(scrollSeeds:GetChildren()) do
            if child:IsA("TextButton") then child:Destroy() end
        end
        
        local ySize = 0
        for seedType, data in pairs(invSeeds) do
            local btn = Instance.new("TextButton", scrollSeeds)
            btn.Size = UDim2.new(1, -8, 0, 26) 
            local isPermitted = State.FarmSettings.PermittedSeeds[seedType]
            
            btn.BackgroundColor3 = isPermitted and Componentes.Theme.ToggleOn or Componentes.Theme.ButtonBG
            btn.Text = "   " .. (isPermitted and "[ V ] " or "[   ] ") .. string.format("%s (%d)", seedType, data.amount)
            btn.TextColor3 = isPermitted and Componentes.Theme.TextWhite or Componentes.Theme.TextDimmed
            btn.Font = Enum.Font.SourceSansSemibold
            btn.TextSize = 13
            btn.TextXAlignment = Enum.TextXAlignment.Left
            Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
            
            btn.MouseButton1Click:Connect(function()
                State.FarmSettings.PermittedSeeds[seedType] = not State.FarmSettings.PermittedSeeds[seedType]
                local nv = State.FarmSettings.PermittedSeeds[seedType]
                btn.BackgroundColor3 = nv and Componentes.Theme.ToggleOn or Componentes.Theme.ButtonBG
                btn.Text = "   " .. (nv and "[ V ] " or "[   ] ") .. string.format("%s (%d)", seedType, data.amount)
                btn.TextColor3 = nv and Componentes.Theme.TextWhite or Componentes.Theme.TextDimmed
            end)
            ySize = ySize + 30 
        end
        scrollSeeds.CanvasSize = UDim2.new(0, 0, 0, ySize)
    end

    Componentes:CriarBotaoEstilizado("🔄 Sincronizar Mochila", cSeed, zSeed, AtualizarListasDeSementes)


    -- ================= LINHA BASE: SELETOR E SAVES =================
    local cSelVerde, zSelVerde = Componentes:CriarCard("📐 SELETOR (VERDE)", LinhaBase, 160, 235)
    Componentes:CriarBotaoEstilizado("👁️ Spawn Selector", cSelVerde, zSelVerde, function()
        if State.ScannerFazenda and type(State.ScannerFazenda.CriarSeletorFrontal) == "function" then
            State.ScannerFazenda:CriarSeletorFrontal()
        end
    end)
    Componentes:CriarControlesEspaciais(cSelVerde, zSelVerde, "ScannerFazenda")


    local cSavVerde, zSavVerde = Componentes:CriarCard("💾 SAVES (FAZENDA)", LinhaBase, 160, 235)
    
    local rSaveNomeF = Instance.new("Frame", cSavVerde)
    rSaveNomeF.Size = UDim2.new(0.95, 0, 0, 28)
    rSaveNomeF.BackgroundTransparency = 1
    rSaveNomeF.ZIndex = zSavVerde; rSaveNomeF.LayoutOrder = Componentes:GetInnerOrder()
    
    local inputPlotFarm = Instance.new("TextBox", rSaveNomeF)
    inputPlotFarm.Size = UDim2.new(0.60, 0, 1, 0)
    inputPlotFarm.BackgroundColor3 = Componentes.Theme.InputBG
    inputPlotFarm.TextColor3 = Componentes.Theme.AccentBlue
    inputPlotFarm.PlaceholderText = " Nome Plot..."
    inputPlotFarm.Font = Enum.Font.SourceSansBold
    inputPlotFarm.TextSize = 13; inputPlotFarm.ZIndex = zSavVerde + 1
    Instance.new("UICorner", inputPlotFarm).CornerRadius = UDim.new(0, 4)
    
    local btnSavePlotFarm = Instance.new("TextButton", rSaveNomeF)
    btnSavePlotFarm.Size = UDim2.new(0.35, 0, 1, 0); btnSavePlotFarm.Position = UDim2.new(0.65, 0, 0, 0)
    btnSavePlotFarm.BackgroundColor3 = Color3.fromRGB(0, 160, 220)
    btnSavePlotFarm.Text = "Salvar"
    btnSavePlotFarm.TextColor3 = Color3.fromRGB(255, 255, 255)
    btnSavePlotFarm.Font = Enum.Font.SourceSansBold; btnSavePlotFarm.TextSize = 13
    btnSavePlotFarm.ZIndex = zSavVerde + 1
    Instance.new("UICorner", btnSavePlotFarm).CornerRadius = UDim.new(0, 4)

    local plotDropdownFarm = Componentes:CriarDropdown("Selecionar Save", cSavVerde, State.FarmSettings, "CurrentSaveName", false, zSavVerde + 10, false)

    local function AtualizarListaSavesFarm()
        if Bot.Modules.PlotManager and plotDropdownFarm then
            pcall(function()
                local plots = Bot.Modules.PlotManager:ObterTodos()
                local lista = {}
                for nome, _ in pairs(plots) do if nome:sub(1, 5) == "Farm_" then table.insert(lista, nome:sub(6)) end end
                plotDropdownFarm:Refresh(lista)
            end)
        end
    end

    btnSavePlotFarm.MouseButton1Click:Connect(function()
        local cubo = State.ScannerFazenda and State.ScannerFazenda.AncoraPart
        if inputPlotFarm.Text ~= "" and cubo then
            Bot.Modules.PlotManager:SalvarPlot("Farm_" .. inputPlotFarm.Text, cubo.Position, cubo.Size)
            AtualizarListaSavesFarm(); inputPlotFarm.Text = ""
        end
    end)

    local rAcoesF = Componentes:CriarGridTripla(cSavVerde, zSavVerde)
    Componentes:CriarBotaoPequeno("Load", Color3.fromRGB(40, 150, 80), rAcoesF, zSavVerde, function()
        local sn = State.FarmSettings.CurrentSaveName
        if sn and sn ~= "None" and Bot.Modules.PlotManager then
            local p = Bot.Modules.PlotManager:ObterTodos()["Farm_" .. sn]
            if p and State.ScannerFazenda then State.ScannerFazenda:CarregarPlot(Vector3.new(p.PosX, p.PosY, p.PosZ), Vector3.new(p.SizeX, p.SizeY, p.SizeZ)) end
        end
    end)
    Componentes:CriarBotaoPequeno("Rewrite", Color3.fromRGB(200, 120, 20), rAcoesF, zSavVerde, function()
        local sn = State.FarmSettings.CurrentSaveName; local cubo = State.ScannerFazenda and State.ScannerFazenda.AncoraPart
        if sn and sn ~= "None" and cubo then Bot.Modules.PlotManager:SalvarPlot("Farm_" .. sn, cubo.Position, cubo.Size) end
    end)
    Componentes:CriarBotaoPequeno("Delete", Color3.fromRGB(200, 50, 50), rAcoesF, zSavVerde, function()
        local sn = State.FarmSettings.CurrentSaveName
        if sn and sn ~= "None" then
            Bot.Modules.PlotManager:DeletarPlot("Farm_" .. sn); State.FarmSettings.CurrentSaveName = "None"
            AtualizarListaSavesFarm()
        end
    end)
    
    local rSave2F = Componentes:CriarGridDupla(cSavVerde, zSavVerde)
    Componentes:CriarCheckboxMetade("Auto-Load", rSave2F, State.FarmSettings, "AutoUseSelectedSave", zSavVerde)

    task.spawn(function()
        task.wait(1)
        pcall(AtualizarListaSavesFarm)
        pcall(AtualizarListasDeSementes)
    end)
end

return FazendaTab