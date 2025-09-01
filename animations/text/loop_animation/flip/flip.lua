local Flip = {
    tag = "Flip",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function Flip:init(filter)
end

function Flip:clear(filter)
end

function Flip:setDuration(filter, duration)
    self.duration = duration
end

function Flip:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Flip:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local ratio = self.timestamp / self.duration
    local lineInfo = filter.label:getLineInfo()
    -- OF_LOGI(self.tag, string.format("Flip:applyEffect filter.style.color1.w =%f alpha = %f", filter.style.color1.w,alpha))

    local rotMat = Matrix4f:RotMat(0, -ratio * 2.0 * math.pi, 0)
    local mvpMat = Matrix4f:TransMat(lineInfo.maxLineWidth / 2.0, -(lineInfo.totalHeight/2 - lineInfo.maxLineHeight), 0.0) *
                    rotMat *
                Matrix4f:TransMat(-lineInfo.maxLineWidth / 2.0, lineInfo.totalHeight/2 - lineInfo.maxLineHeight, 0.0)
    
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

function Flip:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return Flip