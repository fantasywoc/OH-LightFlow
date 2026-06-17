#ifndef EXIFTOOL_HPP_
#define EXIFTOOL_HPP_

#include <string>
#include <map>
#include <vector>
#include <exiv2/exiv2.hpp>

class ExifTool {
public:
    ExifTool();
    ~ExifTool();

    bool openImage(const std::string& filePath);
    bool saveImage(const std::string& filePath = "");

    bool hasExifData() const;
    bool hasExifField(const std::string& key) const;
    
    std::string getExifField(const std::string& key) const;
    bool setExifField(const std::string& key, const std::string& value);
    bool removeExifField(const std::string& key);
    
    std::map<std::string, std::string> getAllExifData() const;
    std::vector<std::string> getAllExifKeys() const;
    
    void clearAllExifData();
    
    std::string getExifFieldWithDefault(const std::string& key, const std::string& defaultValue) const;
    
    bool addBasicExifData();

private:
    Exiv2::Image::AutoPtr image_;
    std::string originalFilePath_;
};

#endif // EXIFTOOL_HPP_