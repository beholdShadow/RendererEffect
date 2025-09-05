--*
--/***************** BEGIN FILE HRADER BLOCK *********************************
--* \author Wanzhiwen <wanzhiwen@yy.com>
--*
--* Copyright (C) 2017-2020 YY.Inc
--* All rights reserve
--*
--***************** END FILE HRADER BLOCK ***********************************/

-- Change history:
--   2020/04/26 : Init LabelPro Pro.
--   2020/05/06 : Support autoscale.
--   2021/03/23 : Refine SDF effect.
--   2021/04/02 : Support text texture.
--   2020/04/12 : Fix default leading.
--   2020/04/15 : Change smooth ratio.
--   2020/05/06 : Take care of space char's size.
--   2021/09/15 : Fix text animation blend error.
--   2021/09/17 : Fix mobile compile error.
--   2021/09/22 : bitmap text shadows tex blend mode from srcAlpha to one
--   2021/09/28 : update render to screen blend mode, fix shadow animation offset
--   2021/09/30 : reset render to screen blend mode
--   2021/10/25 : add text mask
--   2021/11/02 : fix text bitmap blend error
--   2021/11/03 : add char texture reference control
--   2021/11/09 : split label shader
--   2021/11/12 : Support MSDF effect.
--   2022/03/31 : add cross platform 'space' char fixed size
--   2022/06/09 : Text add boundbox, expose background paddding to param, remove smooth param
--   2022/10/12 : Remove MSDF codes, reduce sdf shader feather value.
--   2024/07/16 : support background radius corner
local OPTIMIZE_OUTLINE_VERSION = "4.10"
local DEFINE_ENTER_CHAR_UFT8 = 10
local DEFINE_SPACE_CHAR_UFT8 = 32

local LabelTag = "OF-LabelPro"

local MeshRender = require('render2d.meshrender')
local Shader = require 'render2d.labelshader'
local utils = require('pl.utils')
local class = require('pl.class')
local tablex = require('pl.tablex')
local MaskRender = require 'common.mask'
local bmpBlurRender = require 'common.gaussian_blur'

LabelPro = class()

function LabelPro:_init()
    OF_LOGI(LabelTag, "call LabelPro:_init")
    self.context = nil
    self.filter = nil
    self.textString = ""
    self.textScaleX = 1.0
    self.textScaleY = 1.0
    self.textRotate = 0
    self.textTransX = 0
    self.textTransY = 0
    self.fontPath = ""
    self.fontSize = 10
    self.textDirection = 0 -- 0-horizontal, 1-vertical
    self.textAlignment = 0 -- 0-left, 1-right, 2-center
    self.textSpacing = 0
    self.textLeading = 0
    self.textTextureShadow = nil
    self.boldEnabled = false
    self.italicEnabled = false
    self.underlineEnabled = false
    self.shadowEnabled = false
    self.anchor = 
    {
        type = 0,
        leftX = 0, rightX = 0
    } -- 0"Center", 1"Bottom Left", 2"Bottom Center", 3"Bottom Right", 4"Top Left", 5"Top Center", 6"Top Right", 7"Left Center", 8"Left Right"
    self.distanceFieldEnabled = false
    self.sdfDistanceMapSpread = 12
    self.bmpStyle = {
        color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        shadowColor = Vec4f.new(0.0, 0.0, 0.0, 1.0),
        outlineColor = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        outlineSize = 0,
        shadowDistance = 0.0,
        shadowAngle = 0.0,
        shadowBlurIntensity = 0
    }
    self.sdfStyle = {
        scale1 = 0.5,
        color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        textureEnabled = false,
        textureGL = nil,
        textureScale = 1.0,
        outline1Enabled = false,
        outline1Scale = 0.5,
        outline1Color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        outline2Enabled = false,
        outline2Scale = 0.5,
        outline2Color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        outline3Enabled = false,
        outline3Scale = 0.5,
        outline3Color1 = Vec4f.new(1.0, 1.0, 1.0, 1.0),
        shadowColor = Vec4f.new(0.0, 0.0, 0.0, 1.0),
        shadowBlurIntensity = 0.5,
        ShadowPadding = 0.0;
        shadowDistance = 0.0,
        shadowAngle = 0.0,
        boldScale = 0.0
    }

    self.background = {
        enableFeather = true,
        xpadding = 8,
        ypadding = 8,
        radius = 0
    }
    self.backgroundEnabled = false
    self.backgroundColor = Vec4f.new(0.01, 0.0, 0.0, 0.0)

    self.systemFontDir = nil
    self.systemFontNames = {}
    self.animation = nil

    self.renderPass = nil
    self.sdfPass = nil
    self.sdfShadowPass = nil
    self.sdfMaskPass = nil
    self.backgroundPass = nil

    self.contentWidth = 0.5
    self.contentHeight = 0.5
    self.autoScale = false

    --table reference from LabelMesh
    self.lineInfo = nil
    self.chars = {}
    self.charsBackup = {}
    self.backgroundBackup = {}
    self.backgroundMeshBatch = nil
    self.textMeshBatch = {}
    self.debug = false
    self.dirty = true
    self.autoAlignment = false

    self.pixelScale = 1.0
end

function LabelPro:initParams(context, filter)
    OF_LOGI(LabelTag, "call label initParams")

    filter:insertStringParam("Text", "text")
    filter:insertIntParam("TransX", -1000, 1000, 0)
    filter:insertIntParam("TransY", -1000, 1000, 0)
    filter:insertIntParam("Rotate", -180, 180, 0)
    filter:insertFloatParam("Scale", 0.01, 20, 1.0)
    filter:insertFloatParam("ScaleX", 0.01, 20, 1.0)
    filter:insertFloatParam("ScaleY", 0.01, 20, 1.0)
    filter:insertIntParam("Opacity", 0, 100, 100)

    filter:insertBoolParam("SDF", false)
    filter:insertIntParam("SDFSpread", 1, 500, 128)

    filter:insertFloatParam("Scale1", 0.0, 1.0, 0.5)

    filter:insertColorParam("Color1", Vec4f.new(1.0, 1.0, 1.0, 1.0))
    filter:insertBoolParam("TextureEnabled", false)
    filter:insertResParam("Texture", OF_ResType_Image, "")
    filter:insertFloatParam("TextureScale", 0.1, 5, 1.0)
    filter:insertIntParam("Size", 1, 500, 128)
    filter:insertBoolParam("Outline1Enabled", false)
    filter:insertFloatParam("Outline1Thickness", 0, 100, 0)
    filter:insertFloatParam("Outline1Scale", 0.0, 1.0, 0.5)  -- to be deprecated
    filter:insertColorParam("Outline1Color1", Vec4f.new(1.0, 1.0, 1.0, 1.0))
    filter:insertBoolParam("Outline2Enabled", false)
    filter:insertFloatParam("Outline2Scale", 0.0, 1.0, 0.5)
    filter:insertColorParam("Outline2Color1", Vec4f.new(1.0, 1.0, 1.0, 1.0))
    filter:insertBoolParam("Outline3Enabled", false)
    filter:insertFloatParam("Outline3Scale", 0.0, 1.0, 0.5)
    filter:insertColorParam("Outline3Color1", Vec4f.new(1.0, 1.0, 1.0, 1.0))

    filter:insertIntParam("Spacing", -200, 200, 0)
    filter:insertIntParam("Leading", -500, 500, 0)
    filter:insertBoolParam("Bold", false)
    filter:insertBoolParam("Shadow", false)
    filter:insertColorParam("ShadowColor", Vec4f.new(0.0, 0.0, 0.0, 1.0))
    filter:insertFloatParam("ShadowBlur", 0, 400, 0)
    filter:insertFloatParam("ShadowPadding", -0.6, 0.6, 0)
    filter:insertFloatParam("ShadowDistance", 0.0, 100.0, 0.0)
    filter:insertFloatParam("ShadowAngle", -180.0, 180.0, 0.0)
    filter:insertBoolParam("BackgroundEnabled", false)
    filter:insertIntParam("BackgroundXPadding", -500, 500, 0)
    filter:insertIntParam("BackgroundYPadding", -500, 500, 0)
    filter:insertIntParam("BackgroundRadius", 0, 250, 0)
    filter:insertColorParam("BackgroundColor", Vec4f.new(0.0, 0.0, 0.0, 0.0))
    
    filter:insertStringParam("BoundRect", "")

    filter:insertEnumParam("Direction", 0, { "Horizontal", "Vertical" })
    filter:insertEnumParam("Alignment", 0, { "Left", "Right", "Center" })
    filter:insertEnumParam("AnchorType", 0, {
        "Center", "Bottom Left", "Bottom Center", "Bottom Right", "Top Left",
        "Top Center", "Top Right", "Left Center", "Right Center"
    })
    filter:insertIntParam("AnchorTransX", -1000, 1000, 0)
    filter:insertIntParam("AnchorTransY", -1000, 1000, 0)
    filter:insertBoolParam("AutoAlignment", false)

    filter:insertResParam("InternalFont", OF_ResType_TTF, "")
    filter:insertStringParam("CustomFontPath", "")
    filter:insertStringParam("EmojiFontPath", "")
    filter:insertStringParam("SystemFontDir", "")
    filter:insertStringParam("SystemFontNames", "")
    filter:insertFloatParam("ContentWidth", 0.01, 1.0, 0.5)
    filter:insertFloatParam("ContentHeight", 0.01, 1.0, 0.5)
    filter:insertBoolParam("AutoScale", false)
    filter:insertBoolParam("Debug", false)
    filter:insertFloatParam("Smooth", 0.01, 10.0, 1.0)
    MaskRender:initParams(context, filter)

    return OF_Result_Success
