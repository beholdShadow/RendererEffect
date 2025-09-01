local RightOut = {
    duration = 1000,
    timestamp = 0,
}

function RightOut:init(filter)
end

function RightOut:clear(filter)
end

function RightOut:setDuration(filter, duration)
    self.duration = duration
end

function RightOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RightOut:apply(filter)
    local ratio = self.timestamp / self.duration
    local dist = filter.imageTex:width() * filter.params.scale * 1.3
    filter.animation.params.position[1] = ratio * dist
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration
end

function RightOut:applyEffect(filter, outTex)
end

return RightOut