local RotateCenterOut = {
    tag = "RotateCenterOut",
    duration = 1000,
    timestamp = 0,
    renderToRT = false,
}

function RotateCenterOut:init(filter)
end

function RotateCenterOut:clear(filter)
end

function RotateCenterOut:setDuration(filter, duration)
    self.duration = duration
end

function RotateCenterOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateCenterOut:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function RotateCenterOut:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration
    ratio = 1.0 -  ratio ^ 2

    local alpha = self.linearstep(self, 0.0, 1.0, ratio / (2.0 / rotateAmount)) 
    
    local style = filter.label:getSdfStyle()
    local lineInfo = filter.label:getLineInfo()
    style.color1.w = filter.animation.params.colorAlpha1 * alpha
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha

    -- OF_LOGI(self.tag, string.format("RotateCenterOut:applyEffect filter.style.color1.w =%f alpha = %f", filter.style.color1.w,alpha))

    local rotMat = Matrix4f:RotMat(0, 0, (1.0 - ratio) * rotateAmount * 2.0 * math.pi)
    local scaleMat = Matrix4f:ScaleMat(ratio, ratio, 1.0)
    local mvpMat = Matrix4f:TransMat(lineInfo.maxLineWidth / 2.0, -(lineInfo.totalHeight/2 - lineInfo.maxLineHeight), 0.0) *
                    scaleMat * rotMat *
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

function RotateCenterOut:applyEffect(label, srcTex, dstTex)
    label.context:copyTexture(srcTex, dstTex)
end

return RotateCenterOut