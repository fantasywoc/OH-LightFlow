export type ExifToolInstance = unknown;

export interface ExifToolModule {
  add: (a: number, b: number) => number;
  openImage: (filePath: string) => ExifToolInstance | null;
  saveImage: (exifTool: ExifToolInstance, filePath?: string) => boolean;
  hasExifData: (exifTool: ExifToolInstance) => boolean;
  hasExifField: (exifTool: ExifToolInstance, key: string) => boolean;
  getExifField: (exifTool: ExifToolInstance, key: string) => string;
  setExifField: (exifTool: ExifToolInstance, key: string, value: string) => boolean;
  removeExifField: (exifTool: ExifToolInstance, key: string) => boolean;
  getAllExifData: (exifTool: ExifToolInstance) => Record<string, string>;
  getAllExifKeys: (exifTool: ExifToolInstance) => string[];
  clearAllExifData: (exifTool: ExifToolInstance) => void;
  getExifFieldWithDefault: (exifTool: ExifToolInstance, key: string, defaultValue: string) => string;
  addBasicExifData: (exifTool: ExifToolInstance) => boolean;
}

declare const ExifTool: ExifToolModule;

export default ExifTool;