end

function LabelPro:onApplyParams(context, filter, dirtyTable)
    local opacity = filter:intParam("Opacity") / 100.0
    self.smooth = filter:floatParam("Smooth")
    self.textScaleX = filter:floatParam("Scale") * filter:floatParam("ScaleX")
    self.textScaleY = filter:floatParam("Scale") * filter:floatParam("ScaleY")
    self.textRotate = filter:intParam("Rotate")
    self.textTransX = filter:intParam("TransX")
    self.textTransY = filter:intParam("TransY")
    self.anchor.type = filter:enumParam("AnchorType")
    if dirtyTable:isDirty("AutoAlignment") then
        self.autoAlignment = filter:boolParam("AutoAlignment")
    end
    local fontPath = filter:stringParam("CustomFontPath")
    if string.len(fontPath) ~= 0 and self.pathIsAbsolute(self, fontPath) == nil then
        fontPath = filter:resFullPath(fontPath)
    end
    local internalFont = filter:resParam("InternalFont")
    if string.len(fontPath) == 0 and string.len(internalFont) > 0 then
        fontPath = filter:resFullPath(internalFont)
    end
    self:setFont(fontPath)
    self:setDistanceFieldEnabled(filter:boolParam("SDF"))
    if dirtyTable:isDirty("Text") then
        self:setString(filter:stringParam("Text"))    
    end
    self:setSpacing(filter:intParam("Spacing"))
    self:setLeading(filter:intParam("Leading"))
    self:setDirection(filter:enumParam("Direction"))
    self:setAlignment(filter:enumParam("Alignment"))
    self:setFontSize(filter:intParam("Size"))
    self:setSDFSpread(filter:intParam("SDFSpread"))
    self:setBoldEnabled(filter:boolParam("Bold"))
    self:setShadowEnabled(filter:boolParam("Shadow"))
    self:setBackgroundEnabled(filter:boolParam("BackgroundEnabled"))
    self:setSystemFonts(filter:stringParam("SystemFontDir"),
        utils.split(filter:stringParam("SystemFontNames"), ","))
    self:setContentSize(filter:floatParam("ContentWidth"), filter:floatParam("ContentHeight"))
    self:setAutoScaleEnabled(filter:boolParam("AutoScale"))
    self:setDebug(filter:boolParam("Debug"))

    local color1 = filter:colorParam("Color1"); color1.w = color1.w * opacity;
    local outline1Color1 = filter:colorParam("Outline1Color1"); outline1Color1.w = outline1Color1.w * opacity;
    local outline2Color1 = filter:colorParam("Outline2Color1"); outline2Color1.w = outline2Color1.w * opacity;
    local outline3Color1 = filter:colorParam("Outline3Color1"); outline3Color1.w = outline3Color1.w * opacity;
    local shadowColor = filter:colorParam("ShadowColor"); shadowColor.w = shadowColor.w * opacity;
    local backgroundColor = filter:colorParam("BackgroundColor"); backgroundColor.w = backgroundColor.w * opacity;
    local shadowBlur = filter:floatParam("ShadowBlur")

    local sdfStyle = {
        scale1 = filter:floatParam("Scale1"),
        color1 = color1,
        textureEnabled = filter:boolParam("TextureEnabled"),
        textureScale = filter:floatParam("TextureScale"),
        outline1Enabled = filter:boolParam("Outline1Enabled"),
        outline1Scale = filter:floatParam("Outline1Scale"),
        outline1Color1 = outline1Color1,
        outline2Enabled = filter:boolParam("Outline2Enabled"),
        outline2Scale = filter:floatParam("Outline2Scale"),
        outline2Color1 = outline2Color1,
        outline3Enabled = filter:boolParam("Outline3Enabled"),
        outline3Scale = filter:floatParam("Outline3Scale"),
        outline3Color1 = outline3Color1,
        shadowColor = shadowColor,
        shadowBlurIntensity = 0.5 * (1.0 - shadowBlur / 100),
        shadowBlurPadding = filter:floatParam("ShadowPadding") * (-1.0),
        shadowDistance = filter:floatParam("ShadowDistance"),
        shadowAngle = filter:floatParam("ShadowAngle"),
        boldScale = (self.boldEnabled and {0.05} or {0.0})[1]
    }

    local bmpStyle = {
        color1 = color1,
        shadowColor = shadowColor,
        outlineColor = outline1Color1,
        outlineSize = 0,
        shadowDistance = filter:floatParam("ShadowDistance"),
        shadowAngle = filter:floatParam("ShadowAngle"),
        shadowBlurIntensity = shadowBlur / 400,
    }

    local outline1Thickness = filter:floatParam("Outline1Thickness")
    if filter:boolParam("Outline1Enabled") and outline1Thickness > 0.01 then 
        -- if filter.versionCheckout and filter:versionCheckout(OPTIMIZE_OUTLINE_VERSION) then
        --     bmpStyle.outlineSize = math.floor(filter:floatParam("Outline1Thickness"))
        -- else
        if self.distanceFieldEnabled then
            sdfStyle.outline1Scale = 0.5 - outline1Thickness / 100 * 0.45
            bmpStyle.outlineSize = 0
        else
            bmpStyle.outlineSize = math.floor(filter:floatParam("Outline1Thickness"))
        end
        -- end
    end
    
    self:setBmpStyle(bmpStyle)
    self:setSdfStyle(sdfStyle, filter)
    self:setBackground(backgroundColor, filter:intParam("BackgroundXPadding"), filter:intParam("BackgroundYPadding"), filter:intParam("BackgroundRadius"))

    MaskRender:onApplyParams(context, filter)
    MaskRender:setOpacity(opacity)

    if self.autoAlignment and (dirtyTable:isDirty("Scale") or dirtyTable:isDirty("ScaleX") or
        dirtyTable:isDirty("ScaleY") or dirtyTable:isDirty("TransX") or  
        dirtyTable:isDirty("TransY") or dirtyTable:isDirty("Rotate")) then
        self.anchor.leftX = 0
        self.anchor.rightX = 0
    end
end

function LabelPro:initRenderer(context, filter)
    OF_LOGI(LabelTag, "call label initRenderer")
    self.renderPass = context:createCustomShaderPass(Shader.vs, Shader.fs)
    self.context = context
    self.filter = filter
    MaskRender:initRenderer(context, filter)

    bmpBlurRender:initRenderer(context, filter)

    return OF_Result_Success
end

function LabelPro:getBlurRender()
    return bmpBlurRender
end

function LabelPro:teardown(context)
    OF_LOGI(LabelTag, "call teardownRenderer")
    self.clearMeshBatch(self, context)
    self.clearChars(self)
    context:destroyCustomShaderPass(self.renderPass)
    context:destroyCustomShaderPass(self.backgroundPass)
    context:destroyCustomShaderPass(self.sdfPass)
    context:destroyCustomShaderPass(self.sdfMaskPass)
    context:destroyCustomShaderPass(self.sdfShadowPass)

    MaskRender:teardown(context)
    bmpBlurRender:teardown(context)

    self.setDirty(self)
    return OF_Result_Success
