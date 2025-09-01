--change history
--   2021/09/28 : remove shadowBlurIntensity param
--   2022/10/12 : Remove labelpro MSDF codes, reduce sdf shader feather value.
--   2022/11/11 : fix auto alignment anchor offset

TAG = "OF-Text"
OF_LOGI(TAG, "Call text lua script!")

local Config = require "config"
local LabelPro = require('render2d.labelpro')
local BubbleRender = require('common.texture')
local tablex = require('pl.tablex')
local utils = require('pl.utils')
local path = require('pl.path')
local Filter = {
    name = "text",
    label = nil,
    opacity = 1.0,
    textTex = nil,
    textTexPath = "",
    commandList = {},
    seekFlag = 0,
    bubbleTex = nil,
    bubbleTexDir = "",
    bubbleTextRect = nil,
    flowerDir = "",
    flowerStyle = nil,
    frameWidth = 0,
    frameHeight = 0,
    context = nil,
    animation = {
        enter_animation = nil, enter_duration = 1,
        exit_animation = nil, exit_duration = 1,
        loop_animation = nil, loop_duration = 1,
        params = {
            colorAlpha1 = 1.0,
            outLine1Alpha = 1.0,
            outLine2Alpha = 1.0,
            outLine3Alpha = 1.0,
            shadowAplha = 1.0,
            backgroundAlpha = 1.0
        },
        text = ""
    }
}

function Filter:initParams(context, filter)
    OF_LOGI(TAG, "call initParams")

    self.label = LabelPro()
    self.label:initParams(context, filter)

    filter:insertEnumParam("EnterAnim", 0, Config.enter_animation)
	filter:insertStringParam("EnterAnimDir", "")
	filter:insertFloatParam("EnterAnimDuration", 0, 60.0, 1)

	filter:insertEnumParam("ExitAnim", 0, Config.exit_animation)
	filter:insertStringParam("ExitAnimDir", "")
	filter:insertFloatParam("ExitAnimDuration", 0, 60.0, 1)

	filter:insertEnumParam("LoopAnim", 0, Config.loop_animation)
	filter:insertStringParam("LoopAnimDir", "")
	filter:insertFloatParam("LoopAnimDuration", 0, 60.0, 1)

    filter:insertStringParam("BubbleDir", "")
    filter:insertStringParam("FlowerDir", "")

    return OF_Result_Success
end

function Filter:overwriteStyle(style, newStyle)
    if newStyle == nil then return end
    for k, v in pairs(newStyle) do
        if k == "color1" or k == "outline1Color1" or
           k == "outline2Color1" or k == "outline3Color1" or
           k == "shadowColor" then
            v = Vec4f.new(v[1], v[2], v[3], v[4])
        end

        if style[k] ~= nil then
            style[k] = v
        end
    end
end

function Filter:dumpStyle(style)
    for k, v in pairs(style) do
        print("", k, v)
    end
end

