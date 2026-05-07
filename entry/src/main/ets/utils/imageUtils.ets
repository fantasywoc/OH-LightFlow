import { image } from '@kit.ImageKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { UIContext } from '@kit.ArkUI';  // 确保导入 UIContext
import { fileIo as fs } from '@kit.CoreFileKit';

// import { image } from '@kit.ImageKit';
// import fs from '@ohos.file.fs';
// import { BusinessError } from '@kit.BasicServicesKit';

export interface PhotoInfoData {
  fileName: string;
  date: string;
  resolution: string;
  fileSize: string;
  device: string;
  format: string;
  hdr: string;
  focalLength: string;
  iso: string;
  shutter: string;
  ev: string;
  aperture: string;
  colorMode: string;
  focusMode: string;
  whiteBalance: string;
  flash: string;
  path: string;
}

export async function getOriginalExif(imageUri: string, context: UIContext): Promise<string> {
  let file: fs.File | null = null;
  let imageSource: image.ImageSource | null = null;

  const propertyKeys: Array<image.PropertyKey> = [
    image.PropertyKey.IMAGE_WIDTH,
    image.PropertyKey.IMAGE_LENGTH,
    image.PropertyKey.BITS_PER_SAMPLE,
    image.PropertyKey.COMPRESSION,
    image.PropertyKey.PHOTOMETRIC_INTERPRETATION,
    image.PropertyKey.ORIENTATION,
    image.PropertyKey.DATE_TIME,
    image.PropertyKey.MAKE,
    image.PropertyKey.MODEL,
    image.PropertyKey.DATE_TIME_ORIGINAL,
    image.PropertyKey.EXPOSURE_TIME,
    image.PropertyKey.F_NUMBER,
    image.PropertyKey.ISO_SPEED_RATINGS,
    image.PropertyKey.SHUTTER_SPEED,
    image.PropertyKey.APERTURE_VALUE,
    image.PropertyKey.FOCAL_LENGTH,
    image.PropertyKey.FLASH,
    image.PropertyKey.METERING_MODE,
    image.PropertyKey.WHITE_BALANCE,
    image.PropertyKey.GPS_LATITUDE_REF,
    image.PropertyKey.GPS_LATITUDE,
    image.PropertyKey.GPS_LONGITUDE_REF,
    image.PropertyKey.GPS_LONGITUDE,
  ];

  console.info('[systemdebug] >>> getOriginalExif 开始执行');
  console.info('[systemdebug] 输入参数 imageUri:', imageUri);

  try {
    console.info('[systemdebug] 步骤1: 判断URI类型');
    
    if (imageUri.startsWith('file:///media/')) {
      console.info('[systemdebug] 检测到媒体库URI，直接使用 URI 创建 ImageSource');
      imageSource = image.createImageSource(imageUri);
      console.info('[systemdebug] 步骤1完成: 使用媒体库URI创建 imageSource');
    } else {
      console.info('[systemdebug] 检测到普通文件URI，使用 fs.openSync 打开');
      file = fs.openSync(imageUri, fs.OpenMode.READ_ONLY);
      console.info('[systemdebug] 步骤1完成: fd =', file.fd);

      console.info('[systemdebug] 步骤2: 创建 ImageSource');
      imageSource = image.createImageSource(file.fd);
    }

    console.info('[systemdebug] imageSource =', imageSource ? '成功' : '失败');
    if (!imageSource) {
      console.error('[systemdebug] 创建 imageSource 失败');
      return JSON.stringify({ error: '无法创建图片源 (createImageSource failed)' });
    }

    console.info('[systemdebug] 步骤3: 获取指定 EXIF 信息', propertyKeys);

    const allProperties: Record<string, string | null> = await imageSource.getImageProperties(propertyKeys);

    console.info('[systemdebug] 步骤3完成: 获取到属性数量 =', Object.keys(allProperties).length);
    console.info('[systemdebug] === 图片指定的 EXIF 信息 ===');
    
    console.info('[systemdebug] GPSLatitude:', allProperties['GPSLatitude']);
    console.info('[systemdebug] GPSLongitude:', allProperties['GPSLongitude']);
    console.info('[systemdebug] GPSLatitudeRef:', allProperties['GPSLatitudeRef']);
    console.info('[systemdebug] GPSLongitudeRef:', allProperties['GPSLongitudeRef']);
    console.info('[systemdebug] DateTime:', allProperties['DateTime']);
    console.info('[systemdebug] Make:', allProperties['Make']);
    console.info('[systemdebug] Model:', allProperties['Model']);
    
    const exifString = JSON.stringify(allProperties);
    console.info('[systemdebug] EXIF_JSON:', exifString.substring(0, 500) + (exifString.length > 500 ? '...' : ''));

    console.info('[systemdebug] >>> getOriginalExif 执行成功');
    return JSON.stringify(allProperties, null, 2);
  } catch (err) {
    console.error('[systemdebug] >>> getOriginalExif 执行异常');
    console.error('[systemdebug] 异常类型:', typeof err);
    console.error('[systemdebug] 异常信息:', String(err));
    console.error('[systemdebug] 异常详情:', JSON.stringify(err));
    return JSON.stringify({ error: '获取 EXIF 异常', details: String(err) });
  } finally {
    console.info('[systemdebug] 步骤4: 释放资源');
    if (imageSource) {
      console.info('[systemdebug] 释放 imageSource');
      imageSource.release();
    }
    if (file) {
      console.info('[systemdebug] 关闭文件描述符 fd =', file.fd);
      fs.closeSync(file);
    }
    console.info('[systemdebug] >>> getOriginalExif 执行完毕');
  }
}

