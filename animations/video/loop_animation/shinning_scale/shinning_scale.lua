TAG = "DragDown"
OF_LOGI(TAG, "Call transition lua script!")

local Utils = {}

function Utils.__log_translate (args)
    for i, v in ipairs(args) do
        local type = type(v)
        if type == "table" then
            args[i] = cjson.encode(v)
        elseif type == "boolean" then
            args[i] = v and "true" or "false"
        elseif v == nil then
            args[i] = "nil"
        else
            args[i] = v
        end
    end
    return args
end

function Utils.log (fmt, ...)
---#ifdef DEV
--//    Amaz.LOGW("jorgen", string.format(fmt, (unpack or table.unpack)(Utils.__log_translate({...}))))
---#endif
end

function Utils.swap (a, b)
    return b, a
end


function Utils.sineIn (t)
    return 1 - math.cos(math.pi * t * .5)
end
function Utils.sineOut (t)
    return math.sin(math.pi * t * .5)
end
function Utils.sineInOut (t)
    return -(math.cos(math.pi * t) - 1) * .5
end
function Utils.quadIn (t)
    return t * t
end
function Utils.quadOut (t)
    return (2 - t) * t
end
function Utils.quadInOut (t)
    return t < .5 and 2 * t * t or t * (4 - t - t) - 1
end
function Utils.cubicIn (t)
    return t * t * t
end
function Utils.cubicOut (t)
    t = 1 - t
    return 1 - t * t * t
end
function Utils.cubicInOut (t)
    if t < .5 then
        return 4 * t * t * t
    else
        t = 2 - t - t
        return 1 - t * t * t * .5
    end
end
function Utils.quartIn (t)
    t = t * t
    return t * t
end
function Utils.quartOut (t)
    t = 1 - t
    t = t * t
    return 1 - t * t
end
function Utils.quartInOut (t)
    if t < .5 then
        t = t * t
        return 8 * t * t
    else
        t = 2 - t - t
        t = t * t
        return 1 - t * t * .5
    end
end
function Utils.expoIn (t)
    return t ~= 0 and math.pow(2, 10 - t - 10) or 0
end
function Utils.expoOut (t)
    return t ~= 1 and 1 - math.pow(2, -10 * t) or 1
end
function Utils.expoInOut (t)
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    elseif t < .5 then
        return math.pow(2, 20 * t - 10) * .5
    else
        return 1 - math.pow(2, -20 * t + 10) * .5
    end
end
function Utils.circIn (t) return 1 - math.sqrt(1 - t * t) end
function Utils.circOut (t)
    t = t - 1
    return math.sqrt(1 - t * t)
end
function Utils.circInOut (t)
    if t < .5 then
        return .5 - math.sqrt(1 - 4 * t * t) * .5
    else
        t = 2 - t - t
        return .5 + math.sqrt(1 - t * t) * 0.5
    end
end
function Utils.backIn (t)
    local tt = t * t
    return 2.70158 * tt * t - 1.70158 * tt
end
function Utils.backOut (t)
    t = t - 1
    local tt = t * t
    return 1 + 2.70158 * tt * t + 1.70158 * tt
end
function Utils.backInOut (t)
    if t < .5 then
        t = t + t
        return (t * t * (3.5949095 * t - 2.5949095)) * .5
    else
        t = t + t - 2
        return (t * t * (3.5949095 * t + 2.5949095) + 2) * .5
    end
end
function Utils.elasticIn (t)
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    else
        return -math.pow(2, 10 * t - 10) * math.sin((t * 10 - 10.75) * math.pi * 2 / 3)
    end
end
function Utils.elasticOut (t)
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    else
        return math.pow(2, -10 * t) * math.sin((t * 10 - .75) * math.pi * 2 / 3) + 1
    end
end
function Utils.elasticInOut (t)
    if t == 0 then
        return 0
    elseif t == 1 then
        return 1
    elseif t < 0.5 then
        return -(math.pow(2, 20 * t - 10) * math.sin((t * 20 - 11.125) * math.pi * 2 / 4.5)) * .5
    else
        return (math.pow(2, -20 * t + 10) * math.sin((t * 20 - 11.125) * math.pi * 2 / 4.5)) * .5 + 1
    end
end
function Utils.bounceIn (t)
    return 1 - Utils.bounceOut(1 - t)
end
function Utils.bounceOut (t)
    local n1 = 7.5625;
    local d1 = 2.75;
    if t < 1 / d1 then
        return n1 * t * t;
    elseif t < 2 / d1 then
        t = t - 1.5 / d1
        return n1 * t * t + .75;
    elseif t < 2.5 / d1 then
        t = t - 2.25 / d1
        return n1 * t * t + .9375;
    else
        t = t - 2.625 / d1
        return n1 * t * t + .984375;
    end
