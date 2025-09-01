local TAG = "CropRender"

local DEF_FillColor = 0
local DEF_FillFrostedGlass = 1

local TextureRender = require "common.texture"
local GaussianBlur = require "common.gaussian_blur"
local NoiseRender = require "common.noise"
local CropRender = {
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
    fs_frost_glass = [[
        precision highp float;
        uniform sampler2D uBaseTex;
        uniform sampler2D uBlurTex0;
        uniform sampler2D uBlurTex1;
        uniform sampler2D uBlurTex2;
        uniform sampler2D uNoiseTex;
        uniform vec4 uNoiseTexST;
        uniform float uIntensity;

        varying vec2 vTexCoord;

        vec2 repeatUV(vec2 uv)
        {
            return fract(fract(uv) + vec2(1.0, 1.0));
        }

        void main()
        {
            vec4 color0 = texture2D(uBaseTex, vTexCoord);
            vec3 color1 = texture2D(uBlurTex0, vTexCoord).rgb;
            vec3 color2 = texture2D(uBlurTex1, vTexCoord).rgb;
            vec3 color3 = texture2D(uBlurTex2, vTexCoord).rgb;
            float frostIntensity = texture2D(uNoiseTex, repeatUV(vTexCoord * uNoiseTexST.xy + uNoiseTexST.zw)).r;

            float step2 = uIntensity * smoothstep(0.5, 1.0, frostIntensity);
            float step1 = uIntensity * smoothstep(0.25, 0.5, frostIntensity);
            float step0 = uIntensity * smoothstep(0.00, 0.25, frostIntensity);

            vec3 combineColor = mix(color1.rgb, mix(color1, mix(color2, color3, step2), step1), step0);

            gl_FragColor = vec4(combineColor, color0.a);
        }
        ]],

    cropRect = { 0.0, 0.0, 1.0, 1.0},
    cropRot = 0,
    sourceWidth = 1024,
    sourceHeight = 1024,

    fillMode = DEF_FillFrostedGlass,
    fillColor = Vec4f.new(1.0, 1.0, 1.0, 1.0),
    fillIntensity = 1.0,
    noiseTex = nil,
    fillFrostedST = {1.0, 1.0, 0.0, 0.0},

    pass = nil
}

function CropRender:initParams(context, filter)
    OF_LOGI(TAG, "call CropRender initParams")
    filter:insertStringParam("CropRect", "[0.0, 0.0, 1.0, 1.0]")
    filter:insertIntParam("CropRotate", -180, 180, 0)
    filter:insertIntParam("CropSourceWidth", 0, 4096, self.sourceWidth)
    filter:insertIntParam("CropSourceHeight", 0, 4096, self.sourceHeight)
    filter:insertEnumParam("CropFillMode", self.fillMode, { "color", "frosted glass"})
    filter:insertColorParam("CropFillColor", self.fillColor)
    filter:insertFloatParam("CropFillIntensity", 0, 1.0, self.fillIntensity)
    filter:insertStringParam("CropFillFrostedST", "[1.0, 1.0, 0.0, 0.0]")
    NoiseRender:initParams(context, filter)  
    GaussianBlur:setGaussStrength(1.0)
    GaussianBlur:setGaussIterCount(1)
    return OF_Result_Success
end

function CropRender:initRenderer(context, filter)
    OF_LOGI(TAG, "call CropRender initRenderer")
    GaussianBlur:initRenderer(context, filter)
    NoiseRender:initRenderer(context, filter)
    TextureRender:initRenderer(context, filter)
    self.pass = context:createCustomShaderPass(self.vs, self.fs_frost_glass)
    return OF_Result_Success
end

