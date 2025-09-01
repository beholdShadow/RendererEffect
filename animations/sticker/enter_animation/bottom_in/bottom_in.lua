local BottomIn = {
    duration = 1000,
    timestamp = 0,
}

function BottomIn:setDuration(filter, duration)
    self.duration = duration
end

function BottomIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function BottomIn:apply(filter)
    local ratio = (1.0 - self.timestamp / self.duration)
    local dist = filter.imageTex:height() * filter.params.scale * 1.3
    filter.animation.params.position[2] = ratio * dist
    filter.animation.params.alpha = self.timestamp / self.duration
end

return BottomIn