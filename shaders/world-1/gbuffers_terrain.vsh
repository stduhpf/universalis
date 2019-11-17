#version 130

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tbn;
varying vec3 vpos;
varying vec2 midTexCoord;
varying vec2 texres;
varying vec3 wpos;
attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;

uniform vec3 cameraPosition;

uniform int frameCounter;

#include "/lib/essentials.glsl"

uniform mat4 gbufferModelViewInverse;


void main()
{
	midTexCoord = mc_midTexCoord;

	vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));
	gl_Position = ftransform();
	gl_Position.xy += (offset-.5)*gl_Position.w/resolution;
	normal= normalize(gl_NormalMatrix*gl_Normal);
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_MultiTexCoord1;
	tintColor = gl_Color;

	vec3 tangent = normalize(gl_NormalMatrix*normalize(at_tangent.xyz));
	vec3 binormal = cross(tangent,normal);
	tbn= mat3(tangent, binormal, normal);
vpos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
wpos = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz+cameraPosition;
texres = (2.*abs(texcoord.st-midTexCoord));
}
