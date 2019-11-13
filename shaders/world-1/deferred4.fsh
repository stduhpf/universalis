#version 120
#include "../lib/essentials.glsl"
#include "../lib/trans.glsl"

varying vec2 tc;
//uniform sampler2D colortex0;
uniform sampler2D colortex1;
uniform sampler2D colortex4;
uniform sampler2D depthtex1;

vec3 filt(vec2 tc, sampler2D s){
  vec3 a = vec3(0);
  float b =0.;
  float dp =depthLin(texture2D(depthtex1,tc).r);
  for(int i =-1;i<1;i++){
    for(int j =-1;j<1;j++){
      float si = 3.-float(i+j+i*j);
      vec2 sc = tc+1.5*vec2(i,j)/resolution;
      if(abs(depthLin(texture2D(depthtex1,sc).r)-dp)<.001/dp){
        a+=si*texture2D(s,sc ).rgb;
        b+=si;
      }
    }
  }
  return a/b;
}
#define GLOBAL_ILLUMINATION
/*DRAWBUFFERS:14*/
void main(){
  gl_FragData[0]=vec4(filt(tc,colortex1).rg,texture2D(colortex1, tc).b,1.);
  #ifdef GLOBAL_ILLUMINATION
  gl_FragData[1]=vec4(filt(tc,colortex4),1.);
  #else
  gl_FragData[1]=texture2D(colortex4,tc);
  #endif

}
