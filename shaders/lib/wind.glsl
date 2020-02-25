vec3 wind (vec3 pos){
	float a =.15+.05*sin(frameTimeCounter*.05);
	vec3 dirp = vec3(1.,-.01,1.4)*.1;

  vec3 dird = cos(frameTimeCounter*vec3(.99635256,1.01524,.345)*.5-pos*.1);
	//vec3 dird = vec3(cos(frameTimeCounter*.1-pos.x),sin(frameTimeCounter*.120126-pos.y),.5*cos(frameTimeCounter*.378+.01-pos.z));

  float speed = 1.5;

  float phase = speed*frameTimeCounter+dot(pos,dirp);
  float pressure = (sin(phase)*(1.+rainStrength)+.5*sin(phase*2.3015)+.18*cos(phase*3.953))/1.78;

	return dird*pressure*pressure*a;
}
