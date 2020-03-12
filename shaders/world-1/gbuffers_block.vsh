#version 420 compatibility

out vec3 normal;
out vec4 texcoord;
out vec4 tintColor;
out vec4 lmcoord;
out mat3 tbn;
out vec3 vpos;
out vec2 midTexCoord;
out vec2 texres;
out vec3 wpos;
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
	gl_Position.xy += 2.*(offset-.5)*gl_Position.w/resolution;
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
