const float bloomscale =2.;

vec3 loadpow(sampler2D s,vec2 tc){
  vec3 c = texture2D(s,bloomscale*tc).rgb;
  float i = dot(c,vec3(.33333333333333));
  return c*pow(i*1.3,2.5);
}

vec3 kawazePass(sampler2D s,vec2 tc,float i,vec2 res){
  vec2 ii = (i+.5)/res;

  vec3 c=texture2D(s,tc+ii).rgb;
  c+=texture2D(s,tc-ii).rgb;
  ii.x=-ii.x;
  c+=texture2D(s,tc+ii).rgb;
  c+=texture2D(s,tc-ii).rgb;

  return c*.25;
}


vec3 kawazePass1(sampler2D s,vec2 tc,float i,vec2 res){
  vec2 ii = (i+.5)/res;

  vec3 c=loadpow(s,tc+ii);
  c+=loadpow(s,tc-ii);
  ii.x=-ii.x;
  c+=loadpow(s,tc+ii);
  c+=loadpow(s,tc-ii);

  return c*.25;
}

vec3 kawazePassc(sampler2D s,vec2 tc,float i,vec2 res){
  vec2 ii = (i+.5)/res;

  vec3 c=texture2D(s,clamp(tc+ii,vec2(0.),res/3.)).rgb;
  c+=texture2D(s,clamp(tc-ii,vec2(0.),res/3.)).rgb;
  ii.x=-ii.x;
  c+=texture2D(s,clamp(tc+ii,vec2(0.),res/3.)).rgb;
  c+=texture2D(s,clamp(tc-ii,vec2(0.),res/3.)).rgb;

  return c*.25;
}

vec4 filterCloud(sampler2D s,vec2 tc,float i,vec2 res, sampler2D d){
  vec2 ii = (1.*i+.5)/res;
  const float treshhold = 1.;
  float a =1.;
  vec2 fc = fract(tc*2.);
  vec4 c = texture2D(s,tc);
  const float k = .75;

  if(min(min(fc.x,fc.y),1.-max(fc.x,fc.y))<.001*i)
    return c;
  if(treshhold<= texture2D(d,fract(2.*tc)).r ){
    fc = 2.*tc-fc;
    float dp = float(treshhold<= texture2D(d,fract(2.*(tc+ii))).r)*float(floor(2.*(tc+ii))==fc)*k;
    c+=texture2D(s,tc+ii)*dp;
    a+=dp;
    dp = float(treshhold<= texture2D(d,fract(2.*(tc-ii))).r)*float(floor(2.*(tc-ii))==fc)*k;
    c+=texture2D(s,tc-ii)*dp;
    a+=dp;
    ii.x=-ii.x;
    dp = float(treshhold<= texture2D(d,fract(2.*(tc+ii))).r)*float(floor(2.*(tc+ii))==fc)*k;
    c+=texture2D(s,tc+ii)*dp;
    a+=dp;
    dp = float(treshhold<= texture2D(d,fract(2.*(tc-ii))).r)*float(floor(2.*(tc-ii))==fc)*k;
    c+=texture2D(s,tc-ii)*dp;
    a+=dp;
  }
  return c/a;
}

vec4 filterCloudSh(sampler2D s,vec2 tc,float i,vec2 res){
  vec2 ii = (i+.5)/res;
  const float treshhold = .9;
  float a =0.;
float dp = float(floor(2.*(tc+ii))==floor(2.*(tc)));
  vec4 c=texture2D(s,tc+ii)*dp;
  a+=dp;
  dp = float(floor(2.*(tc-ii))==floor(2.*(tc)));
  c+=texture2D(s,tc-ii)*dp;
  a+=dp;
  ii.x=-ii.x;
  dp = float(floor(2.*(tc+ii))==floor(2.*(tc)));
  c+=texture2D(s,tc+ii)*dp;
  a+=dp;
  dp = float(floor(2.*(tc-ii))==floor(2.*(tc)));
  c+=texture2D(s,tc-ii)*dp;
  a+=dp;
  if (a<1.)
    return texture2D(s,tc);
  return c/a;
}
