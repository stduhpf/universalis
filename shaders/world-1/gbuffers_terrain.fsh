#version 130
#extension GL_ARB_shader_texture_lod : enable
#extension GL_ARB_gpu_shader4 : enable

#define NORMAL_MAPPING
#define POM
#define SELF_SHADOW
//#define DIRECTIONAL_LIGHTMAPS //super broken, not recommended
#define PBR
//#define AO_FIX


uniform sampler2D texture;
uniform sampler2D normals;
#ifdef PBR
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



#define POM_DEPTH .25 // [.025 .05 .1 .2 .25 .3 .4 .5 .6 .7 .75 .8 .9 1.]
#define POM_STEPS 64 //[4 8 16 32 64 128 256]
vec2 parallaxpos(vec2 uv,vec3 rd)
{
		float dpth = POM_DEPTH;
    float ste =dpth/(POM_STEPS+1);
    float height = dpth*gettex(normals,uv).w;
    vec3 pc = vec3(uv,0.);
    vec3 rstep = -ste*vec3(tt,1.)*rd/rd.z;
		pc+=rstep*fract(dither+haltonSeq(13,frameCounter));
    for(int i =0;i<POM_STEPS && pc.z >= height-dpth;i++)
    {
				if(gettex(texture,pc.xy).w==0.)
					break;
        pc+=rstep;
        height =dpth*gettex(normals,pc.xy).w;//*(sin(frameTimeCounter)*.5+.5);
    }
    //pc.xy -= rstep.xy*(height-pc.z)*ste;
    return pc.xy;
}
float parallaxshadow(vec2 pp,vec3 ld)
{
		float dpth =  POM_DEPTH;
    float ste =dpth/(POM_STEPS);
    float height = dpth*gettex(normals,pp).w;
    vec3 pc = vec3(pp,height);
    vec3 rstep = ld*min(ste*vec3(tt,1.)/abs(ld.z),.005);
		pc+=rstep*fract(dither+haltonSeq(19,frameCounter));
    for(int i =0;i<POM_STEPS;i++)
    {
        pc+=rstep;
        height =dpth*gettex(normals,pc.xy).w;
				if(pc.z <= height)
					return 0.;
    }
    //pc.xy -= rstep.xy*(height-pc.z)*ste;
    return 1.;
}


/*DRAWBUFFERS:03271*/
void main()
{
	#ifdef POM
  vec2 uv = parallaxpos(texcoord.st,vpos*tbn);
	#else
	vec2 uv = texcoord.st;
	#endif
  vec2 lm = lmcoord.xy/256.;
	mat2 dlm = mat2(dFdx(lm.x),-dFdy(lm.x),dFdx(lm.y),-dFdy(lm.y));
  vec3 blocklightdir = normalize(vec3(dlm[0],2.*length(dlm[0])*(lm.x)));
  #ifdef PBR
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
#ifdef SELF_SHADOW
	gl_FragData[4].g =0.;
#endif
  gl_FragData[3]=vec4(lm,PBRdata.a<1.?PBRdata.a:0.,1.);

	gl_FragData[1]=vec4(PBRdata.rgb,1);
}
