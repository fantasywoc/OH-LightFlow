# LightFlowMap 项目详细分析文档

## 一、项目概述

### 1.1 项目基本信息

| 属性 | 值 |
|------|-----|
| 项目名称 | LightFlowMap |
| 包名 | com.example.lightflow |
| 版本号 | 1.0.0 (buildCode: 1000000) |
| 类型 | HarmonyOS 应用程序 (Entry类型模块) |
| 设备支持 | phone, tablet, 2in1, car |

### 1.2 项目功能简介

LightFlowMap 是一个基于 HarmonyOS 的图像位置标注应用，主要功能包括：
- 从相册选择图片
- 读取图片的 EXIF GPS 信息获取拍摄位置
- 在地图上标注图片位置
- 将地理坐标转换为实际地址

---

## 二、项目目录结构分析

```
LightFlowMap/
├── AppScope/                          # 应用全局配置
│   ├── app.json5                      # 应用级别配置(包名、版本、图标)
│   └── resources/
│       └── base/
│           └── element/
│               └── string.json        # 应用级字符串资源
│
├── entry/                             # 主模块(Entry)
│   ├── src/main/
│   │   ├── ets/                      # ArkTS/ArkUI源码目录
│   │   │   ├── entryability/
│   │   │   │   └── EntryAbility.ets  # 应用入口Ability
│   │   │   ├── entrybackupability/
│   │   │   │   └── EntryBackupAbility.ets  # 备份恢复Ability
│   │   │   ├── pages/
│   │   │   │   └── Index.ets          # 主页面(地图+图片选择+标注)
│   │   │   └── utils/
│   │   │       ├── ImagePosition.ets  # 核心：图片位置读取+逆地理编码
│   │   │       └── PermissionMng.ets  # 权限管理工具
│   │   │
│   │   ├── resources/                 # 资源目录
│   │   │   ├── base/                  # 默认语言资源
│   │   │   ├── en_US/                 # 英文资源
│   │   │   └── zh_CN/                 # 中文资源
│   │   │
│   │   └── module.json5              # 模块配置(权限声明、Ability配置)
│   │
│   ├── oh-package.json5              # 模块依赖配置
│   ├── build-profile.json5          # 构建配置
│   └── hvigorfile.ts                # Hvigor构建脚本
│
├── hvigor/                           # Hvigor工具配置
├── hvigorfile.ts                     # 根级构建脚本
└── oh-package.json5                  # 根级依赖管理
```

---

## 三、核心功能模块详解

### 3.1 图片选择功能

#### 实现位置：[Index.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/pages/Index.ets#L157-L196) - `selectImage()` 方法

#### 实现流程：

