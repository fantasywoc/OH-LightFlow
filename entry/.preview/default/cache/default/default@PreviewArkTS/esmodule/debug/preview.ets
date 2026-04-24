struct preview{build(){Column() {
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
            // .height(80)
            .height(this.columnHeight)
            .onAppear(() => {
              // 动态设置高度
              this.columnHeight = this.address ? 60 : 0 // 根据实际高度调整
            })
            .animation({
              duration: 300,
              curve: Curve.EaseOut
            })
            .margin({ bottom: 24 });}}