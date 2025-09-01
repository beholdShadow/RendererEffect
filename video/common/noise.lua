local TAG = "NoiseRender"
local NoiseRender = {
    vs = [[
        precision highp float;
        uniform mat4 uMVP;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTexCoord;
        void main()
        {
            gl_Position = uMVP * aPosition;
            vTexCoord = aTextureCoord.xy;
        }
        ]],
    fs_value = [[
        precision highp float;
        uniform float uTexWidth;
        uniform float uTexHeight;
        uniform float uNoiseOpacity;

        varying vec2 vTexCoord;

        float hash(vec2 p)  // replace this by something better
        {
            p  = 50.0*fract( p*0.3183099 + vec2(0.71,0.113));
            return -1.0+2.0*fract( p.x*p.y*(p.x+p.y) );
        }

        float noise(vec2 p )
        {
            vec2 i = floor( p );
            vec2 f = fract( p );
            
            vec2 u = f*f*(3.0-2.0*f);

            return mix( mix( hash( i + vec2(0.0,0.0) ), 
                            hash( i + vec2(1.0,0.0) ), u.x),
                        mix( hash( i + vec2(0.0,1.0) ), 
                            hash( i + vec2(1.0,1.0) ), u.x), u.y);
        }
 
        float fbm(vec2 uv)
        {
            uv *= 8.0;
            float f = 0.0;
            mat2 m = mat2( 1.6,  1.2, -1.2,  1.6 );
            f  = 0.5000*noise( uv ); uv = m*uv;
            f += 0.2500*noise( uv ); uv = m*uv;
            f += 0.1250*noise( uv ); uv = m*uv;
            f += 0.0625*noise( uv ); uv = m*uv;

            return f;
        }

        void main()
        {
            vec2 uv = vec2(vTexCoord.x * uTexWidth, vTexCoord.y * uTexHeight);
            float f = noise(uv);
            f = 0.5 + 0.5*f;
            gl_FragColor = vec4(f, f, f, f);
        }
        ]],
    noiseValuePass = nil,
    nosieNum = 50
}

function NoiseRender:initParams(context, filter)
    filter:insertFloatParam("NoiseNum", 0, 100, 50)
end

function NoiseRender:onApplyParams(context, filter)
    self.nosieNum = filter:floatParam("NoiseNum")
end

function NoiseRender:initRenderer(context, filter)
    OF_LOGI(TAG, "call NoiseRender initRenderer")
    self.noiseValuePass = context:createCustomShaderPass(self.vs, self.fs_value)
end

function NoiseRender:teardown(context, filter)
    OF_LOGI(TAG, "call NoiseRender teardownRenderer")
    if self.noiseValuePass then
        context:destroyCustomShaderPass(self.noiseValuePass)
        self.noiseValuePass = nil
    end
end

function NoiseRender:draw(context, outTex)
    if outTex == nil then
        return
    end
    
    context:bindFBO(outTex)
    context:setViewport(0, 0, outTex.width, outTex.height)
    context:setBlend(false)
    
    self.noiseValuePass:use()
    self.noiseValuePass:setUniform1f("uTexWidth", outTex.width)
    self.noiseValuePass:setUniform1f("uTexHeight", outTex.height)
    self.noiseValuePass:setUniformMatrix4fv("uMVP", 1, 0, Matrix4f.new().x)

    local quadRender = context:sharedQuadRender()
    quadRender:draw(self.noiseValuePass, false)
end

return NoiseRender