end
--
-- lineInfo data structure description:
-- {
--   x = 0,
--   y = 0,
--   maxLineWidth = 100,
--   maxLineHeight = 100,
--   lines = {
--     { width = 100, height = 100, glyphCount = 5 }
--   }
-- }
--

function LabelPro:calcLineInfo(context, text)
    local maxLineWidth, maxLineHeight, totalHeight = 0, 0, 0
    local x, y = 1000, -1000 -- topleft corner of whole text rect
    local xmin, xmax = 1000, -1000
    local ymin, ymax = 1000, -1000
    local xOffset = 0
    local curGlyphCount = 0

    local lines = {}

    local function generateNewline()
        local curLineWidth = xmax - xmin
        local curLineHeight = ymax - ymin
        maxLineWidth = math.max(maxLineWidth, curLineWidth)
        maxLineHeight = math.max(maxLineHeight, curLineHeight)
        if curGlyphCount == 0 then
            curLineWidth = self.fontSize * 0.5
            curLineHeight = self.fontSize / 2
            maxLineHeight = math.max(maxLineHeight, self.fontSize / 2)
            xmin, ymin = 0, 0
            xmax, ymax = self.fontSize * 0.5, self.fontSize / 2
            curGlyphCount = 0
        end
        if #lines == 0 then
            x = math.min(x, xmin)
            y = math.max(y, ymax)
        end

        table.insert(lines, {
            width = curLineWidth, height = curLineHeight,
            glyphCount = curGlyphCount, ymin = ymin, ymax = ymax,
            startx = xmin, starty = ymin,
        })
        curGlyphCount = 0
        xmin, xmax = 1000, -1000
        ymin, ymax = 1000, -1000
        totalHeight = totalHeight + curLineHeight
    end
    
    for p, c in utf8.codes(text) do
        if c ~= DEFINE_ENTER_CHAR_UFT8 then
            local glyph = self.getGlyph(self, context, c)

            if self.textDirection == 0 then -- horizontal
                ymax = math.max(ymax, glyph.horiBearingY)
                ymin = math.min(ymin, glyph.horiBearingY - glyph.height)
                if curGlyphCount == 0 then
                    xmin, xOffset = 0, 0
                end
                    xmax = xOffset + glyph.horiAdvance
                    xOffset = xOffset + glyph.horiAdvance + self.textSpacing
            end
            curGlyphCount = curGlyphCount + 1
        else
            generateNewline()
        end
    end

    if curGlyphCount > 0 then generateNewline() end

    for i = 1, #lines do
        if self.textAlignment == 1 then -- right
            lines[i].startx = lines[i].startx + maxLineWidth - lines[i].width
        elseif self.textAlignment == 2 then -- center
            lines[i].startx = lines[i].startx + (maxLineWidth - lines[i].width) / 2
        end
    end

    self.lineInfo = {}
    self.lineInfo.x = x
    self.lineInfo.y = y
    self.lineInfo.maxLineWidth = maxLineWidth
    self.lineInfo.maxLineHeight = maxLineHeight
    self.lineInfo.totalHeight = totalHeight + (#lines - 1) * self.textLeading
    self.lineInfo.totalRows = #lines
    self.lineInfo.lines = lines
end

function LabelPro:dumpTextInfo(context, text)
    if self.debug == false then return end

    OF_LOGI(LabelTag, string.format("dumpTextInfo %s", text))

    --OF_LOGI(LabelTag, string.format("Font Ascender %d", fontAtlas:getFontAscender()))
    OF_LOGI(LabelTag, string.format("LineInfo"))
    OF_LOGI(LabelTag, string.format(" x %d", self.lineInfo.x))
    OF_LOGI(LabelTag, string.format(" y %d", self.lineInfo.y))
    OF_LOGI(LabelTag, string.format(" MaxWidth  %d", self.lineInfo.maxLineWidth))
    OF_LOGI(LabelTag, string.format(" MaxHeight %d", self.lineInfo.maxLineHeight))
    OF_LOGI(LabelTag, string.format(" TotalHeight %d", self.lineInfo.totalHeight))

    for i = 1, #self.lineInfo.lines do
        OF_LOGI(LabelTag, string.format("[%d] %d, %d, %d, %d, %d", i,
            self.lineInfo.lines[i].width, self.lineInfo.lines[i].height, self.lineInfo.lines[i].glyphCount,
            self.lineInfo.lines[i].startx, self.lineInfo.lines[i].starty))
    end
    OF_LOGI(LabelTag, string.format("    idx  unicode  width  height  bearingX  bearingY  advance   x   y"))
    for p, c in utf8.codes(self.textString) do
        if c ~= 10 then
            local glyph = self.getGlyph(self, context, c)
            if glyph.texture then
                local ofTex = glyph.texture:toOFTexture()
                OF_LOGI(LabelTag, string.format("    %d,   %d,      %d,   %d,    %d,    %d,    %d,    %d,    %d,   %d,   %d",
                    p, c, glyph.width, glyph.height, glyph.horiBearingX, glyph.horiBearingY, glyph.horiAdvance, glyph.x, glyph.y, ofTex.textureID, ofTex.format))
            end
        end
    end
end

function LabelPro:getGlyph(context, char)
    local fontAtlasCache = context:getFontAtlasCache()
    local fontAtlas = nil
    local glyph = nil
    local emojiFontPath = self.filter:stringParam("EmojiFontPath")
    -- emojiFontPath = "fonts/NotoColorEmoji.ttf"
    -- if string.len(emojiFontPath) > 0 then
    --     fontAtlasCache:setEmojiFont(self.filter:resFullPath(emojiFontPath))
    -- end

    if char == DEFINE_SPACE_CHAR_UFT8 then
        glyph = {}
        glyph.width = self.fontSize * 0.25
        glyph.height = self.fontSize * 0.5
        glyph.horiBearingX = 0
        glyph.horiBearingY = self.fontSize * 0.5
        glyph.horiAdvance = self.fontSize * 0.25
        return glyph
    end

    if string.len(self.fontPath) > 0 then
        fontAtlas = fontAtlasCache:getFontAtlas2(
            self.fontPath, self.fontSize, self.bmpStyle.outlineSize, false,
            self.distanceFieldEnabled, self.sdfDistanceMapSpread)
        glyph = fontAtlas:getGlyph(char)

        if glyph and glyph.texture then return glyph end
    end

    if string.len(self.systemFontDir) > 0 then
        for n = 1, #self.systemFontNames do
            local fontPath = self.systemFontDir .. "/" .. self.systemFontNames[n]
            fontPath = self.filter:resFullPath(fontPath)
            -- OF_LOGI(LabelTag, string.format("system font path = %s", fontPath))
            fontAtlas = fontAtlasCache:getFontAtlas2(
                fontPath, self.fontSize, self.bmpStyle.outlineSize, false,
                self.distanceFieldEnabled, self.sdfDistanceMapSpread)
            glyph = fontAtlas:getGlyph(char)
            if glyph and glyph.texture then 
                -- OF_LOGI(LabelTag, string.format("system %s glyph %d texture instead of custom", fontPath, char))
                return glyph
            end
        end
    end

    if glyph == nil then
        OF_LOGI(LabelTag, "Text must set efficient customFontPath or systemFontDir")
        glyph = {}
        glyph.width = self.fontSize * 0.5
        glyph.height = self.fontSize * 0.5
        glyph.horiBearingX = 0
        glyph.horiBearingY = self.fontSize * 0.5
        glyph.horiAdvance = self.fontSize * 0.5
    end

    return glyph
end

function LabelPro:clearChars()
    for i = 1, #self.chars do
        if self.chars[i].texture.decRefCount then
            self.chars[i].texture:decRefCount()
        end
    end
    self.chars = {}
end

function LabelPro:generateChars(context, text, lineInfo)
    OF_LOGI(LabelTag, "LabelPro:generateChars")
    self.clearChars(self)
    
    local curWidth = 0
    local lineIdx = 1
    local heightOffset = 0
    local charCount = 0

    if self.textDirection == 0 then -- horizontal
        for p, c in utf8.codes(self.textString) do
            if c == 10 then
                curWidth = 0
                lineIdx = lineIdx + 1
                if lineIdx <= #lineInfo.lines then
                    heightOffset = heightOffset + lineInfo.lines[lineIdx - 1].ymin - lineInfo.lines[lineIdx].ymax - self.textLeading
                end
            else
                local startx = lineInfo.lines[lineIdx].startx
                local glyph = self.getGlyph(self, context, c)

                if glyph.texture then
                    curWidth = curWidth + glyph.horiBearingX
                    
                    local textureWidth = glyph.texture:width()
                    local textureHeight = glyph.texture:height()
                    local left = glyph.x / textureWidth
                    local right = left + glyph.width / textureWidth
                    local top = glyph.y / textureHeight
                    local bottom = top + glyph.height / textureHeight

                    local d = 0
                    local texFormat = glyph.texture:toOFTexture().format
                    if self.distanceFieldEnabled and texFormat ~= RGBA then
                        right = left + (glyph.width + 2 * self.sdfDistanceMapSpread) / textureWidth
                        bottom = top + (glyph.height + 2 * self.sdfDistanceMapSpread) / textureHeight
                        d = self.sdfDistanceMapSpread
                    end

                    local char  = {}
                    char.pos = {
                        startx + curWidth - d, glyph.horiBearingY + heightOffset + d,
                        startx + glyph.width + curWidth + d, glyph.horiBearingY + heightOffset + d,
                        startx + glyph.width + curWidth + d, glyph.horiBearingY - glyph.height + heightOffset - d,
                        startx + curWidth - d, glyph.horiBearingY - glyph.height + heightOffset - d
                    }
                    char.baseline = heightOffset
                    char.uv = { left, top, right, top, right, bottom, left, bottom }
                    char.uv1 = { left, top, right, top, right, bottom, left, bottom }
                    char.gradientColor = {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
                    char.outlineColor =  {1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0, 1.0}
                    if self.sdfStyle.textureEnabled and self.sdfStyle.textureGL then
                        local glyphWidth, glyphHeight = glyph.width + 2 * d, glyph.height + 2 * d
                        glyphWidth = self.sdfStyle.textureScale * glyphWidth
                        glyphHeight = self.sdfStyle.textureScale * glyphHeight
                        local texWidth, texHeight = self.sdfStyle.textureGL:width(), self.sdfStyle.textureGL:height()

                        local n = charCount % 4
                        left = 0.25 * n
                        right = left + math.min(0.25, glyphWidth / texWidth)
                        top = 0.0
                        bottom = math.min(1.0, glyphHeight / texHeight)
                        char.uv1 = { left, top, right, top, right, bottom, left, bottom }

                        if glyphWidth / texWidth > 0.25 or glyphHeight / texHeight > 1.0 then
                            OF_LOGI(LabelTag, "Warning: Texture Scale is to large!")
                        end
                    end

                    --print(charCount, left, right, top, bottom)
                    char.texture = glyph.texture
                    if char.texture.incRefCount then
                        char.texture:incRefCount()
                    end

                    char.rowIdx = lineIdx

                    table.insert(self.chars, char)
                    curWidth = curWidth + glyph.horiAdvance + self.textSpacing - glyph.horiBearingX
                else 
                    curWidth = curWidth + glyph.width + self.textSpacing
                end
            end
            charCount = charCount + 1
        end
    else  -- vertical

    end
    self.charsBackup = tablex.deepcopy(self.chars)
end

function LabelPro:clearMeshBatch(context)
    for i = 1, #self.textMeshBatch do
        self.textMeshBatch[i].mesh2dRender:teardown(context)
    end
    self.textMeshBatch = {}
end

function LabelPro:generateMeshBatch(context)
    -- OF_LOGI(LabelTag, "LabelPro:generateMeshBatch")
    self.clearMeshBatch(self, context)

    for ci = 1, #self.chars do
        local char = self.chars[ci]
        -- OF_LOGI(LabelTag, string.format("LabelPro:char count = %d", #self.chars))
        -- find if texture exist
        local ofTex = char.texture:toOFTexture()
        local foundIdx = 0
        if #self.textMeshBatch > 0 then
            for i = 1, #self.textMeshBatch do
                if self.textMeshBatch[i].textureId == ofTex.textureID and
                    self.textMeshBatch[i].textureFormat == ofTex.format then
                    foundIdx = i
                    break
                end
            end
        end

        if foundIdx == 0 then
            table.insert(self.textMeshBatch, {
                textureId = ofTex.textureID, textureFormat = ofTex.format,
                textureWidth = ofTex.width, textureHeight = ofTex.height,
                pos = {}, uv = {}, uv1 = {}, color = {}, outlineColor = {}, indices = {} })
            foundIdx = #self.textMeshBatch
        end

        for n = 0, 3 do
            table.insert(self.textMeshBatch[foundIdx].pos, char.pos[2*n+1])
            table.insert(self.textMeshBatch[foundIdx].pos, char.pos[2*n+2])
            table.insert(self.textMeshBatch[foundIdx].uv, char.uv[2*n+1])
            table.insert(self.textMeshBatch[foundIdx].uv, char.uv[2*n+2])
            table.insert(self.textMeshBatch[foundIdx].uv1, char.uv1[2*n+1])
            table.insert(self.textMeshBatch[foundIdx].uv1, char.uv1[2*n+2])
            table.insert(self.textMeshBatch[foundIdx].color, char.gradientColor[4*n+1])
            table.insert(self.textMeshBatch[foundIdx].color, char.gradientColor[4*n+2])
            table.insert(self.textMeshBatch[foundIdx].color, char.gradientColor[4*n+3])
            table.insert(self.textMeshBatch[foundIdx].color, char.gradientColor[4*n+4])
            table.insert(self.textMeshBatch[foundIdx].outlineColor, char.outlineColor[4*n+1])
            table.insert(self.textMeshBatch[foundIdx].outlineColor, char.outlineColor[4*n+2])
            table.insert(self.textMeshBatch[foundIdx].outlineColor, char.outlineColor[4*n+3])
            table.insert(self.textMeshBatch[foundIdx].outlineColor, char.outlineColor[4*n+4])
        end

        local glyphCount = #self.textMeshBatch[foundIdx].pos / 8 - 1
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 0)
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 2)
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 1)
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 0)
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 3)
        table.insert(self.textMeshBatch[foundIdx].indices, 4 * glyphCount + 2)
        
    end

    for i = 1, #self.textMeshBatch do
        local posCnt = #self.textMeshBatch[i].pos
        local colorCnt = #self.textMeshBatch[i].color
        local outlineColorCnt = #self.textMeshBatch[i].outlineColor
        local indicesCnt = #self.textMeshBatch[i].indices
        local mesh2dPosition = FloatArray.new(posCnt)
        local mesh2dTexCoord0 = FloatArray.new(posCnt)
        local mesh2dTexCoord1 = FloatArray.new(posCnt)
        local mesh2dColor = FloatArray.new(colorCnt)
        local mesh2dOutlineColor = FloatArray.new(outlineColorCnt)
        local mesh2dIndices = Uint16Array.new(indicesCnt)

        mesh2dPosition:copyFromTable(self.textMeshBatch[i].pos)
        mesh2dTexCoord0:copyFromTable(self.textMeshBatch[i].uv)
        mesh2dTexCoord1:copyFromTable(self.textMeshBatch[i].uv1)
        mesh2dColor:copyFromTable(self.textMeshBatch[i].color)
        mesh2dOutlineColor:copyFromTable(self.textMeshBatch[i].outlineColor)
        mesh2dIndices:copyFromTable(self.textMeshBatch[i].indices)

        self.textMeshBatch[i].mesh2dRender = MeshRender()
        self.textMeshBatch[i].mesh2dRender:init(context)
        self.textMeshBatch[i].mesh2dRender:updatePositions(mesh2dPosition)
        self.textMeshBatch[i].mesh2dRender:updateTextureCoords0(mesh2dTexCoord0)
        self.textMeshBatch[i].mesh2dRender:updateTextureCoords1(mesh2dTexCoord1)
        self.textMeshBatch[i].mesh2dRender:updateColors(mesh2dColor)
        self.textMeshBatch[i].mesh2dRender:updateOutlineColors(mesh2dOutlineColor)
        self.textMeshBatch[i].mesh2dRender:updateIndexBuffer(mesh2dIndices)
    end

    if self.background.pos ~= nil then
        self.generateBgMesh(self)
    end
    
    --for i = 1, #self.textMeshBatch do
    --    OF_LOGI(LabelTag, string.format(
    --        "texture id %d, format %d", self.textMeshBatch[i].textureId, self.textMeshBatch[i].textureFormat))
    --end