export function parseExifToPhotoInfoData(exifJson: string, filePath: string): PhotoInfoData {
  console.info('[systemdebug] parseExifToPhotoInfoData 开始解析, filePath:', filePath);

  let exifData: Record<string, string | null> = {};
  try {
    exifData = JSON.parse(exifJson);
    console.info('[systemdebug] JSON 解析成功');
  } catch (e) {
    console.error('[systemdebug] JSON 解析失败:', e);
    return createEmptyPhotoInfoData(filePath);
  }

  if (exifData.error) {
    console.error('[systemdebug] EXIF 数据包含错误:', exifData.error);
    return createEmptyPhotoInfoData(filePath);
  }

  const fileName = extractFileName(filePath);
  const date = formatExifDate(exifData['DateTimeOriginal'] || exifData['DateTime'] || '');
  const resolution = `${exifData['ImageWidth'] || '0'} × ${exifData['ImageLength'] || '0'}`;
  const device = formatDevice(exifData['Make'], exifData['Model']);
  const format = extractFileFormat(filePath);
  const focalLength = formatFocalLength(exifData['FocalLength']);
  const iso = exifData['ISOSpeedRatings'] || '';
  const shutter = formatShutter(exifData['ExposureTime'] || exifData['ShutterSpeed']);
  const aperture = formatAperture(exifData['FNumber'] || exifData['ApertureValue']);
  const flash = formatFlash(exifData['Flash']);
  const whiteBalance = formatWhiteBalance(exifData['WhiteBalance']);
  const hdr = checkHdr(exifData);
  const ev = formatExposureCompensation(exifData['ExposureCompensation']);

  console.info('[systemdebug] 解析结果:', {
    fileName, date, resolution, device, format, focalLength, iso, shutter, aperture, flash, whiteBalance, hdr, ev
  });

  return {
    fileName: fileName,
    date: date,
    resolution: resolution,
    fileSize: '',
    device: device,
    format: format,
    hdr: hdr,
    focalLength: focalLength,
    iso: iso,
    shutter: shutter,
    ev: ev,
    aperture: aperture,
    colorMode: '',
    focusMode: '',
    whiteBalance: whiteBalance,
    flash: flash,
    path: filePath
  };
}

function createEmptyPhotoInfoData(filePath: string): PhotoInfoData {
  return {
    fileName: extractFileName(filePath),
    date: '',
    resolution: '',
    fileSize: '',
    device: '',
    format: extractFileFormat(filePath),
    hdr: '',
    focalLength: '',
    iso: '',
    shutter: '',
    ev: '',
    aperture: '',
    colorMode: '',
    focusMode: '',
    whiteBalance: '',
    flash: '',
    path: filePath
  };
}

function extractFileName(filePath: string): string {
  if (!filePath) return '';
  const parts = filePath.split('/');
  const name = parts[parts.length - 1] || '';
  const dotIndex = name.lastIndexOf('.');
  return dotIndex > 0 ? name.substring(0, dotIndex) : name;
}

function extractFileFormat(filePath: string): string {
  if (!filePath) return '';
  const ext = filePath.split('.').pop()?.toUpperCase() || '';
  const formatMap: Record<string, string> = {
    'JPG': 'JPEG',
    'JPEG': 'JPEG',
    'PNG': 'PNG',
    'GIF': 'GIF',
    'WEBP': 'WebP',
    'HEIC': 'HEIC',
    'HEIF': 'HEIF'
  };
  return formatMap[ext] || ext;
}

