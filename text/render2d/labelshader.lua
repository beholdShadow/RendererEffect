local Shader = {
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
    
    fs = [[
    #extension GL_OES_standard_derivatives : enable
    precision mediump float;
    varying vec2 vTexCoord;
    uniform sampler2D uTexture0;
    uniform vec4 uColor;
    uniform vec4 uEffectColor;
    uniform int uEffectType;
    uniform float uWidth;
    uniform float uHeight;
    
    void main()
    {
        vec4 color = texture2D(uTexture0, vTexCoord);
        if (uEffectType == 0) // draw bitmap text
        {
            gl_FragColor = vec4(uColor.rgb, color.a * uColor.a);
        }
        else if (uEffectType == 1) // draw bitmap outline
        {
            gl_FragColor = vec4(uEffectColor.rgb, color.r  * uEffectColor.a);
        }
        else if (uEffectType == 2) // draw texture color
        {
            float limit = 0.005;
            float ratio = mix(uWidth / uHeight,  uHeight / uWidth, step(uWidth, uHeight));
            vec2  clamp = mix(vec2(limit, ratio * limit), vec2(ratio * limit, limit), step(uWidth, uHeight));
            vec2  smoothVal = smoothstep(vec2(0.0), clamp, vTexCoord) - smoothstep(clamp * vec2(-1.0), vec2(0.0), vTexCoord- vec2(1.0));
            
            vec4 texColor = vec4(color.rgb, color.a * uColor.a);
            gl_FragColor = texColor * smoothVal.x * smoothVal.y;
        }
        else if (uEffectType == 3) // sdf
        {
            gl_FragColor = color;
        }
    }
    ]],

    fs_bg = [[
    #extension GL_OES_standard_derivatives : enable
    precision mediump float;
    varying vec2 vTexCoord;
    
    uniform vec4 uColor;
    uniform float uWidth;
    uniform float uHeight;
    uniform float uFeather;
    uniform float uRadius;
    const float featherPixel = 2.0;
    void main()
    {
        vec2  border = vec2(featherPixel / uWidth, featherPixel / uHeight);
        vec2  smoothVal = smoothstep(vec2(0.0), border, vTexCoord) - smoothstep(border * vec2(-1.0), vec2(0.0), vTexCoord- vec2(1.0));
        vec2 transUV = abs(vTexCoord * 2.0 - vec2(1.0, 1.0)) * vec2(uWidth / 2.0, uHeight / 2.0);
        vec2 center = vec2(uWidth / 2.0 - uRadius, uHeight / 2.0 - uRadius);
        vec2 delta = transUV - center;
        float firstQuadrant = step(0.0, delta.x) * step(0.0, delta.y);
        float corner = mix(1.0, 1.0 - smoothstep((uRadius - featherPixel) * (uRadius - featherPixel), uRadius * uRadius, dot(delta, delta)), firstQuadrant);
        gl_FragColor = vec4(uColor.rgb,  uColor.a * (step(uFeather, 0.5) + step(0.5, uFeather) * smoothVal.x * smoothVal.y) * corner);
    }
    ]],
    
    fs_sdf_shadow = [[
    #extension GL_OES_standard_derivatives : enable
    precision mediump float;
    
    varying vec2 vTexCoord;
    uniform sampler2D uTexture0;
    uniform float uPixelScale;
    uniform float uSmooth;
    uniform float _Scale;
    uniform float _Padding;
    uniform vec4 _Color1;
    
    varying vec4 vColor;

    float linearstep(float edge0, float edge1, float x) {
        float t = (x - edge0) / (edge1 - edge0);
        return clamp(t, 0.0, 1.0);
      }
    
    void main()
    {
        float distance = texture2D(uTexture0, vTexCoord).a;
        float smoothing = 2.0 / uPixelScale * uSmooth;
        float v1 = clamp(_Padding + _Scale - smoothing, 0.001, 0.999);
        float v2 = clamp(_Padding + 1.0 - _Scale + smoothing, 0.001, 0.999);
        float alpha = clamp(linearstep(v1, v2, distance), 0.0, 1.0);
        gl_FragColor = vec4(_Color1.rgb * alpha * _Color1.a, alpha * _Color1.a);
    }
    ]],
    
    vs_sdf = [[
    precision highp float;
    uniform mat4 uMVP;
    attribute vec4 aPosition;
    attribute vec4 aTextureCoord;
    attribute vec4 aTextureCoord1;
    attribute vec4 aColor;
    varying vec2 vTexCoord;
    #ifdef TEXTURE
        varying vec2 vTexCoord1;
    #endif
    varying vec4 vColor;
    
    void main()
    {
        gl_Position = uMVP * aPosition;
        vTexCoord = aTextureCoord.xy;
    #ifdef TEXTURE
        vTexCoord1 = aTextureCoord1.xy;
    #endif
        vColor = aColor;
    }
    ]], 

    fs_sdf = [[
    #extension GL_OES_standard_derivatives : enable
    precision mediump float;
    
    varying vec2 vTexCoord;
    #ifdef  TEXTURE
        varying vec2 vTexCoord1;
    #endif
    varying vec4 vColor;
    uniform sampler2D uTexture0;
    uniform float uPixelScale;
    uniform float uSmooth;
    uniform float _Scale;
    uniform vec4 _Color1;
    
    #ifdef TEXTURE
    uniform sampler2D _Diffuse;
    #endif
    
    #ifdef OUTLINE1
    uniform vec4 _Outline1Color1;
    uniform float _Outline1Scale;
    #endif
    
    #ifdef OUTLINE2
    uniform float _Outline2Scale;
    uniform vec4 _Outline2Color1;
    #endif
    
    #ifdef OUTLINE3
    uniform float _Outline3Scale;
    uniform vec4 _Outline3Color1;
    #endif
    

    void main()
    {
        float fillDist = texture2D(uTexture0, vTexCoord).a;
        vec4 cc = _Color1 * vColor;
    #ifdef TEXTURE
        vec4 diff = texture2D(_Diffuse, vTexCoord1);
        cc = cc * (1.0 - diff.a) + diff * diff.a;
    #endif
        
        vec4 FragColor = vec4(cc.rgb, _Color1.a);
        float alpha = 1.0;
        //#ifdef ENABLE_DERIVATIVES
            //float smoothing = 1.5 * fwidth(outlineDist);
        //#else
            float smoothing = 2.0 / uPixelScale * uSmooth;
        //#endif
            // uPixelScale当前渲染字号 feather 2px 
            float l = clamp(_Scale - smoothing, 0.0, 1.0);
            alpha = smoothstep(l, _Scale + smoothing, fillDist); 
        float outlineDist = fillDist;
    #ifdef OUTLINE1
        cc = _Outline1Color1;
        FragColor = mix(cc, FragColor, alpha);
        #ifdef OPTIMIZE_OUTLINE
            outlineDist = texture2D(uTexture0, vTexCoord).r;
        #endif
        l = clamp(_Outline1Scale - smoothing, 0.0, 1.0);
        alpha = smoothstep(l, _Outline1Scale + smoothing, outlineDist);
    #endif // OUTLINE1
    
    #ifdef OUTLINE2
        cc = _Outline2Color1;
        FragColor = mix(cc, FragColor, alpha);
        l = clamp(_Outline2Scale - smoothing, 0.0, 1.0);
        alpha = smoothstep(l, _Outline2Scale + smoothing, outlineDist);
    #endif // OUTLINE2
    
    #ifdef OUTLINE3
        cc = _Outline3Color1;
        FragColor = mix(cc, FragColor, alpha);
        l = clamp(_Outline3Scale - smoothing, 0.0, 1.0);
        alpha = smoothstep(l, _Outline3Scale + smoothing, outlineDist);
    #endif // OUTLINE3
    
        alpha *= FragColor.a;
    
        gl_FragColor = vec4(FragColor.rgb * alpha, alpha);// * vColor.a);
    }
    ]],

    fs_sdf_mask_generate = [[
    #extension GL_OES_standard_derivatives : enable
    precision mediump float;
    
    varying vec2 vTexCoord;
    uniform sampler2D uTexture0;
    uniform float uCutoff;
    uniform float uSmooth;
    
    void main()
    {
        float distance = texture2D(uTexture0, vTexCoord).a;
    #ifdef ENABLE_DERIVATIVES
        float smoothing = uSmooth * fwidth(distance);
    #else
        float smoothing = 0.01;
    #endif

        float alpha = 0.0;
        vec4 FragColor = vec4(1.0);
    
        float l = clamp(uCutoff - smoothing, 0.0, 1.0);
        alpha = smoothstep(l, uCutoff + smoothing, distance);
    
        alpha *= FragColor.a;
    
        gl_FragColor = vec4(FragColor.rgb * alpha, alpha);
    }
    ]]


}

return Shader

