TAG = "OrangeFilter-Grid"
OF_LOGI(TAG, "Call Grid lua script!")

local _vs = [[
precision highp float;
attribute vec4 aPosition;
attribute vec4 aTextureCoord;
varying vec2 vTexCoord;

void main()
{
    gl_Position = aPosition;
    vTexCoord = aTextureCoord.xy;
}
]]

local fs = [[
precision highp float;
varying vec2 vTexCoord;
uniform vec4 uColor;
uniform float uWidth;
uniform float uHeight;
uniform float uPixelX;
uniform float uPixelY;
uniform int uOriginPosition;
void main()
{
	vec4 color = vec4(0.0);
	float x = 0.0;
	float y = 0.0;
	if (uOriginPosition == 0) { // topleft
		x = vTexCoord.x * uWidth;
		y = vTexCoord.y * uHeight;
	}
	else {
		x = abs((vTexCoord.x - 0.5) * uWidth);
		y = abs((vTexCoord.y - 0.5) * uHeight);
	}

	if (mod(x, uPixelX) < 1.0 || mod(y, uPixelY) < 1.0)
		color = uColor;
    gl_FragColor = color;
}
]]

local _blendPass = nil
local _color = Vec4f.new(0.0, 0.0, 0.0, 1.0)

function initParams(context, filter)
    OF_LOGI(TAG, "call initParams")

	filter:insertEnumParam("Origin", 0, { "TopLeft", "Center" })
    filter:insertColorParam("Color", _color)
    filter:insertIntParam("Pixel_X", 1, 200, 50)
    filter:insertIntParam("Pixel_Y", 1, 200, 50)

    return OF_Result_Success
end

function onApplyParams(context, filter)
    _color = filter:colorParam("Color")
    return OF_Result_Success
end

function initRenderer(context, filter)
    OF_LOGI(TAG, "call initRenderer")
    --context:config().isProfilerOn = 1
    _blendPass = context:createCustomShaderPass(_vs, fs)
    return OF_Result_Success
end

function teardownRenderer(context, filter)
    OF_LOGI(TAG, "call teardownRenderer")
    context:destroyCustomShaderPass(_blendPass)
    return OF_Result_Success
end

function applyRGBA(context, filter, frameData, inTex, outTex, debugTex)
	context:copyTexture(inTex, outTex)

    context:bindFBO(outTex)
    context:setViewport(0, 0, outTex.width, outTex.height)
	context:setBlend(true)
    context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)

    _blendPass:use()
    _blendPass:setUniform4f("uColor", _color.x, _color.y, _color.z, _color.w)
    _blendPass:setUniform1f("uWidth", outTex.width)
	_blendPass:setUniform1f("uHeight", outTex.height)
	_blendPass:setUniform1f("uPixelX", filter:intParam("Pixel_X"))
	_blendPass:setUniform1f("uPixelY", filter:intParam("Pixel_Y"))
	_blendPass:setUniform1i("uOriginPosition", filter:enumParam("Origin"))

    local quad_render = context:sharedQuadRender()
    quad_render:draw(_blendPass, false)

    if debugTex then
        context:copyTexture(inTex, debugTex)
    end

    return OF_Result_Success
end

function requiredFrameData(context, game)
    return { OF_RequiredFrameData_None }
end

function readObject(context, filter, archiveIn)
    OF_LOGI(TAG, "call readObject")
    return OF_Result_Success
end

function writeObject(context, filter, archiveOut)
    OF_LOGI(TAG, "call writeObject")
    return OF_Result_Success
end
