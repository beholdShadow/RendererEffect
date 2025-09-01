local BottomOut = {
    duration = 1000,
    timestamp = 0,
}

function BottomOut:init(filter)
end

function BottomOut:clear(filter)
end

function BottomOut:setDuration(filter, duration)
    self.duration = duration
end

function BottomOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function BottomOut:apply(filter)
    local ratio = self.timestamp / self.duration
    local dist = filter.imageTex:height() * filter.params.scale * 1.3
    filter.animation.params.position[2] = ratio * dist
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration
end

function BottomOut:applyEffect(filter, outTex)
end

return BottomOut