local RotateOut = {
    duration = 1000,
    timestamp = 0,
}

function RotateOut:init(filter)
end

function RotateOut:clear(filter)
end

function RotateOut:setDuration(filter, duration)
    self.duration = duration
end

function RotateOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateOut:apply(filter)
    if self.timestamp > self.duration * 0.8 then
        filter.animation.params.alpha = (self.duration - self.timestamp) / (self.duration * 0.2)
    else
        filter.animation.params.alpha = 1.0
    end

    local r = self.timestamp / self.duration
    r = r ^ 2
    filter.animation.params.localScale[1] = 1.0 - 0.99 * r
    filter.animation.params.localScale[2] = 1.0 - 0.99 * r
    filter.animation.params.localScale[3] = 1.0 - 0.99 * r
    filter.animation.params.localRotation[3] = 4 * math.pi * r
end

function RotateOut:applyEffect(filter, outTex)
end
return RotateOut