#version 120
#extension GL_ARB_shader_texture_lod : enable

uniform sampler2D texture;
uniform sampler2D normals;
uniform sampler2D specular;
#include "lib/colorspace.glsl"
#include "lib/trans.glsl"
#define NORMAL_MAPPING
#define POM
#define SELF_SHADOW
//#define DIRECTIONAL_LIGHTMAPS //super broken, not recommended
#define PBR




varying vec3 normal;
varying vec4 texcoord;
varying vec4 tintColor;
varying vec4 lmcoord;
varying mat3 tnb;
varying mat3 tbn;
varying vec3 vpos;
varying vec3 position;
varying vec2 midTexCoord;
varying float entity;
varying vec2 texres;



uniform float frameTimeCounter;
uniform ivec2 atlasSize;
#define WATER_TEXTURE

uniform vec3 shadowLightPosition;
uniform int worldTime;

//{//water stuff

	float hash(vec2 p)
		{
			vec3 p3  = fract(vec3(p.xyx) * 443.8975);
		    p3 += dot(p3, p3.yzx + 19.19);
		    return fract((p3.x + p3.y) * p3.z);
		}


	vec2 dsmoothstep(float edge0, float edge1, float t){
	    t = clamp((t - edge0) / (edge1 - edge0), 0.0, 1.0);
	    return vec2(t*t*(3.0-2.0*t),6.0*t*(1.0-t));
	}

	vec2 dinter(float a, float b, float c){
	    return vec2(a,0.)+(b-a)*dsmoothstep(0.,1.,c);
	}
	float inter(float a, float b, float c){
	    return a+(b-a)*smoothstep(0.,1.,c);
	}
	#define WATER_HEIGHT .15 //[0. .01 .05 .1 .15 .2 .3 .4 .5 .75 1.]

	float whash(vec2 a){
		return (hash(a)-.5)*WATER_HEIGHT;
	}
	vec3 dperlin(vec2 a){
	    vec2 n1 =dinter(whash(floor(a)),
	        whash(floor(a+vec2(1,0))),fract(a.x));
	    vec2 n2 =dinter(whash(floor(a+vec2(0,1))),
	        whash(floor(a+1.)),fract(a.x));
	    return vec3(dinter(n1.x,n2.x,fract(a.y)),dinter(n1.y,n2.y,fract(a.y)).x).xzy;
	}
	float perlin(vec2 a){
	    float n1 =inter(whash(floor(a)),
	        whash(floor(a+vec2(1,0))),fract(a.x));
	    float n2 =inter(whash(floor(a+vec2(0,1))),
	        whash(floor(a+1.)),fract(a.x));
	    return inter(n1,n2,fract(a.y));
	}

	#define WAVE_NOISE_OCTAVES 4 //[1 2 4 8 16]
	#define speed 3.3
	vec3 dfbm(vec2 p){
		vec3 n = dperlin(-p+frameTimeCounter*.2*speed)+ dperlin(p+frameTimeCounter*.3*speed);
		float tt= .5;
		for(int i = 1;i++<WAVE_NOISE_OCTAVES;)
		{
			float s = float(i);
			p*=mat2(cos(i*tt),sin(i*tt),-sin(i*tt),cos(i*tt));
	  	vec3 n1 = dperlin(p*s+frameTimeCounter*.2*s*speed)/pow(s,2.);
	  	n1.xy*=s*mat2(cos(i*tt),-sin(i*tt),sin(i*tt),cos(i*tt));
	  	n+=n1;
	  }
		return -n;
	}

	float fbm(vec2 p){
		float n = perlin(-p+frameTimeCounter*.2*speed)+ perlin(p+frameTimeCounter*.3*speed);
		float tt= .5;
		for(int i = 1;i++<WAVE_NOISE_OCTAVES;)
		{
			float s = float(i);
			p*=mat2(cos(i*tt),sin(i*tt),-sin(i*tt),cos(i*tt));
	  	float n1 = perlin(p*s+frameTimeCounter*.2*s*speed)/pow(s,2.);
	  	n+=n1;
	  }
		return -n;
	}


	vec4 normap(vec2 uv){
		 float ay =.25;
	    mat2 r = mat2(cos(ay),sin(ay),-sin(ay),cos(ay));
	    uv*=r;
	    vec3 d= dfbm(uv*.5);
			d.yz*=.5;
	    d.yz = d.yz* mat2(cos(ay),-sin(ay),sin(ay),cos(ay));
	    return vec4(vec3(d.y,1.,d.z),d.x);
	}

	float heightmap(vec2 uv){
		float ay =.25;
	    mat2 r = mat2(cos(ay),sin(ay),-sin(ay),cos(ay));
	    uv*=r;
	    float d= fbm(uv*.5);
	    return d;
	}
	#define WATER_PARALLAX

	#ifdef WATER_PARALLAX
	#define WATER_PARALLAX_PRECISION .5 //[2. 1. .5 .25 .15 .1]

	vec3 parallaxposw(vec3 p,vec3 rd){
	    vec3 step = vec3(1.,1.,1.)*WATER_PARALLAX_PRECISION;
	    float height = normap(p.xz).w;
	    vec3 pc = vec3(0,0,1.);
	    vec3 rstep = step*rd;
	    for(int i =0;i<150 && pc.z > height;i++)
	    {
	        pc.xy +=rstep.xy*clamp((pc.z-height)/(step.z*.2/(.05-rd.z)),0.,1.);
	        pc.z+=rstep.z;
	        height = (1.-WATER_HEIGHT*2.)+heightmap(p.xz+pc.xy);
	    }
	    return p+vec3(pc.x,0.,pc.y);
	}

	#endif


	//#define PILLAR_WATER
	#ifdef PILLAR_WATER
	#define it 100

	float normaps(vec2 a){
	  float b = heightmap(a);
	  return b*b;
	}

	float map(vec2 uv){
	 return -400.*(normaps(uv)+normaps(-uv));
	}
	vec3 raymarche(vec3 ro, vec3 rd){//hybrid voxel raymarcher.
	  ro*=10.;
	        vec2 zu = vec2(0,1);
	    vec2 p = floor(ro.xy);
	    vec2 s = sign(rd.xy);
	    vec2 td = s/rd.xy,
	        tm = max(s,0.)*td-(fract(ro)/rd).xy,
	        tm2=tm;
	    vec3 n = zu.xyx;
	    for(int i =0;i++<it;)
	    {
	        float pd = (map(p/10.)-ro.z)/rd.z;
	            if(pd>0.){
	            vec3 ip = ro+pd*rd;
	            vec2 ds = (p+(s*.5+.5)-ro.xy)/rd.xy;
	            float md = min(ds.x<0.?1e6:ds.x,ds.y<0.?1e6:ds.y); // takes min and discard negatives

	            vec2 pi= floor(ip.xy);
	            if(pi==p||pd<md){
	               n=zu.xyx;
	                if(pi!=p){
						float m = min(tm2.x,tm2.y);
	                    if(tm2.x==m){
	                        n = zu.yxx;
	                    }else{
	                        n = zu.xxy;
	                    }
	                }
	                n=n*vec3(-s.x,1.,-s.y);
	                return n;
	            }
	        }
	        tm2=tm;
	       float m = min(tm.x,tm.y);//voxel raymarching
	        if(tm.x==m){
	            p.x+=s.x;
	            tm.x+=td.x;
	        }else{
	            p.y+=s.y;
	            tm.y+=td.y;
	        }
	    }
	    return vec3(0);
	}
	#endif
