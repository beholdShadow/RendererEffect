--   2021/09/22 : add more animation params

TAG = "OrangeFilter-Sticker"
OF_LOGI(TAG, "Call Sticker lua script!")
local Config = require "config"

local Filter = {
    name = "sticker",
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
		uniform sampler2D uTexture0;
		uniform vec4 uColor;
		uniform float uTileX;
		uniform float uTileY;
		uniform float uAnimFPS;
		uniform float uTimestamp;
		uniform int uFrameCount;
		uniform int uVertical;
        varying vec2 vTexCoord;

        void main()
        {
			vec2 uv = vTexCoord;
            int idx = int(mod(uTimestamp * uAnimFPS / 1000.0, float(uFrameCount)));
			int rowIdx = 0;
			int colIdx = 0;

			if (uVertical == 1)
			{
				colIdx = int(mod(float(idx) / uTileY, uTileX));
				rowIdx = int(mod(float(idx), uTileY));
			}
			else
			{
				rowIdx = int(mod(float(idx) / uTileX, uTileY));
				colIdx = int(mod(float(idx), uTileX));
			}

			uv.x = uv.x / uTileX + float(colIdx) / uTileX;
			uv.y = uv.y / uTileY + float(rowIdx) / uTileY;

			gl_FragColor = texture2D(uTexture0, uv) * uColor;
        }
        ]],

	renderPass = nil,
	imageTex = nil,
	imagePath = "",
	duration = 10,
	params = { tx = 0, ty = 0, rot = 0, scale = 1,
				scaleX = 1, scaleY = 1, 
				tileX = 1,
				tileY = 1,
				widthRatio = 0.25, outWidth = 0},
	fSetParamsByMsg = false,
	animation = {
		enter_animation = nil, enter_duration = 1,
		exit_animation = nil, exit_duration = 1,
		loop_animation = nil, loop_duration = 1,
		params = {
			alpha = 1.0,
			position = { 0, 0, 0 },
			scale = { 1.0, 1.0, 1.0 },
			rotation = { 0.0, 0.0, 0.0 },
			localPosition = { 0, 0, 0 },
			localScale = { 1.0, 1.0, 1.0 },
			localRotation = { 0.0, 0.0, 0.0 },
			localTRSMat = nil
		}
	},

	dirty = false
}

function Filter:initParams(context, filter)
	OF_LOGI(TAG, "call initParams")
	filter:insertResParam("Image", OF_ResType_Image, "")
	filter:insertIntParam("TileX", 1, 20, 1)
	filter:insertIntParam("TileY", 1, 20, 1)
	filter:insertIntParam("FrameCount", 0, 100, 0)
	filter:insertBoolParam("Vertical", false)
	filter:insertIntParam("FPS", 1, 60, 30)
	filter:insertFloatParam("TransX", -10000, 10000, 0)
	filter:insertFloatParam("TransY", -10000, 10000, 0)
	filter:insertFloatParam("Rotate", -180, 180, 0)
	filter:insertFloatParam("Scale", 0.001, 10, 1.0)	
	filter:insertFloatParam("ScaleX", 0.001, 10, 1.0)
    filter:insertFloatParam("ScaleY", 0.001, 10, 1.0)
	filter:insertFloatParam("Width", 0.0, 1.0, 0.25)

	filter:insertEnumParam("EnterAnim", 0, Config.enter_animation)
	filter:insertStringParam("EnterAnimDir", "")
	filter:insertFloatParam("EnterAnimDuration", 0, 10, 1)

	filter:insertEnumParam("ExitAnim", 0, Config.exit_animation)
	filter:insertStringParam("ExitAnimDir", "")
	filter:insertFloatParam("ExitAnimDuration", 0, 10, 1)

	filter:insertEnumParam("LoopAnim", 0, Config.loop_animation)
	filter:insertStringParam("LoopAnimDir", "")
	filter:insertFloatParam("LoopAnimDuration", 0, 10, 1)
	return OF_Result_Success
