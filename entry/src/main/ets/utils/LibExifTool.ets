/**
 * ExifTool 工具类
 * 封装基于 Exiv2 的 EXIF 数据读写能力
 * 更新时间: 2026-06-17
 */

import { hilog } from '@kit.PerformanceAnalysisKit';
import { fileUri } from '@kit.CoreFileKit';
import libentry from 'libentry.so';

type ExifToolNativeInstance = object;

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
  IMAGE_WIDTH: string;
  IMAGE_LENGTH: string;
  MAKE: string;
  MODEL: string;
  ORIENTATION: string;
  DATE_TIME: string;
  DATE_TIME_ORIGINAL: string;
  DATE_TIME_DIGITIZED: string;
  EXPOSURE_TIME: string;
  F_NUMBER: string;
  ISO_SPEED_RATINGS: string;
  SHUTTER_SPEED_VALUE: string;
  APERTURE_VALUE: string;
  FOCAL_LENGTH: string;
  FLASH: string;
  GPS_LATITUDE: string;
  GPS_LATITUDE_REF: string;
  GPS_LONGITUDE: string;
  GPS_LONGITUDE_REF: string;
  GPS_ALTITUDE: string;
  GPS_ALTITUDE_REF: string;
  GPS_TIME_STAMP: string;
  GPS_DATE_STAMP: string;
}

const IFD_MAP: IfdIndex = {
  MAIN: 0,
  THUMBNAIL: 1,
  EXIF: 2,
  GPS: 3,
  INTEROPERABILITY: 4
};

