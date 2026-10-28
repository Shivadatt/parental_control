import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:parent_control/core/errors/app_exception.dart';
import 'package:parent_control/data/models/pairing.dart';
import 'package:parent_control/data/services/connectivity_service.dart';
import 'package:parent_control/features/pairing/controllers/pairing_redeem_controller.dart';

import '../auth/fakes.dart';

void main() {
  setUpAll(registerRepositoryFallbacks);

  late MockPairingRepository pairing;
  late ConnectivityService connectivity;
  late PairingRedeemController controller;

  setUp(() {
    pairing = MockPairingRepository();
    connectivity = ConnectivityService();
    controller = PairingRedeemController(
      pairingRepository: pairing,
      connectivity: connectivity,
    );
    controller.start('family-1');
  });

  for (final code in <String>[
    'invalid_code',
    'code_expired',
    'rate_limited',
    'child_already_linked',
    'not_configured',
  ]) {
    test('keeps the server failure code $code unchanged', () async {
      when(
        () => pairing.redeemLinkingCode(
          code: 'ABCD1234',
          familyId: 'family-1',
        ),
      ).thenThrow(AppException(code, 'Rejected with $code'));

      final redeemed = await controller.redeem('abcd-1234');

      expect(redeemed, isFalse);
      expect(controller.error.value?.code, code);
      expect(controller.error.value?.message, 'Rejected with $code');
      expect(controller.request.value, isNull);
      expect(controller.isRedeeming.value, isFalse);
    });
  }

  test('a successful redemption shows only the server request', () async {
    final pending = testPairingRequest();
    when(
      () => pairing.redeemLinkingCode(
        code: 'ABCD1234',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);

    final redeemed = await controller.redeem('abcd-1234');

    expect(redeemed, isTrue);
    expect(controller.error.value, isNull);
    expect(controller.request.value?.id, pending.id);
    expect(controller.request.value?.status, PairingRequestStatus.pendingChild);
    expect(controller.request.value?.status, isNot(PairingRequestStatus.approved));
  });

  test('checking status reloads the request from the server', () async {
    final pending = testPairingRequest();
    final approved = testPairingRequest(status: PairingRequestStatus.approved);
    when(
      () => pairing.redeemLinkingCode(
        code: 'ABCD1234',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);
    when(() => pairing.fetchForFamily('family-1'))
        .thenAnswer((_) async => [approved]);

    await controller.redeem('abcd-1234');
    await controller.checkStatus();

    expect(controller.error.value, isNull);
    expect(controller.request.value?.status, PairingRequestStatus.approved);
  });

  test('a missing request is reported instead of being invented', () async {
    final pending = testPairingRequest();
    when(
      () => pairing.redeemLinkingCode(
        code: 'ABCD1234',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);
    when(() => pairing.fetchForFamily('family-1')).thenAnswer((_) async => []);

    await controller.redeem('abcd-1234');
    await controller.checkStatus();

    expect(controller.error.value?.code, AppErrorCodes.notFound);
    expect(controller.request.value?.id, pending.id);
    expect(
      controller.request.value?.status,
      PairingRequestStatus.pendingChild,
    );
  });

  test('redemption requires a family from the route', () async {
    controller.start(null);

    final redeemed = await controller.redeem('ABCD1234');

    expect(redeemed, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('offline redemption never calls either repository path', () async {
    connectivity.isOnline.value = false;

    final redeemed = await controller.redeem('ABCD1234');

    expect(redeemed, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.network);
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
    verifyNever(
      () => pairing.inviteChild(
        childId: any(named: 'childId'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('malformed codes are rejected before the network call', () async {
    final redeemed = await controller.redeem('ABC');

    expect(redeemed, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
    verifyNever(
      () => pairing.inviteChild(
        childId: any(named: 'childId'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('a canonical Child ID invites the child instead of redeeming a code',
      () async {
    final pending = testPairingRequest();
    when(
      () => pairing.inviteChild(
        childId: 'PC7K4M2QRX',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);

    final redeemed = await controller.redeem('PC7K4M2QRX');

    expect(redeemed, isTrue);
    expect(controller.error.value, isNull);
    expect(controller.request.value?.id, pending.id);
    expect(controller.request.value?.status, PairingRequestStatus.pendingChild);
    verify(
      () => pairing.inviteChild(
        childId: 'PC7K4M2QRX',
        familyId: 'family-1',
      ),
    ).called(1);
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('a dashed lower-case Child ID is normalized before the invite',
      () async {
    final pending = testPairingRequest();
    when(
      () => pairing.inviteChild(
        childId: 'PC7K4M2QRX',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);

    final redeemed = await controller.redeem('pc-7k4m2qrx');

    expect(redeemed, isTrue);
    expect(controller.request.value?.id, pending.id);
    verify(
      () => pairing.inviteChild(
        childId: 'PC7K4M2QRX',
        familyId: 'family-1',
      ),
    ).called(1);
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('an 8-character code still uses the legacy repository path', () async {
    final pending = testPairingRequest();
    when(
      () => pairing.redeemLinkingCode(
        code: '4K9M2QRT',
        familyId: 'family-1',
      ),
    ).thenAnswer((_) async => pending);

    final redeemed = await controller.redeem('4k9m-2qrt');

    expect(redeemed, isTrue);
    expect(controller.request.value?.id, pending.id);
    verify(
      () => pairing.redeemLinkingCode(
        code: '4K9M2QRT',
        familyId: 'family-1',
      ),
    ).called(1);
    verifyNever(
      () => pairing.inviteChild(
        childId: any(named: 'childId'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  test('a malformed Child ID never reaches either repository path', () async {
    final redeemed = await controller.redeem('PC-123');

    expect(redeemed, isFalse);
    expect(controller.error.value?.code, AppErrorCodes.validation);
    verifyNever(
      () => pairing.inviteChild(
        childId: any(named: 'childId'),
        familyId: any(named: 'familyId'),
      ),
    );
    verifyNever(
      () => pairing.redeemLinkingCode(
        code: any(named: 'code'),
        familyId: any(named: 'familyId'),
      ),
    );
  });

  for (final code in <String>[
    'invalid_code',
    'child_already_linked',
    'rate_limited',
  ]) {
    test('keeps the invite failure code $code unchanged', () async {
      when(
        () => pairing.inviteChild(
          childId: 'PC7K4M2QRX',
          familyId: 'family-1',
        ),
      ).thenThrow(AppException(code, 'Invite rejected with $code'));

      final redeemed = await controller.redeem('PC7K4M2QRX');

      expect(redeemed, isFalse);
      expect(controller.error.value?.code, code);
      expect(controller.error.value?.message, 'Invite rejected with $code');
      expect(controller.request.value, isNull);
      expect(controller.isRedeeming.value, isFalse);
      verifyNever(
        () => pairing.redeemLinkingCode(
          code: any(named: 'code'),
          familyId: any(named: 'familyId'),
        ),
      );
    });
  }
}
