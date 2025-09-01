local GrowUp = {
    tag = "GrowUp",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function GrowUp:init(filter)
end

function GrowUp:clear(filter)
end

function GrowUp:setDuration(filter, duration)
    self.duration = duration
end

function GrowUp:seek(filter, timestamp)
    self.timestamp = timestamp
end

function GrowUp:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function GrowUp:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function GrowUp:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function GrowUp:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration
    ratio = ratio * (2 - ratio)
    
    local lineInfo = filter.label:getLineInfo()
    local perRowDuration = self.duration / (0.5 * lineInfo.totalRows + 0.5)

    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        
        local curRowTimestamp = perRowDuration + (lineInfo.totalRows - charBackup.rowIdx) * 0.5 * perRowDuration
        
        local scale =  self.smoothstep(self, curRowTimestamp - perRowDuration, curRowTimestamp, self.timestamp)
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
    end
end

function GrowUp:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return GrowUp