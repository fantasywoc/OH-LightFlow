export function readExifData(imagePath: string): Record<string, string>;
export function getSupportedTags(): Array<{id: number; name: string}>;
export function getExifEntry(imagePath: string, ifd: number, tag: number): string | undefined;
