local notify = require("nvim-tree.notify")

---VSCode style multi-root workspace manager.
---A workspace is a named set of folder paths that are displayed as sibling
---top-level nodes in a single tree. Saved workspaces are persisted to a json
---file and may be selected via a picker.
---
---@class nvim_tree.Workspace
---@field name string? nil for an unsaved in-progress workspace
---@field folders string[] absolute folder paths

local M = {
  ---saved workspaces keyed by insertion order
  ---@type nvim_tree.Workspace[]
  saved = {},

  ---the currently active workspace, nil when not in workspace mode
  ---@type nvim_tree.Workspace?
  active = nil,

  ---name of the last activated workspace, persisted for restore_on_start
  ---@type string?
  last_active = nil,

  ---whether saved workspaces have been loaded from disk
  loaded = false,
}

---@return string
local function get_save_path()
  local persist = require("nvim-tree.config").g.workspace.persist
  if type(persist) == "string" then
    return persist
  end
  return vim.fn.stdpath("data") .. "/nvim-tree-workspaces.json"
end

---Load saved workspaces from disk once.
function M.load()
  if M.loaded then
    return
  end
  M.loaded = true

  local persist = require("nvim-tree.config").g.workspace.persist
  if not persist then
    return
  end

  local storepath = get_save_path()
  local file = io.open(storepath, "r")
  if not file then
    return
  end

  local content = file:read("*all")
  file:close()

  if not content or content == "" then
    return
  end

  local ok, data = pcall(vim.json.decode, content)
  if not ok or type(data) ~= "table" or type(data.workspaces) ~= "table" then
    notify.warn("Failed to parse workspaces file: " .. storepath)
    return
  end

  M.saved = {}
  for _, ws in ipairs(data.workspaces) do
    if type(ws) == "table" and type(ws.name) == "string" and type(ws.folders) == "table" then
      table.insert(M.saved, { name = ws.name, folders = vim.deepcopy(ws.folders) })
    end
  end

  if type(data.last_active) == "string" then
    M.last_active = data.last_active
  end
end

---Persist saved workspaces to disk.
function M.save()
  local config = require("nvim-tree.config")
  if not config.g.workspace.persist then
    return
  end

  local storepath = get_save_path()
  local file, errmsg = io.open(storepath, "w")
  if not file then
    notify.warn(string.format("Invalid workspace.persist, disabling persistence: %s", errmsg))
    config.g.workspace.persist = false
    return
  end

  local data = { workspaces = {}, last_active = M.last_active }
  for _, ws in ipairs(M.saved) do
    table.insert(data.workspaces, { name = ws.name, folders = ws.folders })
  end
  file:write(vim.json.encode(data))
  file:close()
end

---@return boolean
function M.is_active()
  return M.active ~= nil
end

---Folders of the active workspace, empty when inactive
---@return string[]
function M.folders()
  return M.active and M.active.folders or {}
end

---Find a saved workspace by name
---@param name string
---@return nvim_tree.Workspace?
---@return integer? index
local function find_saved(name)
  for i, ws in ipairs(M.saved) do
    if ws.name == name then
      return ws, i
    end
  end
  return nil, nil
end

---Sync the active workspace folders into its saved entry and persist.
---Does nothing for an unnamed active workspace.
local function persist_active()
  if not M.active or not M.active.name then
    return
  end

  local saved = find_saved(M.active.name)
  if saved then
    saved.folders = vim.deepcopy(M.active.folders)
  else
    table.insert(M.saved, { name = M.active.name, folders = vim.deepcopy(M.active.folders) })
  end

  M.save()
end

---Ensure the active workspace is persisted, prompting for a name on first save.
---Saving is automatic thereafter: named workspaces persist immediately.
local function ensure_saved()
  if not M.active then
    return
  end

  if M.active.name then
    -- already named: persist automatically
    persist_active()
  elseif #M.active.folders > 0 then
    -- first save: prompt for a name once, then persist
    local utils = require("nvim-tree.utils")
    vim.ui.input({ prompt = "Save workspace as: " }, function(input)
      utils.clear_prompt()
      if input and input ~= "" then
        M.active.name = input
        persist_active()
        notify.info(string.format("Workspace saved: %s", input))
      end
    end)
  end
end

---Normalise a path to an absolute directory, nil when not a readable directory.
---@param path string
---@return string?
local function normalise_dir(path)
  local abs = vim.fn.fnamemodify(path, ":p")
  abs = require("nvim-tree.utils").path_remove_trailing(abs)
  if vim.fn.isdirectory(abs) == 0 then
    return nil
  end
  return abs
end

---Re-initialise the explorer for the active workspace and draw.
local function reinit()
  local core = require("nvim-tree.core")
  local view = require("nvim-tree.view")

  -- init the explorer in workspace mode
  core.init(M.active and M.active.folders[1] or vim.fn.getcwd(), M.active)

  if view.is_visible() then
    local explorer = core.get_explorer()
    if explorer then
      explorer.renderer:draw()
    end
  end
end

---Activate a workspace, entering workspace mode.
---@param ws nvim_tree.Workspace
function M.activate(ws)
  M.active = { name = ws.name, folders = vim.deepcopy(ws.folders) }
  if ws.name then
    M.last_active = ws.name
    M.save()
  end
  reinit()
end

---Exit workspace mode, returning to a single-root tree at cwd.
function M.exit()
  if not M.active then
    return
  end
  M.active = nil
  M.last_active = nil
  M.save()

  local core = require("nvim-tree.core")
  local view = require("nvim-tree.view")
  core.init(vim.fn.getcwd())
  if view.is_visible() then
    local explorer = core.get_explorer()
    if explorer then
      explorer.renderer:draw()
    end
  end
