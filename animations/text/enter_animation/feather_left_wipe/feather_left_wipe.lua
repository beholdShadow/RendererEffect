local FeatherLeftWipe = {
    tag = "FeatherLeftWipe",
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
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform float uRatio;

        void main()
        {
            float w = 0.5;
            float alpha = clamp(-1.0 / w * vTexCoord.x + (1.0 + w) / w + uRatio * (-(1.0 + w) / w), 0.0, 1.0);

            vec4 color1 = vec4(0.0, 0.0, 0.0, 0.0);
            vec4 color2 = texture2D(uTexture0, vTexCoord);

            gl_FragColor = mix(color2, vec4(0.0, 0.0, 0.0, 0.0), alpha);
        }
        ]],
    renderPass = nil
}

function FeatherLeftWipe:init(filter)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function FeatherLeftWipe:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function FeatherLeftWipe:setDuration(filter, duration)
    self.duration = duration
end

function FeatherLeftWipe:seek(filter, timestamp)
    self.timestamp = timestamp
end

function FeatherLeftWipe:apply(filter, outTex) 
end

function FeatherLeftWipe:applyEffect(label, srcTex, dstTex)
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
    self.renderPass:setUniformTexture("uTexture0", 0, srcTex.textureID, TEXTURE_2D)
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = label.context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)

    -- context:copyTexture(srcTex,dstTex);
end

return FeatherLeftWipe