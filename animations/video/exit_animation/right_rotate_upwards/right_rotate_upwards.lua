local RightRotateUpwards = {
    duration = 1000,
    timestamp = 0,
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTexCoord;
        uniform mat4 uMVP;

        void main()
        {
            gl_Position = uMVP * aPosition;
            vTexCoord = aTextureCoord.xy;
        }
        ]],
    fs = [[
        precision highp float;
        varying vec2 vTexCoord;
        
        uniform vec2 center;
        uniform float blurScale;    
        uniform mat4 uInvModel;
        uniform float uTexWidth;
        uniform float uTexHeight;
        uniform sampler2D uTexture0;

        #define BLUR_TYPE 0
        
        #define BLUR_MOTION 0x1
        #define BLUR_SCALE  0x2

        #if BLUR_TYPE == BLUR_SCALE
        #define num 25
        #else
        #define num 7
        #endif
        
        const float PI = 3.141592653589793;
        
        void main() {
            float ratio = uTexWidth / uTexHeight;
        
            const int rotateNum = 10;
            float rotateAngle = blurScale * PI / 400.0;
        
            float fRotateNum = float(rotateNum);
            mat2 startRotateMat = mat2(cos(-rotateAngle * fRotateNum), sin(-rotateAngle * fRotateNum), -sin(-rotateAngle * fRotateNum), cos(-rotateAngle * fRotateNum));    
            mat2 stepRotateMat = mat2(cos(rotateAngle), sin(rotateAngle), -sin(rotateAngle), cos(rotateAngle));
        
            vec2 uv_ori = vTexCoord * vec2(ratio, 1.0);
            uv_ori = (uInvModel * vec4(uv_ori.x * 2.0 - ratio, uv_ori.y * 2.0 - 1.0, 0.0, 1.0)).xy;
            uv_ori.x = (uv_ori.x / ratio + 1.0) / 2.0;
            uv_ori.y = (uv_ori.y + 1.0) / 2.0;
            uv_ori = vec2(1.0 - abs(abs(uv_ori.x) - 1.0), 1.0 - abs(abs(uv_ori.y) - 1.0));
            float A = texture2D(uTexture0, uv_ori).a;
        
            vec2 uv = vTexCoord * vec2(ratio, 1.0);
            vec2 ct = center * vec2(ratio, 1.0);
            uv = startRotateMat * (uv - ct) + ct;
        
            vec4 color = vec4(0.0);
            float sumA = 0.0;
            for(int i = -rotateNum + 1; i < rotateNum; i++) {
                uv = stepRotateMat * (uv - ct) + ct;
                
                vec2 uvT = (uInvModel * vec4(uv.x * 2.0 - ratio, uv.y * 2.0 - 1.0, 0.0, 1.0)).xy;
                uvT.x = (uvT.x / ratio + 1.0) / 2.0;
                uvT.y = (uvT.y + 1.0) / 2.0;
                uvT = vec2(1.0 - abs(abs(uvT.x) - 1.0), 1.0 - abs(abs(uvT.y) - 1.0));
                vec4 clr = texture2D(uTexture0, uvT);
                color += clr * clr.a * step(uvT.x, 1.0) * step(uvT.y, 1.0) * step(0.0, uvT.x) * step(0.0, uvT.y);
                sumA += clr.a;
            }
            color /= sumA;	
            
            color.a = A;
        
            gl_FragColor = color * ceil(A);
        }
        ]],
    renderPass = nil,
    copyPass = nil
}

function RightRotateUpwards:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
end

function RightRotateUpwards:clear(context)
    if self.renderPass ~= nil then
        context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function RightRotateUpwards:setDuration(filter, duration)
    self.duration = duration
end

function RightRotateUpwards:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RightRotateUpwards:apply(filter)
    filter.animation.params.renderToRT = true
end

function RightRotateUpwards:applyEffect(filter, outTex)
    --first render imageTex to output viewport
    local width, height = outTex.width, outTex.height
	local quadRender = filter.context:sharedQuadRender()

	local scaleMat = Matrix4f:ScaleMat(filter.params.scale, filter.params.scale, 1.0)
	local rotMat = Matrix4f:RotMat(0, 0, filter.params.rot)
	local transMat = Matrix4f:TransMat(filter.params.tx, filter.params.ty, 0.0)

	local mvpMat =
		Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) *
		transMat * rotMat * scaleMat *
		Matrix4f:ScaleMat(filter.imageTex:width() * 0.5, filter.imageTex:height() * 0.5, 1)
   
    local texTemp = filter.context:createTexture(width, height)

    filter:drawFrame(filter.context, nil, texTemp:toOFTexture(), mvpMat)

    --second render rotate motion blur effect
    local blurScale = (self.timestamp / self.duration) ^2
    local radian = self.timestamp / self.duration * -math.pi / 2
    
    local center = mvpMat * Vec4f.new(1.0, 0.0, 0.0, 1.0)

    local uvInvModel = Matrix4f:TransMat(center.x * width / height, center.y, 0.0) *
                    Matrix4f:RotMat(0, 0, radian) *
                    Matrix4f:TransMat(-center.x * width / height, -center.y, 0.0)

    -- OF_LOGI(TAG, string.format("center.x =%f center.y = %f", center.x, center.y))
    filter.context:bindFBO(outTex)
    filter.context:setViewport(0, 0, width, height)
    filter.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    filter.context:clearColorBuffer()
    filter.context:setBlend(false)

    self.renderPass:use()
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, Matrix4f:ScaleMat(1.0, 1.0, 1.0).x)
    self.renderPass:setUniformMatrix4fv("uInvModel", 1, 0, uvInvModel.x)
    self.renderPass:setUniform1f("blurScale", blurScale)
    self.renderPass:setUniform1f("uTexWidth", width)
    self.renderPass:setUniform1f("uTexHeight", height)
    self.renderPass:setUniformTexture("uTexture0", 0, texTemp:textureID(), TEXTURE_2D)
    self.renderPass:setUniform2f("center", center.x, center.y)

    quadRender:draw(self.renderPass, false)

    filter.context:destroyTexture(texTemp)
end

return RightRotateUpwards