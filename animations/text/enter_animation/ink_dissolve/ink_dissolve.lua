local InkDissolve = {
    tag = "InkDissolve",
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
        uniform sampler2D uNoise;
        uniform float uRatio;

        void main()
        {
            vec4 noiseColor = texture2D(uNoise, vTexCoord);
            vec4 mainColor = texture2D(uTexture0, vTexCoord);
            gl_FragColor = mainColor * smoothstep(clamp(noiseColor.r - 0.1,0.0,1.0),clamp(noiseColor.r + 0.1,0.0,1.0),uRatio);
        }
        ]],
        
    renderPass = nil,
    imageTex = nil
}

function InkDissolve:init(filter)
    local currentDir = debug.getinfo(1).source:match("@?(.*/)")
    local imagePath = currentDir .. "noise.png"
    self.imageTex = filter.context:loadTextureFromFile(imagePath, TEXTURE_2D, LINEAR, CLAMP_TO_EDGE, false, false)
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function InkDissolve:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function InkDissolve:setDuration(filter, duration)
    self.duration = duration
end

function InkDissolve:seek(filter, timestamp)
    self.timestamp = timestamp
end

function InkDissolve:apply(filter, outTex) 
end

function InkDissolve:applyEffect(label, srcTex, dstTex)
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
    self.renderPass:setUniformTexture("uNoise", 1, self.imageTex:textureID(), TEXTURE_2D)
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = label.context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)

    -- context:copyTexture(srcTex,dstTex);
end

return InkDissolve