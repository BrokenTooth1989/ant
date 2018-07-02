$input v_normal, v_tangent, v_bitangent, v_tex0, v_pos

#include "common.sh"

SAMPLER2D(s_basecolor,  0);
SAMPLER2D(s_normal, 1);

uniform vec4 directional_lightdir[1];
uniform vec4 eyepos;

float fresnel(float _ndotl, float _bias, float _pow)
{
	float facing = (1.0 - _ndotl);
	return max(mix(pow(facing, _pow), 1, _bias), 0.0);
}

float specular_blinn(vec3 lightdir, vec3 normal, vec3 viewdir)
{
	vec3 half = normalize(lightdir + viewdir);

	float hdotn = dot(half, normal);	// Phong need check dot result, but Blinn-Phong not
	float shiness = 8.0;
	return pow(hdotn, shiness);
}

vec3 calc_directional_light(vec3 normal, vec3 lightdir, vec3 viewdir)
{
	float ndotl = dot(normal, lightdir);
	float diffuse = max(0.0, ndotl);
	//vec3 specular_color = vec3(1.0, 1.0, 1.0);
	float fres = fresnel(ndotl, 0.2, 5);	
	float specular = step(0, ndotl) * fres * specular_blinn(lightdir, normal, viewdir);

	return diffuse + specular;
}

void main()
{
	mat3 tbn = mat3(normalize(v_tangent),
					normalize(v_bitangent),
					normalize(v_normal));
	tbn = transpose(tbn);

	vec3 normal = normalize(texture2D(s_normal, v_tex0) * 2.0 - 1.0);
	//normal.z = sqrt(1.0 - dot(normal.xy, normal.xy) );

	vec4 color = toLinear(texture2D(s_basecolor, v_tex0) );

	vec3 lightdir = mul(directional_lightdir[0], tbn);
	vec3 viewdir = mul(normalize(eyepos - v_pos), tbn);

	gl_FragColor.xyz = calc_directional_light(normal, lightdir, viewdir) * color;
	gl_FragColor.w = 1.f;
}