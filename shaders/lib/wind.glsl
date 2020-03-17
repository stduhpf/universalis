vec3 wind (vec3 pos){
	vec3 dirp = vec3(1.,-.01,1.4)*.2;

  vec3 dird = cos(frameTimeCounter*vec3(.99635256,1.01524,.345)*.5-pos*.1);
	//vec3 dird = vec3(cos(frameTimeCounter*.1-pos.x),sin(frameTimeCounter*.120126-pos.y),.5*cos(frameTimeCounter*.378+.01-pos.z));

  float speed = 1.5;

  float phase = speed*frameTimeCounter+dot(pos,dirp);
	float a=.15+.05*sin(frameTimeCounter+phase*.2)+.05*rainStrength;

  float pressure = (sin(phase)*(1.+rainStrength)+.5*sin(phase*2.3015)+.18*cos(phase*3.953))/1.78;

	phase = speed*frameTimeCounter+2.*dot(pos,dirp.xzy);
	pressure = mix(pressure,(sin(phase)*(1.+rainStrength)+.5*sin(phase*2.3015)+.18*cos(phase*3.953))/1.78,.25);
	return dird*pressure*pressure*a;
}
