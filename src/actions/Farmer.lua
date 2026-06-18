-- src/actions/Farmer.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Farmer = {}
local Bot = _G.IslandsBot
local State = Bot.State
local LocalPlayer = Players.LocalPlayer

local ZONE_MAX_SIZE = 30 
local PLACE_KEY = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nffEgdldU"

local MoverConnection = nil
local AntiGravity = nil
local currentHighlight = nil
local nextHighlight = nil

local function PararVoo()
    if MoverConnection then MoverConnection:Disconnect(); MoverConnection = nil end
    if AntiGravity then AntiGravity:Destroy(); AntiGravity = nil end

    local char = LocalPlayer.Character
    if char then
        local hum = char:FindFirstChild("Humanoid")
        local hrp = char:FindFirstChild("HumanoidRootPart")
        if hum then hum.PlatformStand = false end
        if hrp then hrp.Anchored = false; hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero end
    end
end

local function PairarEm(posicao)
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return end

    PararVoo()
    hum.PlatformStand = true; hrp.Anchored = false
    hrp.CFrame = CFrame.new(posicao)
    hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero

    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero
    AntiGravity.Parent = hrp
end

local function VoarParaFisico(destino)
    PararVoo()
    local char = LocalPlayer.Character
    local hrp = char and char:FindFirstChild("HumanoidRootPart")
    local hum = char and char:FindFirstChild("Humanoid")
    if not hrp or not hum then return false end

    hrp.Anchored = false; hum.PlatformStand = true
    AntiGravity = Instance.new("BodyVelocity")
    AntiGravity.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
    AntiGravity.Velocity = Vector3.zero; AntiGravity.Parent = hrp

    local chegou = false
    local velocidade = State.FarmSettings.TweenSpeed or 30

    MoverConnection = RunService.Heartbeat:Connect(function(dt)
        if not State.AutoFarmingCrops or not hrp.Parent then PararVoo(); chegou = true return end

        local posAtual = hrp.Position
        local dist = (destino - posAtual).Magnitude
        if dist <= 1.5 then chegou = true return end

        local step = math.min(velocidade * dt, dist)
        local dir = (destino - posAtual).Unit
        local novaPos = posAtual + (dir * step)

        hrp.CFrame = CFrame.new(novaPos, novaPos + dir)
        hrp.Velocity = Vector3.zero; hrp.RotVelocity = Vector3.zero
    end)

    while not chegou and State.AutoFarmingCrops do task.wait(0.05) end

    if State.AutoFarmingCrops then 
        PairarEm(destino)
        task.wait(0.2)
        return true 
    end
    PararVoo()
    return false
end

local function getSickleName()
    local function check(folder)
        if not folder then return nil end
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("Tool") and string.match(string.lower(item.Name), "sickle") then
                return item.Name
            end
        end
        return nil
    end
    return check(LocalPlayer.Character) or check(LocalPlayer:FindFirstChild("Backpack")) or "sickleStone"
end

local function getSickleRemote(Manager)
    if Manager.SickleRemote then return Manager.SickleRemote end
    local net = game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged")
    local remote = net:FindFirstChild("SwingSickle")
    if remote then Manager.SickleRemote = remote end
    return remote
end

local function getInventorySeedsMap()
    local seedCache = {}
    local function checkFolder(folder)
        if not folder then return end
        for _, item in ipairs(folder:GetChildren()) do
            if item:IsA("Tool") and item:FindFirstChild("seeds") then
                local baseName = string.gsub(item.Name:lower(), "seeds", "")
                baseName = string.gsub(baseName, " ", "")
                local amountVal = item:FindFirstChild("Amount")
                local qty = amountVal and amountVal.Value or 1
                if seedCache[baseName] then
                    seedCache[baseName].amount = seedCache[baseName].amount + qty
                else
                    seedCache[baseName] = {amount = qty, type = baseName}
                end
            end
        end
    end
    checkFolder(LocalPlayer:FindFirstChild("Backpack"))
    checkFolder(LocalPlayer.Character)
    return seedCache
end

