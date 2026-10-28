import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:get/get.dart' hide navigator;

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/widgets.dart';
import '../../../data/services/device_admin_service.dart';
import '../../../data/services/session_service.dart';

/// Asks Android for camera and microphone access. Returns an empty map when the
/// native bridge is unavailable.
typedef SelfTestPermissionRequest = Future<Map<String, bool>> Function({
  required bool camera,
  required bool microphone,
});

/// Opens a local capture stream. Injected only so tests can prove that nothing
/// is captured before the child taps Start test.
typedef SelfTestMediaOpener = Future<MediaStream> Function(
  Map<String, dynamic> constraints,
);

/// Whether this account may open local media at all.
typedef SelfTestCapturePolicy = bool Function();

/// What the sheet is doing right now. Capture only exists in [running]; every
/// other phase means no track is open.
enum SelfTestPhase { idle, starting, running, error }

/// A visible, local-only check of this phone's camera and microphone.
///
/// Nothing opens on its own. The sheet first explains what the test does; the
/// camera and microphone are requested only after the child taps Start test,
/// stay on this screen, and every track is stopped by Stop test, Cancel, or
/// closing the sheet. Nothing is recorded, stored, or sent to the guardian or
/// any server, and there is no background or foreground-service capture here.
///
/// Capture is denied by default when the signed-in role is not the child role,
/// so an unknown or missing role can never open the microphone.
class MediaSelfTestSheet extends StatefulWidget {
  const MediaSelfTestSheet({
    super.key,
    this.permissionRequest,
    this.openMedia,
    this.captureAllowed,
  });

  final SelfTestPermissionRequest? permissionRequest;
  final SelfTestMediaOpener? openMedia;
  final SelfTestCapturePolicy? captureAllowed;

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const MediaSelfTestSheet(),
    );
  }

  @override
  State<MediaSelfTestSheet> createState() => _MediaSelfTestSheetState();
}

class _MediaSelfTestSheetState extends State<MediaSelfTestSheet> {
  final RTCVideoRenderer _renderer = RTCVideoRenderer();

  SelfTestPhase _phase = SelfTestPhase.idle;
  MediaStream? _stream;
  String? _error;
  bool _captureAllowed = false;
  bool _testStopped = false;
  bool _usingFront = false;
  bool _micMuted = false;
  bool _rendererInitialized = false;
  bool _framesRendered = false;
  int _videoWidth = 0;
  int _videoHeight = 0;
  int _token = 0;

  bool get _isRunning => _phase == SelfTestPhase.running;
  bool get _hasCamera => _stream?.getVideoTracks().isNotEmpty ?? false;
  bool get _hasMicrophone => _stream?.getAudioTracks().isNotEmpty ?? false;

  @override
  void initState() {
    super.initState();
    // Fail closed: no role, a parent role, or no session service all mean the
    // microphone stays closed.
    _captureAllowed = widget.captureAllowed?.call() ?? _defaultCaptureAllowed();
  }

  bool _defaultCaptureAllowed() {
    if (!Get.isRegistered<SessionService>()) return false;
    return Get.find<SessionService>().isChild;
  }

  Future<Map<String, bool>> _requestPermissions({
    required bool camera,
    required bool microphone,
  }) {
    final request = widget.permissionRequest;
    if (request != null) {
      return request(camera: camera, microphone: microphone);
    }
    if (!Get.isRegistered<DeviceAdminService>()) {
      return Future<Map<String, bool>>.value(const {});
    }
    return Get.find<DeviceAdminService>().requestPermissions(
      camera: camera,
      microphone: microphone,
    );
  }

  Future<MediaStream> _openMedia(Map<String, dynamic> constraints) {
    final open = widget.openMedia;
    if (open != null) return open(constraints);
    return navigator.mediaDevices.getUserMedia(constraints);
  }

