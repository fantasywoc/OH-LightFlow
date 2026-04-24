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
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import { image } from '@kit.ImageKit';
import { site ,map, mapCommon, MapComponent } from '@kit.MapKit';
import { geoLocationManager } from '@kit.LocationKit';
import { AsyncCallback, BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';
import { getImagePosition, PicInfo } from '../utils/ImagePosition';
import { getLocationPermission } from '../utils/PermissionMng';

@Entry
@Component
export default struct ImagePosition {
  @Provide('pageInfos') pageInfos: NavPathStack = new NavPathStack();
  @State hasMarker: boolean = false;
  @State address: string = '';
  private callback?: AsyncCallback<map.MapComponentController>;
  private mapController?: map.MapComponentController;
  private mapEventManager?: map.MapEventManager;
  private picMap: Map<string, PicInfo> = new Map();
  private picSet: Set<string> = new Set();
  private locMap: Map<string, number> = new Map();
  private lastClickMarker: map.Marker | null = null;


  // 用于标记：是否已经触发过按下事件
  private hasTriggeredDown: boolean = false;
  
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

  aboutToAppear(): void {
    this.callback = async (err, mapController) => {
      if (!err) {
        this.mapController = mapController;
        this.mapEventManager = this.mapController.getEventManager();
        let mapLoadCallback = () => {
          hilog.info(0xFF00, 'ImagePosition', `on-mapLoad`);
        };
        this.mapEventManager.on('mapLoad', mapLoadCallback);

        let markerCallback = (marker: map.Marker) => {
          hilog.info(0xFF00, 'ImagePosition', `on-markerClick marker = ${marker.getId()}`);

          if (this.lastClickMarker === marker) {
            this.setMarkerIcon(marker, false);
            this.lastClickMarker = null;
          } else {
            if (this.lastClickMarker !== null) {
              this.setMarkerIcon(this.lastClickMarker, false);
            }
            this.setMarkerIcon(marker, true);
            this.lastClickMarker = marker;
          }
        };
        this.mapEventManager.on('markerClick', markerCallback);
      }
    };

    this.moveToLocation();
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
              // ===== 核心逻辑：只响应【第一次按下】，滑动不响应，抬起后重置 =====
              if (event.type === TouchType.Down) {
                // 已经按下过一次，直接忽略（滑动时不执行）
                if (this.hasTriggeredDown) return;

                // 标记为已触发，本次触摸期间不再更新
                this.hasTriggeredDown = true;

                // 获取按下时的第一个点
                let positionX = this.getUIContext().vp2px(event.touches[0].x);
                let positionY = this.getUIContext().vp2px(event.touches[0].y);
                let projection: map.Projection | undefined = this.mapController?.getProjection();

                if (projection) {
                  let point: mapCommon.MapPoint = {
                    positionX: positionX,
                    positionY: positionY
                  };
                  let latLng: mapCommon.LatLng = projection.fromScreenLocation(point);

                  this.getUIContext().getPromptAction().showToast({
                    message: 'longitude: ' + latLng.longitude + '  latitude:' + latLng.latitude,
                    duration: 3000
                  });
                }
              }

              // 手指抬起 → 重置标记，下次按下可以重新获取
              else if (event.type === TouchType.Up) {
                this.hasTriggeredDown = false;
              }
            });

          Column() {
            Column() {
              Text(this.address)
                .fontWeight(700)
            }
            .width('100%')
            .padding({ top: 24, left: 16, right: 16 })
            .clip(true);
            Column() {
              Row(){
                Search()
                  .margin({ left: 16, right: 16 })
                  .searchButton($r('sys.symbol.magnifyingglass')) // 设置按钮
                  .onSubmit((value: string) => {
                    console.log("用户回车搜索：", value);
                    // this.onSearchSubmit(value); // 绑定你的搜索函数
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
              .margin({ top: 24 })
              .padding({ left: 16, right: 16 })
              .justifyContent(FlexAlign.SpaceAround);
            }
            .height(100)
            .margin({ bottom: 24 });
          }
          .width('100%')
          .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
          .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])

          .animation({
            duration: 3000,
            curve: Curve.EaseOut,
            onFinish: () => {/* 动画完成回调 */}
          })
          // .backgroundColor('rgba(255, 255, 255, 0.5)')
          .backgroundBlurStyle(BlurStyle.Regular,
            { colorMode: ThemeColorMode.LIGHT, adaptiveColor: AdaptiveColor.DEFAULT, scale: 1.0 })
          .borderRadius({ topLeft: 32, topRight: 32 });
        }
        // .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
        .width('100%')
        .height('100%');


      }
      .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM])
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
    this.mapController!.animateCamera(cameraUpdate, 2000);
  }

  moveToLocation() {
    getLocationPermission(this.getUIContext().getHostContext()!).then(() => {
      let requestInfo: geoLocationManager.SingleLocationRequest = {
        'locatingPriority': geoLocationManager.LocatingPriority.PRIORITY_LOCATING_SPEED,
        'locatingTimeoutMs': 20000
      };
      geoLocationManager.getCurrentLocation(requestInfo).then((res) => {
        hilog.info(0xFF00, 'ImagePosition', `getCurrentLocation`);
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
}
