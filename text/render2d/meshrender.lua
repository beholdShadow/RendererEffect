local class = require 'pl.class'
MeshRender = class()

function MeshRender:_init()
    self.vs = [[
        precision highp float;
        uniform mat4 uMVP;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        attribute vec4 aColor;
        attribute vec4 aOutlineColor;
        varying vec2 vTexCoord;
        varying vec4 vColor;
        varying vec4 vOutlineColor;
        void main()
        {
            gl_Position = uMVP * aPosition;
            vTexCoord = aTextureCoord.xy;
            vColor = aColor;
            vOutlineColor = aOutlineColor;
        }
        ]]
    self.fs = [[
        precision mediump float;
        uniform vec4 uColor;
        varying vec2 vTexCoord;
        varying vec4 vColor;
        varying vec4 vOutlineColor;
        void main()
        {
            gl_FragColor = vColor + vec4(vTexCoord, 1.0, 1.0);
        }
        ]]
    self.context = nil
    self.pass = nil
    self.posVbo = nil
    self.uv0Vbo = nil
    self.uv1Vbo = nil
    self.uv1Enabeld = false
    self.colorVbo = nil
    self.outlineColorVbo = nil
    self.ibo = nil
    self.indicesCount = 0
end

function MeshRender:init(context)
    self.context = context
    --self.pass = context:createCustomShaderPass(self.vs, self.fs)

    local posData = { -0.5,  0.5, 0.5,  0.5, 0.5, -0.5, -0.5, -0.5 }
    local posArr = FloatArray.new(#posData)
    posArr:copyFromTable(posData)
    self.posVbo = context:createVertexBuffer(posArr, DYNAMIC_DRAW)

    local uvData = { 0.0, 1.0, 1.0, 1.0, 1.0, 0.0, 0.0, 0.0 }
    local uvArr = FloatArray.new(#uvData)
    uvArr:copyFromTable(uvData)
    self.uv0Vbo = context:createVertexBuffer(uvArr, DYNAMIC_DRAW)
    self.uv1Vbo = context:createVertexBuffer(uvArr, DYNAMIC_DRAW)

    local colorData = { 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0 }
    local colorArr = FloatArray.new(#colorData)
    colorArr:copyFromTable(colorData)
    self.colorVbo = context:createVertexBuffer(colorArr, DYNAMIC_DRAW)

    local outlineColorData = { 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0, 1.0, 0.0, 0.0, 1.0 }
    local outlineColorArr = FloatArray.new(#outlineColorData)
    outlineColorArr:copyFromTable(outlineColorData)
    self.outlineColorVbo = context:createVertexBuffer(outlineColorArr, DYNAMIC_DRAW)

    local indicesData = { 0, 2, 1, 0, 3, 2 }
    local data = Uint16Array.new(#indicesData)
    data:copyFromTable(indicesData)
    self.ibo = context:createIndexBuffer(data, DYNAMIC_DRAW)
    self.indicesCount = 6
end

function MeshRender:teardown(context)
    --if self.pass then context:destroyCustomShaderPass(self.pass) end
    if self.posVbo then context:destroyBuffer(self.posVbo) end
    if self.uv0Vbo then context:destroyBuffer(self.uv0Vbo) end
    if self.uv1Vbo then context:destroyBuffer(self.uv1Vbo) end
    if self.colorVbo then context:destroyBuffer(self.colorVbo) end
    if self.outlineColorVbo then context:destroyBuffer(self.outlineColorVbo) end
    if self.ibo then context:destroyBuffer(self.ibo) end
end

-- data is a FloatArray
function MeshRender:updatePositions(data)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    if data:size() > self.posVbo:size() / FLOAT_SIZE then
        if self.posVbo then self.context:destroyBuffer(self.posVbo) end
        self.posVbo = self.context:createVertexBuffer(data, DYNAMIC_DRAW)
    else
        self.posVbo:updateFloatArray(0, data)
    end
end

function MeshRender:updateTextureCoords0(data)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    if data:size() > self.uv0Vbo:size() / FLOAT_SIZE then
        if self.uv0Vbo then self.context:destroyBuffer(self.uv0Vbo) end
        self.uv0Vbo = self.context:createVertexBuffer(data, DYNAMIC_DRAW)
    else
        self.uv0Vbo:updateFloatArray(0, data)
    end
end

function MeshRender:updateTextureCoords1(data)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    if data:size() > self.uv1Vbo:size() / FLOAT_SIZE then
        if self.uv1Vbo then self.context:destroyBuffer(self.uv1Vbo) end
        self.uv1Vbo = self.context:createVertexBuffer(data, DYNAMIC_DRAW)
    else
        self.uv1Vbo:updateFloatArray(0, data)
    end
end

function MeshRender:updateColors(data)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    if data:size() > self.colorVbo:size() / FLOAT_SIZE then
        if self.colorVbo then self.context:destroyBuffer(self.colorVbo) end
        self.colorVbo = self.context:createVertexBuffer(data, DYNAMIC_DRAW)
    else
        self.colorVbo:updateFloatArray(0, data)
    end
end

function MeshRender:updateOutlineColors(data)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    if data:size() > self.outlineColorVbo:size() / FLOAT_SIZE then
        if self.outlineColorVbo then self.context:destroyBuffer(self.outlineColorVbo) end
        self.outlineColorVbo = self.context:createVertexBuffer(data, DYNAMIC_DRAW)
    else
        self.outlineColorVbo:updateFloatArray(0, data)
    end
end

function MeshRender:updateIndexBuffer(data)
    local UINT16_SIZE = Uint16Array.byteSizeOfUint16()
    if data:size() > self.ibo:size() / UINT16_SIZE then
        if self.ibo then self.context:destroyBuffer(self.ibo) end
        self.ibo = self.context:createIndexBuffer(data, DYNAMIC_DRAW)
    else
        self.ibo:updateIntArray(0, data)
    end
    self.indicesCount = data:size()
end

function MeshRender:setUV1Enabled(enabled)
    self.uv1Enabeld = enabled
end

function MeshRender:draw(pass)
    local FLOAT_SIZE = FloatArray.byteSizeOfFloat()
    pass:use()
    self.posVbo:bind()
    pass:setVertexAttrib("aPosition", 2, FLOAT, false, 2 * FLOAT_SIZE, 0)

    self.uv0Vbo:bind()
    pass:setVertexAttrib("aTextureCoord", 2, FLOAT, false, 2 * FLOAT_SIZE, 0)

    if self.uv1Enabeld then
        self.uv1Vbo:bind()
        pass:setVertexAttrib("aTextureCoord1", 2, FLOAT, false, 2 * FLOAT_SIZE, 0)
    end

    self.colorVbo:bind()
    pass:setVertexAttrib("aColor", 4, FLOAT, false, 4 * FLOAT_SIZE, 0)

    self.outlineColorVbo:bind()
    pass:setVertexAttrib("aOutlineColor", 4, FLOAT, false, 4 * FLOAT_SIZE, 0)

    self.ibo:bind()
    pass:drawElements(TRIANGLES, self.indicesCount, UNSIGNED_SHORT, 0)

    self.ibo:unbind()
    pass:disableVertexAttrib("aPosition")
    pass:disableVertexAttrib("aTextureCoord")
    if self.uv1Enabeld then
        pass:disableVertexAttrib("aTextureCoord1")
    end
    pass:disableVertexAttrib("aColor")
    pass:disableVertexAttrib("aOutlineColor")
end

return MeshRender