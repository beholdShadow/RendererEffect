local ZoomInSlight = {
    duration = 1000,
    timestamp = 0,
}

function ZoomInSlight:setDuration(filter, duration)
    self.duration = duration
end

function ZoomInSlight:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ZoomInSlight:apply(filter)
    filter.animation.params.alpha = math.min(self.timestamp / (0.2 * self.duration), 1.0)

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 0.9 + 0.1 * r
    filter.animation.params.localScale[2] = 0.9 + 0.1 * r
    filter.animation.params.localScale[3] = 0.9 + 0.1 * r
    filter.animation.params.localPosition[2] = (1.0 - r) * (0.15 * filter.imageTex:height() / 2)
end

return ZoomInSlight