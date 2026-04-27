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


@Entry
@Component
export default struct ImagePosition {
  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @State hasMarker: boolean = false;
  @State address: string = '';
  @State currentLocation: mapCommon.LatLng = { latitude: 33.0, longitude: 110.0 };
  @State searchResult: site.SearchByTextResult = {} as site.SearchByTextResult;  // 地址搜索结果
  @State keyboardHeight: number = 0;
  private searchMarkerIds: Set<string> = new Set(); // 搜索标记ID集合
  private callback?: AsyncCallback<map.MapComponentController>;
  private mapController?: map.MapComponentController;
  private mapEventManager?: map.MapEventManager;
  private picMap: Map<string, PicInfo> = new Map();
  private picSet: Set<string> = new Set();
  private locMap: Map<string, number> = new Map();
  private lastClickMarker: map.Marker | null = null;
  private manualClickMarker: map.Marker | null = null;  //手动点击位置存放



  // 用于标记：是否已经触发过按下事件
  private hasTriggeredDown: boolean = false; 
  private longPressTimer: number | null = null;  // 长按定时器
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
    dayNightMode: mapCommon.DayNightMode.NIGHT
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

        let markerCallback = (marker: map.Marker) => {
          this.hasTriggeredDown = false;
          
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

    const markerOptions: mapCommon.MarkerOptions = {
      position: { latitude: locInfo.latitude, longitude: locInfo.longitude },
      icon: $r('sys.symbol.local'),
      clickable: true
    };

    const marker = await this.mapController.addMarker(markerOptions);
    if (!marker) return;

    this.hasMarker = true;
    this.picMap.set(marker.getId(), locInfo);
    this.searchMarkerIds.add(marker.getId()); // 👈 加入搜索标记集合
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
            .onTouch((event) => {
              if (event.type === TouchType.Down) {
                if (this.hasTriggeredDown) return;
                this.hasTriggeredDown = true;

                let positionX = this.getUIContext().vp2px(event.touches[0].x);
                let positionY = this.getUIContext().vp2px(event.touches[0].y);
                let projection = this.mapController?.getProjection();

                if (projection) {
                  let point: mapCommon.MapPoint = { positionX, positionY };
                  let latLng: mapCommon.LatLng = projection.fromScreenLocation(point);
                  this.longPressLatLng = latLng;

                  // 启动长按定时器
                  this.longPressTimer = setTimeout(() => {
                    this.handleLongPress();
                  }, 1000); // 1000ms长按
                }
              } else if (event.type === TouchType.Up) {
                this.hasTriggeredDown = false;
                // 清除长按定时器
                if (this.longPressTimer) {
                  clearTimeout(this.longPressTimer);
                  this.longPressTimer = null;
                }
              } else if (event.type === TouchType.Move) {
                // 清除长按定时器（移动时取消长按）
                if (this.longPressTimer) {
                  clearTimeout(this.longPressTimer);
                  this.longPressTimer = null;
                }
              }
            })


          Column() {

            if (this.address) {
              Column() {
                Text(this.address)
                  .fontWeight(700)
              }
              .width('100%')
              .padding({ top: 24, left: 16, right: 16 })
              .clip(true);
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
                    this.address = '';
                    this.hasMarker = false;
                  });
                Button('选择图片')
                  .flexGrow(1)
                  .margin({ left: 16 })
                  .onClick(() => {
                    this.selectImage();
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
          .backgroundBlurStyle(BlurStyle.Regular,
            { colorMode: ThemeColorMode.LIGHT, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })
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

  // 处理长按事件：只维护一个标记，更新或添加
  private async handleLongPress() {
    if (this.longPressLatLng) {
      // 检查是否存在任何标记
      let existingMarker: map.Marker | null = null;
      
      // 优先检查搜索标记
      for (const markerId of this.searchMarkerIds) {
        const marker = this.getMarkerById(markerId);
        if (marker) {
          existingMarker = marker;
          break;
        }
      }
      
      // 如果没有搜索标记，检查当前选中的标记
      if (!existingMarker && this.lastClickMarker) {
        existingMarker = this.lastClickMarker;
      }
      
      // 如果没有搜索标记和选中标记，检查是否有其他标记
      if (!existingMarker && this.picMap.size > 0) {
        let entries = this.picMap.entries();
        for (let entry of entries) {
          let info = entry[1];
          if (info.marker) {
            existingMarker = info.marker;
            break;
          }
        }
      }
      
      if (existingMarker) {
        // 更新现有标记位置
        await existingMarker.setPosition(this.longPressLatLng);
        
        // 更新对应 PicInfo 数据
        let markerId = existingMarker.getId();
        let picInfo = this.picMap.get(markerId);
        if (picInfo) {
          picInfo.latitude = this.longPressLatLng.latitude;
          picInfo.longitude = this.longPressLatLng.longitude;
          
          // 更新地址信息
          try {
            picInfo.address = await getAddressFromCoordinates(this.getUIContext().getHostContext()!, 
              this.longPressLatLng.latitude, this.longPressLatLng.longitude);
            // 如果是当前选中的标记，更新显示的地址
            if (this.lastClickMarker === existingMarker) {
              this.address = picInfo.address;
            }
          } catch (error) {
            picInfo.address = `经度：${this.longPressLatLng.longitude}\n纬度：${this.longPressLatLng.latitude}`;
            if (this.lastClickMarker === existingMarker) {
              this.address = picInfo.address;
            }
          }
          
          // 显示更新成功提示
          showToast(this.getUIContext(), '标记位置已更新', 2000).then(() => {
            // 可以在此执行后续操作，例如更新组件状态、发送网络请求等
          });
        }
      } else {
        // 如果没有任何标记，添加新标记
        await this.addLongPressMarker(this.longPressLatLng);
      }
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
    this.lastClickMarker = marker;
    
    // 显示标记信息
    this.address = locInfo.address;
    
    // 显示添加成功提示
    showToast(this.getUIContext(), '已添加标记', 1500).then(() => {
      // 可以在此执行后续操作，例如更新组件状态、发送网络请求等
    });
  }
}
