/**
 * libexiftool 工具类
 * 封装 libexif 库的常用功能，提供 EXIF 数据读写能力
 * 更新时间: 2026-04-29
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileUri } from '@kit.CoreFileKit';
import libexiftool from 'libexiftool.so';

/**
 * EXIF标签信息
 */
export interface ExifTagInfo {
  id: number;
  name: string;
}

/**
 * GPS坐标信息
 */
export interface GPSCoordinates {
  latitude: number;
  longitude: number;
  altitude?: number;
}

/**
 * 图片基本信息
 */
export interface ImageInfo {
  width: number;
  height: number;
  make: string;
  model: string;
  orientation: number;
  dateTime: string;
}

/**
 * 相机设置信息
 */
export interface CameraSettings {
  exposureTime: string;
  fNumber: string;
  iso: string;
  focalLength: string;
  flash: string;
}

/**
 * 相机信息接口
 */
export interface CameraInfo {
  make: string;
  model: string;
}

/**
 * IFD索引接口
 */
export interface IfdIndex {
  MAIN: number;
  THUMBNAIL: number;
  EXIF: number;
  GPS: number;
  INTEROPERABILITY: number;
}

/**
 * 标签映射接口
 */
export interface TagMap {
  IMAGE_WIDTH: number;
  IMAGE_LENGTH: number;
  MAKE: number;
  MODEL: number;
  ORIENTATION: number;
  DATE_TIME: number;
  DATE_TIME_ORIGINAL: number;
  DATE_TIME_DIGITIZED: number;
  EXPOSURE_TIME: number;
  F_NUMBER: number;
  ISO_SPEED_RATINGS: number;
  SHUTTER_SPEED_VALUE: number;
  APERTURE_VALUE: number;
  FOCAL_LENGTH: number;
  FLASH: number;
  GPS_LATITUDE: number;
  GPS_LATITUDE_REF: number;
  GPS_LONGITUDE: number;
  GPS_LONGITUDE_REF: number;
  GPS_ALTITUDE: number;
  GPS_ALTITUDE_REF: number;
  GPS_TIME_STAMP: number;
  GPS_DATE_STAMP: number;
}

const IFD_MAP: IfdIndex = {
  MAIN: 0,
  THUMBNAIL: 1,
  EXIF: 2,
  GPS: 3,
  INTEROPERABILITY: 4
};

const TAG_MAP: TagMap = {
  IMAGE_WIDTH: 0x0100,
  IMAGE_LENGTH: 0x0101,
  MAKE: 0x010f,
  MODEL: 0x0110,
  ORIENTATION: 0x0112,
  DATE_TIME: 0x0132,
  DATE_TIME_ORIGINAL: 0x9003,
  DATE_TIME_DIGITIZED: 0x9004,
  EXPOSURE_TIME: 0x829a,
  F_NUMBER: 0x829d,
  ISO_SPEED_RATINGS: 0x8827,
  SHUTTER_SPEED_VALUE: 0x9201,
  APERTURE_VALUE: 0x9202,
  FOCAL_LENGTH: 0x920a,
  FLASH: 0x9209,
  GPS_LATITUDE: 0x0002,
  GPS_LATITUDE_REF: 0x0001,
  GPS_LONGITUDE: 0x0004,
  GPS_LONGITUDE_REF: 0x0003,
  GPS_ALTITUDE: 0x0006,
  GPS_ALTITUDE_REF: 0x0005,
  GPS_TIME_STAMP: 0x0007,
  GPS_DATE_STAMP: 0x001d
};

const TAG = 'LibExifTool';

export class LibExifTool {
  static readonly IFD: IfdIndex = IFD_MAP;
  static readonly TAGS: TagMap = TAG_MAP;

