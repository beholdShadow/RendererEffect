local Rotation = {
    duration = 1000,
    timestamp = 0,
}

function Rotation:init(filter)
end

function Rotation:clear(filter)
end

function Rotation:setDuration(filter, duration)
    if duration > 0 then
        self.duration = duration
    else
        self.duration = 100
    end
end

function Rotation:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Rotation:apply(filter)
    filter.animation.params.localRotation[3] = math.fmod(self.timestamp, self.duration) / self.duration * 2 * math.pi
end

function Rotation:applyEffect(filter, outTex)
end

return Rotation