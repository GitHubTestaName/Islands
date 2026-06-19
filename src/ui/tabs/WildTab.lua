-- src/ui/tabs/WildTab.lua
local WildTab = {}

function WildTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents
    local WildMiner = Bot.Modules.WildMiner

    Componentes:ResetOrder()

    State.WildSettings = State.WildSettings or {
        IsMining = false,
        SelectedIsland = "Nenhum",
        SelectedPortal = "Nenhum",
        SelectedBlocks = {},
        HitCooldown = 0.15,
        TweenSpeed = 30,
        EspGeral = false,
        EspSpecific = false
    }

    WildMiner:MapearMundo() -- Mapeamento base para evitar listas vazias

    -- ================= BLOCO 1: MAPEAMENTO E ILHA =================
    local cMap, zMap = Componentes:CriarCard("ZONAS DE MINERAÇÃO", paginaPai)
    
    local dropIlha = Componentes:CriarDropdown("▼ Selecionar Ilha", cMap, State.WildSettings, "SelectedIsland", false, zMap, false)
    if dropIlha then dropIlha:Refresh(WildMiner:GetIlhasDisponiveis()) end
    
    Componentes:CriarBotaoEstilizado("❌ Desmarcar Todos (Limpar Fila)", cMap, zMap, function()
        State.WildSettings.SelectedBlocks = {}
        WildMiner:AtualizarESP()
    end)

    -- ================= BLOCO 2: LISTA DE MINÉRIOS (Z-INDEX & COLAPSO FIX) =================
    local cMin, zMin = Componentes:CriarCard("MINÉRIOS DISPONÍVEIS", paginaPai)
    
    -- SOLUÇÃO DA LISTA INVISÍVEL: A altura deve ser fixa em PIXELS (ex: 220), senão a engine colapsa para 0 de tamanho!
    local scrollBlocks = Instance.new("ScrollingFrame", cMin)
    scrollBlocks.Size = UDim2.new(0.95, 0, 0, 220) 
    scrollBlocks.Position = UDim2.new(0.025, 0, 0, 0)
    scrollBlocks.BackgroundTransparency = 1
    scrollBlocks.ScrollBarThickness = 4
    scrollBlocks.ZIndex = zMin + 1
    scrollBlocks.LayoutOrder = Componentes:GetInnerOrder()
    
    local scrollLayout = Instance.new("UIListLayout", scrollBlocks)
    scrollLayout.Padding = UDim.new(0, 3)
    scrollLayout.SortOrder = Enum.SortOrder.Name -- Respeita nossa numeração de forma perfeita

    local function PopulateBlockList(islandCat)
        for _, child in ipairs(scrollBlocks:GetChildren()) do
            if child:IsA("TextLabel") or child:IsA("TextButton") or child:IsA("Frame") then child:Destroy() end
        end
        if not islandCat or islandCat == "Nenhum" or not WildMiner.CacheBlocos[islandCat] then return end
        
        local totalY = 0
        local orderIndex = 1 
        local function GetNextOrder()
            local str = string.format("%04d", orderIndex)
            orderIndex = orderIndex + 1; return str
        end
        
        local sortedSubRegions = {}
        for subReg, _ in pairs(WildMiner.CacheBlocos[islandCat]) do table.insert(sortedSubRegions, subReg) end
        table.sort(sortedSubRegions)

        for _, subRegName in ipairs(sortedSubRegions) do
            local header = Instance.new("TextLabel", scrollBlocks)
            header.Name = GetNextOrder() .. "_Header"
            header.Size = UDim2.new(1, 0, 0, 22); header.BackgroundColor3 = Color3.fromRGB(40, 40, 40)
            header.Text = " -- " .. subRegName .. " --"
            header.TextColor3 = Color3.fromRGB(0, 180, 255); header.Font = Enum.Font.SourceSansBold
            header.TextSize = 13; header.TextXAlignment = Enum.TextXAlignment.Center
            header.ZIndex = zMin + 2
            Instance.new("UICorner", header).CornerRadius = UDim.new(0, 4)
            totalY = totalY + 25

            local sortedBlocks = {}
            for blockName, _ in pairs(WildMiner.CacheBlocos[islandCat][subRegName]) do table.insert(sortedBlocks, blockName) end
            table.sort(sortedBlocks)

            for _, blockName in ipairs(sortedBlocks) do
                local key = subRegName .. "|" .. blockName
                local btn = Instance.new("TextButton", scrollBlocks)
                btn.Name = GetNextOrder() .. "_Item"
                btn.Size = UDim2.new(1, 0, 0, 25)
                btn.ZIndex = zMin + 2
                
                local isSelected = State.WildSettings.SelectedBlocks[key]
                btn.BackgroundColor3 = isSelected and Componentes.Theme.ToggleOn or Componentes.Theme.ButtonBG
                btn.Text = "   " .. (isSelected and "[ V ] " or "[   ] ") .. blockName
                btn.TextColor3 = isSelected and Componentes.Theme.TextWhite or Componentes.Theme.TextDimmed
                btn.Font = Enum.Font.SourceSansSemibold; btn.TextSize = 13; btn.TextXAlignment = Enum.TextXAlignment.Left
                Instance.new("UICorner", btn).CornerRadius = UDim.new(0, 4)
                
                btn.MouseButton1Click:Connect(function()
                    State.WildSettings.SelectedBlocks[key] = not State.WildSettings.SelectedBlocks[key]
                    local newVal = State.WildSettings.SelectedBlocks[key]
                    btn.BackgroundColor3 = newVal and Componentes.Theme.ToggleOn or Componentes.Theme.ButtonBG
                    btn.Text = "   " .. (newVal and "[ V ] " or "[   ] ") .. blockName
                    btn.TextColor3 = newVal and Componentes.Theme.TextWhite or Componentes.Theme.TextDimmed
                    WildMiner:AtualizarESP()
                end)
                totalY = totalY + 28
            end
            
            local spacer = Instance.new("Frame", scrollBlocks)
            spacer.Name = GetNextOrder() .. "_Spacer"
            spacer.Size = UDim2.new(1, 0, 0, 5); spacer.BackgroundTransparency = 1
            totalY = totalY + 8
        end
        scrollBlocks.CanvasSize = UDim2.new(0, 0, 0, totalY)
    end

    -- ================= BLOCO 3: CONFIG & ESP =================
    local cCfg, zCfg = Componentes:CriarCard("CONFIGURAÇÕES DE AÇÃO", paginaPai)
    
    local rCfg1 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarInputMetade("Hit Delay:", rCfg1, State.WildSettings, "HitCooldown", "0.15", zCfg)
    Componentes:CriarInputMetade("Veloc. Voo:", rCfg1, State.WildSettings, "TweenSpeed", "30", zCfg)

    local rCfg2 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarCheckboxMetade("ESP Ilha", rCfg2, State.WildSettings, "EspGeral", zCfg, function() WildMiner:AtualizarESP() end)
    Componentes:CriarCheckboxMetade("ESP Alvos", rCfg2, State.WildSettings, "EspSpecific", zCfg, function() WildMiner:AtualizarESP() end)

    -- ================= BLOCO 4: PORTAIS =================
    local cPort, zPort = Componentes:CriarCard("TELEPORTE INSTANTÂNEO", paginaPai)
    local dropPortal = Componentes:CriarDropdown("▼ Clique p/ Teleportar...", cPort, State.WildSettings, "SelectedPortal", false, zPort, false)
    if dropPortal then dropPortal:Refresh(WildMiner:GetPortaisDisponiveis()) end

    -- ================= BLOCO 5: MOTOR =================
    local cRun, zRun = Componentes:CriarCard("MOTOR PRINCIPAL", paginaPai)
    Componentes:CriarToggleLargo("Ativar Wild Miner", cRun, State.WildSettings, "IsMining", zRun, function(v)
        WildMiner:Alternar(v)
    end)

    -- ================= AUTO-UPDATE (SEGUNDO PLANO) E EVENTOS =================
    
    local screenGui = paginaPai:FindFirstAncestorWhichIsA("ScreenGui")
    
    -- Vigilante: Se o script ou a interface for fechado de forma forçada, ele varre as caixas ESP do mapa.
    task.spawn(function()
        while task.wait(0.5) do
            if not screenGui or not screenGui.Parent then
                WildMiner:LimparTudo()
                break
            end
        end
    end)

    -- Scanner Automático e Silencioso (Substitui o botão de sincronizar)
    task.spawn(function()
        while task.wait(2) do
            if not screenGui or not screenGui.Parent then break end
            
            if not State.WildSettings.IsMining then
                WildMiner:MapearMundo()
                if dropIlha and type(dropIlha.Refresh) == "function" then
                    dropIlha:Refresh(WildMiner:GetIlhasDisponiveis())
                end
                if dropPortal and type(dropPortal.Refresh) == "function" then
                    dropPortal:Refresh(WildMiner:GetPortaisDisponiveis())
                end
            end
        end
    end)

    -- Escutador Instântaneo de Ações nos Dropdowns (Zero Lag)
    local ultimaIlha = State.WildSettings.SelectedIsland
    local ultimoPortal = State.WildSettings.SelectedPortal
    
    task.spawn(function()
        while task.wait(0.1) do
            if not screenGui or not screenGui.Parent then break end
            
            -- Renderiza blocos quando a ilha troca
            if State.WildSettings.SelectedIsland ~= ultimaIlha then
                ultimaIlha = State.WildSettings.SelectedIsland
                PopulateBlockList(ultimaIlha)
                WildMiner:AtualizarESP()
            end
            
            -- Dispara Teleporte automaticamente quando clica na lista
            if State.WildSettings.SelectedPortal ~= ultimoPortal then
                ultimoPortal = State.WildSettings.SelectedPortal
                if ultimoPortal and ultimoPortal ~= "Nenhum" then
                    WildMiner:UsarPortal(ultimoPortal)
                    
                    -- Reseta o Dropdown para o título padrão instantaneamente
                    State.WildSettings.SelectedPortal = "Nenhum"
                    ultimoPortal = "Nenhum"
                    if dropPortal and type(dropPortal.Refresh) == "function" then
                        dropPortal:Refresh(WildMiner:GetPortaisDisponiveis())
                    end
                end
            end
        end
    end)

    local btnDesmarcar = cMap:FindFirstChild("Button_❌ Desmarcar Todos (Limpar Fila)")
    if btnDesmarcar then
        btnDesmarcar.MouseButton1Click:Connect(function() PopulateBlockList(ultimaIlha) end)
    end
end

return WildTab