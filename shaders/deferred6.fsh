#version 120
#include "lib/essentials.glsl"
#include "lib/trans.glsl"

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

#ifdef OREN_NAYAR_DIFFUSE
#define USE_METALS

float diffuse(vec3 v, vec3 l, vec3 n, float r) {
    r *= r;

    float cti = dot(n,l);
    float ctr = dot(n,v);

    float t = max(cti,ctr);
    float g = max(.0, dot(v - n * ctr, l - n * cti));
    float c = g/t - g*t;

    float a = .285 / (r+.57) + .5;
    float b = c * .45 * r / (r+.09);

    return max(0., cti) * ( b + a);
}
#endif

/*DRAWBUFFERS:07*/
void main(){
  #include "lib/lightcol.glsl"
  vec3 normal = texture2D(gnormal,tc).rgb*2.-1.;
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
  float shd = texture2D(colortex1,tc).g*2.;
  #ifdef OREN_NAYAR_DIFFUSE
  float rough = pow(1.-pbr.r,2.);
  vec3 v =normalize(screen2view(vec3(tc,pxdpth)));
  float diff = diffuse(-v,normalize(shadowLightPosition),normal,rough);
  #else
  float diff = max(0.,dot(normal,normalize(shadowLightPosition)));
  #endif
  vec3 sh = lightCol*shd*diff;
  #ifdef USE_METALS
  #else
  pbr.g*=0.;
  #endif
  gl_FragData[0]=vec4(c.rgb*((pxdpth<1.&&pbr.g<.9)?
  (sh+gi+emmisiveness)
  :vec3(.5+.5*float(pxdpth>=1.))),1.);
  gl_FragData[1]=vec4(lme.rg,shd,1.);
}
