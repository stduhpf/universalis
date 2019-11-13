#version 120

#define NORMAL_MAPPING
#define PBR

uniform sampler2D texture;
#ifdef NORMAL_MAPPING
uniform sampler2D normals;
#endif
#ifdef PBR
uniform sampler2D specular;
#endif
#include "../lib/colorspace.glsl"

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tbn;

/*DRAWBUFFERS:03271*/

void main()
{
  vec2 lm = lmcoord.xy/256.;
  vec3 blocklightdir = tbn*normalize(vec3(dFdx(lm.x),-dFdy(lm.x),.005*(1.-sqrt(lm.x))));
  #ifdef PBR
  vec4 PBRdata = texture2D(specular,texcoord.st);
  #else
  vec4 PBRdata = vec4(0);
  #endif
  gl_FragData[0]=texture2D(texture,texcoord.st)*tintColor;
  gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb);
//  gl_FragData[0].rgb=PBRdata.rgb;
  gl_FragData[1]=vec4(PBRdata.rgb,1);
  float ao = 0.;
#ifdef NORMAL_MAPPING
  vec3 nm = texture2D(normals,texcoord.st).rgb*2.-1.;
  ao = length(nm);
  vec3 n = tbn*(nm/ao);
  gl_FragData[2]=vec4(n*.5+.5,1.);
  lm*=ao*ao;
  //lm.x*=max(0.,dot(n,blocklightdir));
#else
  gl_FragData[2]=vec4(.5+.5*normal,1.);
#endif
  gl_FragData[3]=vec4(lm,PBRdata.a<1.?PBRdata.a:0.,1.);
  //gl_FragData[0].rgb*=ao*ao;
  gl_FragData[4]=vec4(ao*ao,1,1,1);

}