local function generateZones(selectorPart)
    local zones = {}
    if not selectorPart then return zones end
    local totalSize = selectorPart.Size; local cframe = selectorPart.CFrame
    local baseY = cframe.Position.Y - (totalSize.Y / 2); local playerYPos = baseY + 4 
    
    local cols = math.max(1, math.ceil(totalSize.X / ZONE_MAX_SIZE))
    local rows = math.max(1, math.ceil(totalSize.Z / ZONE_MAX_SIZE))
    local zoneSizeX = totalSize.X / cols; local zoneSizeZ = totalSize.Z / rows
    local startX = -totalSize.X/2 + zoneSizeX/2; local startZ = -totalSize.Z/2 + zoneSizeZ/2
    
    for row = 0, rows - 1 do
        local z = startZ + (row * zoneSizeZ)
        for col = 0, cols - 1 do
            local x = startX + (col * zoneSizeX)
            local centerWorldPos = cframe:PointToWorldSpace(Vector3.new(x, 0, z))
            table.insert(zones, {
                centerPos = Vector3.new(centerWorldPos.X, playerYPos, centerWorldPos.Z),
                zoneSize = Vector3.new(zoneSizeX, totalSize.Y + 4, zoneSizeZ),
                zoneCFrame = CFrame.new(centerWorldPos.X, baseY + (totalSize.Y/2), centerWorldPos.Z)
            })
        end
    end
    return zones
end

local function sortSnakePattern(a, b)
    local gridZa = math.round(a.pos.Z / 3); local gridZb = math.round(b.pos.Z / 3)
    if gridZa == gridZb then
        if math.abs(gridZa) % 2 == 0 then return a.pos.X < b.pos.X else return a.pos.X > b.pos.X end
    else
        return gridZa < gridZb
    end
end

-- RETORNA: matureCrops, emptySoils, plowableBlocks, growingCrops
local function scanSpecificZone(zoneData, selectorPart)
    local matureCrops = {}; local emptySoils = {}; local plowableBlocks = {}; local growingCrops = {}
    
    local overlapParams = OverlapParams.new()
    overlapParams.FilterType = Enum.RaycastFilterType.Exclude
    overlapParams.FilterDescendantsInstances = {LocalPlayer.Character, selectorPart}
    
    -- Correção: Encolhe a query para não plantar nas bordas vizinhas fora do seletor
    local safeSize = zoneData.zoneSize - Vector3.new(0.2, 0.2, 0.2)
    local partsInBox = Workspace:GetPartBoundsInBox(zoneData.zoneCFrame, safeSize, overlapParams)
    
    local foundSoils = {}; local foundCropPositions = {}

    for _, part in ipairs(partsInBox) do
        if (part.Name == "grass" or part.Name == "dirt") and State.FarmSettings.PlowGrass then
            table.insert(plowableBlocks, {part = part, pos = part.Position + Vector3.new(0, 3, 0)})
        elseif part.Name == "soil" then 
            table.insert(foundSoils, part) 
        end
        
        local cropRoot = nil
        if part:FindFirstChild("stage") and part:FindFirstChild("Health") then cropRoot = part
        elseif part.Parent and part.Parent:FindFirstChild("stage") and part.Parent:FindFirstChild("Health") then cropRoot = part.Parent
        elseif part.Parent and part.Parent.Parent and part.Parent.Parent:FindFirstChild("stage") and part.Parent.Parent:FindFirstChild("Health") then cropRoot = part.Parent.Parent end
        
        if cropRoot and not foundCropPositions[cropRoot] then
            foundCropPositions[cropRoot] = cropRoot:GetPivot().Position
            local stageVal = cropRoot:FindFirstChild("stage")
            if stageVal then
                local stagePart = cropRoot:FindFirstChild("stage-" .. tostring(stageVal.Value))
                if stagePart and stagePart:FindFirstChild("Harvestable") and stagePart.Harvestable.Value == true then
                    table.insert(matureCrops, {model = cropRoot, mesh = stagePart, pos = cropRoot:GetPivot().Position})
                else
                    table.insert(growingCrops, {model = cropRoot, pos = cropRoot:GetPivot().Position})
                end
            end
        end
    end

    for _, soilPart in ipairs(foundSoils) do
        local soilTopPos = soilPart.Position + Vector3.new(0, 3, 0)
        local hasCrop = false
        for _, cropPos in pairs(foundCropPositions) do
            if (cropPos - soilTopPos).Magnitude < 1.5 then hasCrop = true; break end
        end
        if not hasCrop then table.insert(emptySoils, {part = soilPart, pos = soilTopPos}) end
    end

    table.sort(matureCrops, sortSnakePattern)
    table.sort(emptySoils, sortSnakePattern)
    table.sort(plowableBlocks, sortSnakePattern)
    
    return matureCrops, emptySoils, plowableBlocks, growingCrops
end