```
┌─────────────────────────────────────────────────────────────┐
│                    图片选择流程                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 创建 PhotoSelectOptions 对象                            │
│     ├── MIMEType: PhotoViewMIMETypes.IMAGE_TYPE (仅图片)     │
│     └── maxSelectNumber: 1 (单选模式)                       │
│                                                             │
│  2. 创建 PhotoViewPicker 实例                               │
│     └── photoViewPicker.select(options) 发起选择            │
│                                                             │
│  3. 获取选中的图片 URI 列表                                   │
│     └── photoSelectResult.photoUris                         │
│                                                             │
│  4. 遍历每个 URI，调用 getImagePosition()                    │
│     └── 获取 GPS 坐标 + 逆地理编码地址                        │
│                                                             │
│  5. 在地图上添加 Marker 标注                                │
│     └── mapController.addMarker(markerOptions)              │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 关键代码片段：

```typescript
selectImage() {
    // 第1步：配置图片选择选项
    let photoSelectOptions: photoAccessHelper.PhotoSelectOptions = 
        new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    photoSelectOptions.maxSelectNumber = 1;  // 单选

    // 第2步：创建图片选择器并选择图片
    let photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    photoViewPicker.select(photoSelectOptions)
      .then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        // 第3步：处理选中的图片URI
        photoSelectResult.photoUris.forEach(async (uri: string) => {
            // 第4步：获取图片位置信息(EXIF + 逆地理编码)
            let locInfo: PicInfo = await getImagePosition(context, uri);
            
            // 第5步：在地图上添加标注
            let markerOptions: mapCommon.MarkerOptions = {
                position: {
                    latitude: locInfo.latitude,
                    longitude: locInfo.longitude
                },
                icon: 'icons.png',
                clickable: true
            };
            let marker = await this.mapController!.addMarker(markerOptions);
        });
      });
}
```

#### 使用的 Kit 和 API：
- **Kit**: `@kit.MediaLibraryKit`
- **API**: `photoAccessHelper.PhotoViewPicker`
- **权限**: `ohos.permission.MEDIA_LOCATION`

---

### 3.2 EXIF 信息读取功能

#### 实现位置：[ImagePosition.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/ImagePosition.ets#L34-L60) - `getImagePosition()` 方法

#### 实现流程：

```
┌─────────────────────────────────────────────────────────────┐
│                  EXIF GPS 信息读取流程                       │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 根据 URI 创建 FileUri 对象                              │
│     └── new fileUri.FileUri(uri)                            │
│                                                             │
│  2. 打开文件获取文件描述符                                   │
│     └── fs.openSync(fileObj.path, OpenMode.READ_ONLY)      │
│                                                             │
│  3. 根据文件描述符创建 ImageSource                          │
│     └── image.createImageSource(file.fd)                   │
│                                                             │
│  4. 查询 EXIF 属性                                          │
│     └── imageSource.getImageProperties([                    │
│           PropertyKey.GPS_LONGITUDE,                         │
│           PropertyKey.GPS_LONGITUDE_REF,                    │
│           PropertyKey.GPS_LATITUDE,                         │
│           PropertyKey.GPS_LATITUDE_REF                      │
│         ])                                                  │
│                                                             │
│  5. 解析 GPS 坐标值                                         │
│     ├── 格式: "度,分,秒" 如 "113,54,23.5"                   │
│     ├── 计算公式: 度 + 分/60 + 秒/3600                      │
│     └── 根据 REF(E/W/N/S) 确定正负                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### GPS 坐标解析详解：

```typescript
// 原始EXIF数据格式示例
// GPSLongitude: "113,54,23.5"  (度,分,秒)
// GPSLatitude: "22,33,44.5"    (度,分,秒)
// GPSLongitudeRef: "E" 或 "W"
// GPSLatitudeRef: "N" 或 "S"

// 解析经度
let loStr = data.GPSLongitude.split(',');  // ["113", "54", "23.5"]
let longiVal = parseInt(loStr[0]) + parseInt(loStr[1]) / 60 + parseInt(loStr[2]) / 3600;
let longitude = data.GPSLongitudeRef === 'E' ? longiVal : -longiVal;

// 解析纬度
let laStr = data.GPSLatitude.split(',');   // ["22", "33", "44.5"]
let latiVal = parseInt(laStr[0]) + parseInt(laStr[1]) / 60 + parseInt(laStr[2]) / 3600;
let latitude = data.GPSLatitudeRef === 'N' ? latiVal : -latiVal;
```

#### 使用的 Kit 和 API：
- **Kit**: `@kit.CoreFileKit`, `@kit.ImageKit`
- **API**: `fileUri.FileUri`, `fileIo.openSync`, `image.createImageSource`, `image.ImageSource.getImageProperties`

---

### 3.3 地图组件使用

#### 实现位置：[Index.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/pages/Index.ets#L30-L70) - 地图初始化

#### 实现流程：