end

---Add a folder to the active workspace, creating an unnamed workspace when none active.
---@param path string
function M.add_folder(path)
  local abs = normalise_dir(path)
  if not abs then
    notify.warn(string.format("Not a directory: %s", path))
    return
  end

  if not M.active then
    M.active = { name = nil, folders = {} }
  end

  if vim.tbl_contains(M.active.folders, abs) then
    notify.info(string.format("Folder already in workspace: %s", abs))
    return
  end

  table.insert(M.active.folders, abs)
  reinit()
  ensure_saved()
end

---Open an input prompt for the user to type a folder path, then add it to the
---active workspace.
---@param default_path string? prefills the prompt, defaults to cwd
function M.prompt_add_folder(default_path)
  local utils = require("nvim-tree.utils")
  local default = default_path or vim.fn.getcwd()
  default = utils.path_add_trailing(default)

  vim.ui.input({ prompt = "Add workspace folder: ", default = default, completion = "dir" }, function(input)
    utils.clear_prompt()
    if not input or input == "" then
      return
    end
    M.add_folder(input)
  end)
end

---Remove a folder from the active workspace, prompting for confirmation.
---@param path string
function M.remove_folder(path)
  if not M.active then
    return
  end

  local utils = require("nvim-tree.utils")
  local abs = normalise_dir(path) or utils.path_remove_trailing(vim.fn.fnamemodify(path, ":p"))

  if not vim.tbl_contains(M.active.folders, abs) then
    notify.info(string.format("Folder is not a workspace root: %s", abs))
    return
  end

  local function do_remove()
    for i, folder in ipairs(M.active.folders) do
      if folder == abs then
        table.remove(M.active.folders, i)
        break
      end
    end
    reinit()
    ensure_saved()
  end

  local config = require("nvim-tree.config")
  local lib = require("nvim-tree.lib")
  local prompt_select = string.format("Remove workspace folder %s?", vim.fn.fnamemodify(abs, ":t"))
  local prompt_input, items_short, items_long = utils.confirm_prompt(prompt_select, config.g.ui.confirm.default_yes)

  lib.prompt(prompt_input, prompt_select, items_short, items_long, "nvimtree_workspace_remove", function(item_short)
    utils.clear_prompt()
    if item_short == "y" or item_short == (config.g.ui.confirm.default_yes and "") then
      do_remove()
    end
  end)
end

---Save the active folder set as a named workspace and persist.
---When {name} is nil and the workspace is unnamed, prompts once for a name.
---Named workspaces are persisted automatically; explicit calls are rarely needed.
---@param name string?
function M.save_as(name)
  if not M.active or #M.active.folders == 0 then
    notify.warn("No workspace folders to save. Add a folder first.")
    return
  end

  if name then
    M.active.name = name
    persist_active()
    notify.info(string.format("Workspace saved: %s", name))
  else
    ensure_saved()
  end
end

---Present a picker of saved workspaces and activate the chosen one.
function M.select()
  M.load()

  if #M.saved == 0 then
    notify.info("No saved workspaces. Add folders and save a workspace first.")
    return
  end

  local names = {}
  for _, ws in ipairs(M.saved) do
    table.insert(names, ws.name)
  end

  vim.ui.select(names, {
    prompt = "Select workspace",
    kind = "nvim_tree_workspace",
    format_item = function(item)
      local ws = find_saved(item)
      local count = ws and #ws.folders or 0
      return string.format("%s (%d folder%s)", item, count, count == 1 and "" or "s")
    end,
  }, function(choice)
    if not choice then
      return
    end
    local ws = find_saved(choice)
    if ws then
      M.activate(ws)
    end
  end)
end

---Return a shallow list of saved workspaces.
---@return nvim_tree.Workspace[]
function M.list()
  M.load()
  return vim.deepcopy(M.saved)
end

---Absolute path of the workspaces persistence file.
---@return string
function M.config_path()
  return get_save_path()
end

---Open the workspaces persistence file for editing.
---Ensures the file exists first by writing the current state.
function M.edit_config()
  local config = require("nvim-tree.config")
  if not config.g.workspace.persist then
    notify.warn("Workspace persistence is disabled (workspace.persist = false).")
    return
  end

  M.load()

  local path = get_save_path()
  -- create the file if it does not exist yet, so :edit has something to open
  if vim.fn.filereadable(path) == 0 then
    M.save()
  end

  vim.cmd("edit " .. vim.fn.fnameescape(path))
end

---Whether Nvim was started without file arguments (bare `nvim` or `nvim .`).
---@return boolean
local function is_bare_startup()
  -- argv(0) is nil/"" for bare nvim; "." is treated as bare (open cwd)
  if vim.fn.argc() == 0 then
    return true
  end
  if vim.fn.argc() == 1 then
    local arg = vim.fn.argv(0)
    if arg == "." or arg == "" then
      return true
    end
  end
  return false
end

---Restore the last active workspace when configured and appropriate.
---Called after setup; only restores on a bare startup with a valid last_active.
function M.restore()
  local config = require("nvim-tree.config")
  if not config.g.workspace.enable or not config.g.workspace.restore_on_start then
    return
  end
  if not config.g.workspace.persist then
    return
  end
  if M.active then
    return
  end
  if not is_bare_startup() then
    return
  end

  M.load()

  if not M.last_active then
    return
  end

  local ws = find_saved(M.last_active)
  if ws then
    M.activate(ws)
  end
end

return M
