local LittleTrainIV = {
    duration = 1000,
    timestamp = 0,
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;

        uniform mat4 userMat;
        uniform mat4 fitMat;

        varying vec2 TexCoords;
        varying vec2 screenTexCoords;
        vec2 transformUV(vec2 uv) {
            uv = vec2((uv.x * 2. - 1.), uv.y * 2. - 1.);
            uv = (fitMat * userMat * vec4(uv, 0, 1)).xy;
            uv = vec2((uv.x + 1.) / 2., (uv.y + 1.) / 2.);
            return uv;
        }

        void main ()
        {   
            vec2 uv0 = aTextureCoord.xy;
            TexCoords = transformUV(uv0);
            screenTexCoords = uv0;
            gl_Position = aPosition;
        }
        ]],
        
    fs = [[
        precision highp float;
        varying vec2 TexCoords;
        varying vec2 screenTexCoords;
        uniform sampler2D u_inputTexture;
        uniform vec4 u_ScreenParams;
        uniform float dirBlurStep;
        uniform float scaleBlurStep;
        uniform vec2 blurDirection;
        uniform float offsetParm;
        
        const float PI = 3.141592653589793;
        
        uniform int USE_DIR_BLUR;
        uniform int USE_SACLE_BLUR;
        /* random number between 0 and 1 */
        float random(in vec3 scale, in float seed) {
            /* use the fragment position for randomness */
            return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
        }
        
        vec4 crossFade(sampler2D tex, in vec2 uv, in float dissolve) {
            return texture2D(tex, uv).rgba;
        }
        
        vec4 directionBlur(sampler2D tex, vec2 resolution, vec2 uv, vec2 directionOfBlur, float intensity)
        {
            vec2 pixelStep = 1.0 / resolution * intensity;
            float dircLength = length(directionOfBlur);
            pixelStep.x = directionOfBlur.x * 1.0 / dircLength * pixelStep.x;
            pixelStep.y = directionOfBlur.y * 1.0 / dircLength * pixelStep.y;
        
            vec4 color = vec4(0);
            const int num = 7;
            for (int i = -num; i <= num; i++)
            {
                vec2 blurCoord = uv + pixelStep * float(i);
                vec2 uvT = vec2(1.0 - abs(abs(blurCoord.x) - 1.0), 1.0 - abs(abs(blurCoord.y) - 1.0));
                color += texture2D(tex, uvT);
            }
            color /= float(2 * num + 1);
            return color;
        }
        
        vec4 getDirectionBlur(sampler2D tex,vec2 uv0,vec2 tmpBlurDirection)
        {
            vec2 resolution = vec2(u_ScreenParams.x, u_ScreenParams.y);
            vec4 resultColor = directionBlur(tex, resolution, uv0, tmpBlurDirection, dirBlurStep);
            vec4 retColor = vec4(resultColor.rgb, resultColor.a) * step(uv0.x, 2.0) * step(uv0.y, 2.0) * step(-1.0, uv0.x) * step(-1.0, uv0.y);
            return retColor;
        }
        
        vec4 getScaleBlur(sampler2D tex,vec2 uv0)
        {
            vec4 color = vec4(0.0);
            float total = 0.0;
            vec2 toCenter = vec2(0.5, 0.5) - uv0;
            float dissolve = 0.5;
        
            /* randomize the lookup values to hide the fixed number of samples */
            float offset = random(vec3(12.9898, 78.233, 151.7182), 0.0);
            const int num = 25;
            for (int t = 0; t <= num; t++) {
                float percent = (float(t) + offset) / float(num);
                float weight = 4.0 * (percent - percent * percent);
        
                vec2 curUV = uv0 + toCenter * percent * scaleBlurStep;
                vec2 uvT = vec2(1.0 - abs(abs(curUV.x) - 1.0), 1.0 - abs(abs(curUV.y) - 1.0));
                color += crossFade(tex, uvT, dissolve) * weight;
                // color += crossFade(uvT + toCenter * percent * blurStep, dissolve) * weight;
                total += weight;
            }
            vec4 retColor = color / total * step(uv0.x, 2.0) * step(uv0.y, 2.0) * step(-1.0, uv0.x) * step(-1.0, uv0.y);
            return retColor;
        }
        
        vec2 mirrorRepeatUV(vec2 uv)
        {
            vec2 mUV = mod(abs(floor(uv)), 2.0);
            vec2 rUV = fract(fract(uv) + vec2(1.0, 1.0));
            return mix(rUV, vec2(1.0) - rUV, mUV);
        }

        vec2 offsetLeft(vec2 uv, float offsetX)
        {
            vec2 result = uv;
            result.x += offsetX;
            return result;
        }

        vec2 offsetRight(vec2 uv, float offsetX)
        {
            vec2 result = uv;
            result.x -= offsetX;
            return result;
        }

        void main()
        {
            vec2 uv = mirrorRepeatUV(TexCoords);
            vec4 srcColor = texture2D(u_inputTexture, uv);
            gl_FragColor = srcColor;

            if (USE_DIR_BLUR > 0) {
                // motionBlur
                vec4 dirBlur = getDirectionBlur(u_inputTexture,uv,blurDirection);
                gl_FragColor = dirBlur;
            }
            
            if (USE_SACLE_BLUR > 0) {
                //scaleBlur
                vec4 scaleBlur = getScaleBlur(u_inputTexture,uv);
                gl_FragColor = scaleBlur;
            }
            gl_FragColor *= step(-1.0, TexCoords.x) * step(TexCoords.x, 2.0) * step(-1.0, TexCoords.y) * step(TexCoords.y, 2.0);
        }        
        ]],
    renderPass = nil,
    fxaaPass = nil,
    copyPass = nil,
    values = {}
}

