local WordJump = {
    duration = 1000,
    timestamp = 0,
    charJumpData = {},
}

function WordJump:init(filter)
end

function WordJump:clear(filter)
end

function WordJump:setDuration(filter, duration)
    self.duration = duration
end

function WordJump:seek(filter, timestamp)
    self.timestamp = timestamp
end

function WordJump:splitString(inputstr)
    local words = {}
    for word in inputstr:gmatch("%S+") do
        table.insert(words, word)
    end
    return words
end

function WordJump:calculateDuration(word, duration)
    return math.floor(tonumber(#word) * duration)
end

function WordJump:splitLabel(duration, label_chars)
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

function WordJump:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function WordJump:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function WordJump:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function WordJump:apply(filter)
    if #self.charJumpData == 0 then
        self.charJumpData = self.splitLabel(self, tonumber(self.duration) / tonumber(#filter.label.textString), filter.label.textString)
    end
    local count = #filter.label.chars
    local n = math.ceil(self.timestamp / (self.duration / count))

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
    else
        style.color1.w = filter.animation.params.colorAlpha1
        style.outline1Color1.w = filter.animation.params.outLine1Alpha
        style.outline2Color1.w = filter.animation.params.outLine2Alpha
        style.outline3Color1.w = filter.animation.params.outLine3Alpha
        style.shadowColor.w = filter.animation.params.shadowAplha
        filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha

        for i = 1, count do
            local char = filter.label.chars[i]
            local charBackup = filter.label.charsBackup[i]
            char.pos = { 0,0, 0,0, 0,0, 0,0 }
            if self.timestamp >= self.charJumpData[i].end_time then
                --char.color[4] = 1.0
                for j = 1, 8 do
                    char.pos[j] = charBackup.pos[j]
                end
            else
                --grow up
                local scale =  self.smoothstep(self, self.charJumpData[i].begin_time, self.charJumpData[i].end_time, self.timestamp)
                local scaleMat = Matrix4f:ScaleMat(scale, scale, 1.0)
        
                local mvpMat = Matrix4f:TransMat((charBackup.pos[1] + charBackup.pos[3]) / 2, -((charBackup.rowIdx-1) * (lineInfo.maxLineHeight + filter.label.textLeading)), 0.0) *
                            scaleMat * 
                        Matrix4f:TransMat(-(charBackup.pos[1] + charBackup.pos[3]) / 2, ((charBackup.rowIdx -1 ) * (lineInfo.maxLineHeight + filter.label.textLeading)), 0.0)
                for n = 1, 4 do
                    local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
                    pos = mvpMat * pos 
                    char.pos[2*n-1] = pos.x
                    char.pos[2*n] = pos.y
                end
                -- filter.label.textMeshBatch[i].color = { 0.1450, 0.9843, 0.1137, 1.0 }
            end
        end
    end
end

return WordJump
