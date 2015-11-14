
CMAKE_MINIMUM_REQUIRED(VERSION 2.6 FATAL_ERROR)
CMAKE_POLICY(VERSION 2.6)
FIND_PACKAGE(Torch REQUIRED)

SET(luasrc init.lua File.lua)
SET(src init.c)

ADD_TORCH_PACKAGE(csvigo "${src}" "${luasrc}" "CSV Reader/Writer")

TARGET_LINK_LIBRARIES(csvigo luaT TH )
