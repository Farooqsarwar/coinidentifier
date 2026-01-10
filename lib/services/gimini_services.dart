import 'dart:io';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';

class GeminiService {
  static const String _apiKey = 'AIzaSyCqaPcPjyLzYZBVTnp5_JlFnOKbJ9Juh6U';

  static final GenerativeModel _model = GenerativeModel(
    model: 'gemini-2.0-flash-exp',
    apiKey: _apiKey,
  );

  /// Analyze item from File
  static Future<CoinAnalysisResult> analyzeFromFile(
      File imageFile, {
        String type = 'coin',
      }) async {
    try {
      final Uint8List imageBytes = await imageFile.readAsBytes();
      return await analyze(imageBytes, type: type);
    } catch (e) {
      return CoinAnalysisResult(
        success: false,
        analysis: null,
        error: 'Failed to read image: ${e.toString()}',
      );
    }
  }

  /// Analyze item from bytes
  static Future<CoinAnalysisResult> analyze(
      Uint8List imageBytes, {
        String type = 'coin',
      }) async {
    try {
      final prompt = _getPromptForType(type);

      final content = [
        Content.multi([
          TextPart(prompt),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      final response = await _model.generateContent(content);
      final text = response.text ?? 'Unable to analyze the $type.';

      return CoinAnalysisResult(
        success: true,
        analysis: text,
        error: null,
      );
    } catch (e) {
      return CoinAnalysisResult(
        success: false,
        analysis: null,
        error: e.toString(),
      );
    }
  }

  static String _getPromptForType(String type) {
    switch (type.toLowerCase()) {
      case 'coin':
        return '''
Analyze this coin image and provide detailed information in the following format:

**Name**: (Full name of the coin)
**Country**: (Country of origin)
**Year**: (Year minted, if visible)
Please be specific and detailed in your analysis.
''';

      case 'banknote':
        return '''
Analyze this banknote image and provide detailed information in the following format:

**Name**: (Full name/type of banknote)
**Country**: (Issuing country)
**Year/Series**: (Year of issue or series)
Please be specific and detailed in your analysis.
''';

      case 'medal':
        return '''
Analyze this medal image and provide detailed information in the following format:

**Name**: (Name of the medal)
**Type**: (Military/Civilian/Sports/Commemorative/etc.)
**Country**: (Issuing country or organization)
**Year**: (Year of issue or award)

Please be specific and detailed in your analysis.
''';

      case 'token':
        return '''
Analyze this token or artifact image and provide detailed information in the following format:

**Name**: (Name or type of token/artifact)
**Category**: (Gaming token, transit token, commemorative token, artifact, etc.)
**Origin**: (Country or region of origin)
**Era/Period**: (Time period or year)
Please be specific and detailed in your analysis.
''';

      default:
        return _getPromptForType('coin');
    }
  }
}

class CoinAnalysisResult {
  final bool success;
  final String? analysis;
  final String? error;

  CoinAnalysisResult({
    required this.success,
    this.analysis,
    this.error,
  });
}