function CropRender:setParams(context, cropTable)
    if cropTable == nil then
        return 
    end
    self.cropRect = cropTable.cropRect
    self.cropRot = cropTable.cropRotate
    self.sourceWidth = cropTable.sourceWidth
    self.sourceHeight = cropTable.sourceHeight
    self.fillMode = cropTable.fillMode
    self.fillColor = cropTable.fillColor

    if self.noiseTex then context:releaseTexture(self.noiseTex) end
    self.noiseTex = context:getTexture(self.sourceWidth * NoiseRender.nosieNum / 100, self.sourceHeight * NoiseRender.nosieNum / 100)
    NoiseRender:draw(context, self.noiseTex:toOFTexture())
end

function CropRender:onApplyParams(context, filter, dirtyTable)
    OF_LOGI(TAG, "call CropRender onApplyParams")
    if dirtyTable:isDirty("CropRect") then
        local str = filter:stringParam("CropRect")
        if string.len(str) > 0 then
            self.cropRect = Json.JsonToTable(str)
        end
    end
    if dirtyTable:isDirty("CropFillFrostedST") then
        local str = filter:stringParam("CropFillFrostedST")
        if string.len(str) > 0 then
            self.fillFrostedST = Json.JsonToTable(str)
        end
    end

    NoiseRender:onApplyParams(context, filter)
    if dirtyTable:isDirty("CropSourceWidth") or dirtyTable:isDirty("CropSourceHeight") or dirtyTable:isDirty("NoiseNum")  then
        self.sourceWidth = filter:intParam("CropSourceWidth")
        self.sourceHeight = filter:intParam("CropSourceHeight")

        if self.noiseTex then 
            context:releaseTexture(self.noiseTex) 
            self.noiseTex = nil
        end
        if self.sourceWidth == 0 or self.sourceHeight == 0 then
            return OF_Result_Failed
        end
        self.noiseTex = context:getTexture(self.sourceWidth * NoiseRender.nosieNum / 100, self.sourceHeight * NoiseRender.nosieNum / 100)
        NoiseRender:draw(context, self.noiseTex:toOFTexture())
    end
    self.fillMode = filter:enumParam("CropFillMode")
    self.fillColor = filter:colorParam("CropFillColor")
    self.cropRot = filter:intParam("CropRotate") * math.pi / 180
    self.fillIntensity = filter:floatParam("CropFillIntensity")

    return OF_Result_Success
end

function CropRender:teardown(context, filter)
    OF_LOGI(TAG, "call CropRender teardownRenderer")
    GaussianBlur:teardown(context, filter)
    TextureRender:teardown(context, filter)
    NoiseRender:teardown(context, filter)
    if self.pass then
        context:destroyCustomShaderPass(self.pass)
        self.pass = nil
    end
    if self.noiseTex then
        context:releaseTexture(self.noiseTex)
        self.noiseTex = nil
    end
    return OF_Result_Success
end

function CropRender:isEnabled()
    return self.sourceWidth > 0 and self.sourceHeight > 0
end

