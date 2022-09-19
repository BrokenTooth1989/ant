#include <core/Core.h>
#include <core/Interface.h>
#include <core/Document.h>
#include <core/Stream.h>
#include <core/Event.h>
#include <core/EventListener.h>
#include <binding/luaplugin.h>
#include <binding/luabind.h>

extern "C" {
#include <lua.h>
#include "lauxlib.h"
#include "lualib.h"
}


std::unordered_map<uint8_t, uint8_t> ctoh{
    {'0',0x00},
    {'1',0x01},
    {'2',0x02},
    {'3',0x03},
    {'4',0x04},
    {'5',0x05},
    {'6',0x06},
    {'7',0x07},
    {'8',0x08},
    {'9',0x09},
    {'a',0x0a},
    {'b',0x0b},
    {'c',0x0c},
    {'d',0x0d},
    {'e',0x0e},
    {'f',0x0f},
};

class lua_plugin;

class LuaEventListener final : public Rml::EventListener {
public:
	LuaEventListener(lua_plugin* p, Rml::Element* element, const std::string& type, const std::string& code, bool use_capture);
	~LuaEventListener();
private:
	void ProcessEvent(Rml::Event& event) override;
	lua_plugin *plugin;
	int id;
};

static int ref_function(luaref reference, lua_State* L, const char* funcname) {
	if (lua_getfield(L, -1, funcname) != LUA_TFUNCTION) {
		luaL_error(L, "Missing %s", funcname);
	}
	return luaref_ref(reference, L);
}

lua_plugin::lua_plugin(lua_State* L) {
	register_event(L);
	Rml::SetPlugin(this);
}

lua_plugin::~lua_plugin() {
	luaref_close(reference);
}

Rml::EventListener* lua_plugin::OnCreateEventListener(Rml::Element* element, const std::string& type, const std::string& code, bool use_capture) {
	return new LuaEventListener(this, element, type, code, use_capture);
}

void lua_plugin::OnLoadInlineScript(Rml::Document* document, const std::string& content, const std::string& source_path, int source_line) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, content.data(), content.size());
		lua_pushlstring(L, source_path.data(), source_path.size());
		lua_pushinteger(L, source_line);
		call(L, LuaEvent::OnLoadInlineScript, 4);
	});
}

void lua_plugin::OnLoadExternalScript(Rml::Document* document, const std::string& source_path) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlstring(L, source_path.data(), source_path.size());
		call(L, LuaEvent::OnLoadExternalScript, 2);
	});
}

void lua_plugin::OnCreateElement(Rml::Document* document, Rml::Element* element, const std::string& tag) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, tag.data(), tag.size());
		call(L, LuaEvent::OnCreateElement, 3);
	});
}

void lua_plugin::OnDestroyNode(Rml::Document* document, Rml::Node* node) {
	luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)node);
		call(L, LuaEvent::OnDestroyNode, 2);
	});
}

std::string lua_plugin::OnRealPath(const std::string& path) {
    std::string res;
    luabind::invoke([&](lua_State* L) {
        lua_pushlstring(L, path.data(), path.size());
        call(L, LuaEvent::OnRealPath, 1, 1);
        if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
            res.assign(str, sz);
        }
    });
    return res;
}

void lua_plugin::OnLoadTexture(Rml::Document* document, Rml::Element* element, const std::string& path) {
    luabind::invoke([&](lua_State* L) {
		lua_pushlightuserdata(L, (void*)document);
		lua_pushlightuserdata(L, (void*)element);
        lua_pushlstring(L, path.data(), path.size());
        call(L, LuaEvent::OnLoadTexture, 3, 0);
    });
}

