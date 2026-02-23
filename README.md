# mark-and-recall.nvim

> *"No recall or intervention can work in this place."* -- Dagoth Ur

Fortunately, Recall works perfectly fine in Neovim, thanks to this plugin. Inspired by the Mark and Recall spells from Morrowind, it lets you define marks in a `marks.md` file and teleport to them instantly.

Unlike native vim marks which are ephemeral and stored in binary format, these marks are:

- **Persistent**: Saved in a plain text `marks.md` file that survives editor restarts
- **Human-readable**: Easy to view, edit, and share with your team
- **Maintainable**: Symbol marks (`@function`) can be updated via LSP when code shifts (e.g., after pulling from upstream)
- **LLM-friendly**: Feed `marks.md` to an AI to point it to key locations in your codebase, or have the LLM explore your code and generate marks for important entry points, APIs, or architectural boundaries

This is the Neovim port of the VS Code extension, available on the
[VS Code Marketplace](https://marketplace.visualstudio.com/items?itemName=kuhar.mark-and-recall)
and [Open VSX](https://open-vsx.org/extension/kuhar/mark-and-recall).
Both share the same `marks.md` format — you can use the same marks file across editors.

## Features

- **Numbered marks (1-9)** with quick-access keybindings
- **Visual indicators**: numbered gutter signs (1-9, then `*`) and line highlighting
- **Automatic line tracking**: marks update when you insert/delete lines
- **Symbol marks**: auto-named from function/class definitions with `@` prefix via LSP
- **Anonymous and named marks**: name is optional
- **Telescope integration**: fuzzy-find marks with preview
- **Prepend/append modes**: control where new marks appear in the file
- **Bulk operations**: delete all marks in a file at once
- **Runtime marks file switching**: change which `marks.md` file is active without restarting

## Installation

### [lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "kuhar/mark-and-recall.nvim",
  opts = {},
  keys = {
    { "<leader>ma", "<cmd>MarkAdd<cr>", desc = "Add mark" },
    { "<leader>md", "<cmd>MarkDelete<cr>", desc = "Delete mark" },
    { "<leader>mm", "<cmd>MarkRecall<cr>", desc = "Browse marks" },
    { "<leader>mn", "<cmd>MarkNext<cr>", desc = "Next mark (file)" },
    { "<leader>mp", "<cmd>MarkPrev<cr>", desc = "Prev mark (file)" },
    { "<leader>mN", "<cmd>MarkNextGlobal<cr>", desc = "Next mark (global)" },
    { "<leader>mP", "<cmd>MarkPrevGlobal<cr>", desc = "Prev mark (global)" },
    { "<leader>mo", "<cmd>MarkOpen<cr>", desc = "Open marks file" },
    { "<leader>mf", "<cmd>MarkSelectFile<cr>", desc = "Select marks file" },
    { "<leader>mA", "<cmd>MarkAddNamed<cr>", desc = "Add named mark" },
    { "<leader>mD", "<cmd>MarkDeleteAll<cr>", desc = "Delete all marks in file" },
    { "<leader>mu", "<cmd>MarkUpdateSymbols<cr>", desc = "Update symbol marks" },
    { "<leader>mI", "<cmd>MarkAddPrepend<cr>", desc = "Add mark (prepend)" },
    { "<leader>mi", "<cmd>MarkAddNamed!<cr>", desc = "Add named mark (prepend)" },
    { "<leader>m1", "<cmd>MarkRecallByIndex 1<cr>", desc = "Mark 1" },
    { "<leader>m2", "<cmd>MarkRecallByIndex 2<cr>", desc = "Mark 2" },
    { "<leader>m3", "<cmd>MarkRecallByIndex 3<cr>", desc = "Mark 3" },
  },
}
```

### Requirements

- Neovim >= 0.10
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) (for `:MarkRecall` picker)
- An LSP server (optional, for symbol auto-naming and `@symbol` mark updates)

## Configuration

```lua
require("mark-and-recall").setup({
  marks_file = "marks.md",  -- filename or absolute path
})
```

The plugin searches upward from `cwd` for the marks file, falling back to `cwd` if not found. This means a `marks.md` in a project root is found automatically even when working in subdirectories.

## marks.md Format

Create a `marks.md` file in your workspace root:

```md
# Marks
# Examples: name: path:line | @symbol: path:line | path:line

tester: agents/llvm-tester.md:11
@parseConfig: src/utils.ts:42
src/helpers.ts:18
```

- `@` prefix indicates auto-detected symbol names (can be updated with `:MarkUpdateSymbols`)
- Paths can be relative (to workspace root) or absolute
- Line numbers are 1-based
- Lines starting with `#` are comments
- HTML-style comments (`<!-- ... -->`) are also supported, including multi-line
- C++ namespaces in symbol names are supported (e.g., `@std::chrono::now`)

## Commands

| Command | Description |
|---------|-------------|
| `:MarkAdd` | Add mark at cursor (auto-names with `@symbol` if LSP provides one) |
| `:MarkAddPrepend` | Same as `:MarkAdd` but inserts at top of list |
| `:MarkAddNamed` | Add named mark with interactive prompt (bang `!` = prepend) |
| `:MarkDelete` | Delete mark at current line |
| `:MarkDeleteAll` | Delete all marks pointing to current file |
| `:MarkRecall` | Telescope picker to browse and jump to marks |
| `:MarkRecallByIndex N` | Jump directly to mark N (1-based) |
| `:MarkNext` / `:MarkPrev` | Cycle through marks in current file |
| `:MarkNextGlobal` / `:MarkPrevGlobal` | Cycle through all marks by index |
| `:MarkUpdateSymbols` | Update `@symbol` mark line numbers via LSP |
| `:MarkOpen` | Open the marks file for manual editing |
| `:MarkSelectFile` | Switch to a different marks file at runtime |

## Highlight Groups

| Group | Default | Description |
|-------|---------|-------------|
| `MarkAndRecallSign` | Blue, bold | Gutter sign text (1-9, `*`) |
| `MarkAndRecallLineHighlight` | Dark blue background | Marked line highlight |

Override in your config:

```lua
vim.api.nvim_set_hl(0, "MarkAndRecallSign", { fg = "#e06c75", bold = true })
vim.api.nvim_set_hl(0, "MarkAndRecallLineHighlight", { bg = "#2c313a" })
```

## How It Works

- **Signs**: Uses extmarks with `sign_text` and `line_hl_group` for gutter icons and line highlights. Marks 1-9 show their number, marks 10+ show `*`.
- **Line tracking**: Attaches to buffers via `nvim_buf_attach` `on_lines` callback. Edits above a mark shift its line number. Changes are debounced (500ms) and flushed to the marks file.
- **Symbol updates**: `:MarkUpdateSymbols` queries `textDocument/documentSymbol` via LSP, finds the closest matching symbol by name, and rewrites the line number.
- **Caching**: Marks are cached with mtime-based invalidation. A `vim.uv` file watcher picks up external changes (e.g., edits from another editor or git operations).

## Running Tests

```bash
nvim --headless -l tests/run.lua
```

## License

Apache-2.0
