/*
 * Copyright (c) 2025 Huawei Device Co., Ltd.
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 */
import {
  HdsListItemCard,
  IconSize,
  PrefixIcon,
  SuffixImage,
  SuffixSubIcon,
  SuffixSwitch,
  SuffixText,
  SuffixTextAndArrow
} from '@kit.UIDesignKit';
import { KeyboardAvoidMode } from '@kit.ArkUI';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { site ,map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getImagePosition, getAddressFromCoordinates, PicInfo } from '../utils/ImagePosition';
import { getLocationPermission } from '../utils/PermissionMng';
import { debounce ,showToast} from  '../utils/utils'
import {ExifUtility} from  '../utils/ExifUtility'
import LibExifTool from '../utils/LibExifTool';
import { SaveImageHelper } from '../utils/SaveImageHelper';
import { PhotoInfoCard } from '../components/PhotoInfoCard'
import {getOriginalExif ,parseExifToPhotoInfoData,PhotoInfoData} from  '../utils/imageUtils'

@Entry
@Component
export default struct ImagePosition {

  @State photoData: PhotoInfoData = {
    fileName: '',
    date: '',
    resolution: '',
    fileSize: '',
    device: '',
    format: '',
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
    path: ''
  };


  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @State hasMarker: boolean = false;
  @State address: string = '';
  @State currentLocation: mapCommon.LatLng = { latitude: 33.0, longitude: 110.0 };
  @State searchResult: site.SearchByTextResult = {} as site.SearchByTextResult;  // 地址搜索结果
  @State hasSelectedImage: boolean = false; // 是否有选中的图片需要保存
  private searchMarkerId: string | null = null; // 搜索结果和长按的位置标记ID（仅一个）
  private callback?: AsyncCallback<map.MapComponentController>;
  private mapController?: map.MapComponentController;
  private mapEventManager?: map.MapEventManager;
  private picMap: Map<string, PicInfo> = new Map(); // 所有标记数据（包括图片标记和搜索/长按标记）
  private picSet: Set<string> = new Set(); // 图片标记集合（用于区分哪些是图片）
  private locMap: Map<string, number> = new Map();
  private lastClickMarker: map.Marker | null = null;
  private modifiedPicInfo: PicInfo | null = null; // 记录被修改过位置的图片信息

  private longPressLatLng: mapCommon.LatLng | null = null;  // 长按位置
  
  private mapOptions: mapCommon.MapOptions = {
    position: {
      target: {
        latitude: 33.0,
        longitude: 110.0
      },
      zoom: 5
    },
    sphereEnabled: true ,
    zoomControlsEnabled: false,
    // 设置地图为夜间模式
    dayNightMode: mapCommon.DayNightMode.NIGHT,
    // STANDARD：标准地图，展示道路、建筑物以及河流等重要的自然特征。
    // NONE：空地图，没有加载任何数据的地图。
    // TERRAIN：地形图，在保留了行政区划边界、POI、楼块等地图要素的基础上，呈现完整清晰描绘地形走势的标准地图。
    // SATELLITE：卫星图，只支持中国。
    // HYBRID：混合地图，在显示卫星和路网信息。
    mapType: mapCommon.MapType.STANDARD
  };
// 防抖位置搜索，避免频繁盗用
  private debouncedSearchLocation: (value: string) => void = debounce((value: string) =>
  {
    this.searchLocation(value);
  },
    1000
  );

  aboutToAppear(): void {
    // 设置键盘避让模式为 RESIZE（压缩布局）
    this.getUIContext().setKeyboardAvoidMode(KeyboardAvoidMode.RESIZE);
    this.callback = async (err, mapController) => {
      if (!err) {
        this.mapController = mapController;
        this.mapEventManager = this.mapController.getEventManager();
        let mapLoadCallback = () => {
          hilog.info(0xFF00, 'ImagePosition', `on-mapLoad`);
        };
        this.mapEventManager.on('mapLoad', mapLoadCallback);

        // 地图长按事件监听
        let mapLongClickCallback = (position: mapCommon.LatLng) => {
          hilog.info(0xFF00, 'ImagePosition', `on-mapLongClick position = ${position.longitude}`);
          this.longPressLatLng = position;
          this.handleLongPress();
        };
        this.mapEventManager.on('mapLongClick', mapLongClickCallback);

        let markerCallback = (marker: map.Marker) => {
          // 检查是否是搜索标记或长按标记
          const markerId = marker.getId();
          const picInfo = this.picMap.get(markerId);
          
          if (picInfo) {
            if (this.lastClickMarker === marker) {
              // 再次点击，隐藏地址
              this.address = '';
              this.lastClickMarker = null;
            } else {
              // 点击新标记，显示地址
              this.address = picInfo.address;
              this.lastClickMarker = marker;
            }
          }
        };
        this.mapEventManager.on('markerClick', markerCallback);
      }
    };

    this.moveToLocation();
  }

