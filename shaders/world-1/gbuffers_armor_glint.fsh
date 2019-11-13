#version 120

uniform sampler2D texture;

#include "../lib/colorspace.glsl"

varying vec4 texcoord;
varying vec4 tintColor;


/*DRAWBUFFERS:0*/

void main()
{

  gl_FragData[0]=texture2D(texture,texcoord.st)*tintColor;
  gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb);
}
