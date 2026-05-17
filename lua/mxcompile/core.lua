local config = require("mxcompile.config")
local history = require("mxcompile.history")

local M = {}

local active_job = nil
local output_buf = nil
local output_win = nil

local function expand_macros(cmd)
  if not cmd or cmd == "" then return "" end
  -- Expand %, %:r, %:p, etc.
  -- We use a greedy match for % followed by optional modifiers.
  return (cmd:gsub("%%[:%a]*", function(m)
    local expanded = vim.fn.expand(m)
    return (expanded and expanded ~= "") and expanded or m
  end))
end

local function get_default_cmd()
  local ft = vim.bo.filetype
  local cmd = config.options.commands[ft] or ""
  return expand_macros(cmd)
end

function M.interrupt()
  if active_job then
    active_job:kill(15) -- SIGTERM
    M.append_to_buffer("\n--- INTERRUPTED ---\n")
    active_job = nil
  end
end

function M.append_to_buffer(data)
  if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then
    return
  end
  
  local lines = vim.split(data, "\n", { plain = true })
  local last_line_idx = vim.api.nvim_buf_line_count(output_buf)
  local last_line_content = vim.api.nvim_buf_get_lines(output_buf, last_line_idx - 1, last_line_idx, false)[1] or ""

  -- Append first chunk to the last existing line
  vim.api.nvim_buf_set_lines(output_buf, last_line_idx - 1, last_line_idx, false, { last_line_content .. lines[1] })
  
  -- Add subsequent lines
  if #lines > 1 then
    local remaining = {}
    for i = 2, #lines do
      table.insert(remaining, lines[i])
    end
    vim.api.nvim_buf_set_lines(output_buf, last_line_idx, last_line_idx, false, remaining)
  end
  
  -- Scroll to end
  if output_win and vim.api.nvim_win_is_valid(output_win) then
    local last_count = vim.api.nvim_buf_line_count(output_buf)
    vim.api.nvim_win_set_cursor(output_win, {last_count, 0})
  end
end

local function setup_window(opts)
  opts = opts or {}
  local win_config = vim.tbl_deep_extend("force", config.options.window, opts.window or {})

  if output_buf and vim.api.nvim_buf_is_valid(output_buf) then
    -- Reuse buffer but clear it
    vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})
  else
    output_buf = vim.api.nvim_create_buf(false, true) -- listed=false, scratch=true
    vim.api.nvim_buf_set_name(output_buf, "*compile*")
    vim.api.nvim_set_option_value("buftype", "nofile", { buf = output_buf })
    vim.api.nvim_set_option_value("bufhidden", "wipe", { buf = output_buf })
    vim.api.nvim_set_option_value("swapfile", false, { buf = output_buf })
    vim.api.nvim_set_option_value("buflisted", false, { buf = output_buf })
    vim.api.nvim_set_option_value("filetype", "mxcompile", { buf = output_buf })
  end

  -- Set window-local options for a clean terminal-like look
  local function apply_win_options(win)
    vim.api.nvim_set_option_value("number", false, { win = win })
    vim.api.nvim_set_option_value("relativenumber", false, { win = win })
    vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
    vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
    vim.api.nvim_set_option_value("list", false, { win = win })
    vim.api.nvim_set_option_value("fillchars", "eob: ", { win = win })
  end

  -- Set temporary keymaps
  local km_opts = { buffer = output_buf, noremap = true, silent = true }
  vim.keymap.set("n", config.options.close_keymap, function()
    if output_win and vim.api.nvim_win_is_valid(output_win) then
      vim.api.nvim_win_close(output_win, true)
    end
  end, km_opts)

  vim.keymap.set("n", config.options.promote_keymap, function()
    M.promote_window()
  end, km_opts)

  -- Window creation
  local win_type = win_config.type
  if win_type == "float" then
    local width = math.floor(vim.o.columns * win_config.float.width)
    local height = math.floor(vim.o.lines * win_config.float.height)
    output_win = vim.api.nvim_open_win(output_buf, true, {
      relative = "editor",
      width = width,
      height = height,
      row = math.floor((vim.o.lines - height) / 2),
      col = math.floor((vim.o.columns - width) / 2),
      border = win_config.float.border,
    })
  else
    local split_cmd = win_type == "vsplit" and "vsplit" or "split"
    local size = win_type == "vsplit" and (win_config.vsize or 50) or win_config.size
    vim.cmd(size .. split_cmd)
    output_win = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_buf(output_win, output_buf)
  end

  apply_win_options(output_win)
  return output_buf, output_win
