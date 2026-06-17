-- src/core/Scanner.lua
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local CoreGui = game:GetService("CoreGui")

local Scanner = {}
Scanner.__index = Scanner

local Bot = _G.IslandsBot
local Config = Bot.Config
local LocalPlayer = Players.LocalPlayer

function Scanner.new(corCubo)
    local self = setmetatable({}, Scanner)
    self.Cor = corCubo or Color3.fromRGB(0, 150, 255)
    self.HideNumbers = false 
    self.AncoraPart = nil
    self.Handles = nil
    self.CaixaVisual = nil
    self.MarcadoresVisuais = {}
    self.ListaBlocos = {}
    return self
end

function Scanner:LimparEnumeracao()
    for _, obj in pairs(self.MarcadoresVisuais) do if obj then obj:Destroy() end end
    self.MarcadoresVisuais = {}
    self.ListaBlocos = {}
end

function Scanner:LimparAncora()
    if self.AncoraPart then self.AncoraPart:Destroy() end
    if self.Handles then self.Handles:Destroy() end
    self.AncoraPart = nil
    self:LimparEnumeracao()
end

function Scanner:CriarNumeroVisual(posicao, numero)
    if self.HideNumbers then return nil end
    local part = Instance.new("Part")
    part.Size = Vector3.new(0.5, 0.5, 0.5)
    part.Position = posicao + Vector3.new(0, 1.5, 0)
    part.Anchored = true
    part.CanCollide = false
    part.CanQuery = false
    part.CanTouch = false
    part.Transparency = 1
    part.Parent = Workspace
    local bg = Instance.new("BillboardGui", part)
    bg.Size = UDim2.new(0, 25, 0, 25)
    bg.AlwaysOnTop = true
    local txt = Instance.new("TextLabel", bg)
    txt.Size = UDim2.new(1, 0, 1, 0)
    txt.BackgroundTransparency = 0.2
    txt.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
    txt.TextColor3 = Color3.fromRGB(255, 255, 255)
    txt.TextScaled = true
    txt.Font = Enum.Font.SourceSansBold
    txt.Text = tostring(numero)
    table.insert(self.MarcadoresVisuais, part)
    return part
end

function Scanner:AlinharParaGrid(posicao)
    local offsetGrid = Vector3.new(0, 0, 0)
    local minhaIlha = nil
    for _, island in pairs(Workspace:WaitForChild("Islands"):GetChildren()) do
        if island:FindFirstChild("Blocks") then minhaIlha = island; break end
    end
    if minhaIlha then
        local umBloco = minhaIlha.Blocks:FindFirstChildWhichIsA("Model") or minhaIlha.Blocks:FindFirstChildWhichIsA("BasePart")
        if umBloco then
            local bp = umBloco:IsA("Model") and umBloco:GetPivot().Position or umBloco.Position
            offsetGrid = Vector3.new(bp.X % Config.BLOCK_SIZE, bp.Y % Config.BLOCK_SIZE, bp.Z % Config.BLOCK_SIZE)
        end
    end
    local nx = math.floor((posicao.X - offsetGrid.X) / Config.BLOCK_SIZE + 0.5) * Config.BLOCK_SIZE + offsetGrid.X
    local ny = math.floor((posicao.Y - offsetGrid.Y) / Config.BLOCK_SIZE + 0.5) * Config.BLOCK_SIZE + offsetGrid.Y
    local nz = math.floor((posicao.Z - offsetGrid.Z) / Config.BLOCK_SIZE + 0.5) * Config.BLOCK_SIZE + offsetGrid.Z
    return Vector3.new(nx, ny, nz)
end