  // 搜索提交：输入关键词 → 调用 site.searchByText
  private async searchLocation(query: string) {
    if (!query || query.trim() === '') {
      showToast(this.getUIContext(), '请输入搜索地址', 1000).then(() => {
        // 可以在此执行后续操作，例如更新组件状态、发送网络请求等
      });
      return;
    }
    // 搜索参数（动态使用用户输入的关键词）
    let params: site.SearchByTextParams = {
      query: query, // 👈 这里用搜索框输入的内容
      location: this.currentLocation,   //隐藏location，radius搜索全国
      radius: 50000,
      language: "zh"
    };

    try {
      const result: site.SearchByTextResult = await site.searchByText(params);

      // 🔥 修复1：先判断 sites 存在且不为空数组
      if (!result.sites || result.sites.length === 0) {
        showToast(this.getUIContext(), "未找到相关地址", 2000).then(() => {
          // 可以在此执行后续操作，例如更新组件状态、发送网络请求等
        });
        return;
      }

      // 🔥 修复2：安全获取长度
      this.getUIContext().getPromptAction().showToast({
        message: `找到 ${result.sites.length} 条结果`,
        duration: 2000
      });
      this.searchResult = result;
      // 🔥 修复3：取数组第一个元素 [0]
      const firstSite = result.sites[0];
      console.log("第一个地址名称：", firstSite.name);
      console.log("第一个地址坐标：", firstSite.location);

      // 可选：移动地图到搜索结果位置
      if (firstSite.location) {
        this.moveCamera({
          latitude: firstSite.location.latitude,
          longitude: firstSite.location.longitude,
          address: firstSite.name ?? "",
          uri: "",
          marker: null
        });
      }

    } catch (error) {
      const err: BusinessError = error as BusinessError;
      console.error("搜索失败：", err.code, err.message);
      showToast(this.getUIContext(), "搜索失败：" + err.message, 2000).then(() => {
        // 可以在此执行后续操作，例如更新组件状态、发送网络请求等
      });

    }
  }
  private async addSearchMarker(locInfo: PicInfo) {
    if (!this.mapController) return;

    // 如果已存在搜索/长按标记，先删除旧的
    if (this.searchMarkerId) {
      const oldMarker = this.getMarkerById(this.searchMarkerId);
      if (oldMarker) {
        oldMarker.remove();
      }
      this.picMap.delete(this.searchMarkerId);
    }

    const markerOptions: mapCommon.MarkerOptions = {
      position: { latitude: locInfo.latitude, longitude: locInfo.longitude },
      icon: $r('sys.symbol.local'),
      clickable: true
    };

    const marker = await this.mapController.addMarker(markerOptions);
    if (!marker) return;

    this.hasMarker = true;
    locInfo.marker = marker;
    this.picMap.set(marker.getId(), locInfo);
    this.searchMarkerId = marker.getId(); // 保存新标记ID
  }


  @Builder
  MarkerIconBuilder(uri: string, cnt: number, focus: boolean = false) {
    Row() {
      Badge({
        count: cnt,
        style: { badgeColor: Color.Red },
        position: BadgePosition.RightTop,
      }) {
        Row() {
          Image(uri)
            .width(64)
            .height(64)
            .borderRadius(4);
        }
        .border({ radius: 4, width: 2, color: focus ? '#0A59F7' : Color.White });
      };
    }
    .width(80)
    .height(80);
  }

