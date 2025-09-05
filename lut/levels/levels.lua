--/***************** BEGIN FILE HRADER BLOCK *********************************
--*
--* \author Ning hualong <ninghualong@yy.com> phone:15013359003
--*
--* Copyright (C) 2017-2019 YY.Inc
--* All rights reserved.
--*
--* This library is free software; you can redistribute it and/or modify it
--* under the terms of the GNU Lesser General Public License as published by
--* the Free Software Foundation; either version 3 of the License, or (at
--* your option) any later version. Please review the following information
--* to ensure the GNU Lesser General Public License version 3 requirements
--* will be met: https://www.gnu.org/licenses/lgpl.html.
--*
--* You should have received a copy of the GNU Lesser General Public License
--* along with this library; if not, write to the Free Software Foundation.
--*
--* If you use the source in a your project, please consider send an e-mail
--* to me, and allow me to add your project to my home page.
--*
--***************** END FILE HRADER BLOCK ***********************************/
TAG = "OrangeFilter-LevelsFilter"
OF_LOGI(TAG, "Call LevelsFilter lua script!")

local vs = [[
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
precision mediump float;
varying vec2 vTexCoord;
uniform sampler2D uTexture;

uniform vec3 uLevelMinimum;
uniform vec3 uLevelMiddle;
uniform vec3 uLevelMaximum;
uniform vec3 uMinOutput;
uniform vec3 uMaxOutput;

#define GammaCorrection(color, gamma)								pow(color, 1.0 / gamma)
#define LevelsControlInputRange(color, minInput, maxInput)				min(max(color - minInput, vec3(0.0)) / (maxInput - minInput), vec3(1.0))
#define LevelsControlInput(color, minInput, gamma, maxInput)				GammaCorrection(LevelsControlInputRange(color, minInput, maxInput), gamma)
#define LevelsControlOutputRange(color, minOutput, maxOutput) 			mix(minOutput, maxOutput, color)
#define LevelsControl(color, minInput, gamma, maxInput, minOutput, maxOutput) 	LevelsControlOutputRange(LevelsControlInput(color, minInput, gamma, maxInput), minOutput, maxOutput)

void main()
{
    vec4 textureColor = texture2D(uTexture, vTexCoord);
    
    gl_FragColor = vec4(LevelsControl(textureColor.rgb, uLevelMinimum, uLevelMiddle, uLevelMaximum, uMinOutput, uMaxOutput), textureColor.a);
}
]]

local _levelsPass = nil

function initParams(context, filter)
	OF_LOGI(TAG, "call initParams")
    filter:insertFloatParam("Min", 0.0, 1.0, 0.0)
    filter:insertFloatParam("Mid", 0.01, 9.99, 1.0)
    filter:insertFloatParam("Max", 0.0, 1.0, 1.0)
    filter:insertFloatParam("MinOutPut", 0.0, 1.0, 0.0)
    filter:insertFloatParam("MaxOutPut", 0.0, 1.0, 1.0)

	return OF_Result_Success
end

function initRenderer(context, filter)
	OF_LOGI(TAG, "call initRenderer")
	_levelsPass = context:createCustomShaderPass(vs, fs)
	return OF_Result_Success
end

function teardownRenderer(context, filter)
	OF_LOGI(TAG, "call teardownRenderer")
	context:destroyCustomShaderPass(_levelsPass)
	return OF_Result_Success
end

function applyRGBA(context, filter, frameData, inTex, outTex, debugTex)

	context:setViewport(PixelSize.new(outTex.width, outTex.height, outTex.pixelScale))
	context:setBlend(false)
	context:bindFBO(outTex)
	_levelsPass:use()
	_levelsPass:setUniformTexture("uTexture", 0, inTex.textureID, GL_TEXTURE_2D)
    _levelsPass:setUniform3f("uLevelMinimum", filter:floatParam("Min"), filter:floatParam("Min"), filter:floatParam("Min"))
    _levelsPass:setUniform3f("uLevelMiddle", filter:floatParam("Mid"), filter:floatParam("Mid"), filter:floatParam("Mid"))
    _levelsPass:setUniform3f("uLevelMaximum", filter:floatParam("Max"), filter:floatParam("Max"), filter:floatParam("Max"))
    _levelsPass:setUniform3f("uMinOutput", filter:floatParam("MinOutPut"), filter:floatParam("MinOutPut"), filter:floatParam("MinOutPut"))
    _levelsPass:setUniform3f("uMaxOutput", filter:floatParam("MaxOutPut"), filter:floatParam("MaxOutPut"), filter:floatParam("MaxOutPut"))

	local quadRender = context:sharedQuadRender()
	quadRender:draw(_levelsPass, false)

	if debugTex ~= nil then
		context:copyTexture(inTex, debugTex)
	end
	return OF_Result_Success
end

function requiredFrameData(context, game)
	return { OF_RequiredFrameData_None }
end

function onApplyParams(context, filter)
	OF_LOGI(TAG, "call onApplyParams")
	return OF_Result_Success
end

function readObject(context, filter, archiveIn)
	OF_LOGI(TAG, "call readObject")
	return OF_Result_Success
end

function writeObject(context, filter, archiveOut)
	OF_LOGI(TAG, "call writeObject")
	return OF_Result_Success
end