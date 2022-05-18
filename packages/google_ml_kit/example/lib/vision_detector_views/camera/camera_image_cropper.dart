import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_commons/google_mlkit_commons.dart';
import 'package:typed_data/typed_buffers.dart';

import 'camera_image_converter.dart';

/// Camera Image Cropper, in order to limit the barcode scan computations.
///
/// Use CameraController with imageFormatGroup: ImageFormatGroup.yuv420
class CameraImageCropper extends CameraImageConverter {
  final CropRect cropRect;
  late int _left;
  late int _top;
  late int _width;
  late int _height;

  CameraImageCropper({
    required CameraImage cameraImage,
    required CameraDescription cameraDescription,
    required this.cropRect,
  }) : super(cameraImage: cameraImage, cameraDescription: cameraDescription) {
    _computeCropParameters();
  }

  void _computeCropParameters() {
    final int fullWidth = cameraImage.width;
    final int fullHeight = cameraImage.height;
    final int orientation = cameraDescription.sensorOrientation;

    int _getEven(final double value) => 2 * (value ~/ 2);

    if (orientation == 0) {
      _width = _getEven(fullWidth * cropRect.width);
      _height = _getEven(fullHeight * cropRect.height);
      _left = _getEven(fullWidth * cropRect.left);
      _top = _getEven(fullHeight * cropRect.top);
      return;
    }
    if (orientation == 90) {
      _width = _getEven(fullWidth * cropRect.height);
      _height = _getEven(fullHeight * cropRect.width);
      _left = _getEven(fullWidth * cropRect.top);
      _top = _getEven(fullHeight * cropRect.left);
      return;
    }
    throw Exception('Orientation $orientation not dealt with for the moment');
  }

  // cf. https://en.wikipedia.org/wiki/YUV#Y′UV420p_(and_Y′V12_or_YV12)_to_RGB888_conversion
  static const Map<int, int> _planeDividers = <int, int>{
    0: 1, // Y
    1: 2, // U
    2: 2, // V
  };

  @override
  InputImage getInputImage() {
    final InputImageRotation imageRotation =
        InputImageRotationValue.fromRawValue(
                cameraDescription.sensorOrientation) ??
            InputImageRotation.rotation0deg;

    final InputImageFormat inputImageFormat =
        InputImageFormatValue.fromRawValue(
      int.parse(cameraImage.format.raw.toString()),
    )!;

    final List<InputImagePlaneMetadata> planeData = getPlaneMetaData();

    final InputImageData inputImageData = InputImageData(
      size: getSize(),
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    return InputImage.fromBytes(
      bytes: getBytes(),
      inputImageData: inputImageData,
    );
  }

  Size getSize() => Size(_width.toDouble(), _height.toDouble());

  Uint8List getBytes() {
    int size = 0;
    for (final int divider in _planeDividers.values) {
      size += (_width ~/ divider) * (_height ~/ divider);
    }
    final Uint8Buffer buffer = Uint8Buffer(size);
    final int imageWidth = cameraImage.width;
    int planeIndex = 0;
    int bufferOffset = 0;
    for (final Plane plane in cameraImage.planes) {
      final int divider = _planeDividers[planeIndex]!;
      final int fullWidth = imageWidth ~/ divider;
      final int cropLeft = _left ~/ divider;
      final int cropTop = _top ~/ divider;
      final int cropWidth = _width ~/ divider;
      final int cropHeight = _height ~/ divider;

      for (int i = 0; i < cropHeight; i++) {
        for (int j = 0; j < cropWidth; j++) {
          buffer[bufferOffset++] =
              plane.bytes[fullWidth * (cropTop + i) + cropLeft + j];
        }
      }
      planeIndex++;
    }

    return buffer.buffer.asUint8List();
  }

  List<InputImagePlaneMetadata> getPlaneMetaData() {
    final List<InputImagePlaneMetadata> planeData = <InputImagePlaneMetadata>[];
    for (final Plane plane in cameraImage.planes) {
      planeData.add(
        InputImagePlaneMetadata(
          bytesPerRow: (plane.bytesPerRow * _width) ~/ cameraImage.width,
          height: plane.height == null
              ? null
              : (plane.height! * _height) ~/ cameraImage.height,
          width: plane.width == null
              ? null
              : (plane.width! * _width) ~/ cameraImage.width,
        ),
      );
    }
    return planeData;
  }
}

/// [left], [top], [width] and [height] are values between 0 and 1
/// that delimit the cropping area.
/// For instance:
/// * left: 0, top: 0, width: 1, height: .2 delimit the left top 20% banner
/// * left: .5, top: .5, width: .5, height: ..5 the bottom right rect
class CropRect {
  /// left corner
  final double left;

  /// top corner
  final double top;

  /// width percentage of the screen
  final double width;

  /// height percentage of the screen
  final double height;

  CropRect(
      {required this.left,
      required this.top,
      required this.width,
      required this.height}) {
    _validateCropParameters();
  }

  void _validateCropParameters() {
    assert(width > 0 && width <= 1);
    assert(height > 0 && height <= 1);
    assert(left >= 0 && left < 1);
    assert(top >= 0 && top < 1);
    assert(left + width <= 1);
    assert(top + height <= 1);
  }
}
