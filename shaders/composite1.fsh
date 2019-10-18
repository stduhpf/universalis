#version 120
#include "lib/essentials.glsl"
#include "lib/bloom.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"

varying vec2 tc;
uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform sampler2D depthtex1;


/*DRAWBUFFERS:10*/
void main(){
  vec4 color  = texture2D(colortex0,tc);
  gl_FragData[1] = color;
  if(texture2D(depthtex1,tc).r>=1.){
    gl_FragData[1].rgb = mix(getSky3(normalize(screen2cam(vec3(tc,1.))))*.5,color.rgb,texture2D(colortex1,tc*.5+.5).b);
  }
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
