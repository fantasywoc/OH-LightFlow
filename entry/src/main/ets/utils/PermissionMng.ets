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
import { abilityAccessCtrl, PermissionRequestResult, Permissions } from '@kit.AbilityKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { hilog } from '@kit.PerformanceAnalysisKit';

export function getPermission(context: Context, permissions: Permissions[]): Promise<boolean> {
  let atManager: abilityAccessCtrl.AtManager = abilityAccessCtrl.createAtManager();
  return new Promise((resolve, reject) => {
    atManager.requestPermissionsFromUser(context, permissions,
      (err: BusinessError, data: PermissionRequestResult) => {
        if (err) {
          hilog.error(0X0000, 'testTag', `requestPermissionsFromUser fail, err: ${JSON.stringify(err)}`);
          return reject(false);
        } else {
          hilog.info(0X0000, 'testTag', `requestPermissions data: ${JSON.stringify(data)}`);
          return resolve(true);
        }
      });
  });
}

export function getLocationPermission(context: Context): Promise<boolean> {
  let requestPermission: Permissions[] = ['ohos.permission.APPROXIMATELY_LOCATION', 'ohos.permission.LOCATION'];
  return new Promise((resolve, reject) => {
    getPermission(context, requestPermission).then(() => {
      return resolve(true);
    }).catch(() => {
      return reject(false);
    });
  });
}