end

function LabelPro:generateBgMesh()
    -- OF_LOGI(LabelTag, "LabelPro:generateBgMesh")
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

function LabelPro:genarateBackground(lineInfo)
    self.background.xpadding = math.max(self.background.xpadding, -lineInfo.maxLineWidth)
    self.background.ypadding = math.max(self.background.ypadding, -lineInfo.totalHeight)
    self.background.pos = {
        lineInfo.x - self.background.xpadding, lineInfo.y + self.background.ypadding,
        lineInfo.x + self.background.xpadding + lineInfo.maxLineWidth, lineInfo.y + self.background.ypadding,
        lineInfo.x + self.background.xpadding + lineInfo.maxLineWidth, lineInfo.y - lineInfo.totalHeight - self.background.ypadding,
        lineInfo.x - self.background.xpadding, lineInfo.y - lineInfo.totalHeight - self.background.ypadding,
        }
    self.background.uv = { 0.0, 0.0, 1.0, 0.0, 1.0, 1.0, 0.0, 1.0 }
    self.backgroundBackup = tablex.deepcopy(self.background)
end

function LabelPro:genTextShadowTexture(context, lineInfo)
    local lineCount = #lineInfo.lines
    local textWidth = self.lineInfo.maxLineWidth + 2 * self.background.xpadding
    local textHeight = self.lineInfo.totalHeight + 2 * self.background.ypadding
    
    local width = textWidth
    local height = textHeight
    self.textTextureShadow = self.context:getTexture(PixelSize.new(textWidth, textHeight, self.pixelScale))

    -- render text at center
    local shadowTextureOF = self.textTextureShadow:toOFTexture()
    self.context:bindFBO(shadowTextureOF)
    self.context:setViewport(PixelSize.new(width, height, self.pixelScale))
    self.context:setBlend(false)
    self.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    self.context:clearColorBuffer()

    -- local textWidth, textHeight = lineInfo.maxLineWidth, lineInfo.totalHeight
    local anchorMat = Matrix4f.TransMat(-self.lineInfo.x - textWidth / 2, self.lineInfo.y - textHeight / 2, 0.0)

    local mat = Matrix4f:ScaleMat(2 / width, 2 / height, 1.0)
        * anchorMat
        * Matrix4f:ScaleMat(1.0, -1.0, 1.0)

    self.renderText(self, context, shadowTextureOF, mat, true)

    local blurTex = self.context:getTexture(PixelSize.new(width, height, self.pixelScale))
    bmpBlurRender:draw(self.context, shadowTextureOF, blurTex:toOFTexture())
    self.context:copyTexture(blurTex:toOFTexture(), shadowTextureOF)
    self.context:releaseTexture(blurTex)
