import 'dart:typed_data';

enum FoodImagePickSource {
  camera,
  gallery,
}

abstract class IFoodImagePickerService {
  /// Prompts the user to pick or take an image from camera or gallery.
  /// Returns the file path or URI string, or null if cancelled.
  Future<String?> pickImage(FoodImagePickSource source);

  /// Retrieves the raw bytes for the selected image path (works across Mobile & Web).
  Future<Uint8List?> getImageBytes(String imagePath);
}