end

function Filter:onApplyParams(context, filter)
	OF_LOGI(TAG, "call onApplyParams")
	local path = filter:resParam("Image")
	if self.imagePath ~= path then
		self.imagePath = path
		local fullpath = filter:resFullPath(path)
		OF_LOGI(TAG, fullpath)
		if self.imageTex then context:destroyTexture(self.imageTex) end -- destroy if exist
		self.imageTex = context:loadTextureFromFile(fullpath, TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)
	end
	if self.fSetParamsByMsg == false then
		self.params.tx = filter:floatParam("TransX")
		self.params.ty = filter:floatParam("TransY")
		self.params.rot = filter:floatParam("Rotate") * math.pi / 180
		self.params.scale = filter:floatParam("Scale")
		self.params.scaleX = filter:floatParam("Scale") * filter:floatParam("ScaleX")
		self.params.scaleY = filter:floatParam("Scale") * filter:floatParam("ScaleY")
		self.params.tileX = filter:intParam("TileX")
		self.params.tileY = filter:intParam("TileY")
		self.params.widthRatio = filter:floatParam("Width")
	end

	local idx =  filter:enumParam("EnterAnim") + 1
	local name = Config.enter_animation[idx]
	local effect_dir = filter:stringParam("EnterAnimDir")
	local enterAnimPath = filter:filterDir() .. "/../enter_animation/" .. name .. "/" .. name .. ".lua"
	if string.len(effect_dir) > 0 then
		local s = context:loadTextFromFile(effect_dir .. "/config.json")
		local tab = Json.JsonToTable(s)
		enterAnimPath = effect_dir .. "/" .. tab.script
	end
	if idx > 1 or string.len(effect_dir) > 0 then -- not none
		self.animation.enter_animation = dofile(enterAnimPath)
		self.animation.enter_duration = filter:floatParam("EnterAnimDuration") * 1000
		self.animation.enter_animation:setDuration(self, self.animation.enter_duration)
	else
		self.animation.enter_animation = nil
	end

	idx =  filter:enumParam("ExitAnim") + 1
	name = Config.exit_animation[idx]
	effect_dir = filter:stringParam("ExitAnimDir")
	local exitAnimPath = filter:filterDir() .. "/../exit_animation/" .. name .. "/" .. name .. ".lua"
	if string.len(effect_dir) > 0 then
		local s = context:loadTextFromFile(effect_dir .. "/config.json")
		local tab = Json.JsonToTable(s)
		exitAnimPath = effect_dir .. "/" .. tab.script
	end
	if idx > 1 or string.len(effect_dir) > 0 then -- not none
		self.animation.exit_animation = dofile(exitAnimPath)
		self.animation.exit_duration = filter:floatParam("ExitAnimDuration") * 1000
		self.animation.exit_animation:setDuration(self, self.animation.exit_duration)
	else
		self.animation.exit_animation = nil
	end

	idx =  filter:enumParam("LoopAnim") + 1
	name = Config.loop_animation[idx]
	effect_dir = filter:stringParam("LoopAnimDir")
	local loopAnimPath = filter:filterDir() .. "/../loop_animation/" .. name .. "/" .. name .. ".lua"
	if string.len(effect_dir) > 0 then
		local s = context:loadTextFromFile(effect_dir .. "/config.json")
		local tab = Json.JsonToTable(s)
		loopAnimPath = effect_dir .. "/" .. tab.script
	end
	if idx > 1 or string.len(effect_dir) > 0 then -- not none
		self.animation.loop_animation = dofile(loopAnimPath)
		self.animation.loop_duration = filter:floatParam("LoopAnimDuration") * 1000
		self.animation.loop_animation:setDuration(self, self.animation.loop_duration)
	else
		self.animation.loop_animation = nil
	end

	return OF_Result_Success
end

