#version 120
#include "/lib/essentials.glsl"
#include "/lib/trans.glsl"

varying vec2 tc;
uniform sampler2D colortex7;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D colortex0;
uniform sampler2D colortex3;
uniform sampler2D depthtex1;

uniform sampler2D gnormal;

uniform vec3 shadowLightPosition;
uniform int worldTime;



#define AMBIENT_OCCLUSION
#define GLOBAL_ILLUMINATION

#define EMMISIVE_MAP
#define OREN_NAYAR_DIFFUSE
#define USE_METALS

/*DRAWBUFFERS:07*/
void main(){
  vec3 gi = texture2D(colortex4,tc).rgb;
  vec3 lme =  texture2D(colortex7,tc).rgb;
  float pxdpth = texture2D(depthtex1,tc).r;
  vec3 pbr = texture2D(colortex3,tc).rgb;
  #ifdef EMMISIVE_MAP
  float emmisiveness =lme.b;
  #else
  float emmisiveness=0.;
  #endif
  vec4 c = texture2D(colortex0,tc);

  #ifdef USE_METALS
  #else
  pbr.g*=0.;
  #endif
  gl_FragData[0]=vec4(c.rgb*((pxdpth<1.&&pbr.g<.9)?
  (gi+emmisiveness)
  :vec3(1)),1.);
  gl_FragData[1]=vec4(lme.rg,0.,1.);
}
