local CenterShrink = {
    tag = "CenterShrink",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function CenterShrink:init(filter)
end

function CenterShrink:clear(filter)
end

function CenterShrink:setDuration(filter, duration)
    self.duration = duration
end

function CenterShrink:seek(filter, timestamp)
    self.timestamp = timestamp
end

function CenterShrink:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function CenterShrink:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function CenterShrink:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function CenterShrink:squarestep(edge0, edge1, x) 
    x = math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
    return x * x
end

function CenterShrink:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local ratio = self.squarestep(self, 0.0, self.duration, self.timestamp)
    
    local alpha = self.linearstep(self, 0.0, 1.0, ratio) 
    
    local style = filter.label:getSdfStyle()
    local lineInfo = filter.label:getLineInfo()
    style.color1.w = filter.animation.params.colorAlpha1 * alpha
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha

    -- self.lineInfo = {}
    -- self.lineInfo.x = x
    -- self.lineInfo.y = y
    -- self.lineInfo.maxLineWidth = maxLineWidth
    -- self.lineInfo.maxLineHeight = maxLineHeight
    -- self.lineInfo.totalHeight = maxLineHeight * #lines + (#lines - 1) * self.textLeading
    -- self.lineInfo.totalRows = #lines
    -- self.lineInfo.lines = lines

    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        local col = i
        for j = 1, char.rowIdx - 1 do
            col = col - lineInfo.lines[j].glyphCount
        end
        local cnt = (lineInfo.lines[char.rowIdx].glyphCount + 1.0 )
        local xoffset = (1.0 - ratio) * lineInfo.maxLineWidth * 1.5 * (col - cnt / 2.0) / cnt
        local mvpMat = Matrix4f:TransMat(xoffset, 0.0, 0.0)
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end
end

function CenterShrink:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return CenterShrink