# Tail UI Library (Release 2)

Framework de UI para executores Roblox modernos, com foco em visual dark minimal, performance e API avançada.

## Status

- Arquitetura modular via `src/`
- Loader por path remoto (`dist/TailUI.pathloader.lua`)
- Design dark executor-first
- API rica (tabs, sections, widgets, tags, keybind sets, storage, temas dinâmicos)

## Arquivo Principal (Executor)

Use **somente**:

- `dist/TailUI.pathloader.lua`

O projeto **não depende** mais de bundle monolítico.

## Instalação / Uso com Loadstring

```lua
getgenv().TAILUI_REMOTE = {
    user = "Brennoleon",
    repo = "TailUI",
    branch = "main",
    basePath = "src",
    forceReload = false,
    debug = false
}

local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Brennoleon/TailUI/main/dist/TailUI.pathloader.lua"))()
```

Para repositório privado, adicione `authToken` na config (o loader usa fallback via `request/http_request/syn.request`):

```lua
getgenv().TAILUI_REMOTE = {
    user = "Brennoleon",
    repo = "TailUI",
    branch = "main",
    basePath = "src",
    authToken = "ghp_xxxxx",
}
```

## Quickstart

```lua
local ui = TailUI.getSingleton({
    hubName = "MeuHub",
})

local window = ui:tailwindow({
    title = "Tail UI",
    subtitle = "Release 2",
    searchEnabled = true,
    forceDarkOnFullscreen = true,
    transparency = 0.08,
    loading = {
        enabled = true,
        title = "Tail UI v2",
        subtitle = "Executor runtime",
        icon = "*",
    }
})

local tab = window:addTab({ title = "Main", icon = "settings" })
local sec = tab:addSection({ title = "General", description = "Core controls" })

sec:addToggle({
    title = "Auto Farm",
    default = false,
    callback = function(v) print("Auto Farm:", v) end
})

sec:addSlider({
    title = "Walk Speed",
    min = 16, max = 120, step = 1, default = 25,
    callback = function(v) print("Speed:", v) end
})
```

Script completo de validação da biblioteca no executor:

- `examples/full_test_executor.lua`

## Design / UX (Release 2)

- Visual dark minimal inspirado em hubs modernos
- Busca na sidebar
- Resultado de busca em overlay acima da UI
- Cantos arredondados e layout compacto
- `TopMenuOpenButton` arrastável
- Fullscreen com lock de tema escuro

## Keybind Sets (Novo)

### API global

```lua
ui:createKeybindSet("combat")
ui:activateKeybindSet("combat")

ui:bindKeybind("combat", {
    id = "dash",
    title = "Dash",
    key = Enum.KeyCode.Q,
    callback = function()
        print("Dash")
    end
})
```

### API de seção

```lua
sec:addKeybind({
    title = "Panic Key",
    set = "global",
    key = Enum.KeyCode.End,
    callback = function()
        print("Panic action")
    end
})
```

## API Nova de Janela

```lua
window:setTransparency(0.12)          -- ou setOpacity
window:setSidebarWidth(200, 150)      -- desktop, mobile
window:setSearchPlaceholder("Search controls...")
window:setFullscreenDarkTheme("midnight-pro")
window:runLoadingSequence({ "A", "B", "C" })
```

## Temas (Dark Pack)

Temas built-in:

- `midnight-pro` (padrão)
- `carbon-night`
- `neon-obsidian`

Aplicação:

```lua
ui:applyTheme("carbon-night")
```

Custom:

```lua
ui:registerTheme("my-theme", {
    meta = { name = "My Theme", dark = true },
    colors = {
        background = Color3.fromRGB(10, 13, 18),
        surface = Color3.fromRGB(16, 19, 25),
        topbar = Color3.fromRGB(8, 10, 14),
        sidebar = Color3.fromRGB(9, 12, 16),
        text = Color3.fromRGB(232, 241, 252),
        textMuted = Color3.fromRGB(132, 147, 171),
        border = Color3.fromRGB(36, 48, 66),
        accent = Color3.fromRGB(42, 161, 255),
        success = Color3.fromRGB(54, 170, 122),
        warning = Color3.fromRGB(242, 179, 64),
        danger = Color3.fromRGB(220, 90, 92),
        searchHighlight = Color3.fromRGB(80, 145, 255),
        overlay = Color3.fromRGB(6, 8, 12),
    },
    rounding = { window = 18, card = 14, pill = 999 },
}, { persist = true })
```

## Storage API

```lua
local root = ui:getHubRoot()
ui:makeFolder(root .. "/profiles")
ui:writeJSON(root .. "/profiles/default.json", { theme = ui:getConfig("theme.active") })
local profile = ui:readJSON(root .. "/profiles/default.json", {})
```

## Runtime / Executor Info

```lua
local runtime = ui:getRuntimeInfo()
print(runtime.executor)
print(runtime.capabilities.getgc, runtime.capabilities.gethui)
```

## Estrutura

```text
dist/
  TailUI.pathloader.lua
src/
  TailUI.lua
  Executor/
    Runtime.lua
  Input/
    KeybindManager.lua
  Core/
  Theme/
  Assets/
  UI/
examples/
  full_test_executor.lua
  quickstart.lua
  static_api.lua
```

## Observações de Produção

- Recomendado para executores modernos com suporte robusto a UI/IO.
- `pathloader` possui fallback HTTP via `request/http_request/syn.request`.
- Para atualização de release, mantenha `dist/TailUI.pathloader.lua` + `src/` sincronizados no repo.
