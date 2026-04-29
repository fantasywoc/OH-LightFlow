# HarmonyOS C++ Native 集成指南

基于 NativeSoIntegration 项目分析

## 目录
1. [项目结构](#项目结构)
2. [C++编译配置](#C++编译配置)
3. [NAPI绑定实现](#NAPI绑定实现)
4. [TypeScript类型定义](#TypeScript类型定义)
5. [ETS调用方式](#ETS调用方式)
6. [两种集成方式对比](#两种集成方式对比)
7. [接入当前LightFlowMap项目步骤](#接入当前LightFlowMap项目步骤)

---

## 一、项目结构

```
NativeSoIntegration/
├── AppScope/                    # 应用全局配置
├── Multiply/                    # C++模块
│   ├── src/main/cpp/
│   │   ├── CMakeLists.txt       # CMake配置文件
│   │   ├── napi_init.cpp        # NAPI入口文件
│   │   ├── add/                 # C++源码目录
│   │   │   ├── add.h
│   │   │   └── add.cpp
│   │   ├── sub/
│   │   │   ├── sub.h
│   │   │   └── sub.cpp
│   │   └── types/libmultiply/   # TypeScript类型定义
│   │       ├── Index.d.ts
│   │       └── oh-package.json5
│   └── build-profile.json5      # 构建配置
├── entry/                       # 主应用模块
│   ├── libs/                    # 预编译的SO库
│   │   ├── arm64-v8a/
│   │   │   ├── libmultiply.so
│   │   │   ├── libnativeAdd.so
│   │   │   └── libnativeSub.so
│   │   └── x86_64/
│   └── src/main/cpp/            # entry模块的native代码
└── build-profile.json5          # 项目级构建配置
```

---

## 二、C++编译配置

### 2.1 CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.5.0)
project(NativeSoIntegration)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})

include_directories(${NATIVERENDER_ROOT_PATH}
                    ${NATIVERENDER_ROOT_PATH}/include)

# 方式1：编译带NAPI绑定的SO库
add_library(multiply SHARED napi_init.cpp)
target_link_libraries(multiply PUBLIC libace_napi.z.so)

# 方式2：编译纯C++功能库（无NAPI）
add_library(nativeAdd SHARED add/add.cpp)
add_library(nativeSub SHARED sub/sub.cpp)
```

**关键点**：
- `libace_napi.z.so` 是HarmonyOS提供的NAPI运行时库
- 纯C++库不需要链接NAPI，可通过dlopen动态加载

### 2.2 build-profile.json5

```json5
{
  "apiType": "stageMode",
  "buildOption": {
    "externalNativeOptions": {
      "path": "./src/main/cpp/CMakeLists.txt",  // CMake配置路径
      "arguments": "",
      "cppFlags": "",
      "abiFilters": ["arm64-v8a", "x86_64"]     // 目标架构
    }
  }
}
```

---

## 三、NAPI绑定实现

### 3.1 核心结构

```cpp
#include "napi/native_api.h"

// 1. 定义Native函数
static napi_value Multiply(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);
    
    // 获取参数
    double value0;
    napi_get_value_double(env, args[0], &value0);
    double value1;
    napi_get_value_double(env, args[1], &value1);
    
    // 返回结果
    napi_value ret;
    napi_create_double(env, value0 * value1, &ret);
    return ret;
}

// 2. 注册函数到exports
EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"multiply", nullptr, Multiply, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

// 3. 定义模块结构
static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,      // 初始化函数
    .nm_modname = "multiply",      // 模块名（必须与导入名一致）
    .nm_priv = ((void *)0),
    .reserved = {0},
};

// 4. 注册模块
extern "C" __attribute__((constructor)) 
void RegisterMultiplyModule(void) { 
    napi_module_register(&demoModule); 
}
```

### 3.2 NAPI常用API

| API | 功能 |
|-----|------|
| `napi_get_cb_info` | 获取函数调用信息 |
| `napi_get_value_double` | 从napi_value获取double值 |
| `napi_create_double` | 创建napi_value类型的double |
| `napi_define_properties` | 向exports对象添加属性 |
| `napi_module_register` | 注册NAPI模块 |

---

## 四、TypeScript类型定义

### 4.1 types/libmultiply/Index.d.ts

```typescript
export const multiply: (a: number, b: number) => number;
```

### 4.2 types/libmultiply/oh-package.json5

```json5
{
  "name": "libmultiply.so",    // SO库名称（导入时使用）
  "types": "./Index.d.ts",      // 类型定义文件路径
  "version": "1.0.0",
  "description": "Multiply Native Module"
}
```

### 4.3 模块依赖配置（oh-package.json5）

```json5
{
  "name": "multiply",
  "version": "1.0.0",
  "dependencies": {
    "libmultiply.so": "file:./src/main/cpp/types/libmultiply"
  }
}
```

---

## 五、ETS调用方式

### 5.1 导入SO库

```typescript
import testNapi from 'libmultiply.so';
```

### 5.2 调用Native函数

```typescript
// 直接调用导出的函数
let result = testNapi.multiply(2, 3);
console.log(`Result: ${result}`); // Output: 6
```

---

## 六、两种集成方式对比

### 方式1：静态链接（直接绑定）

**适用场景**：项目内部的Native模块

**优点**：
- 调用简单，性能好
- 编译时检查类型错误

**缺点**：
- 必须在同一模块内编译

**示例**：Multiply模块的multiply函数

```typescript
import multiplyNapi from 'libmultiply.so';
let result = multiplyNapi.multiply(2, 3);
```

---

### 方式2：动态加载（dlopen）

**适用场景**：第三方SO库、运行时选择库

**优点**：
- 灵活性高，运行时加载
- 可动态选择不同版本的库

**缺点**：
- 性能稍差（每次调用都要dlopen）
- 需要处理路径和错误

**示例**：entry模块加载libnativeSub.so

```typescript
// 1. 构建SO库路径
let projectPath = this.getUIContext().getHostContext()!.bundleCodeDir;
let abiPath = deviceInfo.abiList === 'x86_64' ? 'x86_64' : 'arm64';
let soLibPath = `${projectPath}/libs/${abiPath}/libnativeSub.so`;

// 2. 调用Native函数（内部使用dlopen）
let result = testNapi.nativeSub(Number(paramX), Number(paramY), soLibPath);
```

**Native端实现**：

```cpp
typedef double (*Sub)(double, double);
static napi_value NAPI_Global_nativeSub(napi_env env, napi_callback_info info) {
    // 获取SO库路径
    char *path = ...;
    
    // 动态加载SO库
    void *handle = dlopen(path, RTLD_LAZY);
    
    // 获取函数指针
    Sub sub_func = (Sub)dlsym(handle, "sub");
    
    // 调用函数
    double result = sub_func(value0, value1);
    
    // 关闭SO库
    dlclose(handle);
    
    return result;
}
```

---

## 七、接入当前LightFlowMap项目步骤

### 步骤1：创建C++目录结构

```
entry/src/main/cpp/
├── CMakeLists.txt
├── napi_init.cpp
├── mylib/
│   ├── mylib.h
│   └── mylib.cpp
└── types/libnative.so/
    ├── Index.d.ts
    └── oh-package.json5
```

### 步骤2：编写CMakeLists.txt

```cmake
cmake_minimum_required(VERSION 3.5.0)
project(LightFlowMapNative)

set(NATIVERENDER_ROOT_PATH ${CMAKE_CURRENT_SOURCE_DIR})
include_directories(${NATIVERENDER_ROOT_PATH})

# 编译带NAPI绑定的SO库
add_library(native SHARED napi_init.cpp mylib/mylib.cpp)
target_link_libraries(native PUBLIC libace_napi.z.so)
```

### 步骤3：编写NAPI绑定代码

```cpp
// napi_init.cpp
#include "napi/native_api.h"
#include "mylib/mylib.h"

static napi_value ProcessImage(napi_env env, napi_callback_info info) {
    // 获取参数
    // 处理图像...
    // 返回结果
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"processImage", nullptr, ProcessImage, nullptr, nullptr, nullptr, napi_default, nullptr}
    };
    napi_define_properties(env, exports, sizeof(desc) / sizeof(desc[0]), desc);
    return exports;
}
EXTERN_C_END

static napi_module demoModule = {
    .nm_version = 1,
    .nm_flags = 0,
    .nm_filename = nullptr,
    .nm_register_func = Init,
    .nm_modname = "native",
    .nm_priv = ((void *)0),
    .reserved = {0},
};

extern "C" __attribute__((constructor)) 
void RegisterNativeModule(void) { 
    napi_module_register(&demoModule); 
}
```

### 步骤4：编写类型定义

```typescript
// types/libnative/Index.d.ts
export const processImage: (data: string) => string;
```

```json5
// types/libnative/oh-package.json5
{
  "name": "libnative.so",
  "types": "./Index.d.ts",
  "version": "1.0.0"
}
```

### 步骤5：配置build-profile.json5

```json5
{
  "apiType": "stageMode",
  "buildOption": {
    "externalNativeOptions": {
      "path": "./src/main/cpp/CMakeLists.txt",
      "arguments": "",
      "cppFlags": "",
      "abiFilters": ["arm64-v8a", "x86_64"]
    }
  }
}
```

### 步骤6：配置模块依赖

```json5
// entry/oh-package.json5
{
  "name": "entry",
  "dependencies": {
    "libnative.so": "file:./src/main/cpp/types/libnative"
  }
}
```

### 步骤7：在ETS中调用

```typescript
import native from 'libnative.so';

// 调用Native函数
let result = native.processImage(imageData);
```

---

## 八、编译验证

### 编译命令

```bash
# 调试构建
./hvigorw.bat assembleDebug

# 发布构建
./hvigorw.bat assembleRelease
```

### 构建产物

```
entry/build/outputs/default/debug/
└── libs/
    ├── arm64-v8a/
    │   └── libnative.so
    └── x86_64/
        └── libnative.so
```

---

## 九、常见问题

### Q1: Native函数无法被调用

**检查项**：
- `nm_modname` 是否与导入名称一致
- `oh-package.json5` 配置是否正确
- CMake是否正确编译了SO库

### Q2: 类型错误

**检查项**：
- `Index.d.ts` 类型定义是否正确
- 函数参数和返回值类型是否匹配

### Q3: 架构不匹配

**检查项**：
- `abiFilters` 是否包含目标架构
- 设备ABI是否与构建的SO库一致

---

## 总结

| 步骤 | 操作 | 文件 |
|------|------|------|
| 1 | 编写C++源码 | `cpp/mylib/*.cpp` |
| 2 | 配置CMake | `cpp/CMakeLists.txt` |
| 3 | 编写NAPI绑定 | `cpp/napi_init.cpp` |
| 4 | 添加类型定义 | `cpp/types/xxx/Index.d.ts` |
| 5 | 配置构建 | `build-profile.json5` |
| 6 | 配置依赖 | `oh-package.json5` |
| 7 | ETS调用 | `import xxx from 'libxxx.so'` |

通过以上步骤，即可将C++代码编译为SO库并集成到HarmonyOS应用中！
