local Open = {
    duration = 1000,
    timestamp = 0,
    renderToRT = true,
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTexCoord;

        void main()
        {
            gl_Position = aPosition;
            vTexCoord = aTextureCoord.xy;
        }
        ]],
    fs = [[
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform float uEraseU;

        void main()
        {
            vec4 color = texture2D(uTexture0, vTexCoord);
            vec2 uv = vTexCoord * 2.0 - vec2(1.0);
            float r = abs(uv.x) - uEraseU;
            float a = 1.0 - smoothstep(-0.4, 0.0, r);
            gl_FragColor = color * a;
        }
        ]],
    renderPass = nil
}

function Open:init(filter)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function Open:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function Open:setDuration(filter, duration)
    self.duration = duration
end

function Open:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Open:applyEffect(label, inTex, outTex)
    if self.renderPass then
        label.context:bindFBO(outTex)
        label.context:setViewport(0, 0, outTex.width, outTex.height)
        label.context:setBlend(false)

        self.renderPass:use()
        self.renderPass:setUniformTexture("uTexture0", 0, inTex.textureID, TEXTURE_2D)
        self.renderPass:setUniform1f("uEraseU", self.timestamp / self.duration * 1.4)

        local quadRender = label.context:sharedQuadRender()
        quadRender:draw(self.renderPass, false)
    else
        OF_LOGI("TextAnimation", "Open pass is nil")
        label.context:copyTexture(inTex, outTex)
    end
end

function Open:apply(filter)
    --filter.animation.params.alpha = self.timestamp / self.duration
    --local count = #filter.label.chars
    --for i = 1, count do
    --    local char = filter.label.chars[i]
    --    char.color[4] = self.timestamp / self.duration
    --end
end

return Open