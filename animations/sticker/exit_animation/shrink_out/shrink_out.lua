local ShrinkOut = {
    duration = 1000,
    timestamp = 0,
}

function ShrinkOut:init(filter)
end

function ShrinkOut:clear(filter)
end

function ShrinkOut:setDuration(filter, duration)
    self.duration = duration
end

function ShrinkOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ShrinkOut:apply(filter)
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 1.0 - 0.5 * r
    filter.animation.params.localScale[2] = 1.0 - 0.5 * r
    filter.animation.params.localScale[3] = 1.0 - 0.5 * r
end

function ShrinkOut:applyEffect(filter, outTex)
end
return ShrinkOut