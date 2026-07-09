import '../../../core/auth/auth_session.dart';
import '../../../core/network/api_exception.dart';
import '../domain/courier_account.dart';

class CourierProfileApi {
  const CourierProfileApi();

  Future<CourierAccount> loadAccount() async {
    final data = await AuthSession.instance.getJson('auth/me/');
    final user = parseUserResponse(data);
    AuthSession.instance.currentUser = user.raw;
    return user;
  }

  static CourierAccount parseUserResponse(dynamic data) {
    if (data is! Map<String, dynamic>) {
      throw const ApiException('تعذر قراءة بيانات حساب المندوب.');
    }

    final account = CourierAccount.fromJson(data);
    if (account.role != 'representative') {
      throw const ApiException('هذا الحساب ليس حساب مندوب.');
    }
    return account;
  }
}
