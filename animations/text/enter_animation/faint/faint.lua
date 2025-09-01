local TAG = "OrangeFilter-AnimationFaint"
local Faint = {
    tag = "Faint",
    duration = 1000,
    timestamp = 0,
    renderToRT = true,
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
    fs = [[
        precision highp float;
        varying highp vec2 vTexCoord;
        uniform sampler2D uTexture0;
        // uniform vec2 u_TextRect;
        uniform vec2 u_Radius;
        uniform float u_Frequency;
        uniform float u_MaskFrequency;
        uniform float u_TwistRotFactor;
        uniform float u_TwistFactor;
        uniform vec2 u_NoisePos;
        uniform float u_Alpha;
        const float PI = 3.141592653589793;
        
        vec2 rotate(vec2 uv, float angle)
        {
            float theta = angle / 180.0 * PI;
            mat2 rotMat2 = mat2(cos(theta), -sin(theta)
                                ,sin(theta), cos(theta));
            return rotMat2 * uv;
        }
        
        
        vec2 random2(vec2 st){
            st = vec2( dot(st,vec2(127.1,311.7)),
                      dot(st,vec2(269.5,183.3)) );
            return -1.0 + 2.0*fract(sin(st)*43758.5453123);
        }
        const mat2 mtx = mat2( 0.80,  0.60, -0.60,  0.80 );
        
        float noise(vec2 st) {
            vec2 i = floor(st);
            vec2 f = fract(st);
        
            vec2 u = f*f*(3.0-2.0*f);
        
            return mix( mix( dot( random2(i + vec2(0.0,0.0) ), f - vec2(0.0,0.0) ),
                             dot( random2(i + vec2(1.0,0.0) ), f - vec2(1.0,0.0) ), u.x),
                        mix( dot( random2(i + vec2(0.0,1.0) ), f - vec2(0.0,1.0) ),
                             dot( random2(i + vec2(1.0,1.0) ), f - vec2(1.0,1.0) ), u.x), u.y);
        }
        
        /* discontinuous pseudorandom uniformly distributed in [-0.5, +0.5]^3 */
        vec3 random3(vec3 c) {
            float j = 4096.0*sin(dot(c,vec3(17.0, 59.4, 15.0)));
            vec3 r;
            r.z = fract(512.0*j);
            j *= .125;
            r.x = fract(512.0*j);
            j *= .125;
            r.y = fract(512.0*j);
            return r-0.5;
        }
        
        /* skew constants for 3d simplex functions */
        const float F3 =  0.3333333;
        const float G3 =  0.1666667;
        
        /* 3d simplex noise */
        float simplex3d(vec3 p) {
             /* 1. find current tetrahedron T and it's four vertices */
             /* s, s+i1, s+i2, s+1.0 - absolute skewed (integer) coordinates of T vertices */
             /* x, x1, x2, x3 - unskewed coordinates of p relative to each of T vertices*/
             
             /* calculate s and x */
             vec3 s = floor(p + dot(p, vec3(F3)));
             vec3 x = p - s + dot(s, vec3(G3));
             
             /* calculate i1 and i2 */
             vec3 e = step(vec3(0.0), x - x.yzx);
             vec3 i1 = e*(1.0 - e.zxy);
             vec3 i2 = 1.0 - e.zxy*(1.0 - e);
                 
             /* x1, x2, x3 */
             vec3 x1 = x - i1 + G3;
             vec3 x2 = x - i2 + 2.0*G3;
             vec3 x3 = x - 1.0 + 3.0*G3;
             
             /* 2. find four surflets and store them in d */
             vec4 w, d;
             
             /* calculate surflet weights */
             w.x = dot(x, x);
             w.y = dot(x1, x1);
             w.z = dot(x2, x2);
             w.w = dot(x3, x3);
             
             /* w fades from 0.6 at the center of the surflet to 0.0 at the margin */
             w = max(0.6 - w, 0.0);
             
             /* calculate surflet components */
             d.x = dot(random3(s), x);
             d.y = dot(random3(s + i1), x1);
             d.z = dot(random3(s + i2), x2);
             d.w = dot(random3(s + 1.0), x3);
             
             /* multiply d by w^4 */
             w *= w;
             w *= w;
             d *= w;
             
             /* 3. return the sum of the four surflets */
             return dot(d, vec4(52.0));
        }
        
        float noise(vec3 m) {
            return   0.5333333*simplex3d(m)
                    +0.2666667*simplex3d(2.0*m)
                    +0.1333333*simplex3d(4.0*m)
                    +0.0666667*simplex3d(8.0*m);
        }
        
        float N21 (vec2 p) {
            p = fract(p * vec2(233.34, 851.73));
            p += dot(p, p+23.45);
            return fract(p.x * p.y);
        }
        
        vec2 N22 (vec2 p) {
            float n = N21(p);
            return vec2(n, N21(p + n));
        }
        
        void main()
        {
            // vec2 uv =(vTexCoord - 0.5) * u_TextRect / max(u_TextRect.x, u_TextRect.y);
            vec2 uv = vTexCoord - vec2(0.5);
            float d = sqrt(uv.x * uv.x + uv.y * uv.y);
            vec2 st1 = uv * u_Frequency;
            vec2 st2 = (1. - uv) * u_Frequency;
        
            vec2 noiseXY = vec2(noise(vec3(st1, 1.0)), noise(vec3(st2, -1.0)));
            noiseXY = rotate(noiseXY, u_TwistRotFactor);
        
            vec2 maskST = uv * u_MaskFrequency + u_NoisePos;
            float maskNoise = simplex3d(vec3(maskST.yx, 6.0));
            vec2 uv1 = uv - vec2(maskNoise, simplex3d(vec3(1. - maskST.yx, 6.0))) * (pow((u_Radius.x + u_Radius.y), 0.4) * 0.8 - 2.0 *  u_Radius.y);
            float d1 = sqrt(uv1.x * uv1.x + uv1.y * uv1.y);
            vec4 textColor = texture2D(uTexture0, vTexCoord - noiseXY * u_TwistFactor);
            gl_FragColor = textColor * smoothstep(u_Radius.x * 1.3 + u_Radius.y, u_Radius.x * 1.3 - u_Radius.y, d1) * u_Alpha;
        }
        ]],
    renderPass = nil
}

