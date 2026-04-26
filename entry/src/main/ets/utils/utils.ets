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