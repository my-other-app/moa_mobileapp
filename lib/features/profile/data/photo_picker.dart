import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

/// Where a new profile photo comes from.
enum PhotoSource { camera, library }

/// Why no photo came back, in words for the person.
class PhotoPickFailure implements Exception {
  const PhotoPickFailure(this.message);

  final String message;

  @override
  String toString() => 'PhotoPickFailure: $message';
}

/// Takes or chooses one photo for the profile. Null when the person
/// backed out; [PhotoPickFailure] when it could not be done.
abstract class PhotoPicker {
  Future<String?> pick(PhotoSource source);
}

/// The system's own pickers (image_picker): the camera app, and the photo
/// picker -- PHPicker on iOS, the Photo Picker on Android -- neither of
/// which needs access to the whole library.
///
/// The photo comes back as a JPEG (an iPhone's HEIC is converted, which
/// the server needs) at most [maxSide] pixels across: a profile picture is
/// drawn at 500 px at most, and a phone photo is 4000.
class DevicePhotoPicker implements PhotoPicker {
  DevicePhotoPicker([ImagePicker? picker])
      : _picker = picker ?? ImagePicker(),
        side = maxSide,
        camera = CameraDevice.front;

  /// A screenshot or a photo of a screen for a help request: big enough to
  /// read its words ([screenshotSide]), from the camera at the back.
  DevicePhotoPicker.screenshots([ImagePicker? picker])
      : _picker = picker ?? ImagePicker(),
        side = screenshotSide,
        camera = CameraDevice.rear;

  final ImagePicker _picker;

  /// The most pixels across a picture comes back at.
  final double side;

  /// The camera a new photo is taken with.
  final CameraDevice camera;

  static const maxSide = 1080.0;

  /// A phone's screenshot is 2400 tall; at 2048 its words stay sharp, and
  /// it stays well under the help desk's 5 MB.
  static const screenshotSide = 2048.0;

  @override
  Future<String?> pick(PhotoSource source) async {
    try {
      final file = await _picker.pickImage(
        source: source == PhotoSource.camera
            ? ImageSource.camera
            : ImageSource.gallery,
        maxWidth: side,
        maxHeight: side,
        imageQuality: 85,
        preferredCameraDevice: camera,
        // No location or other metadata, and so no library permission.
        requestFullMetadata: false,
      );
      return file?.path;
    } on PlatformException catch (e) {
      debugPrint('DevicePhotoPicker: ${e.code} ${e.message}');
      throw PhotoPickFailure(messageFor(e.code, source));
    }
  }

  @visibleForTesting
  static String messageFor(String code, PhotoSource source) => switch (code) {
        'camera_access_denied' || 'camera_access_restricted' =>
          'Camera access is off for MyOtherApp. Turn it on in your '
              "phone's Settings to take a photo.",
        'photo_access_denied' || 'photo_access_restricted' =>
          'Photo access is off for MyOtherApp. Turn it on in your '
              "phone's Settings to choose a photo.",
        'no_available_camera' => 'This phone has no camera to use.',
        _ => source == PhotoSource.camera
            ? "Couldn't open the camera. Try again."
            : "Couldn't open your photos. Try again.",
      };
}

final photoPickerProvider = Provider<PhotoPicker>((ref) => DevicePhotoPicker());
