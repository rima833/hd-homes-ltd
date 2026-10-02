import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hdhomesproject/core/network/supabase_provider.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:hdhomesproject/features/cpms/presentation/providers/cpms_controller.dart';
import 'package:hdhomesproject/features/cpms/presentation/widgets/cpms_edit_dialogs.dart';
import 'package:intl/intl.dart';

/// Shared add/edit/delete dialogs for Construction Command Center.
class CpmsCrudActions {
  CpmsCrudActions(this.ref, this.context);

  final WidgetRef ref;
  final BuildContext context;

  CpmsServiceAccess get _svc => CpmsServiceAccess(ref);
  CpmsController get _ui => ref.read(cpmsControllerProvider.notifier);

  bool get _isRemote => ref.read(supabaseConfiguredProvider);

  bool _guardRemote() {
    if (!_isRemote) {
      _ui.setMessage('Connect Supabase to manage live construction data.');
      return false;
    }
    return true;
  }

  Future<void> _run(Future<void> Function() action, String okMessage) async {
    try {
      await action();
      _ui.setMessage(okMessage);
      await _ui.refresh();
    } catch (e) {
      _ui.setMessage('Save failed: $e');
    }
  }

  String? _defaultProjectId(List<CpmsProject> projects, String? preferred) {
    if (preferred != null && projects.any((p) => p.id == preferred)) {
      return preferred;
    }
    return projects.isEmpty ? null : projects.first.id;
  }