-- Novo Roteador Dinâmico Avançado
local function GetActiveZones(Scanner)
    local rawZones = generateZones(Scanner.AncoraPart)
    local filteredZones = {}
    
    for _, z in ipairs(rawZones) do
        if State.FarmSettings.SmartRouting then
            local mCrops, eSoils, pBlocks, gCrops = scanSpecificZone(z, Scanner.AncoraPart)
            local totalTargets = 0
            local sumPos = Vector3.new(0,0,0)
            
            local function aggregate(arr)
                for _, item in ipairs(arr) do
                    sumPos = sumPos + item.pos
                    totalTargets = totalTargets + 1
                end
            end
            
            aggregate(mCrops)
            aggregate(gCrops)
            if State.FarmSettings.PlowGrass then aggregate(pBlocks) end
            if State.FarmSettings.FillEmptySoils then aggregate(eSoils) end
            
            if totalTargets > 0 then
                local avg = sumPos / totalTargets
                z.centerPos = Vector3.new(avg.X, z.centerPos.Y, avg.Z)
                table.insert(filteredZones, z)
            end
        else
            table.insert(filteredZones, z)
        end
    end
    return filteredZones
end

local function initHighlights()
    local CoreGui = game:GetService("CoreGui")
    if not currentHighlight then
        currentHighlight = Instance.new("Highlight")
        currentHighlight.Name = "FarmCurrentTarget"
        currentHighlight.FillTransparency = 1; currentHighlight.OutlineTransparency = 0.1
        currentHighlight.Parent = CoreGui
    end
    if not nextHighlight then
        nextHighlight = Instance.new("Highlight")
        nextHighlight.Name = "FarmNextTarget"
        nextHighlight.FillTransparency = 1; nextHighlight.OutlineTransparency = 0.5
        nextHighlight.Parent = CoreGui
    end
end

