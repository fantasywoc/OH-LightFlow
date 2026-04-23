if (!("finalizeConstruction" in ViewPU.prototype)) {
    Reflect.set(ViewPU.prototype, "finalizeConstruction", () => { });
}
interface Index_Params {
    // [StartExclude prebuild3]
    // 导航路径栈：管理页面导航历史（鸿蒙导航框架核心组件）
    navPathStack?: NavPathStack;
}
import { SameListReusePage } from "@normalized:N&&&entry/src/main/ets/pages/SameListReusePage&";
import { DiffListReusePage } from "@normalized:N&&&entry/src/main/ets/pages/DiffListReusePage&";
import { OneTypeItemPage } from "@normalized:N&&&entry/src/main/ets/pages/OneTypeItemPage&";
import { MultiTypeItemPage } from "@normalized:N&&&entry/src/main/ets/pages/MultiTypeItemPage&";
import { ComposableItemPage } from "@normalized:N&&&entry/src/main/ets/pages/ComposableItemPage&";
import type { ItemData } from '../model/ItemData';
import { IdleCallback } from "@normalized:N&&&entry/src/main/ets/utils/IdleCallback&";
import { genMockItemData } from "@normalized:N&&&entry/src/main/ets/common/MockData&";
class Index extends ViewPU {
    constructor(parent, params, __localStorage, elmtId = -1, paramsLambda = undefined, extraInfo) {
        super(parent, __localStorage, elmtId, extraInfo);
        if (typeof paramsLambda === "function") {
            this.paramsGenerator_ = paramsLambda;
        }
        this.navPathStack = new NavPathStack();
        this.setInitiallyProvidedValue(params);
        this.finalizeConstruction();
    }
    setInitiallyProvidedValue(params: Index_Params) {
        if (params.navPathStack !== undefined) {
            this.navPathStack = params.navPathStack;
        }
    }
    updateStateVars(params: Index_Params) {
    }
    purgeVariableDependenciesOnElmtId(rmElmtId) {
    }
    aboutToBeDeleted() {
        SubscriberManager.Get().delete(this.id__());
        this.aboutToBeDeletedInternal();
    }
    // [StartExclude prebuild3]
    // 导航路径栈：管理页面导航历史（鸿蒙导航框架核心组件）
    private navPathStack: NavPathStack;
    // [EndExclude prebuild3]
    /**
     * 生命周期函数：页面即将显示时触发
     * 功能：初始化数据并注册空闲回调
     */
    aboutToAppear(): void {
        // 创建测试数据数组
        let dataArray: ItemData[] = [];
        // 生成100条模拟数据并加入数组
        dataArray.push(...genMockItemData(100));
        // 获取UI上下文对象（用于操作UI线程相关任务）
        let context = this.getUIContext();
        // 注册帧回调：在空闲时段执行数据预处理（避免阻塞UI渲染）
        context.postFrameCallback(new IdleCallback(context, dataArray));
    }
    // [StartExclude prebuild3]
    /**
     * 页面映射构建器：根据路由名称返回对应页面组件
     * @param name 路由名称
     * @returns 对应页面组件
     * 注：使用@Builder装饰器声明UI构建函数
     */
    PagesMap(name: string, parent = null) {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            If.create();
            // 路由匹配逻辑
            if (name === 'SameListReusePage') {
                this.ifElseBranchUpdateFunction(0, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new 
                                // 渲染相同列表复用页
                                SameListReusePage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 65, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {};
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "SameListReusePage" });
                    }
                });
            }
            else if (name === 'DiffListPage') {
                this.ifElseBranchUpdateFunction(1, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new 
                                // 渲染不同列表复用页
                                DiffListReusePage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 68, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {};
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "DiffListReusePage" });
                    }
                });
            }
            else if (name === 'OneTypeItemPage') {
                this.ifElseBranchUpdateFunction(2, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new 
                                // 渲染单类型列表项页
                                OneTypeItemPage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 71, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {};
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "OneTypeItemPage" });
                    }
                });
            }
            else if (name === 'MultiTypeItemPage') {
                this.ifElseBranchUpdateFunction(3, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new 
                                // 渲染多类型列表项页
                                MultiTypeItemPage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 74, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {};
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "MultiTypeItemPage" });
                    }
                });
            }
            else if (name === 'ComposableItemPage') {
                this.ifElseBranchUpdateFunction(4, () => {
                    {
                        this.observeComponentCreation2((elmtId, isInitialRender) => {
                            if (isInitialRender) {
                                let componentCall = new 
                                // 渲染可组合列表项页
                                ComposableItemPage(this, {}, undefined, elmtId, () => { }, { page: "entry/src/main/ets/pages/Index.ets", line: 77, col: 7 });
                                ViewPU.create(componentCall);
                                let paramsLambda = () => {
                                    return {};
                                };
                                componentCall.paramsGenerator_ = paramsLambda;
                            }
                            else {
                                this.updateStateVarsOfChildByElmtId(elmtId, {});
                            }
                        }, { name: "ComposableItemPage" });
                    }
                });
            }
            else /**
             * 构建UI布局：声明式UI核心方法
             * 功能：创建导航框架+垂直按钮布局
             */ {
                this.ifElseBranchUpdateFunction(5, () => {
                });
            }
        }, If);
        If.pop();
    }
    /**
     * 构建UI布局：声明式UI核心方法
     * 功能：创建导航框架+垂直按钮布局
     */
    initialRender() {
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.create(this.navPathStack, { moduleName: "entry", pagePath: "entry/src/main/ets/pages/Index", isUserCreateStack: true });
            Navigation.debugLine("entry/src/main/ets/pages/Index.ets(87:5)", "entry");
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.mode(NavigationMode.Stack);
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.title({ "id": 16777222, "type": 10003, params: [], "bundleName": "com.example.lightflow", "moduleName": "entry" });
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.expandSafeArea(// 扩展安全区域
            [SafeAreaType.SYSTEM], // 适配系统安全区域（如刘海屏）
            [SafeAreaEdge.BOTTOM, SafeAreaEdge.TOP] // 扩展底部和顶部区域
            );
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.backgroundColor('#F1F3F5');
            // 1. 导航容器：使用路径栈管理导航状态
            Navigation.navDestination({ builder: this.PagesMap.bind(this) });
        }, Navigation);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 2. 内容区域：垂直排列的按钮组
            Column.create({ space: 12 });
            Column.debugLine("entry/src/main/ets/pages/Index.ets(89:7)", "entry");
            // 2. 内容区域：垂直排列的按钮组
            Column.justifyContent(FlexAlign.End);
            // 2. 内容区域：垂直排列的按钮组
            Column.height('100%');
            // 2. 内容区域：垂直排列的按钮组
            Column.width('100%');
            // 2. 内容区域：垂直排列的按钮组
            Column.padding({
                bottom: 16,
                left: 16,
                right: 16 // 右侧间距
            });
        }, Column);
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 按钮1：跳转到相同列表复用页
            Button.createWithLabel({ "id": 16777231, "type": 10003, params: [], "bundleName": "com.example.lightflow", "moduleName": "entry" });
            Button.debugLine("entry/src/main/ets/pages/Index.ets(91:9)", "entry");
            // 按钮1：跳转到相同列表复用页
            Button.width('100%');
            // 按钮1：跳转到相同列表复用页
            Button.onClick(() => {
                // 导航到指定页面（无参数传递）
                this.navPathStack.pushPathByName('SameListReusePage', '');
            });
        }, Button);
        // 按钮1：跳转到相同列表复用页
        Button.pop();
        this.observeComponentCreation2((elmtId, isInitialRender) => {
            // 按钮2：跳转到不同列表复用页
            Button.createWithLabel({ "id": 16777230, "type": 10003, params: [], "bundleName": "com.example.lightflow", "moduleName": "entry" });
            Button.debugLine("entry/src/main/ets/pages/Index.ets(99:9)", "entry");
            // 按钮2：跳转到不同列表复用页
            Button.width('100%');
            // 按钮2：跳转到不同列表复用页
            Button.onClick(() => {
                this.navPathStack.pushPathByName('DiffListPage', '');
            });
        }, Button);
        // 按钮2：跳转到不同列表复用页
        Button.pop();
        // 2. 内容区域：垂直排列的按钮组
        Column.pop();
        // 1. 导航容器：使用路径栈管理导航状态
        Navigation.pop();
    }
    rerender() {
        this.updateDirtyElements();
    }
    static getEntryName(): string {
        return "Index";
    }
}
registerNamedRoute(() => new Index(undefined, {}), "", { bundleName: "com.example.lightflow", moduleName: "entry", pagePath: "pages/Index", pageFullPath: "entry/src/main/ets/pages/Index", integratedHsp: "false", moduleType: "followWithHap" });
