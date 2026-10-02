import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cpms/domain/entities/cpms_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

bool _numericColumn(String name) {
  return name.endsWith('_pct') ||
      name.endsWith('_amount') ||
      name.endsWith('_cost') ||
      name.endsWith('_days') ||
      name.endsWith('_count') ||
      name.contains('budget') ||
      name.contains('impact') ||
      name.contains('score');
}

/// Loads and mutates Construction Command Center data from Supabase.
/// Never mixes demo/placeholder rows into live snapshots.
class CpmsService {
  CpmsService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  SupabaseClient get _requireClient {
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not configured');
    }
    return client;
  }

  Future<void> _logActivity({
    required String projectId,
    required String eventType,
    required String title,
    String? description,
  }) async {
    try {
      await _requireClient.from('project_activity_logs').insert({
        'project_id': projectId,
        'event_type': eventType,
        'title': title,
        if (description != null) 'description': description,
        'actor_label': 'Construction Desk',
        'occurred_at': DateTime.now().toIso8601String(),
      });
    } catch (_) {
      // Activity logging must not block CRUD.
    }
  }

  static CpmsCommandCenterSnapshot emptyRemote({
    DateTime? loadedAt,
    bool fromRemote = true,
  }) {
    return CpmsCommandCenterSnapshot(
      kpis: CpmsDemo.aggregateKpis(
        projects: const [],
        milestones: const [],
        tasks: const [],
        changeOrders: const [],
        defects: const [],
        safetyIncidents: const [],
      ),
      projects: const [],
      milestones: const [],
      tasks: const [],
      contractors: const [],
      procurementRequests: const [],
      changeOrders: const [],
      budgetLines: const [],
      qualityChecks: const [],
      defects: const [],
      safetyIncidents: const [],
      siteDiaries: const [],
      inspections: const [],
      risks: const [],
      activities: const [],
      alerts: const [],
      aiInsights: const [],
      progressIntelligence: const [],
      fromRemote: fromRemote,
      loadedAt: loadedAt ?? DateTime.now(),
    );
  }

  Future<CpmsCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      // No fake placeholder data — empty desk until Supabase is configured.
      return emptyRemote(fromRemote: false);
    }

    try {
      final projectRows = await client
          .from('construction_projects')
          .select('*, estates(name, slug)')
          .order('updated_at', ascending: false)
          .limit(200);

      final projects = <CpmsProject>[];
      for (final row in projectRows) {
        final map = Map<String, dynamic>.from(row as Map);
        if ((map['name'] as String?)?.isNotEmpty != true) continue;
        projects.add(CpmsProject.fromJson(map));
      }

      final loadWarnings = <String>[];

      Map<String, dynamic> coerceRow(Map raw) {
        final out = <String, dynamic>{};
        raw.forEach((key, value) {
          final name = key.toString();
          if (value is DateTime) {
            out[name] = value.toIso8601String();
          } else if (value is Map) {
            out[name] = coerceRow(value);
          } else if (value is String) {
            final number = num.tryParse(value);
            out[name] = number != null && _numericColumn(name) ? number : value;
          } else {
            out[name] = value;
          }
        });
        return out;
      }

      Future<List<T>> loadList<T>({
        required String table,
        required String select,
        required String orderCol,
        required bool ascending,
        required T Function(Map<String, dynamic>) map,
        int limit = 200,
        dynamic Function(dynamic query)? filter,
      }) async {
        try {
          dynamic query = client.from(table).select(select);
          if (filter != null) {
            query = filter(query);
          }
          final rows = await query
              .order(orderCol, ascending: ascending)
              .limit(limit);
          final parsed = <T>[];
          for (final raw in rows as List) {
            try {
              parsed.add(map(coerceRow(raw as Map)));
            } catch (err) {
              loadWarnings.add('$table: $err');
            }
          }
          return parsed;
        } catch (err) {
          loadWarnings.add('$table: $err');
          return const [];
        }
      }

      final milestones = await loadList(
        table: 'project_milestones',
        select: '*, construction_projects(name)',
        orderCol: 'due_date',
        ascending: true,
        map: CpmsMilestone.fromJson,
      );
      final tasks = await loadList(
        table: 'project_tasks',
        select: '*, construction_projects(name)',
        orderCol: 'due_date',
        ascending: true,
        map: CpmsTask.fromJson,
      );
      final contractors = await loadList(
        table: 'project_contractors',
        select: '*, construction_projects(name)',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsContractor.fromJson,
        limit: 100,
      );
      final procurement = await loadList(
        table: 'project_procurement_requests',
        select: '*',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsProcurementRequest.fromJson,
        limit: 100,
      );
      final changeOrders = await loadList(
        table: 'project_change_orders',
        select: '*, construction_projects(name)',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsChangeOrder.fromJson,
        limit: 100,
      );
      final budgetLines = await loadList(
        table: 'project_budget_lines',
        select: '*',
        orderCol: 'category',
        ascending: true,
        map: CpmsBudgetLine.fromJson,
      );
      final qualityChecks = await loadList(
        table: 'project_quality_checks',
        select: '*',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsQualityCheck.fromJson,
        limit: 100,
      );
      final defects = await loadList(
        table: 'project_defects',
        select: '*, construction_projects(name)',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsDefect.fromJson,
        limit: 100,
      );
      final safety = await loadList(
        table: 'project_safety_incidents',
        select: '*, construction_projects(name)',
        orderCol: 'occurred_at',
        ascending: false,
        map: CpmsSafetyIncident.fromJson,
        limit: 100,
      );
      final diaries = await loadList(
        table: 'project_site_diaries',
        select: '*, construction_projects(name)',
        orderCol: 'entry_date',
        ascending: false,
        map: CpmsSiteDiary.fromJson,
        limit: 100,
      );
      final inspections = await loadList(
        table: 'project_inspections',
        select: '*',
        orderCol: 'scheduled_at',
        ascending: true,
        map: CpmsInspection.fromJson,
        limit: 100,
      );
      final risks = await loadList(
        table: 'project_risk_register',
        select: '*',
        orderCol: 'updated_at',
        ascending: false,
        map: CpmsRisk.fromJson,
        limit: 100,
      );
      final activities = await loadList(
        table: 'project_activity_logs',
        select: '*',
        orderCol: 'occurred_at',
        ascending: false,
        map: CpmsActivity.fromJson,
        limit: 100,
      );
      final alerts = await loadList(
        table: 'project_notifications',
        select: '*',
        orderCol: 'created_at',
        ascending: false,
        map: CpmsAlert.fromJson,
        limit: 100,
        filter: (q) => q.neq('status', 'dismissed'),
      );

      return CpmsCommandCenterSnapshot(
        kpis: CpmsDemo.aggregateKpis(
          projects: projects,
          milestones: milestones,
          tasks: tasks,
          changeOrders: changeOrders,
          defects: defects,
          safetyIncidents: safety,
        ),
        projects: projects,
        milestones: milestones,
        tasks: tasks,
        contractors: contractors,
        procurementRequests: procurement,
        changeOrders: changeOrders,
        budgetLines: budgetLines,
        qualityChecks: qualityChecks,
        defects: defects,
        safetyIncidents: safety,
        siteDiaries: diaries,
        inspections: inspections,
        risks: risks,
        activities: activities,
        alerts: alerts,
        aiInsights: const [],
        progressIntelligence: projects
            .where((p) => p.isDelayed)
            .map(
              (p) =>
                  '${p.name}: ${p.delayDays}d delay · ${p.progressPct.toStringAsFixed(0)}% complete',
            )
            .toList(),
        fromRemote: true,
        loadedAt: DateTime.now(),
        loadWarnings: loadWarnings,
      );
    } catch (e) {
      // Prefer empty remote over demo placeholders when Supabase is configured.
      return emptyRemote();
    }
  }

  String generateProgressSummary(CpmsProject project) {
    final conf = project.forecastConfidencePct;
    final confLabel =
        conf == null ? 'n/a' : '${conf.toStringAsFixed(0)}% confidence';
    return 'Progress summary: ${project.name} · ${project.status.label} · '
        '${project.progressPct.toStringAsFixed(0)}% complete · '
        'delay ${project.delayDays}d · forecast $confLabel. '
        '${project.aiSummary ?? 'Review milestones, blockers, and change orders this week.'} '
        '(${project.forecastDisclaimer})';
  }

  static List<CpmsProject> detectDelayedProjects(List<CpmsProject> projects) =>
      CpmsDemo.detectDelayedProjects(projects);

  Future<Map<String, dynamic>> publishLiveProgress({
    required String projectId,
    double? progressPct,
    String? statusUpdate,
    String? expectedCompletion,
    String? coverImageUrl,
    List<String> galleryImageUrls = const [],
    bool publishWebsite = true,
    bool publishPortals = true,
  }) async {
    final row = await _requireClient.rpc(
      'cpms_publish_live_progress',
      params: {
        'p_project_id': projectId,
        'p_progress_pct': progressPct,
        'p_status_update': statusUpdate,
        'p_expected_completion': expectedCompletion,
        'p_cover_image_url': coverImageUrl,
        'p_gallery_image_urls': galleryImageUrls,
        'p_publish_website': publishWebsite,
        'p_publish_portals': publishPortals,
      },
    );
    if (row is Map) return Map<String, dynamic>.from(row);
    await _logActivity(
      projectId: projectId,
      eventType: 'published',
      title: 'Progress published',
      description: statusUpdate,
    );
    return {'project_id': projectId, 'progress_pct': progressPct};
  }

  String _slugifyProject(CpmsProject project) {
    final raw = (project.projectCode.trim().isNotEmpty
            ? project.projectCode
            : project.name)
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
        .replaceAll(RegExp(r'^-+|-+$'), '');
    return raw.isEmpty ? project.id.replaceAll('-', '') : raw;
  }

  /// Loads the public website card for this CPMS project (if published before).
  Future<CmsWebsiteConstructionUpdate?> findWebsiteUpdateForProject(
    CpmsProject project,
  ) async {
    final client = _client;
    if (client == null) return null;
    final slug = _slugifyProject(project);
    try {
      final rows = await client
          .from('website_construction_updates')
          .select()
          .eq('slug', slug)
          .eq('is_deleted', false)
          .limit(1);
      if (rows.isEmpty) return null;
      return CmsWebsiteConstructionUpdate.fromJson(
        Map<String, dynamic>.from(rows.first),
      );
    } catch (_) {
      return null;
    }
  }

  Future<String> createProjectFromWizard(CpmsWizardDraft draft) async {
    final name = draft.name.trim();
    if (name.isEmpty) throw StateError('Project name is required');
    var code = draft.projectCode.trim();
    if (code.isEmpty) {
      code =
          'CP-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    }

    final client = _requireClient;
    final inserted = await client
        .from('construction_projects')
        .insert({
          'project_code': code,
          'name': name,
          'status': 'planning',
          'location_label':
              draft.locationLabel.trim().isEmpty ? null : draft.locationLabel.trim(),
          'manager_label':
              draft.managerLabel.trim().isEmpty ? null : draft.managerLabel.trim(),
          'budget_total': draft.budgetTotal,
          'start_date': (draft.startDate ?? DateTime.now())
              .toIso8601String()
              .split('T')
              .first,
          'target_end_date': draft.targetEndDate
              ?.toIso8601String()
              .split('T')
              .first,
          'notes': draft.notes.trim().isEmpty ? null : draft.notes.trim(),
          'progress_pct': 0,
        })
        .select('id')
        .single();

    final projectId = inserted['id'] as String;

    for (var i = 0; i < draft.phaseNames.length; i++) {
      final phase = draft.phaseNames[i].trim();
      if (phase.isEmpty) continue;
      await client.from('project_phases').insert({
        'project_id': projectId,
        'name': phase,
        'sort_order': (i + 1) * 10,
        'status': 'planned',
      });
    }

    for (final milestone in draft.milestoneNames) {
      final name = milestone.trim();
      if (name.isEmpty) continue;
      await client.from('project_milestones').insert({
        'project_id': projectId,
        'name': name,
        'status': 'planned',
        'due_date': draft.targetEndDate?.toIso8601String().split('T').first,
      });
    }

    for (final contractor in draft.contractorNames) {
      final name = contractor.trim();
      if (name.isEmpty) continue;
      await client.from('project_contractors').insert({
        'project_id': projectId,
        'company_name': name,
        'status': 'active',
      });
    }

    await client.from('project_activity_logs').insert({
      'project_id': projectId,
      'event_type': 'created',
      'title': 'Project created',
      'description': 'Created from Construction Command Center wizard',
      'actor_label': 'Construction Desk',
    });

    return projectId;
  }

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
  }) async {
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
      if (name != null) 'name': name.trim(),
      if (projectCode != null) 'project_code': projectCode.trim(),
      if (status != null) 'status': status,
      if (locationLabel != null) 'location_label': locationLabel.trim(),
      if (managerLabel != null) 'manager_label': managerLabel.trim(),
      if (progressPct != null) 'progress_pct': progressPct,
      if (budgetTotal != null) 'budget_total': budgetTotal,
      if (budgetSpent != null) 'budget_spent': budgetSpent,
      if (delayDays != null) 'delay_days': delayDays,
      if (riskLevel != null) 'risk_level': riskLevel,
      if (notes != null) 'notes': notes.trim(),
      if (startDate != null)
        'start_date': startDate.toIso8601String().split('T').first,
      if (targetEndDate != null)
        'target_end_date': targetEndDate.toIso8601String().split('T').first,
    };
    await _requireClient.from('construction_projects').update(patch).eq('id', id);
    await _logActivity(
      projectId: id,
      eventType: 'updated',
      title: 'Project updated',
      description: name ?? projectCode,
    );
  }

  Future<void> deleteProject(String id) async {
    await _requireClient.from('construction_projects').delete().eq('id', id);
    await _logActivity(
      projectId: id,
      eventType: 'deleted',
      title: 'Project deleted',
    );
  }

  Future<void> upsertMilestone({
    String? id,
    required String projectId,
    required String name,
    String status = 'planned',
    DateTime? dueDate,
    double progressPct = 0,
    bool isCritical = false,
    String? notes,
  }) async {
    final payload = {
      'project_id': projectId,
      'name': name.trim(),
      'status': status,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'progress_pct': progressPct,
      'is_critical': isCritical,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
      if (status == 'completed')
        'completed_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_milestones').insert(payload);
    } else {
      await _requireClient.from('project_milestones').update(payload).eq('id', id);
    }
  }

  Future<void> deleteMilestone(String id) async {
    await _requireClient.from('project_milestones').delete().eq('id', id);
  }

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
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'status': status,
      'priority': priority,
      'assignee_label': assigneeLabel,
      'due_date': dueDate?.toIso8601String().split('T').first,
      'progress_pct': progressPct,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_tasks').insert(payload);
    } else {
      await _requireClient.from('project_tasks').update(payload).eq('id', id);
    }
  }

  Future<void> deleteTask(String id) async {
    await _requireClient.from('project_tasks').delete().eq('id', id);
  }

  Future<void> setTaskStatus({
    required String taskId,
    required String projectId,
    required String status,
    required String title,
  }) async {
    await _requireClient.from('project_tasks').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', taskId);
    await _logActivity(
      projectId: projectId,
      eventType: 'task',
      title: 'Task $status',
      description: title,
    );
  }

  Future<void> upsertSiteDiary({
    String? id,
    required String projectId,
    required String summary,
    String? blockers,
    DateTime? entryDate,
    String? weather,
    String? authorLabel,
    int? workforceCount,
  }) async {
    final payload = {
      'project_id': projectId,
      'summary': summary.trim(),
      'blockers': blockers,
      'entry_date':
          (entryDate ?? DateTime.now()).toIso8601String().split('T').first,
      'weather': weather,
      'author_label': authorLabel,
      'workforce_count': workforceCount,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_site_diaries').insert(payload);
    } else {
      await _requireClient
          .from('project_site_diaries')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteSiteDiary(String id) async {
    await _requireClient.from('project_site_diaries').delete().eq('id', id);
  }

  Future<void> upsertDefect({
    String? id,
    required String projectId,
    required String title,
    String status = 'open',
    String severity = 'medium',
    String? locationLabel,
    String? notes,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'status': status,
      'severity': severity,
      'location_label': locationLabel,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
      if (id == null) 'reported_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_defects').insert(payload);
    } else {
      await _requireClient.from('project_defects').update(payload).eq('id', id);
    }
  }

  Future<void> deleteDefect(String id) async {
    await _requireClient.from('project_defects').delete().eq('id', id);
  }

  Future<void> upsertChangeOrder({
    String? id,
    required String projectId,
    required String title,
    String status = 'draft',
    double costImpact = 0,
    String? rationale,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'status': status,
      'cost_impact': costImpact,
      'rationale': rationale,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      final code =
          'CO-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      await _requireClient.from('project_change_orders').insert({
        ...payload,
        'change_code': code,
      });
    } else {
      await _requireClient
          .from('project_change_orders')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteChangeOrder(String id) async {
    await _requireClient.from('project_change_orders').delete().eq('id', id);
  }

  Future<void> approveChangeOrder(String id, {required String projectId}) async {
    await _requireClient.from('project_change_orders').update({
      'status': ChangeOrderStatus.approved.slug,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> upsertSafetyIncident({
    String? id,
    required String projectId,
    required String title,
    String severity = 'medium',
    String status = 'open',
    String? locationLabel,
    String? description,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'severity': severity,
      'status': status,
      'location_label': locationLabel,
      'description': description,
      'occurred_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_safety_incidents').insert(payload);
    } else {
      await _requireClient
          .from('project_safety_incidents')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteSafetyIncident(String id) async {
    await _requireClient.from('project_safety_incidents').delete().eq('id', id);
  }

  Future<void> upsertContractor({
    String? id,
    required String projectId,
    required String companyName,
    String status = 'active',
    String? specialty,
    double? contractValue,
    String? contactName,
  }) async {
    final payload = {
      'project_id': projectId,
      'company_name': companyName.trim(),
      'status': status,
      'specialty': specialty,
      'contract_value': contractValue,
      'contact_name': contactName,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_contractors').insert(payload);
    } else {
      await _requireClient
          .from('project_contractors')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteContractor(String id) async {
    await _requireClient.from('project_contractors').delete().eq('id', id);
  }

  Future<void> upsertBudgetLine({
    String? id,
    required String projectId,
    required String category,
    String? description,
    double budgetedAmount = 0,
    double committedAmount = 0,
    double spentAmount = 0,
  }) async {
    final payload = {
      'project_id': projectId,
      'category': category.trim(),
      'description': description,
      'budgeted_amount': budgetedAmount,
      'committed_amount': committedAmount,
      'spent_amount': spentAmount,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_budget_lines').insert(payload);
    } else {
      await _requireClient
          .from('project_budget_lines')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteBudgetLine(String id) async {
    await _requireClient.from('project_budget_lines').delete().eq('id', id);
  }

  Future<void> upsertProcurementRequest({
    String? id,
    required String projectId,
    required String title,
    String status = 'draft',
    double estimatedCost = 0,
    DateTime? neededBy,
    String? requestedByLabel,
    String? notes,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'status': status,
      'estimated_cost': estimatedCost,
      'needed_by': neededBy?.toIso8601String().split('T').first,
      'requested_by_label': requestedByLabel,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      final code =
          'PR-${DateTime.now().millisecondsSinceEpoch.toString().substring(6)}';
      await _requireClient.from('project_procurement_requests').insert({
        ...payload,
        'request_code': code,
      });
    } else {
      await _requireClient
          .from('project_procurement_requests')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteProcurementRequest(String id) async {
    await _requireClient
        .from('project_procurement_requests')
        .delete()
        .eq('id', id);
  }

  Future<void> upsertQualityCheck({
    String? id,
    required String projectId,
    required String title,
    String status = 'pending',
    double? scorePct,
    String? inspectorLabel,
    String? notes,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'status': status,
      'score_pct': scorePct,
      'inspector_label': inspectorLabel,
      'notes': notes,
      'checked_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_quality_checks').insert(payload);
    } else {
      await _requireClient
          .from('project_quality_checks')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteQualityCheck(String id) async {
    await _requireClient.from('project_quality_checks').delete().eq('id', id);
  }

  Future<void> upsertInspection({
    String? id,
    required String projectId,
    required String title,
    String inspectionType = 'site',
    String status = 'scheduled',
    DateTime? scheduledAt,
    String? inspectorLabel,
    String? notes,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'inspection_type': inspectionType,
      'status': status,
      'scheduled_at': scheduledAt?.toIso8601String(),
      'inspector_label': inspectorLabel,
      'notes': notes,
      'updated_at': DateTime.now().toIso8601String(),
      if (status == 'completed')
        'completed_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_inspections').insert(payload);
    } else {
      await _requireClient
          .from('project_inspections')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteInspection(String id) async {
    await _requireClient.from('project_inspections').delete().eq('id', id);
  }

  Future<void> upsertRisk({
    String? id,
    required String projectId,
    required String title,
    String severity = 'medium',
    String likelihood = 'possible',
    String status = 'open',
    String? mitigation,
    String? ownerLabel,
  }) async {
    final payload = {
      'project_id': projectId,
      'title': title.trim(),
      'severity': severity,
      'likelihood': likelihood,
      'status': status,
      'mitigation': mitigation,
      'owner_label': ownerLabel,
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (id == null) {
      await _requireClient.from('project_risk_register').insert(payload);
    } else {
      await _requireClient
          .from('project_risk_register')
          .update(payload)
          .eq('id', id);
    }
  }

  Future<void> deleteRisk(String id) async {
    await _requireClient.from('project_risk_register').delete().eq('id', id);
  }

  Future<void> dismissAlert(String id) async {
    await _requireClient
        .from('project_notifications')
        .update({'status': 'dismissed'})
        .eq('id', id);
  }
}
