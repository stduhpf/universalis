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
#include "lib/colorspace.glsl"
#include "lib/trans.glsl"
#include "lib/essentials.glsl"

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

uniform float wetness;
uniform float rainStrength;

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

#define OREN_NAYAR_DIFFUSE


#ifdef OREN_NAYAR_DIFFUSE

float diffuse(vec3 v, vec3 l, vec3 n, float r) {
    r *= r;

    float cti = dot(n,l);
    float ctr = dot(n,v);

    float t = max(cti,ctr);
    float g = max(.0, dot(v - n * ctr, l - n * cti));
    float c = g/t - g*t;

    float a = .285 / (r+.57) + .5;
    float b = c * .45 * r / (r+.09);

    return max(0., cti) * ( b + a);
}
#else
float diffuse(vec3 v, vec3 l, vec3 n, float r) {

    float cti = dot(n,l);

    return max(0., cti);
}
#endif
float brdflight(vec3 n, vec3 v, vec3 l,float r){
  r+=.015;
  float d = max(dot(n,normalize(v+l)),0.);
  d*=d;
  float a = .5*r/(d*r*r+1.-d);
  return a*a/3.14;
}

float puddlen(vec3 p){
	return smoothstep(.6,.7,texture2D(noisetex,p.xz*.0006).r)*(texture2D(noisetex,p.xz*.003).r*.75+.2*texture2D(noisetex,vec2(p.x+p.z,p.x-p.z)*.0008).r+.05*texture2D(noisetex,vec2(p.x-p.z,p.x+p.z)*.1).r);
}

float hash(vec2 p){
		vec3 p3  = fract(vec3(p.xyx) * 443.8975);
    p3 += dot(p3, p3.yzx + 19.19);
    return fract((p3.x + p3.y) * p3.z);
}

vec2 hash22(vec2 p){
	vec3 p3 = fract(vec3(p.xyx) * vec3(443.897, 441.423, 437.195));
  p3 += dot(p3, p3.yzx+19.19)+ceil(hash(p)*mod(frameTimeCounter,500.)*3.);
  return fract((p3.xx+p3.yz)*p3.zy);
}


vec3 cmp(vec2 a, vec2 b,vec2 u){
	float la =length(a-u),lb=length(b-u);
	return (la<lb?vec3(la,a):vec3(lb,b));
}


vec4 voro(inout vec2 uv){
	uv*=2.9;
	vec2 u = floor(uv);
	vec2 off1 = hash22(u);
	vec2 off2 =  vec2(0,1)+hash22(u+vec2(0,1));
	vec2 off3 =  vec2(1)+hash22(u+vec2(1));
	vec2 off4 =  vec2(1,0)+hash22(u+vec2(1,0));
	u= fract(uv);
	vec3 ret= cmp(cmp(off1,off2,u).yz ,cmp(off3,off4,u).yz,u);
	return vec4(ret,hash(ret.yz-
	(ret.yz==off1?vec2(0):
	ret.yz==off2?vec2(0,1):
	ret.yz==off3?vec2(1):vec2(1,0))));
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
	vec3 skylightdir = normalize(vec3(dlm[1],3.*length(dlm[1])));
  #ifdef PBR
  vec4 PBRdata =gettex(specular,uv);
  #else
  vec4 PBRdata = vec4(0);
  #endif
	float porosity = PBRdata.b<.251?PBRdata.b*4.:0.;
	PBRdata.b=saturate((PBRdata.b-.25)/.75);
	float wet = wetness*smoothstep(.8,.93,lm.y);
	float puddle=0.;
	if(wet>0. && camdir(normal).y>.99){
		puddle=puddlen(wpos)*wet;
		puddle=smoothstep(.45,.7,puddle);
	}
  gl_FragData[0]=gettex(texture,uv)*tintColor;
  gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb);//*step(abs(texres.x-texres.y),.0001);//*0.+blocklightdir;

	gl_FragData[0].rgb*=(1.-porosity*wet*.82+.15*puddle*puddle);
	PBRdata.g = mix(PBRdata.g,.134,wet*porosity*float(PBRdata.g<.9));
	PBRdata.r= mix(PBRdata.r,1.,.5*wet*porosity);
	PBRdata.r= mix(PBRdata.r,1.,puddle*puddle);
	//PBRdata.r= 1.-sqrt(fract(wpos.x*.5));
	gl_FragData[4]=vec4(1);
	vec3 n = normal, nrml=normal;
	if(puddle>0.&&rainStrength>0.){
		vec3 p = wpos.xyz;
		vec4 a = voro(p.xz);
		vec2 d = normalize(a.yz-fract(p.xz));
		float phi = a.a*10.;
		d= .03*d*cos(50.*a.x- frameTimeCounter *24.+phi)*exp( -2.*a.x);
		nrml=tbn*normalize(vec3(d.x,d.y,1.));
	}
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
	ao=min(skylightdir.z>.01?diffuse(vpos,skylightdir,n*tbn,rgh)*(parallaxshadow(uv,skylightdir)*.75+.75):1.,ao);
	#endif
	gl_FragData[4].r=(ao);
	//gl_FragData[0].rgb = vec3(ao*ao);

if(puddle>=nmp.a){
	n=nrml;
	//PBRdata.xyz=vec3(.9,.134,0.);
}

#endif
  gl_FragData[2]=vec4(.5+.5*n,1.);
#ifdef SELF_SHADOW
	gl_FragData[4].g = parallaxshadow(uv,normalize(shadowLightPosition)*tbn);
#endif
  gl_FragData[3]=vec4(lm,PBRdata.a<1.?PBRdata.a:0.,1.);


	//gl_FragData[0].rg = texres;gl_FragData[0].b=0.;
	//gl_FragData[0].rgb=vec3(getpa(texture,uv),0.);
	//gl_FragData[0].rgb*=step(224, lmcoord.x);
	gl_FragData[1]=vec4(PBRdata.rgb,1);
}
