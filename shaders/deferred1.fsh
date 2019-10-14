#version 120
#include "lib/essentials.glsl"
#include "lib/bloom.glsl"

varying vec2 tc;
uniform sampler2D colortex4;


/*DRAWBUFFERS:4*/
void main(){
if(floor(2.*tc)==vec2(0)){
gl_FragData[0]=vec4(kawazePass(colortex4,tc,1.,resolution),1.);
}
else{
  gl_FragData[0]=texture2D(colortex4,tc);
}

}
