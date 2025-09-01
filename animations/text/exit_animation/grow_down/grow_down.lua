local GrowDown = {
    tag = "GrowDown",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function GrowDown:init(filter)
end

function GrowDown:clear(filter)
end

function GrowDown:setDuration(filter, duration)
    self.duration = duration
end

function GrowDown:seek(filter, timestamp)
    self.timestamp = timestamp
end

function GrowDown:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function GrowDown:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function GrowDown:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function GrowDown:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration
    ratio = ratio * (2 - ratio)
    
    local lineInfo = filter.label:getLineInfo()
    local perRowDuration = self.duration / (0.5 * lineInfo.totalRows + 0.5)
    -- OF_LOGI(self.tag, string.format("GrowDown:applyEffect filter.style.color1.w =%f alpha = %f", filter.style.color1.w,alpha))

    -- local rotMat = Matrix4f:RotMat(0, 0, -ratio * rotateAmount * 2.0 * math.pi)
    -- local mvpMat = scaleMat
    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        
        -- local curRowTimestamp = perRowDuration + (lineInfo.totalRows - charBackup.rowIdx) * 0.5 * perRowDuration
        
        local curRowTimestamp = perRowDuration + (charBackup.rowIdx - 1) * 0.5 * perRowDuration
        local scale =  1.0 - self.smoothstep(self, curRowTimestamp - perRowDuration, curRowTimestamp, self.timestamp)
        local scaleMat = Matrix4f:ScaleMat(scale, scale, 1.0)

        local mvpMat = Matrix4f:TransMat((charBackup.pos[1] + charBackup.pos[3]) / 2, -((charBackup.rowIdx -1 ) * (lineInfo.maxLineHeight + filter.label.textLeading)), 0.0) *
                    scaleMat * 
                Matrix4f:TransMat(-(charBackup.pos[1] + charBackup.pos[3]) / 2, ((charBackup.rowIdx -1 ) * (lineInfo.maxLineHeight + filter.label.textLeading)), 0.0)
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end

    if ratio > 0.99 and filter.label.backgroundEnabled then 
        filter.label.backgroundColor.w = 0.0
    end
end

function GrowDown:applyEffect(label, srcTex, dstTex)
    -- OF_LOGI(self.tag, "GrowDown:applyEffect")
    -- if #label.chars <= 0 then
    --     return
    -- end

    -- local rotateAmount = 2.0
    -- local ratio = self.timestamp / self.duration

    -- OF_LOGI(self.tag, string.format("GrowDown:applyEffect %f", ratio))

    -- local alpha = self.linearstep(self, 0.0, 1.0, ratio / (1.0 / rotateAmount)) 

    -- OF_LOGI(self.tag, string.format("GrowDown:applyEffect rotate degree = %f", ratio * rotateAmount * 2.0 * 180))

    -- local rotMat = Matrix4f:RotMat(0, 0, ratio * rotateAmount * 2.0 * math.pi)
    -- local scaleMat = Matrix4f:ScaleMat(ratio, ratio, 1.0)
    -- local mvpMat = Matrix4f:ScaleMat(2.0 / dstTex.width, 2.0 /  dstTex.height, 1.0)
    --             * scaleMat * rotMat 
    --             * Matrix4f:ScaleMat(dstTex.width / 2.0, dstTex.height / 2.0, 1.0)

    -- label.context:bindFBO(dstTex)
    -- label.context:setViewport(0, 0, dstTex.width, dstTex.height)
    -- label.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    -- label.context:clearColorBuffer()
    -- self.renderPass:use()
    -- self.renderPass:setUniform1f("uAlpha", ratio)
    -- self.renderPass:setUniformTexture("uTexture0", 0, srcTex.textureID, TEXTURE_2D)
    -- self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    -- local quadRender = label.context:sharedQuadRender()
    -- quadRender:draw(self.renderPass, false)
    label.context:copyTexture(srcTex, dstTex)
end

return GrowDown