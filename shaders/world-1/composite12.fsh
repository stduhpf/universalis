#version 120
#include "../lib/essentials.glsl"
#include "../lib/bloom.glsl"

varying vec2 tc;
uniform sampler2D colortex1;


/*DRAWBUFFERS:1*/
void main(){

gl_FragData[0]=vec4(kawazePass(colortex1,tc,5.,resolution),1.);

}
