// config/cloudinary_config.dart - SIMPLIFIED VERSION
class CloudinaryConfig {
  static const String cloudName = 'djwzc1hrq';
  static const String apiKey = '242645349617368';
  static const String apiSecret = 'prWvFRd64p3qejkoAc6bij6zSDw';


  static const String uploadPreset = 'image_present';

  static String get uploadUrl =>
      'https://api.cloudinary.com/v1_1/$cloudName/image/upload';
}