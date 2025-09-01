local LeftIn = {
    duration = 1000,
    timestamp = 0,
}

function LeftIn:setDuration(filter, duration)
    self.duration = duration
end

function LeftIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function LeftIn:apply(filter)
    local ratio = (1.0 - self.timestamp / self.duration)
    local dist = filter.imageTex:width() * filter.params.scale * 1.3
    filter.animation.params.position[1] = ratio * -dist
    filter.animation.params.alpha = self.timestamp / self.duration
end

return LeftIn