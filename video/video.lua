-- Change history:
--   2021/04/20 : Optimize.
--   2021/09/17 : add renderToRT in animation.
--   2021/09/27 : fix video texture reuse bug
--   2022/09/19 : fix internal crop bug
TAG = "OrangeFilter-Video"
OF_LOGI(TAG, "Call Video lua script!")
local EffectList = require "sub.effectlist"
local AnimationMgr = require "sub.animation"
local CropRender = require "sub.crop"
local MotionBlurRender = require "common.motion_blur"
local DynamicCollage = require "common.dynamic_collage"
local TextureRender = require "common.texture"

local Filter = {
    name = "video",
    
	imageTex = nil,
	bgTexOF = nil,
	duration = 10,
	context = nil,
	params = {
		tx = 0, ty = 0, rot = 0, scale = 1,
		scaleX = 1,
		scaleY = 1,
		fourCornerMat = Matrix4f.new(),
		rotX = 0, rotY = 0,
		opacity = 100,
		color = nil
		},
	fSetParamsByMsg = false,

	animation = AnimationMgr,
	
	motionBlur = false,

	timestamp = 0,
	debug = 0.0,
	
	camera3D = {
		enable = false,
		zPos = 0
	}
}

function Filter:initParams(context, filter)
	OF_LOGI(TAG, "call initParams")
	filter:insertBoolParam("Camera3D", true)

	filter:insertFloatParam("TransX", -10000, 10000, 0)
	filter:insertFloatParam("TransY", -10000, 10000, 0)
	filter:insertFloatParam("Rotate", -180, 180, 0)
	filter:insertFloatParam("RotateX", -180, 180, 0)
	filter:insertFloatParam("RotateY", -180, 180, 0)
	filter:insertFloatParam("Scale", 0.001, 10, 1.0)
	filter:insertFloatParam("ScaleX", 0.001, 10, 1.0)
    filter:insertFloatParam("ScaleY", 0.001, 10, 1.0)

	if filter.insertFloatArrayParam then  -- version compatible
		filter:insertFloatArrayParam("FourCornerMat", Matrix4f.new().x)
	end
    filter:insertIntParam("Opacity", 0, 100, 100)

    filter:insertBoolParam("MotionBlur", false)
	
	DynamicCollage:initParams(context, filter)

	TextureRender:initParams(context, filter)
	
	AnimationMgr:initParams(context, filter)

	CropRender:initParams(context, filter)

	filter:insertFloatParam("debug", 0, 0.2, 0)


	EffectList:initParams(context, filter)

	return OF_Result_Success
end

function Filter:onApplyParams(context, filter, dirtyTable)
	OF_LOGI(TAG, "call onApplyParams")
	if self.fSetParamsByMsg == false then
		self.params.tx = filter:floatParam("TransX")
		self.params.ty = filter:floatParam("TransY")
		self.params.rot = filter:floatParam("Rotate") * math.pi / 180
		self.params.rotX = filter:floatParam("RotateX") * math.pi / 180
		self.params.rotY = filter:floatParam("RotateY") * math.pi / 180
		self.params.scale = 1.0
		self.params.scaleX = filter:floatParam("ScaleX") * filter:floatParam("Scale")
		self.params.scaleY = filter:floatParam("ScaleY") * filter:floatParam("Scale")
		self.camera3D.enable = filter:boolParam("Camera3D")
	end
	
	if filter.floatArrayParam then -- version compatible
		self.params.fourCornerMat = Matrix4f.new(filter:floatArrayParam("FourCornerMat"))
	end
	self.debug = filter:floatParam("debug")
	
	self.params.opacity = filter:intParam("Opacity")
	self.params.color = filter:colorParam("Color")
	self.motionBlur = filter:boolParam("MotionBlur")
	--AnimationMgr
	AnimationMgr:loadFromFilter(context, filter)
	TextureRender:onApplyParams(context, filter)
	
	EffectList:onApplyParams(context, filter)

	CropRender:onApplyParams(context, filter, dirtyTable)

	DynamicCollage:onApplyParams(context, filter, dirtyTable)

	return OF_Result_Success
end

function Filter:initRenderer(context, filter)
	OF_LOGI(TAG, "call initRenderer")
	self.context = context
	DynamicCollage:initRenderer(context, filter)
	MotionBlurRender:initRenderer(context, filter)
	MotionBlurRender:setLayerMotion(true)
	TextureRender:initRenderer(context, filter)
	CropRender:initRenderer(context, filter)
	return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
	OF_LOGI(TAG, "call teardownRenderer")
	DynamicCollage:teardown(context, filter)
	MotionBlurRender:teardown(context, filter)
	TextureRender:teardown(context)
	CropRender:teardown(context, filter)
	if self.imageTex then 
		context:releaseTexture(self.imageTex) 
		self.imageTex = nil
	end -- destroy if exist
	
	EffectList:clear(context)

	AnimationMgr:clear(context)

	return OF_Result_Success
