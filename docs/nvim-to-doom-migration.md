# Neovim to Doom Emacs migration

This document tracks the useful behavior in `nvim/init.lua` against the current
Doom configuration in `doom/`. The aim is to preserve workflows rather than
reproduce every Neovim plugin one-for-one.

Status meanings: **Done** is configured and usable, **Partial** has a usable
replacement but does not yet cover the complete Neovim workflow, and **Not
done** has no configured equivalent yet.

## Current integration map

| Neovim behavior/plugin | Doom/Emacs equivalent | Status | Notes |
|---|---|---|---|
| Relative line numbers | `display-line-numbers-type` | **Done** | Globally set to relative. |
| Two-space, spaces-only indentation | `tab-width`, `tab-stop-list`, `indent-tabs-mode` | **Done** | `TAB` in insert state advances to two-column tab stops. Major modes can still choose their own indentation offset. |
| Persistent undo | Doom `:emacs undo` | **Done** | Doom's persistent undo system is enabled. |
| Solarized colors | `doom-solarized-light` | **Done** | This intentionally differs from Neovim's current Catppuccin/dark setting. |
| Save/quit bindings | `SPC w`, `SPC q`, `SPC Q` | **Done** | `SPC q` dismisses the current window; `SPC Q` exits Emacs. |
| `jk` leaves insert/terminal input | Evil Escape plus Ghostel integration | **Done** | Configured with a 0.20 second chord delay. |
| Wrapped-line `j`/`k` | Evil visual-line motions | **Not done** | Plain `j`/`k` still use logical lines. |
| Copy the whole file with `C-c` | No custom equivalent | **Not done** | Normal visual selection/yank and the system clipboard work, but the one-key whole-buffer copy was not ported. |
| ToggleTerm numbered floating-terminal bank | Ghostel + Posframe | **Done** | `SPC /` toggles the workspace's last slot; a numeric prefix selects a numbered terminal. Each Doom workspace has its own bank. Slots have 20 MiB scrollback and are centered child frames. |
| Terminal normal/copy browsing | Evil Ghostel + Ghostel copy mode | **Done** | `jk` enters normal state and freezes scrollback; insert state resumes live input. Codex is configured with `tui.alternate_screen = "never"` so its transcript enters Ghostel scrollback too. |
| Terminal interrupt and paste | Ghostel insert-state overrides | **Done** | One `C-c` interrupts. `C-y`, `Ctrl-Shift-V`, and `Shift-Insert` paste; normal-state `p`/`P` also paste. |
| Telescope/FZF pickers | Vertico, Consult, Orderless, Embark, Projectile | **Done** | `SPC f f` is customized to the recursive project picker; Doom also supplies recent-file and search pickers. |
| Floating picker UI | Vertico child frame | **Done** | Enabled with `(vertico +childframe)`. |
| Which-key command preview | Which-Key Posframe | **Done** | Centered child frame; `SPC ?` shows the top-level map. |
| Git status picker | Magit | **Done** | Use `SPC g g`. |
| Barbar buffer tabs | Doom tabs and workspaces | **Done** | `SPC h`/`SPC l` changes the selected window to the previous/next visible buffer tab; normal-state `H`/`L` remains as an alias. Doom provides new-buffer commands; `SPC x` uses the custom close-to-directory behavior. |
| marks.nvim/Telescope marks | Evil marks + Consult | **Done** | Doom remaps the Evil marks list to `consult-mark`; use `SPC s r`. |
| smear-cursor | Pulsar | **Done** | Cursor jumps pulse globally. This is a highlight pulse, not a particle trail. |
| NvimTree | Dired; optional Treemacs | **Partial** | Dired is enabled (`SPC o -`) and `SPC x` closes a file into its directory. No persistent sidebar or `C-n`/`C-h` workflow is configured. |
| Oil | Dired | **Partial** | File operations are available, but the editable Oil-style workflow and tailored Evil bindings have not been configured. |
| Trouble diagnostics | Flycheck list | **Partial** | `:lsp` toggles `*Flycheck errors*`; this has only been exercised as part of the current Eglot setup. |
| Mason/LSP | Eglot + Doom language modules | **Partial** | OCaml and Verilog/SystemVerilog are enabled. SystemVerilog uses the local `slang-server` and recognizes `.slang` project roots. C/C++ and Python modules/LSP are not enabled. |
| nvim-cmp | Corfu + Orderless | **Done** | Completion UI and filtering are enabled. Language-aware candidates still depend on each language's Eglot setup. |
| Treesitter | Doom tree-sitter module or built-in tree-sitter modes | **Not done** | The Doom `tree-sitter` module is disabled and no explicit grammar setup has been ported. |
| render-markdown.nvim | Doom `markdown` module | **Partial** | Editing/fontification is enabled; no rendered or live-preview workflow is configured. |
| goto-preview | Doom lookup/navigation | **Partial** | Doom's lookup commands cover definition/reference navigation, but no floating definition preview was added. |
| Transparent background | Theme/frame customization | **Not done** | No transparency configuration is present. |
| Competitive-programming `cp_run()` | `compilation-mode` runner | **Not done** | No `SPC d` build/run command has been ported. |
| Config edit/reload shortcuts | Custom `SPC e` map | **Done** | See the binding table below. |
| Floating scratch buffer | Doom scratch + Posframe | **Done** | Additional Emacs workflow: `SPC [` toggles a persistent centered scratchpad. |
| Project/session persistence | Doom workspaces | **Partial** | Workspaces and workspace-local terminal banks are enabled, but no project-local build/session policy is configured. |

## Configuration bindings already ported

| Binding | Action |
|---|---|
| `SPC e c` | Open personal Doom `config.el` |
| `SPC e i` | Open personal Doom `init.el` |
| `SPC e p` | Open personal Doom `packages.el` |
| `SPC e b` | Open `~/.bash_configs` |
| `SPC e r` | Reload the Doom configuration |
| `SPC r c` | Reload the Doom configuration (alias) |
| `SPC x` | Kill the current buffer and open its directory in the same window |

Module and package changes still require `doom sync` followed by an Emacs
restart. Ordinary `config.el` changes can usually be applied with the reload
binding.

## Remaining work, in suggested order

### 1. Competitive-programming/build runner

Port `cp_run()` with `compilation-start`: save the current source, run
`build.sh FILE input.txt output.txt` in its directory, show the result in a
managed popup, make compiler locations clickable, and support `recompile`.

### 2. Dired/Oil file workflow

Add a fast current-directory command, Evil-friendly file operations, writable
Dired for bulk renames, and decide whether a persistent project sidebar is
actually useful.

### 3. Wrapped-line movement

Make uncounted `j`/`k` follow screen lines while preserving logical/count
movement for commands such as `5j` and `5k`.

### 4. Finish language support

Enable and verify C/C++ and Python language modules if still needed, decide
whether to enable tree-sitter, and exercise diagnostics/completion across all
three current language families (OCaml, SystemVerilog, and C/C++/Python).

### 5. Markdown and navigation presentation

Choose a Markdown preview style and decide whether a floating definition
preview is worth adding beyond Doom's normal lookup/navigation commands.

### 6. Session and project polish

Add project-local compilation commands, decide what workspaces should survive
restart, and scope build state consistently by project if desired.

## Useful Doom-native replacements

- Project file selection: `SPC p f` or the customized `SPC f f`
- File selection from the current directory: `SPC .`
- Recent files: `SPC f r`
- Project text search: `SPC s p`
- Marks: `SPC s r`
- Git interface/status: `SPC g g`
- Open Dired for the current location: `SPC o -`
- New empty buffer: `SPC b N`