function Filter:onApplyParams(context, filter, dirtyTable)
    OF_LOGI(TAG, "call onApplyParams")
    self.opacity = filter:intParam("Opacity") / 100.0

    local imageFullPath = ""
    local flowerDir = filter:stringParam("FlowerDir")
    --local defaultPath = filter:resFullPath("flower/config.json")
    --if path.isfile(defaultPath) then
    --    flowerDir = filter:resFullPath("flower")
    --end

    if string.len(flowerDir) > 0 and self.flowerDir ~= flowerDir then
        local s = context:loadTextFromFile(flowerDir .. "/config.json")
        local style = Json.JsonToTable(s)
        if style.textureEnabled then
            imageFullPath = flowerDir .. "/" .. style.texture
        end
        self.flowerDir = flowerDir
		self.flowerStyle = style
    elseif string.len(flowerDir) == 0 then
        local path = filter:resParam("Texture")
        if string.len(path) > 0 then
            imageFullPath = filter:resFullPath(path)
        end
        self.flowerStyle = nil
    end

    if self.textTexPath ~= imageFullPath then
        self.textTexPath = imageFullPath

        if self.textTex ~= nil then
            context:destroyTexture(self.textTex)
        end
        self.textTex = context:loadTextureFromFile(imageFullPath,
                TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)
    end

    self.label:onApplyParams(context, filter, dirtyTable)

    local sdfStyle = self.label:getSdfStyle()
    
    sdfStyle.textureGL = self.textTex
    
    self.overwriteStyle(self, sdfStyle, self.flowerStyle)
    --self.dumpStyle(self, sdfStyle)
    
    self.animation.params.colorAlpha1 = sdfStyle.color1.w
    self.animation.params.outLine1Alpha = sdfStyle.outline1Color1.w
    self.animation.params.outLine2Alpha = sdfStyle.outline2Color1.w
    self.animation.params.outLine3Alpha = sdfStyle.outline3Color1.w
    self.animation.params.shadowAplha = sdfStyle.shadowColor.w
    self.animation.params.backgroundAlpha = self.label.backgroundColor.w
    if dirtyTable:isDirty("Text") then
        self.animation.text = filter:stringParam("Text") 
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
        if self.animation.enter_animation then
            self.animation.enter_animation:clear(self)
        end
		self.animation.enter_animation = dofile(enterAnimPath)
        self.animation.enter_animation:init(self)
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
        if self.animation.exit_animation then
            self.animation.exit_animation:clear(self)
        end
		self.animation.exit_animation = dofile(exitAnimPath)
        self.animation.exit_animation:init(self)
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
        if self.animation.loop_animation then
            self.animation.loop_animation:clear(self)
        end
		self.animation.loop_animation = dofile(loopAnimPath)
        self.animation.loop_animation:init(self)
		self.animation.loop_duration = filter:floatParam("LoopAnimDuration") * 1000
		self.animation.loop_animation:setDuration(self, self.animation.loop_duration)
	else
		self.animation.loop_animation = nil
	end

    local bubbleDir = filter:stringParam("BubbleDir")
    if string.len(bubbleDir) > 0 and self.bubbleTexDir ~= bubbleDir then
        self.bubbleTexDir = bubbleDir
        local configPath = bubbleDir .. "/" .. "config.json"
        local ctxt = context:loadTextFromFile(configPath)
        local tab = Json.JsonToTable(ctxt)

        self.bubbleTextRect = tab.textRect
        local imagePath = bubbleDir .. "/" .. tab.image

        if self.bubbleTex ~= nil then
            context:destroyTexture(self.bubbleTex)
        end
        self.bubbleTex = context:loadTextureFromFile(imagePath, TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)
    elseif string.len(bubbleDir) == 0 then
        self.bubbleTexDir = ""
        if self.bubbleTex ~= nil then
            context:destroyTexture(self.bubbleTex)
            self.bubbleTex = nil
        end
        self.label:setAutoScaleEnabled(false)
    end

    return OF_Result_Success
end

function Filter:initRenderer(context, filter)
    OF_LOGI(TAG, "call initRenderer")
    self.context = context
    self.label:initRenderer(context, filter)
    BubbleRender:initRenderer(context, filter)
    return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
    OF_LOGI(TAG, "call teardownRenderer")
    self.label:teardown(context)

    if self.textTex ~= nil then
        context:destroyTexture(self.textTex)
    end

    if self.bubbleTex ~= nil then
        context:destroyTexture(self.bubbleTex)
    end

    if BubbleRender ~= nil then
        BubbleRender:teardown(context)
    end

    if self.animation.enter_animation then
        self.animation.enter_animation:clear(self)
    end

    if self.animation.exit_animation then
        self.animation.exit_animation:clear(self)
    end

    if self.animation.loop_animation then
        self.animation.loop_animation:clear(self)
    end
    return OF_Result_Success
end

