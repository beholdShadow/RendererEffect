local ShrinkIn = {
    duration = 1000,
    timestamp = 0,
}

function ShrinkIn:init(filter)
end

function ShrinkIn:clear(filter)
end

function ShrinkIn:setDuration(filter, duration)
    self.duration = duration
end

function ShrinkIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ShrinkIn:apply(filter)
    filter.animation.params.alpha = self.timestamp / (self.duration * 0.2)

    local r = self.timestamp / self.duration
    filter.animation.params.localScale[1] = 1.5 - 0.5 * r
    filter.animation.params.localScale[2] = 1.5 - 0.5 * r
    filter.animation.params.localScale[3] = 1.5 - 0.5 * r
end

function ShrinkIn:applyEffect(filter, outTex)
end
return ShrinkIn