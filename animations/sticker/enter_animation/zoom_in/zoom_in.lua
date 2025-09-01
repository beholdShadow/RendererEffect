local ZoomIn = {
    duration = 1000,
    timestamp = 0,
}

function ZoomIn:setDuration(filter, duration)
    self.duration = duration
end

function ZoomIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ZoomIn:apply(filter)
    filter.animation.params.alpha = self.timestamp / self.duration

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 0.5 + 0.5 * r
    filter.animation.params.localScale[2] = 0.5 + 0.5 * r
    filter.animation.params.localScale[3] = 0.5 + 0.5 * r
end

return ZoomIn