function Filter:processCommands(filter, outWidth, outHeight)
    self.dirty = self.label.dirty
    local cmdIndices = {}
    local cnt = #self.commandList
    for i = 1, cnt do
        local cmd = self.commandList[i]
        if cmd.id == 1 then
            self.label:setString(cmd.text)
            self.dirty = true
            table.insert(cmdIndices, i)
        elseif cmd.id == 2 then
            self.label.textTransX = cmd.params[1]
            self.label.textTransY = cmd.params[2]
            self.label.textScale = cmd.params[3]
            self.label.textRotate = cmd.params[4]
            table.insert(cmdIndices, i)
        elseif cmd.id == 3 then
            self.label:setFont(cmd.custom_font_path)
            self.label:setSystemFonts(cmd.system_font_dir, utils.split(cmd.system_font_names, ","))
            table.insert(cmdIndices, i)
        elseif cmd.id == 4 then
            local style = self.label:getSdfStyle()
            style.color1 = Vec4f.new(cmd.color[1]/255, cmd.color[2]/255, cmd.color[3]/255, cmd.alpha/100)
            self.label:setSdfStyle(style)
            table.insert(cmdIndices, i)
        elseif cmd.id == 5 then
            local style = self.label:getSdfStyle()
            style.outline1Enabled = cmd.enabled
            style.outline1Scale = 0.5 - cmd.thickness / 100 * 0.2
            style.outline1Color1 = Vec4f.new(cmd.color[1]/255, cmd.color[2]/255, cmd.color[3]/255, cmd.alpha/100)
            self.label:setSdfStyle(style)
            table.insert(cmdIndices, i)
        elseif cmd.id == 6 then
            self.label:setBackgroundEnabled(cmd.enabled)
            self.label:setBackgroundColor(Vec4f.new(cmd.color[1]/255, cmd.color[2]/255, cmd.color[3]/255, cmd.alpha/100))
            table.insert(cmdIndices, i)
        elseif cmd.id == 7 then
            local style = self.label:getSdfStyle()
            self.label:setShadowEnabled(cmd.enabled)
            style.shadowColor = Vec4f.new(cmd.color[1]/255, cmd.color[2]/255, cmd.color[3]/255, cmd.alpha/100)
            style.shadowBlurIntensity = 0.5 * (1.0 - cmd.blur / 100)
            style.shadowDistance = cmd.distance
            style.shadowAngle = cmd.angle
            table.insert(cmdIndices, i)
        elseif cmd.id == 8 then
            if cmd.alignment == 0 then
                self.label:setAlignment(0)
            elseif cmd.alignment == 1 then
                self.label:setAlignment(2)
            elseif cmd.alignment == 2 then
                self.label:setAlignment(1)
            end
            self.label:setSpacing(cmd.spacing)
            self.label:setLeading(cmd.leading)
            table.insert(cmdIndices, i)
        elseif cmd.id == 9 then
            self.label:setBoldEnabled(cmd.bold)
            table.insert(cmdIndices, i)
        elseif cmd.id == 99 then
            self.dirty = true
            table.insert(cmdIndices, i)
        end
    end

    for i = 1, #cmdIndices do
        table.remove(self.commandList, cmdIndices[#cmdIndices - i + 1])
    end

end

function Filter:applyAnimation(context, filter, outTex, timestamp)
	if self.animation.loop_animation then
		self.animation.loop_animation:seek(self, timestamp)
        self.label:setAnimation(context, self.animation.loop_animation, self.animation.params)
		self.animation.loop_animation:apply(self, outTex)
        self.label:generateMeshBatch(context)
		return
	else
		if self.animation.enter_animation and timestamp < self.animation.enter_duration then
			self.animation.enter_animation:seek(self, timestamp)
            self.label:setAnimation(context, self.animation.enter_animation, self.animation.params)
			self.animation.enter_animation:apply(self, outTex)
            self.label:generateMeshBatch(context)
			return
		end

		local exitTime = filter:duration() * 1000 - self.animation.exit_duration
		if self.animation.exit_animation and timestamp > exitTime then
			self.animation.exit_animation:seek(self, timestamp - exitTime)
            self.label:setAnimation(context, self.animation.exit_animation, self.animation.params)
			self.animation.exit_animation:apply(self, outTex)
            self.label:generateMeshBatch(context)
			return
		end
	end
    
    self.label:setAnimation(context, nil, self.animation.params)
end

function Filter:calcTextSize(scale)
    local textWidth, textHeight = self.bubbleTextRect[3] - 10, self.bubbleTextRect[4] - 10
    return textWidth * scale / self.frameWidth, textHeight * scale / self.frameHeight
end

function Filter:renderBubble(context, filter, outTex)
    if self.bubbleTex == nil then return end

    local textScaleMat = Matrix4f:ScaleMat(self.label.textScale, self.label.textScale, 1.0)
    local textRotMat = Matrix4f:RotMat(0, 0, self.label.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(self.label.textTransX, self.label.textTransY, 0.0)
    local mvpMat = Matrix4f:ScaleMat(2 / outTex.width, 2 / outTex.height, 1.0)
        * textTransMat * textRotMat * textScaleMat
        * Matrix4f:ScaleMat(0.5 * self.bubbleTex:width(), 0.5 * self.bubbleTex:height(), 1.0)

    context:setBlend(true)
    context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)

    BubbleRender:setColor(Vec4f.new(1.0, 1.0, 1.0, self.opacity))
    BubbleRender:draw(context, self.bubbleTex:toOFTexture(), outTex,mvpMat)

    context:setBlend(false)
end

function Filter:applyRGBA(context, filter, frameData, inTex, outTex, debugTex)
    context:copyTexture(inTex, outTex)

    local width, height = outTex.width, outTex.height
    if self.frameWidth ~= width or self.frameHeight ~= height then
        self.frameWidth, self.frameHeight = width, height
    end
    if self.bubbleTex then
        self.label:setContentSize(self.calcTextSize(self, self.label.textScale))
        self.label:setAutoScaleEnabled(true)
    end

    self.processCommands(self, filter, outTex.width, outTex.height)

    self.renderBubble(self, context, filter, outTex)

    -- apply animation
    local timestamp = filter:filterTimestamp() * 1000
    self.applyAnimation(self, context, filter, outTex, timestamp)

    self.label:apply(context, inTex, outTex, debugTex)

    if self.dirty == true then
        self.dirty = false
        local lineInfo = self.label:getLineInfo(false)
        local jsonStr = Json.TableToJson({
            id = 200,
            size = { lineInfo.maxLineWidth + 2 * self.label.background.xpadding, lineInfo.totalHeight + 2 * self.label.background.ypadding },
            params = { self.label.textTransX + self.label.anchor.x, self.label.textTransY + self.label.anchor.y, self.label.textScaleX, self.label.textRotate, self.label.textScaleY }
        })
		filter:sendMessageBack(jsonStr)
        OF_LOGI(TAG, jsonStr)
    end

    return OF_Result_Success
end

function Filter:requiredFrameData(context, game)
    return { OF_RequiredFrameData_None }
end

function Filter:readObject(context, filter, archiveIn)
    OF_LOGI(TAG, "call readObject")
    print("readObject", filter:stringParam("Text"))
    return OF_Result_Success
end

function Filter:writeObject(context, filter, archiveOut)
    OF_LOGI(TAG, "call writeObject")
    return OF_Result_Success
end

function Filter:onReceiveMessage(context, filter, msg)
    OF_LOGI(TAG, string.format("call onReceiveMessage %s", msg))
    local evt = Json.JsonToTable(msg)
    if evt.id == 100 then
        OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
        if string.len(evt.effect_dir) > 0 then
            local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
            local tab = Json.JsonToTable(s)
            self.animation.enter_animation = dofile(evt.effect_dir .. "/" .. tab.script)
            self.animation.enter_animation:init(self)
            self.animation.enter_duration = evt.duration * 1000
            self.animation.enter_animation:setDuration(self, self.animation.enter_duration)
        else
            self.animation.enter_animation = nil
        end
    elseif evt.id == 101 then
        OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
        if string.len(evt.effect_dir) > 0 then
            local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
            local tab = Json.JsonToTable(s)
            self.animation.exit_animation = dofile(evt.effect_dir .. "/" .. tab.script)
            self.animation.exit_animation:init(self)
            self.animation.exit_duration = evt.duration * 1000
            self.animation.exit_animation:setDuration(self, self.animation.exit_duration)
        else
            self.animation.exit_animation = nil
        end
    elseif evt.id == 102 then
        OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
        if string.len(evt.effect_dir) > 0 then
            local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
            local tab = Json.JsonToTable(s)
            self.animation.loop_animation = dofile(evt.effect_dir .. "/" .. tab.script)
            self.animation.loop_animation:init(self)
            self.animation.loop_duration = evt.duration * 1000
            self.animation.loop_animation:setDuration(self, self.animation.loop_duration)
        else
            self.animation.loop_animation = nil
        end
    elseif evt.id == 103 then
        OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
        if string.len(evt.effect_dir) > 0 then
            local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
            local tab = Json.JsonToTable(s)
        end
    elseif evt.id == 104 then
        OF_LOGI(TAG, string.format("%d, %s", evt.id, evt.effect_dir))
        if string.len(evt.effect_dir) > 0 then
            local s = context:loadTextFromFile(evt.effect_dir .. "/config.json")
            local tab = Json.JsonToTable(s)
        end
    else
        table.insert(self.commandList, evt)
        OF_LOGI(TAG, string.format("command count %d", #self.commandList))
    end
    return ""
end

return Filter