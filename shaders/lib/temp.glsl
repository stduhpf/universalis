mat3 rgbToyCoCg = mat3(.25,.5,.25,.5,0.,-.5,-.25,.5,-.25);
mat3 yCoCgTorgb = mat3(1,1,-1,1,0,1,1,-1,-1);

vec3 neighborhoodClip(vec2 tc,vec3 previous,sampler2D current){
  previous = previous*rgbToyCoCg;
  vec2 ii = vec2(1)/resolution;
  vec3 aa = texture2D(current, tc+ii*vec2(-1)).rgb*rgbToyCoCg;
  vec3 ab = texture2D(current, tc+ii*vec2(-1,0)).rgb*rgbToyCoCg;
  vec3 ac = texture2D(current, tc+ii*vec2(-1,1)).rgb*rgbToyCoCg;
  vec3 ba = texture2D(current, tc+ii*vec2(0,-1)).rgb*rgbToyCoCg;
  vec3 bb = texture2D(current, tc+ii*vec2(0,0)).rgb*rgbToyCoCg;
  vec3 bc = texture2D(current, tc+ii*vec2(0,1)).rgb*rgbToyCoCg;
  vec3 ca = texture2D(current, tc+ii*vec2(1,-1)).rgb*rgbToyCoCg;
  vec3 cb = texture2D(current, tc+ii*vec2(1,0)).rgb*rgbToyCoCg;
  vec3 cc = texture2D(current, tc+ii*vec2(1)).rgb*rgbToyCoCg;

  float minY2=min(ab.x,min(ba.x,min(bb.x,min(bc.x,cb.x))));
  float maxY2=max(ab.x,max(ba.x,max(bb.x,max(bc.x,cb.x))));

  float minCo2=min(ab.y,min(ba.y,min(bb.y,min(bc.y,cb.y))));
  float maxCo2=max(ab.y,max(ba.y,max(bb.y,max(bc.y,cb.y))));

  float minCg2=min(ab.z,min(ba.z,min(bb.z,min(bc.z,cb.z))));
  float maxCg2=max(ab.z,max(ba.z,max(bb.z,max(bc.z,cb.z))));


  float minY=min(minY2,min(aa.x,min(ac.x,min(ca.x,cc.x))));
  float maxY=max(maxY2,max(aa.x,max(ac.x,max(ca.x,cc.x))));

  float minCo=min(minCo2,min(aa.y,min(ac.y,min(ca.y,cc.y))));
  float maxCo=max(maxCo2,max(aa.y,max(ac.y,max(ca.y,cc.y))));

  float minCg=min(minCg2,min(aa.z,min(ac.z,min(ca.z,cc.z))));
  float maxCg=max(maxCg2,max(aa.z,max(ac.z,max(ca.z,cc.z))));


  const float boxblend =.5;
  minY=mix(minY,minY2,boxblend);
  maxY=mix(maxY,maxY2,boxblend);
  float dY=(maxY-minY)*.5;

  minCo=mix(minCo,minCo2,boxblend);
  maxCo=mix(maxCo,maxCo2,boxblend);
  float dCo=(maxCo-minCo)*.5;

  minCg=mix(minCg,minCg2,boxblend);
  maxCg=mix(maxCg,maxCg2,boxblend);
  float dCg=(maxCg-minCg)*.5;

  vec3 med = .5*vec3(minY+maxY,minCo+maxCo,minCg+maxCg);

  vec3 delta = previous-med;
  vec3 proj = abs(vec3(dY,dCo,dCg)/delta);
  vec3 clip =min(min(min(proj.x,proj.y),proj.z),1.)*delta+med;
//  vec3 clam = vec3(clamp(previous.x,minY,maxY),clamp(previous.y,minCo,maxCo),clamp(previous.z,minCg,maxCg));

  return clip*yCoCgTorgb;
}

vec3 neighborhoodClamp(vec2 tc,vec3 previous,sampler2D current){
  previous = previous*rgbToyCoCg;
  vec2 ii = vec2(1)/resolution;
  vec3 aa = texture2D(current, tc+ii*vec2(-1)).rgb*rgbToyCoCg;
  vec3 ab = texture2D(current, tc+ii*vec2(-1,0)).rgb*rgbToyCoCg;
  vec3 ac = texture2D(current, tc+ii*vec2(-1,1)).rgb*rgbToyCoCg;
  vec3 ba = texture2D(current, tc+ii*vec2(0,-1)).rgb*rgbToyCoCg;
  vec3 bb = texture2D(current, tc+ii*vec2(0,0)).rgb*rgbToyCoCg;
  vec3 bc = texture2D(current, tc+ii*vec2(0,1)).rgb*rgbToyCoCg;
  vec3 ca = texture2D(current, tc+ii*vec2(1,-1)).rgb*rgbToyCoCg;
  vec3 cb = texture2D(current, tc+ii*vec2(1,0)).rgb*rgbToyCoCg;
  vec3 cc = texture2D(current, tc+ii*vec2(1)).rgb*rgbToyCoCg;

  float minY2=min(ab.x,min(ba.x,min(bb.x,min(bc.x,cb.x))));
  float maxY2=max(ab.x,max(ba.x,max(bb.x,max(bc.x,cb.x))));

  float minCo2=min(ab.y,min(ba.y,min(bb.y,min(bc.y,cb.y))));
  float maxCo2=max(ab.y,max(ba.y,max(bb.y,max(bc.y,cb.y))));

  float minCg2=min(ab.z,min(ba.z,min(bb.z,min(bc.z,cb.z))));
  float maxCg2=max(ab.z,max(ba.z,max(bb.z,max(bc.z,cb.z))));


  float minY=min(minY2,min(aa.x,min(ac.x,min(ca.x,cc.x))));
  float maxY=max(maxY2,max(aa.x,max(ac.x,max(ca.x,cc.x))));

  float minCo=min(minCo2,min(aa.y,min(ac.y,min(ca.y,cc.y))));
  float maxCo=max(maxCo2,max(aa.y,max(ac.y,max(ca.y,cc.y))));

  float minCg=min(minCg2,min(aa.z,min(ac.z,min(ca.z,cc.z))));
  float maxCg=max(maxCg2,max(aa.z,max(ac.z,max(ca.z,cc.z))));


  minY=(minY+minY2)*.5;
  maxY=(maxY+maxY2)*.5;
  float dY=(maxY-minY)*.5;

  minCo=(minCo+minCo2)*.5;
  maxCo=(maxCo+maxCo2)*.5;
  float dCo=(maxCo-minCo)*.5;

  minCg=(minCg+minCg2)*.5;
  maxCg=(maxCg+maxCg2)*.5;
  float dCg=(maxCg-minCg)*.5;

  vec3 med = .5*vec3(minY+maxY,minCo+maxCo,minCg+maxCg);

  vec3 delta = previous-med;
  vec3 proj = abs(vec3(dY,dCo,dCg)/delta);
  //vec3 clip =min(min(min(proj.x,proj.y),proj.z),1.)*delta+med;
  vec3 clam = vec3(clamp(previous.x,minY,maxY),clamp(previous.y,minCo,maxCo),clamp(previous.z,minCg,maxCg));

  return clam*yCoCgTorgb;
}
