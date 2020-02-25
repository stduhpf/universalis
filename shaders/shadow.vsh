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
attribute vec4 mc_Entity;
attribute vec2 mc_midTexCoord;
uniform float frameTimeCounter;
uniform float rainStrength;
uniform vec3 cameraPosition;

#include "lib/wind.glsl"

void main()
{
  normal= normalize(gl_NormalMatrix*gl_Normal);

  tc = gl_MultiTexCoord0.xy;
  gl_Position = gl_ModelViewMatrix*gl_Vertex;

  if(mc_Entity.x == 30){
    gl_Position = shadowModelViewInverse*gl_Position;

		gl_Position.xyz+=wind(gl_Position.xyz+cameraPosition);

    gl_Position = shadowModelView*gl_Position;
	}

	if(mc_Entity.x == 31 ){
    gl_Position = shadowModelViewInverse*gl_Position;

		bool istop = (tc.t < mc_midTexCoord.t);
		if(istop){
			gl_Position.xyz+=wind(gl_Position.xyz+cameraPosition);
		}
    gl_Position = shadowModelView*gl_Position;
	}
gl_Position = gl_ProjectionMatrix *gl_Position;

  gl_Position.xyz = stransformcam(gl_Position.xyz);

  tintColor = gl_Color;

  #ifdef RSM_NORMAL_MAPPING
  	vec3 tangent = normalize(gl_NormalMatrix*normalize(at_tangent.xyz));
  	vec3 binormal = cross(tangent,normal);
  	tbn= mat3(tangent, binormal, normal);
  #endif
}
