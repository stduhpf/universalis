#version 120
#include "lib/essentials.glsl"
#include "lib/bloom.glsl"

varying vec2 tc;
uniform sampler2D colortex7;
uniform sampler2D colortex0;
uniform sampler2D colortex1;


vec3 filt(vec2 tc, sampler2D s){
  vec3 a = vec3(0);

  a=3.*texture2D(s, tc).rgb;
  a+=2.*texture2D(s, tc+3.*vec2(0,1)/resolution).rgb;
  a+=2.*texture2D(s, tc+3.*vec2(-1,0)/resolution).rgb;
  a+=2.*texture2D(s, tc+3.*vec2(0,-1)/resolution).rgb;
  a+=2.*texture2D(s, tc+3.*vec2(1,0)/resolution).rgb;
  a+=texture2D(s, tc+3.*vec2(1,1)/resolution).rgb;
  a+=texture2D(s, tc+3.*vec2(-1,1)/resolution).rgb;
  a+=texture2D(s, tc+3.*vec2(1,-1)/resolution).rgb;
  a+=texture2D(s, tc+3.*vec2(-1,-1)/resolution).rgb;
  return a/15.;
}

/*DRAWBUFFERS:01*/
void main(){
  if(texture2D(colortex7, tc).g<.5){
    gl_FragData[0]=texture2D(colortex0,tc);
}else{
  gl_FragData[0]=vec4(kawazePass(colortex0,tc,2.,resolution),1.);
}
gl_FragData[1]=vec4(kawazePass(colortex1,tc,2.,resolution),1.);

}
