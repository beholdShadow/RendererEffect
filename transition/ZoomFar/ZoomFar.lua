TAG = "Transition-Up"
local TextureRender = require "common.texture"
OF_LOGI(TAG, "Call transition lua script!")

local Filter = {
    name = "Transition-Up",

    context = nil,

    vs = [[
        precision highp float;

        attribute vec4 aPosition;

        attribute vec2 aTextureCoord;
        varying vec2 vTexCoord;

        // vertex shader
        void main() {
            gl_Position = aPosition;
            vTexCoord = aTextureCoord;
        }
    ]],

    fs = [[
        precision highp float;
        varying vec2 vTexCoord;
        uniform float progress;
        uniform int inputWidth;
        // transitions interface
        uniform sampler2D uTextureFrom;
        // transitions interface
        uniform sampler2D uTextureTo;
        
        #define EPSILON 0.000001    
        #define uv0 vTexCoord
        #define inputImageTexture uTextureFrom
        #define inputImageTexture2 uTextureTo
        
        vec2 zoomNear(vec2 uv, float amount){
            vec2 UV = vec2(0.0);
            if(amount < 0.5-EPSILON){       //correct critical precision
                UV = 0.5 + ((uv - 0.5)*(1.0 - amount));
            }else{
                UV = 0.5 + ((uv - 0.5)*(2.0 - amount));
            }
            return UV;
        }
        vec2 zoomFar(vec2 uv, float amount){
            vec2 UV = vec2(0.0);
            if(amount < 0.5-EPSILON){       //correct critical precision
                UV = 0.5 + ((uv - 0.5)*(1.0 + amount));
            }else{
                UV = 0.5 + ((uv - 0.5)*(amount));
            }
            return UV;
        }
        vec3 blur(sampler2D Tex, vec2 uv, float iTime, float pixelStep){
            
            vec2 dir = uv - 0.5;//方向
            // float dist = length(dir);
            // dir = normalize(dir);//单位向量
            vec3 color = vec3(0.0);
            const int len = 10;
            for(int i= -len; i <= len; i++){
                vec2 blurCoord = uv + pixelStep*float(i)*dir*2.0*iTime;
                blurCoord = abs(blurCoord);
                if(blurCoord.x > 1.0){
                    blurCoord.x = 2.0 - blurCoord.x;
                }
                if(blurCoord.y > 1.0){
                    blurCoord.y = 2.0 - blurCoord.y;
                }
                color += texture2D(Tex, blurCoord).rgb;
            }
            color /= float(2*len+1);
            return color;
        }
        float easeInOutQuint(float t) 
        { 
            return t<0.5 ? 16.0*t*t*t*t*t : 1.0+16.0*(--t)*t*t*t*t; 
        }
        
        void main() {
            float pixelStep = 10.0/float(inputWidth) * 0.6;
            float TT = easeInOutQuint(progress);
            vec2 uv1 = zoomFar(uv0, TT);
            
            if(TT <= 0.5){
                gl_FragColor = vec4(blur(inputImageTexture, uv1, TT, pixelStep), texture2D(inputImageTexture, uv1).a);
            }else{
                gl_FragColor = vec4(blur(inputImageTexture2, uv1, 1.0 - TT, pixelStep), texture2D(inputImageTexture2, uv1).a);
            }
            
        }
    ]], 

    renderPass = nil,

    frameWidth = 0,
    frameHeight = 0,

    percent = 0.0,
    duration = 1.0,

}

function Filter:initParams(context, filter)
    filter:insertFloatParam("Duration", 0.0, 2.0, self.duration)
    return OF_Result_Success
end

function Filter:onApplyParams(context, filter)
    return OF_Result_Success
end

function Filter:initRenderer(context, filter)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
    TextureRender:initRenderer(context, filter)
    return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
    context:destroyCustomShaderPass(self.renderPass)
	TextureRender:teardown(context)
    return OF_Result_Success
end

function Filter:applyFrame(context, filter, frameData, inArray, outArray)
    if inArray[2] == nil then 
        context:copyTexture(inArray[1], outArray[1])
        return OF_Result_Success
    end

    OF_LOGI(TAG, string.format("lua apply frame applyFrame inArray.width: %d, inArray.height: %d, inArray.pixelScale: %f, outTexArray[1].scale: %f, outTexArray[1].width: %d, outTexArray[1].height: %d", 
        inArray[1].width, inArray[1].height,
        inArray[1].pixelScale, outArray[1].pixelScale,
        outArray[1].width, outArray[1].height))
    context:setBlend(false)	
    local tempTex1 = context:getTexture(PixelSize.new(inArray[1].width * 0.25, inArray[1].height * 0.25, outArray[1].pixelScale))
    local tempTex2 = context:getTexture(PixelSize.new(inArray[2].width * 0.25, inArray[2].height * 0.25, outArray[1].pixelScale))
    TextureRender:setColor(Vec4f.new(1.0, 1.0, 1.0, 1.0))
	TextureRender:draw(context, inArray[1], tempTex1:toOFTexture(),  Matrix4f:ScaleMat(1.0, 1.0, 1.0))
    TextureRender:draw(context, inArray[2], tempTex2:toOFTexture(),  Matrix4f:ScaleMat(1.0, 1.0, 1.0))

    local tempTex3 = context:getTexture(PixelSize.new(outArray[1].width * 0.25, outArray[1].height * 0.25, outArray[1].pixelScale))

    local timestamp = filter:filterTimestamp()
    if timestamp < self.duration then
        self.percent = timestamp / self.duration
    else
        self.percent = 1.0
    end
    if inArray[2] ~= nil then
        context:bindFBO(tempTex3:toOFTexture())
        context:setViewport(PixelSize.new(tempTex3:width(), tempTex3:height(), outArray[1].pixelScale))

        self.renderPass:use()
        self.renderPass:setUniform1f("progress", self.percent)
        self.renderPass:setUniform1i("inputWidth", tempTex3:width() * outArray[1].pixelScale)

        self.renderPass:setTexture("uTextureFrom", 0, tempTex1:toOFTexture())
        self.renderPass:setTexture("uTextureTo", 1, tempTex2:toOFTexture())

        local quadRender = context:sharedQuadRender()
        quadRender:draw(self.renderPass, false)
    end

    context:setBlend(true)	

    TextureRender:draw(context, tempTex3:toOFTexture(), outArray[1], Matrix4f.new())

    if outArray[2] ~= nil then
        context:copyTexture(inArray[1], outArray[2])
    end

    if tempTex1 then context:releaseTexture(tempTex1) end
    if tempTex2 then context:releaseTexture(tempTex2) end
    if tempTex3 then context:releaseTexture(tempTex3) end
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