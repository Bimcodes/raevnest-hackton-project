import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:pointycastle/export.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class KeyManager {
  static const _storage = FlutterSecureStorage();
  static const _privateKeyKey = 'ecdsa_private_key';

  static final ECDomainParameters _domainParams = ECDomainParameters('prime256v1');

  /// Generates a new P-256 ECDSA key pair
  static AsymmetricKeyPair<PublicKey, PrivateKey> generateKeyPair() {
    final secureRandom = _getSecureRandom();
    final keyParams = ECKeyGeneratorParameters(_domainParams);
    final params = ParametersWithRandom(keyParams, secureRandom);
    final keyGenerator = ECKeyGenerator()..init(params);
    return keyGenerator.generateKeyPair();
  }

  /// Saves the private key associated integer 'd' securely
  static Future<void> savePrivateKey(ECPrivateKey privateKey) async {
    final dString = privateKey.d!.toString();
    await _storage.write(key: _privateKeyKey, value: dString);
  }

  /// Loads the private key from secure storage
  static Future<ECPrivateKey?> loadPrivateKey() async {
    final dString = await _storage.read(key: _privateKeyKey);
    if (dString == null) return null;
    final d = BigInt.parse(dString);
    return ECPrivateKey(d, _domainParams);
  }

  /// Exports the public key to a simple PEM-like format for the server
  static String exportPublicKeyPem(ECPublicKey publicKey) {
    final qBytes = publicKey.Q!.getEncoded(false);
    
    // Standard X.509 SubjectPublicKeyInfo (SPKI) ASN.1 header for prime256v1
    final spkiHeader = <int>[
      0x30, 0x59, 0x30, 0x13, 0x06, 0x07, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x02, 0x01, 
      0x06, 0x08, 0x2A, 0x86, 0x48, 0xCE, 0x3D, 0x03, 0x01, 0x07, 0x03, 0x42, 0x00
    ];
    
    final fullBytes = Uint8List.fromList([...spkiHeader, ...qBytes]);
    final b64 = base64Encode(fullBytes);
    return '-----BEGIN PUBLIC KEY-----\n$b64\n-----END PUBLIC KEY-----';
  }

  /// Imports a public key from the custom or standard PEM format
  static ECPublicKey importPublicKeyPem(String pem) {
    final lines = pem.split('\n');
    final b64 = lines.sublist(1, lines.length - 1).join('');
    var bytes = base64Decode(b64);
    
    // If it has the 26-byte SPKI header we added, strip it to get the raw 65-byte point
    if (bytes.length > 65 && bytes[bytes.length - 65] == 0x04) {
      bytes = bytes.sublist(bytes.length - 65);
    }
    
    final q = _domainParams.curve.decodePoint(bytes);
    return ECPublicKey(q, _domainParams);
  }

  static SecureRandom _getSecureRandom() {
    final secureRandom = FortunaRandom();
    final random = Random.secure();
    List<int> seeds = [];
    for (int i = 0; i < 32; i++) {
      seeds.add(random.nextInt(255));
    }
    secureRandom.seed(KeyParameter(Uint8List.fromList(seeds)));
    return secureRandom;
  }
}
