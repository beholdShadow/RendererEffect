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

    local style = filter.label:getSdfStyle()

    local alpha = nil
    if t < halfDuration then
        alpha = t / halfDuration
    else
        alpha = 1.0 - (t - halfDuration) / halfDuration
    end

    style.color1.w = filter.animation.params.colorAlpha1 * alpha
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha
end

return Spark