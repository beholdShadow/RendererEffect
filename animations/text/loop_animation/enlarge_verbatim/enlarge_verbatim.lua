local EnlargeVerbatim = {
    tag = "EnlargeVerbatim",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function EnlargeVerbatim:init(filter)
end

function EnlargeVerbatim:clear(filter)
end

function EnlargeVerbatim:setDuration(filter, duration)
    self.duration = duration
end

function EnlargeVerbatim:seek(filter, timestamp)
    self.timestamp = timestamp
end

function EnlargeVerbatim:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function EnlargeVerbatim:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function EnlargeVerbatim:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local n = #filter.label.charsBackup
    local cycle = math.floor(self.timestamp / self.duration)
    -- local perCharDuration = self.duration / (0.75 * n + 0.25)
    local perCharDuration = self.duration / (0.5 * n + 0.5)

    local lineInfo = filter.label:getLineInfo()
    
    for i = 1, n do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
    
        local curCharTimestamp = perCharDuration + (i-1) * 0.5 * perCharDuration + cycle * self.duration
        
        local deltaTime = self.timestamp - curCharTimestamp
        local scale = 1.0 + 0.2 * (self.smoothstep(self, -perCharDuration, -perCharDuration * 0.5, deltaTime) 
                            - self.smoothstep(self, -perCharDuration * 0.5, 0.0, deltaTime))
        -- local scaleRatio = 1.0 + 0.2 * (self.smoothstep(self, 0.0, 0.5, cRatio) - self.smoothstep(self, 0.5, 1.0,cRatio))
        -- local scaleRatio = 1.1 + 0.1 * math.sin(n * 2 * math.pi / self.duration * (self.timestamp - 0.25 * self.duration / n))
        local mvpMat = Matrix4f:TransMat((charBackup.pos[1] + charBackup.pos[3]) / 2, (charBackup.pos[2] - lineInfo.maxLineHeight), 0.0) 
                    * Matrix4f:ScaleMat(scale, scale, 1.0) * 
                    Matrix4f:TransMat(-(charBackup.pos[1] + charBackup.pos[3]) / 2, -(charBackup.pos[2] - lineInfo.maxLineHeight), 0.0)
    
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end              
end

function EnlargeVerbatim:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return EnlargeVerbatim