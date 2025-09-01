local WaveSlideInII = {
    duration = 1000,
    timestamp = 0,
    vs = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;

        uniform mat4 userMat;
        uniform mat4 fitMat;

        varying vec2 TexCoords;

        vec2 transformUV(vec2 uv) {
            uv = vec2((uv.x * 2. - 1.), uv.y * 2. - 1.);
            uv = (fitMat * userMat * vec4(uv, 0, 1)).xy;
            uv = vec2((uv.x + 1.) / 2., (uv.y + 1.) / 2.);
            return uv;
        }

        void main ()
        {   
            vec2 uv0 = aTextureCoord.xy;
            TexCoords = transformUV(uv0);
            gl_Position = aPosition;
        }
        ]],
        
    fs = [[
        precision highp float;
        varying vec2 TexCoords;
        uniform sampler2D u_inputTexture;
        uniform float iTime;
        uniform float enLarge;
        uniform vec2 transform;
        uniform vec4 u_ScreenParams;
        uniform float dirBlurStep;
        uniform float scaleBlurStep;
        uniform vec2 blurDirection;
        uniform float xAddOffset;
        uniform float yAddOffset;
        uniform float distortSpeed; //  2.0
        // the amount of shearing (shifting of a single column or row)
        // 1.0 = entire screen height offset (to both sides, meaning it's 2.0 in total)
        uniform float xDistMag; // #define xDistMag 0.05
        uniform float yDistMag; // #define yDistMag 0.05
        // cycle multiplier for a given screen height
        // 2*PI = you see a complete sine wave from top..bottom
        uniform float xSineCycles; // #define xSineCycles 6.28
        uniform float ySineCycles; // #define ySineCycles 6.28
        uniform float distortAlpha;
        
        const float PI = 3.141592653589793;
        
        uniform int USE_DIR_BLUR;
        uniform int USE_SACLE_BLUR;
        /* random number between 0 and 1 */
        float random(in vec3 scale, in float seed) {
            /* use the fragment position for randomness */
            return fract(sin(dot(gl_FragCoord.xyz + seed, scale)) * 43758.5453 + seed);
        }
        
        vec4 crossFade(sampler2D tex, in vec2 uv, in float dissolve) {
            return texture2D(tex, uv).rgba;
        }
        
        vec4 directionBlur(sampler2D tex, vec2 resolution, vec2 uv, vec2 directionOfBlur, float intensity)
        {
            vec2 pixelStep = 1.0 / resolution * intensity;
            float dircLength = length(directionOfBlur);
            pixelStep.x = directionOfBlur.x * 1.0 / dircLength * pixelStep.x;
            pixelStep.y = directionOfBlur.y * 1.0 / dircLength * pixelStep.y;
        
            vec4 color = vec4(0);
            const int num = 25;
            for (int i = -num; i <= num; i++)
            {
                vec2 blurCoord = uv + pixelStep * float(i);
                vec2 uvT = vec2(1.0 - abs(abs(blurCoord.x) - 1.0), 1.0 - abs(abs(blurCoord.y) - 1.0));
                color += texture2D(tex, uvT);
            }
            color /= float(2 * num + 1);
            return color;
        }
        
        vec4 getDirectionBlur(sampler2D tex,vec2 uv0,vec2 tmpBlurDirection)
        {
            vec2 resolution = vec2(u_ScreenParams.x, u_ScreenParams.y);
            vec4 resultColor = directionBlur(tex, resolution, uv0, tmpBlurDirection, dirBlurStep);
            vec4 retColor = vec4(resultColor.rgb, resultColor.a) * step(uv0.x, 2.0) * step(uv0.y, 2.0) * step(-1.0, uv0.x) * step(-1.0, uv0.y);
            return retColor;
        }
        
        vec4 getScaleBlur(sampler2D tex,vec2 uv0)
        {
            vec4 color = vec4(0.0);
            float total = 0.0;
            vec2 toCenter = vec2(0.5, 0.5) - uv0;
            float dissolve = 0.5;
        
            /* randomize the lookup values to hide the fixed number of samples */
            float offset = random(vec3(12.9898, 78.233, 151.7182), 0.0);
            const int num = 25;
            for (int t = 0; t <= num; t++) {
                float percent = (float(t) + offset) / float(num);
                float weight = 4.0 * (percent - percent * percent);
        
                vec2 curUV = uv0 + toCenter * percent * scaleBlurStep;
                vec2 uvT = vec2(1.0 - abs(abs(curUV.x) - 1.0), 1.0 - abs(abs(curUV.y) - 1.0));
                color += crossFade(tex, uvT, dissolve) * weight;
                // color += crossFade(uvT + toCenter * percent * blurStep, dissolve) * weight;
                total += weight;
            }
            vec4 retColor = color / total * step(uv0.x, 2.0) * step(uv0.y, 2.0) * step(-1.0, uv0.x) * step(-1.0, uv0.y);
            return retColor;
        }
        
        void main()
        {
            vec2 fragCoord = TexCoords;
            fragCoord += vec2(-transform.x,transform.y);
            float scale = 1.0 / (enLarge);
            fragCoord = (fragCoord - 0.5) * scale + 0.5;
            float time = iTime * distortSpeed;
            float xAngle = (time + fragCoord.y) * xSineCycles + xAddOffset;
            float yAngle = (time + fragCoord.x) * ySineCycles + yAddOffset;
            vec2 distortOffset =
                vec2(sin(xAngle), sin(yAngle)) * // amount of shearing
                vec2(xDistMag, yDistMag) ; // magnitude adjustment
            fragCoord += distortOffset * distortAlpha;
        
            vec2 odd = mod(fragCoord, 2.0); 
            fragCoord = mod(fragCoord, 1.0);
            vec2 tmpBlurDirection = blurDirection;
            if (odd.x > 1.0)
            {
                fragCoord.x = 1.0 - fragCoord.x;
                tmpBlurDirection.x = -tmpBlurDirection.x;
            }
            if (odd.y > 1.0)
            {
                fragCoord.y = 1.0 - fragCoord.y;
                tmpBlurDirection.y = -tmpBlurDirection.y;
            }
        
            vec4 result = texture2D(u_inputTexture, fragCoord);
            gl_FragColor = result;
        
            if (USE_DIR_BLUR > 0) {
                // motionBlur
                vec4 dirBlur = getDirectionBlur(u_inputTexture,fragCoord,tmpBlurDirection);
                gl_FragColor = dirBlur;
            }
            
            if (USE_SACLE_BLUR > 0) {
                //scaleBlur
                vec4 scaleBlur = getScaleBlur(u_inputTexture,fragCoord);
                gl_FragColor = scaleBlur;
            }
            gl_FragColor *= step(0., TexCoords.x) * step(TexCoords.x, 1.) * step(0., TexCoords.y) * step(TexCoords.y, 1.);
        }        
        ]],
    
    vs_fxaa = [[
        precision highp float;
        attribute vec4 aPosition;
        attribute vec4 aTextureCoord;
        varying vec2 vTexCoord;

        void main()
        {
            gl_Position = aPosition;
            vTexCoord = aTextureCoord.xy;
        }
    ]],
    fs_fxaa = [[
        #ifdef GL_ES
        precision mediump float;
        #endif

        varying vec2        vTexCoord;       // Texture coordiantes
        uniform sampler2D u_inputTexture; // FBO texture
        uniform vec2        FBS;            // Frame Buffer Size

        const float EDGE_THRESHOLD_MIN = 0.0312;
        const float EDGE_THRESHOLD_MAX = 0.125;
        const int ITERATIONS = 12;
        const float SUBPIXEL_QUALITY = 0.75;
        float QUALITY[10];

        float rgb2luma(vec3 rgb){
            return sqrt(dot(rgb, vec3(0.299, 0.587, 0.114)));
        }

        float sampleNeighborLuma(sampler2D texSampler, vec2 texCoord){
            return rgb2luma(texture2D(texSampler, texCoord).xyz);
        }

        void initQuality(){
            QUALITY[0] = 1.5;
            QUALITY[1] = 2.0;
            QUALITY[2] = 2.0;
            QUALITY[3] = 2.0;
            QUALITY[4] = 2.0;
            QUALITY[5] = 4.0;
            QUALITY[6] = 8.0;
        }

        void main() {
            
            initQuality();
            vec2 inverseScreenSize = vec2(1./FBS);
            vec2 In = vTexCoord;
            
            vec4 ccenter = texture2D(u_inputTexture, In.xy);
            // gl_FragColor = ccenter;
            // return;
            vec3 colorCenter = ccenter.rgb;
            
            // Luma at the current fragment
            float lumaCenter = rgb2luma(colorCenter);
            
            // Luma at the four direct neighbours of the current fragment.
            float lumaDown = sampleNeighborLuma(u_inputTexture, In.xy + vec2(0, -1.0) * inverseScreenSize);
            float lumaUp = sampleNeighborLuma(u_inputTexture, In.xy+ vec2(0, 1.0) * inverseScreenSize);
            float lumaLeft = sampleNeighborLuma(u_inputTexture, In.xy + vec2(-1.0, 0) * inverseScreenSize);
            float lumaRight = sampleNeighborLuma(u_inputTexture ,In.xy + vec2(1.0, 0) * inverseScreenSize);
            
            // Find the maximum and minimum luma around the current fragment.
            float lumaMin = min(lumaCenter,min(min(lumaDown,lumaUp),min(lumaLeft,lumaRight)));
            float lumaMax = max(lumaCenter,max(max(lumaDown,lumaUp),max(lumaLeft,lumaRight)));
            
            // Compute the delta.
            float lumaRange = lumaMax - lumaMin;
            
            // If the luma variation is lower that a threshold (or if we are in a really dark area), we are not on an edge, don't perform any AA.
            if(lumaRange < max(EDGE_THRESHOLD_MIN,lumaMax*EDGE_THRESHOLD_MAX)){
                gl_FragColor = ccenter;
                return;
            }
            
            // Query the 4 remaining corners lumas.
            float lumaDownLeft = sampleNeighborLuma(u_inputTexture,In.xy + vec2(-1.0) * inverseScreenSize);
            float lumaUpRight = sampleNeighborLuma(u_inputTexture,In.xy + vec2(1.0) * inverseScreenSize);
            float lumaUpLeft = sampleNeighborLuma(u_inputTexture,In.xy + vec2(-1.0,1.0) * inverseScreenSize);
            float lumaDownRight = sampleNeighborLuma(u_inputTexture,In.xy + vec2(1.0,-1.0)* inverseScreenSize);
            
            // Combine the four edges lumas (using intermediary variables for future computations with the same values).
            float lumaDownUp = lumaDown + lumaUp;
            float lumaLeftRight = lumaLeft + lumaRight;
            
            // Same for corners
            float lumaLeftCorners = lumaDownLeft + lumaUpLeft;
            float lumaDownCorners = lumaDownLeft + lumaDownRight;
            float lumaRightCorners = lumaDownRight + lumaUpRight;
            float lumaUpCorners = lumaUpRight + lumaUpLeft;
            
            // Compute an estimation of the gradient along the horizontal and vertical axis.
            float edgeHorizontal =  abs(-2.0 * lumaLeft + lumaLeftCorners)  + abs(-2.0 * lumaCenter + lumaDownUp ) * 2.0    + abs(-2.0 * lumaRight + lumaRightCorners);
            float edgeVertical =    abs(-2.0 * lumaUp + lumaUpCorners)      + abs(-2.0 * lumaCenter + lumaLeftRight) * 2.0  + abs(-2.0 * lumaDown + lumaDownCorners);
            
            // Is the local edge horizontal or vertical ?
            bool isHorizontal = (edgeHorizontal >= edgeVertical);
            
            // Select the two neighboring texels lumas in the opposite direction to the local edge.
            float luma1 = isHorizontal ? lumaDown : lumaLeft;
            float luma2 = isHorizontal ? lumaUp : lumaRight;
            // Compute gradients in this direction.
            float gradient1 = luma1 - lumaCenter;
            float gradient2 = luma2 - lumaCenter;
            
            // Which direction is the steepest ?
            bool is1Steepest = abs(gradient1) >= abs(gradient2);
            
            // Gradient in the corresponding direction, normalized.
            float gradientScaled = 0.25*max(abs(gradient1),abs(gradient2));
            
            // Choose the step size (one pixel) according to the edge direction.
            float stepLength = isHorizontal ? inverseScreenSize.y : inverseScreenSize.x;
            
            // Average luma in the correct direction.
            float lumaLocalAverage = 0.0;
            
            if(is1Steepest){
                // Switch the direction
                stepLength = -stepLength;
                lumaLocalAverage = 0.5*(luma1 + lumaCenter);
            } else {
                lumaLocalAverage = 0.5*(luma2 + lumaCenter);
            }
            
            // Shift UV in the correct direction by half a pixel.
            vec2 currentUv = In.xy;
            if(isHorizontal){
                currentUv.y += stepLength * 0.5;
            } else {
                currentUv.x += stepLength * 0.5;
            }
            
            // Compute offset (for each iteration step) in the right direction.
            vec2 offset = isHorizontal ? vec2(inverseScreenSize.x,0.0) : vec2(0.0,inverseScreenSize.y);
            // Compute UVs to explore on each side of the edge, orthogonally. The QUALITY allows us to step faster.
            vec2 uv1 = currentUv - offset;
            vec2 uv2 = currentUv + offset;
            
            // Read the lumas at both current extremities of the exploration segment, and compute the delta wrt to the local average luma.
            float lumaEnd1 = rgb2luma(texture2D(u_inputTexture,uv1).rgb);
            float lumaEnd2 = rgb2luma(texture2D(u_inputTexture,uv2).rgb);
            lumaEnd1 -= lumaLocalAverage;
            lumaEnd2 -= lumaLocalAverage;
            
            // If the luma deltas at the current extremities are larger than the local gradient, we have reached the side of the edge.
            bool reached1 = abs(lumaEnd1) >= gradientScaled;
            bool reached2 = abs(lumaEnd2) >= gradientScaled;
            bool reachedBoth = reached1 && reached2;
            
            // If the side is not reached, we continue to explore in this direction.
            if(!reached1){
                uv1 -= offset;
            }
            if(!reached2){
                uv2 += offset;
            }
            
            // If both sides have not been reached, continue to explore.
            if(!reachedBoth){
                
                for(int i = 2; i < ITERATIONS; i++){
                    // If needed, read luma in 1st direction, compute delta.
                    if(!reached1){
                        lumaEnd1 = rgb2luma(texture2D(u_inputTexture, uv1).rgb);
                        lumaEnd1 = lumaEnd1 - lumaLocalAverage;
                    }
                    // If needed, read luma in opposite direction, compute delta.
                    if(!reached2){
                        lumaEnd2 = rgb2luma(texture2D(u_inputTexture, uv2).rgb);
                        lumaEnd2 = lumaEnd2 - lumaLocalAverage;
                    }
                    // If the luma deltas at the current extremities is larger than the local gradient, we have reached the side of the edge.
                    reached1 = abs(lumaEnd1) >= gradientScaled;
                    reached2 = abs(lumaEnd2) >= gradientScaled;
                    reachedBoth = reached1 && reached2;
                    
                    // If the side is not reached, we continue to explore in this direction, with a variable quality.
                    if(!reached1){
                        // i for [2, 12]
                        if(i == 2){
                            uv1 -= offset * QUALITY[2];
                        }
                        else if(i == 3){
                            uv1 -= offset * QUALITY[3];
                        }
                        else if(i == 4){
                            uv1 -= offset * QUALITY[4];
                        }
                        else if(i == 5){
                            uv1 -= offset * QUALITY[5];
                        }
                        else if(i == 6){
                            uv1 -= offset * QUALITY[6];
                        }
                        else if(i == 7){
                            uv1 -= offset * QUALITY[7];
                        }
                        else if(i == 8){
                            uv1 -= offset * QUALITY[8];
                        }
                        else if(i == 9){
                            uv1 -= offset * QUALITY[9];
                        }
                        // uv1 -= offset * QUALITY[5];
                    }
                    if(!reached2){
                        if(i == 2){
                            uv2 += offset * QUALITY[2];
                        }
                        else if(i == 3){
                            uv2 += offset * QUALITY[3];
                        }
                        else if(i == 4){
                            uv2 += offset * QUALITY[4];
                        }
                        else if(i == 5){
                            uv2 += offset * QUALITY[5];
                        }
                        else if(i == 6){
                            uv2 += offset * QUALITY[6];
                        }
                        else if(i == 7){
                            uv2 += offset * QUALITY[7];
                        }
                        else if(i == 8){
                            uv2 += offset * QUALITY[8];
                        }
                        else if(i == 9){
                            uv2 += offset * QUALITY[9];
                        }
                        // uv2 += offset * QUALITY[i];
                    }
                    
                    // If both sides have been reached, stop the exploration.
                    if(reachedBoth){ break;}
                }
            }
            
            // Compute the distances to each extremity of the edge.
            float distance1 = isHorizontal ? (In.x - uv1.x) : (In.y - uv1.y);
            float distance2 = isHorizontal ? (uv2.x - In.x) : (uv2.y - In.y);
            
            // In which direction is the extremity of the edge closer ?
            bool isDirection1 = distance1 < distance2;
            float distanceFinal = min(distance1, distance2);
            
            // Length of the edge.
            float edgeThickness = (distance1 + distance2);
            
            // UV offset: read in the direction of the closest side of the edge.
            float pixelOffset = - distanceFinal / edgeThickness + 0.5;
            
            // Is the luma at center smaller than the local average ?
            bool isLumaCenterSmaller = lumaCenter < lumaLocalAverage;
            
            // If the luma at center is smaller than at its neighbour, the delta luma at each end should be positive (same variation).
            // (in the direction of the closer side of the edge.)
            bool correctVariation = ((isDirection1 ? lumaEnd1 : lumaEnd2) < 0.0) != isLumaCenterSmaller;
            
            // If the luma variation is incorrect, do not offset.
            float finalOffset = correctVariation ? pixelOffset : 0.0;
            
            // Sub-pixel shifting
            // Full weighted average of the luma over the 3x3 neighborhood.
            float lumaAverage = (1.0/12.0) * (2.0 * (lumaDownUp + lumaLeftRight) + lumaLeftCorners + lumaRightCorners);
            // Ratio of the delta between the global average and the center luma, over the luma range in the 3x3 neighborhood.
            float subPixelOffset1 = clamp(abs(lumaAverage - lumaCenter)/lumaRange,0.0,1.0);
            float subPixelOffset2 = (-2.0 * subPixelOffset1 + 3.0) * subPixelOffset1 * subPixelOffset1;
            // Compute a sub-pixel offset based on this delta.
            float subPixelOffsetFinal = subPixelOffset2 * subPixelOffset2 * SUBPIXEL_QUALITY;
            
            // Pick the biggest of the two offsets.
            finalOffset = max(finalOffset,subPixelOffsetFinal);
            
            // Compute the final UV coordinates.
            vec2 finalUv = In.xy;
            if(isHorizontal){
                finalUv.y += finalOffset * stepLength;
            } else {
                finalUv.x += finalOffset * stepLength;
            }
            
            // Read the color at the new UV coordinates, and use it.
            vec4 finalColor = texture2D(u_inputTexture,finalUv);
            gl_FragColor = finalColor;
        }
    ]],
    renderPass = nil,
    fxaaPass = nil,
    copyPass = nil,
    values = {}
}

