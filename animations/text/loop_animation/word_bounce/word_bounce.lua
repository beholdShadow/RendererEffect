
local WordBounce = {
    duration = 1000,
    timestamp = 0,
}

function WordBounce:split(s,re,plain,n)
    local find,sub,append = string.find, string.sub, table.insert
    local i1,ls = 1,{}
    if not re then re = '%s+' end
    if re == '' then return {s} end
    while true do
        local i2,i3 = find(s,re,i1,plain)
        if not i2 then
            local last = sub(s,i1)
            if last ~= '' then append(ls,last) end
            if #ls == 1 and ls[1] == '' then
                return {}
            else
                return ls
            end
        end
        append(ls,sub(s,i1,i2-1))
        if n and #ls == n then
            ls[#ls] = sub(s,i1)
            return ls
        end
        i1 = i3+1
    end
end

function WordBounce:init(filter)
    self.firstIdx = math.random(1,4)
end

function WordBounce:clear(filter)
end

function WordBounce:setDuration(filter, duration)
    self.duration = duration
end

function WordBounce:seek(filter, timestamp)
    self.timestamp = timestamp
end

function WordBounce:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function WordBounce:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function WordBounce:squarestep(edge0, edge1, x) 
    x = math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
    return x * x
end

function WordBounce:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

local function funcEaseAction3(t, b, c)
    -- diyijieduandeweiyiquxian，zhegeshigongshibanben
    if t~=0.0 and t~=1.0 then
        t = math.exp(-7.0 * t) * 1.0 * math.sin((t - 0.075) * (2.0*math.pi) / 0.3) + 1.0
    end
    return t * c + (1.0 - t) * b
end

local LabelTag = "OF-LabelPro"
function WordBounce:apply(filter)
    filter.label:flush(filter.context)

    if #filter.label.chars <= 0 then
        return
    end
    -- OF_LOGI(LabelTag, string.format("WordBounce filter.label.textString = %s", filter.animation.text))
    -- local splitWord = WordBounce:split(filter.animation.text, " ")
    -- if #splitWord <= 0 then
    --     return
    -- end
    local splitWord = {}
    local curWord = {}
    local charIdx = 1
    
    local colorArr = {}
    table.insert(colorArr,  Vec4f.new(42.0 / 255, 185.0 / 255, 87.0 / 255, 1.0)) --GREEN
    table.insert(colorArr,  Vec4f.new(128.0 / 255, 77.0 / 255, 236.0 / 255, 1.0)) -- PURPLE
    table.insert(colorArr,  Vec4f.new(255.0 / 255, 48.0 / 255, 53.0 / 255, 1.0)) --RED
    table.insert(colorArr,  Vec4f.new(1.0, 1.0, 1.0, 1.0)) --white
    local colorIdx = {self.firstIdx, 4, 2, 4, 3, 4, 4, 1, 3, 4, 4, 1, 4, 4, 1, 2, 1, 4, 4, 1, 4, 4, 1, 3, 1, 4, 2, 2, 4, 2, 4, 3, 2, 4, 2, 4, 4, 1, 4, 1, 1}
    for p, c in utf8.codes(filter.label.textString) do
        if c == 10 or c == 32 then
            if #curWord > 0 then 
                table.insert(splitWord, curWord)
                curWord = {}
            end
        else 
            local char = filter.label.chars[charIdx]
            char.index = charIdx
            char.color =  colorArr[math.random(1, #colorArr)]
            table.insert(curWord, char)
            charIdx = charIdx + 1
        end
    end
    if #curWord > 0 then 
        table.insert(splitWord, curWord)
    end
    local wordDuration = self.duration / #splitWord
    local index = math.max(math.ceil(self.timestamp / wordDuration), 1)
    -- OF_LOGI(LabelTag, string.format("WordBounce filter.label.textString = %s, len = %d, index = %d", filter.label.textString, #filter.label.chars, index))
    curWord = splitWord[index]
    local lineInfo = filter.label:getLineInfo()
    local textCenter = {lineInfo.x + lineInfo.maxLineWidth * 0.5, 0.0}
    for i = 1, #filter.label.chars do
        local char = filter.label.chars[i]
        char.pos = { 0,0, 0,0, 0,0, 0,0 }
        textCenter[2] = textCenter[2] + char.baseline;
    end
    textCenter[2] = textCenter[2] / #filter.label.chars
    local wordCenter= { minX = 10000, maxX = -10000, maxY = -10000, minY = 10000}
    for i = 1, #curWord do
        local charBackup = filter.label.charsBackup[curWord[i].index]
        for j = 1, 4 do
            wordCenter.minX = math.min(wordCenter.minX, charBackup.pos[2*j-1])
            wordCenter.maxX = math.max(wordCenter.maxX, charBackup.pos[2*j-1])
            wordCenter.minY = math.min(wordCenter.minY, charBackup.pos[2*j])
            wordCenter.maxY = math.max(wordCenter.maxY, charBackup.pos[2*j])
        end
        wordCenter.baseline = charBackup.baseline
    end

    local percent = self:linearstep(0.0, 1.0, (self.timestamp - wordDuration * (index - 1)) / (wordDuration * 0.95))
    -- local scale = 0.9 + 0.5 * self.smoothstep(self, 0, 0.2, percent) -
    --                     0.1 * self.linearstep(self, 0.2, 0.23, percent) -
    --                     0.3 * self.linearstep(self, 0.3, 0.45, percent) +
    --                     0.10 * self.smoothstep(self, 0.5, 0.6, percent) -
    --                     0.10 * self.smoothstep(self, 0.6,  0.7, percent)
    local scale = funcEaseAction3(percent, 0.0, 1.0)
    for i = 1, #curWord do
        local char = filter.label.chars[curWord[i].index]
        local charBackup = filter.label.charsBackup[curWord[i].index]
        for j = 1, 4 do
            char.pos[2*j-1] = textCenter[1] + (charBackup.pos[2*j-1] - (wordCenter.maxX + wordCenter.minX) * 0.5) * scale
            char.pos[2*j] = textCenter[2] - wordCenter.baseline + (wordCenter.minY + wordCenter.maxY) * 0.5 + (charBackup.pos[2*j] - (wordCenter.minY + wordCenter.maxY) * 0.5) * scale
        end
    end
    local colorindex = index - math.floor((index-1) / #colorIdx) * #colorIdx
    local style = filter.label:getSdfStyle()
    style.color1 = colorArr[colorIdx[colorindex]]
end

return WordBounce