function Farmer:AlternarAutoFazenda(valor)
    State.AutoFarmingCrops = valor
    local Manager = Bot.Modules.Manager

    if not valor then
        if Manager then Manager:AtualizarStatus("Ocioso") end
        PararVoo()
        if currentHighlight then currentHighlight.Adornee = nil end
        if nextHighlight then nextHighlight.Adornee = nil end
        return
    end

    local Scanner = State.ScannerFazenda
    if not Scanner or not Scanner.AncoraPart then
        State.AutoFarmingCrops = false
        if Manager then Manager:AtualizarStatus("ERRO: Crie o seletor verde primeiro!") end
        return
    end

    initHighlights()
    Manager:AtualizarStatus("Iniciando Modo Mestre V17...")

    task.spawn(function()
        local char = LocalPlayer.Character
        local hrp = char and char:WaitForChild("HumanoidRootPart")
        if not hrp then State.AutoFarmingCrops = false return end

        local currentIndex = 1

        while State.AutoFarmingCrops do
            local delayHarvest = tonumber(State.FarmSettings.HarvestDelay) or 0.1
            local delayPlant = tonumber(State.FarmSettings.PlantDelay) or 0.05
            
            local sickleName = getSickleName()
            local sRemote = getSickleRemote(Manager)
            local pRemote = Manager.PlowRemote or game:GetService("ReplicatedStorage"):WaitForChild("rbxts_include"):WaitForChild("node_modules"):WaitForChild("@rbxts"):WaitForChild("net"):WaitForChild("out"):WaitForChild("_NetManaged"):FindFirstChild("CLIENT_PLOW_BLOCK_REQUEST")

            local zones = GetActiveZones(Scanner)
            if #zones == 0 then
                Manager:AtualizarStatus("Nenhum alvo válido na área.")
                task.wait(1)
                continue
            end

            local mode = State.FarmSettings.FarmMode or "Snake Farm"
            local zoneToProcess = nil
            local didAnything = false

            -- ================= LÓGICA DE ROTEAMENTO (MODOS) =================
            if mode == "Nearest Plot" then
                local nearestZone = nil
                local minDist = math.huge
                for i, z in ipairs(zones) do
                    local mCrops, eSoils, pBlocks, gCrops = scanSpecificZone(z, Scanner.AncoraPart)
                    local needsAction = (#mCrops > 0) or (#eSoils > 0 and State.FarmSettings.FillEmptySoils) or (#pBlocks > 0 and State.FarmSettings.PlowGrass)
                    if needsAction then
                        local dist = (hrp.Position - z.centerPos).Magnitude
                        if dist < minDist then
                            minDist = dist; nearestZone = z
                        end
                    end
                end
                zoneToProcess = nearestZone
                if not zoneToProcess then Manager:AtualizarStatus("Aguardando próximo plot..."); task.wait(2); continue end

            elseif mode == "Only Fully Growth Plot" then
                for i, z in ipairs(zones) do
                    local mCrops, eSoils, pBlocks, gCrops = scanSpecificZone(z, Scanner.AncoraPart)
                    local needsAction = (#mCrops > 0 and #gCrops == 0) or (#eSoils > 0 and State.FarmSettings.FillEmptySoils) or (#pBlocks > 0 and State.FarmSettings.PlowGrass)
                    if needsAction then zoneToProcess = z; break end
                end
                if not zoneToProcess then Manager:AtualizarStatus("Aguardando cultivo total..."); task.wait(2); continue end

            elseif mode == "Wait First Plot" then
                if currentIndex > #zones then
                    Manager:AtualizarStatus("Aguardando Primeiro Plot...")
                    local firstZ = zones[1]
                    if State.FarmSettings.TweenToTarget then VoarParaFisico(firstZ.centerPos) else PairarEm(firstZ.centerPos) end
                    
                    local ready = false
                    while State.AutoFarmingCrops do
                        local _, _, _, gCrops = scanSpecificZone(firstZ, Scanner.AncoraPart)
                        if #gCrops == 0 then ready = true; break end
                        task.wait(2)
                    end
                    if ready then currentIndex = 1 end
                    continue
                else
                    zoneToProcess = zones[currentIndex]
                    currentIndex = currentIndex + 1
                end

            else -- "Snake Farm" (Padrão)
                if currentIndex > #zones then currentIndex = 1; task.wait(1); continue end
                zoneToProcess = zones[currentIndex]
                currentIndex = currentIndex + 1
            end

            if not zoneToProcess then continue end

            -- Ir fisicamente para o Plot Escolhido
            Manager:AtualizarStatus(string.format("Processando (%s)", mode))
            if State.FarmSettings.TweenToTarget then VoarParaFisico(zoneToProcess.centerPos) else PairarEm(zoneToProcess.centerPos) end
            task.wait(0.15) -- Estabilidade de rede
            
            -- ================= FASE 1: COLHEITA INTELIGENTE =================
            local failSafeLimit = 0
            while State.AutoFarmingCrops do
                local matureCrops, _, _, _ = scanSpecificZone(zoneToProcess, Scanner.AncoraPart)
                if #matureCrops == 0 then break end
                if failSafeLimit > 3 then break end
                
                currentHighlight.OutlineColor = Color3.fromRGB(255, 255, 0)
                
                -- Se Auto for verdadeiro, varre TUDO. Se não, usa o lote da UI.
                local stepValue = (State.FarmSettings.HarvestMethod == "Foice-Auto") and #matureCrops or (tonumber(State.FarmSettings.HarvestBatch) or 5)
                if stepValue <= 0 then stepValue = 1 end
                
                for i = 1, #matureCrops, stepValue do
                    if not State.AutoFarmingCrops then break end
                    local cropArray = {}
                    
                    for j = 0, stepValue - 1 do
                        local cIndex = i + j
                        if cIndex <= #matureCrops then
                            local cropData = matureCrops[cIndex]
                            if cropData.model and cropData.model.Parent then
                                table.insert(cropArray, cropData.model)
                                currentHighlight.Adornee = cropData.mesh
                            end
                        end
                    end
                    
                    if #cropArray > 0 and sRemote then
                        pcall(function() sRemote:InvokeServer(sickleName, cropArray) end)
                        didAnything = true
                        task.wait(delayHarvest)
                    end
                end
                failSafeLimit = failSafeLimit + 1
                task.wait(0.2)
            end
            
            -- ================= FASE 1.5: ARAÇÃO (AUTO-PLOW) =================
            if State.FarmSettings.PlowGrass then
                failSafeLimit = 0
                while State.AutoFarmingCrops do
                    local _, _, pBlocks, _ = scanSpecificZone(zoneToProcess, Scanner.AncoraPart)
                    if #pBlocks == 0 then break end
                    if failSafeLimit > 3 then break end
                    
                    currentHighlight.OutlineColor = Color3.fromRGB(139, 69, 19)
                    local stepValue = (State.FarmSettings.PlantMethod == "Plant-All") and #pBlocks or (tonumber(State.FarmSettings.PlantBatch) or 5)
                    if stepValue <= 0 then stepValue = 1 end
                    
                    local plowedAtLeastOne = false
                    for i = 1, #pBlocks, stepValue do
                        if not State.AutoFarmingCrops then break end
                        
                        for j = 0, stepValue - 1 do
                            local pIndex = i + j
                            if pIndex <= #pBlocks then
                                local blockData = pBlocks[pIndex]
                                if blockData.part and blockData.part.Parent then
                                    currentHighlight.Adornee = blockData.part
                                    task.spawn(function()
                                        if pRemote then pcall(function() pRemote:InvokeServer({block = blockData.part}) end) end
                                    end)
                                    plowedAtLeastOne = true
                                end
                            end
                        end
                        if plowedAtLeastOne then 
                            task.wait(delayPlant) 
                            didAnything = true
                        end
                    end
                    
                    if not plowedAtLeastOne then break end
                    failSafeLimit = failSafeLimit + 1
                    task.wait(0.2)
                end
            end
            
            -- ================= FASE 2: PLANTIO INTELIGENTE (ALL OU EACH) =================
            if State.FarmSettings.FillEmptySoils then
                failSafeLimit = 0
                while State.AutoFarmingCrops do
                    local _, emptySoils, _, _ = scanSpecificZone(zoneToProcess, Scanner.AncoraPart)
                    if #emptySoils == 0 then break end
                    if failSafeLimit > 3 then break end
                    
                    local invCache = getInventorySeedsMap()
                    currentHighlight.OutlineColor = Color3.fromRGB(0, 255, 0)
                    nextHighlight.OutlineColor = Color3.fromRGB(0, 0, 255)
                    
                    -- Avalia se deve estourar o lote inteiro ("Plant-All") ou ir com limite
                    local stepValue = (State.FarmSettings.PlantMethod == "Plant-All") and #emptySoils or (tonumber(State.FarmSettings.PlantBatch) or 5)
                    if stepValue <= 0 then stepValue = 1 end
                    
                    local plantedAtLeastOne = false
                    
                    for i = 1, #emptySoils, stepValue do
                        if not State.AutoFarmingCrops then break end
                        
                        for j = 0, stepValue - 1 do
                            local eIndex = i + j
                            if eIndex <= #emptySoils then
                                local soilData = emptySoils[eIndex]
                                if not soilData.part or not soilData.part.Parent then continue end
                                
                                local chosenSeed = nil
                                local prioSeed = State.FarmSettings.PrioritizePlant
                                local permittedSeeds = State.SementeSelecionada or {}
                                
                                local function cleanSeedName(name)
                                    if not name or name == "Nenhum" or name == "None" or name == "None Found" then return nil end
                                    local clean = string.gsub(name:lower(), "seeds", "")
                                    return string.gsub(clean, " ", "")
                                end

                                local cleanPrio = cleanSeedName(prioSeed)

                                if cleanPrio and invCache[cleanPrio] and invCache[cleanPrio].amount > 0 then
                                    chosenSeed = cleanPrio
                                else
                                    local allowAll = permittedSeeds["All"] == true
                                    for uiSeedName, isAllowed in pairs(permittedSeeds) do
                                        if isAllowed and uiSeedName ~= "All" then
                                            local cleanPerm = cleanSeedName(uiSeedName)
                                            if cleanPerm and invCache[cleanPerm] and invCache[cleanPerm].amount > 0 then
                                                chosenSeed = cleanPerm; break
                                            end
                                        end
                                    end
                                    if not chosenSeed and allowAll then
                                        for seedName, seedData in pairs(invCache) do
                                            if seedData.amount > 0 then chosenSeed = seedName; break end
                                        end
                                    end
                                end
                                
                                if chosenSeed then
                                    plantedAtLeastOne = true
                                    invCache[chosenSeed].amount = invCache[chosenSeed].amount - 1 
                                    
                                    currentHighlight.Adornee = soilData.part
                                    nextHighlight.Adornee = (eIndex < #emptySoils and emptySoils[eIndex+1].part) or nil
                                    
                                    local plantCFrame = CFrame.new(soilData.pos.X, soilData.pos.Y, soilData.pos.Z)
                                    local placePayload = { uwhiHAMdjExWka = PLACE_KEY, cframe = plantCFrame, blockType = chosenSeed, upperBlock = false }
                                    
                                    task.spawn(function()
                                        if Manager.PlaceRemote then pcall(function() Manager.PlaceRemote:InvokeServer(placePayload) end) end
                                    end)
                                end
                            end
                        end
                        if plantedAtLeastOne then 
                            task.wait(delayPlant) 
                            didAnything = true
                        end
                    end
                    
                    if not plantedAtLeastOne then break end
                    failSafeLimit = failSafeLimit + 1
                    task.wait(0.2)
                end
            end
            
            currentHighlight.Adornee = nil; nextHighlight.Adornee = nil
        end
        
        if currentHighlight then currentHighlight.Adornee = nil end
        if nextHighlight then nextHighlight.Adornee = nil end
        PararVoo()
    end)
end

return Farmer