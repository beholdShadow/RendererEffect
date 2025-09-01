local Appear = {
    duration = 1000,
    timestamp = 0,
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
    local alpha = self.timestamp / self.duration

    local style = filter.label:getSdfStyle()
    style.color1.w = filter.animation.params.colorAlpha1 * alpha
    style.outline1Color1.w = filter.animation.params.outLine1Alpha * alpha
    style.outline2Color1.w = filter.animation.params.outLine2Alpha * alpha
    style.outline3Color1.w = filter.animation.params.outLine3Alpha * alpha
    style.shadowColor.w = filter.animation.params.shadowAplha * alpha
    filter.label.backgroundColor.w = filter.animation.params.backgroundAlpha * alpha

end

return Appear