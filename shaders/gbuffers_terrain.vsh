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
attribute vec3 mc_Entity;

uniform vec3 cameraPosition;

uniform int frameCounter;
uniform float frameTimeCounter;

#include "lib/essentials.glsl"

uniform mat4 gbufferModelViewInverse;
uniform mat4 gbufferModelView;
uniform float rainStrength;
#include "lib/wind.glsl"

void main()
{
	midTexCoord = mc_midTexCoord;
	normal= normalize(gl_NormalMatrix*gl_Normal);
	texcoord = gl_MultiTexCoord0;
	lmcoord = gl_MultiTexCoord1;
	tintColor = gl_Color;

	vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));
	//gl_Position = ftransform();
	gl_Position = gl_ModelViewMatrix*gl_Vertex;

vpos =gl_Position.xyz;
wpos = mat3(gbufferModelViewInverse) * vpos +cameraPosition;

	if(mc_Entity.x == 30){
		gl_Position = gbufferModelViewInverse*gl_Position;

		gl_Position.xyz+=wind(wpos);

		gl_Position = gbufferModelView*gl_Position;
	}

	if(mc_Entity.x == 31){
		gl_Position = gbufferModelViewInverse*gl_Position;

		bool istop = (texcoord.t < mc_midTexCoord.t)||mc_Entity.x == 32;
		if(istop){
			gl_Position.xyz+=wind(wpos);
		}
		gl_Position = gbufferModelView*gl_Position;
	}

	gl_Position = gl_ProjectionMatrix*gl_Position;
	gl_Position.xy += 2.*(offset-.5)*gl_Position.w/resolution;

	vec3 tangent = normalize(gl_NormalMatrix*normalize(at_tangent.xyz));
	vec3 binormal = cross(tangent,normal);
	tbn= mat3(tangent, binormal, normal);

texres = (2.*abs(texcoord.st-midTexCoord));
}
