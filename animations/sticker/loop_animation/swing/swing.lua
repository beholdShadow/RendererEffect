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

function Swing:apply(filter) 
    local ratio = self.timestamp / self.duration - math.floor(self.timestamp / self.duration)

    local rotateRad = math.pi / 6 * math.sin(2*math.pi / self.duration * self.timestamp)
   
    filter.animation.params.localRotation[3] = rotateRad
end

return Swing