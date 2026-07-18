import 'package:intl/intl.dart';

class AppFormatters {
  AppFormatters._();

  static final DateFormat _apiDateFormat = DateFormat('yyyy-MM-dd');
  static final DateFormat _displayDateFormat = DateFormat('MMM d, yyyy');
  static final NumberFormat _currencyFormat = NumberFormat.currency(
    locale: 'en_US',
    symbol: '\$',
    decimalDigits: 0,
  );

  static String apiDate(DateTime value) {
    return _apiDateFormat.format(value);
  }

  static String displayDate(DateTime value) {
    return _displayDateFormat.format(value);
  }

  static String money(num value) {
    return _currencyFormat.format(value);
  }
}
