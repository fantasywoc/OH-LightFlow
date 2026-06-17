#include "ExifTool.hpp"
#include <iostream>
#include <map>

int main(int argc, char* argv[]) {
    if (argc < 2) {
        std::cout << "Usage: " << argv[0] << " <image_file>" << std::endl;
        return 1;
    }

    ExifTool exifTool;
    
    if (!exifTool.openImage(argv[1])) {
        std::cerr << "Failed to open image: " << argv[1] << std::endl;
        return 1;
    }

    std::cout << "=== Image: " << argv[1] << " ===" << std::endl;
    
    if (exifTool.hasExifData()) {
        std::cout << "Has EXIF data: Yes" << std::endl;
        
        std::map<std::string, std::string> exifData = exifTool.getAllExifData();
        std::cout << "\nAll EXIF fields:" << std::endl;
        for (const auto& pair : exifData) {
            std::cout << "  " << pair.first << " = " << pair.second << std::endl;
        }
        
        std::string testKey = "Exif.Image.Model";
        if (exifTool.hasExifField(testKey)) {
            std::cout << "\nField '" << testKey << "' exists, value: " << exifTool.getExifField(testKey) << std::endl;
        } else {
            std::cout << "\nField '" << testKey << "' does not exist" << std::endl;
        }
        
        std::string newKey = "Exif.Image.Software";
        std::string newValue = "ExifTool Test 1.0";
        if (exifTool.setExifField(newKey, newValue)) {
            std::cout << "\nAdded field '" << newKey << "' with value: " << newValue << std::endl;
        } else {
            std::cout << "\nFailed to add field '" << newKey << "'" << std::endl;
        }
        
        std::string removeKey = "Exif.Image.Software";
        if (exifTool.removeExifField(removeKey)) {
            std::cout << "\nRemoved field '" << removeKey << "'" << std::endl;
        } else {
            std::cout << "\nFailed to remove field '" << removeKey << "'" << std::endl;
        }
        
        if (exifTool.saveImage("output.jpg")) {
            std::cout << "\nSaved modified image to output.jpg" << std::endl;
        } else {
            std::cout << "\nFailed to save image" << std::endl;
        }
        
    } else {
        std::cout << "Has EXIF data: No" << std::endl;
    }

    return 0;
}