function Filter:initRenderer(context, filter)
	OF_LOGI(TAG, "call initRenderer")
	self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
	return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
	OF_LOGI(TAG, "call teardownRenderer")
	context:destroyCustomShaderPass(self.renderPass)
	if self.imageTex then context:destroyTexture(self.imageTex) end -- destroy if exist
	return OF_Result_Success
end

function Filter:seek(filter, timestamp)
	self.animation.params = {
		alpha = 1.0,
		position = { 0, 0, 0 },
		scale = { 1.0, 1.0, 1.0 },
		rotation = { 0.0, 0.0, 0.0 },
		localPosition = { 0, 0, 0 },
		localScale = { 1.0, 1.0, 1.0 },
		localRotation = { 0.0, 0.0, 0.0 },
		localTRSMat = Matrix4f:ScaleMat(1.0, 1.0, 1.0)
	}

	if self.animation.loop_animation then
		self.animation.loop_animation:seek(self, timestamp)
		self.animation.loop_animation:apply(self)
		return
	else
		if self.animation.enter_animation and timestamp < self.animation.enter_duration then
			self.animation.enter_animation:seek(self, timestamp)
			self.animation.enter_animation:apply(self)
			return
		end

		local exitTime = filter:duration() * 1000 - self.animation.exit_duration
		if self.animation.exit_animation and timestamp > exitTime then
			self.animation.exit_animation:seek(self, timestamp - exitTime)
			self.animation.exit_animation:apply(self)
			return
		end
	end

	return
end

function Filter:applyRGBA(context, filter, frameData, inTex, outTex, debugTex)
    local width = outTex.width
	local height = outTex.height
	local timestamp = filter:filterTimestamp() * 1000
	self.params.outWidth = width
	self.seek(self, filter, timestamp)

	context:copyTexture(inTex, outTex)

	if self.imageTex == nil then
		return OF_Result_Failed
	end

	local tileX = filter:intParam("TileX")
	local tileY = filter:intParam("TileY")
	local widthRatio = filter:floatParam("Width")
	local frameCount = filter:intParam("FrameCount")
	local vertical = 0
	if filter:boolParam("Vertical") then
		vertical = 1
	end
	local imageWidth = self.imageTex:width() / tileX
	local imageHeight = self.imageTex:height() / tileY
	if frameCount == 0 then
		frameCount = tileX * tileY
	end

	context:bindFBO(outTex)
	context:setViewport(0, 0, width, height)
	context:setBlend(true)
	context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)

	local scaleMat = Matrix4f:ScaleMat(self.params.scaleX, self.params.scaleY, 1.0)
	local rotMat = Matrix4f:RotMat(0, 0, self.params.rot)
	local transMat = Matrix4f:TransMat(self.params.tx, self.params.ty, 0.0)

	local animLocalTransMat = Matrix4f:TransMat(
		self.animation.params.localPosition[1], self.animation.params.localPosition[2],
		self.animation.params.localPosition[3])
	local animLocalScaleMat = Matrix4f:ScaleMat(
		self.animation.params.localScale[1], self.animation.params.localScale[2],
		self.animation.params.localScale[3])
	local animLocalRotMat = Matrix4f:RotMat(
		self.animation.params.localRotation[1], self.animation.params.localRotation[2],
		self.animation.params.localRotation[3])

	local animTransMat = Matrix4f:TransMat(
		self.animation.params.position[1], self.animation.params.position[2], self.animation.params.position[3])
	local animScaleMat = Matrix4f:ScaleMat(
		self.animation.params.scale[1], self.animation.params.scale[2],	self.animation.params.scale[3])
	local animRotMat = Matrix4f:RotMat(
		self.animation.params.rotation[1], self.animation.params.rotation[2], self.animation.params.rotation[3])

	local autoFitScale = widthRatio * width / imageWidth
	local mvpMat =
		Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) *
		animTransMat * transMat *
		animRotMat * rotMat *
		animScaleMat * scaleMat *
		animLocalTransMat * animLocalRotMat * animLocalScaleMat * 
		self.animation.params.localTRSMat *
		Matrix4f:ScaleMat(imageWidth * autoFitScale * 0.5, imageHeight * autoFitScale * 0.5, 1)

	self.renderPass:use()
	self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)
	self.renderPass:setUniformTexture("uTexture0", 0, self.imageTex:textureID(), TEXTURE_2D)
	self.renderPass:setUniform1f("uTileX", tileX)
	self.renderPass:setUniform1f("uTileY", tileY)
	self.renderPass:setUniform1f("uAnimFPS", filter:intParam("FPS"))
	self.renderPass:setUniform1f("uTimestamp", math.floor(timestamp))
	self.renderPass:setUniform4f("uColor", 1.0, 1.0, 1.0, self.animation.params.alpha)
	self.renderPass:setUniform1i("uFrameCount", frameCount)
	self.renderPass:setUniform1i("uVertical", vertical)
	
	local quadRender = context:sharedQuadRender()
	quadRender:draw(self.renderPass, false)

	if self.dirty then
		local jsonStr = Json.TableToJson({
			id = 200,
			size = { imageWidth * autoFitScale, imageHeight * autoFitScale},
			params = { self.params.tx, self.params.ty, self.params.rot, self.params.scaleX, self.params.scaleY }
		})
		filter:sendMessageBack(jsonStr)

		OF_LOGI(TAG, jsonStr)
		
		self.dirty = false;
	end

	if debugTex ~= nil then
		context:copyTexture(inTex, debugTex)
	end

	return OF_Result_Success
