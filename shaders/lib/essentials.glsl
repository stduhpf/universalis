//matrices de bayer pour dithering uniforme

//de 0 a 1-1/n²
float bayer2(vec2 a){
    a = floor(a);
    return fract( dot(a, vec2(.5, a.y * .75)) );
}
#define bayer4(a)   (bayer2( .5*(a))*.25+bayer2(a))
#define bayer8(a)   (bayer4( .5*(a))*.25+bayer2(a))
#define bayer16(a)  (bayer8( .5*(a))*.25+bayer2(a))
#define bayer32(a)  (bayer16(.5*(a))*.25+bayer2(a))
#define bayer64(a)  (bayer32(.5*(a))*.25+bayer2(a))
#define bayer128(a) (bayer64(.5*(a))*.25+bayer2(a))

//de -0.5+1/2n² a 0.5-1/2n²
#define dither2(p)   (bayer2(  p)-.375      )
#define dither4(p)   (bayer4(  p)-.46875    )
#define dither8(p)   (bayer8(  p)-.4921875  )
#define dither16(p)  (bayer16( p)-.498046875)
#define dither32(p)  (bayer32( p)-.499511719)
#define dither64(p)  (bayer64( p)-.49987793 )
#define dither128(p) (bayer128(p)-.499969482)

//matrices rotation
mat2 rot(float a){
  float x,y;
  return mat2(x=cos(a),y=sin(a),-y,x);
}

//resolution
uniform float viewWidth;
uniform float viewHeight;
#define resolution vec2(viewWidth,viewHeight)

uniform float shadowWidth;

float saturate(float x){
  return clamp(x,0.,1.);
}
vec3 saturate3(vec3 x){
  return clamp(x,vec3(0),vec3(1));
}
//misc
float minp(float a,float b){
  return min(max(0.,a),max(0.,b));
}
float boxmin(vec2 tc,sampler2D t){
  float a = 0.;

  a=texture2D(t, tc).b;
  a=min(a,texture2D(t, tc+vec2(0,1.)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(0,-1.)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(1.,0)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(-1.,0)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(1.,1.)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(-1.,1.)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(1.,-1.)/resolution).b);
  a=min(a,texture2D(t, tc+vec2(-1.,-1.)/resolution).b);


  return a;
}
float boxmax(vec2 tc,sampler2D t){
  float a = 0.;
  float k=1.;
  a=texture2D(t, tc).b;
  a=max(a,texture2D(t, tc+k*vec2(0,1.)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(0,-1.)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(1.,0)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(-1.,0)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(1.,1.)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(-1.,1.)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(1.,-1.)/resolution).b);
  a=max(a,texture2D(t, tc+k*vec2(-1.,-1.)/resolution).b);


  return a;
}

float haltonSeq(int b, int i) {
    i=int(mod(i,256));
		float r = 0.;
    float f = 1.;
    while(i>0){
        r += (f/=float(b))*mod(i,b);
        i = i/b;
    }
    return r;
}

const float PI = 3.14159265359;
const float TAU = 6.28318530718;