const TAG_MAP: TagMap = {
  IMAGE_WIDTH: 'Exif.Image.ImageWidth',
  IMAGE_LENGTH: 'Exif.Image.ImageLength',
  MAKE: 'Exif.Image.Make',
  MODEL: 'Exif.Image.Model',
  ORIENTATION: 'Exif.Image.Orientation',
  DATE_TIME: 'Exif.Image.DateTime',
  DATE_TIME_ORIGINAL: 'Exif.Photo.DateTimeOriginal',
  DATE_TIME_DIGITIZED: 'Exif.Photo.DateTimeDigitized',
  EXPOSURE_TIME: 'Exif.Photo.ExposureTime',
  F_NUMBER: 'Exif.Photo.FNumber',
  ISO_SPEED_RATINGS: 'Exif.Photo.ISOSpeedRatings',
  SHUTTER_SPEED_VALUE: 'Exif.Photo.ShutterSpeedValue',
  APERTURE_VALUE: 'Exif.Photo.ApertureValue',
  FOCAL_LENGTH: 'Exif.Photo.FocalLength',
  FLASH: 'Exif.Photo.Flash',
  GPS_LATITUDE: 'Exif.GPSInfo.GPSLatitude',
  GPS_LATITUDE_REF: 'Exif.GPSInfo.GPSLatitudeRef',
  GPS_LONGITUDE: 'Exif.GPSInfo.GPSLongitude',
  GPS_LONGITUDE_REF: 'Exif.GPSInfo.GPSLongitudeRef',
  GPS_ALTITUDE: 'Exif.GPSInfo.GPSAltitude',
  GPS_ALTITUDE_REF: 'Exif.GPSInfo.GPSAltitudeRef',
  GPS_TIME_STAMP: 'Exif.GPSInfo.GPSTimeStamp',
  GPS_DATE_STAMP: 'Exif.GPSInfo.GPSDateStamp'
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
      
      const exifTool: ExifToolNativeInstance | null = libentry.openImage(imagePath) as ExifToolNativeInstance | null;
      if (!exifTool) {
        hilog.warn(0xFF00, TAG, `[readExifData] Failed to open image`);
        return {};
      }

      const exifData: Record<string, string> = libentry.getAllExifData(exifTool);
      const keys = Object.keys(exifData);
      
      hilog.info(0xFF00, TAG, `[readExifData] EXIF data read successfully, ${keys.length} tags found`);
      
      if (keys.length > 0) {
        hilog.info(0xFF00, TAG, `[readExifData] First 5 tags: ${keys.slice(0, 5).join(', ')}`);
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
      hilog.info(0xFF00, TAG, `[getSupportedTags] Returning common EXIF tags`);
      const tags: ExifTagInfo[] = [
        { id: 0x0100, name: 'ImageWidth' },
        { id: 0x0101, name: 'ImageLength' },
        { id: 0x010f, name: 'Make' },
        { id: 0x0110, name: 'Model' },
        { id: 0x0112, name: 'Orientation' },
        { id: 0x0132, name: 'DateTime' },
        { id: 0x9003, name: 'DateTimeOriginal' },
        { id: 0x9004, name: 'DateTimeDigitized' },
        { id: 0x829a, name: 'ExposureTime' },
        { id: 0x829d, name: 'FNumber' },
        { id: 0x8827, name: 'ISOSpeedRatings' },
        { id: 0x9201, name: 'ShutterSpeedValue' },
        { id: 0x9202, name: 'ApertureValue' },
        { id: 0x920a, name: 'FocalLength' },
        { id: 0x9209, name: 'Flash' }
      ];
      return tags;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get supported tags: ${error}`);
      return [];
    }
  }

  static getExifEntry(imagePath: string, ifd: number, tag: number): string | undefined {
    try {
      hilog.info(0xFF00, TAG, `Getting EXIF entry: ifd=${ifd}, tag=0x${tag.toString(16)}`);
      
      const exifTool: ExifToolNativeInstance | null = libentry.openImage(imagePath) as ExifToolNativeInstance | null;
      if (!exifTool) {
        return undefined;
      }

      const tagKey = LibExifTool.convertTagToKey(ifd, tag);
      const value: string = libentry.getExifField(exifTool, tagKey);
      
      hilog.info(0xFF00, TAG, `EXIF entry value: ${value ?? 'not found'}`);
      return value || undefined;
    } catch (error) {
      hilog.error(0xFF00, TAG, `Failed to get EXIF entry: ${error}`);
      return undefined;
    }
  }

  private static convertTagToKey(ifd: number, tag: number): string {
    const ifdPrefixes: string[] = ['Exif.Image.', 'Exif.Thumbnail.', 'Exif.Photo.', 'Exif.GPSInfo.', 'Exif.Interoperability.'];
    const prefix = ifdPrefixes[ifd] || 'Exif.Image.';
    
    const tagNames: Record<number, string> = {
      0x0100: 'ImageWidth',
      0x0101: 'ImageLength',
      0x010f: 'Make',
      0x0110: 'Model',
      0x0112: 'Orientation',
      0x0132: 'DateTime',
      0x9003: 'DateTimeOriginal',
      0x9004: 'DateTimeDigitized',
      0x829a: 'ExposureTime',
      0x829d: 'FNumber',
      0x8827: 'ISOSpeedRatings',
      0x9201: 'ShutterSpeedValue',
      0x9202: 'ApertureValue',
      0x920a: 'FocalLength',
      0x9209: 'Flash',
      0x0002: 'GPSLatitude',
      0x0001: 'GPSLatitudeRef',
      0x0004: 'GPSLongitude',
      0x0003: 'GPSLongitudeRef',
      0x0006: 'GPSAltitude',
      0x0005: 'GPSAltitudeRef',
      0x0007: 'GPSTimeStamp',
      0x001d: 'GPSDateStamp'
    };
    
    const tagName = tagNames[tag] || `Tag${tag.toString(16)}`;
    return prefix + tagName;
  }

  static getImageInfo(imagePath: string): ImageInfo | null {
    try {
      hilog.info(0xFF00, TAG, `[getImageInfo] Entering function with path: ${imagePath}`);
      
      const exifData = LibExifTool.readExifData(imagePath);
      const keys = Object.keys(exifData);
      
      hilog.info(0xFF00, TAG, `[getImageInfo] exifData has ${keys.length} keys`);
      
      const widthStr = exifData['Exif.Image.ImageWidth'] || exifData['Exif.Photo.PixelXDimension'];
      const heightStr = exifData['Exif.Image.ImageLength'] || exifData['Exif.Photo.PixelYDimension'];
      const make = exifData['Exif.Image.Make'];
      const model = exifData['Exif.Image.Model'];
      const orientationStr = exifData['Exif.Image.Orientation'];
      const dateTime = exifData['Exif.Photo.DateTimeOriginal'] || exifData['Exif.Image.DateTime'];
      
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

      let latStr = exifData['Exif.GPSInfo.GPSLatitude'];
      let latRef = exifData['Exif.GPSInfo.GPSLatitudeRef'] || 'N';
      let lngStr = exifData['Exif.GPSInfo.GPSLongitude'];
      let lngRef = exifData['Exif.GPSInfo.GPSLongitudeRef'] || 'E';
      let altStr = exifData['Exif.GPSInfo.GPSAltitude'];

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
      const dateTime = exifData['Exif.Photo.DateTimeOriginal'] || exifData['Exif.Photo.DateTimeDigitized'] || exifData['Exif.Image.DateTime'] || '';
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
        make: exifData['Exif.Image.Make'] || '',
        model: exifData['Exif.Image.Model'] || ''
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
        exposureTime: exifData['Exif.Photo.ExposureTime'] || '',
        fNumber: exifData['Exif.Photo.FNumber'] || '',
        iso: exifData['Exif.Photo.ISOSpeedRatings'] || '',
        focalLength: exifData['Exif.Photo.FocalLength'] || '',
        flash: exifData['Exif.Photo.Flash'] || ''
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
      const exifTool: ExifToolNativeInstance | null = libentry.openImage(imagePath) as ExifToolNativeInstance | null;
      if (!exifTool) {
        return false;
      }
      return libentry.hasExifData(exifTool);
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
      const readableInfo: Record<string, string> = {};

      const tagKeyToName: Record<string, string> = {
        'Exif.Image.ImageWidth': 'ImageWidth',
        'Exif.Image.ImageLength': 'ImageLength',
        'Exif.Image.Make': 'Make',
        'Exif.Image.Model': 'Model',
        'Exif.Image.Orientation': 'Orientation',
        'Exif.Image.DateTime': 'DateTime',
        'Exif.Photo.DateTimeOriginal': 'DateTimeOriginal',
        'Exif.Photo.DateTimeDigitized': 'DateTimeDigitized',
        'Exif.Photo.ExposureTime': 'ExposureTime',
        'Exif.Photo.FNumber': 'FNumber',
        'Exif.Photo.ISOSpeedRatings': 'ISOSpeedRatings',
        'Exif.Photo.ShutterSpeedValue': 'ShutterSpeedValue',
        'Exif.Photo.ApertureValue': 'ApertureValue',
        'Exif.Photo.FocalLength': 'FocalLength',
        'Exif.Photo.Flash': 'Flash',
        'Exif.GPSInfo.GPSLatitude': 'GPSLatitude',
        'Exif.GPSInfo.GPSLatitudeRef': 'GPSLatitudeRef',
        'Exif.GPSInfo.GPSLongitude': 'GPSLongitude',
        'Exif.GPSInfo.GPSLongitudeRef': 'GPSLongitudeRef',
        'Exif.GPSInfo.GPSAltitude': 'GPSAltitude',
        'Exif.GPSInfo.GPSAltitudeRef': 'GPSAltitudeRef'
      };

      Object.keys(exifData).forEach((key: string) => {
        const tagName = tagKeyToName[key] || key;
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