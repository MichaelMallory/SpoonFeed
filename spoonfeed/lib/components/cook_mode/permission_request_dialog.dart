import 'package:flutter/material.dart';
import '../../services/cook_mode_permission_service.dart';
import '../../utils/cook_mode_logger.dart';

/// Dialog to request camera permission for cook mode
class PermissionRequestDialog extends StatelessWidget {
  final CookModePermissionService _permissionService;

  const PermissionRequestDialog({
    Key? key,
    required CookModePermissionService permissionService,
  }) : _permissionService = permissionService, super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Camera Permission Required'),
      content: const Text(
        'SpoonFeed needs camera access for hands-free cooking mode. '
        'This allows you to control video playback with gestures while cooking.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            final granted = await _permissionService.requestPermission();
            if (context.mounted) {
              Navigator.of(context).pop(granted);
            }
          },
          child: const Text('Allow Camera'),
        ),
      ],
    );
  }
}

/// Dialog shown when permission is permanently denied
class PermissionDeniedDialog extends StatelessWidget {
  final CookModePermissionService _permissionService;

  const PermissionDeniedDialog({
    Key? key,
    required CookModePermissionService permissionService,
  }) : _permissionService = permissionService, super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Camera Permission Required'),
      content: const Text(
        'SpoonFeed needs camera access for hands-free cooking mode. '
        'Please enable camera access in your device settings.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Not Now'),
        ),
        ElevatedButton(
          onPressed: () async {
            final opened = await _permissionService.openSettings();
            if (context.mounted) {
              Navigator.of(context).pop(opened);
            }
          },
          child: const Text('Open Settings'),
        ),
      ],
    );
  }
} 