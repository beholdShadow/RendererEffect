local RotateRightOut = {
    tag = "RotateRightOut",
    duration = 1000,
    timestamp = 0,
    renderToRT = false,
}

function RotateRightOut:init(filter)
end

function RotateRightOut:clear(filter)
end

function RotateRightOut:setDuration(filter, duration)
    self.duration = duration
end

function RotateRightOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateRightOut:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function RotateRightOut:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration
    ratio = 1.0 - ratio ^ 2

    local alpha = self.linearstep(self, 0.0, 1.0, ratio / (1.0 / rotateAmount)) 

    local style = filter.label:getSdfStyle()
    style.color1.w = filter.animation.params.colorAlpha1 * alpha
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha

    -- OF_LOGI(self.tag, string.format("RotateRightOut:applyEffect filter.style.color1.w =%f alpha = %f", filter.style.color1.w,alpha))

    local rotMat = Matrix4f:RotMat(0, 0, (1.0 - ratio) * rotateAmount * 2.0 * math.pi)
    local scaleMat = Matrix4f:ScaleMat(ratio, ratio, 1.0)
    local lineInfo = filter.label:getLineInfo()
    local mvpMat = Matrix4f:TransMat(lineInfo.maxLineWidth, -(lineInfo.totalHeight - lineInfo.maxLineHeight), 0.0) *
                            scaleMat * rotMat *
                        Matrix4f:TransMat(-lineInfo.maxLineWidth, (lineInfo.totalHeight - lineInfo.maxLineHeight), 0.0)


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

function RotateRightOut:applyEffect(label, srcTex, dstTex)
    -- OF_LOGI(self.tag, "RotateRightOut:applyEffect")
    -- if #label.chars <= 0 then
    --     return
    -- end

    -- local rotateAmount = 2.0
    -- local ratio = self.timestamp / self.duration

    -- OF_LOGI(self.tag, string.format("RotateRightOut:applyEffect %f", ratio))

    -- local alpha = self.linearstep(self, 0.0, 1.0, ratio / (1.0 / rotateAmount)) 

    -- OF_LOGI(self.tag, string.format("RotateRightOut:applyEffect rotate degree = %f", ratio * rotateAmount * 2.0 * 180))

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

return RotateRightOut