  build() {
    Navigation(this.pageInfos) {
      Column() {
        //Alignment.Botton 定位改为底部定位
        Stack({ alignContent: Alignment.Bottom }) {
          MapComponent({ mapOptions: this.mapOptions, mapCallback: this.callback })


          Column() {

            if (this.address) {
              Column() {
                Text(this.address)
                  .fontWeight(700)
              }
              .width('100%')
              .padding({ top: 24, left: 16, right: 16 })
              .clip(true);
              PhotoInfoCard({ photoData: this.photoData })
                .margin({ top: 16 })
                .width('90%')
            }


            Column() {
              Row(){
                Search()
                  .margin({ top:10,left: 16, right: 16 })
                  .searchButton($r('sys.symbol.magnifyingglass')) // 设置搜索按钮
                  .onChange((value: string) => {
                    console.log("用户实时搜索：", value);
                    this.debouncedSearchLocation(value); // 绑定你的搜索函数
                  })
                  .onSubmit((value: string) => {
                    console.log("用户回车搜索：", value);
                    this.debouncedSearchLocation(value); // 绑定你的搜索函数
                  })
              }
              Row() {
                Button('全部清除')
                  .flexGrow(1)
                  .fontColor(Color.Black)
                  .backgroundColor('#0C000000')
                  .enabled(this.hasMarker)
                  .onClick(() => {
                    this.mapController?.clear();
                    this.picMap.clear();
                    this.locMap.clear();
                    this.searchMarkerId = null; // 清空搜索标记ID
                    this.lastClickMarker = null;
                    this.address = '';
                    this.hasMarker = false;
                  });
                Button('选择图片')
                  .flexGrow(1)
                  .margin({ left: 8 })
                  .onClick(() => {
                    this.selectImage();
                  });
                Button('保存图片')
                  .flexGrow(1)
                  .margin({ left: 8 })
                  .enabled(this.hasSelectedImage)
                  .onClick(async () => {
                    await this.saveModifiedImageToAlbum();
                  });
              }
              .width('100%')
              .margin({ top: 10 })
              .padding({ left: 16, right: 16 })
              .justifyContent(FlexAlign.SpaceAround);
            }
            .height(130)
            .margin({ bottom: 0 });

            if(this.searchResult.sites){
              List(){
                ListItemGroup() {
                  // 循环渲染搜索结果
                  ForEach(this.searchResult.sites || [], (item: site.Site) => {
                    ListItem() {
                      Row() {
                        // 🔥 完全对齐你给的官方风格：图标 + 双行文本
                        HdsListItemCard({
                          //图标
                          prefixItem: new PrefixIcon({
                            iconSize: IconSize.SYSTEM_ICON,
                            iconValue: {
                              symbol: $r('sys.symbol.local') // 地址用定位图标更合理
                            },
                          }),
                          //文本
                          textItem: {
                            primaryText: {
                              text: item.name ?? "未知地点",

                            },
                            secondaryText: {
                              text: item.formatAddress ?? "无详细地址"
                            },
                          },
                          suffixItem: new SuffixText({
                            text: "" // 不需要右侧文字就留空
                          }),
                          cardPrefixMargin: 0,
                          cardSuffixMargin: 0,
                          cardBackgroundColor: '#0affffff',
                          // cardBackgroundColor:Color.Transparent,
                        })

                      }
                      .width('100%')
                      .clickEffect({ level: ClickEffectLevel.HEAVY })
                      .onClick(() => {
                        if (item.location) {
                          // 构造正确的 PicInfo
                          const locInfo: PicInfo = {
                            latitude: item.location.latitude,
                            longitude: item.location.longitude,
                            address: item.name ?? "",
                            uri: "", // 搜索点没有图片，所以为空
                            marker: null
                          };

                          this.moveCamera(locInfo);
                          this.addSearchMarker(locInfo);
                          this.searchResult = {} as site.SearchByTextResult;
                        }
                      })
                    }
                  })
                }
                .borderRadius(16)
                .padding({ left: 6, right: 6 })
                .backgroundColor('#00111111')
                //分割线
                .divider({
                  strokeWidth: 1,
                  startMargin: 40,
                  endMargin: 6,
                  color: $r('sys.color.comp_background_tertiary'),
                })
              }.height('50%')

              .animation({
                duration: 300,
                curve: Curve.EaseOut,
              })
              .borderRadius(16)
              .margin({top:5,bottom:5})
            }


          }
          .width('100%')
          .backgroundBlurStyle(BlurStyle.Thick,
            { colorMode: ThemeColorMode.LIGHT, adaptiveColor: AdaptiveColor.DEFAULT, scale: 0.3 })
          .borderRadius({ topLeft: 32, topRight: 32 });
        }
        // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .width('100%')
        .height('100%');


      }
      .width('100%')
      .height('100%');
    }

    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
    .hideTitleBar(true);
  }

