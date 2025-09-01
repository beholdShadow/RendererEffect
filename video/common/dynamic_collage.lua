
local TAG = "DynamicCollage"
local DynamicCollage = {
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        uniform mat4 uMVP;
        varying vec2 vTexCoord; 
        void main()
        {
            gl_Position = aPosition; 
            vTexCoord = aTextureCoord.xy;
        }
    ]],

    collage_fs = [[
        precision highp float;

        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform float uMirror;   
        uniform mat4 uTexInverseMat;
        uniform vec2 uSpace;
        uniform vec2 uPhase;
        vec2 mirrorRepeatUV(vec2 uv)
        {
            vec2 mUV = mod(abs(floor(uv)), 2.0);
            vec2 rUV = fract(fract(uv) + vec2(1.0, 1.0));
            return mix(rUV, vec2(1.0) - rUV, mUV);
        }

        vec2 repeatUV(vec2 uv)
        {
            return fract(fract(uv) + vec2(1.0, 1.0));
        }

        void main()
        {
            vec2 uv = vTexCoord * 2.0 - vec2(1.0, 1.0);
            vec2 reverseUV = (uTexInverseMat * vec4(uv, 0.0, 1.0)).xy;
            reverseUV = reverseUV * 0.5 + vec2(0.5, 0.5);
            vec2 mUV = mod(abs(floor(reverseUV)), 2.0);
            reverseUV = reverseUV + vec2(mUV.y, mUV.x) * uPhase;
            reverseUV = mix(repeatUV(reverseUV), mirrorRepeatUV(reverseUV), uMirror);
            vec2 gap = step(uSpace, reverseUV) * step(reverseUV, vec2(1.0) - uSpace);
            reverseUV = (reverseUV - uSpace) / (vec2(1.0) - uSpace * 2.0);
            gl_FragColor = texture2D(uTexture0, reverseUV) * gap.x * gap.y;
        }
    ]],

    _collagePass = nil,
    _width = 100,
    _height = 100,
    _mirror = false,
    _phase = 0,
    _space = 0,
    _horizontal = false
    -- _filter = nil,
}

function DynamicCollage:initParams(context, filter)
	--filter:insertFloatParam("Time", 0.0, 1.0, 0.4)
	-- filter:insertFloatParam("Pow", 0.0, 2.0, 1.0)
    -- filter:insertIntParam("BlurFrame", 0, 4, 1)
	filter:insertIntParam("CollageWidth", 0, 20000, 100)
    filter:insertIntParam("CollageHeight", 0, 20000, 100)
    filter:insertBoolParam("CollageMirror", false)
    filter:insertIntParam("CollagePhase", 0, 360, 0)
    filter:insertBoolParam("CollageHorizontalOffset", false)
    filter:insertIntParam("CollageHorizontalSpace", 0, 200, 0)
    filter:insertIntParam("CollageVerticalSpace", 0, 200, 0)

    return OF_Result_Success
end

function DynamicCollage:onApplyParams(context, filter, dirtyTable)
	self._width = filter:intParam("CollageWidth") / 100
    self._height = filter:intParam("CollageHeight") / 100
    self._phase = filter:intParam("CollagePhase") / 360
    self._mirror = filter:boolParam("CollageMirror")
    self._spaceX = filter:intParam("CollageHorizontalSpace") / 100 
    self._spaceY = filter:intParam("CollageVerticalSpace") / 100
    self._horizontal = filter:boolParam("CollageHorizontalOffset")
    return OF_Result_Success
end

function DynamicCollage:isEnabled()
    return self._width ~= 1.0 or self._height ~= 1.0
end

function DynamicCollage:initRenderer(context, filter)
    OF_LOGI("DynamicCollage", "call DynamicCollage:initRenderer")

    self._collagePass = context:createCustomShaderPass(self.vs, self.collage_fs)
    -- self._filter = filter
    return OF_Result_Success
end

function DynamicCollage:teardown(context, filter)
    OF_LOGI("DynamicCollage", "call DynamicCollage:teardown")

    context:destroyCustomShaderPass(self._collagePass)
    self._collagePass = nil

    return OF_Result_Success
end

function DynamicCollage:draw(context, inTex, outTex, mvpMat)
    -- OF_LOGI(TAG, string.format("DynamicCollage out w = %f, h = %f", outTex.width, outTex.height))
    context:bindFBO(outTex)
    context:setViewport(0, 0, outTex.width, outTex.height)

    local render = context:sharedQuadRender()   

    self._collagePass:use()
    self._collagePass:setUniformMatrix4fv("uTexInverseMat", 1, 0,  mvpMat.x)
    self._collagePass:setUniformTexture("uTexture0", 0, inTex.textureID, GL_TEXTURE_2D)
    self._collagePass:setUniform1f("uMirror",(self._mirror and {1.0} or {0.0})[1])
    self._collagePass:setUniform2f("uPhase", (self._horizontal and {self._phase} or {0.0})[1], (self._horizontal and {0.0} or {self._phase})[1] )
    self._collagePass:setUniform2f("uSpace", self._spaceX / (2 * (1.0 + self._spaceX)), self._spaceY / (2 * (1.0 + self._spaceY)))

    render:draw(self._collagePass, false)
    
    return OF_Result_Success
end

return DynamicCollage
