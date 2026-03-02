# Tail UI Library (Release 2.1)

UI library para executores Roblox, focada em design dark minimal, arquitetura modular e API completa para hubs.

## Destaques

- Loader modular por path remoto (`dist/TailUI.pathloader.lua`)
- Sem dependencia de `getgenv` (usa `_G.TAILUI_REMOTE` opcional)
- Bootstrap loading no loader (carrega junto enquanto os modulos baixam)
- UI mobile-first com layout adaptativo inteligente
- Busca fuzzy na sidebar com overlay acima da UI
- Keybind sets, temas dinamicos, storage API e isolamento de erro
- Estrutura pronta para producao (sem bundle monolitico)

## Arquivo principal para executor

- `dist/TailUI.pathloader.lua`

## Loadstring rapido

```lua
local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Brennoleon/TailUI/main/dist/TailUI.pathloader.lua"))()
```

## Config remota (opcional)

```lua
_G.TAILUI_REMOTE = {
    user = "Brennoleon",
    repo = "TailUI",
    branch = "main",
    basePath = "src",
    forceReload = false,
    debug = false,
    showBootLoader = true,
    -- authToken = "ghp_xxx", -- para repo privado
}
```

## Quickstart

```lua
local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/Brennoleon/TailUI/main/dist/TailUI.pathloader.lua"))()

local ui = TailUI.getSingleton({
    hubName = "MeuHub",
})

local window = ui:tailwindow({
    title = "Tail UI",
    subtitle = "Release 2.1",
    searchEnabled = true,
    forceDarkOnFullscreen = true,
    transparency = 0.08,
    loading = {
        enabled = true,
        hold = false,
        title = "Tail UI",
        subtitle = "Initializing...",
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

## Script completo de teste

- `examples/full_test_executor.lua`

Esse script cobre:
- tabs, sections e controles
- keybind sets
- temas built-in + tema runtime
- storage API
- runtime info
- loading hold (abre no inicio e fecha no final da montagem)

## APIs principais

### Core

```lua
local ui = TailUI.getSingleton({ hubName = "MeuHub" })
local window = ui:tailwindow({ title = "Tail UI" })
```

### Janela

```lua
window:setTransparency(0.12)
window:setSidebarWidth(190, 140)
window:setSearchPlaceholder("Search controls...")
window:setFullscreenDarkTheme("midnight-pro")
window:setSearchEnabled(true)
window:beginLoading("Loading...", "Mounting")
window:updateLoading(0.5, "Half way")
window:endLoading()
```

### Keybind sets

```lua
ui:createKeybindSet("combat")
ui:activateKeybindSet("combat")

ui:bindKeybind("combat", {
    id = "dash",
    key = Enum.KeyCode.Q,
    callback = function()
        print("Dash")
    end
})
```

### Themes

Temas built-in:
- `midnight-pro`
- `carbon-night`
- `neon-obsidian`

```lua
ui:applyTheme("carbon-night")
```

## Estrutura do projeto

```text
dist/
  TailUI.pathloader.lua
src/
  TailUI.lua
  Core/
  Theme/
  Assets/
  UI/
  Input/
  Executor/
examples/
  quickstart.lua
  static_api.lua
  full_test_executor.lua
```

## Producao

- Para release, mantenha `dist/TailUI.pathloader.lua` e `src/` sincronizados.
- Para repo privado, use `authToken` em `_G.TAILUI_REMOTE`.
- O loader usa fallback HTTP via `request/http_request/syn.request`.
