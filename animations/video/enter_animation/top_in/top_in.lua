local TopIn = {
    duration = 1000,
    timestamp = 0,
}

function TopIn:init(filter)
end

function TopIn:clear(filter)
end

function TopIn:setDuration(filter, duration)
    self.duration = duration
end

function TopIn:seek(filter, timestamp)
    self.timestamp = timestamp
end

function TopIn:apply(filter)
    local ratio = (1.0 - self.timestamp / self.duration)
    local dist = filter.imageTex:height() * filter.params.scale * 1.3
    filter.animation.params.position[2] = ratio * -dist
    filter.animation.params.alpha = self.timestamp / self.duration
end

function TopIn:applyEffect(filter, outTex)
end
return TopIn