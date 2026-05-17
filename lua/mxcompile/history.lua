local M = {}

local history = {}
local max_history = 20

function M.add(cmd)
  if cmd == "" then return end
  -- Remove if already exists to move to top
  for i, c in ipairs(history) do
    if c == cmd then
      table.remove(history, i)
      break
    end
  end
  table.insert(history, 1, cmd)
  if #history > max_history then
    table.remove(history)
  end
end

function M.get_all()
  return history
end

function M.get_last()
  return history[1]
end

return M
