local Sunset = {
    tag = "Sunset",
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
            vec4 resColor;
            if (vTexCoord.y >= uRatio)
                resColor = texture2D(uTexture0, vec2(vTexCoord.x, vTexCoord.y - uRatio));
            else
                resColor = vec4(0.0, 0.0, 0.0, 0.0);
            gl_FragColor = resColor;

        }
        ]],
    renderPass = nil
}

function Sunset:init(filter)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function Sunset:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function Sunset:setDuration(filter, duration)
    self.duration = duration
end

function Sunset:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Sunset:apply(filter, outTex) 
end

function Sunset:applyEffect(label, srcTex, dstTex)
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

return Sunset