function Scanner:MoverSeletor(direcao)
    if not self.AncoraPart then return end
    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local look = char.HumanoidRootPart.CFrame.LookVector
    local frenteWorld, direitaWorld
    if math.abs(look.X) > math.abs(look.Z) then
        frenteWorld = Vector3.new(math.sign(look.X) * Config.BLOCK_SIZE, 0, 0)
        direitaWorld = Vector3.new(0, 0, math.sign(look.X) * Config.BLOCK_SIZE)
    else
        frenteWorld = Vector3.new(0, 0, math.sign(look.Z) * Config.BLOCK_SIZE)
        direitaWorld = Vector3.new(-math.sign(look.Z) * Config.BLOCK_SIZE, 0, 0)
    end
    local d = Vector3.new(0,0,0)
    if direcao == "Frente" then d = frenteWorld
    elseif direcao == "Tras" then d = -frenteWorld
    elseif direcao == "Esquerda" then d = -direitaWorld
    elseif direcao == "Direita" then d = direitaWorld
    elseif direcao == "Subir" then d = Vector3.new(0, Config.BLOCK_SIZE, 0)
    elseif direcao == "Descer" then d = Vector3.new(0, -Config.BLOCK_SIZE, 0)
    end
    self.AncoraPart.Position = self.AncoraPart.Position + d
    if self.CaixaVisual then self.CaixaVisual.Adornee = self.AncoraPart end
    self:EscanearArea()
end

-- 🚨 FUNÇÃO ESCALADORA: Sobe os parentes do objeto até achar o "Health"
local function EncontrarRaizComVida(obj)
    local atual = obj
    while atual and atual ~= workspace do
        if atual:FindFirstChild("Health") then
            return atual
        end
        atual = atual.Parent
    end
    return nil
end

function Scanner:EscanearArea()
    if not self.AncoraPart then return end
    self:LimparEnumeracao()
    
    local querySize = self.AncoraPart.Size - Vector3.new(0.2, 0.2, 0.2)
    local partsInBox = workspace:GetPartBoundsInBox(self.AncoraPart.CFrame, querySize)
    
    local blocosUnicos = {}
    local blocosEncontrados = {}
    local Manager = Bot.Modules.Manager
    
    for _, part in ipairs(partsInBox) do
        if part.Name == "SelectionAnchor_Script" or part.Name == "IslandsFarm_Aura" then continue end
        local lowerName = part.Name:lower()
        if lowerName == "trunk" or lowerName == "top" then continue end
        
        local eDeJogador = false
        for _, plr in ipairs(Players:GetPlayers()) do
            if plr.Character and part:IsDescendantOf(plr.Character) then
                eDeJogador = true
                break
            end
        end
        if eDeJogador then continue end
        
        -- A MÁGICA DE HUB: Descobre quem é o Modelo Raiz de verdade
        local rootBlock = EncontrarRaizComVida(part)
        
        -- Se não tem Health em lugar nenhum, cai na lógica normal de blocos da ilha
        if not rootBlock then
            rootBlock = Manager:ObterBlocoRaiz(part)
        end
        
        if rootBlock and not blocosUnicos[rootBlock] then
            if rootBlock.Name:lower():find("bedrock") then continue end
            
            blocosUnicos[rootBlock] = true
            local pos = rootBlock:IsA("Model") and rootBlock:GetPivot().Position or rootBlock.Position
            table.insert(blocosEncontrados, { Instancia = rootBlock, Posicao = pos, Nome = rootBlock.Name })
        end
    end
    
    table.sort(blocosEncontrados, function(a, b)
        if math.abs(a.Posicao.Y - b.Posicao.Y) > 0.5 then return a.Posicao.Y > b.Posicao.Y end
        if math.abs(a.Posicao.Z - b.Posicao.Z) > 0.5 then return a.Posicao.Z < b.Posicao.Z end
        return a.Posicao.X < b.Posicao.X
    end)
    
    for i, dadosBloco in ipairs(blocosEncontrados) do
        local visualPart = self:CriarNumeroVisual(dadosBloco.Posicao, i)
        if visualPart then dadosBloco.Marcador = visualPart end
        table.insert(self.ListaBlocos, dadosBloco)
    end
end

