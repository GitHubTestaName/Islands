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

    -- ================= BLOCO 1: MAPEAMENTO E ILHA =================
    local cMap, zMap = Componentes:CriarCard("MAPEAMENTO E ILHA", paginaPai)
    
    Componentes:CriarBotaoEstilizado("🔄 Sincronizar Mundo", cMap, zMap, function()
        WildMiner:MapearMundo()
    end)
    
    local dropIlha = Componentes:CriarDropdown("▼ Selecionar Ilha", cMap, State.WildSettings, "SelectedIsland", false, zMap, false)
    
    Componentes:CriarBotaoEstilizado("❌ Desmarcar Todos", cMap, zMap, function()
        State.WildSettings.SelectedBlocks = {}
        WildMiner:AtualizarESP()
    end)

    -- ================= BLOCO 2: LISTA DE MINÉRIOS =================
    local cMin, zMin = Componentes:CriarCard("MINÉRIOS DISPONÍVEIS", paginaPai, 250)
    
    local scrollBlocks = Instance.new("ScrollingFrame", cMin)
    scrollBlocks.Size = UDim2.new(0.95, 0, 1, -10)
    scrollBlocks.Position = UDim2.new(0.025, 0, 0, 5)
    scrollBlocks.BackgroundTransparency = 1
    scrollBlocks.ScrollBarThickness = 4
    local scrollLayout = Instance.new("UIListLayout", scrollBlocks)
    scrollLayout.Padding = UDim.new(0, 3)
    scrollLayout.SortOrder = Enum.SortOrder.Name

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
    local cCfg, zCfg = Componentes:CriarCard("CONFIG & ESP", paginaPai)
    
    local rCfg1 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarInputMetade("Hit Delay:", rCfg1, State.WildSettings, "HitCooldown", 0.15, zCfg)
    Componentes:CriarInputMetade("Speed:", rCfg1, State.WildSettings, "TweenSpeed", 30, zCfg)

    local rCfg2 = Componentes:CriarGridDupla(cCfg, zCfg)
    Componentes:CriarCheckboxMetade("ESP Geral", rCfg2, State.WildSettings, "EspGeral", zCfg, function() WildMiner:AtualizarESP() end)
    Componentes:CriarCheckboxMetade("ESP Alvos", rCfg2, State.WildSettings, "EspSpecific", zCfg, function() WildMiner:AtualizarESP() end)

    -- ================= BLOCO 4: PORTAIS =================
    local cPort, zPort = Componentes:CriarCard("TELEPORTES GLOBAIS", paginaPai)
    local dropPortal = Componentes:CriarDropdown("▼ Escolher Portal", cPort, State.WildSettings, "SelectedPortal", false, zPort, false)
    
    Componentes:CriarBotaoEstilizado("⚡ Usar Portal (Touch Interest)", cPort, zPort, function()
        if State.WildSettings.SelectedPortal and State.WildSettings.SelectedPortal ~= "Nenhum" then
            WildMiner:UsarPortal(State.WildSettings.SelectedPortal)
        end
    end)

    -- ================= BLOCO 5: RUN =================
    local cRun, zRun = Componentes:CriarCard("MOTOR PRINCIPAL", paginaPai)
    Componentes:CriarToggleLargo("Ativar Wild Miner", cRun, State.WildSettings, "IsMining", zRun, function(v)
        WildMiner:Alternar(v)
    end)

    -- ================= LOOPS E EVENTOS DE SINCRONIZAÇÃO =================
    -- Thread inteligente para atualizar a UI sem mexer no script do Components
    local ultimaIlha = nil
    task.spawn(function()
        while task.wait(0.2) do
            -- Sincroniza blocos se a ilha mudou
            if State.WildSettings.SelectedIsland ~= ultimaIlha then
                ultimaIlha = State.WildSettings.SelectedIsland
                PopulateBlockList(ultimaIlha)
                WildMiner:AtualizarESP()
            end
            
            -- Sincroniza Dropdowns se o Cache de Mundo mudou
            local ilhas = WildMiner:GetIlhasDisponiveis()
            local ports = WildMiner:GetPortaisDisponiveis()
            
            -- Prevenção de loop invisível
            if not State.UltimasIlhasSync or #ilhas ~= #State.UltimasIlhasSync then
                State.UltimasIlhasSync = ilhas
                dropIlha:Refresh(ilhas)
            end
            if not State.UltimosPortaisSync or #ports ~= #State.UltimosPortaisSync then
                State.UltimosPortaisSync = ports
                dropPortal:Refresh(ports)
            end
        end
    end)
    
    -- Botão limpar todos re-renderiza lista local
    local btnDesmarcar = cMap:FindFirstChild("Button_❌ Desmarcar Todos")
    if btnDesmarcar then
        btnDesmarcar.MouseButton1Click:Connect(function()
            PopulateBlockList(ultimaIlha)
        end)
    end
end

return WildTab