#include "ExifTool.hpp"
#include <stdexcept>
#include <fstream>
#include <ctime>
#include <iomanip>
#include <sstream>

ExifTool::ExifTool() {}

ExifTool::~ExifTool() {}

bool ExifTool::openImage(const std::string& filePath) {
    try {
        image_ = Exiv2::ImageFactory::open(filePath);
        if (image_.get() == nullptr) {
            return false;
        }
        image_->readMetadata();
        originalFilePath_ = filePath;
        return true;
    } catch (const Exiv2::AnyError& e) {
        return false;
    }
}

bool ExifTool::saveImage(const std::string& filePath) {
    if (!image_.get()) {
        return false;
    }
    try {
        // 濡傛灉娌℃湁鎻愪緵璺緞锛屽垯淇濆瓨鍒板師鏂囦欢
        if (filePath.empty() || filePath == originalFilePath_) {
            image_->writeMetadata();
            return true;
        }

        // 鍙﹀瓨涓猴細鍏堝鍒跺師鏂囦欢锛岀劧鍚庡湪鏂版枃浠朵笂搴旂敤鏇存敼
        // 杩欐牱鍙互纭繚杈撳嚭鏂囦欢鍏锋湁瀹屾暣鐨勫浘鍍忔暟鎹紙涓嶄粎浠呮槸鍏冩暟鎹級
        // 鍚屾椂涔熼伩鍏嶄簡鍦ㄥ師鏂囦欢涓哄彧璇绘椂瀵艰嚧鐨勫啓鍏ュけ璐?
        {
            std::ifstream src(originalFilePath_, std::ios::binary);
            if (!src) return false;
            std::ofstream dst(filePath, std::ios::binary);
            if (!dst) return false;
            dst << src.rdbuf();
            src.close();
            dst.close();
        }

        // 鎵撳紑鏂板鍒剁殑鏂囦欢
        Exiv2::Image::AutoPtr newImage = Exiv2::ImageFactory::open(filePath);
        if (newImage.get() == nullptr) return false;
        
        // 灏嗗唴瀛樹腑鐨勫厓鏁版嵁澶嶅埗鍒版柊鍥惧儚瀵硅薄
        newImage->setExifData(image_->exifData());
        newImage->setIptcData(image_->iptcData());
        newImage->setXmpData(image_->xmpData());
        
        // 鍐欏叆鍏冩暟鎹埌鏂版枃浠?        newImage->writeMetadata();
        return true;
    } catch (const Exiv2::AnyError& e) {
        return false;
    } catch (...) {
        return false;
    }
}

bool ExifTool::hasExifData() const {
    if (!image_.get()) {
        return false;
    }
    return !image_->exifData().empty();
}

bool ExifTool::hasExifField(const std::string& key) const {
    if (!image_.get()) {
        return false;
    }
    const Exiv2::ExifData& exifData = image_->exifData();
    Exiv2::ExifData::const_iterator it = exifData.findKey(Exiv2::ExifKey(key));
    return it != exifData.end();
}

std::string ExifTool::getExifField(const std::string& key) const {
    if (!image_.get()) {
        return "";
    }
    const Exiv2::ExifData& exifData = image_->exifData();
    Exiv2::ExifData::const_iterator it = exifData.findKey(Exiv2::ExifKey(key));
    if (it != exifData.end()) {
        return it->toString();
    }
    return "";
}

bool ExifTool::setExifField(const std::string& key, const std::string& value) {
    if (!image_.get()) {
        return false;
    }
    try {
        Exiv2::ExifData& exifData = image_->exifData();
        exifData[key] = value;
        return true;
    } catch (const Exiv2::AnyError& e) {
        return false;
    }
}

bool ExifTool::removeExifField(const std::string& key) {
    if (!image_.get()) {
        return false;
    }
    Exiv2::ExifData& exifData = image_->exifData();
    Exiv2::ExifData::iterator it = exifData.findKey(Exiv2::ExifKey(key));
    if (it != exifData.end()) {
        exifData.erase(it);
        return true;
    }
    return false;
}

std::map<std::string, std::string> ExifTool::getAllExifData() const {
    std::map<std::string, std::string> result;
    if (!image_.get()) {
        return result;
    }
    const Exiv2::ExifData& exifData = image_->exifData();
    for (Exiv2::ExifData::const_iterator it = exifData.begin(); it != exifData.end(); ++it) {
        result[it->key()] = it->toString();
    }
    return result;
}

std::vector<std::string> ExifTool::getAllExifKeys() const {
    std::vector<std::string> result;
    if (!image_.get()) {
        return result;
    }
    const Exiv2::ExifData& exifData = image_->exifData();
    for (Exiv2::ExifData::const_iterator it = exifData.begin(); it != exifData.end(); ++it) {
        result.push_back(it->key());
    }
    return result;
}

void ExifTool::clearAllExifData() {
    if (image_.get()) {
        image_->clearExifData();
    }
}

std::string ExifTool::getExifFieldWithDefault(const std::string& key, const std::string& defaultValue) const {
    if (!image_.get()) {
        return defaultValue;
    }
    const Exiv2::ExifData& exifData = image_->exifData();
    Exiv2::ExifData::const_iterator it = exifData.findKey(Exiv2::ExifKey(key));
    if (it != exifData.end()) {
        return it->toString();
    }
    return defaultValue;
}