end

function M.promote_window()
  if not output_buf or not vim.api.nvim_buf_is_valid(output_buf) then return end
  
  -- Remove temporary keymaps
  pcall(vim.keymap.del, "n", config.options.close_keymap, { buffer = output_buf })
  pcall(vim.keymap.del, "n", config.options.promote_keymap, { buffer = output_buf })
  
  -- Change bufhidden so it's not wiped and make it listed
  vim.api.nvim_set_option_value("bufhidden", "hide", { buf = output_buf })
  vim.api.nvim_set_option_value("buflisted", true, { buf = output_buf })

  -- If it's a floating window, close it and open as vsplit
  if output_win and vim.api.nvim_win_is_valid(output_win) then
    local win_cfg = vim.api.nvim_win_get_config(output_win)
    if win_cfg.relative ~= "" then
      vim.api.nvim_win_close(output_win, true)
      
      -- Open as vsplit using config vsize
      local vsize = config.options.window.vsize or 50
      vim.cmd(vsize .. "vsplit")
      output_win = vim.api.nvim_get_current_win()
      vim.api.nvim_win_set_buf(output_win, output_buf)
      
      -- Re-apply clean UI options to the new split window
      local function apply_win_options(win)
        vim.api.nvim_set_option_value("number", false, { win = win })
        vim.api.nvim_set_option_value("relativenumber", false, { win = win })
        vim.api.nvim_set_option_value("signcolumn", "no", { win = win })
        vim.api.nvim_set_option_value("foldcolumn", "0", { win = win })
        vim.api.nvim_set_option_value("list", false, { win = win })
        vim.api.nvim_set_option_value("fillchars", "eob: ", { win = win })
      end
      apply_win_options(output_win)
    end
  end
  
  vim.notify("Compilation window promoted to permanent.", vim.log.levels.INFO)
end

function M.compile(cmd, opts)
  if not cmd or cmd == "" then
    local default = get_default_cmd()
    vim.ui.input({
      prompt = "Compile command: ",
      default = default,
      completion = "shellcmd",
    }, function(input)
      if input and input ~= "" then
        M.run(input, opts)
      end
    end)
  else
    M.run(cmd, opts)
  end
end

function M.run(cmd, opts)
  M.interrupt() -- Kill any existing job
  history.add(cmd)
  
  local expanded_cmd = expand_macros(cmd)
  
  setup_window(opts)
  M.append_to_buffer("Command: " .. expanded_cmd .. "\n\n")

  active_job = vim.system({"sh", "-c", expanded_cmd}, {
    stdout = function(err, data)
      if data then
        vim.schedule(function() M.append_to_buffer(data) end)
      end
    end,
    stderr = function(err, data)
      if data then
        vim.schedule(function() M.append_to_buffer(data) end)
      end
    end,
  }, function(obj)
    vim.schedule(function()
      M.append_to_buffer("\nProcess finished with exit code " .. obj.code .. "\n")
      active_job = nil
    end)
  end)
end

function M.repeat_last(opts)
  local last = history.get_last()
  if last then
    M.run(last, opts)
  else
    M.compile(nil, opts)
  end
end

function M.show_history()
  local items = history.get_all()
  if #items == 0 then
    vim.notify("No compile history.", vim.log.levels.WARN)
    return
  end

  -- Use Snacks picker if available
  local has_snacks, snacks = pcall(require, "snacks")
  if has_snacks and snacks.picker then
    snacks.picker.pick({
      title = "Compile History",
      items = vim.tbl_map(function(item)
        return { text = item, value = item }
      end, items),
      format = "text",
      layout = {
        preset = "select",
      },
      confirm = function(picker, item)
        picker:close()
        M.run(item.value)
      end,
      win = {
        input = {
          keys = {
            ["<Tab>"] = "list_down",
            ["<S-Tab>"] = "list_up",
          }
        }
      }
    })
  else
    -- Fallback to vim.ui.select
    vim.ui.select(items, {
      prompt = "Compile History:",
    }, function(choice)
      if choice then
        M.run(choice)
      end
    end)
  end
end

return M