  Future<DateTime?> _pickDate(DateTime? initial) {
    final now = DateTime.now();
    return showDatePicker(
      context: context,
      initialDate: initial ?? now,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 8),
    );
  }

  Future<void> editProject({
    CpmsProject? project,
    required bool fromRemote,
  }) async {
    if (!fromRemote) {
      _ui.setMessage('Connect Supabase to manage live projects.');
      return;
    }
    final name = TextEditingController(text: project?.name ?? '');
    final code = TextEditingController(text: project?.projectCode ?? '');
    final location = TextEditingController(text: project?.locationLabel ?? '');
    final manager = TextEditingController(text: project?.managerLabel ?? '');
    final progress =
        TextEditingController(text: project?.progressPct.toStringAsFixed(0) ?? '0');
    final budget =
        TextEditingController(text: project?.budgetTotal.toStringAsFixed(0) ?? '0');
    final spent =
        TextEditingController(text: project?.budgetSpent.toStringAsFixed(0) ?? '0');
    final delay =
        TextEditingController(text: '${project?.delayDays ?? 0}');
    final notes = TextEditingController(text: project?.description ?? '');
    var status = project?.status.slug ?? 'planning';
    var risk = project?.riskLevel.slug ?? 'medium';
    var start = project?.startDate;
    var end = project?.targetEndDate;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: project == null ? 'New project' : 'Edit project',
      fields: [
        cpmsField(controller: name, label: 'Name'),
        cpmsField(controller: code, label: 'Project code'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            for (final s in ConstructionProjectStatus.values) s.slug,
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsDropdown<String>(
          label: 'Risk',
          value: risk,
          items: statusItems(['low', 'medium', 'high', 'critical']),
          onChanged: (v) => risk = v ?? risk,
        ),
        cpmsField(controller: location, label: 'Location'),
        cpmsField(controller: manager, label: 'Project manager'),
        cpmsField(
          controller: progress,
          label: 'Progress %',
          keyboardType: TextInputType.number,
        ),
        cpmsField(
          controller: budget,
          label: 'Budget total (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(
          controller: spent,
          label: 'Budget spent (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(
          controller: delay,
          label: 'Delay days',
          keyboardType: TextInputType.number,
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Start: ${start == null ? '—' : DateFormat.yMMMd().format(start!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final d = await _pickDate(start);
                    if (d != null) setLocal(() => start = d);
                  },
                  child: const Text('Pick'),
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  'Target end: ${end == null ? '—' : DateFormat.yMMMd().format(end!)}',
                  style: const TextStyle(color: Colors.white),
                ),
                trailing: TextButton(
                  onPressed: () async {
                    final d = await _pickDate(end);
                    if (d != null) setLocal(() => end = d);
                  },
                  child: const Text('Pick'),
                ),
              ),
            ],
          ),
        ),
        cpmsField(controller: notes, label: 'Notes', maxLines: 3),
      ],
    );

    if (ok != true) {
      name.dispose();
      code.dispose();
      location.dispose();
      manager.dispose();
      progress.dispose();
      budget.dispose();
      spent.dispose();
      delay.dispose();
      notes.dispose();
      return;
    }

    await _run(() async {
      if (project == null) {
        await _svc.createProjectFromWizard(
          CpmsWizardDraft(
            name: name.text,
            projectCode: code.text,
            locationLabel: location.text,
            managerLabel: manager.text,
            budgetTotal: double.tryParse(budget.text) ?? 0,
            startDate: start,
            targetEndDate: end,
            notes: notes.text,
          ),
        );
      } else {
        await _svc.updateProject(
          id: project.id,
          name: name.text,
          projectCode: code.text,
          status: status,
          locationLabel: location.text,
          managerLabel: manager.text,
          progressPct: double.tryParse(progress.text),
          budgetTotal: double.tryParse(budget.text),
          budgetSpent: double.tryParse(spent.text),
          delayDays: int.tryParse(delay.text),
          riskLevel: risk,
          notes: notes.text,
          startDate: start,
          targetEndDate: end,
        );
      }
    }, project == null ? 'Project created.' : 'Project updated.');

    name.dispose();
    code.dispose();
    location.dispose();
    manager.dispose();
    progress.dispose();
    budget.dispose();
    spent.dispose();
    delay.dispose();
    notes.dispose();
  }

  Future<void> deleteProject(CpmsProject project) async {
    if (!await confirmCpmsDelete(context, project.name)) return;
    await _run(
      () => _svc.deleteProject(project.id),
      'Deleted ${project.name}.',
    );
  }

  Future<void> editMilestone({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsMilestone? milestone,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final name = TextEditingController(text: milestone?.name ?? '');
    final progress = TextEditingController(
      text: milestone?.progressPct.toStringAsFixed(0) ?? '0',
    );
    final notes = TextEditingController(text: milestone?.notes ?? '');
    var projectId =
        milestone?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = milestone?.status.slug ?? 'planned';
    var due = milestone?.dueDate;
    var critical = milestone?.isCritical ?? false;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: milestone == null ? 'Add milestone' : 'Edit milestone',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: name, label: 'Name'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            for (final s in MilestoneStatus.values) s.slug,
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(
          controller: progress,
          label: 'Progress %',
          keyboardType: TextInputType.number,
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Critical path', style: TextStyle(color: Colors.white)),
            value: critical,
            onChanged: (v) => setLocal(() => critical = v),
          ),
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Due: ${due == null ? '—' : DateFormat.yMMMd().format(due!)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: TextButton(
              onPressed: () async {
                final d = await _pickDate(due);
                if (d != null) setLocal(() => due = d);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      name.dispose();
      progress.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertMilestone(
        id: milestone?.id,
        projectId: projectId,
        name: name.text,
        status: status,
        dueDate: due,
        progressPct: double.tryParse(progress.text) ?? 0,
        isCritical: critical,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      milestone == null ? 'Milestone added.' : 'Milestone updated.',
    );
    name.dispose();
    progress.dispose();
    notes.dispose();
  }

  Future<void> deleteMilestone(CpmsMilestone m) async {
    if (!await confirmCpmsDelete(context, m.name)) return;
    await _run(() => _svc.deleteMilestone(m.id), 'Milestone deleted.');
  }

  Future<void> editTask({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsTask? task,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: task?.title ?? '');
    final assignee = TextEditingController(text: task?.assigneeLabel ?? '');
    final progress =
        TextEditingController(text: task?.progressPct.toStringAsFixed(0) ?? '0');
    final notes = TextEditingController(text: task?.notes ?? '');
    var projectId =
        task?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = task?.status.slug ?? 'todo';
    var priority = task?.priority ?? 'medium';
    var due = task?.dueDate;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: task == null ? 'Add task' : 'Edit task',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([for (final s in TaskStatus.values) s.slug]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsDropdown<String>(
          label: 'Priority',
          value: priority,
          items: statusItems(['low', 'medium', 'high', 'urgent']),
          onChanged: (v) => priority = v ?? priority,
        ),
        cpmsField(controller: assignee, label: 'Assignee'),
        cpmsField(
          controller: progress,
          label: 'Progress %',
          keyboardType: TextInputType.number,
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Due: ${due == null ? '—' : DateFormat.yMMMd().format(due!)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: TextButton(
              onPressed: () async {
                final d = await _pickDate(due);
                if (d != null) setLocal(() => due = d);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      title.dispose();
      assignee.dispose();
      progress.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertTask(
        id: task?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        priority: priority,
        assigneeLabel:
            assignee.text.trim().isEmpty ? null : assignee.text.trim(),
        dueDate: due,
        progressPct: double.tryParse(progress.text) ?? 0,
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      task == null ? 'Task added.' : 'Task updated.',
    );
    title.dispose();
    assignee.dispose();
    progress.dispose();
    notes.dispose();
  }

  Future<void> deleteTask(CpmsTask t) async {
    if (!await confirmCpmsDelete(context, t.title)) return;
    await _run(() => _svc.deleteTask(t.id), 'Task deleted.');
  }

  Future<void> setTaskStatus(CpmsTask task, String status) async {
    await _run(
      () => _svc.setTaskStatus(
        taskId: task.id,
        projectId: task.projectId,
        status: status,
        title: task.title,
      ),
      'Task updated.',
    );
  }

  Future<void> editDiary({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsSiteDiary? entry,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final summary = TextEditingController(text: entry?.summary ?? '');
    final blockers = TextEditingController(text: entry?.blockers ?? '');
    final weather = TextEditingController(text: entry?.weather ?? '');
    final author = TextEditingController(text: entry?.authorLabel ?? '');
    final workforce = TextEditingController(
      text: entry?.workforceCount?.toString() ?? '',
    );
    var projectId =
        entry?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var date = entry?.entryDate ?? DateTime.now();

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: entry == null ? 'Add site diary' : 'Edit site diary',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Date: ${DateFormat.yMMMd().format(date)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: TextButton(
              onPressed: () async {
                final d = await _pickDate(date);
                if (d != null) setLocal(() => date = d);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
        cpmsField(controller: summary, label: 'Summary', maxLines: 3),
        cpmsField(controller: blockers, label: 'Blockers', maxLines: 2),
        cpmsField(controller: weather, label: 'Weather'),
        cpmsField(controller: author, label: 'Author'),
        cpmsField(
          controller: workforce,
          label: 'Workforce count',
          keyboardType: TextInputType.number,
        ),
      ],
    );

    if (ok != true) {
      summary.dispose();
      blockers.dispose();
      weather.dispose();
      author.dispose();
      workforce.dispose();
      return;
    }

    await _run(
      () => _svc.upsertSiteDiary(
        id: entry?.id,
        projectId: projectId,
        summary: summary.text,
        blockers: blockers.text.trim().isEmpty ? null : blockers.text.trim(),
        entryDate: date,
        weather: weather.text.trim().isEmpty ? null : weather.text.trim(),
        authorLabel: author.text.trim().isEmpty ? null : author.text.trim(),
        workforceCount: int.tryParse(workforce.text),
      ),
      entry == null ? 'Diary entry saved.' : 'Diary entry updated.',
    );
    summary.dispose();
    blockers.dispose();
    weather.dispose();
    author.dispose();
    workforce.dispose();
  }

  Future<void> deleteDiary(CpmsSiteDiary e) async {
    if (!await confirmCpmsDelete(context, 'this diary entry')) return;
    await _run(() => _svc.deleteSiteDiary(e.id), 'Diary entry deleted.');
  }

  Future<void> editDefect({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsDefect? defect,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: defect?.title ?? '');
    final location = TextEditingController(text: defect?.locationLabel ?? '');
    final notes = TextEditingController(text: defect?.notes ?? '');
    var projectId =
        defect?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = defect?.status ?? 'open';
    var severity = defect?.severity.slug ?? 'medium';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: defect == null ? 'Add defect' : 'Edit defect',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems(['open', 'in_progress', 'resolved', 'closed']),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsDropdown<String>(
          label: 'Severity',
          value: severity,
          items: statusItems(['low', 'medium', 'high', 'critical']),
          onChanged: (v) => severity = v ?? severity,
        ),
        cpmsField(controller: location, label: 'Location'),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      title.dispose();
      location.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertDefect(
        id: defect?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        severity: severity,
        locationLabel:
            location.text.trim().isEmpty ? null : location.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      defect == null ? 'Defect logged.' : 'Defect updated.',
    );
    title.dispose();
    location.dispose();
    notes.dispose();
  }

  Future<void> deleteDefect(CpmsDefect d) async {
    if (!await confirmCpmsDelete(context, d.title)) return;
    await _run(() => _svc.deleteDefect(d.id), 'Defect deleted.');
  }

  Future<void> editChangeOrder({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsChangeOrder? order,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: order?.title ?? '');
    final cost = TextEditingController(
      text: order?.costImpact.toStringAsFixed(0) ?? '0',
    );
    final rationale = TextEditingController(text: order?.rationale ?? '');
    var projectId =
        order?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = order?.status.slug ?? 'draft';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: order == null ? 'Add change order' : 'Edit change order',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            for (final s in ChangeOrderStatus.values) s.slug,
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(
          controller: cost,
          label: 'Cost impact (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(controller: rationale, label: 'Rationale', maxLines: 3),
      ],
    );

    if (ok != true) {
      title.dispose();
      cost.dispose();
      rationale.dispose();
      return;
    }

    await _run(
      () => _svc.upsertChangeOrder(
        id: order?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        costImpact: double.tryParse(cost.text) ?? 0,
        rationale:
            rationale.text.trim().isEmpty ? null : rationale.text.trim(),
      ),
      order == null ? 'Change order created.' : 'Change order updated.',
    );
    title.dispose();
    cost.dispose();
    rationale.dispose();
  }

  Future<void> deleteChangeOrder(CpmsChangeOrder c) async {
    if (!_guardRemote()) return;
    if (!await confirmCpmsDelete(context, c.changeCode)) return;
    await _run(() => _svc.deleteChangeOrder(c.id), 'Change order deleted.');
  }

  Future<void> approveChangeOrder(CpmsChangeOrder order) async {
    if (!_guardRemote()) return;
    await _run(
      () => _svc.approveChangeOrder(order.id, projectId: order.projectId),
      'Change order ${order.changeCode} approved.',
    );
  }

  Future<void> editSafety({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsSafetyIncident? incident,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: incident?.title ?? '');
    final location = TextEditingController(text: incident?.locationLabel ?? '');
    final description = TextEditingController(text: incident?.description ?? '');
    var projectId =
        incident?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = incident?.status ?? 'open';
    var severity = incident?.severity.slug ?? 'medium';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: incident == null ? 'Log safety incident' : 'Edit safety incident',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems(['open', 'investigating', 'closed']),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsDropdown<String>(
          label: 'Severity',
          value: severity,
          items: statusItems(['low', 'medium', 'high', 'critical']),
          onChanged: (v) => severity = v ?? severity,
        ),
        cpmsField(controller: location, label: 'Location'),
        cpmsField(controller: description, label: 'Description', maxLines: 3),
      ],
    );

    if (ok != true) {
      title.dispose();
      location.dispose();
      description.dispose();
      return;
    }

    await _run(
      () => _svc.upsertSafetyIncident(
        id: incident?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        severity: severity,
        locationLabel:
            location.text.trim().isEmpty ? null : location.text.trim(),
        description:
            description.text.trim().isEmpty ? null : description.text.trim(),
      ),
      incident == null ? 'Safety incident logged.' : 'Safety incident updated.',
    );
    title.dispose();
    location.dispose();
    description.dispose();
  }

  Future<void> deleteSafety(CpmsSafetyIncident s) async {
    if (!await confirmCpmsDelete(context, s.title)) return;
    await _run(() => _svc.deleteSafetyIncident(s.id), 'Safety incident deleted.');
  }

  Future<void> editContractor({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsContractor? contractor,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final company = TextEditingController(text: contractor?.companyName ?? '');
    final contact = TextEditingController(text: contractor?.contactName ?? '');
    final specialty = TextEditingController(text: contractor?.specialty ?? '');
    final value = TextEditingController(
      text: contractor?.contractValue.toStringAsFixed(0) ?? '0',
    );
    var projectId = contractor?.projectId ??
        _defaultProjectId(projects, preferredProjectId)!;
    var status = contractor?.status ?? 'active';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: contractor == null ? 'Add contractor' : 'Edit contractor',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: company, label: 'Company name'),
        cpmsField(controller: contact, label: 'Contact name'),
        cpmsField(controller: specialty, label: 'Specialty'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems(['active', 'inactive', 'pending']),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(
          controller: value,
          label: 'Contract value (NGN)',
          keyboardType: TextInputType.number,
        ),
      ],
    );

    if (ok != true) {
      company.dispose();
      contact.dispose();
      specialty.dispose();
      value.dispose();
      return;
    }

    await _run(
      () => _svc.upsertContractor(
        id: contractor?.id,
        projectId: projectId,
        companyName: company.text,
        status: status,
        specialty:
            specialty.text.trim().isEmpty ? null : specialty.text.trim(),
        contactName: contact.text.trim().isEmpty ? null : contact.text.trim(),
        contractValue: double.tryParse(value.text),
      ),
      contractor == null ? 'Contractor added.' : 'Contractor updated.',
    );
    company.dispose();
    contact.dispose();
    specialty.dispose();
    value.dispose();
  }

  Future<void> deleteContractor(CpmsContractor c) async {
    if (!await confirmCpmsDelete(context, c.companyName)) return;
    await _run(() => _svc.deleteContractor(c.id), 'Contractor deleted.');
  }

  Future<void> editBudgetLine({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsBudgetLine? line,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final category = TextEditingController(text: line?.category ?? '');
    final description = TextEditingController(text: line?.description ?? '');
    final budgeted = TextEditingController(
      text: line?.budgetedAmount.toStringAsFixed(0) ?? '0',
    );
    final committed = TextEditingController(
      text: line?.committedAmount.toStringAsFixed(0) ?? '0',
    );
    final spent = TextEditingController(
      text: line?.spentAmount.toStringAsFixed(0) ?? '0',
    );
    var projectId =
        line?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: line == null ? 'Add budget line' : 'Edit budget line',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: category, label: 'Category'),
        cpmsField(controller: description, label: 'Description', maxLines: 2),
        cpmsField(
          controller: budgeted,
          label: 'Budgeted (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(
          controller: committed,
          label: 'Committed (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(
          controller: spent,
          label: 'Spent (NGN)',
          keyboardType: TextInputType.number,
        ),
      ],
    );

    if (ok != true) {
      category.dispose();
      description.dispose();
      budgeted.dispose();
      committed.dispose();
      spent.dispose();
      return;
    }

    await _run(
      () => _svc.upsertBudgetLine(
        id: line?.id,
        projectId: projectId,
        category: category.text,
        description:
            description.text.trim().isEmpty ? null : description.text.trim(),
        budgetedAmount: double.tryParse(budgeted.text) ?? 0,
        committedAmount: double.tryParse(committed.text) ?? 0,
        spentAmount: double.tryParse(spent.text) ?? 0,
      ),
      line == null ? 'Budget line added.' : 'Budget line updated.',
    );
    category.dispose();
    description.dispose();
    budgeted.dispose();
    committed.dispose();
    spent.dispose();
  }

  Future<void> deleteBudgetLine(CpmsBudgetLine line) async {
    if (!await confirmCpmsDelete(context, line.category)) return;
    await _run(() => _svc.deleteBudgetLine(line.id), 'Budget line deleted.');
  }

  Future<void> editProcurement({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsProcurementRequest? request,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: request?.title ?? '');
    final cost = TextEditingController(
      text: request?.estimatedCost.toStringAsFixed(0) ?? '0',
    );
    final requestedBy =
        TextEditingController(text: request?.requestedByLabel ?? '');
    final notes = TextEditingController();
    var projectId =
        request?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = request?.status ?? 'draft';
    var neededBy = request?.neededBy;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: request == null ? 'Add procurement request' : 'Edit request',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            'draft',
            'submitted',
            'approved',
            'ordered',
            'received',
            'cancelled',
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(
          controller: cost,
          label: 'Estimated cost (NGN)',
          keyboardType: TextInputType.number,
        ),
        cpmsField(controller: requestedBy, label: 'Requested by'),
        StatefulBuilder(
          builder: (ctx, setLocal) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              neededBy == null
                  ? 'Needed by: —'
                  : 'Needed by: ${DateFormat.yMMMd().format(neededBy!)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: TextButton(
              onPressed: () async {
                final d = await _pickDate(neededBy);
                if (d != null) setLocal(() => neededBy = d);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      title.dispose();
      cost.dispose();
      requestedBy.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertProcurementRequest(
        id: request?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        estimatedCost: double.tryParse(cost.text) ?? 0,
        neededBy: neededBy,
        requestedByLabel:
            requestedBy.text.trim().isEmpty ? null : requestedBy.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      request == null ? 'Procurement request created.' : 'Request updated.',
    );
    title.dispose();
    cost.dispose();
    requestedBy.dispose();
    notes.dispose();
  }

  Future<void> deleteProcurement(CpmsProcurementRequest r) async {
    if (!await confirmCpmsDelete(context, r.requestCode)) return;
    await _run(
      () => _svc.deleteProcurementRequest(r.id),
      'Procurement request deleted.',
    );
  }

  Future<void> editQualityCheck({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsQualityCheck? check,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: check?.title ?? '');
    final score = TextEditingController(
      text: check?.scorePct?.toStringAsFixed(0) ?? '',
    );
    final inspector = TextEditingController(text: check?.inspectorLabel ?? '');
    final notes = TextEditingController();
    var projectId =
        check?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var status = check?.status ?? 'pending';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: check == null ? 'Add quality check' : 'Edit quality check',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            'pending',
            'in_progress',
            'passed',
            'failed',
            'waived',
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(
          controller: score,
          label: 'Score %',
          keyboardType: TextInputType.number,
        ),
        cpmsField(controller: inspector, label: 'Inspector'),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      title.dispose();
      score.dispose();
      inspector.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertQualityCheck(
        id: check?.id,
        projectId: projectId,
        title: title.text,
        status: status,
        scorePct: double.tryParse(score.text),
        inspectorLabel:
            inspector.text.trim().isEmpty ? null : inspector.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      check == null ? 'Quality check added.' : 'Quality check updated.',
    );
    title.dispose();
    score.dispose();
    inspector.dispose();
    notes.dispose();
  }

  Future<void> deleteQualityCheck(CpmsQualityCheck q) async {
    if (!await confirmCpmsDelete(context, q.title)) return;
    await _run(() => _svc.deleteQualityCheck(q.id), 'Quality check deleted.');
  }

  Future<void> editInspection({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsInspection? inspection,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: inspection?.title ?? '');
    final inspector =
        TextEditingController(text: inspection?.inspectorLabel ?? '');
    final notes = TextEditingController(text: inspection?.notes ?? '');
    var projectId = inspection?.projectId ??
        _defaultProjectId(projects, preferredProjectId)!;
    var inspectionType = inspection?.inspectionType ?? 'site';
    var status = inspection?.status ?? 'scheduled';
    var scheduledAt = inspection?.scheduledAt;

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: inspection == null ? 'Schedule inspection' : 'Edit inspection',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Type',
          value: inspectionType,
          items: statusItems([
            'site',
            'structural',
            'mep',
            'finishing',
            'handover',
            'other',
          ]),
          onChanged: (v) => inspectionType = v ?? inspectionType,
        ),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems([
            'scheduled',
            'in_progress',
            'completed',
            'cancelled',
          ]),
          onChanged: (v) => status = v ?? status,
        ),
        StatefulBuilder(
          builder: (ctx, setLocal) => ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              scheduledAt == null
                  ? 'Scheduled: —'
                  : 'Scheduled: ${DateFormat.yMMMd().format(scheduledAt!)}',
              style: const TextStyle(color: Colors.white),
            ),
            trailing: TextButton(
              onPressed: () async {
                final d = await _pickDate(scheduledAt);
                if (d != null) setLocal(() => scheduledAt = d);
              },
              child: const Text('Pick'),
            ),
          ),
        ),
        cpmsField(controller: inspector, label: 'Inspector'),
        cpmsField(controller: notes, label: 'Notes', maxLines: 2),
      ],
    );

    if (ok != true) {
      title.dispose();
      inspector.dispose();
      notes.dispose();
      return;
    }

    await _run(
      () => _svc.upsertInspection(
        id: inspection?.id,
        projectId: projectId,
        title: title.text,
        inspectionType: inspectionType,
        status: status,
        scheduledAt: scheduledAt,
        inspectorLabel:
            inspector.text.trim().isEmpty ? null : inspector.text.trim(),
        notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
      ),
      inspection == null ? 'Inspection scheduled.' : 'Inspection updated.',
    );
    title.dispose();
    inspector.dispose();
    notes.dispose();
  }

  Future<void> deleteInspection(CpmsInspection i) async {
    if (!await confirmCpmsDelete(context, i.title)) return;
    await _run(() => _svc.deleteInspection(i.id), 'Inspection deleted.');
  }

  Future<void> editRisk({
    required List<CpmsProject> projects,
    String? preferredProjectId,
    CpmsRisk? risk,
  }) async {
    if (projects.isEmpty) {
      _ui.setMessage('Create a project first.');
      return;
    }
    final title = TextEditingController(text: risk?.title ?? '');
    final mitigation = TextEditingController(text: risk?.mitigation ?? '');
    final owner = TextEditingController(text: risk?.ownerLabel ?? '');
    var projectId =
        risk?.projectId ?? _defaultProjectId(projects, preferredProjectId)!;
    var severity = risk?.severity.slug ?? 'medium';
    var likelihood = risk?.likelihood ?? 'possible';
    var status = risk?.status ?? 'open';

    final ok = await showCpmsFormDialog<bool>(
      context: context,
      title: risk == null ? 'Add risk' : 'Edit risk',
      fields: [
        cpmsDropdown<String>(
          label: 'Project',
          value: projectId,
          items: projectItems(projects),
          onChanged: (v) => projectId = v ?? projectId,
        ),
        cpmsField(controller: title, label: 'Title'),
        cpmsDropdown<String>(
          label: 'Severity',
          value: severity,
          items: statusItems(['low', 'medium', 'high', 'critical']),
          onChanged: (v) => severity = v ?? severity,
        ),
        cpmsDropdown<String>(
          label: 'Likelihood',
          value: likelihood,
          items: statusItems([
            'rare',
            'unlikely',
            'possible',
            'likely',
            'almost_certain',
          ]),
          onChanged: (v) => likelihood = v ?? likelihood,
        ),
        cpmsDropdown<String>(
          label: 'Status',
          value: status,
          items: statusItems(['open', 'mitigating', 'closed', 'accepted']),
          onChanged: (v) => status = v ?? status,
        ),
        cpmsField(controller: owner, label: 'Owner'),
        cpmsField(controller: mitigation, label: 'Mitigation', maxLines: 3),
      ],
    );

    if (ok != true) {
      title.dispose();
      mitigation.dispose();
      owner.dispose();
      return;
    }

    await _run(
      () => _svc.upsertRisk(
        id: risk?.id,
        projectId: projectId,
        title: title.text,
        severity: severity,
        likelihood: likelihood,
        status: status,
        mitigation:
            mitigation.text.trim().isEmpty ? null : mitigation.text.trim(),
        ownerLabel: owner.text.trim().isEmpty ? null : owner.text.trim(),
      ),
      risk == null ? 'Risk added.' : 'Risk updated.',
    );
    title.dispose();
    mitigation.dispose();
    owner.dispose();
  }

  Future<void> deleteRisk(CpmsRisk r) async {
    if (!await confirmCpmsDelete(context, r.title)) return;
    await _run(() => _svc.deleteRisk(r.id), 'Risk deleted.');
  }

  Future<void> dismissAlert(CpmsAlert alert) async {
    await _run(() => _svc.dismissAlert(alert.id), 'Alert dismissed.');
  }

  Future<void> submitWizard(CpmsWizardDraft draft) async {
    if (draft.name.trim().isEmpty) {
      _ui.setMessage('Project name is required.');
      return;
    }
    await _run(() async {
      final id = await _svc.createProjectFromWizard(draft);
      _ui.selectProject(id);
      _ui.wizardReset();
      _ui.setTab(CpmsCommandTab.projects);
    }, 'Project created and saved to Supabase.');
  }
}

