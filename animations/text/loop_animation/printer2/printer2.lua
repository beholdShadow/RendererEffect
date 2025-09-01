
local Printer2 = {
    duration = 1000,
    timestamp = 0,
}

function Printer2:split(s,re,plain,n)
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

function Printer2:init(filter)
end

function Printer2:clear(filter)
end

function Printer2:setDuration(filter, duration)
    self.duration = duration
end

function Printer2:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Printer2:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function Printer2:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function Printer2:squarestep(edge0, edge1, x) 
    x = math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
    return x * x
end

function Printer2:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

local LabelTag = "OF-LabelPro"
function Printer2:apply(filter)
    filter.label:flush(filter.context)
    
    if #filter.label.chars <= 0 then
        OF_LOGI(LabelTag, string.format("Animation Printer2 text empty!!!!!!!!!!!!!!!"))
        return
    end
    -- local splitWord = Printer2:split(filter.animation.text, " ")
    -- if #splitWord <= 0 then
    --     return
    -- end
    local splitWord = {}
    local curWord = {}
    local charIdx = 1
    
    local colorArr = {}
    table.insert(colorArr,  Vec4f.new(42.0 / 255, 185.0 / 255, 87.0 / 255, 1.0)) --GREEN
    table.insert(colorArr,  Vec4f.new(236.0 / 255, 190.0 / 255, 0.0 / 255, 1.0)) -- YELLOW
    table.insert(colorArr,  Vec4f.new(255.0 / 255, 48.0 / 255, 53.0 / 255, 1.0)) --RED
    table.insert(colorArr,  Vec4f.new(1.0, 1.0, 1.0, 1.0)) --white
    local colorIdx = {4, 4, 3, 4, 4, 4, 4, 1, 1, 4, 4, 1, 4, 4, 1, 1, 1, 4, 4, 1, 4, 4, 1, 1, 1, 4, 2, 2, 4, 2, 4, 4, 2, 4, 2, 4, 4, 1, 4, 1, 1}
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

    local percent = self:linearstep(0.0, 1.0, 1.0 - (wordDuration * index - self.timestamp) / wordDuration)
    
    percent = self:clamp(percent, 0.0, 1.0)

    
    -- OF_LOGI(LabelTag, string.format("Animation Printer2 filter.label.textString = %s, timestamp = %f, percent = %f", filter.animation.text, self.timestamp, percent))

    local alpha = self:smoothstep(0.0, 0.4, percent)
    local scale = -0.2 * (-percent * percent + 2.0 * percent) + 1.2
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
    style.color1 = colorArr[colorIdx[index]]
    style.color1.w = filter.animation.params.colorAlpha1 * alpha 
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha
end

return Printer2
