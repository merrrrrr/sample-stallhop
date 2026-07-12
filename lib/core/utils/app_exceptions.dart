/// Base class for domain errors that carry a user-facing message.
class AppException implements Exception {
  final String message;
  const AppException(this.message);

  @override
  String toString() => message;
}

/// Thrown when a wallet does not have enough balance to cover a charge.
class InsufficientBalanceException extends AppException {
  const InsufficientBalanceException([
    super.message = 'Insufficient wallet balance',
  ]);
}

/// Thrown when an expected document is missing during a transaction.
class NotFoundException extends AppException {
  const NotFoundException([super.message = 'Record not found']);
}
