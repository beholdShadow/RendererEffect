TAG = "DragDown"
local TextureRender = require "common.texture"
OF_LOGI(TAG, "Call transition lua script!")

local Utils = require("common.Utils")
local AEAdapter = require("common.AEAdapter")
local AE = require("common.AE")


local FRAMES = 23
local DESIGN_W = 800
local DESIGN_H = 800

local Filter = {
    name = "DragDown",

    context = nil,
    
    vs_motion = [[
        precision highp float;

        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;

        uniform float u_offset;
        uniform float u_skewy0;
        uniform float u_skewy1;
        uniform float u_ratio;
        uniform vec4 u_frame;

        #define attPosition aPosition
        #define attUV aTextureCoord

        varying vec2 v_uv;

        vec2 transform (float offset, float skewy0, float skewy1, vec2 uv) {
            uv.y += offset + mix(skewy0, skewy1, uv.x);
            return uv + uv - 1.0;
        }

        void main () {
            vec2 uv = mix(u_frame.xy, u_frame.zw, attUV);
            v_uv = uv;
            vec2 xy = transform(u_offset, u_skewy0, u_skewy1, uv);
            float r = 1.0 / u_ratio;
        //    gl_Position = vec4(xy, 0.0, 1.0);
            gl_Position = vec4(xy * r, 0.0, 1.0);
        }

    ]],

    fs_motion = [[
        precision highp float;

        uniform sampler2D u_src;
        
        varying vec2 v_uv;
        
        
        vec4 texture2Dmirror (sampler2D tex, vec2 uv) {
            uv = mod(uv, 2.0);
            uv = mix(uv, 2.0 - uv, step(vec2(1.0), uv));
            return texture2D(tex, fract(uv));
        }
        
        void main () {
            gl_FragColor = texture2Dmirror(u_src, v_uv);
        }
        
        
    ]], 

    vs_blur = [[
        precision highp float;

        uniform float u_step_x;
        uniform float u_step_y;
        uniform float u_direction;
        uniform float u_intensity;

        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;

        #define attPosition aPosition.xy
        #define attUV aTextureCoord

        varying vec2 v_uv[9];

        #define PI 3.14159265359


        void main () {
            float a = PI * u_direction;
            float s = sin(a);
            float c = cos(a);

            vec2 t = vec2(u_step_x, u_step_y) * u_intensity;
            mat2 m = mat2(c, s, -s, c);

            v_uv[0] = attUV;
            v_uv[1] = attUV + m * vec2(1.407333, 0.0) * t;
            v_uv[2] = attUV - m * vec2(1.407333, 0.0) * t;
            v_uv[3] = attUV + m * vec2(3.294215, 0.0) * t;
            v_uv[4] = attUV - m * vec2(3.294215, 0.0) * t;
            v_uv[5] = attUV + m * vec2(5.351806, 0.0) * t;
            v_uv[6] = attUV - m * vec2(5.351806, 0.0) * t;
            v_uv[7] = attUV + m * vec2(7.302940, 0.0) * t;
            v_uv[8] = attUV - m * vec2(7.302940, 0.0) * t;

            gl_Position = vec4(attPosition, 0.0, 1.0);
        }
    ]],
    
    fs_blurC =[[
        precision highp float;

        uniform sampler2D u_src;
        uniform vec4 u_weight;

        varying vec2 v_uv[9];

        const vec4 c_weights = vec4(0.233308, 0.135928, 0.051383, 0.012595);


        void main () {
            vec4 raw = texture2D(u_src, v_uv[0]);
            vec4 sum = raw * 0.133571;
            for (int i = 0; i < 4; ++i) {
                sum += texture2D(u_src, v_uv[i * 2 + 1]) * c_weights[i];
                sum += texture2D(u_src, v_uv[i * 2 + 2]) * c_weights[i];
            }
            gl_FragColor = mix(raw, sum, u_weight);
        }
    ]],
    fs_blurT =[[
        precision highp float;

        uniform sampler2D u_src;
        
        varying vec2 v_uv[9];
        
        const vec4 c_weights = vec4(0.233308, 0.135928, 0.051383, 0.012595);
        
        
        vec4 texture2Dmirror (sampler2D tex, vec2 uv) {
            uv = mod(uv, 2.0);
            uv = mix(uv, 2.0 - uv, step(vec2(1.0), uv));
            return texture2D(tex, fract(uv));
        }
        
        void main () {
            vec4 sum = texture2D(u_src, v_uv[0]) * 0.133571;
            for (int i = 0; i < 4; ++i) {
                sum += texture2Dmirror(u_src, v_uv[i * 2 + 1]) * c_weights[i];
                sum += texture2Dmirror(u_src, v_uv[i * 2 + 2]) * c_weights[i];
            }
            gl_FragColor = sum;
        }
    ]],
    
    vs_crop = [[
        precision highp float;

        uniform float u_ratio;

        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;

        #define attPosition aPosition.xy
        #define attUV aTextureCoord

        varying vec2 v_uv;

        void main () {
            const vec2 center = vec2(0.5);
            v_uv = center + (attUV - center) / u_ratio;
            gl_Position = vec4(attPosition, 0.0, 1.0);
        }
    ]],

    fs_crop = [[
        precision highp float;

        uniform sampler2D u_src;

        varying vec2 v_uv;


        void main () {
            gl_FragColor = texture2D(u_src, v_uv);
        }
    ]],

    vs_light = [[
        precision highp float;

        uniform vec2 u_screen_size;
        uniform vec2 u_position;
        uniform float u_angle;

        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;

        #define attPosition aPosition.xy
        #define attUV aTextureCoord

        varying vec2 v_uv;
        varying vec2 v_uv1;


        vec2 transform (vec2 screen_size, vec2 image_size, vec2 translate, vec2 anchor, vec2 scale, float rotate, vec2 uv) {
            float R = rotate * 0.01745329251;
            float c = cos(R);
            float s = sin(R);

            vec2 rx = vec2(c, s);
            vec2 ry = vec2(-s, c);

            vec2 origin = translate * screen_size;
            vec2 p = uv * screen_size - origin;
            p = vec2(dot(rx, p), dot(ry, p));
            p /= image_size * scale;
            p += anchor;
            return p;
        }

        void main () {
            v_uv = attUV;
            v_uv1 = transform(u_screen_size, u_screen_size, u_position, vec2(0.5), vec2(1.0), u_angle, attUV);
            gl_Position = vec4(attPosition, 0.0, 1.0);
        }

    ]],
    fs_light = [[
        precision highp float;

        uniform sampler2D u_base;
        uniform sampler2D u_src1;
        uniform float u_opacity1;
        uniform float u_intensity;

        varying vec2 v_uv;
        varying vec2 v_uv1;

        const vec3 C0 = vec3(0.0);
        const vec3 C1 = vec3(1.0);
        const vec3 C_2 = vec3(0.5);

        vec3 blend_1001 (vec3 dst, vec3 src) {
            return min(src + dst, C1);
        }

        void main () {
            vec4 base = texture2D(u_base, v_uv);
            vec4 src1 = texture2D(u_src1, v_uv1) * u_opacity1;

            vec3 color = blend_1001(base.rgb, src1.rgb);
            gl_FragColor = vec4(color * (1.0 + u_intensity), base.a);
        }
    ]],

    renderPass = nil,
    blurPassC = nil,
    blurPassT = nil,
    cropPass = nil,
    lightPass = nil,
    frameWidth = 0,
    frameHeight = 0,

    percent = 0.0,
    duration = 1.0,

}

