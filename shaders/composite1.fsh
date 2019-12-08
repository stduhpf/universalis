#version 420
#include "lib/essentials.glsl"
#include "lib/bloom.glsl"
#include "lib/trans.glsl"
#include "lib/sky.glsl"

varying vec2 tc;
uniform sampler2D colortex1;
uniform sampler2D colortex0;
uniform sampler2D depthtex1;
uniform sampler2D colortex2;

uniform int frameCounter;
float hash(float seed) {
    return fract(sin(seed)*43758.5453123);
}

/*DRAWBUFFERS:10*/
void main(){
  vec4 color  = texture2D(colortex0,tc);
  gl_FragData[1] = color;
  if(texture2D(depthtex1,tc).r>=1.){
    gl_FragData[1].rgb = mix(getSky3(normalize(screen2cam(vec3(tc,1.))))*.5,color.rgb,texture2D(colortex1,tc*.5+.5).b);
  }
  if(floor(2.*tc)==vec2(1)){
  gl_FragData[0]=filterCloud(colortex1,tc,1.,resolution,depthtex1);
  }
  else{
    if(floor(2.*tc)==vec2(1,0.)){
    gl_FragData[0]=filterCloudSh(colortex1,tc,1.,resolution);
    }else{
      if(floor(2.*tc)==vec2(0.)){

            const float kernel[3] = float[](9./64., 3./32., 1./16.);
            vec3 sum =  vec3(0);
            float cum_w = 0.0;
            float c_phi = 5.0;
            float n_phi = 0.5;


            vec3 cval = texture2D(colortex1, tc).xyz;
            vec3 nval = texture2D(colortex2, tc).xyz;

            float ang = 2.0*3.1415926535*hash(2510.12860182*tc.x + 7290.9126812*tc.y+5.1839513*frameCounter);
            mat2 m = mat2(cos(ang),sin(ang),-sin(ang),cos(ang));
            float denoiseStrength = (2. + 3.*hash(6410.128752*tc.x + 3120.321374*tc.y+1.92357812*frameCounter));
            for(int i=-1; i<2; i++){
              for(int j=-1; j<2; j++){
                  vec2 uv = (tc+m*(vec2(i,j)* denoiseStrength)/resolution.xy);

                  vec3 ctmp = texture2D(colortex1, uv).xyz;
                  vec3 t = cval - ctmp;
                  float dist2 = dot(t,t);
                  float c_w = min(exp(-(dist2)/c_phi), 1.0);

                  vec3 ntmp = texture2D(colortex2, uv*2.).xyz;
                  t = nval - ntmp;
                  dist2 = max(dot(t,t), 0.0);
                  float n_w = min(exp(-(dist2)/n_phi), 1.0);

                  int kerk = int(abs(i)+abs(j));

                  float weight0 = c_w*n_w;
                  sum += ctmp*weight0*kernel[kerk];
                  cum_w += weight0*kernel[kerk];
                }
              }
        gl_FragData[0]=vec4(sum/cum_w,1.);
      }else{
      gl_FragData[0]=texture2D(colortex1,tc);
    }
    }
  }

}
