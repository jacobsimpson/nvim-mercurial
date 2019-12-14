
local Commit = {}

function Commit:new(o)
    o = o or {
        complete = false,
        summary = "",
        description = {},
        files = {},
        indentation = "",
    }   -- create object if user does not provide one
    setmetatable(o, self)
    self.__index = self
    return o
end

function Commit:setSummary(summary)
    self.summary = summary
end

function Commit:setIndentation(indentation)
    self.indentation = indentation
end

function Commit:getIndentation()
    return self.indentation
end

function Commit:setComplete()
    self.complete = true
end

function Commit:isComplete()
    return self.complete
end

function Commit:addFile(file)
    return table.insert(self.files, file)
end

function Commit:addDescription(description)
    return table.insert(self.description, description)
end

function Commit:Lines()
    local result = {self.summary}
    for _, l in ipairs(self.description) do
        table.insert(result, l)
    end
    table.insert(result, self.indentation)
    table.insert(result, self.indentation .. "Files:")
    for _, f in ipairs(self.files) do
        table.insert(result, f)
    end
    table.insert(result, self.indentation)
    return result
end

function Commit:GetDescriptionLength()
    local descLength = 0
    for _, _ in ipairs(self.description) do
        descLength = descLength + 1
    end
    return descLength + 1
end

function Commit:GetFileLength()
    local fileLength = 0
    for _, _ in ipairs(self.files) do
        fileLength = fileLength + 1
    end
    return fileLength + 1
end

function Commit:GetLength()
    return 2 + self:GetDescriptionLength() + self:GetFileLength()
end

function Commit:GetDescriptionFold()
    local descLength = self:GetDescriptionLength()
    local fileLength = self:GetFileLength()
    return {2, descLength + 1 + fileLength}
end

function Commit:GetFileFold()
    local descLength = self:GetDescriptionLength()
    local fileLength = self:GetFileLength()
    return {descLength + 2, descLength + 1 + fileLength}
end

-- copies needs to reference the summary function, but in doing so makes a
-- cycle of references, so this predeclares summary, to satisfy the linter.
local summary

local function copies(line, commit)
    local loc, _ = string.find(line, "<<<<<<<<<<done>>>>>>>>>>")
    if loc ~= nil then
        commit:setComplete()
        return summary
    end
    if string.len(line) > 0 then
        commit:addFile(line)
    end
    return copies
end

local function files(line, commit)
    local loc, _ = string.find(line, "<<<<<<<<<<copies>>>>>>>>>>")
    if loc ~= nil then
        return copies
    end
    if string.len(line) > 0 then
        commit:addFile(line)
    end
    return files
end

local function description(line, commit)
    local loc, _ = string.find(line, "<<<<<<<<<<files>>>>>>>>>>")
    if loc ~= nil then
        commit:setIndentation(string.sub(line, 1, loc - 1))
        return files
    end
    commit:addDescription(line)
    return description
end

summary = function(line, commit)
    commit:setSummary(line)
    return description
end

local function Parser()
    local process = summary
    local commit = Commit:new()

    return function(line)
        process = process(line, commit)
        if commit:isComplete() then
            local result = commit
            commit = Commit:new()
            process = summary
            return result
        end
    end
end

return {
    Commit = Commit,
    Parser = Parser,
}
