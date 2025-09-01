TAG = "Transition-Filter"
OF_LOGI(TAG, "Call transition lua script!")

local Filter = {
    name = "Transition-Filter",
    context = nil,
    frameWidth = 0,
    frameHeight = 0,
    vs = [[
        precision mediump float;
        attribute vec4 aPosition;
        attribute vec2 aTextureCoord;
        varying vec2 vTexCoord;

        void main() {
            gl_Position = aPosition;
            vTexCoord = aTextureCoord;
        }
    ]],

    fs = [[
        precision mediump float;
        varying vec2 vTexCoord;
        uniform sampler2D uTexture0;
        uniform sampler2D uTexture1;
        uniform float progress;

        vec4 getFromColor(vec2 uv)
        {
            return texture2D(uTexture0, uv);
        }

        vec4 getToColor(vec2 uv)
        {
            return texture2D(uTexture1, uv);
        }

        //--------replace next -----------
        uniform float persp;
uniform float unzoom;
uniform float reflection;
uniform float floating;

vec2 project (vec2 p) {
  return p * vec2(1.0, -1.2) + vec2(0.0, -floating/100.);
}

bool inBounds (vec2 p) {
  return all(lessThan(vec2(0.0), p)) && all(lessThan(p, vec2(1.0)));
}

vec4 bgColor (vec2 p, vec2 pfr, vec2 pto) {
  vec4 c = vec4(0.0, 0.0, 0.0, 1.0);
  pfr = project(pfr);
  // FIXME avoid branching might help perf!
  if (inBounds(pfr)) {
    c += mix(vec4(0.0), getFromColor(pfr), reflection * mix(1.0, 0.0, pfr.y));
  }
  pto = project(pto);
  if (inBounds(pto)) {
    c += mix(vec4(0.0), getToColor(pto), reflection * mix(1.0, 0.0, pto.y));
  }
  return c;
}

// p : the position
// persp : the perspective in [ 0, 1 ]
// center : the xcenter in [0, 1] \ 0.5 excluded
vec2 xskew (vec2 p, float persp, float center) {
  float x = mix(p.x, 1.0-p.x, center);
  return (
    (
      vec2( x, (p.y - 0.5*(1.0-persp) * x) / (1.0+(persp-1.0)*x) )
      - vec2(0.5-distance(center, 0.5), 0.0)
    )
    * vec2(0.5 / distance(center, 0.5) * (center<0.5 ? 1.0 : -1.0), 1.0)
    + vec2(center<0.5 ? 0.0 : 1.0, 0.0)
  );
}

vec4 transition(vec2 op) {
  float uz = unzoom * 2.0*(0.5-distance(0.5, progress));
  vec2 p = -uz*0.5+(1.0+uz) * op;
  vec2 fromP = xskew(
    (p - vec2(progress, 0.0)) / vec2(1.0-progress, 1.0),
    1.0-mix(progress, 0.0, persp),
    0.0
  );
  vec2 toP = xskew(
    p / vec2(progress, 1.0),
    mix(pow(progress, 2.0), 1.0, persp),
    1.0
  );
  // FIXME avoid branching might help perf!
  if (inBounds(fromP)) {
    return getFromColor(fromP);
  }
  else if (inBounds(toP)) {
    return getToColor(toP);
  }
  return bgColor(op, fromP, toP);
}

        //--------replace upper -----------

        void main() {
            gl_FragColor = transition(vTexCoord);
        }

    ]], 
    renderPass = nil,
    percent = 0.0,
    duration = 1.0,
}

function Filter:initParams(context, filter)
    filter:insertFloatParam("Duration", 0.0, 10.0, self.duration)
    return OF_Result_Success
end

function Filter:onApplyParams(context, filter)
    self.duration = filter:floatParam("Duration")
    return OF_Result_Success
end

function Filter:initRenderer(context, filter)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
    return OF_Result_Success
end

function Filter:teardownRenderer(context, filter)
    context:destroyCustomShaderPass(self.renderPass)
    return OF_Result_Success
end

function Filter:applyFrame(context, filter, frameData, inArray, outArray)
    local timestamp = filter:filterTimestamp()
    if timestamp < self.duration then
        self.percent = timestamp / self.duration
    else
        self.percent = 1.0
    end

    if inArray[2] ~= nil then
        context:bindFBO(outArray[1])
        context:setViewport(0, 0, outArray[1].width, outArray[1].height)

        self.renderPass:use()
        self.renderPass:setTexture("uTexture0", 0, inArray[1])
        self.renderPass:setTexture("uTexture1", 1, inArray[2])
        self.renderPass:setUniform1f("progress", self.percent)
        self.renderPass:setUniform1f("persp", 0.7)
        self.renderPass:setUniform1f("unzoom", 0.3)
        self.renderPass:setUniform1f("reflection", 0.4)
        self.renderPass:setUniform1f("floating", 3.0)

        local quadRender = context:sharedQuadRender()
        quadRender:draw(self.renderPass, false)
    end

    if outArray[2] ~= nil then
        context:copyTexture(inArray[1], outArray[2])
    end

    return OF_Result_Success
end

function Filter:requiredFrameData(context, game)
    return { OF_RequiredFrameData_None }
end

function Filter:onReceiveMessage(context, filter, msg)
    return ""
end

return Filter