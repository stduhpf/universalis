#version 120

const bool colortex5Clear = false;

#include "lib/trans.glsl"
#include "lib/essentials.glsl"
#include "lib/temp.glsl"

uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;
uniform sampler2D colortex7;
uniform sampler2D colortex4;
uniform sampler2D colortex5;

uniform int worldTime;


#define TEMPORAL_LIGHT_ACCUMULATION
#define GLOBAL_ILLUMINATION


uniform int frameCounter;

varying vec2 tc;




#ifdef GLOBAL_ILLUMINATION
vec3 filt(vec2 tc, sampler2D s){
  vec3 a = vec3(0);
  float b =0.;
  float dp =depthLin(texture2D(depthtex1,tc).r);
  for(int i =-1;i<1;i++){
    for(int j =-1;j<1;j++){
      float si = 3.-float(i+j+i*j);
      vec2 sc = tc+2.5*vec2(i,j)/resolution;
      if(abs(depthLin(texture2D(depthtex1,sc).r)-dp)<.001){
        a+=si*texture2D(s,sc ).rgb;
        b+=si;
      }
    }
  }
  return a/b;
}
#endif

#include "lib/lmcol.glsl"


/*DRAWBUFFERS:154*/
void main() {

  vec2 lmcoord=texture2D(colortex7,tc).rg;


  lmcoord*=lmcoord;

  vec3 naosh =  texture2D(colortex1, tc).rgb;
  float ao =naosh.x;
  #include "lib/ambcol.glsl"
  ao*=.1+lmcoord.y*ambi;
  #ifdef GLOBAL_ILLUMINATION
        vec3 newgi =  filt(tc,colortex4)+ambientCol*ao;
  #else
        vec3 newgi = ambientCol*ao;
  #endif
#ifdef TEMPORAL_LIGHT_ACCUMULATION
    float pixdpth = texture2D(depthtex1,tc).r;
    float lpixdpth = depthLin(boxmin(tc,depthtex1));

    vec3 clipPos = screen2clip(vec3(tc,pixdpth));
    vec3 wpos = clip2view(clipPos);
    wpos = view2cam(wpos);//position relative to the view of the player

    vec3 pwpos = pworld2cam(cam2world(wpos));
    vec3 pclipPos= pcam2clip(pwpos);
    pclipPos=clip2screen(pclipPos);//*.5+.5;
    float newdepth = pclipPos.z;



    float nd =depthLin(newdepth);
    float maxd = boxmin(tc,depthtex1);

    vec3 lastgi = texture2D(colortex5, pclipPos.xy).rgb;


    if(pclipPos.xy != clamp(pclipPos.xy,0,1)){
        lastgi=newgi;
    }

        newgi = mix(lastgi,newgi,.3);


      gl_FragData[0] = vec4(0.,naosh.yz,1);
      newgi = saturate3(newgi);
      gl_FragData[1] = vec4(newgi,1.);
      newgi+=TorchColor*(ao*.5+.5)*lmcoord.x;
      gl_FragData[2] = vec4(newgi,1.);
#else
      gl_FragData[0] = vec4(0.,naosh.yz,1);
      gl_FragData[2] =texture2D(colortex4, tc)+vec4(TorchColor*(naosh.x*.75+.25)*lmcoord.x,0)+vec4(ao*ambientCol,0.);
#endif

  }
