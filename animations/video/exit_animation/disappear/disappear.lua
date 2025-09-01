local Disappear = {
    duration = 1000,
    timestamp = 0,
}

function Disappear:init(filter)
end

function Disappear:clear(filter)
end

function Disappear:setDuration(filter, duration)
    self.duration = duration
end

function Disappear:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Disappear:apply(filter)
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration
end

function Disappear:applyEffect(filter, outTex)
end
return Disappear