import 'component_catalog.dart';
import 'project.dart';
import 'terminal.dart';

class ConnectionIssue {
  const ConnectionIssue(this.messageAr, this.code);

  final String messageAr;
  final String code;
}

abstract final class ConnectionValidator {
  static ConnectionIssue? validate(
    ElectricalProject project,
    TerminalRef from,
    TerminalRef to, {
    String? ignoreWireId,
  }) {
    if (from == to || from.componentId == to.componentId) {
      return const ConnectionIssue(
        'اختر طرفين على جهازين مختلفين.',
        'same_device',
      );
    }
    final fromComponent = project.componentById(from.componentId);
    final toComponent = project.componentById(to.componentId);
    if (fromComponent == null || toComponent == null) {
      return const ConnectionIssue('أحد الجهازين غير موجود.', 'missing_device');
    }
    try {
      final fromTerminal = ComponentCatalog.specOf(fromComponent.kind)
          .terminal(from.terminalId);
      final toTerminal =
          ComponentCatalog.specOf(toComponent.kind).terminal(to.terminalId);
      if ((fromTerminal.kind == TerminalKind.earth) !=
          (toTerminal.kind == TerminalKind.earth)) {
        return const ConnectionIssue(
          'طرف PE لا يُوصل إلا بطرف حماية أرضي PE.',
          'earth_mismatch',
        );
      }
    } on ArgumentError {
      return const ConnectionIssue('طرف التوصيل غير معروف.', 'bad_terminal');
    }
    for (final wire in project.wires) {
      if (wire.id == ignoreWireId) continue;
      if ((wire.from == from && wire.to == to) ||
          (wire.from == to && wire.to == from)) {
        return const ConnectionIssue(
          'هذا التوصيل موجود مسبقاً.',
          'duplicate',
        );
      }
    }
    return null;
  }
}
