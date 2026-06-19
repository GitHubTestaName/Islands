-- src/ui/tabs/SistemaTab.lua
local SistemaTab = {}

function SistemaTab:Construir(paginaPai)
    local Bot = _G.IslandsBot
    local State = Bot.State
    local Componentes = Bot.Modules.UIComponents

    Componentes:ResetOrder()

    local cSys, zSys = Componentes:CriarCard("CONFIGURAÇÕES DO BOT", paginaPai)

    local btnKeybind = Componentes:CriarBotaoEstilizado("⌨️ Tecla Ocultar UI: V", cSys, zSys, function() end)
    btnKeybind.MouseButton1Click:Connect(function()
        State.IsListeningForKey = true
        btnKeybind.Text = "⌨️ Pressione uma tecla..."
        btnKeybind.BackgroundColor3 = Color3.fromRGB(0, 150, 255)
    end)
    
    State.UpdateKeybindButton = function()
        btnKeybind.Text = "⌨️ Tecla Ocultar UI: " .. State.HideKey.Name
        btnKeybind.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
    end

    Componentes:CriarBotaoEstilizado("❌ Fechar Bot de Forma Segura", cSys, zSys, function()
        if Bot.Modules.Miner then Bot.Modules.Miner:Alternar(false) end
        if Bot.Modules.Farmer then Bot.Modules.Farmer:AlternarAutoFazenda(false) end
        if Bot.Modules.WildMiner then Bot.Modules.WildMiner:LimparTudo() end -- LIMPA O WILD!
        if State.ScannerGeral then State.ScannerGeral:LimparAncora() end
        if State.ScannerFazenda then State.ScannerFazenda:LimparAncora() end
        
        -- Destrói a pasta de ESPs global
        local TargetUI = pcall(function() return game:GetService("CoreGui").Name end) and game:GetService("CoreGui") or game:GetService("Players").LocalPlayer:WaitForChild("PlayerGui")
        if TargetUI:FindFirstChild("WildernessEsp") then TargetUI.WildernessEsp:Destroy() end

        if TargetUI:FindFirstChild("IslandsCustomUI") then
            TargetUI.IslandsCustomUI:Destroy()
        end
    end)
end

return SistemaTab