local Wave = {
    tag = "Wave",
    duration = 1000,
    timestamp = 0,
    renderToRT = true,
    extraSpace = true,
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
    fs_wave = [[
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform float uRatio;

        const float PI = 3.1415926;

        void main()
        {
            vec2 texCoord = vTexCoord;
            texCoord.y = texCoord.y + 0.075 * sin(2.0 * PI * (uRatio + 2.0 * (1.0 - texCoord.x)));
            float clamp = smoothstep(-0.02, 0.0, texCoord.y) - smoothstep(0.0, 0.02, texCoord.y - 1.0);
            gl_FragColor = texture2D(uTexture0, texCoord) * vec4(clamp);
        }
        ]],
    wavePass = nil
}

function Wave:init(filter)
    self.wavePass = filter.context:createCustomShaderPass(self.vs, self.fs_wave)
end

function Wave:clear(filter)
    if self.wavePass ~= nil then
        filter.context:destroyCustomShaderPass(self.wavePass)
        self.wavePass = nil
    end
end

function Wave:setDuration(filter, duration)
    self.duration = duration
end

function Wave:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Wave:apply(filter, outTex) 
end

function Wave:applyEffect(label, srcTex, dstTex)
    if #label.chars <= 0 then
        return
    end

    local ratio = self.timestamp / self.duration - math.floor(self.timestamp / self.duration)
    local mvpMat = Matrix4f:ScaleMat(1.0, 1.0, 1.0)

    label.context:bindFBO(dstTex)
    label.context:setViewport(0, 0, dstTex.width, dstTex.height)
    label.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    label.context:clearColorBuffer()
    self.wavePass:use()
    self.wavePass:setUniform1f("uRatio", ratio)
    self.wavePass:setUniformTexture("uTexture0", 0, srcTex.textureID, TEXTURE_2D)
    self.wavePass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = label.context:sharedQuadRender()
    quadRender:draw(self.wavePass, false)

    -- context:copyTexture(srcTex,dstTex);
end

return Wave