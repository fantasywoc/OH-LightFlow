if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface ImagePosition_Params {
    pageInfos?: NavPathStack;
    hasMarker?: boolean;
    address?: string;
    callback?: AsyncCallback<map.MapComponentController>;
    mapController?: map.MapComponentController;
    mapEventManager?: map.MapEventManager;
    picMap?: Map<string, PicInfo>;
    picSet?: Set<string>;
    locMap?: Map<string, number>;
    lastClickMarker?: map.Marker | null;
    hasTriggeredDown?: boolean;
    mapOptions?: mapCommon.MapOptions;
}
import photoAccessHelper from "@ohos:file.photoAccessHelper";
import type image from "@ohos:multimedia.image";
import map from "@bundle:com.huawei.hms.mapservice.kit/mapLibrary/ets/map";
import mapCommon from "@bundle:com.huawei.hms.mapservice.kit/mapLibrary/ets/mapCommon";
import { MapComponent } from "@bundle:com.huawei.hms.mapservice.kit/mapLibrary/ets/MapComponent";
import geoLocationManager from "@ohos:geoLocationManager";
import type { AsyncCallback } from "@ohos:base";
import type { BusinessError } from "@ohos:base";
import hilog from "@ohos:hilog";
import { getImagePosition } from "@normalized:N&&&entry/src/main/ets/utils/ImagePosition&";
import type { PicInfo } from "@normalized:N&&&entry/src/main/ets/utils/ImagePosition&";
import { getLocationPermission } from "@normalized:N&&&entry/src/main/ets/utils/PermissionMng&";
export default class ImagePosition extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.__pageInfos = new ObservedPropertyObjectPU(new NavPathStack(), this, "pageInfos");
        this.addProvidedVar("pageInfos", this.__pageInfos, false);
        this.__hasMarker = new ObservedPropertySimplePU(false, this, "hasMarker");
        this.__address = new ObservedPropertySimplePU('', this, "address");
        this.callback = undefined;
        this.mapController = undefined;
        this.mapEventManager = undefined;
        this.picMap = new Map();
        this.picSet = new Set();
        this.locMap = new Map();
        this.lastClickMarker = null;
        this.hasTriggeredDown = false;
        this.mapOptions = {
            position: {
                target: {
                    latitude: 33.0,
                    longitude: 110.0
                },
                zoom: 5
            },
            sphereEnabled: true,
            zoomControlsEnabled: false,
            // 设置地图为夜间模式
            dayNightMode: mapCommon.DayNightMode.NIGHT
        };
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: ImagePosition_Params) {
        if (params.pageInfos !== undefined) {
            this.pageInfos = params.pageInfos;
        }
        if (params.hasMarker !== undefined) {
            this.hasMarker = params.hasMarker;
        }
        if (params.address !== undefined) {
            this.address = params.address;
        }
        if (params.callback !== undefined) {
            this.callback = params.callback;
        }
        if (params.mapController !== undefined) {
            this.mapController = params.mapController;
        }
        if (params.mapEventManager !== undefined) {
            this.mapEventManager = params.mapEventManager;
        }
        if (params.picMap !== undefined) {
            this.picMap = params.picMap;
        }
        if (params.picSet !== undefined) {
            this.picSet = params.picSet;
        }
        if (params.locMap !== undefined) {
            this.locMap = params.locMap;
        }
        if (params.lastClickMarker !== undefined) {
            this.lastClickMarker = params.lastClickMarker;
        }
        if (params.hasTriggeredDown !== undefined) {
            this.hasTriggeredDown = params.hasTriggeredDown;
        }
        if (params.mapOptions !== undefined) {
            this.mapOptions = params.mapOptions;
        }
    }
    updateStateVars(params: ImagePosition_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
        this.__pageInfos.purgeDependencyOnElmtId(rmElmtId);
        this.__hasMarker.purgeDependencyOnElmtId(rmElmtId);
        this.__address.purgeDependencyOnElmtId(rmElmtId);
    }
    aboutToBeDeleted() {
        this.__pageInfos.aboutToBeDeleted();
        this.__hasMarker.aboutToBeDeleted();
        this.__address.aboutToBeDeleted();
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    private __pageInfos: ObservedPropertyObjectPU<NavPathStack>;
    get pageInfos() {
        return this.__pageInfos.get();
    }
    set pageInfos(newValue: NavPathStack) {
        this.__pageInfos.set(newValue);
    }
    private __hasMarker: ObservedPropertySimplePU<boolean>;
    get hasMarker() {
        return this.__hasMarker.get();
    }
    set hasMarker(newValue: boolean) {
        this.__hasMarker.set(newValue);
    }
    private __address: ObservedPropertySimplePU<string>;
    get address() {
        return this.__address.get();
    }
    set address(newValue: string) {
        this.__address.set(newValue);
    }
    private callback?: AsyncCallback<map.MapComponentController>;
    private mapController?: map.MapComponentController;
    private mapEventManager?: map.MapEventManager;
    private picMap: Map<string, PicInfo>;
    private picSet: Set<string>;
    private locMap: Map<string, number>;
    private lastClickMarker: map.Marker | null;
    // 用于标记：是否已经触发过按下事件
    private hasTriggeredDown: boolean;
    private mapOptions: mapCommon.MapOptions;
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
                    }
                    else {
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
    MarkerIconBuilder(uri: string, cnt: number, focus: boolean = false, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(89:5)", "entry");
            Row.width(80);
            Row.height(80);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Badge.create({
                count: cnt,
                style: { badgeColor: Color.Red },
                position: BadgePosition.RightTop,
            });
            Badge.debugLine("entry/src/main/ets/pages/Index.ets(90:7)", "entry");
        }, Badge);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(95:9)", "entry");
            Row.border({ radius: 4, width: 2, color: focus ? '#0A59F7' : Color.White });
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Image.create(uri);
            Image.debugLine("entry/src/main/ets/pages/Index.ets(96:11)", "entry");
            Image.width(64);
            Image.height(64);
            Image.borderRadius(4);
        }, Image);
        Row.pop();
        Badge.pop();
        Row.pop();
    }
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Navigation.create(this.pageInfos, { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Index", isUserCreateStack: true });
            Navigation.debugLine("entry/src/main/ets/pages/Index.ets(109:5)", "entry");
            Navigation.hideTitleBar(true);
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(110:7)", "entry");
            Column.ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Stack.create({ alignContent: Alignment.Bottom });
            Stack.debugLine("entry/src/main/ets/pages/Index.ets(111:9)", "entry");
            Stack.width('100%');
            Stack.height('100%');
        }, Stack);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            __Common__.create();
            __Common__.onTouch((event) => {
                // ===== 核心逻辑：只响应【第一次按下】，滑动不响应，抬起后重置 =====
                if (event.type === TouchType.Down) {
                    // 已经按下过一次，直接忽略（滑动时不执行）
                    if (this.hasTriggeredDown)
                        return;
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
        }, __Common__);
        {
            this.observeComponentCreation2((elmtId, isInitialRender) => {
                if (isInitialRender) {
                    let componentCall = new MapComponent(this, { mapOptions: this.mapOptions, mapCallback: this.callback }, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 112, col: 11 });
                    ViewPU.create(componentCall);
                    let paramsLambda = () => {
                        return {
                            mapOptions: this.mapOptions,
                            mapCallback: this.callback
                        };
                    };
                    componentCall.paramsGenerator_ = paramsLambda;
                }
                else {
                    this.updateStateVarsOfChildByElmtId(elmtId, {});
                }
            }, { name: "MapComponent" });
        }
        __Common__.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(147:11)", "entry");
            Column.width('100%');
            Column.backgroundColor({ "id": 16777225, "type": 10001, params: [], "bundleName": "com.example.lightflow", "moduleName": "entry" });
            Column.borderRadius({ topLeft: 32, topRight: 32 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(148:13)", "entry");
            Column.width('100%');
            Column.padding({ top: 24, left: 16, right: 16 });
            Column.clip(true);
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Text.create(this.address);
            Text.debugLine("entry/src/main/ets/pages/Index.ets(149:15)", "entry");
            Text.fontWeight(700);
        }, Text);
        Text.pop();
        Column.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Column.create();
            Column.debugLine("entry/src/main/ets/pages/Index.ets(156:13)", "entry");
            globalThis.Context.animation({
                duration: 300,
                curve: Curve.EaseOut,
                onFinish: () => { }
            });
            Column.height(80);
            globalThis.Context.animation(null);
            Column.margin({ bottom: 24 });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Row.create();
            Row.debugLine("entry/src/main/ets/pages/Index.ets(157:15)", "entry");
            Row.width('100%');
            Row.margin({ top: 24 });
            Row.padding({ left: 16, right: 16 });
            Row.justifyContent(FlexAlign.SpaceAround);
        }, Row);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('全部清除');
            Button.debugLine("entry/src/main/ets/pages/Index.ets(158:17)", "entry");
            Button.flexGrow(1);
            Button.fontColor(Color.Black);
            Button.backgroundColor('#0C000000');
            Button.enabled(this.hasMarker);
            Button.onClick(() => {
                this.mapController?.clear();
                this.picMap.clear();
                this.locMap.clear();
                this.address = '';
                this.hasMarker = false;
            });
        }, Button);
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            Button.createWithLabel('选择图片');
            Button.debugLine("entry/src/main/ets/pages/Index.ets(170:17)", "entry");
            Button.flexGrow(1);
            Button.margin({ left: 16 });
            Button.onClick(() => {
                this.selectImage();
            });
        }, Button);
        Button.pop();
        Row.pop();
        Column.pop();
        Column.pop();
        Stack.pop();
        Column.pop();
        Navigation.pop();
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
        }, async (error: Error, pixelMap: image.PixelMap) => {
            if (error) {
                hilog.error(0xFF00, 'ImagePosition', `error message is ${error.message}`);
                return;
            }
            try {
                // 设置图标
                await marker.setIcon(pixelMap);
            }
            finally {
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
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "ImagePosition";
    }
}
registerNamedRoute(() => new ImagePosition(undefined, {}), "", { bundleName: "com.example.lightflow", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
