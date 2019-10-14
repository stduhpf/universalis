uniform vec3 shadowLightPosition;
uniform vec3 sunPosition;
uniform vec3 moonPosition;


//based on robobo1221's code

const vec3 rayleighCoeff = vec3(0.27, 0.5, .9);

#define pi 3.14159265359

#define SUN_BRIGHNESS 5. //[1. 2. 5. 10. 20. 30.]
#define MOON_BRIGHNESS 1. //[.25 .5 1. 2. 5. 10. 20. 30.]

vec3 totalCoeff = rayleighCoeff;

vec3 scatter(vec3 coeff, float depth){
	return coeff * depth;
}

vec3 absorb(vec3 coeff, float depth){
	return exp2(-(coeff*depth));
}

float calcParticleThickness(float depth){
  depth = max(depth + 0.01, 0.01);
  depth = depth * depth * (3.0 - 2.0 * depth);
  depth = 1.0 / depth;

  return .5 * depth;
}

float rayleighPhase(vec3 p, vec3 lp){
  return 0.375 * (1.0 + pow(1.0 - distance(p, lp), 2.0));
}
vec3 calcAtmosphericScattersky(vec3 p, vec3 lp){
  const float ln2 = log(2.0)/log(2.718281828);

  float opticalDepth = calcParticleThickness(p.y);
  float opticalDepthLight = calcParticleThickness(lp.y);

  vec3 scatterView = totalCoeff*opticalDepth;
  vec3 absorbView = exp2(-scatterView);

  vec3 scatterLight = totalCoeff* opticalDepthLight;
  vec3 absorbLight =  exp2(-scatterLight);

  vec3 absorbSun = abs(absorbLight - absorbView) / abs((scatterLight - scatterView) * ln2);
  vec3 scatterSun = smoothstep(-.5, .3, p.y)*.5*scatterView * rayleighPhase(p, lp);


  return (scatterSun * absorbSun ) * pi;
}
vec4 calcAtmosphericScatter(vec3 p, vec3 lp, float rough){

  float opticalDepth = calcParticleThickness(p.y);

  vec3 scatterView = totalCoeff*opticalDepth;
  vec3 absorbView = exp2(-scatterView);

  vec3 sunSpot = SUN_BRIGHNESS*smoothstep(0.07, 0.01, distance(p, lp)) * absorbView;//alerte au gogole

  return vec4(calcAtmosphericScattersky( p, lp) +sunSpot * pi,.5*distance(p, lp));
}


vec3 getsuncol(vec3 p){
	float opticalDepth = calcParticleThickness(p.y);

	vec3 scatterView = totalCoeff*opticalDepth;
	vec3 absorbView = exp2(-scatterView);
	if(sunPosition==shadowLightPosition)
	return SUN_BRIGHNESS*absorbView;
	return MOON_BRIGHNESS*absorbView;
}

vec4 calcAtmosphericScatter2(vec3 p, vec3 lp, float rough){

  float opticalDepth = calcParticleThickness(p.y);

  vec3 scatterView = totalCoeff*opticalDepth;
  vec3 absorbView = exp2(-scatterView);

  vec3 moonSpot = MOON_BRIGHNESS*smoothstep(0.06, 0.01, distance(p, lp)) * absorbView * pi;

  return vec4(.01*calcAtmosphericScattersky( p, lp) +moonSpot * pi,.2*distance(p, lp));
}

vec3 hashstar(vec3 p)
{
    p = fract(p * vec3(443.8975,397.2973, 491.1871));
    p += dot(p.zxy, p.yxz+19.27);
    return fract(vec3(p.x * p.y, p.z*p.x, p.y*p.z));
}

vec3 stars(in vec3 p)
{
    vec3 c = vec3(0.);
    float res = resolution.y;

	for (float i=0.;i<4.;i++)
    {
        vec3 q = fract(p*(.15*res))-0.5;
        vec3 id = floor(p*(.15*res));
        vec2 rn = hashstar(id).xy;
        float c2 = 1.-smoothstep(0.,.6,length(q));
        c2 *= step(rn.x,.0005+i*i*0.001);
        c += c2*(mix(vec3(1.0,0.49,0.1),vec3(0.75,0.9,1.),rn.y)*0.1+0.9);
        p *= 1.3;
    }
    return c*c;
}



vec3 getSky(vec3 p, float rough){
	vec3 c = stars(p);
	vec3 lp = normalize(camdir(sunPosition));
	vec4 sunSky = max(vec4(0.),calcAtmosphericScatter( p, lp,rough));
	lp = normalize(camdir(moonPosition));
	vec4 nightSky = max(vec4(0.),calcAtmosphericScatter2( p, lp,rough));
	vec4 c2 = (sunSky+nightSky);
	c=c2.rgb+c*saturate(.25*c2.a);
	return c*.5;
}
vec3 getSky2(vec3 p){
	vec3 c = stars(p);
	vec3 lp = normalize(camdir(sunPosition));
	vec4 sunSky = max(vec4(0.), vec4(calcAtmosphericScattersky( p, lp) ,.5*distance(p, lp)));
	lp = normalize(camdir(moonPosition));
	vec4 nightSky = max(vec4(0.),vec4(.01*calcAtmosphericScattersky( p, lp),.2*distance(p, lp)));
	vec4 c2 = (sunSky+nightSky);
	c=c2.rgb+c*saturate(.25*c2.a);
	return c*.5;
}
vec3 getSky3(vec3 p){
	vec3 c = vec3(0);
	vec3 lp = normalize(camdir(sunPosition));
	vec4 sunSky = max(vec4(0.), vec4(calcAtmosphericScattersky( p, lp) ,.5*distance(p, lp)));
	lp = normalize(camdir(moonPosition));
	vec4 nightSky = max(vec4(0.),vec4(.01*calcAtmosphericScattersky( p, lp),.2*distance(p, lp)));
	vec4 c2 = (sunSky+nightSky);
	c=c2.rgb+c*saturate(.25*c2.a);
	return c*.5;
}