local function getBezierValue(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3 * xc1 * (1 - t) * (1 - t) * t + 3 * xc2 * (1 - t) * t * t + t * t * t
    ret[2] = 3 * yc1 * (1 - t) * (1 - t) * t + 3 * yc2 * (1 - t) * t * t + t * t * t
    return ret
end

local function getBezierDerivative(controls, t)
    local ret = {}
    local xc1 = controls[1]
    local yc1 = controls[2]
    local xc2 = controls[3]
    local yc2 = controls[4]
    ret[1] = 3 * xc1 * (1 - t) * (1 - 3 * t) + 3 * xc2 * (2 - 3 * t) * t + 3 * t * t
    ret[2] = 3 * yc1 * (1 - t) * (1 - 3 * t) + 3 * yc2 * (2 - 3 * t) * t + 3 * t * t
    return ret
end

local function getBezierTfromX(controls, x)
    local ts = 0
    local te = 1
    -- divide and conque
    repeat
        local tm = (ts + te) / 2
        local value = getBezierValue(controls, tm)
        if (value[1] > x) then
            te = tm
        else
            ts = tm
        end
    until (te - ts < 0.0001)

    return (te + ts) / 2
end

function WaveSlideInII:init(context)
    self.renderPass = context:createCustomShaderPass(self.vs, self.fs)
    self.fxaaPass = context:createCustomShaderPass(self.vs_fxaa, self.fs_fxaa)
    self.params = {
        -- zidingyishuxingdonghuapeizhi
        -- xiamianliziyongyuchuanrusuishijianbianhuaerbianhuadeuniformdaoshader
        {
            -- shijian，buxuyaoxiugai
            key = "iTime",
            obj = self.values,
            startValue = 0.0, -- qishizhi
            endValue = 1.0, -- jieshuzhi
            defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
            actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                renderPass:setUniform1f(key, value)
            end,
            curve = function(t, b, c, d)
                t = t / d
                return b + c * t
            end,
            startTime = 0.0, -- qishishijian
            endTime = 1 -- jieshushijian
        },
        {
            -- xiexiangyundongdeyundongliang
            key = "transform",
            obj = self.values,
            startValue = Vec2f.new(-1, 2.0), -- qishizhi
            endValue = Vec2f.new(0, 0), -- jieshuzhi
            defaultValue = Vec2f.new(0, 0), -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
            actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                renderPass:setUniform2f(key, value.x, value.y)
            end,
            curve = function(t, b, c, d)
                t = t / d
                local controls = {0.06, 0.73, 0.43, 1} -- beisaierquxiancanshu
                local tvalue = getBezierTfromX(controls, t)
                local value = getBezierValue(controls, tvalue)
                return b + c * value[2]
            end,
            startTime = 0.0, -- qishishijian
            endTime = 0.15 -- jieshushijian
        },
        {
            -- xiefangxiangfangxiangmohu，
            key = "dirBlurStep",
            obj = self.values,
            startValue = 10.0, -- qishizhi
            endValue = 0.0, -- jieshuzhi
            defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
            actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                renderPass:setUniform1f(key, value)
                if value > 0.001 then
                    renderPass:setUniform1i("USE_DIR_BLUR", 1)
                else 
                    renderPass:setUniform1i("USE_DIR_BLUR", 0)
                end
            end,
            curve = function(t, b, c, d)
                t = t / d
                if t > 0.99 then
                    return 0.0;
                end
                local controls = {0.06, 0.73, 0.43, 1} -- beisaierquxiancanshu

                local tvalue = getBezierTfromX(controls, t)
                local value = getBezierValue(controls, tvalue)
                return b + c * value[2]
            end,
            startTime = 0.0, -- qishishijian
            endTime = 0.15 -- jieshushijian
        },
        {
            -- qianbanduanniuqudeqiangdu，kuaisujianruo
            key = "distortAlpha",
            keycurves = {
                {
                    obj = self.values,
                    startValue = 0, -- qishizhi
                    endValue = 0.4, -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                        renderPass:setUniform1f(key, value)
                    end,
                    curve = function(t, b, c, d)
                        t = t / d
                        local controls = {0.53, 0.64, 1.00, 1.00} -- beisaierquxiancanshu
                        local tvalue = getBezierTfromX(controls, t)
                        local value = getBezierValue(controls, tvalue)
                        return b + c * value[2]
                    end,
                    startTime = 0.0, -- qishishijian
                    endTime = 0.05 -- jieshushijian
                },
                {
                    obj = self.values,
                    startValue = 0.4, -- qishizhi
                    endValue = 0.0, -- jieshuzhi
                    defaultValue = 0.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                        renderPass:setUniform1f(key, value)
                    end,
                    curve = function(t, b, c, d)
                        t = t / d
                        local controls = {0.35, 0.97, 0.67, 1.00} -- beisaierquxiancanshu
                        local tvalue = getBezierTfromX(controls, t)
                        local value = getBezierValue(controls, tvalue)
                        return b + c * value[2]
                    end,
                    startTime = 0.05, -- qishishijian
                    endTime = 0.6 -- jieshushijian
                }
            }
        },
        {
            -- tupianfangdadezhi，congdaxiaodaoda，huanman
            key = "enLarge",
            keycurves = {
                {
                    obj = self.values,
                    startValue = 1.0, -- qishizhi
                    endValue = 1.1, -- jieshuzhi
                    defaultValue = 1.0, -- morenzhi，gaijieduanmeiyouzhixing，huozhezhixingwanchengzhihougaiyingyongdezhi
                    actionHandle = function(renderPass, key, value) -- seekshidehuidiaofangfa
                        renderPass:setUniform1f(key, value)
                    end,
                    curve = function(t, b, c, d)
                        t = t / d
                        local controls = {0.71, 0.00, 0.75, 0.54} -- beisaierquxiancanshu
                        local tvalue = getBezierTfromX(controls, t)
                        local value = getBezierValue(controls, tvalue)
                        return b + c * value[2]
                    end,
                    startTime = 0.0, -- qishishijian
                    endTime = 1.0
                }
            }
         -- jieshushijian
        }
    }
end

function WaveSlideInII:clear(context)
    if self.renderPass ~= nil then
        context:destroyCustomShaderPass(self.renderPass)
        self.renderPass = nil
    end
    if self.fxaaPass ~= nil then
        context:destroyCustomShaderPass(self.fxaaPass)
        self.fxaaPass = nil
    end
end

function WaveSlideInII:setDuration(filter, duration)
    self.duration = duration
end

function WaveSlideInII:seek(filter, timestamp)
    self.timestamp = timestamp
end

function WaveSlideInII:apply(filter)
    filter.animation.params.renderToRT = true
end

function WaveSlideInII:AnimateParam(progress)
    for i = 1, #self.params do
        local param = self.params[i]
        if param.keycurves ~= nil then
            local percent = math.max(math.min(progress,  param.keycurves[#param.keycurves].endTime),  param.keycurves[1].startTime)
            for j = 1, #param.keycurves do
                if percent <= param.keycurves[j].endTime + 0.001 then 
                    self.values[param.key] = param.keycurves[j].curve(percent - param.keycurves[j].startTime, param.keycurves[j].startValue, param.keycurves[j].endValue - param.keycurves[j].startValue, param.keycurves[j].endTime - param.keycurves[j].startTime)
                    param.keycurves[j].actionHandle(self.renderPass, param.key, self.values[param.key])
                    break;
                end
            end
        else 
            local percent = math.max(math.min(progress, param.endTime), param.startTime)
            self.values[param.key] = param.curve(percent - param.startTime, param.startValue, param.endValue - param.startValue, param.endTime - param.startTime)
            param.actionHandle(self.renderPass, param.key, self.values[param.key])
        end
        if param.key ~= "transform" then
            OF_LOGI("WaveSlideInII", string.format("WaveSlideInII:AnimateParam key = %s, value = %f", param.key, self.values[param.key]))
        end
    end
end

function WaveSlideInII:applyEffect(filter, outTex)
    --first render imageTex to output viewport
    local width, height = outTex.width, outTex.height
	local quadRender = filter.context:sharedQuadRender()    
    self.timestamp = math.max(self.timestamp, 0.0)
    local progress = math.fmod(self.timestamp, self.duration) / self.duration

    -- local inputRatio = filter.imageTex:width() / filter.imageTex:height()
    -- local outputRatio = width / height
    local extraScale = 1
    -- if inputRatio < outputRatio then
    --     extraScale = filter.imageTex:height() / height
    -- else
    --     extraScale = filter.imageTex:width() / width
    -- end
    local uvScale = { x = 1.0, y = 1.0}
    -- local xRatio = inputRatio / outputRatio
    -- local yRatio = outputRatio / inputRatio
    -- if outputRatio > 1. then
    --     if outputRatio > inputRatio then
    --         uvScale.x = xRatio
    --     else
    --         uvScale.y = yRatio
    --     end
    -- elseif math.abs(outputRatio - 1.) < .1 then
    --     if inputRatio < 1. then
    --         uvScale.x = xRatio
    --     else
    --         uvScale.y = yRatio
    --     end
    -- elseif outputRatio < 1. then
    --     if math.abs(inputRatio - 1.) < .1 or outputRatio < inputRatio then
    --         uvScale.y = yRatio
    --     else
    --         uvScale.x = xRatio
    --     end
    -- end

	local scaleMat = Matrix4f:ScaleMat(filter.params.scaleX * filter.params.scale * extraScale, filter.params.scaleY * filter.params.scale * extraScale, 1.0)
	local rotMat = Matrix4f:RotMat(0, 0, filter.params.rot)
	local transMat = Matrix4f:TransMat(filter.params.tx, filter.params.ty, 0.0)
	local mvpMat =
		Matrix4f:ScaleMat(2 / width, 2 / height, 1.0 ) *
		transMat * rotMat * scaleMat *
		Matrix4f:ScaleMat(filter.imageTex:width() * 0.5, filter.imageTex:height() * 0.5, 1)
    local transformMat = mvpMat:inverted()  

    local texTemp = filter.context:getTexture(width, height)
    local fitMat = Matrix4f:ScaleMat(uvScale.x, uvScale.y, 1):inverted() 
    filter.context:bindFBO(texTemp:toOFTexture())
    filter.context:setViewport(0, 0, width, height)
    filter.context:setClearColor(0.0, 0.0, 0.0, 0.0)
    filter.context:clearColorBuffer()
    filter.context:setBlend(false)

    self.renderPass:use()
    self.renderPass:setUniformMatrix4fv("userMat", 1, 0, transformMat.x)
    self.renderPass:setUniformMatrix4fv("fitMat", 1, 0, fitMat.x)
    self.renderPass:setTexture("u_inputTexture", 0, filter.imageTex:toOFTexture())
    self.renderPass:setUniform1f("distortSpeed", 2.0)
    self.renderPass:setUniform1f("xAddOffset", 0.0)
    self.renderPass:setUniform1f("yAddOffset", 0.0)
    self.renderPass:setUniform1f("xDistMag", 0.08)
    self.renderPass:setUniform1f("yDistMag", 0.08)
    self.renderPass:setUniform1f("xSineCycles", 6.28)
    self.renderPass:setUniform1f("ySineCycles", 6.28)
    self.renderPass:setUniform1i("USE_SACLE_BLUR", 0.0)
    self.renderPass:setUniform4f("u_ScreenParams", width, height, 0.0, 0.0)
    self.renderPass:setUniform2f("blurDirection", -0.5, -1)
    self:AnimateParam(progress);

    quadRender:draw(self.renderPass, false)

    filter.context:bindFBO(outTex)
    filter.context:setViewport(0, 0, width, height)
    filter.context:clearColorBuffer()

    self.fxaaPass:use()
    self.fxaaPass:setUniform2f("FBS", width, height)
    self.renderPass:setTexture("u_inputTexture", 0, texTemp:toOFTexture())
    quadRender:draw(self.fxaaPass, false)

    filter.context:releaseTexture(texTemp)
end

return WaveSlideInII