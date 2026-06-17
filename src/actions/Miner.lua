-- src/actions/Miner.lua
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Miner = {}
local Bot = _G.IslandsBot
local State = Bot.State
local LocalPlayer = Players.LocalPlayer

-- Controle persistente de Voo e Colisão
local hoverBv = nil
local noclipConn = nil

local function AtivarModoFantasma(char, hrp)
    if not hoverBv then
        hoverBv = Instance.new("BodyVelocity")
        hoverBv.Name = "BotHoverVel"
        hoverBv.MaxForce = Vector3.new(math.huge, math.huge, math.huge)
        hoverBv.Velocity = Vector3.new(0, 0, 0)
        hoverBv.Parent = hrp
    end
    if not noclipConn then
        noclipConn = RunService.Stepped:Connect(function()
            if char then
                for _, part in ipairs(char:GetDescendants()) do
                    if part:IsA("BasePart") and part.CanCollide then
                        part.CanCollide = false
                    end
                end
            end
        end)
    end
end

local function DesativarModoFantasma()
    if hoverBv then hoverBv:Destroy(); hoverBv = nil end
    if noclipConn then noclipConn:Disconnect(); noclipConn = nil end
end

local function EquiparFerramenta()
    local char = LocalPlayer.Character
    if not char then return end
    
    -- Se já tiver uma ferramenta equipada, mantém ela
    if char:FindFirstChildWhichIsA("Tool") then return end

    -- Tenta achar uma picareta, machado ou ferramenta genérica no inventário
    local bp = LocalPlayer:FindFirstChild("Backpack")
    if bp then
        for _, tool in ipairs(bp:GetChildren()) do
            if tool:IsA("Tool") and (tool.Name:lower():find("pickaxe") or tool.Name:lower():find("axe") or tool.Name:lower():find("hammer")) then
                char.Humanoid:EquipTool(tool)
                task.wait(0.2)
                return
            end
        end
        -- Se não achar especifica, pega a primeira
        local qualquertool = bp:FindFirstChildWhichIsA("Tool")
        if qualquertool then
            char.Humanoid:EquipTool(qualquertool)
            task.wait(0.2)
        end
    end
end

