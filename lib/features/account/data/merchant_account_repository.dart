import '../../../core/network/api_client.dart';
import '../../auth/data/merchant_session_store.dart';

class MerchantAccountRepository {
  final ApiClient _apiClient = ApiClient();

  Future<Map<String, dynamic>> fetchAccount() async {
    final response = await _apiClient.request('/merchant/account');
    final data = Map<String, dynamic>.from(response.data as Map);
    return Map<String, dynamic>.from(data['user'] as Map);
  }

  Future<Map<String, dynamic>> fetchQualification() async {
    final response = await _apiClient.request('/merchant/qualification');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<Map<String, dynamic>> submitQualification({
    String licenseUrl = '',
    String fileName = '',
    String base64Data = '',
    String legalPersonIdFrontUrl = '',
    String legalPersonIdFrontFileName = '',
    String legalPersonIdFrontData = '',
    String legalPersonIdBackUrl = '',
    String legalPersonIdBackFileName = '',
    String legalPersonIdBackData = '',
    String addressProofUrl = '',
    String addressProofFileName = '',
    String addressProofData = '',
  }) async {
    final pendingImages =
        <({String field, String fileName, String base64Data})>[
          if (base64Data.isNotEmpty)
            (field: 'licenseUrl', fileName: fileName, base64Data: base64Data),
          if (legalPersonIdFrontData.isNotEmpty)
            (
              field: 'legalPersonIdFrontUrl',
              fileName: legalPersonIdFrontFileName,
              base64Data: legalPersonIdFrontData,
            ),
          if (legalPersonIdBackData.isNotEmpty)
            (
              field: 'legalPersonIdBackUrl',
              fileName: legalPersonIdBackFileName,
              base64Data: legalPersonIdBackData,
            ),
          if (addressProofData.isNotEmpty)
            (
              field: 'addressProofUrl',
              fileName: addressProofFileName,
              base64Data: addressProofData,
            ),
        ];
    final directObjects = pendingImages.isEmpty
        ? const <Map<String, dynamic>>[]
        : await _apiClient.uploadBase64Images(
            type: 'qualification',
            images: pendingImages
                .map(
                  (image) =>
                      (fileName: image.fileName, base64Data: image.base64Data),
                )
                .toList(),
          );
    final uploadedByField = <String, String>{
      for (var index = 0; index < pendingImages.length; index += 1)
        pendingImages[index].field:
            directObjects[index]['objectName'] as String,
    };

    final response = await _apiClient.request(
      '/merchant/qualification',
      method: 'PATCH',
      data: {
        'licenseUrl': uploadedByField['licenseUrl'] ?? licenseUrl,
        'legalPersonIdFrontUrl':
            uploadedByField['legalPersonIdFrontUrl'] ?? legalPersonIdFrontUrl,
        'legalPersonIdBackUrl':
            uploadedByField['legalPersonIdBackUrl'] ?? legalPersonIdBackUrl,
        'addressProofUrl':
            uploadedByField['addressProofUrl'] ?? addressProofUrl,
      },
    );
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<MerchantSession> updateAccount({
    required String displayName,
    String currentPassword = '',
    String newPassword = '',
  }) async {
    final response = await _apiClient.request(
      '/merchant/account',
      method: 'PATCH',
      data: {
        'displayName': displayName,
        'currentPassword': currentPassword,
        'newPassword': newPassword,
      },
    );
    final data = Map<String, dynamic>.from(response.data as Map);
    final session = MerchantSession(
      token: data['token'] as String,
      user: Map<String, dynamic>.from(data['user'] as Map),
    );
    ApiClient.authToken = session.token;
    await MerchantSessionStore().save(session);
    return session;
  }
}