end
function Utils.bounceInOut (t)
    if t < .5 then
        return (1 - Utils.bounceOut(1 - t + t)) * .5
    else
        return (1 + Utils.bounceOut(t + t - 1)) * .5
    end
end



function Utils.clamp (value, min, max)
    return math.min(math.max(min, value), max)
end
function Utils.mix (x, y, a)
    return x + (y - x) * a
end
function Utils.step (edge0, edge1, value)
    return math.min(math.max(0, (value - edge0) / (edge1 - edge0)), 1)
end
function Utils.smoothstep (edge0, edge1, value)
    local t = math.min(math.max(0, (value - edge0) / (edge1 - edge0)), 1)
    return t * t * (3 - t - t)
end

function Utils.bezier4 (q, x1, x2, x3, x4, y1, y2, y3, y4)
    local p = 1 - q
    local p2 = p * p
    local p3 = p2 * p
    local q2 = q * q
    local q3 = q2 * q
    local x = x1*p3 + 3*x2*p2*q + 3*x3*p*q2 + x4*q3
    local y = y4 and y1*p3 + 3*y2*p2*q + 3*y3*p*q2 + y4*q3
    return x, y
end

local TR = {
    s = {
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1,
        1.28667850207743,
        1.45,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
        1.2,
    },
    r = {
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        0,
        4.000000000018,
        8,
        -3.59978713504461e-11,
        -8,
        5,
        -5,
    },
    x = {
        0.755,
        0.66508669096853,
        0.57655829476603,
        0.50678592981168,
        0.475,
        0.48407341904521,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
    },
    y = {
        0.75,
        0.66256838326687,
        0.57647036188544,
        0.5085397237085,
        0.4775,
        0.48566607714069,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.5,
        0.55538482676619,
        0.68622584999265,
        0.86294511855821,
        1.06906255687805,
        1.2909349342613,
        1.5,
    },
}

local FRAMES = 35
local DIR_I = 135 / 180
local DIR_O = 90 / 180
local RT_I = 90.7 / 7.3
local RT_O = 200 / 7.3
local RN = 1
local DESIGN_H = 800
local ShinningScale = {
    name = "DragDown",

    context = nil,
    
    vs_motion = [[
        precision highp float;

        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;

        uniform vec2 u_screen_size;
        uniform vec2 u_position;
        uniform float u_scale;
        uniform float u_angle;

        #define attPosition aPosition
        #define attUV aTextureCoord

        varying vec2 v_uv;

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
            v_uv = transform(u_screen_size, u_screen_size, u_position, vec2(0.5), vec2(u_scale), u_angle, aTextureCoord);
            gl_Position = aPosition;
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
        uniform float u_intensity;
        varying vec2 v_uv;


        void main () {
            gl_FragColor = texture2D(u_src, v_uv) * u_intensity;
        }
    ]],

    renderPass = nil,
    blurPassC = nil,
    blurPassT = nil,
    cropPass = nil,
    frameWidth = 0,
    frameHeight = 0,

    percent = 0.0,
    duration = 1.0,

}

function ShinningScale:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs_motion, self.fs_motion)
    self.blurPassC = context:createCustomShaderPass(self.vs_blur, self.fs_blurC)
    self.blurPassT = context:createCustomShaderPass(self.vs_blur, self.fs_blurT)
    self.cropPass = context:createCustomShaderPass(self.vs_crop, self.fs_crop)
    return OF_Result_Success
end

function ShinningScale:clear(context)
    context:destroyCustomShaderPass(self.renderPass)
    context:destroyCustomShaderPass(self.blurPassC)
    context:destroyCustomShaderPass(self.blurPassT)
    context:destroyCustomShaderPass(self.cropPass)
    return OF_Result_Success
end

function ShinningScale:setDuration(filter, duration)
    self.duration = duration
end

function ShinningScale:seek(filter, timestamp)
    self.timestamp = timestamp
end

function ShinningScale:apply(filter)
    filter.animation.params.renderToRT = true
end

