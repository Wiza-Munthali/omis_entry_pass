import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The bucket refuses files over 400 KB (docs/SPEC.md → flow 3, step 2).
const maxIdPhotoBytes = 400 * 1024;

/// Takes an ID photo with the phone's camera, resized to at most 1600 px and compressed.
typedef TakePhoto = Future<Uint8List?> Function();

Future<Uint8List?> takeIdPhotoWithCamera() async {
  final file = await ImagePicker().pickImage(
    source: ImageSource.camera,
    maxWidth: 1600,
    maxHeight: 1600,
    imageQuality: 70,
    preferredCameraDevice: CameraDevice.rear,
  );
  return file?.readAsBytes();
}

/// "Add ID photo" tile (G7); shows the photo with Retake / Remove once taken.
class IdPhotoTile extends StatelessWidget {
  const IdPhotoTile({
    super.key,
    required this.photo,
    required this.onTake,
    required this.onRemove,
    this.error,
  });

  final Uint8List? photo;
  final VoidCallback onTake;
  final VoidCallback onRemove;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    if (photo != null) {
      return Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Image.memory(
              photo!,
              width: 120,
              height: 84,
              fit: BoxFit.cover,
            ),
          ),
          const SizedBox(width: AppSpacing.s2),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('ID photo added', style: t.labelLarge),
                Text(
                  '${(photo!.lengthInBytes / 1024).round()} KB',
                  style: const TextStyle(color: AppColors.textMuted),
                ),
                Wrap(
                  children: [
                    TextButton(
                      onPressed: onTake,
                      child: const Text(
                        'Retake',
                        style: TextStyle(color: AppColors.brandStrong),
                      ),
                    ),
                    TextButton(
                      onPressed: onRemove,
                      child: const Text(
                        'Remove',
                        style: TextStyle(color: AppColors.danger),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Material(
          color: AppColors.surface2,
          borderRadius: BorderRadius.circular(AppRadii.card),
          child: InkWell(
            key: const Key('add-id-photo'),
            borderRadius: BorderRadius.circular(AppRadii.card),
            onTap: onTake,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.s3),
              child: Column(
                children: [
                  const CircleAvatar(
                    radius: 28,
                    backgroundColor: AppColors.brandSoft,
                    child: Icon(
                      Icons.photo_camera_outlined,
                      color: AppColors.brandStrong,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.s1),
                  Text(
                    'Add ID photo',
                    style: t.titleLarge?.copyWith(fontSize: 18),
                  ),
                  const Text(
                    'Photograph the ID card, flat and readable',
                    style: TextStyle(color: AppColors.textMuted),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 4),
          Text(error!, style: const TextStyle(color: AppColors.danger)),
        ],
      ],
    );
  }
}
