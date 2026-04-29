# ExifUtility 使用示例

## 目录
1. [基础导入](#基础导入)
2. [读取Exif信息](#读取exif信息)
3. [修改Exif信息](#修改exif信息)
4. [修改GPS坐标](#修改gps坐标)
5. [保存修改后保存文件](#保存修改后保存文件)

---

## 基础导入

```typescript
import ExifUtility, { ExifProperty, GPSCoordinates } from '../utils/ExifUtility';
import { image } from '@kit.ImageKit';
```

---

## 读取Exif信息

### 1. 读取单个属性

```typescript
// 从URI创建ImageSource
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 读取GPS纬度
const latitude = await ExifUtility.getExif(
  imageSource,
  image.PropertyKey.GPS_LATITUDE,
  '未设置'
);
console.log('GPS纬度: ' + latitude);
```

### 2. 读取所有常用属性

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 获取所有常用Exif信息
const exifProperties = await ExifUtility.getCommonExifProperties(imageSource);

// 遍历显示
for (const prop of exifProperties) {
  console.log(`${prop.label}: ${prop.value}`);
}
```

### 3. 读取GPS坐标（小数格式）

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

const coords: GPSCoordinates = await ExifUtility.getGPSCoordinates(imageSource);
console.log(`纬度: ${coords.latitude}`);
console.log(`经度: ${coords.longitude}`);
```

---

## 修改Exif信息

### 1. 修改单个属性

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 修改拍摄时间
const success = await ExifUtility.modifyExif(
  imageSource,
  image.PropertyKey.DATE_TIME_ORIGINAL,
  '2026:04:28 12:00:00'
);

if (success) {
  console.log('修改成功');
}
```

### 2. 批量修改

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 创建要修改的属性列表
const propertiesToModify: ExifProperty[] = [
  { 
    key: image.PropertyKey.MAKE,
    label: '相机品牌',
    value: 'Huawei',
    editable: true
  },
  {
    key: image.PropertyKey.MODEL,
    label: '相机型号',
    value: 'P70 Pro',
    editable: true
  }
];

const allSuccess = await ExifUtility.modifyExifProperties(
  imageSource,
  propertiesToModify
);
```

---

## 修改GPS坐标

### 直接修改GPS坐标（小数格式）

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 修改为北京天安门的坐标
const success = await ExifUtility.modifyGPSCoordinates(
  imageSource,
  39.9042,  // 纬度
  116.4074  // 经度
);

if (success) {
  console.log('GPS坐标修改成功');
}
```

---

## 保存修改后保存文件

### 覆盖原文件

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(uri);

// 先修改Exif
await ExifUtility.modifyGPSCoordinates(imageSource, 39.9042, 116.4074);

// 保存回原文件
const saveSuccess = await ExifUtility.saveExifToFile(
  imageSource,
  uri
);
```

### 保存为新文件

```typescript
const imageSource = ExifUtility.createImageSourceFromUri(sourceUri);

// 修改Exif...

// 保存为新文件
const saveSuccess = await ExifUtility.saveExifToFile(
  imageSource,
  sourceUri,
  targetUri
);
```

---

## 完整示例：在项目中使用

```typescript
import ExifUtility from '../utils/ExifUtility';

// 完整流程示例
async function updateImageGPS(uri: string, newLat: number, newLng: number) {
  try {
    // 1. 创建ImageSource
    const imageSource = ExifUtility.createImageSourceFromUri(uri);
    
    // 2. 读取当前坐标
    const oldCoords = await ExifUtility.getGPSCoordinates(imageSource);
    console.log(`原坐标: ${oldCoords.latitude}, ${oldCoords.longitude}`);
    
    // 3. 修改GPS坐标
    const modifySuccess = await ExifUtility.modifyGPSCoordinates(
      imageSource,
      newLat,
      newLng
    );
    
    if (!modifySuccess) {
      console.error('修改GPS失败');
      return false;
    }
    
    // 4. 保存修改
    const saveSuccess = await ExifUtility.saveExifToFile(
      imageSource,
      uri
    );
    
    if (saveSuccess) {
      console.log('GPS修改并保存成功');
      return true;
    }
    return false;
  } catch (error) {
    console.error('处理失败: ' + error);
    return false;
  }
}
```

---

## 在 Index.ets 中集成使用示例

```typescript
// 在 Index.ets 中添加修改图片GPS的功能
import ExifUtility from './utils/ExifUtility';

// 在选择图片后，允许修改GPS坐标
private async updateSelectedImageGPS(uri: string, latitude: number, longitude: number) {
  try {
    const imageSource = ExifUtility.createImageSourceFromUri(uri);
    
    // 修改GPS
    const success = await ExifUtility.modifyGPSCoordinates(imageSource, latitude, longitude);
    if (success) {
      // 保存文件
      await ExifUtility.saveExifToFile(imageSource, uri);
      showToast(this.getUIContext(), 'GPS信息已更新', 2000);
      
      // 重新读取并重新加载标记...
    }
  } catch (error) {
    console.error('更新GPS失败: ' + error);
  }
}
```

---

## 实用工具方法

### 获取可编辑属性列表

```typescript
const editableProps = ExifUtility.getEditableProperties();
console.log('可编辑的Exif属性:');
for (const prop of editableProps) {
  console.log(prop.key, prop.label);
}
```

### 坐标转换

```typescript
// 小数转度分秒
const dms = ExifUtility.decimalToDMS(39.9042);
console.log(dms); // "39,54,15.12"

// 度分秒转小数
const decimal = ExifUtility.dmsToDecimal("39,54,15.12");
console.log(decimal); // 39.9042
```

---

## 注意事项

1. **DNG格式** 仅支持读取，不支持修改
2. **图片格式支持**：JPEG、PNG、HEIF、WEBP、DNG
3. **操作前备份**：建议在修改Exif前先备份原文件
4. **权限**：确保有文件读写权限
5. **性能**：大文件处理可能需要较长时间