  setMarkerIcon(marker: map.Marker, focus: boolean = false) {
    let picInfo = this.picMap.get(marker.getId());
    if (picInfo === undefined) {
      return;
    }
    this.address = focus ? picInfo.address : '';
    let latLng = picInfo.latitude.toString() + picInfo.longitude.toString();
    let locCnt = this.locMap.get(latLng) ?? 1;
    this.getUIContext().getComponentSnapshot().createFromBuilder(() => {
      this.MarkerIconBuilder(picInfo!.uri, locCnt, focus);
    },
      async (error: Error, pixelMap: image.PixelMap) => {
        if (error) {
          hilog.error(0xFF00, 'ImagePosition', `error message is ${error.message}`);
          return;
        }
        try {
          // 设置图标
          await marker.setIcon(pixelMap);

        } finally {
          // PixelMap用完立即释放，杜绝内存泄漏
          pixelMap.release();
        }
      });
  }

  selectImage() {
    let photoSelectOptions: photoAccessHelper.PhotoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
    photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
    photoSelectOptions.maxSelectNumber = 1;
    let photoViewPicker = new photoAccessHelper.PhotoViewPicker();
    photoViewPicker.select(photoSelectOptions)
      .then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        hilog.info(0xFF00, 'ImagePosition', `photoPicker uris are: ${photoSelectResult.photoUris}`);
        photoSelectResult.photoUris.forEach(async (uri: string, i: number) => {
          let locInfo: PicInfo = await getImagePosition(this.getUIContext().getHostContext()!, uri);

          if (!this.picSet.has(uri)) {

            let info = LibExifTool.getImageInfo(LibExifTool.uriToPath(uri));
            const exifJson = await  getOriginalExif(uri, this.getUIContext());
            this.photoData = parseExifToPhotoInfoData(exifJson, uri);
            console.info('[systemdebug] getOriginalExif 返回:', exifJson);
            showToast(this.getUIContext(), exifJson);

            if (info && info.make) {
              showToast(this.getUIContext(),  info.model);
            } else {
              showToast(this.getUIContext(), "无相机信息test Fail");
            }
            let latLng = locInfo.latitude.toString() + locInfo.longitude.toString();
            let locCnt = this.locMap.get(latLng) ?? 0;
            this.locMap.set(latLng, locCnt + 1);
            this.picSet.add(uri);
            hilog.info(0xFF00, 'ImagePosition', `Number: ${i}, LocationCnt: ${latLng} ${locCnt}`);
          }

          let markerOptions: mapCommon.MarkerOptions = {
            position: {
              latitude: locInfo.latitude,
              longitude: locInfo.longitude
            },
            icon: 'icons.png',
            clickable: true
          };
          let marker: map.Marker | undefined = await this.mapController!.addMarker(markerOptions);
          this.hasMarker = true;
          locInfo.marker = marker;
          this.picMap.set(marker.getId(), locInfo);
          this.setMarkerIcon(marker, false);

          this.moveCamera(locInfo);
        });
      }).catch((err: BusinessError) => {
      hilog.error(0xFF00, 'ImagePosition', `photoPicker failed, message is ${err.message}`);
    });
  }

  moveCamera(locInfo: PicInfo, zoom: number = 12) {
    let cameraPosition: mapCommon.CameraPosition = {
      target: {
        latitude: locInfo.latitude,
        longitude: locInfo.longitude
      },
      zoom,
      tilt: 0,
      bearing: 0
    };
    let cameraUpdate = map.newCameraPosition(cameraPosition);
    this.mapController!.animateCamera(cameraUpdate, 1000);
  }

  moveToLocation() {
    getLocationPermission(this.getUIContext().getHostContext()!).then(() => {
      let requestInfo: geoLocationManager.SingleLocationRequest = {
        'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        'locatingTimeoutMs': 20000
      };
      geoLocationManager.getCurrentLocation(requestInfo).then((res) => {
        hilog.info(0xFF00, 'ImagePosition', `getCurrentLocation`);
        this.currentLocation.latitude = res.latitude;
        this.currentLocation.longitude = res.longitude;
        let locInfo: PicInfo = {
          latitude: res.latitude,
          longitude: res.longitude,
          address: '',
          uri: '',
          marker: null
        };
        this.moveCamera(locInfo, 8);
      });
    });
  }

  // 处理长按事件：更新选中标记或创建新标记
  private async handleLongPress() {
    if (!this.longPressLatLng) return;

    // 1. 检查是否有图片位置标记被选中
    if (this.lastClickMarker) {
      const markerId = this.lastClickMarker.getId();
      const picInfo = this.picMap.get(markerId);
      
      // 如果是图片标记（uri不为空），更新它
      if (picInfo && picInfo.uri && picInfo.uri !== '') {
        await this.updateMarkerPosition(this.lastClickMarker, this.longPressLatLng, picInfo);
        return;
      }
    }

    // 2. 检查是否有搜索结果位置图标被选中
    if (this.lastClickMarker && this.searchMarkerId) {
      const markerId = this.lastClickMarker.getId();
      if (markerId === this.searchMarkerId) {
        // 搜索结果位置图标被选中，更新它
        const picInfo = this.picMap.get(markerId);
        if (picInfo) {
          await this.updateMarkerPosition(this.lastClickMarker, this.longPressLatLng, picInfo);
        }
        return;
      }
    }

    // 3. 检查是否有搜索结果位置图标存在但没被选中
    if (this.searchMarkerId) {
      showToast(this.getUIContext(), '没有位置被选中', 2000);
      return;
    }

    // 4. 如果没有搜索结果，就在长按位置生成一个
    await this.addLongPressMarker(this.longPressLatLng);
  }

  // 更新标记位置的公共方法
  private async updateMarkerPosition(marker: map.Marker, latLng: mapCommon.LatLng, picInfo: PicInfo) {
    await marker.setPosition(latLng);
    
    picInfo.latitude = latLng.latitude;
    picInfo.longitude = latLng.longitude;
    
    // 更新地址信息
    try {
      picInfo.address = await getAddressFromCoordinates(this.getUIContext().getHostContext()!, 
        latLng.latitude, latLng.longitude);
      if (this.lastClickMarker === marker) {
        this.address = picInfo.address;
      }
    } catch (error) {
      picInfo.address = `经度：${latLng.longitude}\n纬度：${latLng.latitude}`;
      if (this.lastClickMarker === marker) {
        this.address = picInfo.address;
      }
    }
    
    // 将新位置更新到图片EXIF GPS信息中
    await this.updateExifGPS(picInfo);
    
    // 记录被修改的图片信息，用于后续保存
    if (picInfo.uri && picInfo.uri !== '') {
      this.modifiedPicInfo = picInfo;
      this.hasSelectedImage = true;
    }
    
    showToast(this.getUIContext(), '标记位置已更新', 2000);
  }

  /**
   * 将新位置更新到图片EXIF GPS信息中
   * @param picInfo 图片信息对象
   */
  private async updateExifGPS(picInfo: PicInfo) {
    try {
      hilog.info(0xFF00, 'Index', `updateExifGPS: Start updating GPS for ${picInfo.uri}`);
      hilog.info(0xFF00, 'Index', `updateExifGPS: lat=${picInfo.latitude}, lng=${picInfo.longitude}`);

      // 检查URI是否有效
      if (!picInfo.uri || picInfo.uri === '') {
        hilog.error(0xFF00, 'Index', `updateExifGPS: Invalid URI`);
        return;
      }

      // 判断是否是媒体库URI
      if (picInfo.uri.startsWith('file://media/')) {
        // 使用媒体库专用方法更新GPS
        hilog.info(0xFF00, 'Index', `updateExifGPS: Media library URI detected, using updateMediaGPS...`);
        const success = await ExifUtility.updateMediaGPS(picInfo.uri, picInfo.latitude, picInfo.longitude);
        if (success) {
          hilog.info(0xFF00, 'Index', `updateExifGPS: GPS updated successfully via updateMediaGPS`);
        } else {
          hilog.error(0xFF00, 'Index', `updateExifGPS: updateMediaGPS failed`);
        }
      } else {
        // 普通文件，使用原有方法
        hilog.info(0xFF00, 'Index', `updateExifGPS: Regular file URI, using createImageSourceFromUri...`);
        const imageSource = ExifUtility.createImageSourceFromUri(picInfo.uri, false);
        const modifySuccess = await ExifUtility.modifyGPSCoordinates(
          imageSource,
          picInfo.latitude,
          picInfo.longitude
        );

        if (modifySuccess) {
          const saveSuccess = await ExifUtility.saveExifToFile(imageSource, picInfo.uri);
          if (saveSuccess) {
            hilog.info(0xFF00, 'Index', `updateExifGPS: GPS updated successfully for ${picInfo.uri}`);
          } else {
            hilog.error(0xFF00, 'Index', `updateExifGPS: Failed to save EXIF to file`);
          }
        } else {
          hilog.error(0xFF00, 'Index', `updateExifGPS: Failed to modify GPS coordinates`);
        }
      }
    } catch (error) {
      hilog.error(0xFF00, 'Index', `updateExifGPS error: ${error}`);
    }
  }

  // 根据标记ID获取标记对象
  private getMarkerById(markerId: string): map.Marker | null {
    // 遍历 picMap 查找对应的标记
    let entries = this.picMap.entries();
    for (let entry of entries) {
      let id = entry[0];
      let info = entry[1];
      if (id === markerId && info.marker) {
        return info.marker;
      }
    }
    return null;
  }

  // 添加长按标记
  private async addLongPressMarker(latLng: mapCommon.LatLng) {
    if (!this.mapController) return;

    // 如果已存在搜索/长按标记，先删除旧的
    if (this.searchMarkerId) {
      const oldMarker = this.getMarkerById(this.searchMarkerId);
      if (oldMarker) {
        oldMarker.remove();
      }
      this.picMap.delete(this.searchMarkerId);
    }

    const markerOptions: mapCommon.MarkerOptions = {
      position: latLng,
      icon: $r('sys.symbol.local'),
      clickable: true
    };

    const marker = await this.mapController.addMarker(markerOptions);
    if (!marker) return;

    this.hasMarker = true;
    
    // 获取实际地址
    let address = '';
    try {
      address = await getAddressFromCoordinates(this.getUIContext().getHostContext()!, latLng.latitude, latLng.longitude);
    } catch (error) {
      address = `经度：${latLng.longitude}\n纬度：${latLng.latitude}`;
    }
    
    // 创建 PicInfo 数据
    const locInfo: PicInfo = {
      latitude: latLng.latitude,
      longitude: latLng.longitude,
      address: address,
      uri: '',
      marker: marker
    };

    this.picMap.set(marker.getId(), locInfo);
    this.searchMarkerId = marker.getId(); // 保存标记ID
    this.lastClickMarker = marker;
    
    // 显示标记信息
    this.address = locInfo.address;
    
    // 显示添加成功提示
    showToast(this.getUIContext(), '已添加标记', 1500);
  }

  private async saveModifiedImageToAlbum(): Promise<void> {
    if (!this.modifiedPicInfo || !this.modifiedPicInfo.uri) {
      showToast(this.getUIContext(), '没有可保存的图片', 2000);
      return;
    }

    const context = this.getUIContext().getHostContext();
    if (!context) {
      showToast(this.getUIContext(), '无法获取应用上下文', 2000);
      return;
    }

    const picInfo = this.modifiedPicInfo;
    hilog.info(0xFF00, 'Index', 'saveModifiedImageToAlbum: uri=' + picInfo.uri);

    try {
      if (picInfo.uri.startsWith('file://media/')) {
        hilog.info(0xFF00, 'Index', 'saveModifiedImageToAlbum: Media library URI detected');

        const imageSource = ExifUtility.createImageSourceFromUri(picInfo.uri, false);

        const modifySuccess = await ExifUtility.modifyGPSCoordinates(
          imageSource,
          picInfo.latitude,
          picInfo.longitude
        );

        if (!modifySuccess) {
          showToast(this.getUIContext(), '修改GPS信息失败', 2000);
          return;
        }

        const result = await SaveImageHelper.saveImageSourceToAlbum(context, imageSource);

        if (result.success) {
          showToast(this.getUIContext(), '图片已保存到相册', 2000);
        } else {
          showToast(this.getUIContext(), result.message, 2000);
        }
      } else {
        hilog.info(0xFF00, 'Index', 'saveModifiedImageToAlbum: Regular file URI');

        const result = await SaveImageHelper.saveFileToAlbum(context, picInfo.uri);

        if (result.success) {
          showToast(this.getUIContext(), '图片已保存到相册', 2000);
        } else {
          showToast(this.getUIContext(), result.message, 2000);
        }
      }
    } catch (error) {
      const err = error as BusinessError;
      hilog.error(0xFF00, 'Index', 'saveModifiedImageToAlbum failed: ' + err.code + ', ' + err.message);
      showToast(this.getUIContext(), '保存失败: ' + err.message, 2000);
    }
  }
}