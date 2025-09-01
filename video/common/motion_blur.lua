local TAG = "MotionBlurRender"

local directionBlur = require'common.direction_blur'
local radialBlur = require'common.radial_blur'

local Epslion = 0.001
local MotionBlurRender = {
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;

        uniform mat4 uMVP;
        uniform mat4 uPreMVP;

        varying vec2 vTexCoord; 
        varying vec2 vCurPosition;
        varying vec2 vPrePosition;

        void main()
        {
            gl_Position = aPosition; 
            vTexCoord = aTextureCoord.xy;
            vec4 curPos = uMVP * vec4(aPosition.xy, 0.0, 1.0);
            vCurPosition = curPos.xy / curPos.w * 0.5 + vec2(0.5, 0.5);
            vec4 prePos = uPreMVP * vec4(aPosition.xy, 0.0, 1.0);
            vPrePosition = prePos.xy / prePos.w * 0.5 + vec2(0.5, 0.5);
        }
    ]],

    blur_overlap_fs = [[
        precision highp float;
    
        varying vec2 vTexCoord;

        uniform sampler2D uTex0;
        uniform sampler2D uTex1;

        uniform float uBlurStrength;
    
        void main()
        {
            vec4 lastColor = texture2D(uTex0, vTexCoord);
            vec4 curColor = texture2D(uTex1, vTexCoord);
            gl_FragColor = vec4(mix(curColor.rgb, lastColor.rgb, uBlurStrength), curColor.a);
        }
    ]],

    blur_motion_fs_post = [[
        precision highp float;

        varying vec2 vCurPosition;
        varying vec2 vPrePosition;
        varying vec2 vTexCoord;
        uniform vec2 uTexSize;
        uniform sampler2D uTex0;
        uniform float uVelCenter;

        const int kSamplesMax = 100;
        const int kSamplesMin = 32;

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
            vec2 velocity = vCurPosition.xy - vPrePosition.xy;
            float distance = max(length(velocity), 0.001);
            velocity *= (min(distance, 0.5) / distance);
            float sampleCountf = max(abs(velocity.x * uTexSize.x) * 2.0, abs(velocity.y * uTexSize.y) * 2.0);
            int sampleCount = int(max(min(float(kSamplesMax), sampleCountf), float(kSamplesMin)));
            vec2 target = vec2(0.0);
            vec4 result = texture2D(uTex0, vTexCoord);
            for (int i = 1; i < kSamplesMax; ++i) {
                if(i > sampleCount)
                    break;
                target = vTexCoord + velocity * (float(i) / float(sampleCount) - uVelCenter);
                result += texture2D(uTex0, target);
            }
            gl_FragColor = result / float(sampleCount + 1);
        }
    ]],
    _blurOverlayPass = nil,
    _blurMotionPass = nil,
    _blurStrength = 0.5,
    _lastTex = nil,

    -- _filter = nil,
    _preParams = nil,
        
    _enableLayer = false,
}

function MotionBlurRender:initRenderer(context, filter)
    OF_LOGI("MotionBlurRender", "call MotionBlurRender:initRenderer")

    self._blurOverlayPass = context:createCustomShaderPass(self.vs, self.blur_overlap_fs)
    self._blurMotionPass = context:createCustomShaderPass(self.vs, self.blur_motion_fs_post)
    -- self._filter = filter

    directionBlur:initRenderer(context, filter)
    radialBlur:initRenderer(context, filter)

    return OF_Result_Success
end

function MotionBlurRender:setLayerMotion(enable)
    self._enableLayer = enable
end

function MotionBlurRender:teardown(context, filter)
    OF_LOGI("MotionBlurRender", "call MotionBlurRender:teardown")

    context:destroyCustomShaderPass(self._blurOverlayPass)
    self._blurOverlayPass = nil

    context:destroyCustomShaderPass(self._blurMotionPass)
    self._blurMotionPass = nil

    if self._lastTex ~= nil then 
        context:releaseTexture(self._lastTex) 
        self._lastTex = nil
    end

    directionBlur:teardown(context, filter)
    radialBlur:teardown(context, filter)

    return OF_Result_Success
end

function MotionBlurRender:initParams(context, filter)
	--filter:insertFloatParam("Time", 0.0, 1.0, 0.4)
	-- filter:insertFloatParam("Pow", 0.0, 2.0, 1.0)
    -- filter:insertIntParam("BlurFrame", 0, 4, 1)
	filter:insertFloatParam("BlurStrength", 0.0, 0.99, 0.5)

    return OF_Result_Success
end

function MotionBlurRender:onApplyParams(context, filter, dirtyTable)
	self._blurStrength = filter:floatParam("BlurStrength")

    return OF_Result_Success
end

