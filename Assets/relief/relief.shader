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
        _MaxStep("Max Step",Range(10,50))=10
        _test("test",Range(1,10))=2


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

            float _test;

            float _MaxHeightField;

            v2f vert (appdata v)
            {
                v2f o;
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);


                float3 worldPos=mul(unity_ObjectToWorld,v.vertex).xyz;

                float3 bitangent=cross(v.normal.xyz,v.tangent.xyz)*v.tangent.w;

                float4 OSCamera=mul(unity_WorldToObject,float4(_WorldSpaceCameraPos,1.0));

                float3 OSViewDir=OSCamera.xyz-v.vertex.xyz ;

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




            float near_acc_binary(float Step_size,float2 startuv,float2 MaxUVOffset,float CurDepth,out float alpha){
                   
                float FinDepth=0;

                float Max_Binary_Step=5;
                float Binary_Step_Size=Step_size*0.5f;

                for(int i=0;i<Max_Binary_Step-1;i++){

                       float2 currentUV=startuv+MaxUVOffset*CurDepth;
                       float RealDepth1=tex2D(_ReliefTex,currentUV).r;
                        float RealDepth1_Back=tex2D(_ReliefTexBack,currentUV).r;
                        if(RealDepth1<CurDepth&&CurDepth<RealDepth1_Back ){
                          if(currentUV.x<1&&currentUV.x>0&&currentUV.y<1&&currentUV.y>0){
                            FinDepth=CurDepth;
                            CurDepth-=2*Binary_Step_Size;
                             alpha=1;
 
                                }
                                else{
                                FinDepth=1;
                                alpha=0;
                                }
                            
                        }
                        CurDepth+=Binary_Step_Size;

                    
                    Binary_Step_Size*=0.5f;
                
                }
                    
                return FinDepth;
            
            }

            float Pass_iterDepth(float2 MaxUVOffset,float2 startuv,inout float alpha){
                
                float Max_step=_MaxStep;
                float Step_size=1.0f/Max_step;

                float AccDepth=1.0f;

                float CurDepth=0.0f;

              
                
                for(int i=0;i<Max_step-1;i++){
                    
                   
                    CurDepth+=Step_size;

                    float h=0;
                    h=(i+lerp(0,Hammersley(i,Max_step).x,_test))/Max_step;

                    float2 currentUV=startuv+MaxUVOffset*h;
                    float RealDepth0=(tex2D(_ReliefTex,currentUV).r)+0.4f;   
                    if(AccDepth>0.996f)
                    if(CurDepth>RealDepth0){
                            AccDepth=CurDepth;    
                            alpha=1;

 
                    }
                                          
                }


                float outalpha=0;

                float Depth=near_acc_binary(Step_size,startuv,MaxUVOffset,AccDepth,outalpha);

                   alpha=outalpha;
                return Depth;
                
            
            }

 
          

            float4 frag (v2f i) : SV_Target
            {


                float3 ViewDirTS=i.TSviewDir;

                float3 LightDirTS=i.TSLightDir;


                
                float3 PosTs=i.TangentPos;

                float2 Curuv=i.uv;
                

                float2 maxUVOffset=ViewDirTS.xy*_MaxHeightField/(-ViewDirTS.z);

                float alpha=0;

                float Fdepth=saturate(Pass_iterDepth(maxUVOffset,Curuv,alpha));
                
               
             //  return  float4(Fdepth.xxx,1);

                float2 Fuv=Curuv+maxUVOffset*Fdepth;

    

     

                
                //alpha*=satUV;
                

               // return float4(alpha.xxx,1);
               float3 diffuseColor =0;
                if(alpha==1.0f)
                 diffuseColor = tex2D(_MainTex, Fuv).rgb;
               


                return float4(diffuseColor*alpha,alpha);
         

                float3 normalTS=UnpackNormal(tex2D(_NormalTex,Fuv));


                       
                float3 hit_Point=PosTs+(ViewDirTS/-ViewDirTS.z)*Fdepth*_MaxHeightField;

          

                float3 From_hit_point_to_light=LightDirTS+(PosTs-hit_Point);

   

                float3 TsLight=normalize(From_hit_point_to_light);
                float3 TsNormal=normalize(normalTS);
                float3 H=normalize(From_hit_point_to_light+ViewDirTS);
          

                float ndotl=max(dot(TsNormal,TsLight),0.0);
                float specualCof=pow(saturate(dot(TsNormal,H)),128);

            

                float3 specularColor=float3(1,1,1);
                
       

                float3 col=diffuseColor.rgb*ndotl;//+specualCof*specularColor;

              
                return float4(col,alpha);
            }
            ENDCG
        }
    }
}
