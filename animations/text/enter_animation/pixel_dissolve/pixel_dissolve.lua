local PixelDissolve = {
    tag = "PixelDissolve",
    duration = 1000,
    timestamp = 0,
    renderToRT = true,
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
        uniform sampler2D uTexture0;
        uniform float uRatio;
        uniform float uTexWidth;
        uniform float uTexHeight;

        float random(vec2 st) {
            return fract(sin(dot(st.xy,vec2(12.9898, 78.233))) * 43758.5453123);
        }

        void main()
        {
            vec4 color1 = texture2D(uTexture0, vTexCoord);
            vec2 gridNum = vec2(clamp(uTexWidth / 5.0, 30.0, 100.0), clamp(uTexHeight / 5.0, uTexHeight / uTexWidth * 30.0, uTexHeight / uTexWidth * 100.0));
            float x = floor(vTexCoord.x * gridNum.x) * 1.0 / gridNum.x;
            float y = floor(vTexCoord.y * gridNum.y) * 1.0 / gridNum.y;
            float randomNum = random(vec2(x, y));
            gl_FragColor = mix(vec4(0.0, 0.0, 0.0, 0.0), color1, step(randomNum, uRatio));
        }
        ]],
    renderPass = nil
}

function PixelDissolve:init(filter)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function PixelDissolve:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function PixelDissolve:setDuration(filter, duration)
    self.duration = duration
end

function PixelDissolve:seek(filter, timestamp)
    self.timestamp = timestamp
end

function PixelDissolve:apply(filter, outTex) 
end

function PixelDissolve:applyEffect(label, srcTex, dstTex)
    if #label.chars <= 0 then
        return
    end

    local ratio = self.timestamp / self.duration
    local mvpMat = Matrix4f:ScaleMat(1.0, 1.0, 1.0)

    label.context:bindFBO(dstTex)
    label.context:setViewport(0, 0, dstTex.width, dstTex.height)
    label.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    label.context:clearColorBuffer()
    self.renderPass:use()
    self.renderPass:setUniform1f("uRatio", ratio)    
    self.renderPass:setUniform1f("uTexWidth", dstTex.width)
    self.renderPass:setUniform1f("uTexHeight", dstTex.height)
    self.renderPass:setUniformTexture("uTexture0", 0, srcTex.textureID, TEXTURE_2D)
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = label.context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)

    -- context:copyTexture(srcTex,dstTex);
end

return PixelDissolve