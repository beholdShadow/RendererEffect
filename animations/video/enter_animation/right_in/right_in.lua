local RightIn = {
    duration = 1000,
    timestamp = 0,
}

function RightIn:init(filter)
end

function RightIn:clear(filter)
end

function RightIn:setDuration(filter, duration)
    self.duration = duration
end

function RightIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RightIn:apply(filter)
    local ratio = (1.0 - self.timestamp / self.duration)
    local dist = filter.imageTex:width() * filter.params.scale * 1.3
    filter.animation.params.position[1] = ratio * dist
    filter.animation.params.alpha = self.timestamp / self.duration
end

function RightIn:applyEffect(filter, outTex)
end

return RightIn