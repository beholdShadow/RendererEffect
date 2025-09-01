local SwirlRotateOut = {
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
        
        uniform mat4 uInvModel;
        uniform float uTexWidth;
        uniform float uTexHeight;

        uniform vec2 uOffset;
        uniform float uRadius;
        uniform float uAngle;

        uniform sampler2D uTexture0;

        const float PI = 3.141592653589793;

        vec2 swirl(vec2 uv)
        {
            float ratio = uTexWidth / uTexHeight;
            
            uv -= uOffset;
            uv.x = uv.x * ratio;
        
            float dist = length(uv);
            float percent = (uRadius - dist) / uRadius;
            if (percent < 1.0 && percent >= 0.0)
            {  
                float theta = percent * uAngle * PI / 2.0;
                float s = sin(theta);
                float c = cos(theta);
                
                uv = vec2(uv.x*c - uv.y*s, uv.x*s + uv.y*c);
            }

            uv.x = uv.x / ratio;
            uv += uOffset;
            uv = vec2(1.0 - abs(abs(uv.x) - 1.0), 1.0 - abs(abs(uv.y) - 1.0));
        
            return uv;
        }

        void main() {
            float ratio = uTexWidth / uTexHeight;
            
            vec2 uv = (uInvModel * vec4((vTexCoord.x * 2.0 - 1.0) * ratio, vTexCoord.y * 2.0 - 1.0, 0.0, 1.0)).xy;

            uv.x = (uv.x / ratio + 1.0) / 2.0;
            uv.y = (uv.y + 1.0) / 2.0;

            gl_FragColor = texture2D(uTexture0, swirl(uv)) * step(uv.x, 2.0) * step(uv.y, 2.0) * step(-1.0, uv.x) * step(-1.0, uv.y);
        }
        ]],
    renderPass = nil
}

function SwirlRotateOut:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
end

function SwirlRotateOut:clear(context)
    if self.renderPass ~= nil then
        context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function SwirlRotateOut:setDuration(filter, duration)
    self.duration = duration
end

function SwirlRotateOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function SwirlRotateOut:apply(filter)
    filter.animation.params.renderToRT = true
end

function SwirlRotateOut:applyEffect(filter, outTex)
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

    --second render rotate swirl effect
    local ratio = self.timestamp / self.duration
    local radian = -ratio * math.pi / 2
    local radius = ratio * math.min(filter.imageTex:width() * filter.params.scale, filter.imageTex:height() * filter.params.scale) / height
    local angle = -2.0
    local center = mvpMat * Vec4f.new(0.0, 0.0, 0.0, 1.0)

    local uvInvModel = Matrix4f:TransMat(center.x * width / height, center.y, 0.0) *
                    Matrix4f:RotMat(0, 0, radian) *
                    Matrix4f:TransMat(-center.x * width / height, -center.y, 0.0)

    -- OF_LOGI(TAG, string.format("w =%f h = %f w/h = %f h/w= %f", width, height, width/height, height/width))
    filter.context:bindFBO(outTex)
    filter.context:setViewport(0, 0, width, height)
    filter.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    filter.context:clearColorBuffer()
    filter.context:setBlend(false)

    self.renderPass:use()
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, Matrix4f:ScaleMat(1.0, 1.0, 1.0).x)
    self.renderPass:setUniformMatrix4fv("uInvModel", 1, 0, uvInvModel.x)
    self.renderPass:setUniform1f("uTexWidth", width)
    self.renderPass:setUniform1f("uTexHeight", height)
    self.renderPass:setUniform1f("uRadius", radius)
    self.renderPass:setUniform1f("uAngle", angle)
    self.renderPass:setUniform2f("uOffset", center.x / 2 + 0.5, center.y / 2 + 0.5)

    self.renderPass:setUniformTexture("uTexture0", 0, texTemp:textureID(), TEXTURE_2D)

    quadRender:draw(self.renderPass, false)

    filter.context:destroyTexture(texTemp)
end

return SwirlRotateOut