function Filter:initParams(context, filter)
    local currentDir = debug.getinfo(1).source:match("@?(.*/)")
    local imagePath = currentDir .. "light.jpg"
    self.imageTex = context:loadTextureFromFile(imagePath, TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)

    filter:insertFloatParam("Duration", 0.0, 2.0, self.duration)
    self.ae = AEAdapter:new()
    self.ae:addKeyframes("src0", AE.src0)
    self.ae:addKeyframes("effect", AE.effect)
    self.ae:addFrames("mask", AE.mask)
    self.y0 = self.ae:get("src0/0/ADBE Position/y", 0)
    return OF_Result_Success
end

function Filter:onApplyParams(context, filter)
    return OF_Result_Success
end

function Filter:initRenderer(context, filter)
    self.renderPass = context:createCustomShaderPass(self.vs_motion, self.fs_motion)
    self.blurPassC = context:createCustomShaderPass(self.vs_blur, self.fs_blurC)
    self.blurPassT = context:createCustomShaderPass(self.vs_blur, self.fs_blurT)
    self.cropPass = context:createCustomShaderPass(self.vs_crop, self.fs_crop)
    self.lightPass = context:createCustomShaderPass(self.vs_light, self.fs_light)
    TextureRender:initRenderer(context, filter)
    return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
    context:destroyCustomShaderPass(self.renderPass)
    context:destroyCustomShaderPass(self.blurPassC)
    context:destroyCustomShaderPass(self.blurPassT)
    context:destroyCustomShaderPass(self.cropPass)
    context:destroyCustomShaderPass(self.lightPass)
	TextureRender:teardown(context)
    return OF_Result_Success
