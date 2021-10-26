local ecs   = ...
local world = ecs.world
local w     = world.w

local renderpkg = import_package "ant.render"
local declmgr   = renderpkg.declmgr

local fs        = require "filesystem"
local datalist  = require "datalist"
local bgfx      = require "bgfx"

local imesh     = ecs.import.interface "ant.asset|imesh"

local quad_ts = ecs.system "shape_terrain_system"

local function read_terrain_field(tf)
    if type(tf) == "string" then
        return datalist.parse(fs.open(fs.path(tf)):read "a")
    end

    return tf
end

local function is_power_of_2(n)
	if n ~= 0 then
		local l = math.log(n, 2)
		return math.ceil(l) == math.floor(l)
	end
end

local layout_name<const>    = declmgr.correct_layout "p4|n3|T3|c40niu|t20"
local layout                = declmgr.get(layout_name)
local memfmt<const>         = declmgr.vertex_desc_str(layout_name)

local function add_cube(vb, origin, extent, color)
    local ox, oy, oz = origin[1], origin[2], origin[3]
    local nx, ny, nz = ox+extent[1], oy+extent[2], oz+extent[3]
    
    --TODO: compress this data:
    --  x, y, z for int16
    --  uv for int16/int8?
    --  remove normal/tangent, calculate normal and tangent by gl_VertexID, but we need the ib back
    --    or use int8 for normal/tangent, or some kind of value to point out which face the vertex belong to
    --  write color to texture and fetch from vs
    -- local v = {
    --     ox, oy, oz, color, 1.0, 0.0,
    --     ox, oy, nz, color, 1.0, 1.0,
    --     nx, oy, nz, color, 0.0, 1.0,
    --     nx, oy, oz, color, 0.0, 0.0,
    --     ox, ny, oz, color, 0.0, 0.0,
    --     ox, ny, nz, color, 0.0, 1.0,
    --     nx, ny, nz, color, 1.0, 1.0,
    --     nx, ny, oz, color, 1.0, 0.0,
    -- }

    -- 6 face, 4 vertices pre face, bottom face can omitted?
    local v = {
        --bottom
        ox, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0, --3
        nx, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0, --2
        nx, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0, --1
        ox, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0, --0

        --top
        ox, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0, --4
        ox, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0, --5
        nx, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0, --6
        nx, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0, --7

        --left
        nx, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0, --1
        ox, ny, nz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0, --5
        ox, ny, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0, --4
        ox, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0, --0

        --right
        ox, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0, --3
        nx, ny, oz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0, --7
        nx, ny, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0, --6
        nx, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0, --2

        --front
        ox, oy, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0, --0
        ox, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0, --4
        nx, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0, --7
        ox, oy, nz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0, --3

        --back
        nx, oy, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0, --2
        nx, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0, --6
        ox, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0, --5
        nx, oy, oz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0, --1
    }

    assert(#memfmt * 6 * 4 == #v)
    table.move(v, 1, #v, #vb+1, vb)
end

local packfmt<const> = "fffffffffIff"
local function add_cube2(vb, origin, extent, color)
    local ox, oy, oz = table.unpack(origin)
    local nx, ny, nz = ox+extent[1], oy+extent[2], oz+extent[3]
    local v = {
        packfmt:pack(ox, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0), --3
        packfmt:pack(nx, oy, nz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0), --2
        packfmt:pack(nx, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0), --1
        packfmt:pack(ox, oy, oz,  0.0, -1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0), --0

        --top
        packfmt:pack(ox, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 0.0), --4
        packfmt:pack(ox, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 0.0, 1.0), --5
        packfmt:pack(nx, ny, nz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 1.0), --6
        packfmt:pack(nx, ny, oz,  0.0,  1.0,  0.0,  1.0,  0.0,  0.0, color, 1.0, 0.0), --7

        --left
        packfmt:pack(nx, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --1
        packfmt:pack(ox, ny, nz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --5
        packfmt:pack(ox, ny, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --4
        packfmt:pack(ox, oy, oz, -1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --0

        --right
        packfmt:pack(ox, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --3
        packfmt:pack(nx, ny, oz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --7
        packfmt:pack(nx, ny, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --6
        packfmt:pack(nx, oy, nz,  1.0,  0.0,  0.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --2

        --front
        packfmt:pack(ox, oy, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --0
        packfmt:pack(ox, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --4
        packfmt:pack(nx, ny, oz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --7
        packfmt:pack(ox, oy, nz,  0.0,  0.0, -1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --3

        --back
        packfmt:pack(nx, oy, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 0.0), --2
        packfmt:pack(nx, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 0.0, 1.0), --6
        packfmt:pack(ox, ny, nz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 1.0), --5
        packfmt:pack(nx, oy, oz,  0.0,  0.0,  1.0,  0.0,  1.0,  0.0, color, 1.0, 0.0), --1
    }

    vb[#vb+1] = table.concat(v, "")
end

--[[
     5-------6
    /       /|
   /       / |
  4-------7  2
  |       |  /
  |       | /
  0-------3
]]

local default_quad_ib<const> = {
    0, 1, 2,
    2, 3, 0,
}

local function add_quad_ib(ib, offset)
    for i=1, #default_quad_ib do
        ib[#ib+1] = default_quad_ib[i] + offset
    end
end

local default_cube_ib = {}
for i=0, 5 do
    add_quad_ib(default_cube_ib, 4*i)
end

--build ib
local cubeib_handle
do
    local cubeib = {}
    for i=1, #default_cube_ib do
        cubeib[i] = default_cube_ib[i]
    end
    local fmt<const> = ('I'):rep(36)
    local offset<const> = 24

    local s = #fmt
    local m = bgfx.memory_buffer(s*256*256*4)
    local ib = {}
    for i=1, 256*256 do
        local mo = s*(i-1)+1
        m[mo] = fmt:pack(table.unpack(cubeib))
        --offset, 6 * 4 = 24
        for ii=1, #cubeib do
            cubeib[ii]  = cubeib[ii] + offset
        end
    end
    cubeib_handle = bgfx.create_index_buffer(m, "d")
end

local function add_cube_ib(ib, offset)
    for i=1, #default_cube_ib do
        ib[#ib+1] = default_cube_ib[i] + offset
    end
end

local function add_quad(vb, offset, color, unit)
    local x, y, z = offset[1], 0.0, offset[2]
    local nx, nz = x+unit, z+unit
    local v = {
        x, y,    z, color, 0.0, 0.0,
        x, y,   nz, color, 0.0, 1.0,
       nx, y,   nz, color, 1.0, 1.0,
       nx, y,    z, color, 1.0, 0.0,
    }

    table.move(v, 1, #v, #vb+1, vb)
end

local function to_mesh_buffer(vb)
    local vbbin = table.concat(vb, "")
    local numv = #vbbin // #memfmt
    local numi = (numv // 4) * 6
    return {
        vb = {
            start = 0,
            num = numv,
            {
                handle = bgfx.create_vertex_buffer(bgfx.memory_buffer(vbbin), layout.handle),
            }
        },
        ib = {
            start = 0,
            num = numi,
            handle = cubeib_handle,
        }
    }
end

local function build_section_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            if field.type == "grass" or field.type == "dust" then
                local colors<const> = {
                    grass   = 0xff00ff00,
                    dust    = 0xff00ffff,
                }
                local iboffset = #vb // #memfmt
                local x, z = cterrainfileds:get_offset(sectionidx)
                local h = field.height or 0
                local origin = {(iw-1+x)*unit, 0.0, (ih-1+z)*unit}
                local extent = {unit, h*unit, unit}
                add_cube2(vb, origin, extent, colors[field.type])
            end
        end
    end

    if #vb > 0 then
        return to_mesh_buffer(vb)
    end
end

local function build_section_edge_mesh(sectionsize, sectionidx, unit, cterrainfileds)
    local vb = {}
    for ih=1, sectionsize do
        for iw=1, sectionsize do
            local field = cterrainfileds:get_field(sectionidx, iw, ih)
            local color = cterrainfileds.edge_color or 0xffe5e5e5
            local edges = field.edges
            if edges then
                for k, edge in pairs(edges) do
                    add_cube2(vb, edge.origin, edge.extent, color)
                end
            end
        end
    end

    if #vb > 0 then
        return to_mesh_buffer(vb)
    end
end

local cterrain_fields = {}

function cterrain_fields.new(st)
    return setmetatable(st, {__index=cterrain_fields})
end

--[[
    field:
        type: [none, grass, dust]
        height: 0.0
        edge = {
            color:
            thickness:
            types: {left, right, top, bottom}
        }
]]
function cterrain_fields:get_field(sidx, iw, ih)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width

    local offset = (ish * self.section_size+ih-1) * self.width +
                    isw * self.section_size + iw

    return self.terrain_fields[offset]
end

function cterrain_fields:get_offset(sidx)
    local ish = (sidx-1) // self.section_width
    local isw = (sidx-1) % self.section_width
    return isw * self.section_size, ish * self.section_size
end

function cterrain_fields:build_edges()
    local tf = self.terrain_fields
    local w, h = self.width, self.height
    local unit = self.unit
    local thickness = self.edge_thickness * unit
    
    for ih=1, h do
        for iw=1, w do
            local idx = (ih-1)*w+iw
            local f = tf[idx]
            local hh = f.height * 1.05 * unit
            if f.type ~= "none" then
                local function is_empty_elem(iiw, iih)
                    if iiw == 0 or iih == 0 or iiw == w+1 or iih == h+1 then
                        return true
                    end

                    local iidx = (iih-1)*w+iiw
                    return assert(tf[iidx]).type == "none"
                end
                local edges = {}
                if is_empty_elem(iw-1, ih) then
                    local len = unit + 2 * thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw-1, ih+1) then
                        len = len - thickness
                    end
                    if not is_empty_elem(iw-1, ih-1) then
                        len = len - thickness
                        origin[3] = origin[3] + thickness
                    end
                    edges.left = {
                        origin = origin,
                        extent = {thickness, hh, len},
                    }
                end

                if is_empty_elem(iw+1, ih) then
                    local len = unit+2*thickness
                    local origin = {iw*unit, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw+1, ih+1) then
                        len = len - thickness
                    end
                    if not is_empty_elem(iw+1, ih-1) then
                        len = len - thickness
                        origin[3] = origin[3] + thickness 
                    end
                    edges.right = {
                        origin = origin,
                        extent = {thickness, hh, len}
                    }
                end

                --top
                if is_empty_elem(iw, ih+1) then
                    local len = unit+2*thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, ih*unit}
                    if not is_empty_elem(iw-1, ih+1) then
                        len = len - thickness
                        origin[1] = origin[1] + thickness 
                    end
                    if not is_empty_elem(iw+1, ih+1) then
                        len = len - thickness
                    end
                    edges.top = {
                        origin = origin,
                        extent = {len, hh, thickness}
                    }
                end
                if is_empty_elem(iw, ih-1) then
                    local len = unit+2*thickness
                    local origin = {(iw-1)*unit-thickness, 0.0, (ih-1)*unit-thickness}
                    if not is_empty_elem(iw-1, ih-1) then
                        len = len - thickness
                        origin[1] = origin[1] + thickness 
                    end
                    if not is_empty_elem(iw+1, ih-1) then
                        len = len - thickness
                    end
                    edges.bottom = {
                        origin = origin,
                        extent = {len, hh, thickness}
                    }
                end

                f.edges = edges
            end
        end
    end
end

function quad_ts:entity_init()
    for e in w:select "INIT shape_terrain:in material:in reference:in" do
        local st = e.shape_terrain

        if st.terrain_fields == nil then
            error "need define terrain_field, it should be file or table"
        end
        st.terrain_fields = read_terrain_field(st.terrain_fields)

        local width, height = st.width, st.height
        if width * height ~= #st.terrain_fields then
            error(("height_fields data is not equal 'width' and 'height':%d, %d"):format(width, height))
        end

        if not (is_power_of_2(width) and is_power_of_2(height)) then
            error(("one of the 'width' or 'heigth' is not power of 2"):format(width, height))
        end

        local ss = st.section_size
        if not is_power_of_2(ss) then
            error(("'section_size':%d, is not power of 2"):format(ss))
        end

        if ss == 0 or ss > width or ss > height then
            error(("invalid 'section_size':%d, larger than 'width' or 'height' or it is 0: %d, %d"):format(ss, width, height))
        end

        st.section_width, st.section_height = width // ss, height // ss
        st.num_section = st.section_width * st.section_height

        local unit = st.unit
        st.edge_thickness = unit * 0.15

        local material = e.material

        local ctf = cterrain_fields.new(st)
        ctf:build_edges()

        for ih=1, st.section_height do
            for iw=1, st.section_width do
                local sectionidx = (ih-1) * st.section_width+iw
                
                local terrain_mesh = build_section_mesh(ss, sectionidx, unit, ctf)
                if terrain_mesh then
                    local ce = ecs.create_entity{
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                            "ant.general|name",
                        },
                        data = {
                            scene = {
                                srt = {}
                            },
                            reference   = true,
                            simplemesh  = imesh.init_mesh(terrain_mesh),
                            material    = material,
                            state       = "visible|selectable",
                            name        = "section" .. sectionidx,
                            shape_terrain_drawer = true,
                        }
                    }

                    ecs.method.set_parent(ce, e.reference)
                end

                local edge_meshes = build_section_edge_mesh(ss, sectionidx, unit, ctf)
                if edge_meshes then
                    local ce = ecs.create_entity {
                        policy = {
                            "ant.scene|scene_object",
                            "ant.render|simplerender",
                            "ant.general|name",
                        },
                        data = {
                            scene = {
                                srt = {}
                            },
                            reference   = true,
                            material    = material,
                            simplemesh  = imesh.init_mesh(edge_meshes),
                            state       = "visible|selectable",
                            name        = "section_edge" .. sectionidx,
                            shape_terrain_edge_drawer = true,
                        }
                    }
                    ecs.method.set_parent(ce, e.reference)
                end
            end
        end
    end
end