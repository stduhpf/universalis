vec4 nmp = gettex(normals,uv);
vec3 nm = nmp.rgb*2.-1.;
#if PBR_FORMAT ==labPBRv1_2
  vec2 tb = nm.xy;
  ao = nm.z*.5.5;
  n = vec3(tb,sqrt(1.-dot(tb,tb))); //test for 2 channels normals (is working fine)
#else
	ao = length(nm);
	n = (nm/ao);
	#ifndef AO_FIX
	 ao*=ao;
	#else
  	ao=sqrt(ao);
  	ao = saturate(ao);
	#endif
#endif
n=tbn*n;
