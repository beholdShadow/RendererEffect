local Spark = {
    duration = 1000,
    timestamp = 0,
}

function Spark:init(filter)
end

function Spark:clear(filter)
end


function Spark:setDuration(filter, duration)
    if duration > 0 then
        self.duration = duration
    else
        self.duration = 100
    end
end

function Spark:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Spark:apply(filter)
    local t = math.fmod(self.timestamp, self.duration)
    local halfDuration = 0.5 * self.duration
    if t < halfDuration then
        filter.animation.params.alpha = t / halfDuration
    else
        filter.animation.params.alpha = 1.0 - (t - halfDuration) / halfDuration
    end
end

function Spark:applyEffect(filter, outTex)
end
return Spark