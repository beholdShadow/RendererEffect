local HeartJump = {
    duration = 1000,
    timestamp = 0,
    imageTex = nil,
    imageScale = 0.25,
    spriteTimeOffsets = { -0.08, -0.06, -0.04, -0.02, 0 },
    spriteAlphas = { 0.2, 0.3, 0.5, 0.7, 1.0 },
    spriteBlurSteps = { 16, 12, 8, 4, 0 },
    vs = [[
        precision highp float;
        uniform mat4 uMVP;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTexCoord;

        void main()
        {
            gl_Position = uMVP * aPosition;
            vTexCoord = aTextureCoord.xy;
        }
        ]],
    fs = [[
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform float uAlpha;

        void main()
        {
            vec4 color = texture2D(uTexture0, vTexCoord);
            gl_FragColor = vec4(color.rgb, color.a * uAlpha);
        }
        ]],
    renderPass = nil,
}

function HeartJump:init(filter)
    local currentDir = debug.getinfo(1).source:match("@?(.*/)")
    local imagePath = currentDir .. "kiss.png"
    self.imageTex = filter.context:loadTextureFromFile(imagePath, TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
    OF_LOGI("HeartJump Animation", "HeartJump createCustomShaderPass")
end

function HeartJump:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end

    if self.imageTex ~= nil then
        filter.context:destroyTexture(self.imageTex)
        self.imageTex = nil
    end
end

function HeartJump:setDuration(filter, duration)
    self.duration = duration
end

function HeartJump:seek(filter, timestamp)
    self.timestamp = timestamp
end

function HeartJump:renderImage(filter, context, outTex, x, y, rot, scale, alpha)
    context:bindFBO(outTex)
    context:setViewport(0, 0, outTex.width, outTex.height)
    context:setBlend(true)
    context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ZERO, RS_BlendFunc_ONE)

    local frameWidth, frameHeight = outTex.width, outTex.height
    local heartWidth, heartHeight = self.imageTex:width(), self.imageTex:height()

    local label = filter.label
    local textWidth, textHeight = label.lineInfo.maxLineWidth, label.lineInfo.totalHeight
    local anchorMat = Matrix4f:TransMat(-label.lineInfo.x - textWidth / 2, label.lineInfo.y - textHeight / 2, 0.0)
    local textScaleMat = Matrix4f:ScaleMat(label.textScaleX, label.textScaleY, 1.0)
    local textRotMat = Matrix4f:RotMat(0, 0, label.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(label.textTransX, label.textTransY, 0.0)

    local mvpMat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
        * textTransMat * textRotMat * textScaleMat
        * anchorMat
        * Matrix4f:TransMat(x, y, 0)
        * Matrix4f:RotMat(0, 0, rot * math.pi / 180)
        * Matrix4f:ScaleMat(0.5 * heartWidth * scale, 0.5 * heartHeight * scale, 1.0)

    self.renderPass:use()
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)
    self.renderPass:setUniform1f("uAlpha", alpha)
    self.renderPass:setUniformTexture("uTexture0", 0, self.imageTex:textureID(), TEXTURE_2D)

    local quadRender = context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)
end

function HeartJump:calcImageTransform(chars, t)
    local charCount = #chars
	local charT = 1.0 / (charCount + 0.5)
	local index = math.floor(t / charT)
	local localT = (t % charT) / charT

    local c = nil
	if index < charCount then
		c = chars[index + 1]
	else
		c = chars[charCount]
	end

    if c == nil then
        return { x = -9999, y = -9999, deg = 0 }
    end

    local width, height = math.abs(c.pos[1] - c.pos[3]), math.abs(c.pos[2] - c.pos[6])
    local position = { x = 0.5 * (c.pos[1] + c.pos[3]), y = -0.5 * (c.pos[2] + c.pos[6]) }

    -- compute x
    local beginX = position.x - width / 2
	local centerX = position.x
	local endX = position.x + width / 2
	if index > 1 then
		local prev = chars[index]
        local prevPosition = { x = 0.5 * (prev.pos[1] + prev.pos[3]), y = -0.5 * (prev.pos[2] + prev.pos[6]) }
		beginX = (centerX + prevPosition.x) / 2
	end
	if index < charCount - 1 then
		local next = chars[index + 2]
        local nextPosition = { x = 0.5 * (next.pos[1] + next.pos[3]), y = -0.5 * (next.pos[2] + next.pos[6]) }
		endX = (centerX + nextPosition.x) / 2
	end
	if index == charCount then
		beginX = position.x + width / 2
		centerX = position.x + width
		endX = position.x + width * 3 / 2
	end

	local x = centerX
	if localT < 0.5 then
		x = beginX + (centerX - beginX) * localT * 2
	else
		x = centerX + (endX - centerX) * (localT - 0.5) * 2
	end

    -- compute y
    local spriteH = self.imageTex:height() * self.imageScale
    local spriteTopY = 2
	local localMirrorT = localT
	local posY = position.y
	local beginY = posY - spriteH * spriteTopY
	local endY = posY - height * 0.3 - spriteH * 0.5
	if localT > 0.5 then
		localMirrorT = 1.0 - localT
	else
		if index > 1 then
			local prev = chars[index]
            local prevPosition = { x = 0.5 * (prev.pos[1] + prev.pos[3]), y = -0.5 * (prev.pos[2] + prev.pos[6]) }
			local prevY = prevPosition.y
			beginY = prevY - spriteH * spriteTopY
		end
	end
	local a = 2 * (endY - beginY) / (0.5 * 0.5)
	local y = beginY + 0.5 * a * localMirrorT * localMirrorT

    -- compute rot
    local spriteRotateSpeed = 250
	local deg = spriteRotateSpeed * t * self.duration / 1000

    return { x = x, y = y, deg = deg }
end

function HeartJump:apply(filter, outTex)
    if #filter.label.chars <= 0 then
        return
    end

    local t = self.timestamp / self.duration
	for i = 1, #self.spriteTimeOffsets do
        local ret = self.calcImageTransform(self, 
                                            filter.label.charsBackup,
                                            t + self.spriteTimeOffsets[i])
        self.renderImage(self, 
                        filter, 
                        filter.context, 
                        outTex,
                        ret.x, 
                        ret.y, 
                        ret.deg,
                        self.imageScale,
                        self.spriteAlphas[i])
    end

    local count = #filter.label.charsBackup
    local percent = self.timestamp / self.duration
    local onePercent = 1/count
    local lastCharBegin = onePercent / 2
    for i = 1, count do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]

        local cPercent = 0
        local cBegin = lastCharBegin
        local cEnd = onePercent + lastCharBegin
        if percent >= cBegin and percent <= cEnd then
            cPercent = (percent - cBegin) / onePercent
        end

        local yOffset = 0
        if cPercent > 0 then
            yOffset = -(1 - cPercent) * 20
        end

        for n = 2, 8, 2 do
            if n < 6 then
                char.pos[n] = charBackup.pos[n] + yOffset * 1.7
            else
                char.pos[n] = charBackup.pos[n] + yOffset * 0.3
            end
        end
        lastCharBegin = cEnd
    end
end

return HeartJump