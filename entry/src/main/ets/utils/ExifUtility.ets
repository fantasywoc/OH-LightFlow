/**
 * 图像Exif信息读写工具
 * 提供图片Exif信息的读取、修改、保存功能
 * 更新时间: 2026-04-28
 */

import { image } from '@kit.ImageKit';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * Exif属性类型定义
 */
export interface ExifProperty {
  key: image.PropertyKey;
  label: string;
  value?: string;
  editable: boolean;  // 是否可编辑
}

/**
 * GPS坐标类型定义
 */
export interface GPSCoordinates {
  latitude: number;
  longitude: number;
}

/**
 * Exif信息工具类
 */
export class ExifUtility {
  private static readonly TAG = 'ExifUtility';
  
  /**
   * 常用Exif属性列表
   */
  private static readonly COMMON_EXIF_PROPERTIES: ExifProperty[] = [
    { key: image.PropertyKey.GPS_LATITUDE, label: 'GPS纬度', editable: true },
    { key: image.PropertyKey.GPS_LATITUDE_REF, label: 'GPS纬度参考', editable: true },
    { key: image.PropertyKey.GPS_LONGITUDE, label: 'GPS经度', editable: true },
    { key: image.PropertyKey.GPS_LONGITUDE_REF, label: 'GPS经度参考', editable: true },
    { key: image.PropertyKey.ORIENTATION, label: '旋转方向', editable: true },
    { key: image.PropertyKey.IMAGE_WIDTH, label: '图片宽度', editable: false },
    { key: image.PropertyKey.IMAGE_LENGTH, label: '图片高度', editable: false },
    { key: image.PropertyKey.DATE_TIME_ORIGINAL, label: '拍摄时间', editable: true },
    { key: image.PropertyKey.MAKE, label: '相机品牌', editable: true },
    { key: image.PropertyKey.MODEL, label: '相机型号', editable: true },
    { key: image.PropertyKey.F_NUMBER, label: '光圈值', editable: true },
    { key: image.PropertyKey.ISO_SPEED_RATINGS, label: 'ISO感光度', editable: true },
    { key: image.PropertyKey.EXPOSURE_TIME, label: '曝光时间', editable: true },
    { key: image.PropertyKey.FOCAL_LENGTH, label: '焦距', editable: true },
  ];

  /**
   * 从URI创建ImageSource
   * @param uri 图片URI
   * @param writable 是否以读写模式打开（修改EXIF时需要）
   * @returns ImageSource对象
   */
  static createImageSourceFromUri(uri: string, writable: boolean = false): image.ImageSource {
    hilog.info(0xFF00, ExifUtility.TAG, `createImageSourceFromUri: ${uri}, writable: ${writable}`);
    
    try {
      // 直接使用 URI 打开文件
      const mode = writable ? fs.OpenMode.READ_WRITE : fs.OpenMode.READ_ONLY;
      const file = fs.openSync(uri, mode);
      let imageSource: image.ImageSource;
      try {
        imageSource = image.createImageSource(file.fd);
      } finally {
        fs.closeSync(file);
      }
      return imageSource;
    } catch (error) {
      hilog.error(0xFF00, ExifUtility.TAG, `createImageSourceFromUri: Failed to open URI: ${error}`);
      throw new Error(`Failed to open URI ${uri}: ${error}`);
    }
  }

