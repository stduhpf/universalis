uniform int frameCounter;
#define PCSS_ACCURACY 4     //[2 3 4 5 6] //Huge performance impact, little visual difference
#define sshradius .1/PCSS_ACCURACY    //radius in m*pixel/screenwidthh

#define PCSS_SAMPLES 8  //[1 2 4 8 12 16]
#define shadow_offset 0.0001
#define GA 2.39996322973

const mat2 Grot = mat2(cos(GA),sin(GA),-sin(GA),cos(GA));

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



float getSoftShadows(vec3 sp, float pen){
  float a = 0.;
  float dither = dither16(gl_FragCoord.xy);
  vec2 angle = vec2(0,pen/sqrt(float(PCSS_SAMPLES+1)));
  angle *= rot(dither*6.28318530718+sin(dither)*frameCounter);
  float r = 1.+fract(.5+dither+sin(dither)*frameTimeCounter);
  for(int i = 0;i<PCSS_SAMPLES;i++){
    r+=1./r;
    angle *= Grot;
    vec2 sc = (r-1.)*angle+sp.xy;
    float depth =(texture2D(shadowtex1,sc).r);
    a+= step(sp.z-shadow_offset*(SHADOW_BIAS+length8(sc)),depth);
  }
return a/float(PCSS_SAMPLES);
}

float shadow3(vec3 p){
  vec3 sp = stransformcam(scam2clip(p))*.5+.5;
  sp.z-=.0001;
  #ifdef PCSS
  return getSoftShadows(sp,max(getPenumbra(sp),1.41421356237/float(shadowMapResolution*MC_SHADOW_QUALITY)));
  #else
  return step(sp.z-shadow_offset*(SHADOW_BIAS+length8(sp.xy)),texture2D(shadowtex1,sp.xy).r);
  #endif
}
