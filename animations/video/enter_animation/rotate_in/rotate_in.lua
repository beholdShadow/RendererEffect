local RotateIn = {
    duration = 1000,
    timestamp = 0,
}

function RotateIn:init(filter)
end

function RotateIn:clear(filter)
end

function RotateIn:setDuration(filter, duration)
    self.duration = duration
end

function RotateIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RotateIn:apply(filter)
    if self.timestamp < self.duration * 0.2 then
        filter.animation.params.alpha = self.timestamp / (self.duration * 0.2)
    else
        filter.animation.params.alpha = 1.0
    end

    local r = self.timestamp / self.duration
    r = r * (2 - r)
    filter.animation.params.localScale[1] = 0.01 + 0.99 * r
    filter.animation.params.localScale[2] = 0.01 + 0.99 * r
    filter.animation.params.localScale[3] = 0.01 + 0.99 * r
    filter.animation.params.localRotation[3] = 4 * math.pi * (1.0 - r)
end

function RotateIn:applyEffect(filter, outTex)
end
return RotateIn