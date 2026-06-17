# the minimum version of CMake.
cmake_minimum_required(VERSION 3.5.0)
project(LightFlowMap)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

if(DEFINED PACKAGE_FIND_FILE)
    include(${PACKAGE_FIND_FILE})
endif()

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

set(EXIFTOOL_DIR ${CMAKE_CURRENT_SOURCE_DIR}/ExifTool)
set(EXIF_DIR "${EXIFTOOL_DIR}/EXIF")
set(ZLIB_DIR "${EXIF_DIR}/zlib-1.3/zlib-1.3")
set(EXPAT_DIR "${EXIF_DIR}/libexpat-R_2_8_1/libexpat-R_2_8_1/expat")
set(EXIV2_DIR "${EXIF_DIR}/exiv2-0.27.7/exiv2-0.27.7")

set(SKIP_INSTALL_ALL ON CACHE BOOL "" FORCE)
set(SKIP_INSTALL_FILES ON CACHE BOOL "" FORCE)
set(SKIP_INSTALL_EXPORT ON CACHE BOOL "" FORCE)
add_subdirectory(${ZLIB_DIR} zlib_build)

set(EXPAT_BUILD_TOOLS OFF CACHE BOOL "" FORCE)
set(EXPAT_BUILD_EXAMPLES OFF CACHE BOOL "" FORCE)
set(EXPAT_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(EXPAT_BUILD_DOCS OFF CACHE BOOL "" FORCE)
set(EXPAT_SHARED_LIBS OFF CACHE BOOL "" FORCE)
add_subdirectory(${EXPAT_DIR} expat_build)

set(EXIV2_ENABLE_XMP OFF CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_WEBREADY OFF CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_CURL OFF CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_NLS OFF CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_PRINTUCS2 ON CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_LENSDATA ON CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_EXTERNAL ON CACHE BOOL "" FORCE)
set(EXIV2_BUILD_EXIV2_COMMAND OFF CACHE BOOL "" FORCE)
set(EXIV2_BUILD_SAMPLES OFF CACHE BOOL "" FORCE)
set(EXIV2_BUILD_TESTS OFF CACHE BOOL "" FORCE)
set(EXIV2_ENABLE_PNG OFF CACHE BOOL "" FORCE)
add_subdirectory(${EXIV2_DIR} exiv2_build)

add_library(ExifTool STATIC
    ${EXIFTOOL_DIR}/ExifTool.cpp
    ${EXIFTOOL_DIR}/ExifTool.hpp
)

target_include_directories(ExifTool PRIVATE
    ${EXIV2_DIR}/include
    ${CMAKE_CURRENT_BINARY_DIR}
)

target_link_libraries(ExifTool PRIVATE
    exiv2lib
)

add_library(entry SHARED napi_init.cpp)
target_include_directories(entry PRIVATE
    ${EXIFTOOL_DIR}
    ${EXIV2_DIR}/include
    ${CMAKE_CURRENT_BINARY_DIR}
)
target_link_libraries(entry PUBLIC
    libace_napi.z.so
    ExifTool
    exiv2lib
    zlibstatic
    expat
)
