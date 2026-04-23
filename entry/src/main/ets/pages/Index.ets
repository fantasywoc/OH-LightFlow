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

// 导入页面组件模块

// [Start prebuild3]
@Entry // 标记为应用入口组件
@Component // 声明为自定义组件
struct Index {
  build() {
    Column() { // 移除废弃的 Alignment 参数
      Text('MapTest')
        .fontSize(20)
        .fontColor(Color.Orange);
    }
    .justifyContent(FlexAlign.Center) // 垂直居中（新版标准）
    .width("100%")
    .height("100%") // 必须加，否则无法全屏居中
    .ignoreLayoutSafeArea([LayoutSafeAreaType.SYSTEM], [LayoutSafeAreaEdge.TOP, LayoutSafeAreaEdge.BOTTOM]);
  }
}