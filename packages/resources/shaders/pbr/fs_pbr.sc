#define NEW_LIGHTING
#include "common/inputs.sh"

$input v_texcoord0 OUTPUT_WORLDPOS OUTPUT_NORMAL OUTPUT_TANGENT OUTPUT_LIGHTMAP_TEXCOORD OUTPUT_COLOR0

#include <bgfx_shader.sh>
#include <bgfx_compute.sh>
#include <shaderlib.sh>
#include "common/camera.sh"

#include "common/transform.sh"
#include "common/utils.sh"
#include "common/cluster_shading.sh"
#include "common/constants.sh"
#include "common/uvmotion.sh"
#include "pbr/lighting.sh"
#include "pbr/indirect_lighting.sh"
#include "pbr/pbr.sh"
#include "input_attributes.sh"

void main()
{
#include "attributes_getter.sh"

#ifdef MATERIAL_UNLIT
    gl_FragColor = input_attribs.basecolor + input_attribs.emissive;
#else //!MATERIAL_UNLIT
    material_info mi = init_material_info(input_attribs);

    vec3 color = calc_direct_light(input_attribs, mi);

#   ifdef ENABLE_IBL
    color += calc_indirect_light(input_attribs, mi);
#   endif //ENABLE_IBL
    gl_FragColor = vec4(color, input_attribs.basecolor.a) + input_attribs.emissive;
#endif //MATERIAL_UNLIT
}