end

function Filter:applyFrame(context, filter, frameData, inArray, outArray)
    if inArray[2] == nil then 
        return OF_Result_Success
    end
    local w = inArray[1].width * inArray[1].pixelScale
    local h = inArray[1].height * inArray[1].pixelScale
    local timestamp = filter:filterTimestamp()
    if timestamp < self.duration then
        self.percent = timestamp / self.duration
    else
        self.percent = 1.0
    end
    local f = self.percent * FRAMES 
    
    --skew up && skew down
    local y0 = (self.ae:get("src0/0/ADBE Position/y", f) - self.y0) / DESIGN_H
    local y1 = y0 - 2
    local dy0 = self.ae:get("src0/0/ADBE Corner Pin-0001/y", f) / DESIGN_H
    local dy1 = self.ae:get("src0/0/ADBE Corner Pin-0002/y", f) / DESIGN_H

    context:setBlend(false)
    -- OF_LOGI(TAG, string.format("DragDown y0 = %f, dy0 = %f, dy1 = %f",y0,dy0,dy1))
    local tempTex = context:getTexture(PixelSize.new(outArray[1].width, outArray[1].height, outArray[1].pixelScale))
    -- context:bindFBO(outArray[1])
    -- context:setViewport(0, 0, outArray[1].width, outArray[1].height)
    context:bindFBO(tempTex:toOFTexture())
    context:setViewport(PixelSize.new(outArray[1].width, outArray[1].height, outArray[1].pixelScale))
    context:setClearColor(0.0, 0.0, 0.0, 0.0)
    context:clearColorBuffer()

    self.renderPass:use()

    self.renderPass:setUniform1f("u_skewy0", dy0)
    self.renderPass:setUniform1f("u_skewy1", dy1)
    self.renderPass:setUniform1f("u_ratio", 1.5)
    self.renderPass:setUniform4f("u_frame", 0, -0.5, 1, 1)
    self.renderPass:setUniform1f("u_offset", y0)
    self.renderPass:setTexture("u_src", 0, inArray[1])
    local quadRender = context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)

    self.renderPass:setUniform4f("u_frame", 0, 0, 1, 1.5)
    self.renderPass:setUniform1f("u_offset", y1)
    self.renderPass:setTexture("u_src", 0, inArray[2])
    quadRender:draw(self.renderPass, false)


    local s = math.min(w, h) / DESIGN_H
    local dw = s / w
    local dh = s / h
    local bc = self.ae:get("effect/0/ADBE Channel Blur-0001", f) / 7.3
    local bt = self.ae:get("effect/0/ADBE Motion Blur-0002", f) / 7.3
    local lx = self.ae:get("mask.position.x", f)
    local ly = self.ae:get("mask.position.y", f)
    local lr = self.ae:get("mask.rotate", f)

    context:bindFBO(outArray[1])
    self.blurPassC:use()
    -- gs1c
    self.blurPassC:setUniform1f("u_step_x", dw)
    self.blurPassC:setUniform1f("u_step_y", dh)
    self.blurPassC:setUniform1f("u_intensity", bc)
    self.blurPassC:setTexture("u_src", 0, tempTex:toOFTexture())
    self.blurPassC:setUniform1f("u_direction", 0.5)
    self.blurPassC:setUniform4f("u_weight", 1.0, 0.0, 0.0, 0.0)
    quadRender:draw(self.blurPassC, false)
    -- gs2c
    context:bindFBO(tempTex:toOFTexture())
    self.blurPassC:setUniform1f("u_intensity", bc * 0.5)
    self.blurPassC:setTexture("u_src", 0, outArray[1])
    quadRender:draw(self.blurPassC, false)
    -- gs3c
    context:bindFBO(outArray[1])
    self.blurPassC:setUniform1f("u_intensity", bc * 0.25)
    self.blurPassC:setTexture("u_src", 0, tempTex:toOFTexture())
    quadRender:draw(self.blurPassC, false)


    context:bindFBO(tempTex:toOFTexture())
    self.blurPassT:use()
    -- gs1t
    self.blurPassT:setUniform1f("u_step_x", dw)
    self.blurPassT:setUniform1f("u_step_y", dh)
    self.blurPassT:setUniform1f("u_intensity", bt)
    self.blurPassT:setTexture("u_src", 0, outArray[1])
    self.blurPassT:setUniform1f("u_direction", 0.5)
    quadRender:draw(self.blurPassT, false)
    -- gs2t
    context:bindFBO(outArray[1])
    self.blurPassT:setUniform1f("u_intensity", bt * 0.5)
    self.blurPassT:setTexture("u_src", 0,  tempTex:toOFTexture())
    quadRender:draw(self.blurPassT, false)
    -- gs3t
    context:bindFBO(tempTex:toOFTexture())
    self.blurPassT:setUniform1f("u_intensity", bt * 0.25)
    self.blurPassT:setTexture("u_src", 0, outArray[1])
    quadRender:draw(self.blurPassT, false)
    -- gs4t
    context:bindFBO(outArray[1])
    self.blurPassT:setUniform1f("u_intensity", bt * 0.125)
    self.blurPassT:setTexture("u_src", 0,  tempTex:toOFTexture())
    quadRender:draw(self.blurPassT, false)
    -- gs1n
    context:bindFBO(tempTex:toOFTexture())
    self.blurPassT:setUniform1f("u_intensity", bt / 200 * 0.5)
    self.blurPassT:setTexture("u_src", 0, outArray[1])
    self.blurPassT:setUniform1f("u_direction", 0.0)
    quadRender:draw(self.blurPassT, false)

    context:bindFBO(outArray[1])
    self.cropPass:use()
    self.cropPass:setUniform1f("u_ratio", 1.5)
    self.cropPass:setTexture("u_src", 0,  tempTex:toOFTexture())
    quadRender:draw(self.cropPass, false)

    context:bindFBO(tempTex:toOFTexture())
    self.lightPass:use()
    self.lightPass:setUniform2f( "u_screen_size", w, h)
    self.lightPass:setUniform2f("u_position", lx, ly)
    self.lightPass:setUniform1f("u_angle", lr)
    local exp = self.ae:get("effect/0/PEDG-0002", f)
    self.lightPass:setUniform1f("u_intensity", exp * 7.5)
    self.lightPass:setUniform1f("u_opacity1", 0.5)
    self.lightPass:setTexture("u_base", 0,  outArray[1])
    self.lightPass:setTexture("u_src1", 1,  self.imageTex:toOFTexture())
    quadRender:draw(self.lightPass, false)

    context:copyTexture(tempTex:toOFTexture(), outArray[1])

    if outArray[2] ~= nil then
        context:copyTexture(inArray[1], outArray[2])
    end

    context:releaseTexture(tempTex)
    return OF_Result_Success
end

function Filter:requiredFrameData(context, game)
    return { OF_RequiredFrameData_None }
end

function Filter:onReceiveMessage(context, filter, msg)
    OF_LOGI(TAG, string.format("call onReceiveMessage %s", msg))
    local evt = Json.JsonToTable(msg)
    if evt.duration and evt.duration >= 0 then
        self.duration = evt.duration
    end
    return ""
end

return Filter