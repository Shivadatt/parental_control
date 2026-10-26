import 'package:parent_control/core/config/env.dart';
import 'package:parent_control/core/utils/validators.dart';

/// A strictly parsed `parentcontrol://pair?code=…&v=1` payload. Anything else
/// (web links, other schemes, newer versions, extra query fields) is rejected
/// so the scanner never acts on unexpected content.
class PairingQrPayload {
  const PairingQrPayload({required this.code});

  final String code;

  static PairingQrPayload? tryParse(String raw) {
    final uri = Uri.tryParse(raw.trim());
    if (uri == null) return null;
    if (uri.scheme.toLowerCase() != Env.qrScheme.toLowerCase()) return null;
    if (uri.host.toLowerCase() != 'pair') return null;
    if (uri.path != '' && uri.path != '/') return null;
    if (uri.userInfo.isNotEmpty || uri.hasPort || uri.hasFragment) return null;
    final keys = uri.queryParametersAll.keys.toSet();
    if (keys.length != 2 ||
        !keys.contains('code') ||
        !keys.contains('v')) {
      return null;
    }
    final versions = uri.queryParametersAll['v'] ?? const <String>[];
    final codes = uri.queryParametersAll['code'] ?? const <String>[];
    if (versions.length != 1 || versions.first != '1') return null;
    if (codes.length != 1) return null;
    final normalized = Validators.normalizePairingCode(codes.first);
    if (Validators.pairingCode(normalized) != null) return null;
    return PairingQrPayload(code: normalized);
  }
}
