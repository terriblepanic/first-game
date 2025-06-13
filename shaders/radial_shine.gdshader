shader_type canvas_item;

uniform float amplitude : hint_range(0., 1000. , 1.) = 100.;
uniform float frequency : hint_range(0., 1000. , 1.) = 8.;
uniform float light_magnitude : hint_range(0., 180. , 1.) = 30.;
uniform float color_spread : hint_range(0., 180. , 1.) = 0.3;
uniform float light_distance : hint_range(0., 1. , 0.01) = 0.09;

uniform float speed : hint_range(-1000., 1000. , 0.01) = 0.03;

uniform bool cut_angle = true;
uniform float angle : hint_range(0., 180. , 1.) = 120.;
uniform float yshift : hint_range(-1., 1. , 0.01) = -0.6;

float yget(float x,float fc1,float fc2,float fc3,float fc4,float tc1,float tc2,float tc3,float tc4,float amc1,float amc2,float amc3,float amc4,float addt) {

	float t = speed*(TIME*130.0) + addt;
	float y = sin(x * frequency);

	y += sin(x*frequency*fc1 + t*tc1)*amc1;
	y += sin(x*frequency*fc2 + t*tc2)*amc2;
	y += sin(x*frequency*fc3 + t*tc3)*amc3;
	y += sin(x*frequency*fc4 + t*tc4)*amc4;
	y *= amplitude/(amc1*amc2*amc3*amc4);

	return y;
}

void fragment(){

	vec2 st = (UV-0.5)*2.;
	float x = st.x;
	float y = st.y + yshift*2.;
	float d = 1. - distance(vec2(0.),vec2(x,y))*(1. - light_distance);
	
	float theta = atan(y,x);
	float aphla = (90. - angle*0.5)*PI/180.;

	if ((theta < -aphla) && (theta > -(PI - aphla)) || !cut_angle) {

		float sa = sin(atan(y,x) + PI*0.5);

 		float alpha_r = distance(vec2(0.),vec2(sa,yget(sa,1.30,1.72,2.221,3.1122,1.,1.121,0.437,4.,4.5,4.,5.,2.5,0.))/amplitude)*light_magnitude;
		float alpha_g = distance(vec2(0.),vec2(sa,yget(sa,1.31,1.72,2.221,3.1122,1.,1.121,0.437,4.269,4.5,4.,5.,2.5,color_spread))/amplitude)*light_magnitude;
		float alpha_b = distance(vec2(0.),vec2(sa,yget(sa,1.29,1.72,2.221,3.1122,1.,1.121,0.437,5.,4.5,4.,5.,2.5,-color_spread))/amplitude)*light_magnitude;

		COLOR = alpha_r*vec4(d,0.,0.,d) + alpha_g*vec4(0.,d,0.,d) + alpha_b*vec4(0.,0.,d,d);
		//out_color *= sin(atan(y,x));
	} else {
  
		COLOR = vec4(0.);
	}
}