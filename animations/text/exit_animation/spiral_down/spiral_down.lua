local SpiralDown = {
    tag = "SpiralDown",
    duration = 1000,
    timestamp = 0,
    renderToRT = false,
    randomArray = {}
}

function SpiralDown:init(filter)
end

function SpiralDown:clear(filter)
end

function SpiralDown:setDuration(filter, duration)
    self.duration = duration
end

function SpiralDown:seek(filter, timestamp)
    self.timestamp = timestamp
end

function SpiralDown:step(edge, x)
    if x < edge then
        return 0.0
    else
        return x
    end
end

function SpiralDown:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function SpiralDown:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function SpiralDown:apply(filter, outTex) 
    if #filter.label.chars <= 0 then
        return
    end

    if #self.randomArray == 0 or #self.randomArray ~= #filter.label.charsBackup then
        for i = #self.randomArray, 1, -1 do
            table.remove(self.randomArray, i)
        end
        
        for i = 1, #filter.label.charsBackup do 
            self.randomArray[i] = {
                start = math.random(0, math.min(#filter.label.charsBackup * 20, 150)) / 200.0,
                yoffset = math.random(math.min(#filter.label.charsBackup * 100, 1000), math.min(#filter.label.charsBackup * 200, 2000)) / 10.0,
                speed = math.random(100, 300) / 100.0
            }
            self.randomArray[i].yoffset = self.randomArray[i].yoffset * (2.5 - 1.5 * self.randomArray[i].start)
            -- self.randomArray[i].speed = self.randomArray[i].speed * (3.0 * self.randomArray[i].start + 1.0)
            self.randomArray[i].speed = math.random(math.floor(100 + 200 * self.randomArray[i].start), 300) / 100.0
        end
    end

    local rotateAmount = 2.0
    local ratio = self.timestamp / self.duration

    for i = 1, #filter.label.charsBackup do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        
        local speed = self.randomArray[i].speed - ratio * (self.randomArray[i].speed - 1.0)
        local cRatio = self.clamp(self, ratio * speed, 0.0, 1.0) 
        local cTransRatio = self.clamp(self, 1.3 * cRatio, 0.0, 1.0) 
        local transMat = Matrix4f:TransMat(0.0, -(cTransRatio ) * self.randomArray[i].yoffset, 0.0)
        local rotMat = Matrix4f:RotMat(0, 0, - cRatio * rotateAmount * 2.0 * math.pi)
        local scaleMat = Matrix4f:ScaleMat(self.step(self, self.randomArray[i].start, 1.0 - cRatio), self.step(self, self.randomArray[i].start, 1.0 - cRatio), 1.0)

        local center = {
            x = (charBackup.pos[1] + charBackup.pos[3]) / 2,
            y = (charBackup.pos[2] + charBackup.pos[6]) / 2
        }

        local mvpMat = transMat * Matrix4f:TransMat(center.x, center.y, 0.0)
                * scaleMat * rotMat *
                Matrix4f:TransMat(-center.x, -center.y, 0.0)
            
        for n = 1, 4 do
            local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)

            pos = mvpMat * pos 
            char.pos[2*n-1] = pos.x
            char.pos[2*n] = pos.y
        end
    end
end

function SpiralDown:applyEffect(label, srcTex, dstTex)
end

return SpiralDown