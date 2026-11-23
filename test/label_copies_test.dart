import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pps_tablet/core/network/endpoints.dart';
import 'package:pps_tablet/core/printing/label_copies.dart';
import 'package:pps_tablet/core/printing/label_printer.dart';
import 'package:pps_tablet/core/printing/network_tspl_printer.dart';

void main() {
  test('Barang Jadi label PDFs default to two copies, other labels to one', () {
    expect(
      LabelCopies.forPdfUrl(Uri.parse('http://10.0.0.1:7500/api/labels/packing/BA.0001/pdf/')),
      2,
    );
    for (final path in [
      'furniture-wip/BB.01',
      'reject/BF.01',
      'washing/B.01',
      'barang-dagang/BD.01',
      'bahan-pendukung/BP.01',
    ]) {
      expect(
        LabelCopies.forPdfUrl(Uri.parse('http://10.0.0.1:7500/api/labels/$path/pdf/')),
        1,
        reason: path,
      );
    }
  });

  test('real endpoint helpers match the copies rule', () {
    dotenv.testLoad(
      fileInput:
          'API_BASE_URL_INTERNAL=http://localhost:7500\nDEFAULT_NETWORK_MODE=internal',
    );
    expect(
      LabelCopies.forPdfUrl(Uri.parse(ApiConstants.packingLabelPdf('BA.0001'))),
      LabelCopies.barangJadi,
    );
    expect(
      LabelCopies.forPdfUrl(Uri.parse(ApiConstants.furnitureWipLabelPdf('BB.0001'))),
      1,
    );
    expect(
      LabelCopies.forPdfUrl(Uri.parse(ApiConstants.rejectLabelPdf('BF.0001'))),
      1,
    );
  });

  test('TSPL print command carries the copy count, clamped to 1..max', () {
    expect(NetworkTsplPrinter.printCommand(1), '\r\nPRINT 1,1\r\n');
    expect(NetworkTsplPrinter.printCommand(2), '\r\nPRINT 1,2\r\n');
    expect(NetworkTsplPrinter.printCommand(0), '\r\nPRINT 1,1\r\n');
    expect(
      NetworkTsplPrinter.printCommand(99),
      '\r\nPRINT 1,${LabelPrinter.maxCopies}\r\n',
    );
  });
}
