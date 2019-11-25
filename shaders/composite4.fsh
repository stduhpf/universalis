#version 120

#include "lib/essentials.glsl"

varying vec2 tc;
uniform sampler2D colortex4;
uniform sampler2D colortex0;

vec3 filter(sampler2D s,vec2 tc,float a){
  vec2 ii = 1.5/resolution;

  vec3 c=texture2D(s,tc).rgb;
  c+=texture2D(s,tc+ii).rgb*a;
  c+=texture2D(s,tc-ii).rgb*a;
  ii.x=-ii.x;
  c+=texture2D(s,tc+ii).rgb*a;
  c+=texture2D(s,tc-ii).rgb*a;

  return c/(1.+a*4.);
}

/*DRAWBUFFERS:0*/
void main(){
  vec3 c = texture2D(colortex0,tc).rgb;
  vec3 refc = filter(colortex4,tc,.25).rgb;

  gl_FragData[0] = vec4(c+refc,1.);
}