```
┌─────────────────────────────────────────────────────────────┐
│                    地图组件使用流程                           │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 配置地图初始化参数 MapOptions                           │
│     ├── position.target: 初始中心点(纬度/经度)               │
│     ├── zoom: 缩放级别(4.8 表示查看全国)                     │
│     └── zoomControlsEnabled: 隐藏缩放控件                   │
│                                                             │
│  2. 创建 MapComponent 组件                                   │
│     └── <MapComponent mapOptions={mapOptions}               │
│                    mapCallback={callback} />                │
│                                                             │
│  3. 在回调中获取 MapComponentController                      │
│     └── 用于操作地图(添加标注、移动相机等)                    │
│                                                             │
│  4. 注册地图事件监听                                         │
│     ├── mapLoad: 地图加载完成事件                            │
│     └── markerClick: 标注点击事件                            │
│                                                             │
│  5. 使用地图控制器操作地图                                   │
│     ├── addMarker(): 添加标注                               │
│     ├── clear(): 清除所有标注                               │
│     ├── animateCamera(): 相机动画移动                        │
│     └── getEventManager(): 获取事件管理器                    │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 地图配置参数：

```typescript
private mapOptions: mapCommon.MapOptions = {
    position: {
        target: {
            latitude: 33.0,    // 初始纬度(中国中部)
            longitude: 110.0  // 初始经度
        },
        zoom: 4.8             // 缩放级别(小数字=更大范围)
    },
    zoomControlsEnabled: false  // 隐藏缩放控件
};
```

#### 地图事件监听示例：

```typescript
// 获取地图控制器
this.callback = async (err, mapController) => {
    if (!err) {
        this.mapController = mapController;
        this.mapEventManager = this.mapController.getEventManager();
        
        // 监听地图加载完成
        this.mapEventManager.on('mapLoad', () => {
            hilog.info(0xFF00, 'ImagePosition', `on-mapLoad`);
        });
        
        // 监听标注点击
        this.mapEventManager.on('markerClick', (marker: map.Marker) => {
            hilog.info(0xFF00, 'ImagePosition', `marker = ${marker.getId()}`);
            // 处理标注点击逻辑
        });
    }
};
```

#### 相机移动方法：

```typescript
moveCamera(locInfo: PicInfo, zoom: number = 12) {
    let cameraPosition: mapCommon.CameraPosition = {
        target: {
            latitude: locInfo.latitude,
            longitude: locInfo.longitude
        },
        zoom: zoom,        // 目标缩放级别
        tilt: 0,          // 倾斜角度
        bearing: 0        // 旋转角度
    };
    let cameraUpdate = map.newCameraPosition(cameraPosition);
    // 以动画方式移动地图相机，时长1000ms
    this.mapController!.animateCamera(cameraUpdate, 1000);
}
```

#### 添加标注方法：

```typescript
let markerOptions: mapCommon.MarkerOptions = {
    position: {
        latitude: locInfo.latitude,   // 纬度
        longitude: locInfo.longitude   // 经度
    },
    icon: 'icons.png',     // 标注图标
    clickable: true         // 可点击
};
let marker = await this.mapController!.addMarker(markerOptions);
```

#### 使用的 Kit 和 API：
- **Kit**: `@kit.MapKit`
- **API**: `MapComponent`, `map.MapComponentController`, `map.MapEventManager`, `mapCommon.MarkerOptions`

---

### 3.4 位置定位功能

#### 实现位置：[Index.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/pages/Index.ets#L198-L217) - `moveToLocation()` 方法

#### 实现流程：

```
┌─────────────────────────────────────────────────────────────┐
│                  获取当前位置流程                             │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 请求位置权限                                            │
│     ├── APPROXIMATELY_LOCATION (模糊位置)                    │
│     └── LOCATION (精确位置)                                 │
│                                                             │
│  2. 配置定位请求参数                                        │
│     ├── locatingPriority: PRIORITY_LOCATING_SPEED (快速定位) │
│     └── locatingTimeoutMs: 10000 (10秒超时)                  │
│                                                             │
│  3. 调用 getCurrentLocation 获取当前位置                     │
│                                                             │
│  4. 获取成功后移动相机到当前位置                             │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 关键代码：

```typescript
moveToLocation() {
    // 第1步：请求位置权限
    getLocationPermission(this.getUIContext().getHostContext()!).then(() => {
        
        // 第2步：配置定位请求
        let requestInfo: geoLocationManager.SingleLocationRequest = {
            'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
            'locatingTimeoutMs': 10000
        };
        
        // 第3步：获取当前位置
        geoLocationManager.getCurrentLocation(requestInfo).then((res) => {
            hilog.info(0xFF00, 'ImagePosition', `getCurrentLocation`);
            
            // 第4步：移动相机到当前位置
            let locInfo: PicInfo = {
                latitude: res.latitude,
                longitude: res.longitude,
                address: '',
                uri: '',
                marker: null
            };
            this.moveCamera(locInfo, 8);  // 缩放级别8
        });
    });
}
```

