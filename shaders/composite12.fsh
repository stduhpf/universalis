#version 120
#include "lib/essentials.glsl"
#include "lib/bloom.glsl"

varying vec2 tc;
uniform sampler2D colortex1;
uniform sampler2D depthtex1;


/*DRAWBUFFERS:1*/
void main(){
  if(floor(2.*tc)==vec2(1)){
  gl_FragData[0]=filterCloud(colortex1,tc,1.,resolution,depthtex1);
  }
  else{
    if(floor(2.*tc)==vec2(1,0.)){
    gl_FragData[0]=filterCloudSh(colortex1,tc,1.,resolution);
    }else{
      gl_FragData[0]=texture2D(colortex1,tc);
    }
  }

}