function CropRender:draw(context, inTex, outTex, bgTex, clipMat)
    context:setBlend(false)    
    local centerX = ((self.cropRect[1] + self.cropRect[3] / 2) - 0.5) * outTex.width
    local centerY = ((self.cropRect[2] + self.cropRect[4] / 2) - 0.5) * outTex.height
    if self.fillMode == DEF_FillFrostedGlass then
        local frostedGlassTex = context:getTexture(outTex.width, outTex.height)
        context:bindFBO(frostedGlassTex:toOFTexture())
        context:setViewport(0, 0, frostedGlassTex:width(), frostedGlassTex:height()) 
        context:setClearColor(1.0, 1.0, 1.0, 0.0)
        context:clearColorBuffer()
        if bgTex then
            local clipInvertMat = clipMat:inverted()
            TextureRender:setColor(Vec4f.new(1.0, 1.0, 1.0, 0.0))
            TextureRender:draw(context, bgTex, frostedGlassTex:toOFTexture(), clipInvertMat)
        end
        local blurTexTable = {};
        for i = 1, 3, 1 do
            local temp = context:getTexture(outTex.width * 0.15, outTex.height * 0.15)
            table.insert(blurTexTable, temp)
        end
        local fillWidth, fillHeight
        if outTex.width / outTex.height > inTex.width / inTex.height then
            fillWidth = outTex.width
            fillHeight = math.ceil(fillWidth * inTex.height / inTex.width)
        else
            fillHeight = outTex.height
            fillWidth = math.ceil(fillHeight * inTex.width / inTex.height)
        end

        local XOffset, YOffset = math.abs(centerX), math.abs(centerY)
        if XOffset / fillWidth > YOffset / fillHeight then 
            fillWidth = fillWidth + 2.0 * XOffset
            fillHeight = math.ceil(fillWidth * inTex.height / inTex.width)
        else
            fillHeight = fillHeight + 2.0 * YOffset
            fillWidth = math.ceil(fillHeight * inTex.width / inTex.height)
        end
        
        local mvpMat = Matrix4f:ScaleMat(2 / outTex.width, 2 / outTex.height, 1.0 ) * 
                        Matrix4f:TransMat(centerX, centerY, 0.0) *
                            Matrix4f:ScaleMat(fillWidth * 0.5, fillHeight * 0.5, 1.0)
 
        TextureRender:setColor(Vec4f.new(1.0, 1.0, 1.0, 1.0))   
        TextureRender:draw(context, inTex, frostedGlassTex:toOFTexture(), mvpMat, true)

        GaussianBlur:setGaussStrength(1.0)
        GaussianBlur:draw(context, frostedGlassTex:toOFTexture(), blurTexTable[1]:toOFTexture())
        GaussianBlur:setGaussStrength(0.6)
        for i = 1, 2, 1 do
            GaussianBlur:draw(context, blurTexTable[i]:toOFTexture(), blurTexTable[i+1]:toOFTexture())
        end

        context:bindFBO(outTex) 
        context:setViewport(0, 0, outTex.width, outTex.height)
        self.pass:use()
        self.pass:setUniformMatrix4fv("uMVP", 1, 0, Matrix4f.new().x)
        self.pass:setUniformTexture("uBaseTex", 0, frostedGlassTex:textureID(), TEXTURE_2D)
        for i = 1, 3, 1 do
            self.pass:setUniformTexture(string.format("uBlurTex%d", (i - 1)), i, blurTexTable[i]:textureID(), TEXTURE_2D)
        end
        self.pass:setUniformTexture("uNoiseTex", 5, self.noiseTex:textureID(), TEXTURE_2D)
        self.pass:setUniform4f("uNoiseTexST", self.fillFrostedST[1], self.fillFrostedST[2], self.fillFrostedST[3], self.fillFrostedST[4])
        self.pass:setUniform1f("uIntensity", self.fillIntensity)
        local quadRender = context:sharedQuadRender()
        quadRender:draw(self.pass, false)

        for i = 1, 3, 1 do
            context:releaseTexture(blurTexTable[i])
        end
        context:releaseTexture(frostedGlassTex)
    else    
        context:bindFBO(outTex)
        context:setViewport(0, 0, outTex.width, outTex.height)
        context:setClearColor(self.fillColor.x, self.fillColor.y, self.fillColor.z, self.fillColor.w)
        context:clearColorBuffer()
    end

    local mvpMat = Matrix4f:ScaleMat(2 / outTex.width, 2 / outTex.height, 1.0 ) * 
            Matrix4f:TransMat(centerX, centerY, 0.0) *
            Matrix4f:RotMat(0.0, 0.0, self.cropRot)*
            Matrix4f:ScaleMat(self.cropRect[3] * outTex.width * 0.5, self.cropRect[4] * outTex.height * 0.5, 1)
    
    TextureRender:setColor(Vec4f.new(1.0, 1.0, 1.0, 1.0))   
    if self.fillMode == DEF_FillFrostedGlass then
        context:setBlend(true)  
        context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)
        TextureRender:draw(context, inTex, outTex, mvpMat)
        context:setBlend(false)    
    else
        TextureRender:draw(context, inTex, outTex, mvpMat)
    end
    return OF_Result_Success
end

return CropRender