function Scanner:MontarCuboVisuais(posExata, tamanho)
    self:LimparAncora()
    self.AncoraPart = Instance.new("Part")
    self.AncoraPart.Size = tamanho or Vector3.new(Config.BLOCK_SIZE, Config.BLOCK_SIZE, Config.BLOCK_SIZE)
    self.AncoraPart.Position = posExata
    self.AncoraPart.Anchored = true
    self.AncoraPart.CanCollide = false
    self.AncoraPart.CanQuery = false 
    self.AncoraPart.CanTouch = false
    self.AncoraPart.Transparency = 0.7
    self.AncoraPart.Color = self.Cor
    self.AncoraPart.Parent = Workspace
    self.CaixaVisual = Instance.new("SelectionBox")
    self.CaixaVisual.Color3 = self.Cor
    self.CaixaVisual.LineThickness = 0.05
    self.CaixaVisual.Adornee = self.AncoraPart
    self.CaixaVisual.Parent = self.AncoraPart
    self.Handles = Instance.new("Handles")
    self.Handles.Color3 = Color3.fromRGB(255, 200, 50)
    self.Handles.Style = Enum.HandlesStyle.Resize
    self.Handles.Adornee = self.AncoraPart
    self.Handles.Parent = CoreGui
    local sizeInicial, cframeInicial
    self.Handles.MouseButton1Down:Connect(function()
        sizeInicial = self.AncoraPart.Size
        cframeInicial = self.AncoraPart.CFrame
    end)
    self.Handles.MouseDrag:Connect(function(face, distancia)
        local deltaSnap = math.floor(distancia / Config.BLOCK_SIZE + 0.5) * Config.BLOCK_SIZE
        if face == Enum.NormalId.Front or face == Enum.NormalId.Back then
            self.AncoraPart.Size = sizeInicial + Vector3.new(0, 0, deltaSnap)
            self.AncoraPart.CFrame = cframeInicial * CFrame.new(0, 0, deltaSnap / 2 * (face == Enum.NormalId.Front and -1 or 1))
        elseif face == Enum.NormalId.Top or face == Enum.NormalId.Bottom then
            self.AncoraPart.Size = sizeInicial + Vector3.new(0, deltaSnap, 0)
            self.AncoraPart.CFrame = cframeInicial * CFrame.new(0, deltaSnap / 2 * (face == Enum.NormalId.Top and 1 or -1), 0)
        elseif face == Enum.NormalId.Right or face == Enum.NormalId.Left then
            self.AncoraPart.Size = sizeInicial + Vector3.new(deltaSnap, 0, 0)
            self.AncoraPart.CFrame = cframeInicial * CFrame.new(deltaSnap / 2 * (face == Enum.NormalId.Right and 1 or -1), 0, 0)
        end
    end)
    self.Handles.MouseButton1Up:Connect(function() self:EscanearArea() end)
    self:EscanearArea()
end

function Scanner:CriarSeletorFrontal()
    if self.AncoraPart then self:LimparAncora() return end

    local char = LocalPlayer.Character
    if not char or not char:FindFirstChild("HumanoidRootPart") then return end
    local hrp = char.HumanoidRootPart
    local look = hrp.CFrame.LookVector
    local dirVector = Vector3.new(0, 0, 0)
    if math.abs(look.X) > math.abs(look.Z) then
        dirVector = Vector3.new(math.sign(look.X) * Config.BLOCK_SIZE, 0, 0)
    else
        dirVector = Vector3.new(0, 0, math.sign(look.Z) * Config.BLOCK_SIZE)
    end
    local posExata = hrp.Position + dirVector
    local Manager = Bot.Modules.Manager
    local params = RaycastParams.new()
    params.FilterDescendantsInstances = {char}
    params.FilterType = Enum.RaycastFilterType.Exclude
    local ray = workspace:Raycast(hrp.Position, Vector3.new(0, -20, 0), params)
    if ray and ray.Instance and Manager then
        local inst = ray.Instance
        local lowerName = inst.Name:lower()
        if lowerName ~= "trunk" and lowerName ~= "top" then
            local rootBlock = Manager:ObterBlocoRaiz(inst)
            if rootBlock then
                local hitPos = rootBlock:IsA("Model") and rootBlock:GetPivot().Position or rootBlock.Position
                posExata = hitPos + dirVector
            end
        end
    end
    posExata = self:AlinharParaGrid(posExata)
    self:MontarCuboVisuais(posExata)
end

function Scanner:CarregarPlot(posicao, tamanho)
    self:MontarCuboVisuais(posicao, tamanho)
end

Bot.State.ScannerGeral = Scanner.new(Color3.fromRGB(0, 150, 255))
Bot.State.ScannerFazenda = Scanner.new(Color3.fromRGB(50, 255, 50))

return Scanner