//}

//{//others


	vec2 dcdx = dFdx(texcoord.rg);
	vec2 dcdy = dFdy(texcoord.rg);

	vec4 gettex(sampler2D t, vec2 v)
	{
		return texture2DGradARB(t,v,dcdx,dcdy);
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
	#include "lib/essentials.glsl"
	uniform sampler2D shadowtex1;
	#include "lib/shadowtransform.glsl"

	#include "lib/shadow_lite.glsl"
	#include "lib/lmcol.glsl"

//}



/*DRAWBUFFERS:01237*/
void main()
{
  #include "lib/lightcol.glsl"

  bool iswater = ((floor(entity+.1)==9.)||floor(entity+.1)==8.);
	vec2 lm = lmcoord.xy/256.;

	vec2 tc = texcoord.st;
	vec3 p = position;
  #ifndef PILLAR_WATER
	#ifdef WATER_PARALLAX
  if(iswater){
    p = parallaxposw(p,normalize(vpos)*tbn);
    tc =iswater? midTexCoord+(fract(p.xz)-.5)*texres:tc;
		#endif
		#endif
		vec4 t =texture2D(texture,tc);
		vec3 c = t.rgb;
		float trans = t.a;
		gl_FragData[0]=tintColor;
		//gl_FragData[0].rgb=vec3(1.-(WATER_TEXTURE_RESOLUTION*length(tc-midTexCoord)));
		#ifdef WATER_TEXTURE
		gl_FragData[0].rgb= srgbToLinear(c*gl_FragData[0].rgb*.5)*lightCol*lmcoord.y/256.;
		gl_FragData[0].a=trans;
		gl_FragData[1]=vec4(1,1.,srgbToLinear(c).r,1);
		#else
		gl_FragData[0]=vec4(0,0,0,0.);
		gl_FragData[1]=vec4(1,1.,1.,1.);
		#endif


		vec3 n =iswater? tnb*normalize(normap(p.xz).xyz):normal;
		#ifdef PILLAR_WATER
		n = iswater?tnb*raymarche(vec3(position.xz,0.),normalize(vpos)*tbn):n;
		#endif
		gl_FragData[2]=vec4(normalize(n)*.25+.5,1.);

		gl_FragData[3]=vec4(.9,.134,0.,1.);
  }
	else{
		vec2 uv = texcoord.st;

		mat2 dlm = mat2(dFdx(lm.x),-dFdy(lm.x),dFdx(lm.y),-dFdy(lm.y));
		vec3 blocklightdir = normalize(vec3(dlm[0],2.*length(dlm[0])*(lm.x)));
		vec3 skylightdir = normalize(vec3(dlm[1],3.*length(dlm[1])));
		#ifdef PBR
		vec4 PBRdata =gettex(specular,uv);
		#else
		vec4 PBRdata = vec4(0);
		#endif
		gl_FragData[0]=gettex(texture,uv);
		gl_FragData[0].rgb= srgbToLinear(gl_FragData[0].rgb*tintColor.rgb)*.5;//*0.+blocklightdir;
		//gl_FragData[0].a=1.;
		//gl_FragData[0].rg = texres;gl_FragData[0].b=0.;
		//gl_FragData[0].rgb=vec3(getpa(texture,uv),0.);
		gl_FragData[3]=vec4(PBRdata.rgb,1);
		vec3 n = normal;
	#ifdef NORMAL_MAPPING
		n = normalize(gettex(normals,uv).rgb*2.-1.);
	#endif
		gl_FragData[2]=vec4(n*.5+.5,1.);

//gl_FragData[0]=vec4(PBRdata.rgb,1.);

		#include "lib/ambcol.glsl"

		gl_FragData[0].rgb*=mix(vec3(1.),diffuse(normalize(vpos),normalize(shadowLightPosition),n,pow(1.-PBRdata.r,2.))*lightCol*shadow3(world2cam(p))+ambientCol*lm.y*ambi+TorchColor*lm.x,gl_FragData[0].a);
		gl_FragData[1]=vec4(1,0.,1.,1.);
	}
	gl_FragData[4]=vec4(lm,0.,1.);

}
