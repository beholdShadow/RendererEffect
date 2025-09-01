local RotateGrowUp = {
    tag = "RotateGrowUp",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function RotateGrowUp:init(filter)
end

function RotateGrowUp:clear(filter)
end

function RotateGrowUp:setDuration(filter, duration)
    self.duration = duration
end

function RotateGrowUp:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateGrowUp:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function RotateGrowUp:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function RotateGrowUp:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function RotateGrowUp:squarestep(edge0, edge1, x) 
    x = math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
    return 1.0 - (1.0 - x) * (1.0 - x)
end

function RotateGrowUp:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end
    
    local lineInfo = filter.label:getLineInfo()
    local n = #filter.label.charsBackup
    local perCharDuration = self.duration / (0.25 * n + 0.75)

    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        
        local curCharTimestamp = perCharDuration * (i - 1) * 0.25
            
        local scale = self.smoothstep(self, curCharTimestamp, curCharTimestamp + perCharDuration, self.timestamp)

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

function RotateGrowUp:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return RotateGrowUp