import 'dart:typed_data';
import 'package:image_picker/image_picker.dart';
import 'package:fitfuel/features/food_scan/domain/services/food_image_picker_service.dart';

class FoodImagePickerServiceImpl implements IFoodImagePickerService {
  final ImagePicker _picker;

  FoodImagePickerServiceImpl({ImagePicker? picker})
      : _picker = picker ?? ImagePicker();

  @override
  Future<String?> pickImage(FoodImagePickSource source) async {
    final imageSource = source == FoodImagePickSource.camera
        ? ImageSource.camera
        : ImageSource.gallery;

    final XFile? file = await _picker.pickImage(
      source: imageSource,
      maxWidth: 1280,
      maxHeight: 1280,
      imageQuality: 85,
    );

    return file?.path;
  }

  @override
  Future<Uint8List?> getImageBytes(String imagePath) async {
    if (imagePath.isEmpty) return null;
    final file = XFile(imagePath);
    return await file.readAsBytes();
  }
}
