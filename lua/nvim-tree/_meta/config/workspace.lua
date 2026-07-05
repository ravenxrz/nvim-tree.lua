---@meta
error("Cannot require a meta file")


---VSCode style multi-root workspaces: show project folders from different
---locations as sibling top-level nodes in a single tree.
---
---Optionally {persist} saved workspaces to a json file:
---- `true` use default: `stdpath("data") .. "/nvim-tree-workspaces.json"`
---- `false` do not persist
---- `string` absolute path of your choice
---
---@class nvim_tree.config.workspace
---
---(default: `true`)
---@field enable? boolean
---
---(default: `true`)
---@field persist? boolean|string
---
---Prevent changing the tree root while a workspace is active.
---(default: `true`)
---@field restrict_root_change? boolean
---
---Automatically restore the last active workspace when Nvim is started without
---file arguments (bare `nvim` or `nvim .`). Requires {persist}.
---(default: `true`)
---@field restore_on_start? boolean
