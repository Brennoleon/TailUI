# Tail UI Library

UI Library para scripts Roblox, com arquitetura inspirada no Safari, API modular e sistema completo de tema, storage e isolamento de erros.

## Arquivo Principal Para Executor

Arquivo principal para `loadstring`:

- `dist/TailUI.pathloader.lua` (recomendado, modular)
- `dist/TailUI.executor.lua` (opcional, bundle monolitico)

Para aproveitar a estrutura modular de `src/`, use o `pathloader`.

Exemplo de URL raw:

```text
https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/dist/TailUI.pathloader.lua
```

Uso no executor:

```lua
getgenv().TAILUI_REMOTE = {
    user = "SEU_USUARIO",
    repo = "SEU_REPO",
    branch = "main",
    basePath = "src"
}

local TailUI = loadstring(game:HttpGet("https://raw.githubusercontent.com/SEU_USUARIO/SEU_REPO/main/dist/TailUI.pathloader.lua"))()

local ui = TailUI.getSingleton({
    hubName = "MeuHubExecutor"
})

local window = ui:tailwindow({
    title = "Tail UI Executor",
    subtitle = "Safari Architecture",
    searchEnabled = true,
    loading = { enabled = true }
})
```

## Publicar No GitHub (para usar Raw)

Sim, para usar `game:HttpGet(...)` no executor voce precisa hospedar o arquivo em algum lugar acessivel por URL (GitHub Raw e o mais comum).

Fluxo recomendado:

1. Suba o projeto no GitHub com a pasta `src/` e `dist/TailUI.pathloader.lua`.
2. Use o `pathloader` no executor com `getgenv().TAILUI_REMOTE`.
3. (Opcional) gere bundle monolitico se quiser fallback:
   - `powershell -ExecutionPolicy Bypass -File tools/build_executor_bundle.ps1`
4. Suba tambem `dist/TailUI.executor.lua` se for usar esse modo.

Se usar monolitico, sempre que alterar arquivos em `src/`, gere novamente `dist/TailUI.executor.lua`.

## Visao Geral

Tail UI foi desenhada para hubs avancados:

- Janela estilo Safari com topbar, bolinhas de controle e `TopMenuOpenButton`.
- Layout inteligente para desktop e mobile (resize + breakpoint responsivo).
- Sistema de Tabs, Sections, Folders e componentes de formulario.
- Search in UI com fuzzy matching (aceita erro de digitacao).
- Sistema de tags na topbar (`icone + texto + pill`).
- Loading screens por API de configuracao.
- Theme Engine com criacao, aplicacao e persistencia em disco.
- Storage API com `makefolder`, `writefile`, `readfile`.
- Core Execution Isolation: erro em callback nao derruba a UI.

## Destaques Tecnicos

### 1) Arquitetura Safari

- Topbar com botoes close/minimize/maximize.
- Janela com cantos arredondados, stroke e hierarquia visual limpa.
- Botao `TopMenuOpenButton` quando a UI e minimizada.

### 2) Mobile + Responsivo

- Breakpoint configuravel via `internal.mobileBreakpoint`.
- Ajuste automatico de tamanho e distribuicao lateral.
- Resize manual (handle no canto) em desktop.

### 3) Search in UI (Fuzzy)

- Indexa tabs, sections, tags e controles.
- Busca por similaridade textual (nao depende de regex).
- Permite localizar funcoes mesmo com digitacao imperfeita.
- Pode ser ativada/desativada via API.

### 4) Theme System

- Registro em runtime: `registerTheme`.
- Aplicacao dinamica: `applyTheme`.
- Persistencia de tema em pasta (`theme.json`).
- Carregamento de temas locais na inicializacao.

### 5) Icones e Fontes

- Compatibilidade nativa com Lucide (fallback textual).
- Ate 5 bibliotecas externas de icones alem de Lucide.
- Ate 5 fontes externas alem do pack padrao.

### 6) Execution Isolation

- Callbacks protegidos por `pcall` centralizado.
- Erros sao logados com contexto.
- Componente que falha pode ser desativado sem matar a UI.
- Label de erro detalhada aparece dentro da propria UI.

## Estrutura do Projeto

```text
dist/
  TailUI.pathloader.lua
  TailUI.executor.lua
tools/
  build_executor_bundle.ps1
src/
  init.lua
  TailUI.lua
  Core/
    Logger.lua
    SafeCall.lua
    FileSystem.lua
    ConfigManager.lua
  Theme/
    BuiltinThemes.lua
    ThemeManager.lua
  Assets/
    IconRegistry.lua
    FontRegistry.lua
  UI/
    Window.lua
    FuzzySearch.lua
    LoadingOverlay.lua
examples/
  quickstart.lua
  static_api.lua
```

## Estrutura Runtime (disco)