#### 使用的 Kit 和 API：
- **Kit**: `@kit.LocationKit`
- **API**: `geoLocationManager.getCurrentLocation`, `geoLocationManager.SingleLocationRequest`

---

### 3.5 坐标转地址功能（逆地理编码）

#### 实现位置：[ImagePosition.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/ImagePosition.ets#L61-L74) - `getImagePosition()` 方法末尾

#### 实现流程：

```
┌─────────────────────────────────────────────────────────────┐
│                  逆地理编码(坐标→地址)流程                     │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 构建逆地理编码请求参数 ReverseGeocodeParams              │
│     ├── location: {latitude, longitude}                    │
│     ├── language: 'zh' (中文)                               │
│     └── radius: 100 (范围半径，米)                          │
│                                                             │
│  2. 调用 site.reverseGeocode() 发起逆地理编码               │
│                                                             │
│  3. 获取地址描述结果                                         │
│     └── result.addressDescription                          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

#### 关键代码：

```typescript
// 构建逆地理编码参数
let params: site.ReverseGeocodeParams = {
    location: {
        latitude: latitude,   // 纬度
        longitude: longitude  // 经度
    },
    language: 'zh',          // 使用中文
    radius: 100              // 范围半径100米
};

// 调用逆地理编码API
let result = await site.reverseGeocode(context, params);

// 获取地址描述
let address = result.addressDescription;
```

#### 返回结果示例：

```json
{
    "addressDescription": "广东省深圳市南山区科技中一道",
    "latitude": 22.53,
    "longitude": 113.93
}
```

#### 使用的 Kit 和 API：
- **Kit**: `@kit.MapKit`
- **API**: `site.ReverseGeocodeParams`, `site.reverseGeocode()`

---

## 四、数据结构定义

### 4.1 PicInfo 接口

定义位置：[ImagePosition.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/ImagePosition.ets#L19-L25)

```typescript
export interface PicInfo {
    longitude: number;      // 经度
    latitude: number;       // 纬度
    uri: string;            // 图片URI
    address: string;        // 地址描述
    marker: map.Marker | null;  // 关联的地图标注
}
```

---

## 五、权限配置分析

### 5.1 权限清单

定义位置：[module.json5](file:///e:/Program/OH/LightFlowMap/entry/src/main/module.json5#L18-L40)

| 权限名称 | 用途 | 场景描述 |
|---------|------|---------|
| `ohos.permission.INTERNET` | 网络访问 | 地图服务、逆地理编码需要网络 |
| `ohos.permission.MEDIA_LOCATION` | 媒体位置访问 | 读取相册图片的GPS信息 |
| `ohos.permission.LOCATION` | 精确位置 | 获取当前设备位置 |
| `ohos.permission.APPROXIMATELY_LOCATION` | 模糊位置 | 获取当前设备位置(低精度) |

### 5.2 权限请求实现

定义位置：[PermissionMng.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/PermissionMng.ets)

```typescript
export function getLocationPermission(context: Context): Promise<boolean> {
    // 请求两个位置权限
    let requestPermission: Permissions[] = [
        'ohos.permission.APPROXIMATELY_LOCATION', 
        'ohos.permission.LOCATION'
    ];
    
    return new Promise((resolve, reject) => {
        getPermission(context, requestPermission)
            .then(() => resolve(true))
            .catch(() => reject(false));
    });
}
```

#### 权限请求流程：

```
┌─────────────────────────────────────────────────────────────┐
│                    权限请求流程                              │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  1. 创建 AtManager 实例                                     │
│     └── abilityAccessCtrl.createAtManager()                │
│                                                             │
│  2. 调用 requestPermissionsFromUser                         │
│     ├── 传入 Context                                        │
│     ├── 传入权限数组                                        │
│     └── 传入回调函数                                        │
│                                                             │
│  3. 系统弹出权限授予对话框                                   │
│                                                             │
│  4. 用户选择后，回调返回授权结果                             │
│     ├── err: 错误信息(如果有)                               │
│     └── data: PermissionRequestResult                      │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 六、主页面布局结构

