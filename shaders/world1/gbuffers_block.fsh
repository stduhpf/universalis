#version 130
#extension GL_ARB_shader_texture_lod : enable
#extension GL_ARB_gpu_shader4 : enable

#define NORMAL_MAPPING
//#define DIRECTIONAL_LIGHTMAPS //super broken, not recommended
//#define AO_FIX

#include "/common/pbrformats"


uniform sampler2D texture;
uniform sampler2D normals;
#if PBR_FORMAT
uniform sampler2D specular;
#endif
uniform sampler2D noisetex;
#include "/lib/colorspace.glsl"
#include "/lib/trans.glsl"
#include "/lib/essentials.glsl"

varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tbn;
varying vec3 vpos;
varying vec2 midTexCoord;
uniform vec3 shadowLightPosition;
uniform float frameTimeCounter;
uniform int frameCounter;
varying vec3 wpos;

const int noiseTextureResolution = 256;

varying vec2 texres;
#define tt texres // vec2(max(texres.x,texres.y))

float dither = bayer16(gl_FragCoord.xy);



vec2 dcdx = dFdx(texcoord.rg);
vec2 dcdy = dFdy(texcoord.rg);

vec4 gettex(sampler2D t, vec2 v)
{
	v =(v-midTexCoord)/texres+.5;
	v=(fract(v)-.5)*texres+midTexCoord;
	return texture2DGradARB(t,v,dcdx,dcdy);

}


/*DRAWBUFFERS:03271*/
void main()
{

	vec2 uv = texcoord.st;
  vec2 lm = lmcoord.xy/256.;
	mat2 dlm = mat2(dFdx(lm.x),-dFdy(lm.x),dFdx(lm.y),-dFdy(lm.y));
  vec3 blocklightdir = normalize(vec3(dlm[0],2.*length(dlm[0])*(lm.x)));
	#if PBR_FORMAT
  vec4 PBRdata =gettex(specular,uv);
  #else
  vec4 PBRdata = vec4(0);
  #endif

  gl_FragData[0]=gettex(texture,uv)*tintColor;
  gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb);//*step(abs(texres.x-texres.y),.0001);//*0.+blocklightdir;

	gl_FragData[4]=vec4(1);
	vec3 n = normal, nrml=normal;

#ifdef NORMAL_MAPPING
	vec4 nmp = gettex(normals,uv);
	vec3 nm = nmp.rgb*2.-1.;
	float ao = length(nm);
//	vec2 tb = (nm/ao).xy;
//	vec3 nrm = vec3(tb,sqrt(1.-dot(tb,tb))); //test for 2 channels normals (is working fine)
  n = tbn*(nm/ao);
	//n=tbn*vec3(0,0,1);
	#ifndef AO_FIX
	ao*=ao;
	#else
	ao=sqrt(ao);
	ao = saturate(ao);
	#endif
	#ifdef DIRECTIONAL_LIGHTMAPS
	float rgh = pow(1.-PBRdata.r,2.);
  lm.x=min(blocklightdir.z>.0?diffuse(vpos,blocklightdir,n*tbn,rgh)*(parallaxshadow(uv,blocklightdir)*.75+.25):1.,lm.x);
	//lm.y*=skylightdir.z>.01?max(0.1,dot(n*tbn,skylightdir))*parallaxshadow(uv,skylightdir):1.;
	#endif
	gl_FragData[4].r=(ao);
	//gl_FragData[0].rgb = vec3(ao*ao);


#endif
  gl_FragData[2]=vec4(.5+.5*n,1.);

  gl_FragData[3]=vec4(lm,PBRdata.a<1.?PBRdata.a:0.,1.);

	gl_FragData[1]=vec4(PBRdata.rgb,1);
}
