#version 120

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tnb;
varying mat3 tbn;
varying vec3 position;
varying vec3 vpos;
varying vec2 midTexCoord;
varying float entity;
varying vec2 texres;


uniform int frameCounter;
uniform mat4 gbufferModelViewInverse;
uniform vec3 cameraPosition;

attribute vec4 at_tangent;
attribute vec2 mc_midTexCoord;
attribute vec2 mc_Entity;


#include "/lib/essentials.glsl"


void main()
{
	vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));
	midTexCoord = mc_midTexCoord;
	gl_Position = ftransform();
	gl_Position.xy += (offset-.5)*gl_Position.w/resolution;
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_MultiTexCoord1;
	tintColor = gl_Color;
	position = (gbufferModelViewInverse * (gl_ModelViewMatrix * gl_Vertex)).xyz+cameraPosition;
	vec3 t,b;
	normal= normalize(gl_NormalMatrix*gl_Normal);
	t=normalize(gl_NormalMatrix*at_tangent.xyz);
	b= cross(t,normal);
	tnb = mat3(t,normal,b);
	tbn = mat3(t,b,normal);
	vpos = mat3(gl_ModelViewMatrix) * gl_Vertex.xyz + gl_ModelViewMatrix[3].xyz;
	entity=mc_Entity.x;
	texres = 2.*abs(texcoord.st-midTexCoord);
}
