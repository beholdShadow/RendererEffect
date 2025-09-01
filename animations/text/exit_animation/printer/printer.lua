local Printer = {
    duration = 1000,
    timestamp = 0,
}

function Printer:init(filter)
end

function Printer:clear(filter)
end

function Printer:setDuration(filter, duration)
    self.duration = duration
end

function Printer:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Printer:apply(filter)
    local count = #filter.label.chars
    local n = math.ceil(self.timestamp / (self.duration / count))
    --print("Printer1", self.timestamp, self.timestamp / (self.duration / count))
    for i = 1, count do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        if i <= n then
            char.pos = { 0,0, 0,0, 0,0, 0,0 }
        else
            for j = 1, 8 do
                char.pos[j] = charBackup.pos[j]
            end
        end
    end
    if self.timestamp / self.duration > 0.99 and filter.label.backgroundEnabled then
        filter.label.backgroundColor.w = 0.0
    end
end

return Printer