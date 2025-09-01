local function getBezierValue(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3*xc1*(1-t)*(1-t)*t+3*xc2*(1-t)*t*t+t*t*t
    ret[2] = 3*yc1*(1-t)*(1-t)*t+3*yc2*(1-t)*t*t+t*t*t
    return ret
end

local function getBezierDerivative(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3*xc1*(1-t)*(1-3*t)+3*xc2*(2-3*t)*t+3*t*t
    ret[2] = 3*yc1*(1-t)*(1-3*t)+3*yc2*(2-3*t)*t+3*t*t
    return ret
end

local function getBezierTfromX(controls, x)
    local ts = 0
    local te = 1
    -- divide and conque
    repeat
        local tm = (ts+te)/2
        local value = getBezierValue(controls, tm)
        if(value[1]>x) then
            te = tm
        else
            ts = tm
        end
    until(te-ts < 0.0001)

    return (te+ts)/2
end

local function bezier(controls)
	return function (t, b, c, d)
		t = t/d
		local tvalue = getBezierTfromX(controls, t)
		local value =  getBezierValue(controls, tvalue)
		return b + c * value[2]
	end
end

local function funcEaseBlurAction1(t, b, c, d)
    t = t/d
    -- diyijieduandeweiyiquxian，beisaierquxianbanben
    local controls = {.05,.71,.61,.99}
    local tvalue = getBezierTfromX(controls, t)
    local deriva = getBezierDerivative(controls, tvalue)
    return math.abs(deriva[2] / deriva[1]) * c
end

local function funcEaseAction3(t, b, c, d)
    t= t/d
    -- diyijieduandeweiyiquxian，zhegeshigongshibanben
    if t~=0.0 and t~=1.0 then
        t = math.exp(-7.0 * t) * 1.0 * math.sin((t - 0.075) * (2.0*math.pi) / 0.3) + 1.0
    end
    return Amaz.Ease.linearFunc(t,c,b)
end

local function funcEaseBlurAction3(t, b, c, d)
    t=t/d
    -- diyijieduandemohuquxian，zhegeshigongshibanben
    t = math.abs(2 ^(-5.0 * t) * math.log(2) * math.sin(2.5 * math.pi * t - 0.5 * math.pi) + 2 ^(-5.0 * t) * math.cos(2.5 * math.pi * t - 0.5 * math.pi))
    
    return c * t
end
local function clamp(min, max, value)
	return math.min(math.max(value, 0), 1)
end

local function saturate(value)
	return clamp(0, 1, value)
end

local function lerp(a, b, c)
	c = saturate(0, 1, c)
	return (1 - c) * a + c * b
end

local function lerpVector3(a, b, c)
	c = saturate(0, 1, c)
	return Amaz.Vector3f(
		lerp(a.x, b.x, c),
		lerp(a.y, b.y, c),
		lerp(a.z, b.z, c)
	)
end

local function remap(smin, smax, dmin, dmax, value)
	return (value - smin) / (smax - smin) * (dmax - dmin) + dmin
end

local function remapClamped(smin, smax, dmin, dmax, value)
	return saturate(value - smin) / (smax - smin) * (dmax - dmin) + dmin
end

local function remapVector3(smin, smax, dmin, dmax, value)
	return Amaz.Vector3f(
		remap(smin.x, smax.x, dmin.x, dmax.x, value.x),
		remap(smin.y, smax.y, dmin.y, dmax.y, value.y),
		remap(smin.z, smax.z, dmin.z, dmax.z, value.z)
	) 
end

local function remapVector4(smin, smax, dmin, dmax, value)
	return Amaz.Vector3f(
		remap(smin.x, smax.x, dmin.x, dmax.x, value.x),
		remap(smin.y, smax.y, dmin.y, dmax.y, value.y),
		remap(smin.z, smax.z, dmin.z, dmax.z, value.z),
		remap(smin.w, smax.w, dmin.w, dmax.w, value.w)
	) 
end

local function playAnimation(info, nt, setValue)
	for key, value in pairs(info.default) do
		setValue(key, value)
	end
	for key, value in pairs(info.animations) do
		for index, keyframe in pairs(value) do
			if nt >= keyframe[1] and nt <= keyframe[2] then
				local func
				if type(keyframe[5]) == 'function' then
					func = keyframe[5]
				elseif type(keyframe[5]) == 'table' and #keyframe[5] == 4 then
					func = bezier(keyframe[5])
				end
				if type(func) == 'function' then
					local t = nt - keyframe[1]
					if keyframe[6] then t = 1 - t end
					if type(keyframe[3]) == 'number' and type(keyframe[4]) == 'number' then
						setValue(key, func(t, keyframe[3], keyframe[4] - keyframe[3], keyframe[2] - keyframe[1]))
					elseif type(keyframe[3]) == 'table'
						and type(keyframe[4]) == 'table'
						and #keyframe[3] == #keyframe[4] then
						local values = {}
						for i = 1, #keyframe[3] do
							values[i] = func(t, keyframe[3][i], keyframe[4][i] - keyframe[3][i], keyframe[2] - keyframe[1])
						end
						setValue(key, values)
					end
				end
				break
			elseif nt < keyframe[1] then
				if index > 1 then
					local val = value[index - 1][4]
					if value[index - 1][6] then val = value[index - 1][3] end
					setValue(key, val)
				end
				break
			elseif nt > keyframe[2] then
				local val = value[index][4]
				if keyframe[6] then val = value[index][3] end
				setValue(key, val)
			end
		end
	end
end

local function anchor(pivot, anchor, halfWidth, halfHeight, translate, rotate, scale)
	local anchor = Vec4f.new(
		remap(-.5, .5, 1, -1, pivot[1]) * halfWidth + remap(-.5, .5, -(1 - scale.x), 1 - scale.x, anchor[1]) * halfWidth,
		remap(-.5, .5, 1, -1, pivot[2]) * halfHeight + remap(-.5, .5, -(1 - scale.y), 1 - scale.y, anchor[2]) * halfHeight,
		0,
		1
	)
	local mat = Matrix4f:TransMat(
					remap(-.5, .5, -1, 1, pivot[1]) * halfWidth,
					remap(-.5, .5, -1, 1, pivot[2]) * halfHeight,
					0) * Matrix4f:RotMat(rotate.x / 180 * math.pi, rotate.y / 180 * math.pi, rotate.z / 180 * math.pi)

	anchor = mat * anchor
	translate.x = translate.x + anchor.x
	translate.y = translate.y + anchor.y
	translate.z = translate.z + anchor.z
	return translate, rotate, scale
end

local BounceOut = {
    duration = 1000,
    timestamp = 0,
}

function BounceOut:init(filter)
end

function BounceOut:clear(filter)
end

function BounceOut:animate()
	return {
		-- ['playSpeed'] = 30,
		['anchor'] = {0, 0},
		['pivot'] = {0, 0},
		['default'] = {
			['blurType'] = 0,
            ['blurDirection'] = {0, 1},
            ['blurStep'] = 0,
			['translate'] = {0, 0, 0},
			-- ['translate.x'] = 0,
			-- ['translate.y'] = 0,
			-- ['translate.z'] = 0,
			['rotate'] = {0, 0, 0},
			-- ['rotate.x'] = 0,
			-- ['rotate.y'] = 0,
			-- ['rotate.z'] = 0,
			['scale'] = {1, 1, 1},
			-- ['scale.x'] = 0,
			-- ['scale.y'] = 0,
			-- ['scale.z'] = 0,
		},
		['animations'] = {
			-- 0 none 1 motion 2 scale
			['blurType'] = {
				{0, 1, 0, 0, {0, 0, 1, 1}},
			},
			['blurDirection'] = {
				{0, 1, {0, 1}, {0, 1}, {0, 0, 1, 1}}
			},
			['blurStep'] = {
				{0, 1, 1, 0, funcEaseBlurAction3, true},
			},
			['translate'] = {
			},
			['translate.x'] = {
			},
			['translate.y'] = {
			},
			['translate.z'] = {
			},
			['rotate'] = {
			},
			['rotate.x'] = {
			},
			['rotate.y'] = {
			},
			['rotate.z'] = {
			},
			['scale'] = {
				{0, .43, {1, 1, 1}, {1.1, 1.1, 1.1}, {0.20, 0.00, 0.13, 1.00}},
				{.43, 1, {1.1, 1.1, 1.1}, {0, 0, 0}, {1.00, 0.00, 0.72, 1.00}}
			},
			['scale.x'] = {
			},
			['scale.y'] = {
			},
			['scale.z'] = {
			}
		}
	}
end

function BounceOut:animateChar(char)
	return {
		['mode'] = 0,
		['duration'] = .8,
		['anchor'] = {0, 0},
		['pivot'] = {0, 0},
		['default'] = {
			['translate'] = {0, 0, 0},
			-- ['translate.x'] = 0,
			-- ['translate.y'] = 0,
			-- ['translate.z'] = 0,
			['rotate'] = {0, 0, 0},
			-- ['rotate.x'] = 0,
			-- ['rotate.y'] = 0,
			-- ['rotate.z'] = 0,
			['scale'] = {1, 1, 1},
			-- ['scale.x'] = 0,
			-- ['scale.y'] = 0,
			-- ['scale.z'] = 0,
			['color'] = {1, 1, 1, 1},
			-- ['color.x'] = 1,
			-- ['color.y'] = 1,
			-- ['color.z'] = 1,
			-- ['color.w'] = 1,
		},
		['animations'] = {
			['translate'] = {
			},
			['translate.x'] = {
			},
			['translate.y'] = {
			},
			['translate.z'] = {
			},
			['rotate'] = {
			},
			['rotate.x'] = {
			},
			['rotate.y'] = {
			},
			['rotate.z'] = {
			},
			['scale'] = {
			},
			['scale.x'] = {
			},
			['scale.y'] = {
			},
			['scale.z'] = {
			},
			['color'] = {
			},
			['color.x'] = {
			},
			['color.y'] = {
			},
			['color.z'] = {
			},
			['color.w'] = {
			},
		}
	}
end

function BounceOut:setDuration(filter, duration)
    self.duration = duration
end

function BounceOut:seek(filter, timestamp)
    self.timestamp = timestamp
end

function BounceOut:apply(filter)
    self.count = #filter.label.chars
	local time = self.timestamp
    --print("Printer1", self.timestamp, self.timestamp / (self.duration / count))
    for i = 1, self.count do
        local char = filter.label.chars[i]
        local charBackup = filter.label.charsBackup[i]
		local info = self:animateChar(char)
		local nt = 0
		-- if info.mode == 0 then
			local late = 0
			if self.count > 1 then
				late = (1 - info.duration) / (self.count - 1) * (i - 1)
			end
			if time / self.duration >= late then
				nt = saturate((time / self.duration - late) / info.duration)
			end
		-- else
			-- local duration = Amaz.Ease.linear((self.count - i + 1) / self.count, 0, self.duration, 1)
			-- nt = (time - (self.duration - duration)) / duration
		-- end
		local translate = Vec3f.new(0.0, 0.0, 0.0)
		local rotate = Vec3f.new(0.0, 0.0, 0.0)
		local scale = Vec3f.new(1.0, 1.0, 1.0)
		local color = Vec4f.new(1.0, 1.0, 1.0, 1.0)
		playAnimation(info, nt, function (key, value)
			if key == 'translate.x' then
				translate.x = value
			elseif key == 'translate.y' then
				translate.y = value
			elseif key == 'translate.z' then
				translate.z = value
			elseif key == 'translate' and type(value) == 'table' then
				translate:set(value[1], value[2], value[3])
			elseif key == 'rotate.x' then
				rotate.x = value
			elseif key == 'rotate.y' then
				rotate.y = value
			elseif key == 'rotate.z' then
				rotate.z = value
			elseif key == 'rotate' and type(value) == 'table' then
				rotate:set(value[1], value[2], value[3])
			elseif key == 'scale.x' then
				scale.x = value
			elseif key == 'scale.y' then
				scale.y = value
			elseif key == 'scale.z' then
				scale.z = value
			elseif key == 'scale' and type(value) == 'table' then
				scale:set(value[1], value[2], value[3])
			elseif key == 'color.x' then
				color.x = value
			elseif key == 'color.y' then
				color.y = value
			elseif key == 'color.z' then
				color.z = value
			elseif key == 'color.w' then
				color.w = value
			elseif key == 'color' and type(value) == 'table' then
				color:set(value[1], value[2], value[3], value[4])
			end
		end)
		
		local charWidth = charBackup.pos[3] - charBackup.pos[1]
		local charHeight = charBackup.pos[2] - charBackup.pos[6]
		translate, rotate, scale = anchor(info['pivot'], info['anchor'], charWidth / 3, charHeight / 3, translate, rotate, scale)

		local mvpMat = Matrix4f:TransMat(translate.x, translate.y, translate.z) *
					Matrix4f:RotMat(rotate.x, rotate.y, rotate.z) *  
					Matrix4f:ScaleMat(scale.x, scale.y, scale.z)

		for n = 1, 4 do
			local pos = Vec4f.new(charBackup.pos[2*n-1], charBackup.pos[2*n], 0.0, 1.0)
			pos = mvpMat * pos 
			char.pos[2*n-1] = pos.x
			char.pos[2*n] = pos.y
		end
    end

	local info = self:animate()
	local translate = Vec3f.new(0.0, 0.0, 0.0)
	local rotate = Vec3f.new(0.0, 0.0, 0.0)
	local scale = Vec3f.new(1.0, 1.0, 1.0)
	-- local realTime = time - time % (1 / info.playSpeed)
	playAnimation(info, time / self.duration, function (key, value)
		if key == 'translate.x' then
			translate.x = value
		elseif key == 'translate.y' then
			translate.y = value
		elseif key == 'translate.z' then
			translate.z = value
		elseif key == 'translate' and type(value) == 'table' then
			translate:set(value[1], value[2], value[3])
		elseif key == 'rotate.x' then
			rotate.x = value
		elseif key == 'rotate.y' then
			rotate.y = value
		elseif key == 'rotate.z' then
			rotate.z = value
		elseif key == 'rotate' and type(value) == 'table' then
			rotate:set(value[1], value[2], value[3])
		elseif key == 'scale.x' then
			scale.x = value
		elseif key == 'scale.y' then
			scale.y = value
		elseif key == 'scale.z' then
			scale.z = value
		elseif key == 'scale' and type(value) == 'table' then
			scale:set(value[1], value[2], value[3])
		-- elseif key == 'blurType' then
        --     self.materials:get(0):enableMacro('BLUR_TYPE', value)
        -- elseif key == 'blurDirection' then
        --     self.materials:get(0):setVec2('blurDirection', Amaz.Vector2f(value[1], value[2]))
        -- elseif key == 'blurStep' then
		-- 	self.materials:get(0):setFloat('blurStep', value)
		-- elseif key == 'alpha' then
        --     self.materials:get(0):setFloat('alpha', value)
		end
	end)
	local halfOutputHeight = 1280 / 2
	local lineInfo = filter.label:getLineInfo()
	-- local halfOutputHeight = Amaz.BuiltinObject:getOutputTextureHeight() / 2
	local halfWidth = 0
	local halfHeight = 0
	halfWidth = lineInfo.maxLineWidth / 2 / halfOutputHeight
	halfHeight = lineInfo.totalHeight / 2 / halfOutputHeight

	translate, rotate, scale = anchor(info['pivot'], info['anchor'], halfWidth, halfHeight, translate, rotate, scale)
	
	local mvpMat = Matrix4f:TransMat(lineInfo.maxLineWidth / 2.0, -(lineInfo.totalHeight/2 - lineInfo.maxLineHeight), 0.0) *
					Matrix4f:TransMat(translate.x, translate.y, translate.z) *
					Matrix4f:RotMat(rotate.x, rotate.y, rotate.z) *  
					Matrix4f:ScaleMat(scale.x, scale.y, scale.z) * 
					Matrix4f:TransMat(-lineInfo.maxLineWidth / 2.0, lineInfo.totalHeight/2 - lineInfo.maxLineHeight, 0.0)

	for i = 1, self.count do
		local char = filter.label.chars[i]
		for n = 1, 4 do
			local pos = Vec4f.new(char.pos[2*n-1], char.pos[2*n], 0.0, 1.0)
			pos = mvpMat * pos 
			char.pos[2*n-1] = pos.x
			char.pos[2*n] = pos.y
		end
    end
end

return BounceOut