function ShinningScale:applyEffect(filter, outTex)
    local w, h = outTex.width, outTex.height
    self.timestamp = math.max(self.timestamp, 0.0)
    local progress =  math.fmod(self.timestamp, self.duration) / self.duration
    local s = math.min(w, h) / DESIGN_H
    local dw = s / w
    local dh = s / h
    local i = progress * FRAMES + 1
    local i0 = math.floor(i)
    local i1 = math.ceil(i)
    local t = i - i0
    local scale = Utils.mix(TR.s[i0], TR.s[i1], t)
    local angle = Utils.mix(TR.r[i0], TR.r[i1], t)
    local x = Utils.mix(TR.x[i0], TR.x[i1], t)
    local y = Utils.mix(TR.y[i0], TR.y[i1], t)
    
    local d, bt, Rn
    local enableblur = false
    if progress < 5/FRAMES then
        enableblur = true
        d = DIR_I
        bt = Utils.mix(RT_I, 0, Utils.step(0/FRAMES, 5/FRAMES, progress))
        Rn = Utils.mix(RN, 0, Utils.step(0/FRAMES, 5/FRAMES, progress))
    elseif progress > 28/FRAMES then
        enableblur = true
        d = DIR_O
        bt = Utils.mix(0, RT_O, Utils.step(28/FRAMES, 35/FRAMES, progress))
        Rn = Utils.mix(0, RN, Utils.step(28/FRAMES, 35/FRAMES, progress))
    else
        d = 0
        bt = 0
        Rn = 0
    end

    local context = filter.context
    context:setBlend(false)
    -- OF_LOGI(TAG, string.format("DragDown y0 = %f, dy0 = %f, dy1 = %f",y0,dy0,dy1))
    local tempTex = context:getTexture(outTex.width, outTex.height)
    context:bindFBO(outTex)
    context:setViewport(0, 0, outTex.width, outTex.height)
    context:setClearColor(0.0, 0.0, 0.0, 0.0)
    context:clearColorBuffer()

    self.renderPass:use()
    self.renderPass:setUniform2f("u_screen_size", w, h)
    self.renderPass:setUniform1f("u_scale", scale)
    self.renderPass:setUniform1f("u_angle", -angle)
    self.renderPass:setUniform2f("u_position", x, y)
    self.renderPass:setTexture("u_src", 0, filter.imageTex:toOFTexture())
    local quadRender = context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)

    if enableblur then
        context:bindFBO(tempTex:toOFTexture())
        self.blurPassT:use()
        -- gs1t
        self.blurPassT:setUniform1f("u_step_x", dw)
        self.blurPassT:setUniform1f("u_step_y", dh)
        self.blurPassT:setUniform1f("u_intensity", bt)
        self.blurPassT:setTexture("u_src", 0, outTex)
        self.blurPassT:setUniform1f("u_direction", -d)
        quadRender:draw(self.blurPassT, false)
        -- gs2t
        context:bindFBO(outTex)
        self.blurPassT:setUniform1f("u_intensity", bt * 0.5)
        self.blurPassT:setTexture("u_src", 0,  tempTex:toOFTexture())
        quadRender:draw(self.blurPassT, false)
        -- gs3t
        context:bindFBO(tempTex:toOFTexture())
        self.blurPassT:setUniform1f("u_intensity", bt * 0.25)
        self.blurPassT:setTexture("u_src", 0, outTex)
        quadRender:draw(self.blurPassT, false)
        -- gs4t
        context:bindFBO(outTex)
        self.blurPassT:setUniform1f("u_intensity", bt * 0.125)
        self.blurPassT:setTexture("u_src", 0,  tempTex:toOFTexture())
        quadRender:draw(self.blurPassT, false)
        -- gs1n
        context:bindFBO(tempTex:toOFTexture())
        self.blurPassT:setUniform1f("u_intensity", Rn)
        self.blurPassT:setTexture("u_src", 0, outTex)
        self.blurPassT:setUniform1f("u_direction", d+0.5)
        quadRender:draw(self.blurPassT, false)
        -- gs2n
        context:bindFBO(outTex)
        self.blurPassT:setUniform1f("u_intensity", Rn * 0.5)
        self.blurPassT:setTexture("u_src", 0, tempTex:toOFTexture())
        quadRender:draw(self.blurPassT, false)
    end
    context:bindFBO(tempTex:toOFTexture())
    self.cropPass:use()
    self.cropPass:setUniform1f("u_ratio", 1.0)
    local exposure = Utils.mix(1, 2.6 * 0.8, Utils.step(14/FRAMES, 15/FRAMES, progress) * Utils.step(19/FRAMES, 15/FRAMES, progress))
    self.cropPass:setUniform1f("u_intensity", exposure)
    self.cropPass:setTexture("u_src", 0,  outTex)
    quadRender:draw(self.cropPass, false)

    context:copyTexture(tempTex:toOFTexture(), outTex)

    context:releaseTexture(tempTex)
end

return ShinningScale