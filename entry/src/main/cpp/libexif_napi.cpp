#include <cstring>
#include <cstdio>
#include <cstdlib>
#include "napi/native_api.h"
#include <libexif/exif-data.h>
#include <libexif/exif-content.h>
#include <libexif/exif-entry.h>
#include <libexif/exif-tag.h>
#include <libexif/exif-format.h>

static napi_value ReadExifData(napi_env env, napi_callback_info info) {
    size_t argc = 1;
    napi_value args[1];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 1) {
        napi_throw_type_error(env, nullptr, "Missing image path argument");
        return nullptr;
    }

    // 增加路径缓冲区大小，支持更长的路径和中文路径
    char imagePath[2048];
    size_t pathLength;
    napi_status status = napi_get_value_string_utf8(env, args[0], imagePath, sizeof(imagePath), &pathLength);
    
    if (status != napi_ok) {
        napi_throw_error(env, nullptr, "Failed to get image path string");
        return nullptr;
    }

    // 尝试使用 libexif 读取 EXIF 数据
    ExifData* data = exif_data_new_from_file(imagePath);
    
    // 如果 libexif 无法读取，尝试使用 exif_data_new_from_data 从文件内容读取
    if (!data) {
        FILE* fp = fopen(imagePath, "rb");
        if (fp) {
            // 获取文件大小
            fseek(fp, 0, SEEK_END);
            long fileSize = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            
            // 读取文件内容
            unsigned char* buffer = (unsigned char*)malloc(fileSize);
            if (buffer) {
                size_t bytesRead = fread(buffer, 1, fileSize, fp);
                if (bytesRead == fileSize) {
                    data = exif_data_new_from_data(buffer, fileSize);
                }
                free(buffer);
            }
            fclose(fp);
        }
    }

    if (!data) {
        napi_throw_error(env, nullptr, "Failed to read EXIF data from file");
        return nullptr;
    }

    napi_value result;
    napi_create_object(env, &result);

    for (int i = 0; i < EXIF_IFD_COUNT; i++) {
        ExifContent* content = data->ifd[i];
        if (!content) continue;

        for (unsigned int j = 0; j < content->count; j++) {
            ExifEntry* entry = content->entries[j];
            if (!entry) continue;

            char buffer[256];
            const char* value = exif_entry_get_value(entry, buffer, sizeof(buffer));

            char tagName[32];
            snprintf(tagName, sizeof(tagName), "0x%04X", entry->tag);

            napi_value tagValue;
            napi_create_string_utf8(env, value, NAPI_AUTO_LENGTH, &tagValue);

            napi_set_named_property(env, result, tagName, tagValue);
        }
    }

    exif_data_unref(data);
    return result;
}

// 定义支持的标签列表
typedef struct {
    ExifTag tag;
    const char* name;
} SupportedTag;

static const SupportedTag supportedTags[] = {
    {EXIF_TAG_IMAGE_DESCRIPTION, "ImageDescription"},
    {EXIF_TAG_SOFTWARE, "Software"},
    {EXIF_TAG_DATE_TIME, "DateTime"},
    {EXIF_TAG_DATE_TIME_ORIGINAL, "DateTimeOriginal"},
    {EXIF_TAG_DATE_TIME_DIGITIZED, "DateTimeDigitized"},
    {EXIF_TAG_EXIF_VERSION, "ExifVersion"},
    {EXIF_TAG_USER_COMMENT, "UserComment"},
    {(ExifTag)EXIF_TAG_GPS_LATITUDE, "GPSLatitude"},
    {(ExifTag)EXIF_TAG_GPS_LONGITUDE, "GPSLongitude"},
    {(ExifTag)EXIF_TAG_GPS_LATITUDE_REF, "GPSLatitudeRef"},
    {(ExifTag)EXIF_TAG_GPS_LONGITUDE_REF, "GPSLongitudeRef"},
    {(ExifTag)EXIF_TAG_GPS_ALTITUDE, "GPSAltitude"},
    {EXIF_TAG_GPS_ALTITUDE_REF, "GPSAltitudeRef"},
    {EXIF_TAG_GPS_TIME_STAMP, "GPSTimeStamp"},
    {(ExifTag)EXIF_TAG_GPS_DATE_STAMP, "GPSDateStamp"},
    {EXIF_TAG_MAKE, "Make"},
    {EXIF_TAG_MODEL, "Model"},
    {EXIF_TAG_ORIENTATION, "Orientation"},
    {EXIF_TAG_X_RESOLUTION, "XResolution"},
    {EXIF_TAG_Y_RESOLUTION, "YResolution"},
    {EXIF_TAG_RESOLUTION_UNIT, "ResolutionUnit"},
    {EXIF_TAG_EXPOSURE_TIME, "ExposureTime"},
    {EXIF_TAG_FNUMBER, "FNumber"},
    {EXIF_TAG_ISO_SPEED_RATINGS, "ISOSpeedRatings"},
    {EXIF_TAG_FLASH, "Flash"},
    {EXIF_TAG_FOCAL_LENGTH, "FocalLength"},
    {EXIF_TAG_FOCAL_LENGTH_IN_35MM_FILM, "FocalLengthIn35mmFilm"},
    {EXIF_TAG_WHITE_BALANCE, "WhiteBalance"},
    {EXIF_TAG_EXPOSURE_MODE, "ExposureMode"},
    {EXIF_TAG_EXPOSURE_PROGRAM, "ExposureProgram"},
    {EXIF_TAG_METERING_MODE, "MeteringMode"},
    {EXIF_TAG_SCENE_TYPE, "SceneType"},
    {EXIF_TAG_SHUTTER_SPEED_VALUE, "ShutterSpeedValue"},
    {EXIF_TAG_APERTURE_VALUE, "ApertureValue"},
    {EXIF_TAG_BRIGHTNESS_VALUE, "BrightnessValue"},
    {EXIF_TAG_EXPOSURE_BIAS_VALUE, "ExposureBiasValue"},
    {EXIF_TAG_SUBJECT_DISTANCE, "SubjectDistance"},
    {EXIF_TAG_DIGITAL_ZOOM_RATIO, "DigitalZoomRatio"},
    {EXIF_TAG_GAIN_CONTROL, "GainControl"},
    {EXIF_TAG_CONTRAST, "Contrast"},
    {EXIF_TAG_SATURATION, "Saturation"},
    {EXIF_TAG_SHARPNESS, "Sharpness"},
    {EXIF_TAG_DEVICE_SETTING_DESCRIPTION, "DeviceSettingDescription"},
    {EXIF_TAG_SUBJECT_DISTANCE_RANGE, "SubjectDistanceRange"},
};

