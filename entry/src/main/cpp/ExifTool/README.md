# ExifTool - C++ EXIF 信息处理工具

## 项目简介

ExifTool 是一个基于 exiv2 库的 C++ 封装类，用于读取、修改和写入图像文件的 EXIF 元数据。该项目提供了简洁的接口来处理图像的 EXIF 信息，包括：

- 获取所有 EXIF 信息
- 获取单个 EXIF 字段信息
- 检查图像是否包含 EXIF 数据
- 检查是否包含特定字段
- 添加/修改 EXIF 字段
- 删除 EXIF 字段
- 保存修改后的图像

## 项目结构

```
e:\Program\OH\CPP\
├── CMakeLists.txt              # 主项目 CMake 配置文件
├── ExifTool.hpp                # ExifTool 类头文件
├── ExifTool.cpp                # ExifTool 类实现文件
├── test.cpp                    # 测试程序
├── README.md                   # 项目说明文档
└── EXIF/                       # 依赖库目录
    ├── exiv2-0.27.7/           # Exiv2 库
    ├── libexpat-R_2_8_1/       # Expat XML 解析库
    └── zlib-1.3/               # Zlib 压缩库
```

## 依赖库

- **Exiv2 0.27.7**: 图像元数据处理库
- **Expat 2.8.1**: XML 解析库（用于 XMP 支持）
- **Zlib 1.3**: 压缩库（用于 PNG 支持）

## 编译环境要求

- **操作系统**: Windows 10/11
- **编译器**: Visual Studio 2022 (MSVC 19.44)
- **CMake**: 4.0.0 或更高版本
- **PowerShell**: 5.0 或更高版本

## 编译方法

### 1. 环境准备

确保已安装以下软件：
- Visual Studio 2022 Community 或更高版本
- CMake 4.0.0 或更高版本
- Windows SDK 10.0.26100.0 或更高版本

### 2. 编译步骤

#### 方法一：使用 PowerShell 命令（推荐）

**重要提示**: 在 PowerShell 中，路径包含空格时必须使用 `&` 操作符调用程序。

```powershell
# 1. 清理旧的构建文件
Remove-Item -Path e:\Program\OH\CPP\build -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path e:\Program\OH\CPP\build

# 2. 配置项目
cd e:\Program\OH\CPP\build
& "D:\Sofeware\cmake-4.0.0-rc4-windows-x86_64\bin\cmake.exe" .. -G "Visual Studio 17 2022"

# 3. 编译项目（注意使用 & 操作符）
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ExifTool.sln /p:Configuration=Release /v:m /nologo
```

#### 方法二：使用 MinGW 编译器

```powershell
# 1. 清理旧的构建文件
Remove-Item -Path e:\Program\OH\CPP\build -Recurse -Force -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Path e:\Program\OH\CPP\build

# 2. 配置项目
cd e:\Program\OH\CPP\build
& "D:\Sofeware\cmake-4.0.0-rc4-windows-x86_64\bin\cmake.exe" .. -G "MinGW Makefiles"

# 3. 编译项目
mingw32-make
```

### 3. 编译输出

编译成功后，会在 `build` 目录下生成以下文件：

```
build/
├── bin/
│   └── exiv2.dll                    # Exiv2 动态库
├── expat_build/Release/
│   └── libexpatMD.lib               # Expat 静态库
├── zlib_build/Release/
│   ├── zlib1.dll                    # Zlib 动态库
│   └── zlibstatic.lib               # Zlib 静态库
└── Release/
    ├── ExifTool.lib                 # ExifTool 静态库
    └── ExifToolTest.exe             # 测试程序
```

## 使用示例

### 基本使用

```cpp
#include "ExifTool.hpp"

int main() {
    ExifTool tool;
    
    // 打开图像文件
    if (tool.openImage("test.jpg")) {
        // 获取所有 EXIF 信息
        auto allData = tool.getAllExifData();
        for (const auto& [key, value] : allData) {
            std::cout << key << ": " << value << std::endl;
        }
        
        // 获取单个字段
        std::string make = tool.getExifField("Exif.Image.Make");
        std::cout << "Camera Make: " << make << std::endl;
        
        // 设置字段
        tool.setExifField("Exif.Image.Artist", "My Name");
        
        // 保存修改
        tool.saveImage("output.jpg");
    }
    
    return 0;
}
```

### 高级功能

```cpp
// 检查是否包含 EXIF 数据
if (tool.hasExifData()) {
    std::cout << "Image contains EXIF data" << std::endl;
}

// 检查特定字段是否存在
if (tool.hasExifField("Exif.Photo.DateTimeOriginal")) {
    std::cout << "DateTimeOriginal exists" << std::endl;
}

// 删除字段
tool.removeExifField("Exif.Image.Software");

// 清除所有 EXIF 数据
tool.clearAllExifData();
```

## CMake 配置说明

### 主要配置选项

```cmake
# C++ 标准
set(CMAKE_CXX_STANDARD 11)

# 依赖库配置
set(EXIV2_ENABLE_XMP OFF)        # 禁用 XMP 支持
set(EXIV2_ENABLE_PNG OFF)        # 禁用 PNG 支持
set(EXIV2_ENABLE_WEBREADY OFF)   # 禁用 Web 支持
set(EXIV2_BUILD_EXIV2_COMMAND OFF)  # 不构建命令行工具
```

### 链接库

项目会自动链接以下库：
- `exiv2lib`: Exiv2 主库
- `libexpatMD`: Expat XML 解析库
- `zlibstatic`: Zlib 压缩库

## 常见问题

### 1. 编译时出现中文乱码

**解决方案**: 使用英文输出或简化输出格式

```powershell
# 使用英文输出
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ExifTool.sln /p:Configuration=Release /clp:Summary;Verbosity=minimal

# 或使用简化输出
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" ExifTool.sln /p:Configuration=Release /v:m /nologo
```

### 2. 找不到 exv_conf.h 文件

**解决方案**: 确保在 CMakeLists.txt 中正确设置了包含路径

```cmake
target_include_directories(ExifTool PRIVATE
    ${EXIV2_DIR}/include
    ${CMAKE_CURRENT_BINARY_DIR}
)
```

### 3. 链接错误

**解决方案**: 确保所有依赖库都正确编译并链接

```powershell
# 单独编译每个库
cd e:\Program\OH\CPP\build
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" zlib_build\zlibstatic.vcxproj /p:Configuration=Release
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" expat_build\expat.vcxproj /p:Configuration=Release
& "C:\Program Files\Microsoft Visual Studio\2022\Community\MSBuild\Current\Bin\MSBuild.exe" exiv2_build\src\exiv2lib.vcxproj /p:Configuration=Release
```

## 许可证

本项目使用的依赖库许可证：
- Exiv2: GPL-2.0
- Expat: MIT
- Zlib: zlib License

## 联系方式

如有问题或建议，请通过以下方式联系：
- 项目地址: [项目仓库地址]
- 问题反馈: [Issues 地址]

## 更新日志

### v1.0.0 (2026-06-10)
- 初始版本发布
- 实现基本的 EXIF 读写功能
- 支持 JPEG、TIFF 等常见图像格式
- 完成 Windows 平台编译配置