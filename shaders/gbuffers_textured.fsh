#version 120

#define NORMAL_MAPPING

#include "/common/pbrformats"


uniform sampler2D texture;
#ifdef NORMAL_MAPPING
uniform sampler2D normals;
#endif
#if PBR_FORMAT
uniform sampler2D specular;
#endif
#include "/lib/colorspace.glsl"

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tbn;
uniform vec4 entityColor;
uniform int entityId;
/*DRAWBUFFERS:03271*/

void main()
{
  vec2 lm = lmcoord.xy/256.;
  vec3 blocklightdir = tbn*normalize(vec3(dFdx(lm.x),-dFdy(lm.x),.005*(1.-sqrt(lm.x))));
  #if PBR_FORMAT
  vec4 PBRdata = texture2D(specular,texcoord.st);
  #else
  vec4 PBRdata = vec4(0);
  #endif
  #if PBR_FORMAT == labPBRv1_3
  PBRdata.g = sqrt(PBRdata.g);
  #endif
  gl_FragData[0]=texture2D(texture,texcoord.st)*tintColor+vec4(entityColor.rgb,0);
  
  gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb);
  gl_FragData[1]=vec4(PBRdata.rgb,1);
  float ao = 1.;
  #ifdef NORMAL_MAPPING
  #define gettex texture2D
  vec2 uv = texcoord.st;
  vec3 n;
  #include "/lib/normals.glsl"

    gl_FragData[2]=vec4(n*.5+.5,gl_FragData[0].a);
    //lm*=ao;
  #else
  gl_FragData[2]=vec4(.5+.5*normal,gl_FragData[0].a);
  #endif
  gl_FragData[3]=vec4(lm,PBRdata.a<1.?PBRdata.a:0.,1.);
  //gl_FragData[0].rgb*=ao*ao;
  gl_FragData[4]=vec4(ao,1,1,1);

  }
