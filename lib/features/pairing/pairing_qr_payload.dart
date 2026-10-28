import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/core/utils/validators.dart';

/// A strictly parsed pairing payload.
///
/// Two versions are accepted and nothing else:
///   * `parentcontrol://pair?code=XXXXXXXX&v=1` — legacy short-lived code
///   * `parentcontrol://pair?id=PC7K4M2QRX&v=2` — permanent Child ID
///
/// Web links, other schemes, unknown versions, extra query fields and repeated
/// parameters are rejected so the scanner never acts on unexpected content.
class PairingQrPayload {
  const PairingQrPayload({required this.value, required this.isChildId});

  /// Normalized identifier (no dashes, upper case).
  final String value;
  final bool isChildId;

  static PairingQrPayload? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != Env.qrScheme.toLowerCase()) return null;
    if (uri.host.toLowerCase() != 'pair') return null;
    if (uri.path != '' && uri.path != '/') return null;
    if (uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) return null;

    final keys = uri.queryParametersAll.keys.toSet();
    if (keys.length != 2 || !keys.contains('v')) return null;
    final version = _single(uri, 'v');

    if (version == '1') {
      if (!keys.contains('code')) return null;
      final code = _single(uri, 'code');
      if (code == null) return null;
      final normalized = Validators.normalizePairingCode(code);
      if (!Validators.isLinkingCode(normalized)) return null;
      return PairingQrPayload(value: normalized, isChildId: false);
    }

    if (version == '2') {
      if (!keys.contains('id')) return null;
      final id = _single(uri, 'id');
      if (id == null) return null;
      final normalized = Validators.normalizePairingCode(id);
      if (!Validators.isChildId(normalized)) return null;
      return PairingQrPayload(value: normalized, isChildId: true);
    }

    return null;
  }

  static String? _single(Uri uri, String key) {
    final values = uri.queryParametersAll[key] ?? const <String>[];
    if (values.length != 1) return null;
    return values.first;
  }
}
