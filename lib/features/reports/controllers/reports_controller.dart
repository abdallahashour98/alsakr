import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../repositories/reports_local_repository.dart';
import 'package:al_sakr/core/database/database_provider.dart';

part 'reports_controller.g.dart';

@riverpod
class ReportsData extends _$ReportsData {
  @override
  FutureOr<Map<String, double>> build({
    String? startDate,
    String? endDate,
  }) async {
    final db = await ref.watch(localDatabaseProvider.future);
    final repo = ReportsLocalRepository(db);
    return await repo.getGeneralReportData(
      startDate: startDate,
      endDate: endDate,
    );
  }
}
