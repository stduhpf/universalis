#version 120
#define NORMAL_MAPPING

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
#ifdef NORMAL_MAPPING
varying mat3 tbn;

attribute vec4 at_tangent;
#endif

uniform int frameCounter;

#include "lib/essentials.glsl"



void main()
{
	vec2 offset = 0.*vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));
	gl_Position = ftransform();
	gl_Position.xy += (offset-.5)*gl_Position.w/resolution;
	normal= normalize(gl_NormalMatrix*gl_Normal);
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_MultiTexCoord1;
	tintColor = gl_Color;

#ifdef NORMAL_MAPPING
	vec3 tangent = normalize(gl_NormalMatrix*normalize(at_tangent.xyz));
	vec3 binormal = cross(tangent,normal);
	tbn= mat3(tangent, binormal, normal);
#endif
}
