cmake_minimum_required(VERSION 3.16.3)

project(exif-napi)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# 添加 libexif 子目录
add_subdirectory(libexif)

# NAPI 模块
add_library(exiftool SHARED libexif_napi.cpp)

# 包含目录 - libexif 的父目录，这样 #include <libexif/...> 可以找到
target_include_directories(exiftool PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/libexif
)

# 链接 libexif 和 NAPI
target_link_libraries(exiftool PRIVATE
    libace_napi.z.so
    libexif
)

# 设置输出目录
set_target_properties(exiftool PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/../libs/${CMAKE_BUILD_TYPE}
)
