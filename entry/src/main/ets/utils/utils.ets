// import { promptAction } from '@kit.ArkUI';
import { promptAction, UIContext } from '@kit.ArkUI';
import { BusinessError } from '@kit.BasicServicesKit';

// 搜索框专用 防抖函数（无 any、无 unknown、无 call/apply，完全合规）
export function debounce(fn: (value: string) => void, delay: number = 500) {
  let timer: number | null = null;

  // 只接收 string 类型参数，专门给搜索框使用
  return (value: string) => {
    if (timer !== null) {
      clearTimeout(timer);
    }

    timer = setTimeout(() => {
      fn(value); // 直接调用，无任何语法违规
    }, delay);
  };
}


// api23 不推荐使用
export class ToastUtils {
  static showToast(uiContext: UIContext, message: string) {
    const promptAction = uiContext.getPromptAction();
    promptAction.showToast({
      message,
      duration: 2000
    });

  }
}






/**
 * 显示Toast提示的工具函数
 @param
 uiContext 当前UI组件的上下文，可通过 this.getUIContext() 获取
 @param
 message 要显示的文本信息
 @param
 duration Toast显示的持续时间（毫秒），建议范围1500-10000，默认2000
 */
export async function showToast(uiContext: UIContext, message: string, duration: number = 2000): Promise<void> {
  try {
    // 通过UIContext获取与当前UI实例关联的PromptAction对象
    const promptActionInstance = uiContext.getPromptAction();
    // 调用openToast方法
    const toastId = await promptActionInstance.openToast({
      message: message,
      duration: duration,
    });
    // 此处可记录toastId，用于可能需要提前关闭的场景
    // console.log(`Toast displayed with ID: ${toastId}`);
  } catch (error) {
    const err = error as BusinessError;
    console.error(`showToast failed, error code: ${err.code}, message: ${err.message}`);
  }
}
