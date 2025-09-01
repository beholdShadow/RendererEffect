local EffectList = {
    effectList = {},
    effectPaths = {}
}

function EffectList:init(context)
end

function EffectList:isEmpty()
    return #self.effectList == 0
end

function EffectList:isSamePaths(paths)
    if #paths ~= #self.effectPaths then
        return false
    end

    for i = 1, #paths do
        if paths[i] ~= self.effectPaths[i] then
            return false
        end
    end
    return true
end

function EffectList:clear(context)
    local cnt = #self.effectList
    for i = 1, cnt do
        if self.effectList[i].inited then
            context:destroyEffect(self.effectList[i].id)
        end
    end
    self.effectList = {}
end

function EffectList:setEffectPaths(context, paths)
    if not self.isSamePaths(self, paths) then
        self.clear(self, context)
        for i = 1, #paths do
            local effectPath = paths[i]
            effectPath = string.gsub(effectPath, "\\", "/")
            local effectDir = string.match(effectPath, ".*/")
            table.insert(self.effectList, { id = 0,
                                            enabled = false, 
                                            inited = false,
                                            effectDir = effectDir,
                                            effectPath = effectPath,
                                            lastMsg = nil })
        end
        self.effectPaths = paths
    end
end

function EffectList:applyBatch(context, idList, frameData, inTex, outTex, debugTex, filterTimestamp)
    local width = inTex.width
    local height = inTex.height
    local cachedTexture = context:getTexture(width, height)
    local tempTex = cachedTexture:toOFTexture()

    local isOddCount = false
    if (#idList % 2) ~= 0 then
        isOddCount = true
    end

    local pIn, pOut = outTex, tempTex
    if isOddCount == true then
        pIn, pOut = tempTex, outTex
    end

    local timestamp = filterTimestamp * 1000
    local t = i64.new(timestamp)
    context:seekEffectAnimation(idList[1], t)

    context:applyRGBA(idList[1], frameData, inTex, pOut, debugTex)

    for i = 2, #idList do
        pIn, pOut = pOut, pIn
        context:seekEffectAnimation(idList[i], t)
        context:applyRGBA(idList[i], frameData, pIn, pOut, debugTex)
    end

    context:releaseTexture(cachedTexture)
end

function EffectList:dump()
    for i = 1, #self.effectList do
        print(i, self.effectList[i].id, self.effectList[i].enabled)
    end
end

function EffectList:apply(context, frameData, inTex, outTex, debugTex, filterTimestamp)
    --self.dump(self)
    local ids = {}
    for i = 1, #self.effectList do
        if self.effectList[i].enabled then
            if self.effectList[i].inited == false then
                local effectId = context:createEffectFromFile(self.effectList[i].effectPath, self.effectList[i].effectDir)
                if effectId > 0 then
                    self.effectList[i].inited = true
                    self.effectList[i].id = effectId
                    if self.effectList[i].lastMsg ~= nil then
                        context:sendMessage(self.effectList[i].id, self.effectList[i].lastMsg)
                        self.effectList[i].lastMsg = nil
                    end
                else
                    OF_LOGE("EffectList", string.format("Create effect failed. %s", effectPath))
                end
            end

            if self.effectList[i].inited then
                table.insert(ids, self.effectList[i].id)
            end
        end
    end

    if #ids > 0 then
        self.applyBatch(self, context, ids, frameData, inTex, outTex, debugTex, filterTimestamp)
    else
        context:copyTexture(inTex, outTex)
    end
end

function EffectList:setEnabled(idx, enabled)
    if idx <= #self.effectList then
        print("setEnabled", idx, enabled)
        self.effectList[idx].enabled = enabled
    end
end

function EffectList:sendMessage(context, idx, msg)
    if idx <= #self.effectList then
        if self.effectList[idx].inited == false then
            self.effectList[idx].lastMsg = msg
        else
            context:sendMessage(self.effectList[idx].id, msg)
        end
    end
end

return EffectList