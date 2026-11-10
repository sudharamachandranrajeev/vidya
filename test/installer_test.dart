import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Windows installer ids (Inno Setup AppId) of the Brahma apps. Two apps
/// sharing one makes Windows treat them as one app: same folder, shortcuts
/// and uninstaller. A new app needs a new GUID, never a copied one.
const _ids = {
  'Artha': 'E08F3DAF-D71C-41CD-8B56-B177B7B4C216',
  'Bahya Nireekshana': '3B4C320B-9334-480A-84EB-F11BB6917594',
  'Bhojana': '2AEE7A28-EC87-4960-8ADE-7B8C22FB9C32',
  'Brahma': '6DAAFB0C-B2A5-440A-92B9-370050674767',
  'Chithram': '0A13D487-F502-40BC-84E4-9F69588F5B02',
  'Graha Anveshana': 'F96051B1-6F25-4804-B685-5FC768E030C1',
  'Paattu': '6E0B9C1E-3D4A-4F57-9B1E-7A5C2D8F0A61',
  'Samridhi': '5B1E7A52-3C0D-4F7B-9A44-2D6E8C1F90A3',
  'Udyoga': '55825A17-B296-4ED6-A66E-84FB1F5A100C',
  'Vahana Anveshana': '1BFC6395-2669-4958-84C2-909F48B0B533',
  'Vani': '6AB2670E-49A5-4703-851F-808B3C52B347',
  'Vastra': '801368EB-2DD0-456A-A5B3-BD25FF0D8141',
  'Vidya': '84D33EF5-7087-46D6-9977-5856CA367B3A',
  'Vinyasa': '6AFDD642-E453-4A64-A34D-835F44165BA5',
};

void main() {
  test('the Windows installer has its own id', () {
    final iss = File('windows/installer/vidya.iss').readAsStringSync();
    final id = RegExp(r'^AppId=\{\{([0-9A-F-]{36})\}', multiLine: true).firstMatch(iss)?.group(1);
    expect(id, _ids['Vidya']);
    expect(_ids.entries.where((e) => e.value == id).map((e) => e.key), ['Vidya']);
  });
}
