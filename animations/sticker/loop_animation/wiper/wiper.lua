local Wiper = {
    tag = "Wiper",
    duration = 1000,
    timestamp = 0,
    renderToRT = false
}

function Wiper:init(filter)
end

function Wiper:clear(filter)
end

function Wiper:setDuration(filter, duration)
    self.duration = duration
end

function Wiper:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Wiper:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function Wiper:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function Wiper:apply(filter, outTex) 
    local ratio = self.timestamp / self.duration - math.floor(self.timestamp / self.duration)

    local rotateRad = math.pi / 6 * math.sin(2*math.pi / self.duration * self.timestamp)
    -- local rotateRad = math.pi / 3 * ( self.smoothstep(self, 0.0, 0.25, ratio) - 2 * self.smoothstep(self, 0.25, 0.75, ratio) + self.smoothstep(self, 0.75, 1*.00, ratio))

    local imageWidth = filter.imageTex:width() / filter.params.tileX
    local imageHeight = filter.imageTex:height() / filter.params.tileY
    local scale = filter.params.widthRatio * filter.params.outWidth / imageWidth 

    filter.animation.params.localTRSMat = Matrix4f:TransMat(0.0, imageHeight * scale * 0.5, 0.0) *
                                        Matrix4f:RotMat(0.0, 0.0, rotateRad) *
                                        Matrix4f:TransMat(0.0, -imageHeight * scale * 0.5, 0.0)
end

return Wiper