function Miner:ExecutarLoop()
    local Manager = Bot.Modules.Manager
    local Scanner = State.ScannerGeral
    local rangeSeletor = 14 -- Raio de 7 para cada lado (Alcance do player)

    while State.Minerando do
        if Scanner then Scanner:EscanearArea() end
        
        if not Scanner or #Scanner.ListaBlocos == 0 then
            if Manager then Manager:AtualizarStatus("Aguardando blocos...") end
            task.wait(1)
            continue
        end

        local char = LocalPlayer.Character
        local hrp = char and char:FindFirstChild("HumanoidRootPart")
        if not char or not hrp then task.wait(1) continue end

        EquiparFerramenta()

        if State.MiningSettings.TweenToTarget then AtivarModoFantasma(char, hrp) end

        -- ALGORITMO DE CLUSTER (Smart Grid)
        local zonas = {}
        for _, dados in ipairs(Scanner.ListaBlocos) do
            local pos = dados.Posicao
            -- Agrupa num grid de 14x14
            local cx = math.floor(pos.X / rangeSeletor) * rangeSeletor + (rangeSeletor / 2)
            local cz = math.floor(pos.Z / rangeSeletor) * rangeSeletor + (rangeSeletor / 2)
            local key = string.format("%.1f_%.1f", cx, cz)
            
            if not zonas[key] then
                -- O Y da zona será um pouco acima do bloco mais alto para o boneco pairar
                zonas[key] = { centro = Vector3.new(cx, pos.Y + 6, cz), alvos = {} }
            end
            table.insert(zonas[key].alvos, dados)
        end

        local listaZonas = {}
        for _, z in pairs(zonas) do table.insert(listaZonas, z) end

        -- O boneco vai de zona em zona
        while #listaZonas > 0 and State.Minerando do
            -- Pega a zona mais próxima do boneco
            table.sort(listaZonas, function(a, b)
                return (hrp.Position - a.centro).Magnitude < (hrp.Position - b.centro).Magnitude
            end)
            
            local zonaAtual = table.remove(listaZonas, 1)

            -- Voa para o centro da Zona
            if State.MiningSettings.TweenToTarget then
                local dist = (hrp.Position - zonaAtual.centro).Magnitude
                if dist > 3 then
                    local speed = State.MiningSettings.TweenSpeed or 30
                    local tempo = dist / speed
                    local tween = TweenService:Create(hrp, TweenInfo.new(tempo, Enum.EasingStyle.Linear), {CFrame = CFrame.new(zonaAtual.centro)})
                    if Manager then Manager:AtualizarStatus(string.format("✈️ Viajando para Zona (%d alvos)", #zonaAtual.alvos)) end
                    tween:Play()
                    tween.Completed:Wait()
                else
                    hrp.CFrame = CFrame.new(zonaAtual.centro)
                end
            end

            -- Fica parado no centro e destroi tudo ao redor
            for i, dados in ipairs(zonaAtual.alvos) do
                if not State.Minerando then break end

                local bloco = dados.Instancia
                if not bloco or not bloco:IsDescendantOf(workspace) then continue end

                local healthObj = bloco:FindFirstChild("Health")
                local tentativas = 0
                local basePos = bloco:IsA("Model") and bloco:GetPivot().Position or bloco.Position
                
                -- Segurança caso ele desligue o voo e esteja longe
                if not State.MiningSettings.TweenToTarget and (hrp.Position - basePos).Magnitude > 20 then continue end
                
                while bloco and bloco:IsDescendantOf(workspace) do
                    if not State.Minerando then break end
                    
                    local hpAtual = healthObj and healthObj.Value or 0
                    if healthObj and hpAtual <= 0 then 
                        if dados.Marcador then dados.Marcador:Destroy() end
                        break 
                    end
                    
                    tentativas = tentativas + 1
                    if Manager then
                        Manager:AtualizarStatus(string.format("Minerando [%d/%d] | HP: %s", i, #zonaAtual.alvos, tostring(hpAtual)))
                    end

                    -- Se tentar mais de 25 vezes (uns 5 segundos preso), ele pula pro próximo
                    if tentativas > 25 then break end

                    local hitPosition = basePos + Vector3.new(math.random(-10,10)/100, 0, math.random(-10,10)/100)
                    local payload = {
                        Xoeoxuqilfgenamojfjmj = "\a\240\159\164\163\240\159\164\161\a\n\a\n\a\nohIstskUiftvgjy",
                        part = bloco, block = bloco, norm = hitPosition, pos = Vector3.new(0, 1, 0)
                    }

                    pcall(function() Manager.HitRemote:InvokeServer(payload) end)
                    
                    -- DELAY CORRIGIDO PARA EVITAR PHANTOM HITS (Respeita o cooldown do jogo)
                    task.wait(0.002) 
                end
                
                if dados.Marcador and dados.Marcador.Parent then dados.Marcador:Destroy() end
            end
        end
        task.wait(0.0002)
    end
    
    DesativarModoFantasma()
end

function Miner:Alternar(valor)
    local Manager = Bot.Modules.Manager
    State.Minerando = valor
    
    if valor then
        if State.MiningSettings.AutoUseSelectedSave and State.MiningSettings.CurrentSaveName then
            local PlotManager = Bot.Modules.PlotManager
            local plots = PlotManager:ObterTodos()
            local plot = plots["Mining_" .. State.MiningSettings.CurrentSaveName]
            if plot and State.ScannerGeral then
                State.ScannerGeral:CarregarPlot(Vector3.new(plot.PosX, plot.PosY, plot.PosZ), Vector3.new(plot.SizeX, plot.SizeY, plot.SizeZ))
            end
        end

        if not State.ScannerGeral or not State.ScannerGeral.AncoraPart then 
            if Manager then Manager:AtualizarStatus("ERRO: Crie o seletor azul primeiro!") end
            State.Minerando = false
            return false
        end
        
        State.Construindo = false
        task.spawn(function() Miner:ExecutarLoop() end)
    else
        DesativarModoFantasma()
        if Manager then Manager:AtualizarStatus("Ocioso") end
    end
    return true
end

return Miner
