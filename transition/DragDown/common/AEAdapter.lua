local Utils = require("common.Utils")

-- GrabKeyFrameInfo.jsx: KeyFrame path: TRACK_GROUP_NAME/TRACK_NAME
--  AttributeReader.jsx: PerFrame path: TRACK_GROUP_NAME.TRACK_NAME

---@class AEAdapter
local AEAdapter = {}
AEAdapter.__index = AEAdapter
AEAdapter.EPSILON = 0.001


function AEAdapter:new ()
    local self = setmetatable({}, AEAdapter)
    self._tracks = {}
    return self
end


---@param layerName string
---@param layerData table<string, table>
function AEAdapter:addKeyframes (layerName, layerData)
    for trackName, trackData in pairs(layerData) do
        local trackPath = layerName.."/"..trackName
        trackData.keyframe = true
        self._tracks[trackPath] = trackData
    end
end


---@param layerName string
---@param layerData table
function AEAdapter:addFrames (layerName, layerData)
    layerData = layerData.layer0
    self:_addFramesVec2(layerName, layerData, "position")
    self:_addFramesVec2(layerName, layerData, "anchor")
    self:_addFramesVec2(layerName, layerData, "scale")
    self._tracks[layerName..".rotate"] = layerData.rotate
    self._tracks[layerName..".opacity"] = layerData.opacity
end


---@param track string
---@param frame number
---@return number|number[]
function AEAdapter:get (track, frame)
    track = self._tracks[track]
    if not track then
        return
    end
    if not track.keyframe then
        frame = Utils.clamp(frame, 0, #track - 1)
        local f0 = math.floor(frame)
        local f1 = math.ceil(frame)
        local t = frame - f0
        return self._interpolateFrame(track[f0+1], track[f1+1], t)
    end

    if frame <= track[1][3] then
        return track[1][4]
    end
    for i = 2, #track do
        local keyframe1 = track[i]
        if frame < keyframe1[3] then
            local keyframe0 = track[i - 1]
            local x = Utils.step(keyframe0[3], keyframe1[3], frame)
            return self._interpolateKeyframe(keyframe0, keyframe1, x)
        end
    end
    return track[#track][4]
end




function AEAdapter:_addFramesVec2 (name, data, attr)
    data = data[attr]
    if not data then
        return
    end
    local path = name.."."..attr

    if data[1] then
        self._tracks[path] = data
        return
    end

    if data.x then
        self._tracks[path..".x"] = data.x
    end
    if data.y then
        self._tracks[path..".y"] = data.y
    end
end

function AEAdapter._interpolateKeyframe (k0, k1, x)
    local x1 = k0[2][1]
    local x2 = 1 - k1[1][1]
    local t_ = 0
    local _t = 1
    local bezier4 = Utils.bezier4
    repeat
        local _t_ = (t_ + _t) * 0.5
        local _x_ = bezier4(_t_, 0, x1, x2, 1)
        if _x_ > x then
            _t = _t_
        else
            t_ = _t_
        end
    until _t - t_ < AEAdapter.EPSILON

    local t = (t_ + _t) * 0.5
    local y0 = k0[4]
    local y1 = y0 + k0[2][2]
    local y3 = k1[4]
    local y2 = y3 - k1[1][2]
    return bezier4(t, y0, y1, y2, y3)
end

function AEAdapter._interpolateFrame (f0, f1, t)
    local mix = Utils.mix
    if type(f0) == "number" then
        return mix(f0, f1, t)
    end

    local v = {}
    for i = 1, #f0 do
        v[i] = mix(f0[i], f1[i], t)
    end
    return v
end


return AEAdapter