end

function LabelPro:renderTextShadow(context, outTex, shadowMat, alphaScale)
    if self.distanceFieldEnabled then
        context:bindFBO(outTex)
        context:setViewport(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
        context:setBlend(true)
        context:setBlendMode(RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)

        if self.sdfShadowPass == nil then
            local defstr = ""
            if self.context:glChecker().isSupportExtension then
                if self.context:glChecker():isSupportExtension("GL_OES_standard_derivatives", "OES_standard_derivatives") then
                    defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
                end
            else
                defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
            end
            self.sdfShadowPass = context:createCustomShaderPass(Shader.vs_sdf, defstr..Shader.fs_sdf_shadow)
        end
        for i = 1, #self.textMeshBatch do
            self.sdfShadowPass:use()
            self.sdfShadowPass:setUniformMatrix4fv("uMVP", 1, 0, shadowMat.x)
            self.sdfShadowPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
            self.sdfShadowPass:setUniform1f("_Scale", self.sdfStyle.shadowBlurIntensity)
            self.sdfShadowPass:setUniform1f("uPixelScale", self.fontSize * self.textScaleX);
            self.sdfShadowPass:setUniform1f("uSmooth", self.smooth);
            self.sdfShadowPass:setUniform1f("_Padding", self.sdfStyle.shadowBlurPadding)
            self.sdfShadowPass:setUniform4f("_Color1", self.sdfStyle.shadowColor.x,
                self.sdfStyle.shadowColor.y, self.sdfStyle.shadowColor.z, self.sdfStyle.shadowColor.w)
            self.textMeshBatch[i].mesh2dRender:setUV1Enabled(false)
            self.textMeshBatch[i].mesh2dRender:draw(self.sdfShadowPass)
        end
    else
        self.genTextShadowTexture(self, context, self.lineInfo)

        context:bindFBO(outTex)
        context:setViewport(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
        context:setBlend(true)
        context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)
        -- context:copyTexture(self.textTextureShadow:toOFTexture(), outTex)
        self.renderPass:use()
        self.renderPass:setUniform1i("uEffectType", 0)
        self.renderPass:setUniformTexture("uTexture0", 0, self.textTextureShadow:textureID(), TEXTURE_2D)
        self.renderPass:setUniform4f("uColor", self.bmpStyle.shadowColor.x, self.bmpStyle.shadowColor.w, self.bmpStyle.shadowColor.z, self.bmpStyle.shadowColor.w)
        self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, shadowMat.x)
        self.backgroundMeshBatch:draw(self.renderPass, false)
    end
end

function LabelPro:renderTextMask(context, outTex, maskMat)
    context:bindFBO(outTex)
    context:setViewport(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
    context:setBlend(true)
    if self.distanceFieldEnabled then
        context:setBlendMode(RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)

        if self.sdfMaskPass == nil then
            local defstr = ""
            if self.context:glChecker().isSupportExtension then
                if self.context:glChecker():isSupportExtension("GL_OES_standard_derivatives", "OES_standard_derivatives") then
                    defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
                end
            else
                defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
            end
            self.sdfMaskPass = context:createCustomShaderPass(Shader.vs_sdf, defstr..Shader.fs_sdf_mask_generate)
        end
        for i = 1, #self.textMeshBatch do
            self.sdfMaskPass:use()
            self.sdfMaskPass:setUniformMatrix4fv("uMVP", 1, 0, maskMat.x)
            self.sdfMaskPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
            self.sdfMaskPass:setUniform1f("uCutoff", self.sdfStyle.scale1 - self.sdfStyle.boldScale)
            self.sdfMaskPass:setUniform1f("uSmooth", 0.5)
            self.textMeshBatch[i].mesh2dRender:setUV1Enabled(false)
            self.textMeshBatch[i].mesh2dRender:draw(self.sdfMaskPass)
        end
    else
        context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)
        for i = 1, #self.textMeshBatch do
            self.renderPass:use()
            self.renderPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
            self.renderPass:setUniform4f("uColor", 1.0, 1.0, 1.0, 1.0)
            self.renderPass:setUniform4f("uEffectColor", 1.0, 1.0, 1.0, 1.0)
            self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, maskMat.x)

            if self.bmpStyle.outlineSize > 0 and self.textMeshBatch[i].textureFormat ~= RGBA then
                self.renderPass:setUniform1i("uEffectType", 1)
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)

                self.renderPass:setUniform1i("uEffectType", 0)
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)
            else
                if self.textMeshBatch[i].textureFormat == RGBA then
                    self.renderPass:setUniform1i("uEffectType", 2)
                else
                    self.renderPass:setUniform1i("uEffectType", 0)
                end
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)
            end
        end
    end
end

