#include "napi/native_api.h"
#include "ExifTool/ExifTool.hpp"
#include <memory>
#include <map>

static std::string convertUriToPath(const std::string& uri) {
    // 处理 file:// 前缀
    if (uri.substr(0, 7) == "file://") {
        return uri.substr(7);
    }
    // 处理 content:// 前缀（鸿蒙媒体库格式）
    if (uri.substr(0, 10) == "content://") {
        // 尝试从 content URI 提取路径
        size_t pos = uri.find("/external_files/");
        if (pos != std::string::npos) {
            return "/storage/emulated/0/" + uri.substr(pos + 16);
        }
        // 其他 content URI 直接返回
        return uri;
    }
    // 处理 media:// 前缀
    if (uri.substr(0, 7) == "media://") {
        // 提取文件名
        size_t lastSlash = uri.find_last_of('/');
        if (lastSlash != std::string::npos) {
            std::string fileName = uri.substr(lastSlash + 1);
            return "/storage/emulated/0/Pictures/" + fileName;
        }
        return uri;
    }
    return uri;
}

static napi_value OpenImage(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing file path argument");
        return nullptr;
    }

    char filePath[1024] = {0};
    size_t filePathLen = 0;
    napi_get_value_string_utf8(env, args[0], filePath, sizeof(filePath), &filePathLen);

    std::string originalPath(filePath);
    std::string convertedPath = convertUriToPath(originalPath);

    std::unique_ptr<ExifTool>* exifToolPtr = new std::unique_ptr<ExifTool>(new ExifTool());
    
    // 首先尝试转换后的路径
    bool result = (*exifToolPtr)->openImage(convertedPath);
    
    // 如果失败，尝试原始路径
    if (!result) {
        result = (*exifToolPtr)->openImage(originalPath);
    }

    if (!result) {
        delete exifToolPtr;
        napi_value ret;
        napi_get_null(env, &ret);
        return ret;
    }

    napi_value external;
    napi_create_external(env, exifToolPtr, [](napi_env env, void* data, void* hint) {
        delete static_cast<std::unique_ptr<ExifTool>*>(data);
    }, nullptr, &external);

    return external;
}

static napi_value SaveImage(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    std::string filePath = "";
    if (argc >= 2) {
        char path[1024] = {0};
        size_t pathLen = 0;
        napi_get_value_string_utf8(env, args[1], path, sizeof(path), &pathLen);
        filePath = std::string(path);
    }

    bool result = (*exifToolPtr)->saveImage(filePath);

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

static napi_value HasExifData(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    bool result = (*exifToolPtr)->hasExifData();

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

static napi_value HasExifField(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "Missing arguments");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    char key[256] = {0};
    size_t keyLen = 0;
    napi_get_value_string_utf8(env, args[1], key, sizeof(key), &keyLen);

    bool result = (*exifToolPtr)->hasExifField(std::string(key));

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

static napi_value GetExifField(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "Missing arguments");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    char key[256] = {0};
    size_t keyLen = 0;
    napi_get_value_string_utf8(env, args[1], key, sizeof(key), &keyLen);

    std::string result = (*exifToolPtr)->getExifField(std::string(key));

    napi_value ret;
    napi_create_string_utf8(env, result.c_str(), result.length(), &ret);
    return ret;
}

static napi_value SetExifField(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "Missing arguments");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    char key[256] = {0};
    size_t keyLen = 0;
    napi_get_value_string_utf8(env, args[1], key, sizeof(key), &keyLen);

    char value[1024] = {0};
    size_t valueLen = 0;
    napi_get_value_string_utf8(env, args[2], value, sizeof(value), &valueLen);

    bool result = (*exifToolPtr)->setExifField(std::string(key), std::string(value));

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

static napi_value RemoveExifField(napi_env env, napi_callback_info info) {
    size_t argc = 2;
    napi_value args[2] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 2) {
        napi_throw_error(env, nullptr, "Missing arguments");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    char key[256] = {0};
    size_t keyLen = 0;
    napi_get_value_string_utf8(env, args[1], key, sizeof(key), &keyLen);

    bool result = (*exifToolPtr)->removeExifField(std::string(key));

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

static napi_value GetAllExifData(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    std::map<std::string, std::string> data = (*exifToolPtr)->getAllExifData();

    napi_value ret;
    napi_create_object(env, &ret);

    for (const auto& pair : data) {
        napi_value value;
        napi_create_string_utf8(env, pair.second.c_str(), pair.second.length(), &value);
        napi_set_named_property(env, ret, pair.first.c_str(), value);
    }

    return ret;
}

static napi_value GetAllExifKeys(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    std::vector<std::string> keys = (*exifToolPtr)->getAllExifKeys();

    napi_value ret;
    napi_create_array(env, &ret);

    for (size_t i = 0; i < keys.size(); ++i) {
        napi_value key;
        napi_create_string_utf8(env, keys[i].c_str(), keys[i].length(), &key);
        napi_set_element(env, ret, i, key);
    }

    return ret;
}

static napi_value ClearAllExifData(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    (*exifToolPtr)->clearAllExifData();

    napi_value ret;
    napi_get_undefined(env, &ret);
    return ret;
}

static napi_value GetExifFieldWithDefault(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_error(env, nullptr, "Missing arguments");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    char key[256] = {0};
    size_t keyLen = 0;
    napi_get_value_string_utf8(env, args[1], key, sizeof(key), &keyLen);

    char defaultValue[1024] = {0};
    size_t defaultValueLen = 0;
    napi_get_value_string_utf8(env, args[2], defaultValue, sizeof(defaultValue), &defaultValueLen);

    std::string result = (*exifToolPtr)->getExifFieldWithDefault(std::string(key), std::string(defaultValue));

    napi_value ret;
    napi_create_string_utf8(env, result.c_str(), result.length(), &ret);
    return ret;
}

static napi_value AddBasicExifData(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1] = {nullptr};
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_error(env, nullptr, "Missing exifTool instance");
        return nullptr;
    }

    std::unique_ptr<ExifTool>* exifToolPtr = nullptr;
    napi_get_value_external(env, args[0], reinterpret_cast<void**>(&exifToolPtr));

    if (!exifToolPtr || !(*exifToolPtr)) {
        napi_throw_error(env, nullptr, "Invalid exifTool instance");
        return nullptr;
    }

    bool result = (*exifToolPtr)->addBasicExifData();

    napi_value ret;
    napi_get_boolean(env, result, &ret);
    return ret;
}

EXTERN_C_START
static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        { "openImage", nullptr, OpenImage, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "saveImage", nullptr, SaveImage, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "hasExifData", nullptr, HasExifData, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "hasExifField", nullptr, HasExifField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getExifField", nullptr, GetExifField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "setExifField", nullptr, SetExifField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "removeExifField", nullptr, RemoveExifField, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getAllExifData", nullptr, GetAllExifData, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getAllExifKeys", nullptr, GetAllExifKeys, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "clearAllExifData", nullptr, ClearAllExifData, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "getExifFieldWithDefault", nullptr, GetExifFieldWithDefault, nullptr, nullptr, nullptr, napi_default, nullptr },
        { "addBasicExifData", nullptr, AddBasicExifData, nullptr, nullptr, nullptr, napi_default, nullptr },
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
    .nm_modname = "entry",
    .nm_priv = ((void*)0),
    .reserved = { 0 },
};

extern "C" __attribute__((constructor)) void RegisterEntryModule(void) {
    napi_module_register(&demoModule);
}