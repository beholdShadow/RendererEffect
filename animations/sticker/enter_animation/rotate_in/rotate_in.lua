local RotateIn = {
    duration = 1000,
    timestamp = 0,
}

function RotateIn:setDuration(filter, duration)
    self.duration = duration
end

function RotateIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateIn:apply(filter)
    filter.animation.params.alpha = math.min(self.timestamp / (0.2 * self.duration), 1.0)
    local r = self.timestamp / self.duration
    r = r * (2 - r)
    filter.animation.params.localScale[1] = 0.01 + 0.99 * r
    filter.animation.params.localScale[2] = 0.01 + 0.99 * r
    filter.animation.params.localScale[3] = 0.01 + 0.99 * r
    filter.animation.params.localRotation[3] = 4 * math.pi * (1.0 - r)
end

return RotateIn