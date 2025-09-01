TAG = "OF-Frames"
OF_LOGI(TAG, "Call Label lua script!")

Frames = {
	imageNames = {},
	textureSheet = nil,
	svga = nil,
	svgaTex = nil,
	svgaPath = "",
	interval = 30,
	context = nil,
}

function Frames:initParams(context, filter)
	OF_LOGI(TAG, "call initParams")
	filter:insertResArrParam("Images", OF_ResType_Image)
	filter:insertResParam("SVGA", OF_ResType_SVGA, "")
	filter:insertIntParam("Interval", 1, 1000, 50)
	return OF_Result_Success
end

function Frames:onApplyParams(context, filter)
	OF_LOGI(TAG, "call onApplyParams")
	self.interval = filter:intParam("Interval")
	self.loadResource(self, context, filter, false)
	return OF_Result_Success
end

function Frames:isSame(list1, list2)
	if #list1 ~= #list2 then return false end
	for i = 1, #list2 do
		if list1[i] ~= list2[i] then
			return false
		end
	end
	return true
end

function Frames:loadResource(context, filter, preload)
	OF_LOGI(TAG, string.format("call Frames:loadResource %s", tostring(preload)))

	local images = filter:resArrParam("Images")
	if self.isSame(self, images, self.imageNames) == false then
		if #images > 0 then
			self.imageNames = images
			if self.textureSheet then
				context:destroyTextureSheet(self.textureSheet)
				self.textureSheet = nil
			end
			self.textureSheet = context:createTextureSheet()
			self.textureSheet:load(images, filter:resDir(), 50, false)
			OF_LOGI(TAG, "create and load texture sheet")

			if preload then
				local cnt = self.textureSheet:frames()
				for i = 1, cnt do
					self.textureSheet:frame(i-1)
				end
			end
		else
			if self.textureSheet then
				context:destroyTextureSheet(self.textureSheet)
				self.textureSheet = nil
			end
		end
	end

	local path = filter:resParam("SVGA")
	if self.svgaPath ~= path then
		self.svgaPath = path
		if path ~= "" then
			if self.svga then
				context:destroySVGA(self.svga)
				self.svga = nil
			end
			self.svga = context:createSVGAFromFile(filter:resFullPath(path), filter:resDir(), preload)
			if preload then
				repeat
					context:destroyGame(0) -- invoke applyPerformFunctions
					OF_LOGI(TAG, "Ignore this error log")
				until self.svga:isLoaded()
			end
			OF_LOGI(TAG, "create and load svga file")
		else
			if self.svga then
				context:destroySVGA(self.svga)
				self.svga = nil
			end
		end
	end
end

function Frames:initRenderer(context, filter)
	OF_LOGI(TAG, "call initRenderer")
	self.context = context
	return OF_Result_Success
end

function Frames:teardownRenderer(context, filter)
	OF_LOGI(TAG, "call teardownRenderer")

	if self.textureSheet then
		context:destroyTextureSheet(self.textureSheet)
		self.textureSheet = nil
	end

	if self.svga then
		context:destroySVGA(self.svga)
		self.svga = nil
	end

	if self.svgaTex then
		context:releaseTexture(self.svgaTex)
		self.svgaTex = nil
	end
	return OF_Result_Success
end

function Frames:getTexture(timestamp)
	if self.textureSheet then
		local count = self.textureSheet:frames()
		local duration = count * self.interval
		local frameIdx = math.floor((timestamp % duration) / duration * count)
		--print("Frames:getTexture", timestamp % duration, duration, count, frameIdx)
		return self.textureSheet:frame(frameIdx)
	elseif self.svga then
		local svgaWidth, svgaHeight = self.svga:viewWidth(), self.svga:viewHeight()
		if self.svgaTex == nil then
			self.svgaTex = self.context:getTexture(svgaWidth, svgaHeight)
		end

		if self.svga:isLoaded() == false then
			self.context:bindFBO(self.svgaTex:toOFTexture())
			self.context:setClearColor(0.0, 0.0, 0.0, 0.0)
			self.context:clearColorBuffer()
		end

		local count = self.svga:frames()
		local duration = count * self.interval
		local frameIdx = math.floor((timestamp % duration) / duration * count)
		self.svga:applyRGBA(self.svgaTex:toOFTexture(), frameIdx)
		return self.svgaTex
	end
end

function Frames:count()
	return self.textureSheet:frames()
end

return Frames