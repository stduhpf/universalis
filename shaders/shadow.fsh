#version 120

#include "lib/colorspace.glsl"
uniform sampler2D texture;
varying vec2 tc;
varying vec4 tintColor;
varying vec3 normal;

//#define RSM_NORMAL_MAPPING
#ifdef RSM_NORMAL_MAPPING
uniform sampler2D normals;
varying mat3 tbn;
#endif


void main(){
  vec4 c=texture2D(texture,tc)*tintColor;
  c.rgb = srgbToLinear(c.rgb);
  gl_FragData[0]  = c;
  #ifdef RSM_NORMAL_MAPPING
  vec3 n = tbn*(2.*texture2D(normals,tc).rgb-1.);
  gl_FragData[1]=vec4(n*.5+.5,1.);
  #else
  gl_FragData[1] = vec4(normal*.5+.5,1.);
  #endif
}
