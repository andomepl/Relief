Shader "Unlit/relief"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _MaxHeightField("Height Field",Range(0.0001,10))=1
        _ReliefTex("Relief Texture",2D)="white" {}
        _ReliefTexBack("Relief Texture Back",2D)="white" {}
        [NORMAL]
        _NormalTex("Normal Tex",2D)="white"{}
        _MaxStep("Max Step",Range(10,500))=10
        _DiterStep("Dither Step",Range(0,100))=0.5

        _FrontScale("Fron Scale ",Range(0,2))=1
        _BackScale("Back Scale",Range(0,2))=1


    }
    SubShader
    {

         Tags {"Queue"="Transparent" "IgnoreProjector"="True" "RenderType"="Transparent"}
        ZWrite Off
        Blend SrcAlpha OneMinusSrcAlpha 
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
   
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal:NORMAL;
                float4 tangent:TANGENT;
            };

            struct v2f
            {   
                float4 pos : SV_POSITION;
                float2 uv : TEXCOORD0;
                


                float3 TSviewDir:TEXCOORD1;
                float3 TSLightDir:TEXCOORD2;
                float3 TangentPos:TEXCOORD3;

            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            sampler2D _NormalTex;
            sampler2D _ReliefTex;


            sampler2D _ReliefTexBack;

            float _MaxStep;

            float _DiterStep;

            float _MaxHeightField;

            float _FrontScale;
            float _BackScale;


            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);


                float3 worldPos=mul(unity_ObjectToWorld,v.vertex).xyz;

                float3 bitangent=cross(v.normal.xyz,v.tangent.xyz)*v.tangent.w;

                float4 OSCamera=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1.0));

                float3 OSViewDir=normalize(OSCamera.xyz-v.vertex.xyz);

                o.TSviewDir =float3(
                    dot(OSViewDir, v.tangent.xyz),
                    dot(OSViewDir, bitangent),
                    dot(OSViewDir, v.normal)
                    );

				float4 LightDirOS= mul(unity_WorldToObject, float4(_WorldSpaceLightPos0.xyz,0));

                o.TSLightDir=float3(
					dot(LightDirOS.xyz, v.tangent.xyz),
                    dot(LightDirOS.xyz, bitangent),
                    dot(LightDirOS.xyz, v.normal)
				
				);

                o.TangentPos=float3(
                   	dot(v.vertex.xyz, v.tangent.xyz),
                    dot(v.vertex.xyz, bitangent),
                    dot(v.vertex.xyz, v.normal)
                );






                return o;
            }


            float2 Hammersley(float i, float numSamples)
            {   
                uint b = uint(i);
    
                b = (b << 16u) | (b >> 16u);
                b = ((b & 0x55555555u) << 1u) | ((b & 0xAAAAAAAAu) >> 1u);
                b = ((b & 0x33333333u) << 2u) | ((b & 0xCCCCCCCCu) >> 2u);
                b = ((b & 0x0F0F0F0Fu) << 4u) | ((b & 0xF0F0F0F0u) >> 4u);
                b = ((b & 0x00FF00FFu) << 8u) | ((b & 0xFF00FF00u) >> 8u);
    
                float radicalInverseVDC = float(b) * 2.3283064365386963e-10;
    
                return float2((i / numSamples), radicalInverseVDC);
            } 




            float3 unrealVer(out float alpha,float2 startuv,float3 ViewDirTs){
            
                float3 uvout=float3(0,0,0);

                float i=0;

                float height=0;

                while(i<_MaxStep){
                    float h=(i+lerp(0,Hammersley(i,_MaxStep).x-0.5f,_DiterStep))/_MaxStep;


                    float2 uvCurrent=startuv+ViewDirTs.xy*(h-_MaxHeightField)/(dot(ViewDirTs,float3(0,0,1.0f)));

  

                        float RealDepth1=tex2Dlod(_ReliefTex,float4(uvCurrent,0,0)).r*_FrontScale;
                        float RealDepth1_Back=tex2Dlod(_ReliefTexBack,float4(uvCurrent,0,0)).r*_BackScale;

                        if(RealDepth1>h&&h>(1-RealDepth1_Back)){
                            if(uvCurrent.x>0&&uvCurrent.x<1&&uvCurrent.y>0&&uvCurrent.y<1){
                                    uvout=float3(uvCurrent,h);
                                    alpha=1;

                            }
                        }

                        i++;
                }
                
                
                return uvout;
            
            }
 
          

            float4 frag (v2f i) : SV_Target
            {


                float3 ViewDirTS=normalize(i.TSviewDir);



             

                float2 Curuv=i.uv;
                



                float alpha=0;

      
               float3 unrealUV=unrealVer(alpha,Curuv,normalize(ViewDirTS));


               float3  unrealColor = tex2Dlod(_MainTex, float4(unrealUV.xy,0,0)).rgb;

           //    return float4(unrealUV.zzz,1);

               return float4(unrealColor,alpha);

            }
            ENDCG
        }
    }
}