end

function Filter:drawFrame(context, baseTex, outTex, mvpMat)
	context:setBlend(false)	

	local inTex = self.imageTex:toOFTexture()

	local tempTexOF, tempTex = outTex, nil
	if self.motionBlur then
		tempTex = context:getTexture(PixelSize.new(outTex.width, outTex.height, outTex.pixelScale))
		tempTexOF = tempTex:toOFTexture()
	end

	TextureRender:setColor(Vec4f.new(1.0, 1.0, 1.0, 0.0))
	TextureRender:draw(context, self.bgTexOF, tempTexOF, Matrix4f.new())

	TextureRender:setColor(Vec4f.new(self.params.color.x, self.params.color.y, self.params.color.z, self.params.color.w * AnimationMgr.params.alpha * self.params.opacity / 100))
	if self.params.rot ~= 0 then
		TextureRender:drawAntiAlias(context, self.bgTexOF, inTex, tempTexOF, mvpMat)
	else
		TextureRender:draw(context, inTex, tempTexOF, mvpMat, true)
	end
	
	if self.motionBlur then
		MotionBlurRender:draw(context, tempTexOF, outTex, mvpMat)
	end

	if tempTex then context:releaseTexture(tempTex) end
end

function Filter:renderToOutputDirectly(context, filter, outTex)
	local width, height = outTex.width, outTex.height

	local scaleMat = Matrix4f:ScaleMat(self.params.scaleX * self.params.scale, self.params.scaleY * self.params.scale, 0.0)
	local rotMat = Matrix4f:RotMat(0, 0, self.params.rot)
	local transMat = Matrix4f:TransMat(self.params.tx, self.params.ty, 0.0)
	
	local animateMat = AnimationMgr:getMatrix();

	local mvpMat = nil
	if self.camera3D.enable then	
		local viewMat = Matrix4f:LookAtMat(Vec3f.new(0.0, 0.0, self.camera3D.zPos), Vec3f.new(0.0, 0.0, 0.0), Vec3f.new(0.0, 1.0, 0.0))
		local deltaZ = 2.0 * self.camera3D.zPos / outTex.height
		local projMat = Matrix4f:PerspectiveMat(math.atan(1.0 / deltaZ) / math.pi * 180 * 2, outTex.width / outTex.height, 0.01, 2.0 * self.camera3D.zPos) 
		local worldMat = self.params.fourCornerMat * 
				animateMat.transMat * transMat * 
				Matrix4f:RotMat(self.params.rotX, 0, 0) * Matrix4f:RotMat(0, self.params.rotY, 0) *
				animateMat.rotMat * rotMat *	
				animateMat.scaleMat * scaleMat *
				animateMat.localTransMat * animateMat.localRotMat * animateMat.localScaleMat *
				Matrix4f:ScaleMat(self.imageTex:width() * 0.5, self.imageTex:height() * 0.5, 1.0)	
		mvpMat = projMat * viewMat * worldMat
	else
		mvpMat = Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) * self.params.fourCornerMat * 
				animateMat.transMat * transMat * 
				animateMat.rotMat * rotMat *	
				animateMat.scaleMat * scaleMat *
				animateMat.localTransMat * animateMat.localRotMat * animateMat.localScaleMat *
				Matrix4f:ScaleMat(self.imageTex:width() * 0.5, self.imageTex:height() * 0.5, 1.0)
	end
	-- OF_LOGI(TAG, string.format("renderToOutputDirectly mvpMat: %s", mvpMat))
	self.drawFrame(self, context, nil, outTex, mvpMat)
end

function Filter:renderThroughRT(context, filter, outTex)
	AnimationMgr:apply(self, filter, outTex)
end