function MotionBlurRender:CombineBlur(context, inTex, outTex, params)
    local width = outTex.width
    local height = outTex.height

    local deltaTime = (params.timestamp - self._preParams.timestamp)
    if deltaTime < Epslion then
        context:copyTexture(inTex, outTex)
    else
        local deltaScale = math.max(math.abs(params.scaleY - self._preParams.scaleY), math.abs(params.scaleX - self._preParams.scaleX))
        radialBlur._blurStrength = math.min(deltaScale * math.max(width, height) * self._blurStrength / deltaTime / 1.5, 1.0)
        radialBlur._blurType = BLUR_TYPE_SCALE
        radialBlur._blurIterCount = math.max(math.floor(radialBlur._blurStrength * 30), 1)
        
        radialBlur:draw(context, inTex, outTex)

        -- OF_LOGI(TAG, string.format("Rotate: [_blurStrength = %f _blurIterCount = %f]", radialBlur._blurStrength, radialBlur._blurIterCount))
    
        local deltaRot = params.rot - self._preParams.rot
        radialBlur._blurStrength = math.min(math.abs(deltaRot * 500 * self._blurStrength / deltaTime), 1.0)
        radialBlur._blurType = BLUR_TYPE_ROTATE
        radialBlur._blurIterCount = math.max(math.floor(radialBlur._blurStrength * 30), 1)

        radialBlur:draw(context, outTex, self._lastTex:toOFTexture())
        
        -- OF_LOGI(TAG, string.format("Scale: [_blurStrength = %f _blurIterCount = %f]", radialBlur._blurStrength, radialBlur._blurIterCount))

        local deltaPos = {
            x = (params.tx - self._preParams.tx),
            y = (params.ty - self._preParams.ty)
        } 
        directionBlur._blurStrength = math.min((deltaPos.x * deltaPos.x +  deltaPos.y * deltaPos.y) * self._blurStrength / deltaTime / 10, 1.0)
        directionBlur._blurIterCount = math.max(math.floor(directionBlur._blurStrength * 30), 1)
        directionBlur._blurDirection = math.atan(deltaPos.y, deltaPos.x) / math.pi * 180
        directionBlur:draw(context, self._lastTex:toOFTexture(), outTex)

        -- OF_LOGI(TAG, string.format("Translate:[ deltaPos = (%f, %f) deltaTime = %f _blurStrength = %f _blurIterCount = %f _blurDirection = %f]", 
        -- deltaPos.x, deltaPos.y, deltaTime, 
        -- directionBlur._blurStrength, directionBlur._blurIterCount, directionBlur._blurDirection))
    end
end

function MotionBlurRender:draw(context, inTex, outTex, mvpMat)
    local width = outTex.width
    local height = outTex.height

    -- OF_LOGI(TAG, string.format("MotionBlurRender out w = %f, h = %f", outTex.width, outTex.height))
    
    context:bindFBO(outTex)
    context:setViewport(0, 0, width, height)

    local render = context:sharedQuadRender()   

    if self._enableLayer then
        local curParams = {}

        if mvpMat ~= nil then
            curParams = Matrix4f.new()
            curParams:set(mvpMat.x)
        end

        if self._preParams == nil then
            self._preParams = curParams
        end

        self._blurMotionPass:use()
        self._blurMotionPass:setUniformMatrix4fv("uPreMVP", 1, 0, self._preParams.x)
        self._blurMotionPass:setUniformMatrix4fv("uMVP", 1, 0, curParams.x)
        self._blurMotionPass:setUniform2f("uTexSize", width, height)
        self._blurMotionPass:setUniformTexture("uTex0", 0, inTex.textureID, GL_TEXTURE_2D)
        self._blurMotionPass:setUniform1f("uVelCenter", 0.5)

        render:draw(self._blurMotionPass, false)

        self._preParams = curParams
    else
        if self._lastTex == nil then
            self._lastTex = context:getTexture(width, height)
            context:copyTexture(inTex, self._lastTex:toOFTexture())
        end
        local blurStrength = self._blurStrength

        self._blurOverlayPass:use()
        self._blurOverlayPass:setUniformMatrix4fv("uMVP", 1, 0, Matrix4f:ScaleMat(1.0, 1.0, 1.0).x)
        self._blurOverlayPass:setUniformTexture("uTex0", 0, self._lastTex:textureID(), GL_TEXTURE_2D)
        self._blurOverlayPass:setUniformTexture("uTex1", 1, inTex.textureID, GL_TEXTURE_2D)
        self._blurOverlayPass:setUniform1f("uBlurStrength", blurStrength)

        render:draw(self._blurOverlayPass, false)

        context:copyTexture(outTex, self._lastTex:toOFTexture())
    end
    
    return OF_Result_Success
end

return MotionBlurRender