function LabelPro:renderText(context, outTex, mat, isShadow)
    context:bindFBO(outTex)
    context:setViewport(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
    context:setBlend(true)

    if self.distanceFieldEnabled then  
        context:setBlendMode(RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)
        for i = 1, #self.textMeshBatch do
            if self.textMeshBatch[i].textureFormat ~= RGBA then
                self.sdfPass:use()
                self.sdfPass:setUniformMatrix4fv("uMVP", 1, 0, mat.x)
                self.sdfPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
                self.sdfPass:setUniform1f("uPixelScale", self.fontSize * self.textScaleX);
                self.sdfPass:setUniform1f("uSmooth", self.smooth);
                self.sdfPass:setUniform1f("_Scale", self.sdfStyle.scale1 - self.sdfStyle.boldScale)
                self.sdfPass:setUniform4f("_Color1",
                    self.sdfStyle.color1.x, self.sdfStyle.color1.y, self.sdfStyle.color1.z, self.sdfStyle.color1.w)
                
                if self.sdfStyle.textureEnabled then
                    self.sdfPass:setUniformTexture("_Diffuse", 1, self.sdfStyle.textureGL:textureID(), TEXTURE_2D)
                end

                if self.sdfStyle.outline1Enabled then
                    self.sdfPass:setUniform1f("_Outline1Scale", self.sdfStyle.outline1Scale - self.sdfStyle.boldScale);
                    self.sdfPass:setUniform4f("_Outline1Color1", self.sdfStyle.outline1Color1.x,
                        self.sdfStyle.outline1Color1.y, self.sdfStyle.outline1Color1.z, self.sdfStyle.outline1Color1.w)
                end

                if self.sdfStyle.outline2Enabled then
                    self.sdfPass:setUniform1f("_Outline2Scale", self.sdfStyle.outline2Scale - self.sdfStyle.boldScale);
                    self.sdfPass:setUniform4f("_Outline2Color1", self.sdfStyle.outline2Color1.x,
                        self.sdfStyle.outline2Color1.y, self.sdfStyle.outline2Color1.z, self.sdfStyle.outline2Color1.w)
                end

                if self.sdfStyle.outline3Enabled then
                    self.sdfPass:setUniform1f("_Outline3Scale", self.sdfStyle.outline3Scale - self.sdfStyle.boldScale);
                    self.sdfPass:setUniform4f("_Outline3Color1", self.sdfStyle.outline3Color1.x,
                        self.sdfStyle.outline3Color1.y, self.sdfStyle.outline3Color1.z, self.sdfStyle.outline3Color1.w)
                end
                
                self.textMeshBatch[i].mesh2dRender:setUV1Enabled(self.sdfStyle.textureEnabled)
                self.textMeshBatch[i].mesh2dRender:draw(self.sdfPass)
            else
                self.renderPass:use()
                self.renderPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
                self.renderPass:setUniform4f("uColor",
                    self.sdfStyle.color1.x, self.sdfStyle.color1.y, self.sdfStyle.color1.z, self.sdfStyle.color1.w)
                self.renderPass:setUniform4f("uEffectColor",  self.sdfStyle.outline1Color1.x, self.sdfStyle.outline1Color1.y, self.sdfStyle.outline1Color1.z, self.sdfStyle.outline1Color1.w)
                self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mat.x)

                self.renderPass:setUniform1i("uEffectType", 2)
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)
            end

        end
    else
        context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)
        local textColor, outlineSize = self.bmpStyle.color1, self.bmpStyle.outlineSize
        if isShadow then
            textColor = self.bmpStyle.shadowColor
            outlineSize = 0
        end

        for i = 1, #self.textMeshBatch do
            self.renderPass:use()
            self.renderPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
            self.renderPass:setUniform4f("uColor", textColor.x, textColor.y, textColor.z, textColor.w)
            self.renderPass:setUniform4f("uEffectColor", self.bmpStyle.outlineColor.x, self.bmpStyle.outlineColor.y, self.bmpStyle.outlineColor.z, self.bmpStyle.outlineColor.w)
            self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mat.x)

            if outlineSize > 0 and self.textMeshBatch[i].textureFormat ~= RGBA then
                -- OF_LOGI(LabelTag, "text mask draw text bitmap alpha tex with outline")
                self.renderPass:setUniform1i("uEffectType", 1)
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)

                self.renderPass:setUniform1i("uEffectType", 0)
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)
            else
                if self.textMeshBatch[i].textureFormat == RGBA then
                    -- OF_LOGI(LabelTag, "text mask draw text bitmap rgba tex without outline")
                    self.renderPass:setUniform1i("uEffectType", 2)
                else
                    -- OF_LOGI(LabelTag, "text mask draw text bitmap alpha tex without outline")
                    self.renderPass:setUniform1i("uEffectType", 0)
                end
                self.textMeshBatch[i].mesh2dRender:draw(self.renderPass)
            end
        end
    end
end

