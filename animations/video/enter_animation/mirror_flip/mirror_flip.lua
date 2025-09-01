local MirrorFlip = {
    duration = 1000.0,
    timestamp = 0.0,
}


function MirrorFlip:init(context)
end

function MirrorFlip:clear(context)
end

function MirrorFlip:setDuration(filter, duration)
    self.duration = duration
end

function MirrorFlip:seek(filter, timestamp)
    self.timestamp = timestamp
end

function MirrorFlip:apply(filter)
    -- local r = self.timestamp / self.duration
    -- OF_LOGI(TAG, string.format("MirrorFlip:apply R= %f", r))
    -- filter.animation.params.rotation[2] =  math.pi  * (r - 1.0)
    filter.animation.params.renderToRT = true
end

function MirrorFlip:applyEffect(filter, outTex)
    --first render imageTex to output viewport
    local width, height = outTex.width, outTex.height
	local quadRender = filter.context:sharedQuadRender()

    local r = self.timestamp / self.duration

    local mirrorMat = Matrix4f:RotMat(0.0, (1.0 - r) * math.pi / 2, 0.0)
	local scaleMat = Matrix4f:ScaleMat(filter.params.scale, filter.params.scale, 1.0)
	local rotMat = Matrix4f:RotMat(0.0, 0.0, filter.params.rot)
	local transMat = Matrix4f:TransMat(filter.params.tx, filter.params.ty, 0.0)

	local mvpMat = Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) *
		transMat * scaleMat * rotMat * 
		Matrix4f:ScaleMat(filter.imageTex:width() * 0.5, filter.imageTex:height() * 0.5, 1) * mirrorMat

    -- filter.context:bindFBO(texTemp:toOFTexture())
    filter:drawFrame(filter.context, nil, outTex, mvpMat)
end
return MirrorFlip