Quando inicializa com `hubName = "MeuHub"`, a lib cria:

```text
workspace/meuhub/
  bin/
    configurations.config
  themes/
    initate.lua
    <nome-do-tema>/
      theme.json
  cache/
  logs/
```

### Arquivos importantes

- `workspace/<hub>/bin/configurations.config`
  - Config principal da UI (tema ativo, flags internas, etc).
- `workspace/<hub>/themes/initate.lua`
  - Bootstrap do sistema de temas locais.
- `workspace/<hub>/themes/<tema>/theme.json`
  - Tema custom que pode ser aplicado por API.

## API Rapida

## Bootstrap

```lua
local TailUI = require(path.to.src.TailUI)

local ui = TailUI.new({
  hubName = "MeuHub",
})

local window = ui:tailwindow({
  title = "Meu Hub",
  subtitle = "Tail UI - Safari",
  searchEnabled = true,
})
```

## Estilo `Window.tailwindow(...)`

```lua
local Window = require(path.to.src.TailUI)

local win = Window.tailwindow({
  hubName = "MeuHubStatic",
  title = "Static Window API",
  searchEnabled = true,
})
```

## Tabs / Sections / Components

```lua
local tab = window:addTab({ title = "Main", icon = "settings" })
local section = tab:addSection({ title = "Gameplay", description = "Core options" })

section:addToggle({
  title = "Auto Farm",
  default = false,
  callback = function(state) print(state) end,
})

section:addSlider({
  title = "Walk Speed",
  min = 16, max = 120, step = 1, default = 24,
  callback = function(value) print(value) end,
})

section:addDropdown({
  title = "Target Team",
  options = { "Alpha", "Bravo", "Charlie" },
  callback = function(opt) print(opt) end,
})
```

## Tags na Topbar

```lua
window:addTag({
  icon = "theme",
  text = "BETA",
  width = 90,
})
```

## Temas dinamicos

```lua
ui:registerTheme("my-custom", {
  meta = { name = "My Custom" },
  colors = {
    background = Color3.fromRGB(228, 234, 241),
    surface = Color3.fromRGB(245, 249, 255),
    topbar = Color3.fromRGB(220, 228, 238),
    text = Color3.fromRGB(29, 40, 53),
    textMuted = Color3.fromRGB(90, 107, 128),
    border = Color3.fromRGB(179, 194, 214),
    accent = Color3.fromRGB(52, 120, 245),
    success = Color3.fromRGB(54, 170, 122),
    warning = Color3.fromRGB(242, 179, 64),
    danger = Color3.fromRGB(220, 90, 92),
    searchHighlight = Color3.fromRGB(80, 145, 255),
  },
  rounding = { window = 14, card = 10, pill = 999 },
}, { persist = true })

ui:applyTheme("my-custom")
```

## Storage API (writefile/readfile/makefolder)

```lua
local root = ui:getHubRoot()

ui:makeFolder(root .. "/profiles")
ui:writeJSON(root .. "/profiles/default.json", {
  theme = ui:getConfig("theme.active"),
})

local data = ui:readJSON(root .. "/profiles/default.json", {})
```

## Icones e Fontes

```lua
ui:registerIconLibrary("my-icons", {
  sword = "⚔",
  gem = "◆",
})

ui:registerFont("my-font", Enum.Font.FredokaOne)
```

## Loading Screen por API

```lua
local window = ui:tailwindow({
  title = "Meu Hub",
  loading = { enabled = true },
})

window:runLoadingSequence({
  "Checking modules",
  "Syncing themes",
  "Boot complete",
})
```

## Principais Metodos

- `TailUI.new(options)`
- `TailUI.tailwindow(options)` (singleton)
- `TailUI.getSingleton(options)` (singleton explicito)
- `ui:tailwindow(options)` / `ui:createWindow(options)`
- `ui:registerTheme(name, data, opts)`
- `ui:applyTheme(name, overrides?)`
- `ui:registerIconLibrary(name, provider)`
- `ui:registerFont(name, fontEnum)`
- `ui:getConfig(path?)` / `ui:setConfig(path, value, shouldSave?)`
- `ui:makeFolder(path)` / `ui:writeFile(path, content)` / `ui:readFile(path, default?)`
- `ui:writeJSON(path, data)` / `ui:readJSON(path, default?)`
- `ui:getStorageAPI()`
- `window:addTag(...)`
- `window:addTab(...)`
- `window:setSearchEnabled(boolean)`
- `window:runLoadingSequence({...})`

## Observacoes

- A UI foi feita para modularidade e extensao.
- O sistema prioriza resiliencia: erros locais sao isolados.
- O projeto esta pronto para evoluir com novos componentes/telas.

---

Tail UI Library: Safari-like, modular, advanced and ready for production hubs.
