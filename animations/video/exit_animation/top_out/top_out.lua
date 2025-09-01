local TopOut = {
    duration = 1000,
    timestamp = 0,
}

function TopOut:init(filter)
end

function TopOut:clear(filter)
end

function TopOut:setDuration(filter, duration)
    self.duration = duration
end

function TopOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function TopOut:apply(filter)
    local ratio = self.timestamp / self.duration
    local dist = filter.imageTex:height() * filter.params.scale * 1.3
    filter.animation.params.position[2] = ratio * -dist
    filter.animation.params.alpha = 1.0 - self.timestamp / self.duration
end

function TopOut:applyEffect(filter, outTex)
end

return TopOut