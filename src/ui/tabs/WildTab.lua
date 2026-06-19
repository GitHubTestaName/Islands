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
        SelectedBlocks = {},
        HitCooldown = 0.15,
        TweenSpeed = 30,
        EspGeral = false,
        EspSpecific = false
    }

    -- ================= BLOCO 1: MAPEAMENTO E ILHA =================
    local cMap, zMap = Componentes:CriarCard("MAPEAMENTO DE ZONAS", paginaPai)
    
    local dropIlha = Componentes:CriarDropdown("▼ Selecionar Ilha", cMap, State.WildSettings, "SelectedIsland", false, zMap, false)
    
    Componentes:CriarBotaoEstilizado("❌ Desmarcar Todos", cMap, zMap, function()
        State.WildSettings.SelectedBlocks = {}
        WildMiner:AtualizarESP()
    end)

    -- ================= BLOCO 2: LISTA DE MINÉRIOS (Z-INDEX FIX) =================
    local cMin, zMin = Componentes:CriarCard("MINÉRIOS DISPONÍVEIS", paginaPai, 250)
    -- Elevando a ordem global do painel direito
    cMin.ZIndex = 10 
    
    local scrollBlocks = Instance.new("ScrollingFrame", cMin)
    scrollBlocks.Size = UDim2.new(0.95, 0, 1, -10)
    scrollBlocks.Position = UDim2.new(0.025, 0, 0, 5)
    scrollBlocks.BackgroundTransparency = 1
    scrollBlocks.ScrollBarThickness = 4
    scrollBlocks.ZIndex = 15 -- Z-Index mais alto para ficar acima do fundo
    
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
            header.ZIndex = 20 -- FORÇANDO NA FRENTE DE TUDO!
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
                btn.ZIndex = 20 -- FORÇANDO NA FRENTE DE TUDO!
                
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
    local cPort, zPort = Componentes:CriarCard("TELEPORTES INTELIGENTES", paginaPai)
    local dropPortal = Componentes:CriarDropdown("▼ Escolher Portal", cPort, State.WildSettings, "SelectedPortal", false, zPort, false)

    -- ================= BLOCO 5: RUN =================
    local cRun, zRun = Componentes:CriarCard("MOTOR PRINCIPAL", paginaPai)
    Componentes:CriarToggleLargo("Ativar Wild Miner", cRun, State.WildSettings, "IsMining", zRun, function(v)
        WildMiner:Alternar(v)
    end)

    -- ================= AUTO-UPDATE & LISTENERS =================
    -- Pega os botões nativos do componente Dropdown (que você já construiu no Components.lua)
    local dFrameIsland = cMap:FindFirstChild("DropdownContainer_SelectedIsland")
    if dFrameIsland then
        local trigBtn = dFrameIsland:FindFirstChild("TriggerButton")
        if trigBtn then
            -- MÁGICA: Atualiza o mundo instantes antes de o dropdown do Components.lua abrir a lista!
            trigBtn.MouseButton1Click:Connect(function()
                WildMiner:MapearMundo()
                dropIlha:Refresh(WildMiner:GetIlhasDisponiveis())
            end)
        end
    end

    local dFramePortal = cPort:FindFirstChild("DropdownContainer_SelectedPortal")
    if dFramePortal then
        local trigPBtn = dFramePortal:FindFirstChild("TriggerButton")
        if trigPBtn then
            trigPBtn.MouseButton1Click:Connect(function()
                WildMiner:MapearMundo()
                dropPortal:Refresh(WildMiner:GetPortaisDisponiveis())
            end)
        end
        
        -- Event listener pro teleporte 1-Click
        local menuPanel = dFramePortal:FindFirstChild("MenuListPanel")
        if menuPanel then
            local pScroll = menuPanel:FindFirstChild("Scroller")
            if pScroll then
                pScroll.ChildAdded:Connect(function(child)
                    if child:IsA("TextButton") then
                        child.MouseButton1Click:Connect(function()
                            -- Extrai o nome do portal do texto (tirando espaços iniciais que o Component usa)
                            local destName = string.gsub(child.Text, "^%s+", "")
                            if destName ~= "None Found" then
                                WildMiner:UsarPortal(destName)
                            end
                        end)
                    end
                end)
            end
        end
    end

    -- Escutador de Mudança de Ilha para Renderizar a Lista da Direita
    local ultimaIlha = nil
    task.spawn(function()
        while task.wait(0.2) do
            if State.WildSettings.SelectedIsland ~= ultimaIlha then
                ultimaIlha = State.WildSettings.SelectedIsland
                PopulateBlockList(ultimaIlha)
                WildMiner:AtualizarESP()
            end
        end
    end)
    
    local btnDesmarcar = cMap:FindFirstChild("Button_❌ Desmarcar Todos")
    if btnDesmarcar then
        btnDesmarcar.MouseButton1Click:Connect(function() PopulateBlockList(ultimaIlha) end)
    end
end

return WildTab