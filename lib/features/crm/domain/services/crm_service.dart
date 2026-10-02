import 'package:hdhomesproject/features/crm/domain/entities/crm_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Live CRM sales desk — Supabase only (no demo mixing).
class CrmService {
  CrmService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<CrmCommandCenterSnapshot> loadCommandCenter() async {
    final client = _client;
    if (client == null) {
      return CrmCommandCenterSnapshot(
        kpis: _aggregateKpis(
          clients: const [],
          leads: const [],
          tasks: const [],
          inspections: const [],
        ),
        clients: const [],
        leads: const [],
        tasks: const [],
        appointments: const [],
        timeline: const [],
        stages: const [],
        aiInsights: const [],
        leadIntelligence: const [],
        relationshipGraph: const [],
        fromRemote: false,
        realtimeConnected: false,
        loadedAt: DateTime.now(),
      );
    }

    final clients = await _loadClients(client);
    final stages = await _loadStages(client);
    final leads = await _loadLeads(client);
    final tasks = await _loadTasks(client);
    final appointments = await _loadAppointments(client);
    final timeline = await _loadTimeline(client);
    final inspections = await _loadInspections(client);
    final applications = await _loadApplications(client);
    final callbacks = await _loadCallbacks(client);
    final consultations = await _loadConsultations(client);
    final properties = await _loadProperties(client);
    final payments = await _loadPayments(client);

    return CrmCommandCenterSnapshot(
      kpis: _aggregateKpis(
        clients: clients,
        leads: leads,
        tasks: tasks,
        inspections: inspections,
      ),
      clients: clients,
      leads: leads,
      tasks: tasks,
      appointments: appointments,
      timeline: timeline,
      stages: stages,
      aiInsights: const [],
      leadIntelligence: const [],
      relationshipGraph: const [],
      inspections: inspections,
      applications: applications,
      callbacks: callbacks,
      consultations: consultations,
      properties: properties,
      payments: payments,
      fromRemote: true,
      realtimeConnected: true,
      loadedAt: DateTime.now(),
    );
  }

  List<CrmKpi> _aggregateKpis({
    required List<CrmClient> clients,
    required List<CrmLead> leads,
    required List<CrmTask> tasks,
    required List<SalesBridgeRow> inspections,
  }) {
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final newLeads = leads
        .where((l) =>
            l.stageSlug == 'new' ||
            (l.capturedAt != null &&
                l.capturedAt!.isAfter(now.subtract(const Duration(days: 7))) &&
                l.status == CrmLeadStatus.open))
        .length
        .toDouble();
    final activePipeline = leads
        .where((l) =>
            l.status != CrmLeadStatus.won && l.status != CrmLeadStatus.lost)
        .length
        .toDouble();
    final qualified = leads
        .where((l) =>
            l.stageSlug == 'qualified' ||
            l.stageSlug == 'property_matched' ||
            l.status == CrmLeadStatus.qualified)
        .length
        .toDouble();
    final inspectionsToday = inspections
        .where((i) =>
            i.when != null &&
            !i.when!.isBefore(todayStart) &&
            i.when!.isBefore(todayStart.add(const Duration(days: 1))))
        .length
        .toDouble();
    final followUpsDue = tasks
        .where((t) =>
            (t.status == CrmTaskStatus.open ||
                t.status == CrmTaskStatus.inProgress) &&
            t.dueAt != null &&
            !t.dueAt!.isAfter(todayStart.add(const Duration(days: 1))))
        .length
        .toDouble();
    final activeClients = clients
        .where((c) =>
            c.relationshipStatus == CrmRelationshipStatus.activeBuyer ||
            c.relationshipStatus == CrmRelationshipStatus.prospect ||
            c.relationshipStatus == CrmRelationshipStatus.vip)
        .length
        .toDouble();
    var pipelineValue = 0.0;
    for (final lead in leads) {
      if (lead.status == CrmLeadStatus.won ||
          lead.status == CrmLeadStatus.lost) {
        continue;
      }
      pipelineValue += lead.estimatedValue ?? 0;
    }
    final closed = leads
        .where((l) =>
            l.status == CrmLeadStatus.won || l.status == CrmLeadStatus.lost)
        .length;
    final won =
        leads.where((l) => l.status == CrmLeadStatus.won).length.toDouble();
    final conversionRate = closed == 0 ? 0.0 : (won / closed) * 100;

    return [
      CrmKpi(label: 'New Leads', value: newLeads),
      CrmKpi(label: 'Active Pipeline', value: activePipeline),
      CrmKpi(label: 'Qualified', value: qualified),
      CrmKpi(label: 'Inspections Today', value: inspectionsToday),
      CrmKpi(label: 'Follow-ups Due', value: followUpsDue),
      CrmKpi(label: 'Active Clients', value: activeClients),
      CrmKpi(label: 'Pipeline Value', value: pipelineValue, unit: 'ngn'),
      CrmKpi(label: 'Conversion Rate', value: conversionRate, unit: 'percent'),
    ];
  }