function Faint:init(filter)
    self.maskRadiusBlur = 0.02
    self.renderPass = filter.context:createCustomShaderPass(self.vs, self.fs)
end

function Faint:clear(filter)
    if self.renderPass ~= nil then
        filter.context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
end

function Faint:setDuration(filter, duration)
    self.duration = duration
end

function Faint:seek(filter, timestamp)
    self.timestamp = timestamp
end

function Faint:apply(filter, outTex) 
end

function Faint:applyEffect(label, srcTex, dstTex)
    if #label.chars <= 0 then
        return
    end

    local progress = self.timestamp / self.duration
    local mvpMat = Matrix4f:ScaleMat(1.0, 1.0, 1.0)

    local x = progress ^ 1.5
    local z = progress * math.pi
    x = (math.cos(z * x * x * 2.5) / math.exp(z * 2.0))
    if x ~= 0 then
        x = (x) / math.abs(x) * (math.abs(x) ^ 0.7)
    end
    
    OF_LOGI(TAG, "Faint:applyEffect %f", progress)

    label.context:bindFBO(dstTex)
    label.context:setBlend(false)
    label.context:setViewport(0, 0, dstTex.width, dstTex.height)
    label.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    label.context:clearColorBuffer()
    self.renderPass:use()
    self.renderPass:setUniform2f("u_Radius",progress - self.maskRadiusBlur,  self.maskRadiusBlur)
    self.renderPass:setUniform1f("u_TwistRotFactor", (1 - x) * 360.0)
    self.renderPass:setUniform1f("u_TwistFactor",  x * 0.3)
    self.renderPass:setUniform1f("u_Frequency", 1.5)
    self.renderPass:setUniform1f("u_MaskFrequency", 3.0)
    self.renderPass:setUniform1f("u_Alpha",math.min(progress * progress * 25.0, 1.0))
    self.renderPass:setUniformTexture("uTexture0", 0, srcTex.textureID, TEXTURE_2D)
    self.renderPass:setUniformMatrix4fv("uMVP", 1, 0, mvpMat.x)

    local quadRender = label.context:sharedQuadRender()
    quadRender:draw(self.renderPass, false)
end

return Faint