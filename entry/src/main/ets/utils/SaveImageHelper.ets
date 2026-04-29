/**
 * 图片保存助手
 * 使用 photoAccessHelper 的 showAssetsCreationDialog 实现无权限保存图片到系统相册
 * 适用于不需要预先申请 WRITE_IMAGEVIDEO 权限的场景
 */

import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { fileIo as fs } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

/**
 * 图片保存结果类型
 */
export interface SaveImageResult {
  success: boolean;
  message: string;
  assetUri?: string;
}

/**
 * 图片保存助手类
 */
export class SaveImageHelper {
  private static readonly TAG = 'SaveImageHelper';

  /**
   * 将 PixelMap 转换为二进制流（JPEG格式）
   * @param pixelMap 像素图对象
   * @param quality 图片质量 0-100
   * @returns Promise<ArrayBuffer> 二进制数据
   */
  static async pixelMapToBuffer(pixelMap: image.PixelMap, quality: number = 95): Promise<ArrayBuffer> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `pixelMapToBuffer: quality=${quality}`);

    try {
      const imagePacker = image.createImagePacker();
      const packOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: quality
      };

      const imageBuffer = await imagePacker.packToData(pixelMap, packOptions);
      hilog.info(0xFF00, SaveImageHelper.TAG, `pixelMapToBuffer: success, size=${imageBuffer.byteLength}`);
      return imageBuffer;
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, SaveImageHelper.TAG, `pixelMapToBuffer failed: ${err.code}, ${err.message}`);
      throw new Error(`Failed to pack image: ${err.message}`);
    }
  }

  /**
   * 将 ImageSource 转换为二进制流（JPEG格式）
   * @param imageSource 图片源对象
   * @param quality 图片质量 0-100
   * @returns Promise<ArrayBuffer> 二进制数据
   */
  static async imageSourceToBuffer(imageSource: image.ImageSource, quality: number = 95): Promise<ArrayBuffer> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `imageSourceToBuffer: quality=${quality}`);

    try {
      const pixelMap = await imageSource.createPixelMap();
      try {
        return await SaveImageHelper.pixelMapToBuffer(pixelMap, quality);
      } finally {
        pixelMap.release();
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, SaveImageHelper.TAG, `imageSourceToBuffer failed: ${err.code}, ${err.message}`);
      throw new Error(`Failed to convert image source: ${err.message}`);
    }
  }

  /**
   * 将图片数据保存到应用沙箱临时文件
   * @param context 应用上下文
   * @param imageBuffer 图片二进制数据
   * @returns Promise<string> 临时文件路径
   */
  private static async createTempFile(context: Context, imageBuffer: ArrayBuffer): Promise<string> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `createTempFile: bufferSize=${imageBuffer.byteLength}`);

    const filesDir = context.filesDir;
    const fileName = `temp_photo_${Date.now()}.jpg`;
    const tempPath = `${filesDir}/${fileName}`;

    const file = fs.openSync(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
    try {
      const uint8Data = new Uint8Array(imageBuffer);
      fs.writeSync(file.fd, uint8Data.buffer);
      hilog.info(0xFF00, SaveImageHelper.TAG, `createTempFile: saved to ${tempPath}`);
      return tempPath;
    } finally {
      fs.closeSync(file);
    }
  }

  /**
   * 使用 showAssetsCreationDialog 弹窗授权方式保存图片到相册
   * 此方式无需预先申请 WRITE_IMAGEVIDEO 权限
   * @param context 应用上下文
   * @param imageBuffer 图片二进制数据
   * @returns Promise<SaveImageResult> 保存结果
   */
  static async saveBufferToAlbum(context: Context, imageBuffer: ArrayBuffer): Promise<SaveImageResult> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: bufferSize=${imageBuffer.byteLength}`);

    let tempPath: string = '';

    try {
      // 1. 先将二进制数据写入应用沙箱临时文件
      tempPath = await SaveImageHelper.createTempFile(context, imageBuffer);

      // 2. 使用 photoAccessHelper 的弹窗授权方式
      const helper = photoAccessHelper.getPhotoAccessHelper(context);

      // 配置保存选项
      let photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [{
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE,
      }];

      // 调用弹窗授权接口，获取目标URI
      let desFileUris: Array<string> = await helper.showAssetsCreationDialog([tempPath], photoCreationConfigs);

      if (desFileUris.length > 0) {
        hilog.info(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: Got target uri=${desFileUris[0]}`);
        
        // 将临时文件复制到目标URI
        let srcFile = fs.openSync(tempPath, fs.OpenMode.READ_ONLY);
        let desFile = fs.openSync(desFileUris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);
        
        try {
          fs.copyFileSync(srcFile.fd, desFile.fd);
          hilog.info(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: File copied successfully`);
        } finally {
          fs.closeSync(srcFile);
          fs.closeSync(desFile);
        }
        
        return {
          success: true,
          message: '图片已保存到相册',
          assetUri: desFileUris[0]
        };
      } else {
        hilog.error(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: User denied authorization`);
        return {
          success: false,
          message: '用户拒绝授权'
        };
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum failed: ${err.code}, ${err.message}`);
      return {
        success: false,
        message: `保存失败: ${err.message}`
      };
    } finally {
      // 删除临时文件
      if (tempPath) {
        try {
          fs.unlinkSync(tempPath);
          hilog.info(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: Temp file deleted`);
        } catch (e) {
          hilog.warn(0xFF00, SaveImageHelper.TAG, `saveBufferToAlbum: Failed to delete temp file`);
        }
      }
    }
  }

  /**
   * 将图片URI对应的图片保存到相册（自动处理EXIF修改）
   * @param context 应用上下文
   * @param imageSource 包含修改后EXIF的ImageSource
   * @returns Promise<SaveImageResult> 保存结果
   */
  static async saveImageSourceToAlbum(context: Context, imageSource: image.ImageSource): Promise<SaveImageResult> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `saveImageSourceToAlbum: starting`);

    let tempPath: string = '';

    try {
      const filesDir = context.filesDir;
      tempPath = filesDir + '/temp_exif_' + Date.now() + '.jpg';

      hilog.info(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: packing to ' + tempPath);

      const packingOptions: image.PackingOption = {
        format: 'image/jpeg',
        quality: 95,
        needsPackProperties: true
      };

      const file = fs.openSync(tempPath, fs.OpenMode.WRITE_ONLY | fs.OpenMode.CREATE);
      try {
        const imagePackerApi = image.createImagePacker();
        await imagePackerApi.packToFile(imageSource, file.fd, packingOptions);
        hilog.info(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: packToFile completed');
      } finally {
        fs.closeSync(file);
      }

      const helper = photoAccessHelper.getPhotoAccessHelper(context);

      const photoCreationConfigs: Array<photoAccessHelper.PhotoCreationConfig> = [{
        fileNameExtension: 'jpg',
        photoType: photoAccessHelper.PhotoType.IMAGE,
      }];

      let desFileUris: Array<string> = await helper.showAssetsCreationDialog([tempPath], photoCreationConfigs);

      if (desFileUris.length > 0) {
        hilog.info(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: Got target uri=' + desFileUris[0]);

        let srcFile = fs.openSync(tempPath, fs.OpenMode.READ_ONLY);
        let desFile = fs.openSync(desFileUris[0], fs.OpenMode.READ_WRITE | fs.OpenMode.CREATE);

        try {
          fs.copyFileSync(srcFile.fd, desFile.fd);
          hilog.info(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: File copied successfully');
        } finally {
          fs.closeSync(srcFile);
          fs.closeSync(desFile);
        }

        return {
          success: true,
          message: '图片已保存到相册',
          assetUri: desFileUris[0]
        };
      } else {
        hilog.error(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: User denied authorization');
        return {
          success: false,
          message: '用户拒绝授权'
        };
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum failed: ' + err.code + ', ' + err.message);
      return {
        success: false,
        message: '保存失败: ' + err.message
      };
    } finally {
      if (tempPath) {
        try {
          fs.unlinkSync(tempPath);
          hilog.info(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: Temp file deleted');
        } catch (e) {
          hilog.warn(0xFF00, SaveImageHelper.TAG, 'saveImageSourceToAlbum: Failed to delete temp file');
        }
      }
    }
  }

  /**
   * 将本地文件保存到相册（使用弹窗授权方式）
   * @param context 应用上下文
   * @param filePath 本地文件路径（file:// 或绝对路径）
   * @returns Promise<SaveImageResult> 保存结果
   */
  static async saveFileToAlbum(context: Context, filePath: string): Promise<SaveImageResult> {
    hilog.info(0xFF00, SaveImageHelper.TAG, `saveFileToAlbum: filePath=${filePath}`);

    let file: fs.File | undefined;

    try {
      // 读取文件内容
      file = fs.openSync(filePath, fs.OpenMode.READ_ONLY);

      // 获取文件大小
      const stat = fs.statSync(filePath);
      const imageBuffer = new ArrayBuffer(stat.size);

      fs.readSync(file.fd, imageBuffer);
      fs.closeSync(file);
      file = undefined;

      // 保存到相册
      return await SaveImageHelper.saveBufferToAlbum(context, imageBuffer);
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, SaveImageHelper.TAG, `saveFileToAlbum failed: ${err.code}, ${err.message}`);
      return {
        success: false,
        message: `保存失败: ${err.message}`
      };
    } finally {
      if (file !== undefined) {
        try {
          fs.closeSync(file);
        } catch (e) {}
      }
    }
  }
}

export default SaveImageHelper;