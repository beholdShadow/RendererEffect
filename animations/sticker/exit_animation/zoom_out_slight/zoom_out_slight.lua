local ZoomOutSlight = {
    duration = 1000,
    timestamp = 0,
}

function ZoomOutSlight:init(filter)
end

function ZoomOutSlight:clear(filter)
end

function ZoomOutSlight:setDuration(filter, duration)
    self.duration = duration
end

function ZoomOutSlight:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ZoomOutSlight:apply(filter)
    filter.animation.params.alpha = math.min((self.duration - self.timestamp) / (self.duration * 0.2), 1.0)

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 0.1 * r + 1.0
    filter.animation.params.localScale[2] = 0.1 * r + 1.0
    filter.animation.params.localScale[3] = 0.1 * r + 1.0
end

function ZoomOutSlight:applyEffect(filter, outTex)
end
return ZoomOutSlight