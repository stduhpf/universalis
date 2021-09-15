#version 120

#include "lib/essentials.glsl"

varying vec2 tc;
uniform sampler2D colortex4;
uniform sampler2D colortex0;


/*DRAWBUFFERS:0*/
void main(){
  vec3 c = texture2D(colortex0,tc).rgb;
  vec3 refc = texture2D(colortex4,tc).rgb;

  gl_FragData[0] = vec4(c+refc,1.);
}