  /**
   * 将URI转换为实际文件路径
   * @param uri 图片URI（如 file:// 或 content:// 格式）
   * @returns 实际文件路径
   */
  static uriToPath(uri: string): string {
    try {
      hilog.info(0xFF00, TAG, `Converting URI to path: ${uri}`);
      const fileObj = new fileUri.FileUri(uri);
      const path = fileObj.path;
      hilog.info(0xFF00, TAG, `Converted path: ${path}`);
      return path;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to convert URI to path: ${error}`);
      return uri;
    }
  }

  static readExifData(imagePath: string): Record<string, string> {
    try {
      hilog.info(0xFF00, TAG, `[readExifData] Reading EXIF data from: ${imagePath}`);
      hilog.info(0xFF00, TAG, `[readExifData] Path length: ${imagePath.length}`);
      hilog.info(0xFF00, TAG, `[readExifData] Path starts with: ${imagePath.substring(0, 20)}...`);
      
      const exifData: Record<string, string> = libexiftool.readExifData(imagePath);
      const keys = Object.keys(exifData);
      
      hilog.info(0xFF00, TAG, `[readExifData] EXIF data read successfully, ${keys.length} tags found`);
      
      if (keys.length > 0) {
        hilog.info(0xFF00, TAG, `[readExifData] First 5 tags: ${keys.slice(0, 5).join(', ')}`);
        // 打印 Make 标签的值（如果存在）
        const makeValue = exifData['0x010F'];
        if (makeValue !== undefined) {
          hilog.info(0xFF00, TAG, `[readExifData] Make tag found: ${makeValue}`);
        } else {
          hilog.info(0xFF00, TAG, `[readExifData] Make tag NOT found in exifData`);
          // 检查所有可能的键名变体
          hilog.info(0xFF00, TAG, `[readExifData] Checking for Make tag with different cases...`);
          for (let i = 0; i < keys.length; i++) {
            const key = keys[i];
            if (key.toLowerCase() === '0x010f' || key.indexOf('Make') !== -1) {
              hilog.info(0xFF00, TAG, `[readExifData] Found potential Make tag: ${key} = ${exifData[key]}`);
            }
          }
        }
      } else {
        hilog.warn(0xFF00, TAG, `[readExifData] No EXIF tags found in image`);
      }
      
      return exifData;
    } catch (error) {
      hilog.error(0xFF00, TAG, `[readExifData] Failed to read EXIF data: ${error}`);
      return {};
    }
  }

  static getSupportedTags(): ExifTagInfo[] {
    try {
      const tags: ExifTagInfo[] = libexiftool.getSupportedTags();
      hilog.info(0xFF00, TAG, `Supported tags count: ${tags.length}`);
      return tags;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get supported tags: ${error}`);
      return [];
    }
  }

  static getExifEntry(imagePath: string, ifd: number, tag: number): string | undefined {
    try {
      hilog.info(0xFF00, TAG, `Getting EXIF entry: ifd=${ifd}, tag=0x${tag.toString(16)}`);
      const value: string | undefined = libexiftool.getExifEntry(imagePath, ifd, tag);
      hilog.info(0xFF00, TAG, `EXIF entry value: ${value ?? 'not found'}`);
      return value;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get EXIF entry: ${error}`);
      return undefined;
    }
  }

  static getImageInfo(imagePath: string): ImageInfo | null {
    try {
      hilog.info(0xFF00, TAG, `[getImageInfo] Entering function with path: ${imagePath}`);
      
      const exifData = LibExifTool.readExifData(imagePath);
      const keys = Object.keys(exifData);
      
      hilog.info(0xFF00, TAG, `[getImageInfo] exifData has ${keys.length} keys`);
      
      const widthStr = exifData['0x0100'];
      const heightStr = exifData['0x0101'];
      const make = exifData['0x010F'];
      const model = exifData['0x0110'];
      const orientationStr = exifData['0x0112'];
      const dateTime = exifData['0x0132'];
      
      hilog.info(0xFF00, TAG, `[getImageInfo] widthStr: ${widthStr ?? 'undefined'}`);
      hilog.info(0xFF00, TAG, `[getImageInfo] heightStr: ${heightStr ?? 'undefined'}`);
      hilog.info(0xFF00, TAG, `[getImageInfo] make: ${make ?? 'undefined'}`);
      hilog.info(0xFF00, TAG, `[getImageInfo] model: ${model ?? 'undefined'}`);
      hilog.info(0xFF00, TAG, `[getImageInfo] orientationStr: ${orientationStr ?? 'undefined'}`);
      hilog.info(0xFF00, TAG, `[getImageInfo] dateTime: ${dateTime ?? 'undefined'}`);

      const result: ImageInfo = {
        width: widthStr ? parseInt(widthStr, 10) : 0,
        height: heightStr ? parseInt(heightStr, 10) : 0,
        make: make || '',
        model: model || '',
        orientation: orientationStr ? parseInt(orientationStr, 10) : 1,
        dateTime: dateTime || ''
      };
      
      hilog.info(0xFF00, TAG, `[getImageInfo] Returning result: make=${result.make}, model=${result.model}`);
      return result;
    } catch (error) {
      hilog.error(0xFF00, TAG, `[getImageInfo] Failed to get image info: ${error}`);
      return null;
    }
  }

  static getGPSCoordinates(imagePath: string): GPSCoordinates | null {
    try {
      const exifData = LibExifTool.readExifData(imagePath);

      let latStr = exifData['GPSLatitude'] || exifData['0x0002'];
      let latRef = exifData['GPSLatitudeRef'] || exifData['0x0001'] || 'N';
      let lngStr = exifData['GPSLongitude'] || exifData['0x0004'];
      let lngRef = exifData['GPSLongitudeRef'] || exifData['0x0003'] || 'E';
      let altStr = exifData['GPSAltitude'] || exifData['0x0006'];

      if (!latStr || !lngStr) {
        hilog.warn(0xFF00, TAG, `GPS data not found in image: ${imagePath}`);
        return null;
      }

      const latitude = LibExifTool.parseDMS(latStr) * (latRef === 'S' ? -1 : 1);
      const longitude = LibExifTool.parseDMS(lngStr) * (lngRef === 'W' ? -1 : 1);
      const altitude = altStr ? parseFloat(altStr) : undefined;

      hilog.info(0xFF00, TAG, `GPS coordinates: ${latitude}, ${longitude}, altitude: ${altitude}`);

      const result: GPSCoordinates = {
        latitude,
        longitude,
        altitude
      };
      return result;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get GPS coordinates: ${error}`);
      return null;
    }
  }

  static getDateTimeOriginal(imagePath: string): string {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      const dateTime = exifData['0x9003'] || exifData['0x9004'] || exifData['0x0132'] || '';
      return dateTime;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get date time: ${error}`);
      return '';
    }
  }

  static getCameraInfo(imagePath: string): CameraInfo {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      const result: CameraInfo = {
        make: exifData['0x010F'] || '',
        model: exifData['0x0110'] || ''
      };
      return result;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get camera info: ${error}`);
      const result: CameraInfo = {
        make: '',
        model: ''
      };
      return result;
    }
  }

  static getCameraSettings(imagePath: string): CameraSettings {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      const result: CameraSettings = {
        exposureTime: exifData['0x829A'] || '',
        fNumber: exifData['0x829D'] || '',
        iso: exifData['0x8827'] || '',
        focalLength: exifData['0x920A'] || '',
        flash: exifData['0x9209'] || ''
      };
      return result;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get camera settings: ${error}`);
      const result: CameraSettings = {
        exposureTime: '',
        fNumber: '',
        iso: '',
        focalLength: '',
        flash: ''
      };
      return result;
    }
  }

  static parseDMS(dms: string): number {
    try {
      const parts: number[] = dms.split(',').map((part: string) => {
        const fraction = part.split('/');
        if (fraction.length === 2) {
          return parseFloat(fraction[0]) / parseFloat(fraction[1]);
        }
        return parseFloat(part) || 0;
      });

      if (parts.length < 3) {
        hilog.warn(0xFF00, TAG, `Invalid DMS format: ${dms}`);
        return 0;
      }

      return parts[0] + parts[1] / 60 + parts[2] / 3600;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to parse DMS: ${dms}, error: ${error}`);
      return 0;
    }
  }

  static hasExifData(imagePath: string): boolean {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      return Object.keys(exifData).length > 0;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to check EXIF data: ${error}`);
      return false;
    }
  }

  static getExifTagCount(imagePath: string): number {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      return Object.keys(exifData).length;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get tag count: ${error}`);
      return 0;
    }
  }

  static getReadableExifInfo(imagePath: string): Record<string, string> {
    try {
      const exifData = LibExifTool.readExifData(imagePath);
      const supportedTags = LibExifTool.getSupportedTags();

      const tagIdToName = new Map<number, string>();
      supportedTags.forEach((tag: ExifTagInfo) => {
        tagIdToName.set(tag.id, tag.name);
      });

      const readableInfo: Record<string, string> = {};
      Object.keys(exifData).forEach((key: string) => {
        let tagName = key;
        if (key.startsWith('0x')) {
          const tagId = parseInt(key, 16);
          const name = tagIdToName.get(tagId);
          if (name) {
            tagName = name;
          }
        }
        readableInfo[tagName] = exifData[key];
      });

      return readableInfo;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get readable EXIF info: ${error}`);
      return {};
    }
  }
}

export default LibExifTool;