  /// Requests permission and opens media. Never called from [initState].
  Future<void> _start() async {
    if (!_captureAllowed) return;
    final token = ++_token;
    setState(() {
      _phase = SelfTestPhase.starting;
      _error = null;
      _testStopped = false;
      _framesRendered = false;
      _videoWidth = 0;
      _videoHeight = 0;
    });
    MediaStream? stream;
    try {
      final permissions = await _requestPermissions(
        camera: true,
        microphone: true,
      );
      if (!mounted || token != _token) return;
      if (permissions.isNotEmpty &&
          (permissions['camera'] != true || permissions['microphone'] != true)) {
        setState(() {
          _phase = SelfTestPhase.error;
          _error =
              'Android denied camera or microphone access. No test was run. '
              'Allow both for this app in Android Settings, then tap Try '
              'again.';
        });
        return;
      }
      stream = await _openMedia({
        'audio': {
          'echoCancellation': true,
          'noiseSuppression': true,
        },
        'video': {
          'facingMode': _usingFront ? 'user' : 'environment',
          'width': {'ideal': 640},
          'height': {'ideal': 480},
        },
      });
      if (!mounted || token != _token) {
        await _stopStream(stream);
        return;
      }
      if (!_rendererInitialized) {
        // Never leave the child on an endless "starting" state if the platform
        // renderer does not answer.
        await _renderer
            .initialize()
            .timeout(const Duration(seconds: 8));
        _renderer.onFirstFrameRendered = _markFramesRendered;
        _renderer.onResize = _markFramesRendered;
        _rendererInitialized = true;
      }
      if (!mounted || token != _token) {
        await _stopStream(stream);
        return;
      }
      _renderer.srcObject = stream;
      setState(() {
        _stream = stream;
        _phase = SelfTestPhase.running;
        _micMuted = false;
        _framesRendered = _renderer.videoWidth > 0 && _renderer.videoHeight > 0;
        _videoWidth = _renderer.videoWidth;
        _videoHeight = _renderer.videoHeight;
      });
    } catch (caught) {
      // The preview, permission prompt, or capture failed. Release anything
      // that opened so no track is left running behind an error message.
      if (stream != null) {
        await _stopStream(stream);
      }
      if (!mounted || token != _token) return;
      setState(() {
        _stream = null;
        _phase = SelfTestPhase.error;
        _error = _errorMessage(caught);
      });
    }
  }

  String _errorMessage(Object caught) {
    final text = caught.toString().toLowerCase();
    if (text.contains('permission') ||
        text.contains('notallowed') ||
        text.contains('denied')) {
      return 'Android denied camera or microphone access. No test is running. '
          'Allow both for this app in Android Settings, then tap Try again.';
    }
    return 'The camera and microphone could not be started. Another app may be '
        'using them. Nothing is being captured; try again.';
  }

  /// Leaves the starting phase without opening anything. A capture that lands
  /// later is stopped by the token check in [_start].
  void _cancelStart() {
    if (_phase != SelfTestPhase.starting) return;
    _token++;
    setState(() {
      _phase = SelfTestPhase.idle;
      _error = null;
      _testStopped = false;
    });
  }

  /// Visible Stop test action: stops and disposes every track, keeps the sheet
  /// open so the child can see that media is off or run the test again.
  Future<void> _stopTest() async {
    _token++;
    final stream = _stream;
    final hadMedia = stream != null || _phase != SelfTestPhase.idle;
    setState(() {
      _stream = null;
      _phase = SelfTestPhase.idle;
      _testStopped = hadMedia;
      _micMuted = false;
      _framesRendered = false;
      _videoWidth = 0;
      _videoHeight = 0;
      _error = null;
    });
    try {
      _renderer.srcObject = null;
    } catch (_) {
      // Renderer may already be released.
    }
    await _stopStream(stream);
  }

