import 'package:permission_handler/permission_handler.dart';
import '../utils/cook_mode_logger.dart';

/// Service to handle camera permissions for the cook mode feature
class CookModePermissionService {
  /// Checks if camera permission is granted
  Future<bool> checkPermission() async {
    try {
      final status = await Permission.camera.status;
      CookModeLogger.logCookMode('Permission check', data: {'status': status.toString()});
      return status.isGranted;
    } catch (e, stackTrace) {
      CookModeLogger.error('Permission', 'Failed to check camera permission',
        data: {'error': e.toString()},
        stackTrace: stackTrace
      );
      return false;
    }
  }

  /// Requests camera permission
  Future<bool> requestPermission() async {
    try {
      CookModeLogger.logCookMode('Requesting camera permission');
      final status = await Permission.camera.request();
      CookModeLogger.logCookMode('Permission request result', data: {'status': status.toString()});
      
      return status.isGranted;
    } catch (e, stackTrace) {
      CookModeLogger.error('Permission', 'Failed to request camera permission',
        data: {'error': e.toString()},
        stackTrace: stackTrace
      );
      return false;
    }
  }

  /// Opens app settings if permission is permanently denied
  Future<bool> openSettings() async {
    try {
      CookModeLogger.logCookMode('Opening app settings');
      return await openAppSettings();
    } catch (e, stackTrace) {
      CookModeLogger.error('Permission', 'Failed to open app settings',
        data: {'error': e.toString()},
        stackTrace: stackTrace
      );
      return false;
    }
  }

  /// Checks if permission is permanently denied
  Future<bool> isPermanentlyDenied() async {
    try {
      final status = await Permission.camera.status;
      return status.isPermanentlyDenied;
    } catch (e, stackTrace) {
      CookModeLogger.error('Permission', 'Failed to check permanent denial',
        data: {'error': e.toString()},
        stackTrace: stackTrace
      );
      return false;
    }
  }
} 