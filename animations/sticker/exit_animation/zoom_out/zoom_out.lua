local ZoomOut = {
    duration = 1000,
    timestamp = 0,
}

function ZoomOut:init(filter)
end

function ZoomOut:clear(filter)
end

function ZoomOut:setDuration(filter, duration)
    self.duration = duration
end

function ZoomOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ZoomOut:apply(filter)
    filter.animation.params.alpha = math.min((self.duration - self.timestamp) / (self.duration * 0.2), 1.0)

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 0.5 * r + 1.0
    filter.animation.params.localScale[2] = 0.5 * r + 1.0
    filter.animation.params.localScale[3] = 0.5 * r + 1.0
end

function ZoomOut:applyEffect(filter, outTex)
end
return ZoomOut