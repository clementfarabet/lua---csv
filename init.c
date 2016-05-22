#include "TH.h"
#include "luaT.h"

#if LUA_VERSION_NUM == 501
static void luaL_setfuncs(lua_State *L, const luaL_Reg *l, int nup)
{
  luaL_checkstack(L, nup+1, "too many upvalues");
  for (; l->name != NULL; l++) {  /* fill the table with given functions */
    int i;
    lua_pushstring(L, l->name);
    for (i = 0; i < nup; i++)  /* copy upvalues to the top */
      lua_pushvalue(L, -(nup+1));
    lua_pushcclosure(L, l->func, nup);  /* closure with those upvalues */
    lua_settable(L, -(nup + 3));
  }
  lua_pop(L, nup);  /* remove upvalues */
}
#endif

static int create_lookup(lua_State* L)
{

  THCharStorage *input = luaT_checkudata(L, 1, "torch.CharStorage");
  char* data = THCharStorage_data(input);
  long length = input->size;

  long num_lines = 0;
  long i;
#pragma omp parallel for private(i)
  for (i = 0; i < length; i++) {
    if (data[i] == '\n') {
      num_lines++;
    }
  }

  if (data[length-1] != '\n') {
    num_lines++;
  }

  THLongTensor* lookup = THLongTensor_newWithSize2d(num_lines, 2);
  long* ldata = THLongTensor_data(lookup);

  long offset = 0;
  for (i = 0; i < length; i++) {
    if (data[i] == '\n' || data[i] == '\r') {
      *ldata++ = offset;
      *ldata++ = i - offset;

      if (data[i] == '\r') {
        i++;
      }

      offset = i+1;
    }
  }
  if (data[length-1] != '\n') {
    *ldata++ = offset;
    *ldata++ = length - offset;
  }

  luaT_pushudata(L, lookup, "torch.LongTensor");

  return 1;
}


static const struct luaL_Reg lib[] = {
  {"create_lookup", create_lookup},
  {NULL, NULL},
};

int luaopen_libcsvigo (lua_State *L) {
  lua_newtable(L);
  luaL_setfuncs(L, lib, 0);
  return 1;
}