/// Thin accessor so CRUD actions stay independent of importing the service type
/// repeatedly in call sites.
class CpmsServiceAccess {
  CpmsServiceAccess(this.ref);
  final WidgetRef ref;

  Future<String> createProjectFromWizard(CpmsWizardDraft draft) =>
      ref.read(cpmsServiceProvider).createProjectFromWizard(draft);

  Future<void> updateProject({
    required String id,
    String? name,
    String? projectCode,
    String? status,
    String? locationLabel,
    String? managerLabel,
    double? progressPct,
    double? budgetTotal,
    double? budgetSpent,
    int? delayDays,
    String? riskLevel,
    String? notes,
    DateTime? startDate,
    DateTime? targetEndDate,
  }) =>
      ref.read(cpmsServiceProvider).updateProject(
            id: id,
            name: name,
            projectCode: projectCode,
            status: status,
            locationLabel: locationLabel,
            managerLabel: managerLabel,
            progressPct: progressPct,
            budgetTotal: budgetTotal,
            budgetSpent: budgetSpent,
            delayDays: delayDays,
            riskLevel: riskLevel,
            notes: notes,
            startDate: startDate,
            targetEndDate: targetEndDate,
          );

  Future<void> deleteProject(String id) =>
      ref.read(cpmsServiceProvider).deleteProject(id);

