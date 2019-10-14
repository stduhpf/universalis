#define PCSS_ACCURACY 4     //[2 3 4 5 6] //Huge performance impact, little visual difference
#define sshradius .1/PCSS_ACCURACY    //radius in m*pixel/screenwidthh

#define PCSS_SAMPLES 8  //[1 2 4 8 12 16]
#define shadow_offset 0.0001

//#define SSCS

#define PCSS
//#define VOLUME_PCSS
const int		shadowMapResolution	= 1024; //[512 1024 2048 4096]
const float shadowDistance = 64.; //[16. 32. 64. 128. 256.]

#define PCSS_STRENGTH 1. //[0. .25 .5 1. 1.5 2. 2.5 3. 3.5 4.] //0 disables PCSS, but keeps the filtering
float getPenumbra(vec3 sp){
  if (PCSS_STRENGTH==0.){
    return 0.;
    }else{
    int k = 0;
    float a = 0.;
    float r =0.;
    for(int i = 0;i<PCSS_ACCURACY;i++){
      for(int j=0;j<PCSS_ACCURACY;j++){
        vec2 sc = sshradius*((vec2(r,-r)+vec2(i,j))/PCSS_ACCURACY-.5)+sp.xy;
        float depth =(texture2D(shadowtex1,sc).r);
        if(depth<sp.z-shadow_offset){
          a+=depth;
          k++;
        }
      }
    }
    a/=float(k);
    return PCSS_STRENGTH*.1*(sp.z-a)/a;
  }
}

#define WATER_THICCNESS 0.25 //[0.0 0.0004 0.0016 0.0036 0.0064 0.01 0.0144 0.0196 0.0256 0.0324 0.04 0.0484 0.0576 0.0676 0.0784 0.09 0.1024 0.1156 0.1296 0.1444 0.16 0.1764 0.1936 0.2116 0.2304 0.25 0.2704 0.2916 0.3136 0.3364 0.36 0.3844 0.4096 0.4356 0.4624 0.49 0.5184 0.5476 0.5776 0.6084 0.64 0.6724 0.7056 0.7396 0.7744 0.81 0.8464 0.8836 0.9216 0.9604 1.0]
#define WATER_ABSORB
float shadowDepth(vec3 p){
  #ifdef WATER_ABSORB
    vec3 sp = stransformcam(scam2clip(p))*.5+.5;
    return 0.*max(0.,-sdepthLin(sp.z)+sdepthLin(texture2D(shadowtex0,sp.xy).r))*WATER_THICCNESS*3.1;
    #else
    return 0.;
    #endif
}

float getSoftShadows(vec3 sp, float pen,float d){
  d = depthLin(d);
  float a = 0.;
  vec2 angle = vec2(0,pen/sqrt(float(PCSS_SAMPLES+1)));
  angle *= rot(dither*6.28318530718+sin(dither)*frameCounter);
  float r = 1.+fract(.5+dither+sin(dither)*frameTimeCounter);
  for(int i = 0;i<PCSS_SAMPLES;i++){
    r+=1./r;
    angle *= Grot;
    vec2 sc = (r-1.)*angle+sp.xy;
    float depth =(texture2D(shadowtex1,sc).r);
    a+= step(sp.z-shadow_offset*(SHADOW_BIAS+length8(sc)),depth)*exp2(-shadowDepth(vec3(sc,depth)));
  }
return a/float(PCSS_SAMPLES);
}
#define SSCS_IT 16

float sscs(vec3 p){
  vec3 cp = p, cp0=p;
  vec3 sp =screen2view(p);
  vec3 d = normalize(view2screen(sp+normalize(shadowLightPosition))-p);
  vec3 toBord = (step(0,d)-cp)/(d*float(SSCS_IT)*4.); //distances to borders divided by the number of steps
  float limstep =.05*max(min(1./SSCS_IT,float(SSCS_IT)),min(min(toBord.x,toBord.y),toBord.z));
	float	stepl=limstep, depth;
	cp+=stepl*d;

	float c = 1.;//to replace with sky color
	for(int i =0;i++<SSCS_IT;)
	{
		if(floor(cp.xy)!=vec2(0))
      break;
		if(	(depth = texture2D(depthtex1,cp.xy).r)<cp.z){
			if(abs(cp.z-depth)-.0003<5.*abs(stepl*d.z)&&depth<1.)
			     c=0.;
			break;

    }
		cp+=stepl*d;
    stepl =clamp((depth-p.z)/abs(d.z),.01*limstep,limstep);

	}

	return c;
}


float shadow(float pixdpth){
  vec3 scp = vec3(tc,pixdpth);
  vec3 p = screen2cam(scp);
  vec3 sp = stransformcam(scam2clip(p))*.5+.5;
  sp.z-=.0001;
  #ifdef SSCS
  float s = sscs(scp);
  //return s;
  #else
  float s =1.;
  #endif
  #ifdef PCSS
  return min(s,getSoftShadows(sp,max(getPenumbra(sp),1.41421356237/float(shadowMapResolution*MC_SHADOW_QUALITY)),pixdpth));
  #else
  return step(sp.z-shadow_offset*(SHADOW_BIAS+length8(sp.xy)),texture2D(shadowtex1,sp.xy).r)*exp2(-shadowDepth(p));
  #endif
}
float shadow2(vec3 p){
  vec3 sp = stransformcam(scam2clip(p))*.5+.5;
  sp.z-=.0001;
  #ifdef VOLUME_PCSS
  float d = cam2screen(p).z;
  return getSoftShadows(sp,max(getPenumbra(sp),1.41421356237/float(shadowMapResolution*MC_SHADOW_QUALITY)),d)*exp2(-shadowDepth(p));
  #else
  return step(sp.z,texture2D(shadowtex1,sp.xy).r)*exp2(-shadowDepth(p));
  #endif
}
float shadow3(vec3 p){
  vec3 sp = stransformcam(scam2clip(screen2cam(p)))*.5+.5;
  sp.z-=.0001;
  #ifdef PCSS
  return getSoftShadows(sp,max(getPenumbra(sp),1.41421356237/float(shadowMapResolution*MC_SHADOW_QUALITY)),p.z);
  #else
  return step(sp.z-shadow_offset*(SHADOW_BIAS+length8(sp.xy)),texture2D(shadowtex1,sp.xy).r);
  #endif
}
