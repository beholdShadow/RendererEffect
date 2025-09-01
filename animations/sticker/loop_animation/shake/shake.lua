local Shake = {
    duration = 1000,
    timestamp = 0,
}

function Shake:init(filter)
end

function Shake:clear(filter)
end

function Shake:setDuration(filter, duration)
    if duration > 0 then
        self.duration = duration
    else
        self.duration = 100
    end
end

function Shake:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Shake:apply(filter)
    local t = math.fmod(self.timestamp, self.duration)    
    local p = t / self.duration;
    local randomPos = {
        { -10, -10 },
        { -20, -20 },
        { -20, 0 },
        { -15, 15 },
        { -0, 10 },
        { 20, 20 },
        { 20, -10 },
        { 0, 15 },
        { -5, 20 },
        { 0, 0 }
    }
    local v = randomPos[math.floor(p * 10) + 1]
    filter.animation.params.position[1]  = v[1]   
    filter.animation.params.position[2]  = v[2]   
end

return Shake