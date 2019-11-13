#version 120

#include "lib/shadowtransform.glsl"
#include "lib/essentials.glsl"

varying vec2 tc;
varying vec4 tintColor;
varying vec3 normal;
//#define RSM_NORMAL_MAPPING //can improve the quality of gi in some situations, but is not worth the performance cost most of the time
#ifdef RSM_NORMAL_MAPPING
varying mat3 tbn;

attribute vec4 at_tangent;
#endif

void main()
{
  normal= normalize(gl_NormalMatrix*gl_Normal);

  tc = gl_MultiTexCoord0.xy;
  gl_Position = gl_ProjectionMatrix *gl_ModelViewMatrix*gl_Vertex;

  gl_Position.xyz = stransformcam(gl_Position.xyz);

  tintColor = gl_Color;

  #ifdef RSM_NORMAL_MAPPING
  	vec3 tangent = normalize(gl_NormalMatrix*normalize(at_tangent.xyz));
  	vec3 binormal = cross(tangent,normal);
  	tbn= mat3(tangent, binormal, normal);
  #endif
}
