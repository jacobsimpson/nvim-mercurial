
-- Gets the color values for a particular highlight group. The result is a
-- table that will contain the following keys:
--     ctermfg, ctermbg, guifg, guibg
--
-- Example:
--
-- local h = getHighlight("Fold")
-- h.ctermfg == "7"
-- h.ctermbg == "0"
-- h.guifg == "Grey80"
-- h.guibg == "Black"
--
local function getHighlight(group)
    local highlight = vim.trim(vim.fn.execute("highlight " .. group))
    local loc, _ = string.find(highlight, " ")
    highlight = vim.trim(string.sub(highlight, loc))
    loc, _ = string.find(highlight, " ")
    highlight = vim.trim(string.sub(highlight, loc))
    local result = {}
    for _, e in ipairs(vim.split(highlight, " ")) do
        local r = vim.split(e, "=")
        result[r[1]] = r[2]
    end
    return result
end

-- Sets the color values for a particular highlight group. The values parameter
-- is a table that can have the following keys:
--     ctermfg, ctermbg, guifg, guibg
--
-- Example:
--
-- setHighlight("Fold", {ctermfg="7", ctermbg="0", guifg="Grey80", guibg="Black"})
--
-- Warning, if the group does not exist, the error is not captured. I've not
-- been able to figure out if there is a way to do that.
local function setHighlight(group, values)
    local highlight = {"highlight ", group}
    if values ~= nil then
        if values.ctermfg ~= nil then
            table.insert(highlight, "ctermfg=" .. values.ctermfg)
        end
        if values.ctermbg ~= nil then
            table.insert(highlight, "ctermbg=" .. values.ctermbg)
        end
        if values.guifg ~= nil then
            table.insert(highlight, "guifg=" .. values.guifg)
        end
        if values.guibg ~= nil then
            table.insert(highlight, "guibg=" .. values.guibg)
        end
    end
    vim.fn.execute(table.concat(highlight, " "))
end

return {
    getHighlight = getHighlight,
    setHighlight = setHighlight,
}