local function getBezierValue(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3 * xc1 * (1 - t) * (1 - t) * t + 3 * xc2 * (1 - t) * t * t + t * t * t
    ret[2] = 3 * yc1 * (1 - t) * (1 - t) * t + 3 * yc2 * (1 - t) * t * t + t * t * t
    return ret
end

local function getBezierDerivative(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3 * xc1 * (1 - t) * (1 - 3 * t) + 3 * xc2 * (2 - 3 * t) * t + 3 * t * t
    ret[2] = 3 * yc1 * (1 - t) * (1 - 3 * t) + 3 * yc2 * (2 - 3 * t) * t + 3 * t * t
    return ret
end

local function getBezierTfromX(controls, x)
    local ts = 0
    local te = 1
    -- divide and conque
    repeat
        local tm = (ts + te) / 2
        local value = getBezierValue(controls, tm)
        if (value[1] > x) then
            te = tm
        else
            ts = tm
        end
    until (te - ts < 0.0001)

    return (te + ts) / 2
end

-- ================自定义曲线================

local function funcEaseAction1(t, b, c, d)
    t = t/d
    -- diyijieduandeweiyiquxian，beisaierquxianbanben
    local controls = {.2,.8,.8,.2}
    local tvalue = getBezierTfromX(controls, t)
    local value =  getBezierValue(controls, tvalue)
    return b + c * value[2]
end

local function funcEaseBlurAction1(t, b, c, d)
    t = t/d
    -- diyijieduandeweiyiquxian，beisaierquxianbanben
    local controls = {.2,.8,.8,.2}
    local tvalue = getBezierTfromX(controls, t)
    local deriva = getBezierDerivative(controls, tvalue)
    return math.abs(deriva[2] / deriva[1]) * c
end

local function funcEaseAction2(t, b, c, d)
    t = t/d
    -- diyijieduandeweiyiquxian，beisaierquxianbanben
    local controls = {0.33, 1, 0.68, 1}
    local tvalue = getBezierTfromX(controls, t)
    local value =  getBezierValue(controls, tvalue)
    return b + c * value[2]
end
local function funcEaseAction3(t, b, c, d)
    t = t/d
    -- diyijieduandeweiyiquxian，beisaierquxianbanben
    local controls = {0.32, 0, 0.67, 0}
    local tvalue = getBezierTfromX(controls, t)
    local value =  getBezierValue(controls, tvalue)
    return b + c * value[2]
end

function LittleTrainIV:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
    self.params = {
        {
            -- qianbanduanniuqudeqiangdu，zhujianzengqiang
            key = "localPosition",
            obj = self.values,
            startValue = Vec3f.new(-2.0, 0.0, 0.0), -- qishizhi
            endValue = Vec3f.new(2.0, 0.0, 0.0), -- jieshuzhi
            defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
            actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
            end,
            curve = funcEaseAction1,
            -- 起始时间
            startTime = 0,
            -- 结束时间
            endTime =  1.0
        },
        {
            -- qianbanduanniuqudeqiangdu，zhujianzengqiang
            key = "localScale",
            keycurves = {
                {
                    obj = self.values,
                    startValue = Vec3f.new(1.1, 1.1, 1.0), -- qishizhi
                    endValue = Vec3f.new(1.0, 1.0, 1.0), -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                    end,
                    curve = funcEaseAction2,
                    startTime = 0.0, -- qishishijian
                    endTime = 0.5 -- jieshushijian
                },
                {
                    obj = self.values,
                    startValue = Vec3f.new(1.0, 1.0, 1.0), -- qishizhi
                    endValue = Vec3f.new(1.1, 1.1, 1.0), -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                    end,
                    curve = funcEaseAction3,
                    startTime = 0.5, -- qishishijian
                    endTime = 1.0 -- jieshushijian

                }
            }
        },
        {
            -- qianbanduanniuqudeqiangdu，zhujianzengqiang
            key = "localRotate",
            keycurves = {
                {
                    obj = self.values,
                    startValue = Vec3f.new(0.0, 0.0, 0.0), -- qishizhi
                    endValue = Vec3f.new(0.0, 0.0, 0.0), -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                    end,
                    curve = funcEaseAction2,
                    -- 起始时间
                    startTime = 0,
                    -- 结束时间
                    endTime =  0.5
                }
            }
        },
        {
            -- qianbanduanniuqudeqiangdu，zhujianzengqiang
            key = "dirBlurStep",
            keycurves = {
                {
                    obj = self.values,
                    startValue = 7.0, -- qishizhi
                    endValue = 0.0, -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                        renderPass:setUniform1f(key, value)
                        renderPass:setUniform2f("blurDirection", 1.0, 0.0)
                        if value > 0.001 then
                            renderPass:setUniform1i("USE_DIR_BLUR", 1)
                        else 
                            renderPass:setUniform1i("USE_DIR_BLUR", 0)
                        end
                    end,
                    curve = funcEaseAction2,
                    -- 起始时间
                    startTime = 0.0,
                    -- 结束时间
                    endTime = 0.5
                },
                {
                    obj = self.values,
                    startValue = 0.0, -- qishizhi
                    endValue = 7.0, -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                        renderPass:setUniform1f(key, value)
                        renderPass:setUniform2f("blurDirection", 1.0, 0.0)
                        if value > 0.001 then
                            renderPass:setUniform1i("USE_DIR_BLUR", 1)
                        else 
                            renderPass:setUniform1i("USE_DIR_BLUR", 0)
                        end
                    end,
                    curve = funcEaseAction3,
                    -- 起始时间
                    startTime = 0.5,
                    -- 结束时间
                    endTime = 1.0
                }
            }
        },
        -- {
        --     -- qianbanduanniuqudeqiangdu，zhujianzengqiang
        --     key = "scaleBlurStep",
        --     obj = self.values,
        --     startValue = 0.0, -- qishizhi
        --     endValue = 0.02, -- jieshuzhi
        --     defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
        --     actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
        --         renderPass:setUniform1f(key, value)
        --         if value > 0.001 then
        --             renderPass:setUniform1i("USE_SACLE_BLUR", 1)
        --         else 
        --             renderPass:setUniform1i("USE_SACLE_BLUR", 0)
        --         end
        --     end,
        --     curve = funcEaseBlurAction4,
        --     -- 起始时间
        --     startTime = 0.5,
        --     -- 结束时间
        --     endTime =  1.0
        -- }
    }
end

function LittleTrainIV:clear(context)
    if self.renderPass ~= nil then
        context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function LittleTrainIV:setDuration(filter, duration)
    self.duration = duration
end

function LittleTrainIV:seek(filter, timestamp)
    self.timestamp = timestamp
end

function LittleTrainIV:apply(filter)
    filter.animation.params.renderToRT = true
end

function LittleTrainIV:AnimateParam(progress)
    for i = 1, #self.params do
        local param = self.params[i]
        if param.keycurves ~= nil then
            local percent = math.max(math.min(progress,  param.keycurves[#param.keycurves].endTime),  param.keycurves[1].startTime)
            for j = 1, #param.keycurves do
                if percent <= param.keycurves[j].endTime + 0.001 then 
                    self.values[param.key] = param.keycurves[j].curve(percent - param.keycurves[j].startTime, param.keycurves[j].startValue, param.keycurves[j].endValue - param.keycurves[j].startValue, param.keycurves[j].endTime - param.keycurves[j].startTime)
                    param.keycurves[j].actionHandle(self.renderPass, param.key, self.values[param.key])
                    break;
                end
            end
        else 
            local percent = math.max(math.min(progress, param.endTime), param.startTime)
            self.values[param.key] = param.curve(percent - param.startTime, param.startValue, param.endValue - param.startValue, param.endTime - param.startTime)
            param.actionHandle(self.renderPass, param.key, self.values[param.key])
        end
    end
end

function LittleTrainIV:applyEffect(filter, outTex)
    --first render imageTex to output viewport
    local width, height = outTex.width, outTex.height
	local quadRender = filter.context:sharedQuadRender()    
    self.timestamp = math.max(self.timestamp, 0.0)
    local progress = math.fmod(self.timestamp, self.duration) / self.duration

    filter.context:bindFBO(outTex)
    filter.context:setViewport(0, 0, width, height)
    filter.context:clearColorBuffer()

    self.renderPass:use()
    
    self:AnimateParam(progress);

    self.values["localPosition"] = self.values["localPosition"] * width * 0.5;
    self.values["localRotate"] = self.values["localRotate"] * (math.pi / 180)
	local scaleMat = Matrix4f:ScaleMat(filter.params.scaleX * filter.params.scale, filter.params.scaleY * filter.params.scale, 1.0)
	local rotMat = Matrix4f:RotMat(0, 0, filter.params.rot)
	local transMat = Matrix4f:TransMat(filter.params.tx, filter.params.ty, 0.0)
	local mvpMat =  Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) *
		transMat * Matrix4f:TransMat(self.values["localPosition"].x, self.values["localPosition"].y, 0.0) *
        rotMat * Matrix4f:RotMat(self.values["localRotate"].x, self.values["localRotate"].y, self.values["localRotate"].z) *
        scaleMat * Matrix4f:ScaleMat(self.values["localScale"].x, self.values["localScale"].y, 1.0) * 
		Matrix4f:ScaleMat(filter.imageTex:width() * 0.5, filter.imageTex:height() * 0.5, 1)
    local transformMat = mvpMat:inverted()  

    local uvScale = { x = 1.0, y = 1.0}
    local fitMat = Matrix4f:ScaleMat(uvScale.x, uvScale.y, 1):inverted() 

    self.renderPass:setUniformMatrix4fv("userMat", 1, 0, transformMat.x)
    self.renderPass:setUniformMatrix4fv("fitMat", 1, 0, fitMat.x)
    self.renderPass:setTexture("u_inputTexture", 0, filter.imageTex:toOFTexture())
    self.renderPass:setUniform4f("u_ScreenParams", width, height, 0.0, 0.0)
    self.renderPass:setUniform1i("USE_SACLE_BLUR", 0)
    quadRender:draw(self.renderPass, false)
end

return LittleTrainIV