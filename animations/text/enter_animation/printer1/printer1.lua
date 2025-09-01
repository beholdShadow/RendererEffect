local Printer1 = {
    duration = 1000,
    timestamp = 0,
}

function Printer1:init(filter)
end

function Printer1:clear(filter)
end

function Printer1:setDuration(filter, duration)
    self.duration = duration
end

function Printer1:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Printer1:apply(filter)
    local count = #filter.label.chars
    local n = math.ceil(self.timestamp / (self.duration / count))
    --print("Printer1", self.timestamp, self.timestamp / (self.duration / count))
    for i = 1, count do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
        if i <= n then
            --char.color[4] = 1.0
            for j = 1, 8 do
                char.pos[j] = charBackup.pos[j]
            end
        else
            --char.color[4] = 0.0
            char.pos = { 0,0, 0,0, 0,0, 0,0 }
        end
    end
end

return Printer1
