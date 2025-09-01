local Spring = {
    duration = 1000,
    timestamp = 0,
}

function Spring:setDuration(filter, duration)
    self.duration = duration
end

function Spring:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Spring:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function Spring:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

function Spring:apply(filter)
    filter.animation.params.alpha = math.min((self.duration - self.timestamp) / (self.duration * 0.2), 1.0)

    local perStepDuration = self.duration / 6

    local scale = 0.02 * self.smoothstep(self, 0, perStepDuration, self.timestamp) -
                  0.02 * self.smoothstep(self, perStepDuration, 2 * perStepDuration, self.timestamp) +
                  0.15 * self.smoothstep(self, 2 * perStepDuration, 3 * perStepDuration, self.timestamp) -
                  0.15 * self.smoothstep(self, 3 * perStepDuration, 4 * perStepDuration, self.timestamp) +
                  0.5 * self.smoothstep(self, 4 * perStepDuration, 5 * perStepDuration, self.timestamp) -
                  1.0 * self.smoothstep(self, 5 * perStepDuration, 6 * perStepDuration, self.timestamp)

    filter.animation.params.localScale[1] = 1.0 + scale
    filter.animation.params.localScale[2] = 1.0 + scale
    filter.animation.params.localScale[3] = 1.0 + scale
end

return Spring