function formatExifDate(dateStr: string | null): string {
  if (!dateStr) return '';
  console.info('[systemdebug] 原始日期字符串:', dateStr);
  const parts = dateStr.split(' ');
  if (parts.length < 2) return dateStr;
  const dateParts = parts[0].split(':');
  const timeParts = parts[1].split(':');
  if (dateParts.length >= 3 && timeParts.length >= 3) {
    return `${dateParts[0]}年${dateParts[1]}月${dateParts[2]}日 ${timeParts[0]}:${timeParts[1]}`;
  }
  return dateStr;
}

function formatDevice(make: string | null, model: string | null): string {
  const makeStr = make || '';
  const modelStr = model || '';
  if (makeStr && modelStr) {
    return makeStr.includes(modelStr) ? makeStr : `${makeStr} ${modelStr}`;
  }
  return makeStr || modelStr;
}

function formatFocalLength(focal: string | null): string {
  if (!focal) return '';
  if (focal.includes('mm')) return focal;
  const num = parseFloat(focal);
  return isNaN(num) ? focal : `${num.toFixed(1)}mm`;
}

function formatShutter(shutter: string | null): string {
  if (!shutter) return '';
  if (shutter.includes('s') || shutter.includes('/')) return shutter;
  const num = parseFloat(shutter);
  if (isNaN(num)) return shutter;
  if (num >= 1) {
    return `${num.toFixed(1)}s`;
  }
  const denominator = Math.round(1 / num);
  return `1/${denominator}s`;
}

function formatAperture(aperture: string | null): string {
  if (!aperture) return '';
  if (aperture.includes('f') || aperture.includes('F')) return aperture;
  const num = parseFloat(aperture);
  return isNaN(num) ? aperture : `f/${num.toFixed(1)}`;
}

function formatFlash(flash: string | null): string {
  if (!flash) return '';
  const flashNum = parseInt(flash, 10);
  if (isNaN(flashNum)) return flash;
  const flashStates: Record<number, string> = {
    0: '未闪光',
    1: '闪光',
    5: '闪光（未检测到反射）',
    7: '闪光（检测到反射）',
    9: '闪光（强制）',
    13: '闪光（强制，未检测到反射）',
    15: '闪光（强制，检测到反射）',
    16: '闪光（关闭）',
    24: '自动（不闪光）',
    25: '自动（闪光）',
    29: '自动（闪光）',
    31: '自动（闪光）',
    65: '无闪光功能',
    73: '闪光（TTL）',
    77: '闪光（TTL，自动）',
    89: '闪光（TTL，自动）'
  };
  return flashStates[flashNum] || flash;
}

function formatExposureCompensation(ev: string | null): string {
  if (!ev) return '';
  if (ev.includes('EV')) {
    const match = ev.match(/([+-]?[\d.]+)\s*EV/i);
    if (match) {
      const num = parseFloat(match[1]);
      return !isNaN(num) ? `${num > 0 ? '+' : ''}${num.toFixed(1)} EV` : ev;
    }
    return ev;
  }
  const num = parseFloat(ev);
  return isNaN(num) ? ev : `${num > 0 ? '+' : ''}${num.toFixed(1)} EV`;
}

function formatWhiteBalance(wb: string | null): string {
  if (!wb) return '';
  const wbNum = parseInt(wb, 10);
  if (isNaN(wbNum)) return wb;
  return wbNum === 0 ? '自动' : '手动';
}

function checkHdr(exifData: Record<string, string | null>): string {
  if (exifData['ExposureTime'] && exifData['FNumber']) {
    return 'HDR';
  }
  return '';
}

export async function pickPhotos(maxSelectNumber: number = 9): Promise<string[]> {
  try {
    const photoPicker = new photoAccessHelper.PhotoViewPicker();
    const result: photoAccessHelper.PhotoSelectResult = await photoPicker.select({
      MIMEType: photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE,
      maxSelectNumber: maxSelectNumber
    });

    return result.photoUris ?? [];
  } catch (err) {
    console.error(`PhotoPicker failed: ${JSON.stringify(err)}`);
    return [];
  }
}

// export async function showToast(uiContext: UIContext, message: string, duration: number = 1500): Promise<void> {
//   try {
//     const promptActionInstance = uiContext.getPromptAction();
//     await promptActionInstance.openToast({
//       message: message,
//       duration: duration,
//     });
//   } catch (error) {
//     const err = error as BusinessError;
//     console.error(`showToast failed, code: ${err.code}, message: ${err.message}`);
//   }
// }