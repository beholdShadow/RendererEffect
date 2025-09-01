local Disappear = {
    duration = 1000,
    timestamp = 0,
}

function Disappear:init(filter)
end

function Disappear:clear(filter)
end

function Disappear:setDuration(filter, duration)
    self.duration = duration
end

function Disappear:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Disappear:apply(filter)
    -- local count = #filter.label.chars
    -- for i = 1, count do
    --     local char = filter.label.chars[i]
    --     char.color[4] = 1.0 - self.timestamp / self.duration
    -- end
    -- print(self.timestamp)
    local alpha = self.timestamp / self.duration

    local style = filter.label:getSdfStyle()
    style.color1.w = filter.animation.params.colorAlpha1 * (1.0 - alpha)
    style.outline1Color1.w = filter.animation.params.outLine1Alpha *  (1.0 - alpha)
    style.outline2Color1.w = filter.animation.params.outLine2Alpha *  (1.0 - alpha)
    style.outline3Color1.w = filter.animation.params.outLine3Alpha *  (1.0 - alpha)
    style.shadowColor.w = filter.animation.params.shadowAplha *  (1.0 - alpha)
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha *  (1.0 - alpha)
end

return Disappear