static const size_t supportedTagsCount = sizeof(supportedTags) / sizeof(SupportedTag);

static napi_value GetSupportedTags(napi_env env, napi_callback_info info) {
    napi_value result;
    napi_create_array(env, &result);

    for (int i = 0; i < supportedTagsCount; i++) {
        napi_value tagObj;
        napi_create_object(env, &tagObj);

        napi_value tagId;
        napi_create_int32(env, supportedTags[i].tag, &tagId);
        napi_set_named_property(env, tagObj, "id", tagId);

        napi_value tagName;
        napi_create_string_utf8(env, supportedTags[i].name, NAPI_AUTO_LENGTH, &tagName);
        napi_set_named_property(env, tagObj, "name", tagName);

        napi_set_element(env, result, i, tagObj);
    }

    return result;
}

static napi_value GetExifEntry(napi_env env, napi_callback_info info) {
    size_t argc = 3;
    napi_value args[3];
    napi_get_cb_info(env, info, &argc, args, nullptr, nullptr);

    if (argc < 3) {
        napi_throw_type_error(env, nullptr, "Missing arguments: path, ifd, tag");
        return nullptr;
    }

    // 增加路径缓冲区大小
    char imagePath[2048];
    size_t pathLength;
    napi_status status = napi_get_value_string_utf8(env, args[0], imagePath, sizeof(imagePath), &pathLength);
    
    if (status != napi_ok) {
        napi_throw_error(env, nullptr, "Failed to get image path string");
        return nullptr;
    }

    int32_t ifdIndex;
    napi_get_value_int32(env, args[1], &ifdIndex);

    int32_t tagId;
    napi_get_value_int32(env, args[2], &tagId);

    if (ifdIndex < 0 || ifdIndex >= EXIF_IFD_COUNT) {
        napi_throw_type_error(env, nullptr, "Invalid IFD index");
        return nullptr;
    }

    // 尝试使用 libexif 读取 EXIF 数据
    ExifData* data = exif_data_new_from_file(imagePath);
    
    // 如果 libexif 无法读取，尝试使用 exif_data_new_from_data 从文件内容读取
    if (!data) {
        FILE* fp = fopen(imagePath, "rb");
        if (fp) {
            fseek(fp, 0, SEEK_END);
            long fileSize = ftell(fp);
            fseek(fp, 0, SEEK_SET);
            
            unsigned char* buffer = (unsigned char*)malloc(fileSize);
            if (buffer) {
                size_t bytesRead = fread(buffer, 1, fileSize, fp);
                if (bytesRead == fileSize) {
                    data = exif_data_new_from_data(buffer, fileSize);
                }
                free(buffer);
            }
            fclose(fp);
        }
    }

    if (!data) {
        napi_throw_error(env, nullptr, "Failed to read EXIF data from file");
        return nullptr;
    }

    ExifEntry* entry = exif_content_get_entry(data->ifd[ifdIndex], (ExifTag)tagId);

    napi_value result;
    if (entry) {
        char buffer[256];
        const char* value = exif_entry_get_value(entry, buffer, sizeof(buffer));
        napi_create_string_utf8(env, value, NAPI_AUTO_LENGTH, &result);
    } else {
        napi_get_undefined(env, &result);
    }

    exif_data_unref(data);
    return result;
}

static napi_value Init(napi_env env, napi_value exports) {
    napi_property_descriptor desc[] = {
        {"readExifData", nullptr, ReadExifData, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getSupportedTags", nullptr, GetSupportedTags, nullptr, nullptr, nullptr, napi_default, nullptr},
        {"getExifEntry", nullptr, GetExifEntry, nullptr, nullptr, nullptr, napi_default, nullptr}
    };

    napi_define_properties(env, exports, 3, desc);
    return exports;
}

NAPI_MODULE(NODE_GYP_MODULE_NAME, Init)
