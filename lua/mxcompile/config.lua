local M = {}

M.defaults = {
    commands = {
        go = "go run %",
        python = "python %",
        rust = "cargo run",
        cpp = "g++ % -o %:r && ./%:r",
        c = "gcc % -o %:r && ./%:r",
        make = "make",
        sh = "bash %",
        lua = "lua %",
        javascript = "node %",
        typescript = "ts-node %",
    },
    window = {
        type = "split", -- "split", "vsplit", or "float"
        size = 15,  -- height for split
        vsize = 50, -- width for vsplit
        float = {
            width = 0.8,
            height = 0.8,
            border = "rounded",
        },
    },
    close_keymap = "q",
    promote_keymap = "<C-p>", -- Promotes window to permanent
}

M.options = {}

function M.setup(opts)
    M.options = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

return M
