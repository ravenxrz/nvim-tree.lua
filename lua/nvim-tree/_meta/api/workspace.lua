---@meta
local nvim_tree = { api = { workspace = {} } }

---
---VSCode style multi-root workspaces. A workspace is a named set of folder
---paths displayed as sibling top-level nodes in a single tree. While a
---workspace is active the tree root cannot be changed.
---

---
---Present a picker of saved workspaces and activate the chosen one.
---
function nvim_tree.api.workspace.select() end

---
---Prompt for a folder path and add it to the active workspace, entering
---workspace mode when not already active. The prompt is prefilled with the
---directory of the node under the cursor when {path} is nil, otherwise the
---current working directory.
---
---The workspace is saved automatically: the first save prompts once for a
---name, subsequent changes persist without prompting.
---
---@param path? string absolute or relative folder path used to prefill the prompt
function nvim_tree.api.workspace.add_folder(path) end

---
---Remove a workspace folder root, prompting for confirmation to avoid
---accidental removal. Uses the node under the cursor when {path} is nil.
---Changes are persisted automatically.
---
---@param path? string absolute or relative folder path
function nvim_tree.api.workspace.remove_folder(path) end

---
---Save the active folder set as a named workspace, persisting it to disk.
---Saving is normally automatic; this is rarely needed. Prompts for a name
---when {name} is nil and the workspace is unnamed.
---
---@param name? string
function nvim_tree.api.workspace.save_as(name) end

---
---Exit workspace mode, returning to a single-root tree at the current working
---directory.
---
function nvim_tree.api.workspace.exit() end

---
---Retrieve all saved workspaces.
---
---@return nvim_tree.Workspace[]
function nvim_tree.api.workspace.list() end

---
---Open the workspaces persistence file for editing. The file is created first
---when it does not yet exist. Does nothing when {persist} is disabled.
---
function nvim_tree.api.workspace.edit_config() end

return nvim_tree.api.workspace
