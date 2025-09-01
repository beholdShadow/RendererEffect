
local WordColorBlocks = {
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
    fs_block = [[
        #extension GL_OES_standard_derivatives : enable
        precision mediump float;
        varying vec2 vTexCoord;
        
        uniform vec4 uColor;
        uniform float uWidth;
        uniform float uHeight;
        uniform float uRadius;
        const float featherPixel = 2.0;
        void main()
        {
            vec2  border = vec2(featherPixel / uWidth, featherPixel / uHeight);
            vec2  smoothVal = smoothstep(vec2(0.0), border, vTexCoord) - smoothstep(border * vec2(-1.0), vec2(0.0), vTexCoord- vec2(1.0));
            vec2 transUV = abs(vTexCoord * 2.0 - vec2(1.0, 1.0)) * vec2(uWidth / 2.0, uHeight / 2.0);
            vec2 center = vec2(uWidth / 2.0 - uRadius, uHeight / 2.0 - uRadius);
            vec2 delta = transUV - center;
            float firstQuadrant = step(0.0, delta.x) * step(0.0, delta.y);
            float corner = mix(1.0, 1.0 - smoothstep((uRadius - featherPixel) * (uRadius - featherPixel), uRadius * uRadius, dot(delta, delta)), firstQuadrant);
            gl_FragColor = vec4(uColor.rgb,  uColor.a * smoothVal.x * smoothVal.y * corner);
        }
        ]],
    blockPass = nil,
    background = {
        xpadding = 5,
        ypadding = 5,
        radius = 10,
        color =  Vec4f.new(128.0 / 255, 77.0 / 255, 236.0 / 255, 1.0)
    }
}