function LabelPro:renderTextThroughRT(context, outTex)
    local textWidth = (self.lineInfo.maxLineWidth + 2 * self.background.xpadding) * self.textScaleX
    local textHeight = (self.lineInfo.totalHeight + 2 * self.background.ypadding) * self.textScaleY
    local ratio = math.max(textHeight / textWidth, textWidth / textHeight)
    if self.shadowEnabled == true then
        local extraDist = math.max(self.textScaleX, self.textScaleY) * self.sdfStyle.shadowDistance * 2
        if textWidth < textHeight then 
            textWidth = textWidth + extraDist
            textHeight = textHeight + extraDist * ratio 
        else
            textHeight = textHeight + extraDist
            textWidth = textWidth + extraDist * ratio
        end
    end

    if self.animation.extraSpace then
        textWidth, textHeight = textWidth * 2, textHeight * 2
    end

    local textTex = context:getTexture(PixelSize.new(textWidth, textHeight, self.pixelScale))
    context:bindFBO(textTex:toOFTexture())
    context:setViewport(PixelSize.new(textTex:width(), textTex:height(), self.pixelScale))
    context:setClearColor(0.0, 0.0, 0.0, 0.0)
    context:clearColorBuffer()
    
    local mvpMat = Matrix4f:ScaleMat(2 / textWidth, 2 / textHeight, 1.0)
                * self.anchor.scaleMat 

    if self.backgroundEnabled then
        context:setBlend(true)
        context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA)
        if self.backgroundPass == nil then
            self.backgroundPass = context:createCustomShaderPass(Shader.vs, Shader.fs_bg)
        end
        self.backgroundPass:use()
        self.backgroundPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)
        self.backgroundPass:setUniform1f("uWidth", textWidth)
        self.backgroundPass:setUniform1f("uHeight", textHeight)
        self.backgroundPass:setUniform1f("uFeather", self.background.enableFeather)
        self.backgroundPass:setUniform4f("uColor", self.backgroundColor.x, self.backgroundColor.y, self.backgroundColor.z, self.backgroundColor.w)
        self.backgroundMeshBatch:draw(self.backgroundPass, false)
        -- context:setClearColor(self.backgroundColor.x * self.backgroundColor.w, self.backgroundColor.y* self.backgroundColor.w, self.backgroundColor.z* self.backgroundColor.w, self.backgroundColor.w)
        -- context:clearColorBuffer()
    end

    local textRotMat = Matrix4f:RotMat(0, 0, self.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(self.textTransX, self.textTransY, 0.0) 
    
    if self.shadowEnabled == true then
        self.shadowOffsetX = self.textScaleX *self.sdfStyle.shadowDistance
            * math.cos(-self.sdfStyle.shadowAngle * math.pi / 180)
        self.shadowOffsetY = self.textScaleY *self.sdfStyle.shadowDistance
            * math.sin(-self.sdfStyle.shadowAngle * math.pi / 180)
        local shadowMat = Matrix4f:ScaleMat(2 / textWidth, 2 / textHeight, 1.0)
                        * Matrix4f:TransMat(self.shadowOffsetX, self.shadowOffsetY, 0.0)
                        * self.anchor.scaleMat 
 
        self.renderTextShadow(self, context, textTex:toOFTexture(), shadowMat, 1.0)
    end 
                
    self.renderText(self, context, textTex:toOFTexture(), mvpMat, false)

    local textTexTemp = context:getTexture(PixelSize.new(textWidth, textHeight, self.pixelScale))
    self.animation:applyEffect(self, textTex:toOFTexture(), textTexTemp:toOFTexture())

    context:bindFBO(outTex)
    context:setViewport(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
    context:setBlend(true)
    context:setBlendModeSeparate(RS_BlendFunc_ONE, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ZERO, RS_BlendFunc_ONE)
    
    mvpMat = Matrix4f:ScaleMat(2 / outTex.width, 2 / outTex.height, 1.0)
        * textTransMat 
        * self.anchor.transMat 
        * textRotMat 
        * Matrix4f:ScaleMat(0.5 * textWidth, 0.5 * textHeight, 1.0)

    self.renderPass:use()
    self.renderPass:setUniform1i("uEffectType", 2)
    self.renderPass:setUniform1f("uWidth", textWidth);
    self.renderPass:setUniform1f("uHeight", textHeight);
    self.renderPass:setUniformTexture("uTexture0", 0, textTexTemp:textureID(), TEXTURE_2D)
    self.renderPass:setUniform4f("uColor", 1.0, 1.0, 1.0, 1.0)
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)
    
    if textTex then context:releaseTexture(textTex) end
    if textTexTemp then context:releaseTexture(textTexTemp) end
end

function LabelPro:renderTextMaskToScreen(context, inTex, outTex)
    local textTex = context:getTexture(PixelSize.new(outTex.width, outTex.height, self.pixelScale))
    context:bindFBO(textTex:toOFTexture())
    context:setViewport(PixelSize.new(textTex:width(), textTex:height(), self.pixelScale))
    context:setClearColor(0.0, 0.0, 0.0, 0.0)
    context:clearColorBuffer()
    
    local textRotMat = Matrix4f:RotMat(0, 0, self.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(self.textTransX, self.textTransY, 0.0) 
    local mvpMat = Matrix4f:ScaleMat(2 / outTex.width, 2 / outTex.height, 1.0)
            * textTransMat * textRotMat
                * self.anchor.scaleMat 
        
    self.renderTextMask(self, context, textTex:toOFTexture(), mvpMat)

    MaskRender:draw(context, inTex, textTex:toOFTexture(), outTex, Matrix4f:ScaleMat(1.0, 1.0, 1.0))
    
    if textTex then context:releaseTexture(textTex) end
end

function LabelPro:renderTextToScreen(context, outTex)
    local frameWidth, frameHeight = outTex.width, outTex.height
    local textRotMat = Matrix4f:RotMat(0, 0, self.textRotate * math.pi / 180)
    local textTransMat = Matrix4f:TransMat(self.textTransX, self.textTransY, 0.0)
    local mvpMat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
        * textTransMat * self.anchor.transMat * textRotMat * self.anchor.scaleMat

    context:bindFBO(outTex)
    context:setViewport(PixelSize.new(frameWidth, frameHeight, self.pixelScale))
    context:setBlend(true)
    context:setBlendModeSeparate(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA, RS_BlendFunc_ZERO, RS_BlendFunc_ONE)
    
    if self.backgroundEnabled then
        if self.backgroundPass == nil then
            self.backgroundPass = context:createCustomShaderPass(Shader.vs, Shader.fs_bg)
        end
        self.backgroundPass:use()
        self.backgroundPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)
        self.backgroundPass:setUniform1f("uWidth", (self.lineInfo.maxLineWidth + 2 * self.background.xpadding) * self.textScaleX)
        self.backgroundPass:setUniform1f("uHeight", (self.lineInfo.totalHeight + 2 * self.background.ypadding) * self.textScaleY)
        self.backgroundPass:setUniform1f("uRadius", self.background.radius * (self.textScaleX + self.textScaleY) * 0.5)
        self.backgroundPass:setUniform1f("uFeather", self.background.enableFeather)
        self.backgroundPass:setUniform4f("uColor", self.backgroundColor.x, self.backgroundColor.y, self.backgroundColor.z, self.backgroundColor.w)
        self.backgroundMeshBatch:draw(self.backgroundPass, false)
    end
    
    if self.shadowEnabled == true then
        self.shadowOffsetX = self.textScaleX *self.sdfStyle.shadowDistance
            * math.cos(-self.sdfStyle.shadowAngle * math.pi / 180)
        self.shadowOffsetY = self.textScaleY *self.sdfStyle.shadowDistance
            * math.sin(-self.sdfStyle.shadowAngle * math.pi / 180)
        local shadowMat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
            * textTransMat * Matrix4f:TransMat(self.shadowOffsetX, self.shadowOffsetY, 0.0)
            * self.anchor.transMat * textRotMat * self.anchor.scaleMat

        self.renderTextShadow(self, context, outTex, shadowMat, 1.0)
    end
    self.renderText(self, context, outTex, mvpMat, false)
end

function LabelPro:renderDebugTex(context, inTex, debugTex)
    local frameWidth, frameHeight = debugTex.width, debugTex.height
    context:copyTexture(inTex, debugTex)
    context:bindFBO(debugTex)
    context:setViewport(PixelSize.new(frameWidth, frameHeight, self.pixelScale))
    context:setBlend(true)
    context:setBlendMode(RS_BlendFunc_SRC_ALPHA, RS_BlendFunc_INV_SRC_ALPHA)

    if self.shadowEnabled and self.textTextureShadow then

        local mvpMat = Matrix4f:ScaleMat(self.textTextureShadow:width() / frameWidth, self.textTextureShadow:height() / frameHeight, 1.0)

        self.renderPass:use()
        self.renderPass:setUniform1i("uEffectType", 2)
        self.renderPass:setUniformTexture("uTexture0", 0, self.textTextureShadow:textureID(), TEXTURE_2D)
        self.renderPass:setUniform4f("uColor", 1.0, 1.0, 1.0, 1.0)
        self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

        local quadRender = context:sharedQuadRender()
        quadRender:draw(self.renderPass, false)
    else
        local unitWidth = frameWidth / #self.textMeshBatch
        local startX = unitWidth / 2 - frameWidth / 2
        for i = 1, #self.textMeshBatch do
            local mvpMat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
                * Matrix4f:TransMat(startX + unitWidth * (i - 1), 0, 0)
                * Matrix4f:ScaleMat(unitWidth * 0.5 * 0.9, unitWidth * 0.5 * 0.9, 1.0)

            self.renderPass:use()
            self.renderPass:setUniform1i("uEffectType", 0)
            self.renderPass:setUniformTexture("uTexture0", 0, self.textMeshBatch[i].textureId, TEXTURE_2D)
            self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

            local quadRender = context:sharedQuadRender()
            quadRender:draw(self.renderPass, false)
        end
    end
end

function LabelPro:calAnchorInfo()
    local textWidth, textHeight = self.lineInfo.maxLineWidth, self.lineInfo.totalHeight

    local paddingFactor = 0
    if self.backgroundEnabled then paddingFactor = 1 end
    local halfWidth, halfHeight = self.textScaleX * (0.5 * textWidth  + paddingFactor * self.background.xpadding), self.textScaleY * (0.5 * textHeight + paddingFactor * self.background.ypadding)
    
    local anchorType = self.anchor.type

    local anchorX, anchorY = 0, 0
    if self.autoAlignment then 
        if self.anchor.leftX == 0 and self.anchor.rightX == 0 then
            self.anchor.leftX, self.anchor.rightX = -halfWidth, halfWidth
        end 
        if self.textAlignment == 0 then -- left center
            self.anchor.rightX = self.anchor.leftX + 2 * halfWidth
            anchorX = self.anchor.leftX + halfWidth
        elseif self.textAlignment == 1 then -- right center
            self.anchor.leftX = self.anchor.rightX - 2 * halfWidth
            anchorX = self.anchor.rightX - halfWidth
        else
            local anchorWidth = (self.anchor.rightX - self.anchor.leftX)  / 2
            self.anchor.leftX  = self.anchor.leftX - (halfWidth - anchorWidth)
            self.anchor.rightX = self.anchor.rightX + (halfWidth - anchorWidth)
            anchorX = (self.anchor.leftX + self.anchor.rightX ) / 2
        end  
    else
        if anchorType == 1 then -- bottom left
            anchorX, anchorY = anchorX - halfWidth, anchorY + halfHeight
        elseif anchorType == 2 then -- bottom center
            anchorY = anchorY + halfHeight
        elseif anchorType == 3 then -- bottom right
            anchorX, anchorY = anchorX + halfWidth, anchorY + halfHeight
        elseif anchorType == 4 then -- top left
            anchorX, anchorY = anchorX - halfWidth, anchorY - halfHeight
        elseif anchorType == 5 then -- top center
            anchorY = anchorY - halfHeight
        elseif anchorType == 6 then -- top right
            anchorX, anchorY = anchorX + halfWidth, anchorY - halfHeight
        elseif anchorType == 7 then -- left center
            anchorX = anchorX - halfWidth
        elseif anchorType == 8 then -- right center
            anchorX = anchorX + halfWidth
        end  
        anchorX, anchorY = -anchorX, -anchorY
    end 

    local anchorPos = Matrix4f:RotMat(0, 0, self.textRotate * math.pi / 180) * Vec3f.new(anchorX, anchorY, 0.0)
    self.anchor.scaleMat = Matrix4f:ScaleMat(self.textScaleX, self.textScaleY, 1.0) * 
                            Matrix4f:TransMat(-self.lineInfo.x - textWidth / 2, self.lineInfo.y - textHeight / 2, 0.0) * 
                            Matrix4f:ScaleMat(1.0, -1.0, 1.0)
    self.anchor.x = anchorPos.x
    self.anchor.y = anchorPos.y
    self.anchor.transMat = Matrix4f.TransMat(anchorPos.x, anchorPos.y, 0.0)

end

function LabelPro:flush(context)
    if self.dirty then
        -- OF_LOGI(LabelTag, string.format("Animation LabelPro flush string = %s", self.textString))
        self.calcLineInfo(self, context, self.textString)
        self.generateChars(self, context, self.textString, self.lineInfo)
        self.genarateBackground(self, self.lineInfo)
        self.generateMeshBatch(self, context)
        self.dirty = false
    end
    self:calAnchorInfo()
end 
function LabelPro:apply(context, inTex, outTex, debugTex)
    -- OF_LOGI(LabelTag, string.format("Animation LabelPro draw text string = %s", self.textString))
    self:flush(context);
    -- if self.debug then
    --     local cw, ch = self.contentWidth * frameWidth, self.contentHeight * frameHeight
    --     local mat = Matrix4f:ScaleMat(2 / frameWidth, 2 / frameHeight, 1.0)
    --         * textTransMat * textRotMat * contentMat
    --         * Matrix4f:ScaleMat(cw / 2, ch  / 2, 1.0)
    --     self.renderColorRect(self, context, outTex, mat, { 255, 0, 0, 255 })
    -- end
    self.pixelScale = outTex.pixelScale
    if self.animation ~= nil and self.animation.renderToRT == true then
        self.renderTextThroughRT(self, context, outTex)
    elseif MaskRender.maskEnable == true then
        self.renderTextMaskToScreen(self, context, inTex, outTex)
    else
        self.renderTextToScreen(self, context, outTex)
    end

    if debugTex then
        self.renderDebugTex(self, context, inTex, debugTex)
    end

    return OF_Result_Success
end

function LabelPro:setDirty()
    self.dirty = true
    if self.textTextureShadow then
        self.context:releaseTexture(self.textTextureShadow)
        self.textTextureShadow = nil
    end
end

function LabelPro:pathIsAbsolute(p) 
    -- local firstChar = p:sub(1,1)
    -- return firstChar ~= "/" and firstChar ~= "\\";
    return string.match(p, "[\\/]+");
end 

function LabelPro:setString(str)
    if #str == 0 then str = " " end
    if self.textString ~= str then
        OF_LOGI(LabelTag, "setString")
        self.textString = str
        self.setDirty(self)
    end
end

function LabelPro:setFont(fontPath, fontDir)
    if self.fontPath ~= fontPath or self.fontDir ~= fontDir then
        OF_LOGI(LabelTag, "setFont")
        self.fontPath = fontPath
        self.setDirty(self)
    end
end

function LabelPro:setFontSize(size)
    if self.fontSize ~= size then
        OF_LOGI(LabelTag, "setFontSize")
        self.fontSize = size
        self.setDirty(self)
    end
end

function LabelPro:setSDFSpread(spread)
    if self.sdfDistanceMapSpread ~= spread then
        self.sdfDistanceMapSpread = spread
        self.setDirty(self)
    end
end
function LabelPro:setDirection(dir)
    if self.textDirection ~= dir then
        self.textDirection = dir
        self.setDirty(self)
    end
end

function LabelPro:setAlignment(align)
    if self.textAlignment ~= align then
        self.textAlignment = align
        self.setDirty(self)
    end
end

function LabelPro:setSpacing(spacing)
    if self.textSpacing ~= spacing then
        self.textSpacing = spacing
        self.setDirty(self)
    end
end

function LabelPro:setLeading(leading)
    if self.textLeading ~= leading then
        self.textLeading = leading
        self.setDirty(self)
    end
end

function LabelPro:setBoldEnabled(state)
    if self.boldEnabled ~= state then
        self.boldEnabled = state
        self.setDirty(self)
    end
end

function LabelPro:setDistanceFieldEnabled(enable)
    if self.distanceFieldEnabled ~= enable then
        self.distanceFieldEnabled = enable
        self.setDirty(self)

        self.getLineInfo(self, true)
    end
end

function LabelPro:setShadowEnabled(state)
    self.shadowEnabled = state
end

function LabelPro:setSdfStyle(style, filter)
    if self.sdfPass ~= nil then
        self.context:destroyCustomShaderPass(self.sdfPass)
    end

    local defstr = ""
    if self.context:glChecker().isSupportExtension then
        if self.context:glChecker():isSupportExtension("GL_OES_standard_derivatives", "OES_standard_derivatives") then
            defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
        end
    else
        defstr = defstr .. "#define ENABLE_DERIVATIVES\n"
    end

    if style.outline1Enabled then defstr = defstr .. "#define OUTLINE1\n" end 
    if style.outline2Enabled then defstr = defstr .. "#define OUTLINE2\n" end
    if style.outline3Enabled then defstr = defstr .. "#define OUTLINE3\n" end
    if style.textureEnabled then defstr = defstr .. "#define TEXTURE\n" end
    if filter.versionCheckout and filter:versionCheckout(OPTIMIZE_OUTLINE_VERSION) then
        if self.bmpStyle.outlineSize > 0 then
            defstr = defstr .. "#define OPTIMIZE_OUTLINE\n"
        end
    end
    self.sdfPass = self.context:createCustomShaderPass(defstr .. Shader.vs_sdf, defstr .. Shader.fs_sdf)

    if style.textureEnabled and self.sdfStyle.textureEnabled then
        if style.textureScale ~= self.sdfStyle.textureScale then
            self.dirty = true
        end
    end
    self.sdfStyle = style
end

function LabelPro:setBmpStyle(style)
    if self.bmpStyle.outlineSize ~= style.outlineSize then
        self.dirty = true
    end
    if self.bmpStyle.shadowBlurIntensity ~= style.shadowBlurIntensity then   
        bmpBlurRender:setGaussStrength(self.bmpStyle.shadowBlurIntensity)
        self.dirty = true
    end
    self.bmpStyle = style
end

function LabelPro:getSdfStyle()
    return self.sdfStyle
end

function LabelPro:getBmpStyle(style)
    return self.bmpStyle
end

function LabelPro:setBackgroundEnabled(state)
    self.backgroundEnabled = state
end

function LabelPro:setBackground(color, xpaddding, ypadding, radius)
    if self.backgroundColor ~= color then
        self.backgroundColor = color
    end
    if self.background.xpadding ~= xpaddding then
        self.background.xpadding = xpaddding
        self.dirty = true
    end
    if self.background.ypadding ~= ypadding then
        self.background.ypadding = ypadding
        self.dirty = true
    end
    if self.background.radius ~= radius then
        self.background.radius = radius
        self.dirty = true
    end
end

function LabelPro:setContentSize(w, h)
    self.contentWidth = w
    self.contentHeight = h
end

function LabelPro:setAutoScaleEnabled(state)
    self.autoScale = state
end

function LabelPro:setDebug(state)
    self.debug = state
end

function LabelPro:getLineInfo(dump)
    self.calcLineInfo(self, self.context, self.textString)
    if dump then
        self.dumpTextInfo(self, self.context, self.textString)
    end
    return self.lineInfo
end

function LabelPro:setSystemFonts(dir, names)
    if self.systemFontDir ~= dir then
        self.dirty = true
        self.systemFontDir = dir
    end

    local ttfs = {}
    for i = 1, #names do
        if string.sub(names[i], -3) == "ttf" then
            table.insert(ttfs, names[i])
        end
    end
    local cmp = function(a,b) return a == b end
    if not tablex.compare(ttfs, self.systemFontNames, cmp) then
        self.dirty = true
        self.systemFontNames = ttfs
    end
end

function LabelPro:setAnimation(context, anim, style)
    if self.animation ~= anim then
        OF_LOGI(LabelTag, "LabelPro: set different Animation ")
        self.reset(self, context, style)
    end
    self.animation = anim
end

function LabelPro:reset(context, style) 
    if #self.charsBackup ~= 0 then
        OF_LOGI(LabelTag, "LabelPro:reset char and background mesh by deepcopy")
        self.chars = tablex.deepcopy(self.charsBackup)
        self.background = tablex.deepcopy(self.backgroundBackup)
        self.generateMeshBatch(self, context)
    end

    self.sdfStyle.color1.w = style.colorAlpha1
    self.sdfStyle.outline1Color1.w = style.outLine1Alpha
    self.sdfStyle.outline2Color1.w = style.outLine2Alpha
    self.sdfStyle.outline3Color1.w = style.outLine3Alpha
    self.sdfStyle.shadowColor.w = style.shadowAplha
    self.backgroundColor.w = style.backgroundAlpha
end

return LabelPro
