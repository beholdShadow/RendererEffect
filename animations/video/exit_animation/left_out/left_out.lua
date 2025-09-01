local LeftOut = {
    duration = 1000,
    timestamp = 0,
}

function LeftOut:init(filter)
end

function LeftOut:clear(filter)
end

function LeftOut:setDuration(filter, duration)
    self.duration = duration
end

function LeftOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function LeftOut:apply(filter)
    local ratio = (self.timestamp / self.duration)
    local dist = filter.imageTex:width() * filter.params.scale * 1.3
    filter.animation.params.position[1] = ratio * -dist
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration
end

function LeftOut:applyEffect(filter, outTex)
end
return LeftOut