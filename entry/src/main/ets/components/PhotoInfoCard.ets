// PhotoInfoCard.ets
import { PhotoInfoData } from '../utils/imageUtils'

@Component
export struct PhotoInfoCard {
  @Prop photoData: PhotoInfoData = {
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

  build() {
    Column() {
      this.headerSection()
      this.separatorLine()
      this.histogramSection()
      this.paramsSection()
      this.footerSection()
      this.separatorLine()
      this.footerPath()
    }
    .width('100%')
    .padding({ top: 14, bottom: 14, left: 14, right: 14 })
    .backgroundColor('#1B1B1B')
    .borderRadius(20)
  }

  @Builder
  separatorLine() {
    Divider()
      .width('100%')
      .height(1)
      .color('#ff9f9e9e')
      .margin({ top: 5, bottom: 0 })
  }

  @Builder
  headerSection() {
    Column({ space: 4 }) {
      Row() {
        Text(this.photoData.fileName || '')
          .fontSize(16)
          .fontWeight(FontWeight.Medium)
          .fontColor('#FFFFFF')
          .layoutWeight(1)
      }

      Row() {
        Text(this.photoData.date || '')
          .fontSize(10)
          .fontColor('#ffaeadad')
          .layoutWeight(1)

        if (this.photoData.hdr) {
          this.tag(this.photoData.hdr)
        }
      }
    }
    .width('100%')
  }

  @Builder
  histogramSection() {
    Column({ space: 6 }) {
      Row(){
        Text(`${this.photoData.resolution || ''}    ${this.photoData.fileSize || ''}`)
          .fontSize(10)
          .fontColor('#888888')
          .width('100%')
          .layoutWeight(1)
        Row({ space: 4 }) {
          if (this.photoData.device) {
            this.tag(this.photoData.device)
          }
          if (this.photoData.format) {
            this.tag(this.photoData.format)
          }
        }
      }
      Stack()
        .width('100%')
        .height(70)
        .backgroundColor('#000000')
        .borderRadius(4)
    }
    .width('100%')
    .margin({ top: 5 })
  }

  @Builder
  paramsSection() {
    Row() {
      this.paramItem(this.photoData.focalLength || '')
      this.divider()
      this.paramItem(this.photoData.iso || '')
      this.divider()
      this.paramItem(this.photoData.shutter || '')
      this.divider()
      this.paramItem(this.photoData.ev || '')
      this.divider()
      this.paramItem(this.photoData.aperture || '')
    }
    .width('100%')
    .justifyContent(FlexAlign.SpaceBetween)
    .margin({ top: 10 })
  }

  @Builder
  paramItem(text: string) {
    Text(text)
      .fontSize(10)
      .fontColor('#ffa7a7a7')
  }

  @Builder
  divider() {
    Text('|')
      .fontSize(12)
      .fontColor('#444444')
  }

  @Builder
  footerSection() {
    Column({ space: 8 }) {
      Row() {
        Text('等效 35毫米 胶片焦距')
          .fontSize(10)
          .fontColor('#888888')
          .layoutWeight(1)

        Row({ space: 4 }) {
          this.tag(this.photoData.colorMode || '')
          this.tag(this.photoData.focusMode || '')
          this.tag(this.photoData.ev || '')
          this.tag(this.photoData.whiteBalance || '')
          this.tag(this.photoData.flash || '')
        }
      }
    }
    .width('100%')
    .margin({ top: 5 })
  }

  @Builder
  footerPath() {
    Column({ space: 8 }) {
      Text(`存储路径：${this.photoData.path || ''}`)
        .fontSize(10)
        .fontColor('#ffaeadad')
        .width('100%')
    }
    .width('100%')
    .margin({ top: 5 })
  }

  @Builder
  tag(content: string) {
    if (content) {
      Text(content)
        .fontSize(10)
        .fontColor('#ff919191')
        .padding({ left: 4, right: 4, top: 2, bottom: 2 })
        .backgroundColor('#2A2A2A')
        .borderRadius(4)
    }
  }
}