  Future<List<CrmClient>> _loadClients(SupabaseClient client) async {
    final rows = await client
          .from('crm_clients')
          .select()
          .order('updated_at', ascending: false)
        .limit(300);
      final clients = <CrmClient>[];
    for (final row in rows as List) {
      clients.add(CrmClient.fromJson(Map<String, dynamic>.from(row as Map)));
    }

    try {
      final prefRows =
          await client.from('crm_preferences').select().limit(300);
      if ((prefRows as List).isEmpty) return clients;
          final byClient = <String, CrmClientPreference>{};
          for (final row in prefRows) {
            final map = Map<String, dynamic>.from(row as Map);
            final id = map['client_id']?.toString();
        if (id != null) byClient[id] = CrmClientPreference.fromJson(map);
          }
          for (var i = 0; i < clients.length; i++) {
            final pref = byClient[clients[i].id];
            if (pref == null) continue;
            final c = clients[i];
            clients[i] = CrmClient(
              id: c.id,
              clientCode: c.clientCode,
              fullName: c.fullName,
              email: c.email,
              phone: c.phone,
              whatsapp: c.whatsapp,
              customerType: c.customerType,
              relationshipStatus: c.relationshipStatus,
              assignedStaffId: c.assignedStaffId,
              profileId: c.profileId,
              nationality: c.nationality,
              preferredLanguage: c.preferredLanguage,
              occupation: c.occupation,
              company: c.company,
              industry: c.industry,
              budgetMin: c.budgetMin,
              budgetMax: c.budgetMax,
              preferredLocations: c.preferredLocations,
              healthScore: c.healthScore,
              healthLabel: c.healthLabel,
              leadScore: c.leadScore,
              aiSummary: c.aiSummary,
              marketingConsent: c.marketingConsent,
              preferences: pref,
              tags: c.tags,
            );
        }
      } catch (_) {}

    return clients;
  }

