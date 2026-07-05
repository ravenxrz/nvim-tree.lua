local core = require("nvim-tree.core")
local config = require("nvim-tree.config")
local find_file = require("nvim-tree.actions.tree.find-file")

local M = {}

---Whether an explicit root change should be blocked by active workspace mode.
---Notifies the user when blocked.
---@return boolean
function M.blocked_by_workspace()
  local explorer = core.get_explorer()
  if explorer and explorer:workspace_restricts_root_change() then
    require("nvim-tree.notify").info("Cannot change root while a workspace is active. Exit the workspace first.")
    return true
  end
  return false
end

---@param name? string
function M.fn(name)
  local explorer = core.get_explorer()
  if name and explorer then
    explorer:change_dir(name)
  end

  if config.g.update_focused_file.update_root.enable then
    find_file.fn()
  end
end

return M
