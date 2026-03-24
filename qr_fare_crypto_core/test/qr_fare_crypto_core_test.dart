import 'package:flutter_test/flutter_test.dart';
import 'package:qr_fare_crypto_core/qr_fare_crypto_core.dart';
import 'package:pointycastle/export.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  
  group('Crypto Core Tests', () {
    test('Generate key pair and export/import PEM', () {
      final keyPair = KeyManager.generateKeyPair();
      final publicKey = keyPair.publicKey as ECPublicKey;
      
      final pem = KeyManager.exportPublicKeyPem(publicKey);
      expect(pem.contains('BEGIN PUBLIC KEY'), isTrue);
      
      final importedPub = KeyManager.importPublicKeyPem(pem);
      expect(importedPub.Q!.getEncoded(false), equals(publicKey.Q!.getEncoded(false)));
    });

    test('Sign and Verify Payload', () {
      final keyPair = KeyManager.generateKeyPair();
      final privKey = keyPair.privateKey as ECPrivateKey;
      final pubKey = keyPair.publicKey as ECPublicKey;
      
      final rawPayload = '{"user_id":"STU-123","amount":100,"nonce":1,"timestamp":1700000000}';
      
      final signature = TransactionSigner.signPayload(rawPayload, privKey);
      expect(signature, isNotEmpty);
      
      final isValid = TransactionSigner.verifySignature(rawPayload, signature, pubKey);
      expect(isValid, isTrue);
      
      final isInvalid = TransactionSigner.verifySignature('{"user_id":"STU-123","amount":50,"nonce":1,"timestamp":1700000000}', signature, pubKey);
      expect(isInvalid, isFalse);
    });
    
    test('Geofence Distance Calculation', () async {
      final geofence = GeofenceManager();
      await geofence.loadStops();
      
      // Main Gate: 7.3775, 3.9470
      final nearest = geofence.getNearestStop(7.37755, 3.94705); // slightly off but within 100m
      expect(nearest, isNotNull);
      expect(nearest!.id, equals('S1'));
      
      // Far away
      final nullStop = geofence.getNearestStop(8.0, 4.0);
      expect(nullStop, isNull);
    });
  });
}