bool ExifTool::addBasicExifData() {
    if (!image_.get()) {
        return false;
    }
    try {
        Exiv2::ExifData& exifData = image_->exifData();
        
        if (exifData.empty()) {
            std::time_t now = std::time(nullptr);
            std::tm* localTime = std::localtime(&now);
            std::ostringstream dateTimeStream;
            dateTimeStream << std::setw(4) << std::setfill('0') << (localTime->tm_year + 1900)
                          << ":" << std::setw(2) << std::setfill('0') << (localTime->tm_mon + 1)
                          << ":" << std::setw(2) << std::setfill('0') << localTime->tm_mday
                          << " " << std::setw(2) << std::setfill('0') << localTime->tm_hour
                          << ":" << std::setw(2) << std::setfill('0') << localTime->tm_min
                          << ":" << std::setw(2) << std::setfill('0') << localTime->tm_sec;
            std::string currentDateTime = dateTimeStream.str();
            
            exifData["Exif.Image.Make"] = "Vimag";
            exifData["Exif.Image.Model"] = "";
            exifData["Exif.Image.Software"] = "ExifTool";
            exifData["Exif.Image.DateTime"] = currentDateTime;
            exifData["Exif.Image.Artist"] = "";
            exifData["Exif.Image.Copyright"] = "";
            exifData["Exif.Image.ImageDescription"] = "";
            exifData["Exif.Image.Orientation"] = "1";
            exifData["Exif.Image.ResolutionUnit"] = "2";
            exifData["Exif.Image.XResolution"] = "72/1";
            exifData["Exif.Image.YResolution"] = "72/1";
            exifData["Exif.Photo.DateTimeOriginal"] = currentDateTime;
            exifData["Exif.Photo.DateTimeDigitized"] = currentDateTime;
            exifData["Exif.Photo.ExposureTime"] = "";
            exifData["Exif.Photo.FNumber"] = "";
            exifData["Exif.Photo.ISOSpeedRatings"] = "";
            exifData["Exif.Photo.ExposureProgram"] = "";
            exifData["Exif.Photo.WhiteBalance"] = "";
            exifData["Exif.Photo.MeteringMode"] = "";
            exifData["Exif.Photo.Flash"] = "";
            exifData["Exif.Photo.FocalLength"] = "";
            exifData["Exif.Photo.ColorSpace"] = "65535";
            exifData["Exif.Photo.FileSource"] = "3";
            exifData["Exif.Photo.SceneType"] = "1";
            exifData["Exif.Photo.SensingMethod"] = "2";
            exifData["Exif.Photo.CustomRendered"] = "";
            exifData["Exif.Photo.ExposureMode"] = "";
            exifData["Exif.Photo.DigitalZoomRatio"] = "";
            exifData["Exif.Photo.FocalLengthIn35mmFilm"] = "";
            exifData["Exif.Photo.SceneCaptureType"] = "";
            exifData["Exif.Photo.GainControl"] = "";
            exifData["Exif.Photo.Contrast"] = "";
            exifData["Exif.Photo.Saturation"] = "";
            exifData["Exif.Photo.Sharpness"] = "";
            exifData["Exif.Photo.SubjectDistanceRange"] = "";
            exifData["Exif.Photo.BodySerialNumber"] = "";
            exifData["Exif.Photo.LensModel"] = "";
            exifData["Exif.Photo.LensSerialNumber"] = "";
            
            exifData["Exif.GPSInfo.GPSLatitudeRef"] = "";
            exifData["Exif.GPSInfo.GPSLatitude"] = "";
            exifData["Exif.GPSInfo.GPSLongitudeRef"] = "";
            exifData["Exif.GPSInfo.GPSLongitude"] = "";
            exifData["Exif.GPSInfo.GPSAltitudeRef"] = "";
            exifData["Exif.GPSInfo.GPSAltitude"] = "";
            exifData["Exif.GPSInfo.GPSTimeStamp"] = "";
            exifData["Exif.GPSInfo.GPSDateStamp"] = "";
            exifData["Exif.GPSInfo.GPSProcessingMethod"] = "";
            exifData["Exif.GPSInfo.GPSAltitude"] = "";
            exifData["Exif.GPSInfo.GPSSpeedRef"] = "";
            exifData["Exif.GPSInfo.GPSSpeed"] = "";
            exifData["Exif.GPSInfo.GPSTrackRef"] = "";
            exifData["Exif.GPSInfo.GPSTrack"] = "";
            exifData["Exif.GPSInfo.GPSImgDirectionRef"] = "";
            exifData["Exif.GPSInfo.GPSImgDirection"] = "";
            exifData["Exif.GPSInfo.GPSMapDatum"] = "";
            exifData["Exif.GPSInfo.GPSDestLatitudeRef"] = "";
            exifData["Exif.GPSInfo.GPSDestLatitude"] = "";
            exifData["Exif.GPSInfo.GPSDestLongitudeRef"] = "";
            exifData["Exif.GPSInfo.GPSDestLongitude"] = "";
            exifData["Exif.GPSInfo.GPSDestBearingRef"] = "";
            exifData["Exif.GPSInfo.GPSDestBearing"] = "";
            exifData["Exif.GPSInfo.GPSDestDistanceRef"] = "";
            exifData["Exif.GPSInfo.GPSDestDistance"] = "";
            exifData["Exif.GPSInfo.GPSDifferential"] = "";
        }
        
        return true;
    } catch (const Exiv2::AnyError& e) {
        return false;
    }
}