void lua_plugin::OnParseText(const std::string& str,std::vector<Rml::group>& groups,std::vector<int>& groupMap,std::string& ctext,Rml::group& default_group) {
    luabind::invoke([&](lua_State* L) {
        lua_pushstring(L, str.data());
		call(L, LuaEvent::OnParseText, 1, 3);

		//-1 -2 -3 - groupmap groups ctext
		lua_pushnil(L);//-1 -2 - nil groupmap
		while(lua_next(L,-2)){//-1 -2 idx groupmap
			groupMap.emplace_back((int)lua_tointeger(L,-1)-1);
			lua_pop(L,1);
		}

		lua_pop(L,1);

		lua_pushnil(L);
		while(lua_next(L,-2)){
			Rml::group group;
			lua_getfield(L,-1,"color");
			size_t sz=0;
			const char* s = lua_tolstring(L, -1, &sz);
			std::string str(s,sz);
			if(str=="default"){
				group.color=default_group.color;
			}
			else{
				Rml::Color c;
				std::string ctmp(str);
				c.r=ctoh[ctmp[0]]*16+ctoh[ctmp[1]];
				c.g=ctoh[ctmp[2]]*16+ctoh[ctmp[3]];
				c.b=ctoh[ctmp[4]]*16+ctoh[ctmp[5]];
				group.color=c;
			}
			lua_pop(L,1);
			lua_pop(L,1);
			groups.emplace_back(group);
		}

		lua_pop(L,1);

		if (lua_type(L, -1) == LUA_TSTRING) {
            size_t sz = 0;
            const char* str = lua_tolstring(L, -1, &sz);
			std::string ctmp(str);
            ctext=str;
		}	
    });

	//TODO
}

void lua_plugin::register_event(lua_State* L) {
	luaL_checktype(L, 1, LUA_TTABLE);
	lua_settop(L, 1);
	lua_getfield(L, 1, "callback");
	lua_remove(L, 1);
	luaL_checktype(L, 1, LUA_TTABLE);
	reference = luaref_init(L);
	ref_function(reference, L, "OnLoadInlineScript");
	ref_function(reference, L, "OnLoadExternalScript");
	ref_function(reference, L, "OnCreateElement");
	ref_function(reference, L, "OnDestroyNode");
	ref_function(reference, L, "OnEvent");
	ref_function(reference, L, "OnEventAttach");
	ref_function(reference, L, "OnEventDetach");
	ref_function(reference, L, "OnRealPath");
	ref_function(reference, L, "OnLoadTexture");
	ref_function(reference, L, "OnParseText");
}

int  lua_plugin::ref(lua_State* L) {
	return luaref_ref(reference, L);
}

void lua_plugin::unref(int ref) {
	luaref_unref(reference, ref);
}

void lua_plugin::callref(lua_State* L, int ref, size_t argn, size_t retn) {
	luaref_get(reference, L, ref);
	lua_insert(L, -1 - (int)argn);
	lua_call(L, (int)argn, (int)retn);
}

void lua_plugin::call(lua_State* L, LuaEvent eid, size_t argn, size_t retn) {
	callref(L, (int)eid, argn, retn);
}

void lua_plugin::pushevent(lua_State* L, const Rml::Event& event) {
	luaref_get(reference, L, event.GetParameters());
	luaL_checktype(L, -1, LUA_TTABLE);
	lua_pushstring(L, event.GetType().c_str());
	lua_setfield(L, -2, "type");
	Rml::Element* target = event.GetTargetElement();
	target? lua_pushlightuserdata(L, target): lua_pushnil(L);
	lua_setfield(L, -2, "target");
	Rml::Element* current = event.GetCurrentElement();
	current ? lua_pushlightuserdata(L, current) : lua_pushnil(L);
	lua_setfield(L, -2, "current");
}

LuaEventListener::LuaEventListener(lua_plugin* p, Rml::Element* element, const std::string& type, const std::string& code, bool use_capture)
	: Rml::EventListener(type, use_capture)
	, plugin(p)
	, id(0)
	{
	luabind::invoke([&](lua_State* L) {
		Rml::Document* doc = element->GetOwnerDocument();
		lua_pushlightuserdata(L, (void*)doc);
		lua_pushlightuserdata(L, (void*)element);
		lua_pushlstring(L, code.c_str(), code.length());
		plugin->call(L, LuaEvent::OnEventAttach, 3, 1);
        if (lua_type(L, -1) == LUA_TNUMBER) {
            id = (int)luaL_checkinteger(L, -1);
        }
	});
	
}

LuaEventListener::~LuaEventListener() {
	if (!id) {
		return;
	}
	luabind::invoke([&](lua_State* L) {
		lua_pushinteger(L, id);
		plugin->call(L, LuaEvent::OnEventDetach, 1);
	});
}

void LuaEventListener::ProcessEvent(Rml::Event& event) {
	if (!id) {
		return;
	}
	luabind::invoke([&](lua_State* L) {
		lua_pushinteger(L, id);
		plugin->pushevent(L, event);
		plugin->call(L, LuaEvent::OnEvent, 2);
	});
}