function Filter:applyFrame(context, filter, frameData, inTexArray, outTexArray)	
	if inTexArray[2] == nil then
        context:copyTexture(inTexArray[1], outTexArray[1])
        return OF_Result_Success
    end

	local pixelScale = outTexArray[1].pixelScale

	self.bgTexOF = {
		textureID = inTexArray[1].textureID,
		width = outTexArray[1].width,
		height = outTexArray[1].height
	}

	--
	-- apply extra effects to inTexArray[2]
	--
	local imageTexOF = context:createTextureRef(inTexArray[2]):toOFTexture()
	imageTexOF.pixelScale = pixelScale
	-- 统一合成的分辨率和预览设计的源分辨率，解决预览/合成的源的宽高不一致导致矩阵计算偏差问题
	imageTexOF.width = CropRender.sourceWidth
	imageTexOF.height = CropRender.sourceHeight
	local tempTex = context:getTexture(PixelSize.new(imageTexOF.width, imageTexOF.height, pixelScale))
	if not EffectList:isEmpty() then
		EffectList:apply(context, frameData, inTexArray[2], tempTex:toOFTexture(),
			outTexArray[2], filter:filterTimestamp())
		imageTexOF = tempTex:toOFTexture()
	end

	self.camera3D.zPos = math.max(imageTexOF.width * filter:floatParam("ScaleX") * filter:floatParam("Scale"), 
			imageTexOF.height * filter:floatParam("ScaleY") * filter:floatParam("Scale")) * 4
	
	local collageTex = nil
	if DynamicCollage:isEnabled() then
		local widthFactor = math.min(filter:floatParam("ScaleX") * filter:floatParam("Scale"), 1.0)
		local heightFactor = math.min(filter:floatParam("ScaleY") * filter:floatParam("Scale"), 1.0)
		local curFactor = math.min(widthFactor, heightFactor)
		self.params.scaleX = filter:floatParam("ScaleX") * filter:floatParam("Scale") / curFactor 
		self.params.scaleY = filter:floatParam("ScaleY") * filter:floatParam("Scale") / curFactor
		local collageUnit = {
			width = imageTexOF.width * (1.0 + DynamicCollage._spaceX),
			height = imageTexOF.height * (1.0 + DynamicCollage._spaceY)
		}
		local collageWidth = math.min(math.floor(collageUnit.width * DynamicCollage._width * curFactor + 0.5), 2048)
		local collageHeight = math.min(math.floor(collageUnit.height * DynamicCollage._height * curFactor + 0.5), 2048)
		collageTex = context:getTexture(PixelSize.new(collageWidth, collageHeight, pixelScale))
		local scale = Matrix4f:ScaleMat(collageWidth / collageUnit.width / curFactor, collageHeight / collageUnit.height / curFactor, 1.0)
		DynamicCollage:draw(context, imageTexOF, collageTex:toOFTexture(), scale)
		imageTexOF = collageTex:toOFTexture()
	end

	if self.imageTex ~= nil then context:releaseTexture(self.imageTex) end
	
	if CropRender:isEnabled() then
		self.imageTex = context:getTexture(PixelSize.new(CropRender.sourceWidth, CropRender.sourceHeight, pixelScale))
		local scaleMat = Matrix4f:ScaleMat(self.params.scaleX * self.params.scale, self.params.scaleY * self.params.scale, 1.0)
		local rotMat = Matrix4f:RotMat(0, 0, self.params.rot)
		local transMat = Matrix4f:TransMat(self.params.tx, self.params.ty, 0.0)
		local mvpMat = Matrix4f:ScaleMat(2 / outTexArray[1].width, 2 / outTexArray[1].height, 1.0 ) * 
			transMat * rotMat * scaleMat *
			Matrix4f:ScaleMat(CropRender.sourceWidth * 0.5, CropRender.sourceHeight * 0.5, 1.0)
		CropRender:draw(context, imageTexOF, self.imageTex:toOFTexture(), self.bgTexOF, mvpMat)
	else
		self.imageTex = context:createTextureRef(imageTexOF)
	end
	-- OF_LOGI(TAG, string.format("lua apply frame applyFrame imageTexOF.width: %d, imageTexOF.height: %d, imageTexOF.pixelScale: %f, outTexArray[1].scale: %f, outTexArray[1].width: %d, outTexArray[1].height: %d", 
		-- 	imageTexOF.width, imageTexOF.height,
		--  imageTexOF.pixelScale, outTexArray[1].pixelScale,
		-- 	outTexArray[1].width, outTexArray[1].height))
	AnimationMgr:seek(self, filter)

	if AnimationMgr.params.renderToRT then
		self.renderThroughRT(self, context, filter, outTexArray[1])
	else
		self.renderToOutputDirectly(self, context, filter, outTexArray[1])
	end

	-- debug tex
	if outTexArray[2] ~= nil then
		context:copyTexture(inTexArray[1], outTexArray[2])
	end

	if tempTex then context:releaseTexture(tempTex) end
	if collageTex then context:releaseTexture(collageTex) end
	return OF_Result_Success
end

function Filter:requiredFrameData(context, filter)
    if filter:intParam("ThinFace") > 0 then
        return { OF_RequiredFrameData_FaceLandmarker }
    else
		return { OF_RequiredFrameData_None }
    end
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
	else
		AnimationMgr:loadFromMsg(context, evt)
	end
	return ""
end

return Filter
