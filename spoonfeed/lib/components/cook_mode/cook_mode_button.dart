import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../providers/cook_mode_provider.dart';
import '../../utils/cook_mode_logger.dart';

/// A button widget that allows users to toggle cook mode and displays its current state.
/// This button is designed to be placed in the video player controls.
class CookModeButton extends StatelessWidget {
  const CookModeButton({super.key});

  void _showSettingsMenu(BuildContext context, CookModeProvider provider) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _CookModeSettings(provider: provider),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<CookModeProvider>(
      builder: (context, provider, _) {
        final isActive = provider.isActive;
        final isProcessing = provider.isProcessing;
        final hasError = provider.error != null;

        // Show loading state
        if (isProcessing) {
          return Semantics(
            button: true,
            enabled: false,
            label: 'Cook Mode is initializing',
            child: const _ButtonContainer(
              child: SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          );
        }

        final String tooltipMessage = hasError
            ? 'Tap to clear error and try again'
            : isActive
                ? 'Disable hands-free cooking mode'
                : 'Enable hands-free cooking mode';

        final String semanticLabel = hasError
            ? 'Cook Mode error - tap to retry'
            : isActive
                ? 'Disable hands-free cooking mode'
                : 'Enable hands-free cooking mode';

        return Semantics(
          button: true,
          enabled: true,
          label: semanticLabel,
          child: Tooltip(
            message: tooltipMessage,
            child: _ButtonContainer(
              onTap: hasError
                  ? () {
                      HapticFeedback.lightImpact();
                      provider.clearError();
                      CookModeLogger.logCookMode('Error cleared by user tap');
                    }
                  : () {
                      HapticFeedback.lightImpact();
                      provider.toggleCookMode(context);
                      CookModeLogger.logCookMode('Button tapped', data: {
                        'isEnabled': provider.isActive,
                        'currentState': provider.isActive ? 'active' : 'inactive',
                      });
                    },
              onLongPress: () => _showSettingsMenu(context, provider),
              child: Stack(
                children: [
                  // Main icon
                  Icon(
                    isActive ? Icons.gesture : Icons.touch_app_outlined,
                    color: Colors.white,
                    size: 24,
                    semanticLabel: null, // Handled by parent Semantics
                  ),
                  
                  // Error indicator
                  if (hasError)
                    const Positioned(
                      right: -4,
                      top: -4,
                      child: Icon(
                        Icons.error,
                        color: Colors.red,
                        size: 14,
                        semanticLabel: null, // Handled by parent Semantics
                      ),
                    ),
                    
                  // Active indicator
                  if (isActive)
                    Positioned(
                      right: -4,
                      top: -4,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: const BoxDecoration(
                          color: Colors.green,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Container widget for the cook mode button that provides
/// consistent styling and feedback animations.
class _ButtonContainer extends StatelessWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  const _ButtonContainer({
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      behavior: HitTestBehavior.opaque, // Ensures taps are caught even on transparent areas
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: Colors.black.withOpacity(0.6),
          shape: BoxShape.circle,
        ),
        child: Center(child: child),
      ),
    );
  }
}

class _CookModeSettings extends StatelessWidget {
  final CookModeProvider provider;

  const _CookModeSettings({required this.provider});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Cook Mode Settings',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text(
            'Rewind Duration',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'When resuming video playback, rewind by this many seconds to catch up on missed steps.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).textTheme.bodySmall?.color,
            ),
          ),
          const SizedBox(height: 16),
          StatefulBuilder(
            builder: (context, setState) {
              final duration = provider.rewindDurationMs / 1000;
              return Column(
                children: [
                  Slider(
                    value: duration,
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '${duration.round()} seconds',
                    onChanged: (value) {
                      provider.setRewindDuration((value * 1000).round());
                      setState(() {});
                    },
                  ),
                  Text(
                    '${duration.round()} seconds',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),
          // Add more settings here in the future
        ],
      ),
    );
  }
} 