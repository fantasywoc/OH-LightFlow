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
import { map, site } from '@kit.MapKit';
import { image } from '@kit.ImageKit';
import { fileUri, fileIo as fs } from '@kit.CoreFileKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export interface PicInfo {
  longitude: number;
  latitude: number;
  uri: string;
  address: string;
  marker: map.Marker | null;
}

function getImageSource(uri: string): image.ImageSource {
  let fileObj = new fileUri.FileUri(uri);
  let file = fs.openSync(fileObj.path, fs.OpenMode.READ_ONLY);
  //根据文件fd创建imagSource
  let imageSource: image.ImageSource;
  try {
    imageSource = image.createImageSource(file.fd);
  } finally {
    fs.close(file);
  }
  return imageSource;
}

export async function getImagePosition(context: Context, uri: string): Promise<PicInfo> {
  let imageSource: image.ImageSource = getImageSource(uri);
  let key = [image.PropertyKey.GPS_LONGITUDE, image.PropertyKey.GPS_LONGITUDE_REF,
    image.PropertyKey.GPS_LATITUDE, image.PropertyKey.GPS_LATITUDE_REF];
  let data = await imageSource.getImageProperties(key);
  if (!data || !data.GPSLongitude || !data.GPSLatitude) {
    return {
      longitude: 0,
      latitude: 0,
      uri,
      address: '',
      marker: null
    };
  }
  hilog.info(0xFF00, 'ImagePosition', JSON.stringify(data));
  let loStr = data.GPSLongitude.split(',');
  let laStr = data.GPSLatitude.split(',');
  let longiVal = (Math.round((parseInt(loStr[0]) + parseInt(loStr[1]) / 60 + parseInt(loStr[2]) / 3600) * 1000)) / 1000;
  let latiVal = (Math.round((parseInt(laStr[0]) + parseInt(laStr[1]) / 60 + parseInt(laStr[2]) / 3600) * 1000)) / 1000;
  let longitude = data.GPSLongitudeRef === 'E' ? longiVal : (0 - longiVal);
  let latitude = data.GPSLatitudeRef === 'N' ? latiVal : (0 - latiVal);
  let params: site.ReverseGeocodeParams = {
    location: {
      latitude: latitude,
      longitude: longitude
    },
    language: 'zh',
    radius: 100
  };
  let result = await site.reverseGeocode(context, params);
  hilog.info(0xFF00, 'ImagePosition', `address: ${result.addressDescription}`);
  return {
    longitude,
    latitude,
    uri,
    address: result.addressDescription,
    marker: null
  };
}