local lm = require "luamake"

lm.BgfxDir = lm.AntDir.."/3rd/bgfx"
lm.BxDir = lm.AntDir.."/3rd/bx"
lm.BimgDir = lm.AntDir.."/3rd/bimg"

lm:conf {
    defines = "BGFX_CONFIG_DEBUG_UNIFORM=0",
}

lm:import(lm.AntDir.."/3rd/bgfx.luamake/use.lua")

lm:copy "copy_bgfx_shader" {
    inputs = {
        lm.BgfxDir .. "/src/bgfx_shader.sh",
        lm.BgfxDir .. "/src/bgfx_compute.sh",
        lm.BgfxDir .. "/examples/common/shaderlib.sh",
    },
    outputs = {
        lm.AntDir .. "/pkg/ant.resources/shaders/bgfx_shader.sh",
        lm.AntDir .. "/pkg/ant.resources/shaders/bgfx_compute.sh",
        lm.AntDir .. "/pkg/ant.resources/shaders/shaderlib.sh",
    }
}