  Future<void> _switchCamera() async {
    if (_stream == null) return;
    final tracks = _stream!.getVideoTracks();
    if (tracks.isEmpty) return;
    try {
      await Helper.switchCamera(tracks.first);
      if (!mounted) return;
      setState(() => _usingFront = !_usingFront);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Android could not switch cameras on this phone.';
      });
    }
  }

  void _toggleMicrophone() {
    final tracks = _stream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    final nextMuted = !_micMuted;
    for (final track in tracks) {
      track.enabled = !nextMuted;
    }
    setState(() => _micMuted = nextMuted);
  }

  void _markFramesRendered() {
    if (!mounted) return;
    final width = _renderer.videoWidth;
    final height = _renderer.videoHeight;
    if (width <= 0 || height <= 0) return;
    if (_framesRendered && _videoWidth == width && _videoHeight == height) {
      return;
    }
    setState(() {
      _framesRendered = true;
      _videoWidth = width;
      _videoHeight = height;
    });
  }

  Future<void> _stopStream(MediaStream? stream) async {
    if (stream == null) return;
    for (final track in stream.getTracks()) {
      try {
        await track.stop();
      } catch (_) {
        // Track already ended.
      }
    }
    try {
      await stream.dispose();
    } catch (_) {
      // Stream already released.
    }
  }

  @override
  void dispose() {
    _token++;
    final stream = _stream;
    _stream = null;
    try {
      _renderer.srcObject = null;
    } catch (_) {
      // Renderer may already be released.
    }
    unawaited(_stopStream(stream));
    unawaited(_renderer.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 10,
        bottom: 24 + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.muted.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              'Camera and microphone test',
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            const Text(
              'This test uses your microphone locally so you can check it. It '
              'also opens the camera for a preview on this screen. Nothing is '
              'recorded, saved, or sent, and it stops when you tap Stop test or '
              'close this sheet.',
              style: TextStyle(height: 1.45, color: AppColors.muted),
            ),
            const SizedBox(height: 16),
            if (!_captureAllowed)
              const InfoBanner(
                tone: BannerTone.warning,
                title: 'Test not available',
                message:
                    'This test only runs on the child account. This account is '
                    'not signed in as the child, so the camera and microphone '
                    'stay closed.',
              )
            else ...[
              _preview(),
              const SizedBox(height: 14),
              if (_error != null) ...[
                InfoBanner(
                  tone: BannerTone.danger,
                  title: 'Test failed',
                  message: _error!,
                ),
                const SizedBox(height: 12),
              ],
              if (_testStopped && _phase == SelfTestPhase.idle) ...[
                const InfoBanner(
                  tone: BannerTone.info,
                  title: 'Test stopped',
                  message: 'The camera and microphone are off.',
                ),
                const SizedBox(height: 12),
              ],
              ..._statusRows(),
              _controls(),
            ],
            const SizedBox(height: 8),
            TextButton(
              onPressed: () => Navigator.of(context).maybePop(),
              child: const Text('Close'),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _statusRows() {
    switch (_phase) {
      case SelfTestPhase.starting:
        return const [
          Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Text('Waiting for Android and the camera…'),
                ),
              ],
            ),
          ),
        ];
      case SelfTestPhase.idle:
        if (_testStopped) return const [];
        return const [
          InfoBanner(
            tone: BannerTone.info,
            message:
                'The camera and microphone are off until you tap Start test.',
          ),
        ];
      case SelfTestPhase.error:
      case SelfTestPhase.running:
        break;
    }
    if (_stream == null) return const [];
    return [
      KeyValueRow(
        label: 'Camera',
        value: _cameraValue,
        valueColor: _hasCamera
            ? (_framesRendered ? AppColors.success : AppColors.warning)
            : AppColors.danger,
      ),
      KeyValueRow(
        label: 'Microphone',
        value: _microphoneValue,
        valueColor: _hasMicrophone ? AppColors.success : AppColors.danger,
      ),
      KeyValueRow(
        label: 'Video frames',
        value: _framesRendered
            ? '$_videoWidth×$_videoHeight received'
            : 'Waiting for the first frame…',
        valueColor: _framesRendered ? AppColors.success : AppColors.warning,
      ),
      const KeyValueRow(label: 'Recording', value: 'Off — nothing is saved'),
    ];
  }

  String get _cameraValue {
    if (!_hasCamera) return 'No camera track';
    if (_framesRendered) {
      return _usingFront
          ? 'Front camera preview running'
          : 'Main camera preview running';
    }
    return 'Camera opened, waiting for the first frame';
  }

  String get _microphoneValue {
    if (!_hasMicrophone) return 'No audio track';
    if (_micMuted) return 'Track running, muted for this test';
    return 'Track running, not sent anywhere';
  }

  Widget _controls() {
    if (_phase == SelfTestPhase.starting) {
      return AppButton(
        label: 'Cancel',
        icon: Icons.close,
        outlined: true,
        onPressed: _cancelStart,
      );
    }
    if (_isRunning) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppButton(
            label: 'Switch camera',
            icon: Icons.cameraswitch_outlined,
            outlined: true,
            onPressed: _hasCamera ? _switchCamera : null,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: _micMuted ? 'Unmute microphone' : 'Mute microphone',
            icon: _micMuted ? Icons.mic_off : Icons.mic,
            outlined: true,
            onPressed: _hasMicrophone ? _toggleMicrophone : null,
          ),
          const SizedBox(height: 10),
          AppButton(
            label: 'Stop test',
            icon: Icons.stop_circle_outlined,
            destructive: true,
            onPressed: _stopTest,
          ),
        ],
      );
    }
    return AppButton(
      label: _phase == SelfTestPhase.error ? 'Try again' : 'Start test',
      icon: _phase == SelfTestPhase.error ? Icons.refresh : Icons.mic_none,
      onPressed: _start,
    );
  }

  Widget _preview() {
    return AspectRatio(
      aspectRatio: 4 / 3,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          color: const Color(0xFF11151C),
          child: _stream == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.videocam_off_outlined,
                        size: 44,
                        color: Colors.white.withValues(alpha: 0.45),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _phase == SelfTestPhase.starting
                            ? 'Opening the camera…'
                            : 'Camera off',
                        style: TextStyle(
                          color: Colors.white.withValues(alpha: 0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                )
              : RTCVideoView(
                  _renderer,
                  objectFit: RTCVideoViewObjectFit.RTCVideoViewObjectFitCover,
                  mirror: _usingFront,
                ),
        ),
      ),
    );
  }
}