  Future<List<CrmPipelineStage>> _loadStages(SupabaseClient client) async {
    final rows = await client
            .from('crm_pipeline_stages')
            .select()
            .eq('is_active', true)
        .order('sort_order', ascending: true);
    final stages = (rows as List)
        .map((e) => CrmPipelineStage.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
    stages.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return stages;
        }

  Future<List<CrmLead>> _loadLeads(SupabaseClient client) async {
    final rows = await client
            .from('crm_leads')
            .select(
          '*, crm_pipeline_stages(slug, name), crm_lead_sources(name), crm_clients(full_name), properties(title)',
            )
            .order('captured_at', ascending: false)
        .limit(400);
    return (rows as List)
        .map((e) => CrmLead.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

  Future<List<CrmTask>> _loadTasks(SupabaseClient client) async {
    final rows = await client
            .from('crm_tasks')
            .select('*, crm_clients(full_name)')
            .order('due_at', ascending: true)
        .limit(200);
    return (rows as List)
        .map((e) => CrmTask.fromJson(Map<String, dynamic>.from(e as Map)))
              .toList();
        }

  Future<List<CrmAppointment>> _loadAppointments(SupabaseClient client) async {
    final rows = await client
            .from('crm_appointments')
            .select('*, crm_clients(full_name)')
            .order('scheduled_at', ascending: true)
        .limit(200);
    return (rows as List)
              .map(
          (e) => CrmAppointment.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }

  Future<List<CrmTimelineEvent>> _loadTimeline(SupabaseClient client) async {
    final rows = await client
            .from('crm_activity_logs')
            .select('*, crm_clients(full_name)')
            .order('occurred_at', ascending: false)
        .limit(100);
    return (rows as List)
              .map(
          (e) => CrmTimelineEvent.fromJson(Map<String, dynamic>.from(e as Map)),
              )
              .toList();
        }

  Future<List<Map<String, dynamic>>> listLeadSources() async {
    final client = _client;
    if (client == null) return const [];
    final rows =
        await client.from('crm_lead_sources').select('id, name').order('name');
    return (rows as List)
        .map((e) => Map<String, dynamic>.from(e as Map))
        .toList();
  }

  Future<String> upsertClient({
    String? id,
    required String fullName,
    String? email,
    String? phone,
    String? whatsapp,
    String customerType = 'guest',
    String relationshipStatus = 'lead',
    double? budgetMin,
    double? budgetMax,
    List<String> preferredLocations = const [],
    String? company,
    String? occupation,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final cleanedEmail =
        email?.trim().isEmpty == true ? null : email?.trim();
    String? linkedProfileId;
    if (cleanedEmail != null) {
      try {
        final profile = await client
            .from('profiles')
            .select('id')
            .ilike('email', cleanedEmail)
            .maybeSingle();
        linkedProfileId = profile?['id']?.toString();
      } catch (_) {}
    }

    final payload = <String, dynamic>{
      'full_name': fullName.trim(),
      'email': cleanedEmail,
      'phone': phone?.trim().isEmpty == true ? null : phone?.trim(),
      'whatsapp': whatsapp?.trim().isEmpty == true ? null : whatsapp?.trim(),
      'customer_type': customerType,
      'relationship_status': relationshipStatus,
      'budget_min': budgetMin,
      'budget_max': budgetMax,
      'preferred_locations': preferredLocations,
      'company': company?.trim().isEmpty == true ? null : company?.trim(),
      'occupation':
          occupation?.trim().isEmpty == true ? null : occupation?.trim(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      if (linkedProfileId != null) 'profile_id': linkedProfileId,
    };

    if (id != null) {
      await client.from('crm_clients').update(payload).eq('id', id);
      await _logActivity(
        clientId: id,
        eventType: 'client_updated',
        title: 'Client profile updated',
        description: fullName.trim(),
      );
      return id;
    }

    final code =
        'CL-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    final row = await client
        .from('crm_clients')
        .insert({
          ...payload,
          'client_code': code,
        })
        .select('id')
        .single();
    final newId = '${row['id']}';
    await _logActivity(
      clientId: newId,
      eventType: 'client_created',
      title: 'Client created',
      description: fullName.trim(),
    );
    return newId;
  }

  Future<String> createLead({
    required String clientId,
    required String title,
    String? stageId,
    String? sourceId,
    String priority = 'medium',
    double? estimatedValue,
    String? notes,
    double conversionProbability = 10,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    String? resolvedStage = stageId;
    if (resolvedStage == null) {
      final stages = await _loadStages(client);
      if (stages.isNotEmpty) resolvedStage = stages.first.id;
    }

    final row = await client
        .from('crm_leads')
        .insert({
          'client_id': clientId,
          'title': title.trim(),
          'stage_id': resolvedStage,
          'source_id': sourceId,
          'priority': priority,
          'estimated_value': estimatedValue,
          'notes': notes?.trim(),
          'conversion_probability': conversionProbability,
          'status': 'open',
        })
        .select('id')
        .single();
    final leadId = '${row['id']}';
    await _logActivity(
      clientId: clientId,
      eventType: 'lead_created',
      title: 'Lead created',
      description: title.trim(),
    );
    return leadId;
  }

  Future<void> updateLead({
    required String leadId,
    String? title,
    String? priority,
    String? status,
    double? estimatedValue,
    String? notes,
    double? conversionProbability,
    String? assignedTo,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final payload = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (title != null) payload['title'] = title.trim();
    if (priority != null) payload['priority'] = priority;
    if (status != null) payload['status'] = status;
    if (estimatedValue != null) payload['estimated_value'] = estimatedValue;
    if (notes != null) payload['notes'] = notes.trim();
    if (conversionProbability != null) {
      payload['conversion_probability'] = conversionProbability;
    }
    if (assignedTo != null) payload['assigned_to'] = assignedTo;

    await client.from('crm_leads').update(payload).eq('id', leadId);
  }

  Future<void> moveLeadStage({
    required String leadId,
    required String toStageId,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');

    final current = await client
        .from('crm_leads')
        .select('id, client_id, stage_id, title')
        .eq('id', leadId)
        .single();
    final fromStageId = current['stage_id']?.toString();
    final clientId = '${current['client_id']}';
    final title = '${current['title'] ?? 'Lead'}';

    final stages = await _loadStages(client);
    CrmPipelineStage? toStage;
    for (final s in stages) {
      if (s.id == toStageId) toStage = s;
    }

    final statusUpdate = switch (toStage?.slug) {
      'won' => 'won',
      'lost' => 'lost',
      _ => null,
    };

    await client.from('crm_leads').update({
      'stage_id': toStageId,
      if (statusUpdate != null) 'status': statusUpdate,
      if (toStage != null) 'conversion_probability': toStage.probabilityPct,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);

    await client.from('crm_pipeline_history').insert({
      'lead_id': leadId,
      'from_stage_id': fromStageId,
      'to_stage_id': toStageId,
      'changed_by': client.auth.currentUser?.id,
      'notes': notes,
    });

    await _logActivity(
      clientId: clientId,
      eventType: 'stage_changed',
      title: 'Pipeline stage updated',
      description:
          '$title → ${toStage?.name ?? toStageId}${notes == null || notes.isEmpty ? '' : ' · $notes'}',
    );
  }

  Future<String> createTask({
    required String clientId,
    required String title,
    String? leadId,
    String taskType = 'follow_up',
    String priority = 'medium',
    DateTime? dueAt,
    String? assignedTo,
    String? notes,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final uid = client.auth.currentUser?.id;
    final row = await client
        .from('crm_tasks')
        .insert({
          'client_id': clientId,
          'lead_id': leadId,
          'title': title.trim(),
          'task_type': taskType,
          'priority': priority,
          'status': 'open',
          'due_at': dueAt?.toUtc().toIso8601String(),
          'assigned_to': assignedTo ?? uid,
          'created_by': uid,
        })
        .select('id')
        .single();
    final note = notes?.trim();
    await _logActivity(
      clientId: clientId,
      eventType: 'task_created',
      title: 'Task created',
      description: note == null || note.isEmpty ? title.trim() : '${title.trim()} · $note',
    );
    return '${row['id']}';
  }

  Future<void> updateTask({
    required String taskId,
    String? status,
    DateTime? dueAt,
    bool clearDue = false,
    String? priority,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (status != null) patch['status'] = status;
    if (priority != null) patch['priority'] = priority;
    if (clearDue) {
      patch['due_at'] = null;
    } else if (dueAt != null) {
      patch['due_at'] = dueAt.toUtc().toIso8601String();
    }
    await client.from('crm_tasks').update(patch).eq('id', taskId);
  }

  Future<void> updateTaskStatus(String taskId, String status) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('crm_tasks').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', taskId);
  }

  Future<String> createAppointment({
    required String clientId,
    required String title,
    required DateTime scheduledAt,
    String appointmentType = 'meeting',
    String? location,
    String? meetingUrl,
    String? propertyId,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final row = await client
        .from('crm_appointments')
        .insert({
          'client_id': clientId,
          'title': title.trim(),
          'scheduled_at': scheduledAt.toUtc().toIso8601String(),
          'appointment_type': appointmentType,
          'location': location?.trim(),
          'meeting_url': meetingUrl?.trim(),
          'property_id': propertyId,
          'assigned_staff_id': client.auth.currentUser?.id,
          'status': 'scheduled',
        })
        .select('id')
        .single();
    await _logActivity(
      clientId: clientId,
      eventType: 'appointment_created',
      title: 'Appointment scheduled',
      description: title.trim(),
    );
    return '${row['id']}';
  }

  Future<void> updateAppointmentStatus(String id, String status) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('crm_appointments').update({
      'status': status,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> addNote({
    required String clientId,
    required String body,
    String noteType = 'general',
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    await client.from('crm_notes').insert({
      'client_id': clientId,
      'body': body.trim(),
      'note_type': noteType,
      'author_id': client.auth.currentUser?.id,
      'is_private': false,
    });
    await _logActivity(
      clientId: clientId,
      eventType: 'note_added',
      title: 'Note added',
      description: body.trim().length > 80
          ? '${body.trim().substring(0, 80)}…'
          : body.trim(),
    );
  }

  Future<void> _logActivity({
    required String clientId,
    required String eventType,
    required String title,
    String? description,
  }) async {
    final client = _client;
    if (client == null) return;
    try {
      await client.from('crm_activity_logs').insert({
        'client_id': clientId,
        'event_type': eventType,
        'title': title,
        'description': description,
        'actor_id': client.auth.currentUser?.id,
        'occurred_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  Future<List<SalesBridgeRow>> _loadInspections(SupabaseClient client) async {
    try {
      final rows = await client
          .from('property_inspections')
          .select(
            'id, visitor_name, status, scheduled_at, property_id, properties(title)',
          )
          .order('scheduled_at', ascending: true)
          .limit(80);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final prop = m['properties'];
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'inspection',
          title: 'Inspection — ${m['visitor_name'] ?? 'Visitor'}',
          status: '${m['status'] ?? ''}',
          clientName: m['visitor_name'] as String?,
          propertyTitle: prop is Map
              ? (prop['title'] as String? ?? prop['name'] as String?)
              : null,
          when: DateTime.tryParse('${m['scheduled_at'] ?? ''}'),
          linkId: m['property_id']?.toString(),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesBridgeRow>> _loadApplications(SupabaseClient client) async {
    try {
      final rows = await client
          .from('client_property_applications')
          .select(
            'id, status, amount_offered, created_at, property_id, client_id, '
            'properties(title), '
            'clients('
            '  id, client_code, user_id, '
            '  profiles:user_id(first_name, last_name, preferred_name, email, phone)'
            ')',
          )
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(80);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final prop = m['properties'];
        final clients = m['clients'];
        String? name;
        String? email;
        String? phone;
        String? profileId;
        if (clients is Map) {
          profileId = clients['user_id']?.toString();
          final code = clients['client_code'] as String?;
          final prof = clients['profiles'];
          if (prof is Map) {
            name = _profileDisplayName(Map<String, dynamic>.from(prof));
            email = prof['email'] as String?;
            phone = prof['phone'] as String?;
          }
          name ??= code;
        }
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'application',
          title: 'Application${name != null ? ' — $name' : ''}',
          status: '${m['status'] ?? ''}',
          amount: (m['amount_offered'] as num?)?.toDouble(),
          propertyTitle: prop is Map ? prop['title'] as String? : null,
          when: DateTime.tryParse('${m['created_at'] ?? ''}'),
          linkId: m['client_id']?.toString(),
          profileId: profileId,
          clientName: name,
          clientEmail: email,
          clientPhone: phone,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  static String? _profileDisplayName(Map<String, dynamic> prof) {
    final preferred = (prof['preferred_name'] as String?)?.trim();
    if (preferred != null && preferred.isNotEmpty) return preferred;
    final first = prof['first_name'] as String? ?? '';
    final last = prof['last_name'] as String? ?? '';
    final combined = '$first $last'.trim();
    return combined.isEmpty ? null : combined;
  }

  Future<List<SalesBridgeRow>> _loadCallbacks(SupabaseClient client) async {
    try {
      final rows = await client
          .from('callback_requests')
          .select(
            'id, full_name, status, phone, email, created_at, reference_number, crm_client_id',
          )
          .order('created_at', ascending: false)
          .limit(50);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'callback',
          title: 'Callback — ${m['full_name'] ?? ''}',
          status: '${m['status'] ?? ''}',
          subtitle: m['reference_number'] as String?,
          clientName: m['full_name'] as String?,
          clientPhone: m['phone'] as String?,
          clientEmail: m['email'] as String?,
          crmClientId: m['crm_client_id']?.toString(),
          when: DateTime.tryParse('${m['created_at'] ?? ''}'),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesBridgeRow>> _loadConsultations(SupabaseClient client) async {
    try {
      final rows = await client
          .from('consultation_bookings')
          .select(
            'id, full_name, status, scheduled_at, reference, purpose, phone, email, crm_client_id',
          )
          .order('scheduled_at', ascending: true)
          .limit(50);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'consultation',
          title: 'Consultation — ${m['full_name'] ?? ''}',
          status: '${m['status'] ?? ''}',
          subtitle: m['purpose'] as String? ?? m['reference'] as String?,
          clientName: m['full_name'] as String?,
          clientPhone: m['phone'] as String?,
          clientEmail: m['email'] as String?,
          crmClientId: m['crm_client_id']?.toString(),
          when: DateTime.tryParse('${m['scheduled_at'] ?? ''}'),
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesBridgeRow>> _loadPayments(SupabaseClient client) async {
    try {
      final rows = await client
          .from('client_payment_intents')
          .select('''
            id, amount, status, payment_reference, created_at, submitted_at,
            sender_name, property_id, client_id,
            properties(title),
            clients(
              id, client_code, user_id,
              profiles:user_id(preferred_name, first_name, last_name, email, phone)
            )
          ''')
          .eq('is_deleted', false)
          .order('created_at', ascending: false)
          .limit(80);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final prop = m['properties'];
        final clients = m['clients'];
        String? name = m['sender_name'] as String?;
        String? email;
        String? phone;
        String? profileId;
        if (clients is Map) {
          profileId = clients['user_id']?.toString();
          final prof = clients['profiles'];
          if (prof is Map) {
            name ??= _profileDisplayName(Map<String, dynamic>.from(prof));
            email = prof['email'] as String?;
            phone = prof['phone'] as String?;
          }
          name ??= clients['client_code'] as String?;
        }
        final ref = m['payment_reference'] as String?;
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'payment',
          title: ref != null && ref.isNotEmpty
              ? 'Payment $ref'
              : 'Payment${name != null ? ' — $name' : ''}',
          status: '${m['status'] ?? ''}',
          subtitle: name,
          clientName: name,
          clientEmail: email,
          clientPhone: phone,
          amount: (m['amount'] as num?)?.toDouble(),
          propertyTitle: prop is Map ? prop['title'] as String? : null,
          when: DateTime.tryParse(
            '${m['submitted_at'] ?? m['created_at'] ?? ''}',
          ),
          linkId: m['client_id']?.toString(),
          profileId: profileId,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  Future<List<SalesBridgeRow>> _loadProperties(SupabaseClient client) async {
    try {
      final rows = await client
          .from('properties')
          .select('id, title, status, city, updated_at')
          .order('updated_at', ascending: false)
          .limit(60);
      return (rows as List).map((raw) {
        final m = Map<String, dynamic>.from(raw as Map);
        final title = (m['title'] as String?) ?? 'Property';
        return SalesBridgeRow(
          id: '${m['id']}',
          kind: 'property',
          title: title,
          status: '${m['status'] ?? 'available'}',
          subtitle: m['city'] as String?,
        );
      }).toList();
    } catch (_) {
      return const [];
    }
  }

  /// Persist website contact form lead into CRM (no fake local-only record).
  Future<Map<String, dynamic>> persistPublicLead({
    required String fullName,
    required String phone,
    String? email,
    String? title,
    String? notes,
    String sourceSlug = 'website',
    String? propertyId,
    String? preferredLocation,
    String? interestSummary,
    String priority = 'medium',
    double? estimatedValue,
  }) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final row = await client.rpc(
      'upsert_crm_public_lead',
      params: {
        'p_full_name': fullName,
        'p_phone': phone,
        'p_email': email,
        'p_title': title,
        'p_notes': notes,
        'p_source_slug': sourceSlug,
        'p_property_id': propertyId,
        'p_preferred_location': preferredLocation,
        'p_interest_summary': interestSummary,
        'p_priority': priority,
        'p_estimated_value': estimatedValue,
        'p_visitor_profile_id': client.auth.currentUser?.id,
      },
    );
    return Map<String, dynamic>.from(row as Map);
  }

  Future<String> convertLeadToClient(String leadId) async {
    final client = _client;
    if (client == null) throw StateError('Supabase is not configured');
    final lead = await client
        .from('crm_leads')
        .select('id, client_id, title')
        .eq('id', leadId)
        .single();
    final clientId = '${lead['client_id']}';
    await client.from('crm_clients').update({
      'relationship_status': 'prospect',
      'customer_type': 'registered_client',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', clientId);
    await client.from('crm_leads').update({
      'status': 'qualified',
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', leadId);
    await _logActivity(
      clientId: clientId,
      eventType: 'converted_to_client',
      title: 'Lead converted to client',
      description: '${lead['title']}',
    );
    return clientId;
  }

  Future<List<CrmClient>> findDuplicateClients({
    String? email,
    String? phone,
  }) async {
    final client = _client;
    if (client == null) return const [];
    final results = <CrmClient>[];
    if (email != null && email.trim().isNotEmpty) {
      final rows = await client
          .from('crm_clients')
          .select()
          .ilike('email', email.trim())
          .limit(5);
      for (final r in rows as List) {
        results.add(CrmClient.fromJson(Map<String, dynamic>.from(r as Map)));
      }
    }
    if (phone != null && phone.trim().isNotEmpty) {
      final rows = await client
          .from('crm_clients')
          .select()
          .eq('phone', phone.trim())
          .limit(5);
      for (final r in rows as List) {
        final c = CrmClient.fromJson(Map<String, dynamic>.from(r as Map));
        if (!results.any((e) => e.id == c.id)) results.add(c);
      }
    }
    return results;
  }

  /// Plain operational summary for 360° (not AI theater).
  String clientSummary(CrmClient client) {
    final locs = client.preferredLocations.isEmpty
        ? '—'
        : client.preferredLocations.join(', ');
    return '${client.customerType.label} · ${client.relationshipStatus.label}. '
        'Budget ${client.budgetRange}. Locations: $locs. '
        'Health ${client.healthLabel.label} (${client.healthScore.toStringAsFixed(0)}). '
        'Lead score ${client.leadScore.toStringAsFixed(0)}/100.';
  }

  @Deprecated('Use clientSummary')
  String generateClientSummary(CrmClient client) => clientSummary(client);

  static double computeHealthScore({
    double engagement = 0,
    double recency = 0,
    double pipeline = 0,
    double referrals = 0,
  }) {
    final score = (engagement * 0.35) +
        (recency * 0.25) +
        (pipeline * 0.25) +
        (referrals * 0.15);
    return score.clamp(0, 100);
  }

  static CrmHealthLabel labelForScore(double score) =>
      CrmHealthLabel.fromScore(score);

  static double computeLeadScore({
    double budgetFit = 0,
    double engagement = 0,
    double stageProbability = 0,
    double priorityBoost = 0,
  }) {
    final score = (budgetFit * 0.3) +
        (engagement * 0.3) +
        (stageProbability * 0.25) +
        (priorityBoost * 0.15);
    return score.clamp(0, 100);
  }
}