end

function Filter:requiredFrameData(context, game)
	return { OF_RequiredFrameData_None }
end

function Filter:readObject(context, filter, archiveIn)
	OF_LOGI(TAG, "call readObject")
	return OF_Result_Success
end

function Filter:writeObject(context, filter, archiveOut)
	OF_LOGI(TAG, "call writeObject")
	return OF_Result_Success
end

function Filter:onReceiveMessage(context, filter, msg)
	OF_LOGI(TAG, string.format("call onReceiveMessage %s", msg))
	local evt = Json.JsonToTable(msg)
	if evt.id == 1 then
		self.fSetParamsByMsg = true
		self.params.tx = evt.params[1]
		self.params.ty = evt.params[2]
		self.params.scale = evt.params[3]
		self.params.rot = evt.params[4] * math.pi / 180
	elseif evt.id == 2 then
		OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
		if string.len(evt.effect_dir) > 0 then
			local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
			local tab = Json.JsonToTable(s)
			self.animation.enter_animation = dofile(evt.effect_dir .. "/" .. tab.script)
			self.animation.enter_duration = evt.duration * 1000
			self.animation.enter_animation:setDuration(self.animation.enter_duration)
		else
			self.animation.enter_animation = nil
		end
	elseif evt.id == 3 then
		OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
		if string.len(evt.effect_dir) > 0 then
			local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
			local tab = Json.JsonToTable(s)
			self.animation.exit_animation = dofile(evt.effect_dir .. "/" .. tab.script)
			self.animation.exit_duration = evt.duration * 1000
			self.animation.exit_animation:setDuration(self.animation.exit_duration)
		else
			self.animation.exit_animation = nil
		end
	elseif evt.id == 4 then
		OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
		if string.len(evt.effect_dir) > 0 then
			local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
			local tab = Json.JsonToTable(s)
			self.animation.loop_animation = dofile(evt.effect_dir .. "/" .. tab.script)
			self.animation.loop_duration = evt.duration * 1000
			self.animation.loop_animation:setDuration(self.animation.loop_duration)
		else
			self.animation.loop_animation = nil
		end
	elseif evt.id == 99 then	
		self.dirty = true
	end
	return ""
end

return Filter

