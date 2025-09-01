local RightRotate = {
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
        uniform sampler2D uTexture0;
        
        const float PI = 3.141592653589793;
        
        void main() {
            float ratio = uTexWidth / uTexHeight;
            
            vec2 uv = (uInvModel * vec4((vTexCoord.x * 2.0 - 1.0) * ratio, vTexCoord.y * 2.0 - 1.0, 0.0, 1.0)).xy;

            uv.x = (uv.x / ratio + 1.0) / 2.0;
            uv.y = (uv.y + 1.0) / 2.0;
        
            gl_FragColor = texture2D(uTexture0, uv) * step(uv.x, 1.0) * step(uv.y, 1.0) * step(0.0, uv.x) * step(0.0, uv.y);
        }
        ]],
    renderPass = nil,
    copyPass = nil
}

function RightRotate:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
end

function RightRotate:clear(context)
    if self.renderPass ~= nil then
        context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function RightRotate:setDuration(filter, duration)
    self.duration = duration
end

function RightRotate:seek(filter, timestamp)
    self.timestamp = timestamp
end

function RightRotate:apply(filter)
    filter.animation.params.renderToRT = true
end

function RightRotate:applyEffect(filter, outTex)
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

    -- filter.context:bindFBO(texTemp:toOFTexture())
    filter:drawFrame(filter.context, nil, texTemp:toOFTexture(), mvpMat)
    
    --second render rotate motion blur effect
    local ratio = self.timestamp / self.duration
    local radian = -(1.0 - ratio) * math.pi / 2
    
    local center = mvpMat * Vec4f.new(0.0, 0.0, 0.0, 1.0)
    local uvInvModel =  Matrix4f:TransMat(-0.5 * (1.0 - ratio) * width / height, 0.0, 0.0) * Matrix4f:TransMat(center.x * width / height, center.y, 0.0) * 
                Matrix4f:RotMat(0, 0, radian) * 
                Matrix4f:TransMat(-center.x * width / height, -center.y, 0.0)
    uvInvModel = uvInvModel:inverted()           
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
    self.renderPass:setUniformTexture("uTexture0", 0, texTemp:textureID(), TEXTURE_2D)

    quadRender:draw(self.renderPass, false)

    filter.context:destroyTexture(texTemp)
end

return RightRotate