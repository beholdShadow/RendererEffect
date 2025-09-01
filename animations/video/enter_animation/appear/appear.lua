local Appear = {
    duration = 1000,
    timestamp = 0,
    params = {
        alpha = 1.0,
        localPosition = { 0, 0, 0 },
        localScale = { 1.0, 1.0, 1.0 },
        localRotation = { 0.0, 0.0, 0.0 }
    }
}


function Appear:init(filter)
end

function Appear:clear(filter)
end

function Appear:setDuration(filter, duration)
    self.duration = duration
end

function Appear:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Appear:apply(filter)
    filter.animation.params.alpha = self.timestamp / self.duration
end

function Appear:applyEffect(filter, outTex)
end
return Appear