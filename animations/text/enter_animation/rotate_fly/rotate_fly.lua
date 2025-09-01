local RotateFly = {
    tag = "RotateFly",
    duration = 1000,
    timestamp = 0,
    renderToRT = false,
}

function RotateFly:init(filter)
end

function RotateFly:clear(filter)
end

function RotateFly:setDuration(filter, duration)
    self.duration = duration
end

function RotateFly:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateFly:step(edge, x)
    if x < edge then
        return 0.0
    else
        return x
    end
end

function RotateFly:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function RotateFly:step(edge, x)
    if edge < x then
        return 1.0
    else
        return 0.0
    end
end

function RotateFly:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function RotateFly:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function RotateFly:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    local rotateAmount = 2.0

    local d = 0
    local n = #filter.label.chars
    local velocity = (rotateAmount * 2 * math.pi + (n - 1) * math.pi +  (n - 1) * self.step(self, 0.0, (n -2)) * (n - 2) * d / 2 + 3.0 * math.pi) / self.duration
    local delayTime = math.pi / velocity

    local uniformTime = (rotateAmount * 2 * math.pi -  1.5 * math.pi) / velocity
    local slowTime = 4.5 * math.pi / velocity
    local a = velocity / slowTime ^ 2
    -- OF_LOGI(self.tag, string.format("RotateCenterIn:apply velocity =%f delayTime = %f", velocity, delayTime))

    local lineInfo = filter.label:getLineInfo()
    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]

        local rotateTime = self.timestamp - delayTime * (i -1) - (i - 1) * self.step(self, 0.0, (i -2)) * (i - 2) * d / 2 / velocity
        
        local rotateRad
        if rotateTime >= (uniformTime + slowTime) then
            rotateRad =  rotateAmount * 2 * math.pi
        else
            if rotateTime > uniformTime then
                local curSlowTime = slowTime - (rotateTime - uniformTime)
                rotateRad = (rotateAmount * 2 * math.pi -  1.5 * math.pi) + a / 3 * (slowTime ^ 3 - curSlowTime ^ 3)
            else
                rotateRad = velocity * rotateTime
            end
        end
      
        rotateRad = self.clamp(self, rotateRad, 0.0, rotateAmount * 2 * math.pi)

        local rotMat = Matrix4f:RotMat(0, 0, -rotateRad)

        local ratio = rotateRad / (rotateAmount * 2 * math.pi)  
        ratio = 1.1 * self.smoothstep(self, 0.0, 0.9, ratio) - 0.1 * self.smoothstep(self, 0.9, 1.0, ratio)
        local scaleMat = Matrix4f:ScaleMat(ratio, ratio, 1.0)

        local radiusOffset = charBackup.pos[1] * (1.0 - ratio) 

        local mvpMat = Matrix4f:TransMat(0.0, lineInfo.maxLineHeight, 0.0) *
                        scaleMat * rotMat * Matrix4f:TransMat(-radiusOffset, 0.0, 0.0) *
                    Matrix4f:TransMat(0.0, - lineInfo.maxLineHeight, 0.0)
            
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)

            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end
end

function RotateFly:applyEffect(label, srcTex, dstTex)
end

return RotateFly