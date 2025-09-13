Shader "Custom/TVSpriteURP"
{
    Properties
    {
        [MainTexture][NoScaleOffset] _MainTex ("Texture", 2D) = "white" {}
        _Tint ("Tint", Color) = (1,1,1,1)

        _ScanlineStrength ("Scanline Strength", Range(0,1)) = 0.35
        _ScanlineDensity  ("Scanline Density", Range(200,4000)) = 1200
        _Vignette         ("Vignette", Range(0,1)) = 0.25
        _Distortion       ("Barrel Distortion", Range(0,0.2)) = 0.05

        _BandSpeed        ("Band Speed", Range(0,10)) = 2.2
        _BandFreq         ("Band Freq (per-row)", Range(0,50)) = 12
        _JitterAmp        ("Horizontal Jitter Amp", Range(0,0.02)) = 0.006
        _Chromatic        ("Chromatic Amount", Range(0,2)) = 0.6

        _GrainIntensity   ("Grain Intensity", Range(0,0.3)) = 0.06
        _GrainScale       ("Grain Scale", Range(1,400)) = 150
    }

    SubShader
    {
        Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
        Blend SrcAlpha OneMinusSrcAlpha
        Cull Off
        ZWrite Off

        Pass
        {
            Name "ForwardLit"

            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0
            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv     : TEXCOORD0;
                float4 color  : COLOR;
            };

            struct v2f
            {
                float4 pos    : SV_POSITION;
                float2 uv     : TEXCOORD0;
                float4 color  : COLOR;
            };

            TEXTURE2D(_MainTex);
            SAMPLER(sampler_MainTex);

            CBUFFER_START(UnityPerMaterial)
                float4 _Tint;

                float _ScanlineStrength;
                float _ScanlineDensity;
                float _Vignette;
                float _Distortion;

                float _BandSpeed;
                float _BandFreq;
                float _JitterAmp;
                float _Chromatic;

                float _GrainIntensity;
                float _GrainScale;
            CBUFFER_END

            float hash12(float2 p) {
                float3 p3  = frac(float3(p.xyx) * 0.1031);
                p3 += dot(p3, p3.yzx + 33.33);
                return frac((p3.x + p3.y) * p3.z);
            }

            float2 barrel(float2 uv, float amount)
            {
                float2 cc = uv - 0.5;
                float r2  = dot(cc, cc);
                return cc * (1.0 + amount * r2) + 0.5;
            }

            v2f vert (appdata v)
            {
                v2f o;
                o.pos   = TransformObjectToHClip(v.vertex.xyz);
                o.uv    = v.uv;
                o.color = v.color;
                return o;
            }

            float4 frag (v2f i) : SV_Target
            {
                float2 uv = i.uv;

                uv = barrel(uv, _Distortion);

                float t = _Time.y * _BandSpeed;
                float rowNoise = hash12(float2(floor(uv.y * _ScanlineDensity * 0.5) + floor(t*20.0), 0.0));
                float wave = sin(uv.y * _BandFreq + t * 1.7) * 0.5 + 0.5;
                float jitter = (rowNoise - 0.5) * 2.0;
                float xShiftBase = (wave * 0.7 + 0.3) * jitter * _JitterAmp;

                float2 shiftR = float2(+xShiftBase * _Chromatic, 0.0);
                float2 shiftG = float2(0.0, 0.0);
                float2 shiftB = float2(-xShiftBase * _Chromatic, 0.0);

                float4 colR = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + shiftR);
                float4 colG = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv);
                float4 colB = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, uv + shiftB);
                float4 col  = float4(colR.r, colG.g, colB.b, (colR.a + colG.a + colB.a)/3.0);

                float scan = sin(uv.y * _ScanlineDensity + _Time.y * 6.28318);
                float scanMask = 1.0 - _ScanlineStrength * (0.5 + 0.5 * scan);
                col.rgb *= scanMask;

                float2 d = uv - 0.5;
                float vign = 1.0 - _Vignette * smoothstep(0.4, 0.72, dot(d,d));
                col.rgb *= vign;

                float g = hash12(uv * _GrainScale + _Time.y);
                col.rgb += (g - 0.5) * _GrainIntensity;

                col.rgb *= _Tint.rgb * i.color.rgb;
                col.a   *= _Tint.a   * i.color.a;
                return col;
            }
            ENDHLSL
        }
    }
    FallBack "Hidden/Universal Render Pipeline/FallbackError"
}
