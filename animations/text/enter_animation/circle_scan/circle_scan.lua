local CircleScan = {
    tag = "CircleScan",
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
        uniform float uTexWidth;
        uniform float uTexHeight;

        const float PI = 3.1415926;

        float atan2(float a, float b)
        {
            if(a == 0.0 && b == 0.0)
                return 0.0;
            if(a == 0.0)
                return PI * (0.5 + step(b, 0.0));
            if(b == 0.0)
                return PI * step(a, 0.0);
            if (a > 0.0 && b > 0.0)
                return atan(b / a);
            if (a < 0.0 && b > 0.0)
                return atan(-1.0 * a / b) + PI / 2.0;
            if (a < 0.0 && b < 0.0)
                return atan(b / a) + PI;
            if (a > 0.0 && b < 0.0)
                return atan(-1.0 * a / b) + PI * 3.0 / 2.0;
        }
        void main()
        {
            vec4 color2 = texture2D(uTexture0, vTexCoord);
            float w = 0.2;
            float theta = atan2(uTexHeight *(0.5 - vTexCoord.y), uTexWidth * (vTexCoord.x-0.5));
            float alpha = clamp(1.0 / w * theta + 1.0 + uRatio * (-2.0 * PI / w - 1.0), 0.0, 1.0);
            gl_FragColor = mix(color2, vec4(0.0, 0.0, 0.0, 0.0), alpha);
        }
        ]],
    renderPass = nil
}

function CircleScan:init(filter)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function CircleScan:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function CircleScan:setDuration(filter, duration)
    self.duration = duration
end

function CircleScan:seek(filter, timestamp)
    self.timestamp = timestamp
end

function CircleScan:apply(filter, outTex) 
end

function CircleScan:applyEffect(label, srcTex, dstTex)
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

return CircleScan