function WordColorBlocks:split(s,re,plain,n)
    local find,sub,append = string.find, string.sub, table.insert
    local i1,ls = 1,{}
    if not re then re = '%s+' end
    if re == '' then return {s} end
    while true do
        local i2,i3 = find(s,re,i1,plain)
        if not i2 then
            local last = sub(s,i1)
            if last ~= '' then append(ls,last) end
            if #ls == 1 and ls[1] == '' then
                return {}
            else
                return ls
            end
        end
        append(ls,sub(s,i1,i2-1))
        if n and #ls == n then
            ls[#ls] = sub(s,i1)
            return ls
        end
        i1 = i3+1
    end
end

function WordColorBlocks:init(filter)
    self.blockPass = filter.context:createCustomShaderPass(self.vs, self.fs_block)
    self.firstIdx = math.random(1,4)
end

function WordColorBlocks:clear(filter)
    if self.blockPass ~= nil then
        filter.context:destroyCustomShaderPass(self.blockPass)
        self.blockPass = nil
    end
end

function WordColorBlocks:setDuration(filter, duration)
    self.duration = duration
end

function WordColorBlocks:seek(filter, timestamp)
    self.timestamp = timestamp
end

function WordColorBlocks:linearstep(edge0, edge1, x) 
    return math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
end

function WordColorBlocks:clamp(x, min, max)
    return math.max(math.min(x, max), min)
end

function WordColorBlocks:squarestep(edge0, edge1, x) 
    x = math.min(1.0, math.max(0.0, (x - edge0) / (edge1 - edge0)))
    return x * x
end

function WordColorBlocks:smoothstep(edge0, edge1, x) 
    x = self.clamp(self, (x - edge0) / (edge1 - edge0), 0.0, 1.0)
    return x * x * (3 - 2 * x)
end

local function funcEaseAction3(t, b, c)
    if t~=0.0 and t~=1.0 then
        t = math.exp(-7.0 * t) * 1.0 * math.sin((t - 0.075) * (2.0*math.pi) / 0.3) + 1.0
    end
    return t * c + (1.0 - t) * b
end

local LabelTag = "OF-LabelPro"
function WordColorBlocks:apply(filter, outTex)
    filter.label:flush(filter.context)

    if #filter.label.chars <= 0 then
        return
    end

    local splitWord = {}
    local curWord = {}
    local charIdx = 1
    
    local colorArr = {}
    table.insert(colorArr,  Vec4f.new(42.0 / 255, 185.0 / 255, 87.0 / 255, 1.0)) --GREEN
    table.insert(colorArr,  Vec4f.new(128.0 / 255, 77.0 / 255, 236.0 / 255, 1.0)) -- PURPLE
    table.insert(colorArr,  Vec4f.new(255.0 / 255, 48.0 / 255, 53.0 / 255, 1.0)) --RED
    table.insert(colorArr,  Vec4f.new(1.0, 1.0, 1.0, 1.0)) --white
    local colorIdx = {self.firstIdx, 4, 2, 4, 3, 4, 4, 1, 3, 4, 4, 1, 4, 4, 1, 2, 1, 4, 4, 1, 4, 4, 1, 3, 1, 4, 2, 2, 4, 2, 4, 3, 2, 4, 2, 4, 4, 1, 4, 1, 1}
    for p, c in utf8.codes(filter.label.textString) do
        if c == 10 or c == 32 then
            if #curWord > 0 then 
                table.insert(splitWord, curWord)
                curWord = {}
            end
        else 
            local char = filter.label.chars[charIdx]
            char.index = charIdx
            char.color =  colorArr[math.random(1, #colorArr)]
            table.insert(curWord, char)
            charIdx = charIdx + 1
        end
    end
    if #curWord > 0 then 
        table.insert(splitWord, curWord)
    end
    local wordDuration = self.duration / #splitWord
    local index = math.max(math.ceil(self.timestamp / wordDuration), 1)
    curWord = splitWord[index]
    local wordBox= { minX = 10000, maxX = -10000, maxY = -10000, minY = 10000}
    for i = 1, #curWord do
        local charBackup = filter.label.charsBackup[curWord[i].index]
        for j = 1, 4 do
            wordBox.minX = math.min(wordBox.minX, charBackup.pos[2*j-1])
            wordBox.maxX = math.max(wordBox.maxX, charBackup.pos[2*j-1])
            wordBox.minY = math.min(wordBox.minY, charBackup.pos[2*j])
            wordBox.maxY = math.max(wordBox.maxY, charBackup.pos[2*j])
        end
        wordBox.baseline = charBackup.baseline
    end
    
    self:generateBgMesh(wordBox)

    local frameWidth, frameHeight = outTex.width, outTex.height
    local textRotMat = Matrix4f:RotMat(0, 0, filter.label.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(filter.label.textTransX, filter.label.textTransY, 0.0)
    local mvpMat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
        * textTransMat * filter.label.anchor.transMat * textRotMat * filter.label.anchor.scaleMat
    filter.context:bindFBO(outTex)
    filter.context:setViewport(0, 0, frameWidth, frameHeight)
    filter.context:setBlend(true)
    filter.context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)
    self.blockPass:use()
    self.blockPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)
    self.blockPass:setUniform1f("uWidth", wordBox.maxX - wordBox.minX)
    self.blockPass:setUniform1f("uHeight", wordBox.maxY - wordBox.minY)
    self.blockPass:setUniform1f("uRadius", self.background.radius * (filter.label.textScaleX + filter.label.textScaleY) * 0.5)
    self.blockPass:setUniform4f("uColor", self.background.color.x, self.background.color.y, self.background.color.z, self.background.color.w)
    self.backgroundMeshBatch:draw(self.blockPass, false)

end

function WordColorBlocks:generateBgMesh(wordBox)
    self.background.pos = {
        wordBox.minX - self.background.xpadding, wordBox.maxY + self.background.ypadding,
        wordBox.maxX + self.background.xpadding, wordBox.maxY + self.background.ypadding,
        wordBox.maxX + self.background.xpadding, wordBox.minY - self.background.ypadding,
        wordBox.minX - self.background.xpadding, wordBox.minY - self.background.ypadding
        }
    self.background.uv = { 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0 }
    local mesh2dPosition = FloatArray.new(8)
    mesh2dPosition:copyFromTable(self.background.pos)

    if self.backgroundMeshBatch == nil then
        local mesh2dTexCoord = FloatArray.new(8)
        mesh2dTexCoord:copyFromTable(self.background.uv)

        local indices = IntArray.new(3 * 2)
        indices:set(0,  0)
        indices:set(1,  2)
        indices:set(2,  1)
        indices:set(3,  0)
        indices:set(4,  3)
        indices:set(5,  2)
        self.backgroundMeshBatch = Mesh2dRender.new(mesh2dPosition, mesh2dTexCoord, 4, indices, 6)
    else
        self.backgroundMeshBatch:updateSubPositions(mesh2dPosition, 4)
    end
end

return WordColorBlocks
