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
    local v = randomPos[math.floor(p * 10) + 1];
    local count = #filter.label.chars
    for i = 1, count do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        for j = 1, 8, 2 do
            char.pos[j] = charBackup.pos[j] + v[1]
            char.pos[j + 1] = charBackup.pos[j + 1] + v[2]
        end
    end    
end

return Shake