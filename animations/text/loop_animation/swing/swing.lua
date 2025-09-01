local Swing = {
    tag = "Swing",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function Swing:init(filter)
end

function Swing:clear(filter)
end

function Swing:setDuration(filter, duration)
    self.duration = duration
end

function Swing:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Swing:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function Swing:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function Swing:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local ratio = self.timestamp / self.duration - math.floor(self.timestamp / self.duration)
    
    local lineInfo = filter.label:getLineInfo()

    local rotateRad = math.pi / 6 * math.sin(2*math.pi / self.duration * self.timestamp)
    -- local rotateRad = math.pi / 3 * ( self.smoothstep(self, 0.0, 0.25, ratio) - 2 * self.smoothstep(self, 0.25, 0.75, ratio) + self.smoothstep(self, 0.75, 1*.00, ratio))
    local rotMat = Matrix4f:RotMat(0, 0, rotateRad)
    local mvpMat = Matrix4f:TransMat(lineInfo.maxLineWidth / 2.0, -(lineInfo.totalHeight / 2  - lineInfo.maxLineHeight), 0.0) *
                    rotMat *
                Matrix4f:TransMat(-lineInfo.maxLineWidth / 2.0, lineInfo.totalHeight / 2  - lineInfo.maxLineHeight, 0.0)
    
    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end
    if filter.label.backgroundEnabled then
        local bg = filter.label.background
        local bgBackup = filter.label.backgroundBackup
        
        for n = 1, 4 do
            local pos = Vec4f.new(bgBackup.pos[2*n-1], bgBackup.pos[2*n], 0.0, 1.0)
            pos = mvpMat * pos 
            bg.pos[2*n-1] = pos.x
            bg.pos[2*n] = pos.y
        end
    end
end

function Swing:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return Swing