定义位置：[Index.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/pages/Index.ets#L97-L140)

### 6.1 整体布局

```
┌─────────────────────────────────────────────────────────────┐
│                      Navigation                             │
│  ┌───────────────────────────────────────────────────────┐ │
│  │                    Column                               │ │
│  │  ┌───────────────────────────────────────────────────┐ │ │
│  │  │              Stack (层叠布局)                      │ │ │
│  │  │  ┌─────────────────────────────────────────────┐ │ │ │
│  │  │  │         MapComponent (地图组件)              │ │ │ │
│  │  │  │                                              │ │ │ │
│  │  │  │    ┌──────────────────────┐                │ │ │ │
│  │  │  │    │  底部叠加层 Column   │                │ │ │ │
│  │  │  │    │  ┌────────────────┐  │                │ │ │ │
│  │  │  │    │  │ 地址信息 Text  │  │                │ │ │ │
│  │  │  │    │  └────────────────┘  │                │ │ │ │
│  │  │  │    │  ┌────────────────┐  │                │ │ │ │
│  │  │  │    │  │ 按钮行 Row    │  │                │ │ │ │
│  │  │  │    │  │ [清除] [选择]  │  │                │ │ │ │
│  │  │  │    │  └────────────────┘  │                │ │ │ │
│  │  │  │    └──────────────────────┘                │ │ │ │
│  │  │  └─────────────────────────────────────────────┘ │ │ │
│  │  └───────────────────────────────────────────────────┘ │ │
│  └───────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────┘
```

### 6.2 标注图标自定义构建器

```typescript
@Builder
MarkerIconBuilder(uri: string, cnt: number, focus: boolean = false) {
    Row() {
        Badge({
            count: cnt,              // 同位置图片数量
            style: { badgeColor: Color.Red },
            position: BadgePosition.RightTop,  // 徽章位置
        }) {
            Row() {
                Image(uri)            // 图片缩略图
                    .width(64)
                    .height(64)
                    .borderRadius(4);
            }
            .border({ 
                radius: 4, 
                width: 2, 
                color: focus ? '#0A59F7' : Color.White  // 选中时蓝色边框
            });
        };
    }
    .width(80)
    .height(80);
}
```

---

## 七、完整功能流程图

```
┌──────────────────────────────────────────────────────────────────────┐
│                         应用启动流程                                  │
├──────────────────────────────────────────────────────────────────────┤
│                                                                       │
│  EntryAbility.onWindowStageCreate()                                  │
│           │                                                          │
│           ▼                                                          │
│  windowStage.loadContent('pages/Index')                              │
│           │                                                          │
│           ▼                                                          │
│  Index.aboutToAppear()                                               │
│           │                                                          │
│           ├──► moveToLocation() ──► 获取当前位置 ──► 移动相机        │
│           │                                                          │
│           └──► 初始化地图回调                                          │
│                    │                                                 │
│                    ▼                                                 │
│              Index.build()                                           │
│                    │                                                 │
│                    ▼                                                 │
│         ┌─────────────────────┐                                      │
│         │   等待用户交互       │                                      │
│         └─────────────────────┘                                      │
│                    │                                                  │
│     ┌──────────────┴──────────────┐                                  │
│     │                             │                                  │
│     ▼                             ▼                                  │
│  点击"选择图片"              点击地图标注                             │
│     │                             │                                  │
│     ▼                             ▼                                  │
│  selectImage()               markerCallback()                        │
│     │                             │                                  │
│     ├──► PhotoViewPicker.select  │                                  │
│     │         │                   │                                  │
│     │         ▼                   │                                  │
│     │    获取图片URI               │                                  │
│     │         │                   │                                  │
│     │         ▼                   │                                  │
│     │    getImagePosition()        │                                  │
│     │         │                   │                                  │
│     │         ├──► 读取EXIF GPS ──┼──► MarkerIconBuilder            │
│     │         │                   │                  │              │
│     │         ▼                   │                  ▼              │
│     │    逆地理编码 ───────────────┼──► setMarkerIcon()              │
│     │         │                   │                  │              │
│     │         ▼                   │                  ▼              │
│     │    addMarker()              │            更新地址显示           │
│     │         │                   │                                  │
│     │         ▼                   │                                  │
│     │    moveCamera()             │                                  │
│     └─────────┘                   │                                  │
│                                    └──────────────────────────────────┘
│                                                                       │
└──────────────────────────────────────────────────────────────────────┘
```

---

## 八、技术栈总结

### 8.1 使用的 HarmonyOS Kit

| Kit 名称 | 用途 | 引入方式 |
|---------|------|---------|
| `@kit.MediaLibraryKit` | 访问相册图片 | `photoAccessHelper` |
| `@kit.ImageKit` | 图片处理、EXIF读取 | `image` |
| `@kit.MapKit` | 地图展示、标注、逆地理编码 | `map`, `mapCommon`, `site` |
| `@kit.LocationKit` | 位置服务 | `geoLocationKit` |
| `@kit.AbilityKit` | 权限管理 | `abilityAccessCtrl` |
| `@kit.CoreFileKit` | 文件操作 | `fileUri`, `fileIo` |
| `@kit.BasicServicesKit` | 基础服务(错误处理) | `BusinessError` |
| `@kit.PerformanceAnalysisKit` | 日志记录 | `hilog` |

### 8.2 项目配置要点

- **API版本**: stageMode (Stage模型)
- **最低设备类型**: phone, tablet, 2in1, car
- **构建工具**: Hvigor
- **混淆配置**: 未启用 (release模式也禁用混淆)

---

## 九、关键实现细节

### 9.1 图片 URI 处理

```typescript
function getImageSource(uri: string): image.ImageSource {
    // 1. 将应用文件URI转换为系统路径
    let fileObj = new fileUri.FileUri(uri);
    
    // 2. 以只读模式打开文件
    let file = fs.openSync(fileObj.path, fs.OpenMode.READ_ONLY);
    
    // 3. 通过文件描述符创建ImageSource
    let imageSource = image.createImageSource(file.fd);
    
    // 4. 关闭文件
    fs.close(file);
    
    return imageSource;
}
```

### 9.2 标注点击状态管理

```typescript
let lastClickMarker: map.Marker | null = null;

let markerCallback = (marker: map.Marker) => {
    if (this.lastClickMarker === marker) {
        // 再次点击同一标注，取消选中
        this.setMarkerIcon(marker, false);
        this.lastClickMarker = null;
    } else {
        // 点击新标注
        if (this.lastClickMarker !== null) {
            this.setMarkerIcon(this.lastClickMarker, false);  // 取消上一个
        }
        this.setMarkerIcon(marker, true);  // 选中当前
        this.lastClickMarker = marker;
    }
};
```

### 9.3 同位置图片计数

```typescript
private locMap: Map<string, number> = new Map();
private picSet: Set<string> = new Set();

// 同一经纬度坐标的图片计数
let latLng = locInfo.latitude.toString() + locInfo.longitude.toString();
let locCnt = this.locMap.get(latLng) ?? 0;
this.locMap.set(latLng, locCnt + 1);

// 同一张图片只添加一次
if (!this.picSet.has(uri)) {
    this.picSet.add(uri);
    // 添加标注...
}
```

---

## 十、文件清单

| 文件路径 | 行数 | 功能说明 |
|---------|------|---------|
| [Index.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/pages/Index.ets) | 252 | 主页面，包含地图、标注、图片选择 |
| [ImagePosition.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/ImagePosition.ets) | 79 | 图片EXIF读取和逆地理编码 |
| [PermissionMng.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/utils/PermissionMng.ets) | 44 | 权限请求管理 |
| [EntryAbility.ets](file:///e:/Program/OH/LightFlowMap/entry/src/main/ets/entryability/EntryAbility.ets) | 49 | 应用入口Ability |
| [module.json5](file:///e:/Program/OH/LightFlowMap/entry/src/main/module.json5) | 88 | 模块配置，包含权限声明 |

---

*文档生成时间: 2026-04-23*
*分析工具: Trae IDE Code Assistant*
