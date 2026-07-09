import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nfc_manager/nfc_manager.dart';

class NfcService {
  static bool? _isAvailable;

  /// Check if NFC is available on this device
  static Future<bool> isNfcAvailable() async {
    if (kIsWeb) return false;
    try {
      _isAvailable ??= await NfcManager.instance.isAvailable();
      return _isAvailable!;
    } catch (e) {
      debugPrint('NFC availability check failed: $e');
      return false;
    }
  }

  /// Write vCard data to an NFC tag
  /// Returns null on success, error message string on failure
  static Future<String?> writeVCardToTag(Map<String, dynamic> card, {
    void Function(String message)? onStatusUpdate,
  }) async {
    if (!await isNfcAvailable()) return 'NFC is not available on this device';

    final vcard = buildVCard(card);

    final completer = Completer<String?>();

    try {
      onStatusUpdate?.call('Hold your phone to an NFC tag...');
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await NfcManager.instance.stopSession(errorMessage: 'Tag is not NDEF compatible');
              completer.complete('Tag is not NDEF compatible');
              return;
            }
            if (!ndef.isWritable) {
              await NfcManager.instance.stopSession(errorMessage: 'Tag is read-only');
              completer.complete('This NFC tag is read-only');
              return;
            }

            final message = NdefMessage([
              NdefRecord.createMime(
                'text/vcard',
                Uint8List.fromList(vcard.codeUnits),
              ),
            ]);

            await ndef.write(message);
            await NfcManager.instance.stopSession();
            onStatusUpdate?.call('✅ Written to NFC tag successfully!');
            completer.complete(null); // null = success
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessage: e.toString());
            completer.complete('Write failed: $e');
          }
        },
      );
    } catch (e) {
      completer.complete('NFC session error: $e');
    }

    return completer.future;
  }

  /// Read vCard from NFC tag
  static Future<String?> readFromTag({
    void Function(String message)? onStatusUpdate,
    void Function(String vcardData)? onVCardRead,
  }) async {
    if (!await isNfcAvailable()) return 'NFC is not available on this device';

    final completer = Completer<String?>();

    try {
      onStatusUpdate?.call('Hold your phone to an NFC tag...');
      await NfcManager.instance.startSession(
        onDiscovered: (NfcTag tag) async {
          try {
            final ndef = Ndef.from(tag);
            if (ndef == null) {
              await NfcManager.instance.stopSession();
              completer.complete('Tag is not NDEF readable');
              return;
            }

            final message = await ndef.read();
            for (final record in message.records) {
              final payload = String.fromCharCodes(record.payload);
              if (payload.contains('BEGIN:VCARD') || payload.contains('text/vcard')) {
                onVCardRead?.call(payload);
              }
            }

            await NfcManager.instance.stopSession();
            completer.complete(null);
          } catch (e) {
            await NfcManager.instance.stopSession(errorMessage: e.toString());
            completer.complete('Read failed: $e');
          }
        },
      );
    } catch (e) {
      completer.complete('NFC session error: $e');
    }

    return completer.future;
  }

  /// Stop any active NFC session
  static Future<void> stopSession() async {
    try {
      await NfcManager.instance.stopSession();
    } catch (_) {}
  }

  /// Build a vCard 3.0 string from card data
  static String buildVCard(Map<String, dynamic> card) {
    final name = _val(card, 'point_person');
    final org = _val(card, 'organization_name');
    final title = _val(card, 'department');
    final phone = _val(card, 'contact_number');
    final email = _val(card, 'contact_email');
    final address = _val(card, 'address').isNotEmpty
        ? _val(card, 'address')
        : _val(card, 'location');
    final url = _val(card, 'url');
    final note = _val(card, 'notes').isNotEmpty
        ? _val(card, 'notes')
        : _val(card, 'remark');

    // Split name into first/last
    final nameParts = name.split(' ');
    final firstName = nameParts.isNotEmpty ? nameParts.first : '';
    final lastName = nameParts.length > 1 ? nameParts.skip(1).join(' ') : '';

    final buffer = StringBuffer();
    buffer.writeln('BEGIN:VCARD');
    buffer.writeln('VERSION:3.0');
    buffer.writeln('FN:$name');
    buffer.writeln('N:$lastName;$firstName;;;');
    if (org.isNotEmpty) buffer.writeln('ORG:$org');
    if (title.isNotEmpty) buffer.writeln('TITLE:$title');
    if (phone.isNotEmpty) buffer.writeln('TEL;TYPE=WORK,VOICE:$phone');
    if (email.isNotEmpty) buffer.writeln('EMAIL;TYPE=WORK:$email');
    if (address.isNotEmpty) buffer.writeln('ADR;TYPE=WORK:;;$address;;;;');
    if (url.isNotEmpty) buffer.writeln('URL:$url');
    if (note.isNotEmpty) buffer.writeln('NOTE:$note');
    buffer.writeln('PRODID:-//kardo//EN');
    buffer.writeln('END:VCARD');

    return buffer.toString();
  }

  static String _val(Map<String, dynamic> card, String key) {
    final value = card[key];
    if (value == null) return '';
    final str = value.toString().trim();
    if (str.toLowerCase() == 'not found') return '';
    return str;
  }
}
