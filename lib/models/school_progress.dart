// lib/models/school_progress.dart

class SchoolProgress {
  final String schoolName;
  final double collectedAmountKg;
  final double goalAmountKg;
  final int daysRemaining;

  SchoolProgress({
    required this.schoolName,
    required this.collectedAmountKg,
    required this.goalAmountKg,
    required this.daysRemaining,
  });

  // Calcula o que falta para atingir a meta
  double get remainingAmountKg => goalAmountKg - collectedAmountKg;
}