  Future<void> upsertMilestone({
    String? id,
    required String projectId,
    required String name,
    String status = 'planned',
    DateTime? dueDate,
    double progressPct = 0,
    bool isCritical = false,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertMilestone(
            id: id,
            projectId: projectId,
            name: name,
            status: status,
            dueDate: dueDate,
            progressPct: progressPct,
            isCritical: isCritical,
            notes: notes,
          );

  Future<void> deleteMilestone(String id) =>
      ref.read(cpmsServiceProvider).deleteMilestone(id);

  Future<void> upsertTask({
    String? id,
    required String projectId,
    required String title,
    String status = 'todo',
    String priority = 'medium',
    String? assigneeLabel,
    DateTime? dueDate,
    double progressPct = 0,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertTask(
            id: id,
            projectId: projectId,
            title: title,
            status: status,
            priority: priority,
            assigneeLabel: assigneeLabel,
            dueDate: dueDate,
            progressPct: progressPct,
            notes: notes,
          );

  Future<void> deleteTask(String id) =>
      ref.read(cpmsServiceProvider).deleteTask(id);

  Future<void> setTaskStatus({
    required String taskId,
    required String projectId,
    required String status,
    required String title,
  }) =>
      ref.read(cpmsServiceProvider).setTaskStatus(
        taskId: taskId,
        projectId: projectId,
        status: status,
        title: title,
      );

  Future<void> upsertSiteDiary({
    String? id,
    required String projectId,
    required String summary,
    String? blockers,
    DateTime? entryDate,
    String? weather,
    String? authorLabel,
    int? workforceCount,
  }) =>
      ref.read(cpmsServiceProvider).upsertSiteDiary(
            id: id,
            projectId: projectId,
            summary: summary,
            blockers: blockers,
            entryDate: entryDate,
            weather: weather,
            authorLabel: authorLabel,
            workforceCount: workforceCount,
          );

  Future<void> deleteSiteDiary(String id) =>
      ref.read(cpmsServiceProvider).deleteSiteDiary(id);

  Future<void> upsertDefect({
    String? id,
    required String projectId,
    required String title,
    String status = 'open',
    String severity = 'medium',
    String? locationLabel,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertDefect(
            id: id,
            projectId: projectId,
            title: title,
            status: status,
            severity: severity,
            locationLabel: locationLabel,
            notes: notes,
          );

  Future<void> deleteDefect(String id) =>
      ref.read(cpmsServiceProvider).deleteDefect(id);

  Future<void> upsertChangeOrder({
    String? id,
    required String projectId,
    required String title,
    String status = 'draft',
    double costImpact = 0,
    String? rationale,
  }) =>
      ref.read(cpmsServiceProvider).upsertChangeOrder(
            id: id,
            projectId: projectId,
            title: title,
            status: status,
            costImpact: costImpact,
            rationale: rationale,
          );

  Future<void> deleteChangeOrder(String id) =>
      ref.read(cpmsServiceProvider).deleteChangeOrder(id);

  Future<void> approveChangeOrder(String id, {required String projectId}) =>
      ref.read(cpmsServiceProvider).approveChangeOrder(id, projectId: projectId);

  Future<void> upsertSafetyIncident({
    String? id,
    required String projectId,
    required String title,
    String severity = 'medium',
    String status = 'open',
    String? locationLabel,
    String? description,
  }) =>
      ref.read(cpmsServiceProvider).upsertSafetyIncident(
            id: id,
            projectId: projectId,
            title: title,
            severity: severity,
            status: status,
            locationLabel: locationLabel,
            description: description,
          );

  Future<void> deleteSafetyIncident(String id) =>
      ref.read(cpmsServiceProvider).deleteSafetyIncident(id);

  Future<void> upsertContractor({
    String? id,
    required String projectId,
    required String companyName,
    String status = 'active',
    String? specialty,
    double? contractValue,
    String? contactName,
  }) =>
      ref.read(cpmsServiceProvider).upsertContractor(
            id: id,
            projectId: projectId,
            companyName: companyName,
            status: status,
            specialty: specialty,
            contractValue: contractValue,
            contactName: contactName,
          );

  Future<void> deleteContractor(String id) =>
      ref.read(cpmsServiceProvider).deleteContractor(id);

  Future<void> upsertBudgetLine({
    String? id,
    required String projectId,
    required String category,
    String? description,
    double budgetedAmount = 0,
    double committedAmount = 0,
    double spentAmount = 0,
  }) =>
      ref.read(cpmsServiceProvider).upsertBudgetLine(
            id: id,
            projectId: projectId,
            category: category,
            description: description,
            budgetedAmount: budgetedAmount,
            committedAmount: committedAmount,
            spentAmount: spentAmount,
          );

  Future<void> deleteBudgetLine(String id) =>
      ref.read(cpmsServiceProvider).deleteBudgetLine(id);

  Future<void> upsertProcurementRequest({
    String? id,
    required String projectId,
    required String title,
    String status = 'draft',
    double estimatedCost = 0,
    DateTime? neededBy,
    String? requestedByLabel,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertProcurementRequest(
            id: id,
            projectId: projectId,
            title: title,
            status: status,
            estimatedCost: estimatedCost,
            neededBy: neededBy,
            requestedByLabel: requestedByLabel,
            notes: notes,
          );

  Future<void> deleteProcurementRequest(String id) =>
      ref.read(cpmsServiceProvider).deleteProcurementRequest(id);

  Future<void> upsertQualityCheck({
    String? id,
    required String projectId,
    required String title,
    String status = 'pending',
    double? scorePct,
    String? inspectorLabel,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertQualityCheck(
            id: id,
            projectId: projectId,
            title: title,
            status: status,
            scorePct: scorePct,
            inspectorLabel: inspectorLabel,
            notes: notes,
          );

  Future<void> deleteQualityCheck(String id) =>
      ref.read(cpmsServiceProvider).deleteQualityCheck(id);

  Future<void> upsertInspection({
    String? id,
    required String projectId,
    required String title,
    String inspectionType = 'site',
    String status = 'scheduled',
    DateTime? scheduledAt,
    String? inspectorLabel,
    String? notes,
  }) =>
      ref.read(cpmsServiceProvider).upsertInspection(
            id: id,
            projectId: projectId,
            title: title,
            inspectionType: inspectionType,
            status: status,
            scheduledAt: scheduledAt,
            inspectorLabel: inspectorLabel,
            notes: notes,
          );

  Future<void> deleteInspection(String id) =>
      ref.read(cpmsServiceProvider).deleteInspection(id);

  Future<void> upsertRisk({
    String? id,
    required String projectId,
    required String title,
    String severity = 'medium',
    String likelihood = 'possible',
    String status = 'open',
    String? mitigation,
    String? ownerLabel,
  }) =>
      ref.read(cpmsServiceProvider).upsertRisk(
            id: id,
            projectId: projectId,
            title: title,
            severity: severity,
            likelihood: likelihood,
            status: status,
            mitigation: mitigation,
            ownerLabel: ownerLabel,
          );

  Future<void> deleteRisk(String id) =>
      ref.read(cpmsServiceProvider).deleteRisk(id);

  Future<void> dismissAlert(String id) =>
      ref.read(cpmsServiceProvider).dismissAlert(id);
}
