#version 120

varying vec4 texcoord;
varying vec4 tintColor;

uniform int frameCounter;

#include "../lib/essentials.glsl"



void main()
{
	vec2 offset = vec2(haltonSeq(5,frameCounter),haltonSeq(7,frameCounter+12));
	gl_Position = ftransform();
	gl_Position.xy += (offset-.5)*gl_Position.w/resolution;
	texcoord = gl_MultiTexCoord0;
	tintColor = gl_Color;

}
