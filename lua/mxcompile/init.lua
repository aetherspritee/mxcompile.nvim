local M = {}

local core = require("mxcompile.core")
local config = require("mxcompile.config")

function M.setup(opts)
    config.setup(opts)

    -- Register commands
    vim.api.nvim_create_user_command("MxCompile", function(args)
        if args.args ~= "" then
            core.run(args.args)
        else
            core.compile()
        end
    end, { nargs = "?", complete = "shellcmd" })

    vim.api.nvim_create_user_command("MxRepeat", function()
        core.repeat_last()
    end, {})

    vim.api.nvim_create_user_command("MxHistory", function()
        core.show_history()
    end, {})

    vim.api.nvim_create_user_command("MxInterrupt", function()
        core.interrupt()
    end, {})

    vim.api.nvim_create_user_command("MxPromote", function()
        core.promote_window()
    end, {})
end

-- Export functions for easy keybinding
M.compile = core.compile
M.repeat_last = core.repeat_last
M.show_history = core.show_history
M.interrupt = core.interrupt
M.promote = core.promote_window

return M
