local WordPrint = {
    duration = 1000,
    timestamp = 0,
    charJumpData = {} ,
    color = Vec4f.new(1.0, 1.0, 1.0, 1.0)
}

function WordPrint:init(filter) 
    self.colorArr = {}
    -- table.insert(self.colorArr,  Vec4f.new(42.0 / 255, 185.0 / 255, 87.0 / 255, 1.0)) --GREEN
    table.insert(self.colorArr,  {color = Vec4f.new(1.0, 1.0, 85 / 255, 1.0), outlineColor = Vec4f.new(1.0, 1.0, 1.0, 0.0)}) -- YELLOW
    table.insert(self.colorArr,  {color = Vec4f.new(0.9, 0.2, 0.17, 1.0), outlineColor = Vec4f.new(1.0, 1.0, 1.0, 0.0)}) --RED
    table.insert(self.colorArr,  {color = Vec4f.new(1.0, 1.0, 1.0, 1.0), outlineColor = Vec4f.new(1.0, 1.0, 1.0, 0.0)}) --white
    table.insert(self.colorArr,  {color = Vec4f.new(1.0, 1.0, 1.0, 0.0), outlineColor = Vec4f.new(1.0, 1.0, 1.0, 1.0)})
    self.index = math.random(1, #self.colorArr)
    self.color = self.colorArr[index]
end

function WordPrint:clear(filter)
end

function WordPrint:setDuration(filter, duration)
    self.duration = duration
end

function WordPrint:seek(filter, timestamp)
    self.timestamp = timestamp
end

function WordPrint:splitString(inputstr)
    local words = {}
    for word in inputstr:gmatch("%S+") do
        table.insert(words, word)
    end
    return words
end

function WordPrint:calculateDuration(word, duration)
    return math.floor(tonumber(#word) * duration)
end

function WordPrint:splitWord(filter)
    local splitWord = {}
    local curWord = {}
    local charIdx = 1

    for p, c in utf8.codes(filter.label.textString) do
        if c == 10 or c == 32 then
            if #curWord > 0 then 
                table.insert(splitWord, curWord)
                curWord = {}
            end
        else 
            local char = filter.label.chars[charIdx]
            char.index = charIdx
            table.insert(curWord, char)
            charIdx = charIdx + 1
        end
    end
    if #curWord > 0 then 
        table.insert(splitWord, curWord)
    end
    return splitWord
end
function WordPrint:splitLabel(duration, label_chars)
    local words = self.splitString(self, label_chars)
    local result = {}

    local begin_time = 0
    for _, word in ipairs(words) do
        local wordDuration = self.calculateDuration(self, word, duration)
        for i = 1, #word do
            table.insert(result, { word = word[i], begin_time = begin_time, end_time = begin_time + wordDuration })
        end
        begin_time = begin_time + wordDuration
    end

    return result
end

function WordPrint:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function WordPrint:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function WordPrint:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function WordPrint:apply(filter)
    filter.label:flush(filter.context)
    if #self.charJumpData == 0 then
        self.charJumpData = self.splitLabel(self, tonumber(self.duration) / tonumber(#filter.label.textString), filter.label.textString)
    end
    local count = #filter.label.chars
    local n = math.ceil(self.timestamp / (self.duration / count))

    local words = self:splitWord(filter)
    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration
    ratio = ratio * (2 - ratio)
    local lineInfo = filter.label:getLineInfo()

    local style = filter.label:getSdfStyle()
    if self.timestamp < 33 then
        style.color1.w = 0
        style.outline1Color1.w = 0
        style.outline2Color1.w = 0
        style.outline3Color1.w = 0
        style.shadowColor.w = 0
        filter.label.backgroundColor.w = 0    
        self.index = math.random(1, #self.colorArr)
        self.color = self.colorArr[index]
    else
        style.color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0)
        style.color1.w = filter.animation.params.colorAlpha1
        style.outline1Color1.w = filter.animation.params.outLine1Alpha
        style.outline2Color1.w = filter.animation.params.outLine2Alpha
        style.outline3Color1.w = filter.animation.params.outLine3Alpha
        style.shadowColor.w = filter.animation.params.shadowAplha
        filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha

        for i = 1, count do
            local char = filter.label.chars[i]
            local charBackup = filter.label.charsBackup[i]
            local wordIdx = 1;
            for m = 1, #words do
                local word = words[m]
                for n = 1, #word do
                   if i == word[n].index then
                        wordIdx = m
                        break
                   end
                end
            end
            wordIdx = math.floor(wordIdx / 2.0)
            local charColor = self.colorArr[math.fmod(self.index + wordIdx, #self.colorArr) + 1]
            -- local charColor = (self.index + 1)
            if self.timestamp >= self.charJumpData[i].begin_time then
                --char.color[4] = 1.0
                for j = 1, 8 do
                    char.pos[j] = charBackup.pos[j]
                end
                
                -- Calculate alpha fade-in effect for each word
                local wordBeginTime = self.charJumpData[i].begin_time
                local wordEndTime = self.charJumpData[i].end_time
                local wordDuration = wordEndTime - wordBeginTime
                local fadeInDuration = wordDuration * 0.8-- 30% of word duration or max 200ms for fade-in
                local currentTime = self.timestamp - wordBeginTime
                
                local alpha = 1.0
                if currentTime < fadeInDuration then
                    -- Alpha gradually increases from 0 to 1 during fade-in period
                    alpha = self:smoothstep(0, fadeInDuration, currentTime)
                end
                
                -- Apply alpha to character color
                local fadeColor = Vec4f.new(charColor.color.x, charColor.color.y, charColor.color.z, charColor.color.w * alpha)
                local fadeOutlineColor = Vec4f.new(charColor.outlineColor.x, charColor.outlineColor.y, charColor.outlineColor.z, charColor.outlineColor.w * alpha)
                char.gradientColor = {fadeColor.x, fadeColor.y, fadeColor.z, fadeColor.w, 
                                        fadeColor.x, fadeColor.y, fadeColor.z, fadeColor.w, 
                                        fadeColor.x, fadeColor.y, fadeColor.z, fadeColor.w, 
                                        fadeColor.x, fadeColor.y, fadeColor.z, fadeColor.w}
    
                char.outlineColor = {fadeOutlineColor.x, fadeOutlineColor.y, fadeOutlineColor.z, fadeOutlineColor.w, 
                                        fadeOutlineColor.x, fadeOutlineColor.y, fadeOutlineColor.z, fadeOutlineColor.w, 
                                        fadeOutlineColor.x, fadeOutlineColor.y, fadeOutlineColor.z, fadeOutlineColor.w, 
                                        fadeOutlineColor.x, fadeOutlineColor.y, fadeOutlineColor.z, fadeOutlineColor.w}
            else
                char.pos = { 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0, 0,0 }
            end
        end
    end
end

return WordPrint