  /**
   * 获取指定key的Exif信息
   * @param imageSourceApi ImageSource对象
   * @param key Exif属性key
   * @param defaultValue 默认值
   * @returns Promise<string> 属性值
   */
  static async getExif(
    imageSourceApi: image.ImageSource | undefined,
    key: image.PropertyKey,
    defaultValue: string = ''
  ): Promise<string> {
    if (!imageSourceApi) {
      hilog.warn(0xFF00, ExifUtility.TAG, 'getExif: imageSourceApi is undefined');
      return defaultValue;
    }

    try {
      const options: image.ImagePropertyOptions = { index: 0, defaultValue };
      const data = await imageSourceApi.getImageProperty(key, options);
      hilog.info(0xFF00, ExifUtility.TAG, `getExif: ${key} = ${data}`);
      return data;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, ExifUtility.TAG, `getExif failed: ${key}, ${err.code}, ${err.message}`);
      return defaultValue;
    }
  }

  /**
   * 批量获取Exif信息
   * @param imageSourceApi ImageSource对象
   * @param properties 要获取的属性列表
   * @returns Promise<ExifProperty[]> 完整的属性列表
   */
  static async getExifProperties(
    imageSourceApi: image.ImageSource | undefined,
    properties?: ExifProperty[]
  ): Promise<ExifProperty[]> {
    if (!imageSourceApi) {
      hilog.warn(0xFF00, ExifUtility.TAG, 'getExifProperties: imageSourceApi is undefined');
      return properties || [];
    }

    const targetProperties = properties || ExifUtility.COMMON_EXIF_PROPERTIES;
    const result: ExifProperty[] = [];

    for (const prop of targetProperties) {
      const value = await ExifUtility.getExif(imageSourceApi, prop.key);
      result.push({
        key: prop.key,
        label: prop.label,
        editable: prop.editable,
        value: value
      });
    }

    return result;
  }

  /**
   * 获取常用Exif信息（简化版）
   * @param imageSourceApi ImageSource对象
   * @returns Promise<ExifProperty[]>
   */
  static async getCommonExifProperties(imageSourceApi: image.ImageSource | undefined): Promise<ExifProperty[]> {
    return await ExifUtility.getExifProperties(imageSourceApi, ExifUtility.COMMON_EXIF_PROPERTIES);
  }

  /**
   * 修改指定key的Exif信息
   * @param imageSourceApi ImageSource对象
   * @param key Exif属性key
   * @param value 新的值
   * @returns Promise<boolean> 是否成功
   */
  static async modifyExif(
    imageSourceApi: image.ImageSource | undefined,
    key: image.PropertyKey,
    value: string
  ): Promise<boolean> {
    if (!imageSourceApi) {
      hilog.warn(0xFF00, ExifUtility.TAG, 'modifyExif: imageSourceApi is undefined');
      return false;
    }

    try {
      hilog.info(0xFF00, ExifUtility.TAG, `modifyExif: setting ${key} = ${value}`);
      await imageSourceApi.modifyImageProperty(key, value);
      
      // 验证修改是否成功（忽略空格差异）
      const verifyValue = await ExifUtility.getExif(imageSourceApi, key);
      // 比较时去除空格，因为系统返回的值可能包含空格
      const normalizedValue = value.replace(/\s/g, '');
      const normalizedVerifyValue = verifyValue.replace(/\s/g, '');
      const success = normalizedValue === normalizedVerifyValue;
      
      hilog.info(0xFF00, ExifUtility.TAG, `modifyExif: ${success ? 'success' : 'verify failed'}, ${key} = ${verifyValue}`);
      return success;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, ExifUtility.TAG, `modifyExif failed: ${key}, ${err.code}, ${err.message}`);
      return false;
    }
  }

  /**
   * 批量修改Exif信息
   * @param imageSourceApi ImageSource对象
   * @param properties 要修改的属性列表
   * @returns Promise<boolean> 是否全部成功
   */
  static async modifyExifProperties(
    imageSourceApi: image.ImageSource | undefined,
    properties: ExifProperty[]
  ): Promise<boolean> {
    if (!imageSourceApi) {
      hilog.warn(0xFF00, ExifUtility.TAG, 'modifyExifProperties: imageSourceApi is undefined');
      return false;
    }

    let allSuccess = true;
    for (const prop of properties) {
      if (prop.editable && prop.value !== undefined) {
        const success = await ExifUtility.modifyExif(imageSourceApi, prop.key, prop.value);
        if (!success) {
          allSuccess = false;
        }
      }
    }
    return allSuccess;
  }

  /**
   * 修改GPS坐标（方便方法）
   * @param imageSourceApi ImageSource对象
   * @param latitude 纬度（小数）
   * @param longitude 经度（小数）
   * @returns Promise<boolean> 是否成功
   */
  static async modifyGPSCoordinates(
    imageSourceApi: image.ImageSource | undefined,
    latitude: number,
    longitude: number
  ): Promise<boolean> {
    if (!imageSourceApi) {
      return false;
    }

    try {
      // 将小数经纬度转换为度分秒格式
      const latDMS = ExifUtility.decimalToDMS(latitude);
      const lngDMS = ExifUtility.decimalToDMS(longitude);
      
      const latRef = latitude >= 0 ? 'N' : 'S';
      const lngRef = longitude >= 0 ? 'E' : 'W';

      hilog.info(0xFF00, ExifUtility.TAG, `modifyGPSCoordinates: ${latDMS} ${latRef}, ${lngDMS} ${lngRef}`);

      // 修改所有GPS相关属性
      const success1 = await ExifUtility.modifyExif(imageSourceApi, image.PropertyKey.GPS_LATITUDE, latDMS);
      const success2 = await ExifUtility.modifyExif(imageSourceApi, image.PropertyKey.GPS_LATITUDE_REF, latRef);
      const success3 = await ExifUtility.modifyExif(imageSourceApi, image.PropertyKey.GPS_LONGITUDE, lngDMS);
      const success4 = await ExifUtility.modifyExif(imageSourceApi, image.PropertyKey.GPS_LONGITUDE_REF, lngRef);

      return success1 && success2 && success3 && success4;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, ExifUtility.TAG, `modifyGPSCoordinates failed: ${err.code}, ${err.message}`);
      return false;
    }
  }

  /**
   * 将十进制度数转换为度分秒格式字符串
   * @param decimal 十进制度数
   * @returns 度分秒格式字符串，如 "30,15,30"
   */
  static decimalToDMS(decimal: number): string {
    const absDecimal = Math.abs(decimal);
    const degrees = Math.floor(absDecimal);
    const minutesDecimal = (absDecimal - degrees) * 60;
    const minutes = Math.floor(minutesDecimal);
    const seconds = Math.round((minutesDecimal - minutes) * 60 * 1000) / 1000;
    
    return `${degrees},${minutes},${seconds}`;
  }

  /**
   * 将度分秒格式转换为十进制度数
   * @param dms 度分秒格式字符串，如 "30,15,30"
   * @returns 十进制度数
   */
  static dmsToDecimal(dms: string): number {
    const parts = dms.split(',').map(parseFloat);
    if (parts.length < 3) return 0;
    
    const degrees = parts[0];
    const minutes = parts[1] || 0;
    const seconds = parts[2] || 0;
    
    return degrees + minutes / 60 + seconds / 3600;
  }

  /**
   * 读取GPS坐标并转换为小数格式
   * @param imageSourceApi ImageSource对象
   * @returns Promise<GPSCoordinates> 坐标对象
   */
  static async getGPSCoordinates(
    imageSourceApi: image.ImageSource | undefined
  ): Promise<GPSCoordinates> {
    if (!imageSourceApi) {
      return { latitude: 0, longitude: 0 } as GPSCoordinates;
    }

    try {
      const latStr = await ExifUtility.getExif(imageSourceApi, image.PropertyKey.GPS_LATITUDE);
      const latRef = await ExifUtility.getExif(imageSourceApi, image.PropertyKey.GPS_LATITUDE_REF, 'N');
      const lngStr = await ExifUtility.getExif(imageSourceApi, image.PropertyKey.GPS_LONGITUDE);
      const lngRef = await ExifUtility.getExif(imageSourceApi, image.PropertyKey.GPS_LONGITUDE_REF, 'E');

      if (!latStr || !lngStr) {
        hilog.warn(0xFF00, ExifUtility.TAG, 'getGPSCoordinates: GPS data not found');
        return { latitude: 0, longitude: 0 } as GPSCoordinates;
      }

      let latitude = ExifUtility.dmsToDecimal(latStr);
      let longitude = ExifUtility.dmsToDecimal(lngStr);

      if (latRef === 'S') latitude = -latitude;
      if (lngRef === 'W') longitude = -longitude;

      hilog.info(0xFF00, ExifUtility.TAG, `getGPSCoordinates: ${latitude}, ${longitude}`);
      return { latitude, longitude } as GPSCoordinates;
    } catch (error) {
      hilog.error(0xFF00, ExifUtility.TAG, `getGPSCoordinates failed: ${error}`);
      return { latitude: 0, longitude: 0 } as GPSCoordinates;
    }
  }

  /**
   * 将修改后的Exif信息保存到文件
   * @param imageSourceApi ImageSource对象（包含修改后的Exif）
   * @param sourceUri 源图片URI
   * @param targetUri 目标URI（可选，不传则覆盖源文件）
   * @returns Promise<boolean> 是否成功
   */
  static async saveExifToFile(
    imageSourceApi: image.ImageSource | undefined,
    sourceUri: string,
    targetUri?: string
  ): Promise<boolean> {
    if (!imageSourceApi) {
      hilog.warn(0xFF00, ExifUtility.TAG, 'saveExifToFile: imageSourceApi is undefined');
      return false;
    }

    try {
      const outputUri = targetUri || sourceUri;
      hilog.info(0xFF00, ExifUtility.TAG, `saveExifToFile: ${outputUri}`);
      
      const fileObj = new fileUri.FileUri(outputUri);
      const file = fs.openSync(fileObj.path, fs.OpenMode.READ_WRITE);
      
      try {
        const imagePacker = image.createImagePacker();
        const packOpts: image.PackingOption = {
          format: 'image/jpeg',
          quality: 90
        };
        
        const pixelMap = await imageSourceApi.createPixelMap();
        const data = await imagePacker.packing(pixelMap, packOpts);
        
        // 修复ArrayBuffer问题，使用Uint8Array
        const uint8Data = new Uint8Array(data);
        fs.writeSync(file.fd, uint8Data.buffer);
        
        pixelMap.release();
        
        hilog.info(0xFF00, ExifUtility.TAG, 'saveExifToFile: success');
        return true;
      } finally {
        fs.closeSync(file);
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, ExifUtility.TAG, `saveExifToFile failed: ${err.code}, ${err.message}`);
      return false;
    }
  }

  /**
   * 获取可编辑的Exif属性列表
   * @returns ExifProperty[] 可编辑属性列表
   */
  static getEditableProperties(): ExifProperty[] {
    return ExifUtility.COMMON_EXIF_PROPERTIES.filter(prop => prop.editable);
  }

  /**
   * 获取所有支持的Exif属性key
   * @returns image.PropertyKey[]
   */
  static getAllPropertyKeys(): image.PropertyKey[] {
    return Object.values(image.PropertyKey);
  }

  /**
   * 更新媒体库图片的GPS坐标（处理只读限制）
   * @param uri 媒体库图片URI
   * @param latitude 纬度
   * @param longitude 经度
   * @returns Promise<boolean> 是否成功，成功时返回修改后的文件路径
   */
  static async updateMediaGPS(uri: string, latitude: number, longitude: number): Promise<boolean> {
    hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: uri=${uri}, lat=${latitude}, lng=${longitude}`);

    let sourceFile: fs.File | undefined;
    let tempFile: fs.File | undefined;
    let outputFile: fs.File | undefined;

    try {
      // 媒体库图片无法直接修改，需要先复制到应用私有目录
      // 1. 获取图片文件名
      const uriParts = uri.split('/');
      const fileName = uriParts[uriParts.length - 1] || `photo_${Date.now()}.jpg`;
      
      // 2. 构建应用私有目录路径
      const filesDir = '/data/storage/el2/base/haps/entry/files';
      const tempPath = `${filesDir}/temp_${fileName}`;
      const newPath = `${filesDir}/${fileName}`;
      
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: tempPath=${tempPath}, newPath=${newPath}`);

      // 3. 先将原始文件复制到临时位置（保持原始数据）
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Copying source file to temp...`);
      sourceFile = fs.openSync(uri, fs.OpenMode.READ_ONLY);
      tempFile = fs.openSync(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
      
      // 读取源文件内容并写入临时文件
      const bufferSize = 8192;
      const buffer = new ArrayBuffer(bufferSize);
      let bytesRead = 0;
      do {
        bytesRead = fs.readSync(sourceFile.fd, buffer);
        if (bytesRead > 0) {
          const view = new Uint8Array(buffer, 0, bytesRead);
          fs.writeSync(tempFile.fd, view.buffer);
        }
      } while (bytesRead > 0);
      
      // 关闭源文件和临时文件
      fs.closeSync(sourceFile);
      sourceFile = undefined;
      fs.closeSync(tempFile);
      tempFile = undefined;
      
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: File copied to temp`);

      // 4. 以读写模式打开临时文件进行修改
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Opening temp file for modification...`);
      tempFile = fs.openSync(tempPath, fs.OpenMode.READ_WRITE);
      const imageSource = image.createImageSource(tempFile.fd);

      // 5. 修改GPS坐标
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Modifying GPS...`);
      const modifySuccess = await ExifUtility.modifyGPSCoordinates(imageSource, latitude, longitude);
      if (!modifySuccess) {
        hilog.error(0xFF00, ExifUtility.TAG, `updateMediaGPS: Failed to modify GPS`);
        return false;
      }

      // 6. 将修改后的图片保存到最终位置
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Saving to final location...`);
      const imagePacker = image.createImagePacker();
      const packOpts: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95
      };
      const pixelMap = await imageSource.createPixelMap();
      const data = await imagePacker.packing(pixelMap, packOpts);
      pixelMap.release();
      
      // 关闭临时文件
      fs.closeSync(tempFile);
      tempFile = undefined;
      
      // 写入最终文件
      outputFile = fs.openSync(newPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
      const uint8Data = new Uint8Array(data);
      fs.writeSync(outputFile.fd, uint8Data.buffer);
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Saved to ${newPath}`);

      // 7. 删除临时文件
      fs.unlinkSync(tempPath);
      hilog.info(0xFF00, ExifUtility.TAG, `updateMediaGPS: Temp file deleted`);

      // 8. 返回成功，但需要调用方更新URI引用
      return true;
    } catch (error) {
      hilog.error(0xFF00, ExifUtility.TAG, `updateMediaGPS failed: ${error}`);
      return false;
    } finally {
      // 确保所有文件被关闭
      if (sourceFile !== undefined) {
        try { fs.closeSync(sourceFile); } catch (e) {}
      }
      if (tempFile !== undefined) {
        try { fs.closeSync(tempFile); } catch (e) {}
      }
      if (outputFile !== undefined) {
        try { fs.closeSync(outputFile); } catch (e) {}
      }
    }
  }
}

export default ExifUtility;
