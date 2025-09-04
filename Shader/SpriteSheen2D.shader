Shader "Universal Render Pipeline/2D/SpriteSheen2D"
{
    Properties
    {
        _MainTex     ("Sprite Texture", 2D) = "white" {}
        _Color       ("Tint", Color) = (1,1,1,1)

        _SheenColor  ("Sheen Color", Color) = (1,1,1,1)
        _Speed       ("Speed", Range(-8, 8)) = 1.5
        _SheenWidth  ("Sheen Width", Range(0.0, 0.5)) = 0.12
        _Softness    ("Softness", Range(0.0, 0.5)) = 0.06
        _Angle       ("Angle (deg)", Range(-90,90)) = 0.0
        _Offset      ("Phase Offset", Range(0,1)) = 0.0

        _Interval    ("Interval (sec) — 0=continuous", Range(0, 5)) = 1.0
        _Duty        ("Active Ratio (0..1)", Range(0.01, 1.0)) = 0.25
    }

    SubShader
    {
        Tags
        {
            "Queue"="Transparent"
            "RenderType"="Transparent"
            "IgnoreProjector"="True"
            "RenderPipeline"="UniversalPipeline"
            "CanUseSpriteAtlas"="True"
        }

        Cull Off
        ZWrite Off
        Blend One OneMinusSrcAlpha

        Pass
        {
            HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #pragma target 2.0

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Core.hlsl"

            TEXTURE2D(_MainTex);        SAMPLER(sampler_MainTex);
            float4 _MainTex_ST;
            float4 _Color;

            float4 _SheenColor;
            float  _Speed, _SheenWidth, _Softness, _Angle, _Offset;
            float  _Interval, _Duty; 

            struct Attributes
            {
                float4 positionOS : POSITION;
                float2 uv         : TEXCOORD0;
                float4 color      : COLOR;
            };

            struct Varyings
            {
                float4 positionHCS : SV_POSITION;
                float2 uv          : TEXCOORD0;
                float4 color       : COLOR;
            };

            Varyings vert (Attributes v)
            {
                Varyings o;
                o.positionHCS = TransformObjectToHClip(v.positionOS.xyz);
                o.uv = v.uv * _MainTex_ST.xy + _MainTex_ST.zw;
                o.color = v.color * _Color;
                return o;
            }

            float dist01(float v, float center)
            {
                return abs(frac(v - center + 0.5) - 0.5);
            }

            half4 frag (Varyings i) : SV_Target
            {
                half4 baseCol = SAMPLE_TEXTURE2D(_MainTex, sampler_MainTex, i.uv) * i.color;
                if (baseCol.a <= 0) return 0;

                float2 p = i.uv - 0.5;
                float rad = radians(_Angle);
                float cs = cos(rad), sn = sin(rad);
                float2 pRot = float2(cs * p.x - sn * p.y, sn * p.x + cs * p.y) + 0.5;

                float tSec = _Time.y;
                float tCenter;

                if (_Interval <= 0.0)
                {
                    tCenter = frac(tSec * _Speed + _Offset);
                }
                else
                {
                    float phase = frac(tSec / max(_Interval, 1e-3) + _Offset);
                    float activeRatio = saturate(_Duty);
                    float isActive = 1.0 - step(activeRatio, phase);
                    float local = saturate(phase / max(activeRatio, 1e-3));
                    tCenter = local;


                }

                float d = dist01(pRot.x, tCenter);

                float m = saturate( (_SheenWidth - d) / max(_Softness, 1e-5) );
                m *= baseCol.a;

                if (_Interval > 0.0)
                {
                    float phase2 = frac(tSec / max(_Interval, 1e-3) + _Offset);
                    float isActive2 = 1.0 - step(saturate(_Duty), phase2);
                    m *= isActive2;
                }

                half3 finalRGB = baseCol.rgb + _SheenColor.rgb * _SheenColor.a * m;
                return half4(finalRGB, baseCol.a);
            }
            ENDHLSL
        }
    }
}
