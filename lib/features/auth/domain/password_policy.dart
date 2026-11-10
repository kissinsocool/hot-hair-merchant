const newPasswordRule = '密码至少 10 位，且包含英文字母和数字';

bool isValidNewPassword(String password) =>
    password.length >= 10 &&
    password.length <= 128 &&
    RegExp(r'[A-Za-z]').hasMatch(password) &&
    RegExp(r'[0-9]').hasMatch(password);
