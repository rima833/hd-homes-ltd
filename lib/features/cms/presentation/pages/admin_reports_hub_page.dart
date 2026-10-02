import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:hdhomesproject/core/constants/route_paths.dart';
import 'package:hdhomesproject/core/errors/app_exception.dart';
import 'package:hdhomesproject/core/export/export_engine.dart';
import 'package:hdhomesproject/core/theme/tokens/design_tokens.dart';
import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/presentation/providers/cms_providers.dart';
import 'package:hdhomesproject/features/cms/presentation/widgets/cms_admin_widgets.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons/lucide_icons.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Admin → Reports hub: live estate and property inventory, plus links into
/// the analytics, finance, and construction dashboards.
class AdminReportsHubPage extends ConsumerStatefulWidget {
  const AdminReportsHubPage({super.key});

  @override
  ConsumerState<AdminReportsHubPage> createState() => _AdminReportsHubPageState();
}

class _AdminReportsHubPageState extends ConsumerState<AdminReportsHubPage> {
  bool _exportingPdf = false;
  bool _exportingExcel = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    ref.watch(publishedEstatesRealtimeProvider);
    ref.watch(publishedPropertiesRealtimeProvider);
    final estatesAsync = ref.watch(cmsEstatesProvider);
    final propertiesAsync = ref.watch(cmsFeaturedPropertiesProvider(null));

    final estates = estatesAsync.valueOrNull ?? const <CmsEstateSummary>[];
    final properties =
        propertiesAsync.valueOrNull ?? const <CmsPropertyFeatured>[];
    final waiting = !estatesAsync.hasValue && !propertiesAsync.hasValue &&
        (estatesAsync.isLoading || propertiesAsync.isLoading);
    final failed = estatesAsync.hasError && propertiesAsync.hasError &&
        !estatesAsync.hasValue &&
        !propertiesAsync.hasValue;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: waiting
          ? const Center(child: CircularProgressIndicator())
          : failed
              ? _LoadFailure(
                  message: userFacingError(
                    estatesAsync.error ?? propertiesAsync.error,
                    fallback: 'Unable to load the website report.',
                  ),
                  onRetry: _refresh,
                )
              : SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AdminSectionHeader(
                        title: 'Reports hub',
                        subtitle:
                            'Estate and property inventory. Counts update when the website catalog changes.',
                        action: IconButton(
                          tooltip: 'Refresh',
                          onPressed: _refresh,
                          icon: const Icon(LucideIcons.refreshCw, size: 18),
                        ),
                      ),
                      if (estatesAsync.hasError || propertiesAsync.hasError)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            userFacingError(
                              estatesAsync.error ?? propertiesAsync.error,
                              fallback: 'Part of this report could not be loaded.',
                            ),
                            style: const TextStyle(color: AppColors.error),
                          ),
                        ),
                      if (estatesAsync.isLoading || propertiesAsync.isLoading)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 12),
                          child: LinearProgressIndicator(minHeight: 2),
                        ),
                      Row(
                        children: [
                          Expanded(
                            child: AdminKpi(
                              label: 'Total estates',
                              value: '${estates.length}',
                              subtitle:
                                  '${estates.where((e) => e.isPublished).length} published',
                              icon: LucideIcons.building2,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminKpi(
                              label: 'Featured estates',
                              value:
                                  '${estates.where((e) => e.isFeatured).length}',
                              icon: LucideIcons.star,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminKpi(
                              label: 'Total properties',
                              value: '${properties.length}',
                              subtitle:
                                  '${properties.where((p) => p.isPublished).length} published',
                              icon: LucideIcons.home,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: AdminKpi(
                              label: 'Featured properties',
                              value:
                                  '${properties.where((p) => p.isFeatured).length}',
                              icon: LucideIcons.sparkles,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Detailed dashboards',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ReportLinkCard(
                            title: 'Analytics',
                            description: 'Traffic, conversion and engagement dashboards.',
                            icon: LucideIcons.barChart3,
                            onTap: () => context.go(RoutePaths.dashboardAnalytics),
                          ),
                          _ReportLinkCard(
                            title: 'Finance',
                            description: 'Revenue, collections and payout summaries.',
                            icon: LucideIcons.wallet,
                            onTap: () => context.go(RoutePaths.dashboardFinance),
                          ),
                          _ReportLinkCard(
                            title: 'Construction',
                            description: 'Project milestones, budgets and site progress.',
                            icon: LucideIcons.hardHat,
                            onTap: () => context.go(RoutePaths.dashboardConstruction),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Website content snapshot',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Review every estate and property before you export. '
                        'The file includes the full catalog, not only the counts above.',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: AppColors.slate500,
                            ),
                      ),
                      const SizedBox(height: 12),
                      AdminCard(
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Estates & properties snapshot',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Generated as of ${DateFormat.yMMMd().add_jm().format(DateTime.now())}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(color: AppColors.slate500),
                                  ),
                                ],
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: _exportingPdf || estatesAsync.isLoading
                                  ? null
                                  : () => _exportPdf(estates, properties),
                              icon: _exportingPdf
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(strokeWidth: 2),
                                    )
                                  : const Icon(LucideIcons.fileText, size: 16),
                              label: const Text('Export PDF'),
                            ),
                            const SizedBox(width: 8),
                            FilledButton.icon(
                              onPressed: _exportingExcel || propertiesAsync.isLoading
                                  ? null
                                  : () => _exportExcel(estates, properties),
                              icon: _exportingExcel
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Icon(LucideIcons.fileSpreadsheet, size: 16),
                              label: const Text('Export Excel'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        onChanged: (value) => setState(() => _query = value.trim().toLowerCase()),
                        decoration: const InputDecoration(
                          isDense: true,
                          hintText: 'Search estates and properties',
                          prefixIcon: Icon(LucideIcons.search, size: 16),
                        ),
                      ),
                      const SizedBox(height: 16),
                      _InventorySection(
                        title: 'Estates',
                        empty: 'No estates match this report.',
                        onOpen: () => context.go(RoutePaths.dashboardWebsiteFeaturedEstates),
                        rows: _filterEstates(estates).map((estate) {
                          return _InventoryRow(
                            title: estate.name,
                            detail: [
                              if (estate.location.isNotEmpty) estate.location,
                              estate.displayStatus,
                              estate.isPublished ? 'Published' : 'Draft',
                              if (estate.isFeatured) 'Featured',
                              if ((estate.priceFromLabel ?? '').isNotEmpty)
                                estate.priceFromLabel!,
                            ].join(' · '),
                            onTap: () => context.go(
                              RoutePaths.dashboardWebsiteFeaturedEstates,
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 12),
                      _InventorySection(
                        title: 'Properties',
                        empty: 'No properties match this report.',
                        onOpen: () =>
                            context.go(RoutePaths.dashboardWebsiteFeaturedProperties),
                        rows: _filterProperties(properties).map((property) {
                          return _InventoryRow(
                            title: property.title,
                            detail: [
                              if ((property.estateName ?? '').isNotEmpty)
                                property.estateName!,
                              if (property.location.isNotEmpty) property.location,
                              property.displayPrice,
                              property.isPublished ? 'Published' : 'Draft',
                              if (property.isFeatured) 'Featured',
                            ].join(' · '),
                            onTap: () => context.go(
                              RoutePaths.dashboardWebsiteFeaturedProperties,
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
    );
  }

  void _refresh() {
    ref.invalidate(cmsEstatesProvider);
    ref.invalidate(cmsFeaturedPropertiesProvider(null));
  }

  List<CmsEstateSummary> _filterEstates(List<CmsEstateSummary> estates) {
    if (_query.isEmpty) return estates;
    return estates.where((estate) {
      final haystack =
          '${estate.name} ${estate.location} ${estate.slug} ${estate.displayStatus}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  List<CmsPropertyFeatured> _filterProperties(List<CmsPropertyFeatured> properties) {
    if (_query.isEmpty) return properties;
    return properties.where((property) {
      final haystack =
          '${property.title} ${property.estateName ?? ''} ${property.location} ${property.propertyCode ?? ''}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList();
  }

  Future<void> _exportPdf(
    List<CmsEstateSummary> estates,
    List<CmsPropertyFeatured> properties,
  ) async {
    setState(() => _exportingPdf = true);
    try {
      final bytes = await _buildSnapshotPdf(estates, properties);
      await ExportEngine.saveBytes(
        filename: 'hdhomes-website-snapshot.pdf',
        bytes: bytes,
        mimeType: 'application/pdf',
      );
    } catch (e) {
      _showExportError(e);
    } finally {
      if (mounted) setState(() => _exportingPdf = false);
    }
  }

  Future<void> _exportExcel(
    List<CmsEstateSummary> estates,
    List<CmsPropertyFeatured> properties,
  ) async {
    setState(() => _exportingExcel = true);
    try {
      final bytes = _buildSnapshotExcel(estates, properties);
      await ExportEngine.saveBytes(
        filename: 'hdhomes-website-snapshot.xlsx',
        bytes: bytes,
        mimeType:
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
    } catch (e) {
      _showExportError(e);
    } finally {
      if (mounted) setState(() => _exportingExcel = false);
    }
  }

  void _showExportError(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          userFacingError(error, fallback: 'Unable to export this report.'),
        ),
      ),
    );
  }

  Future<Uint8List> _buildSnapshotPdf(
    List<CmsEstateSummary> estates,
    List<CmsPropertyFeatured> properties,
  ) async {
    final generated = DateFormat.yMMMd().add_jm().format(DateTime.now());
    final doc = pw.Document();
    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(28),
        build: (context) => [
          pw.Text(
            'HD Homes — Website Content Snapshot',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(
            generated,
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(
            headers: const ['Metric', 'Count'],
            data: [
              ['Total estates', '${estates.length}'],
              ['Published estates', '${estates.where((e) => e.isPublished).length}'],
              ['Featured estates', '${estates.where((e) => e.isFeatured).length}'],
              ['Total properties', '${properties.length}'],
              [
                'Published properties',
                '${properties.where((p) => p.isPublished).length}',
              ],
              [
                'Featured properties',
                '${properties.where((p) => p.isFeatured).length}',
              ],
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text('Estates', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (estates.isEmpty)
            pw.Text('No estates')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Name', 'Location', 'Status', 'Published', 'Featured', 'From'],
              data: [
                for (final estate in estates)
                  [
                    estate.name,
                    estate.location,
                    estate.displayStatus,
                    estate.isPublished ? 'Yes' : 'No',
                    estate.isFeatured ? 'Yes' : 'No',
                    estate.priceFromLabel ?? '',
                  ],
              ],
            ),
          pw.SizedBox(height: 18),
          pw.Text('Properties', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          if (properties.isEmpty)
            pw.Text('No properties')
          else
            pw.TableHelper.fromTextArray(
              headers: const ['Title', 'Estate', 'Location', 'Price', 'Published', 'Featured'],
              data: [
                for (final property in properties)
                  [
                    property.title,
                    property.estateName ?? '',
                    property.location,
                    property.displayPrice,
                    property.isPublished ? 'Yes' : 'No',
                    property.isFeatured ? 'Yes' : 'No',
                  ],
              ],
            ),
        ],
      ),
    );
    return doc.save();
  }

  Uint8List _buildSnapshotExcel(
    List<CmsEstateSummary> estates,
    List<CmsPropertyFeatured> properties,
  ) {
    final excel = Excel.createExcel();
    excel.rename('Sheet1', 'Summary');
    final summary = excel['Summary'];
    final generated = DateFormat.yMMMd().add_jm().format(DateTime.now());
    summary.appendRow([TextCellValue('HD Homes Website Content Snapshot')]);
    summary.appendRow([TextCellValue('Generated'), TextCellValue(generated)]);
    summary.appendRow([]);
    summary.appendRow([TextCellValue('Metric'), TextCellValue('Count')]);
    summary.appendRow([
      TextCellValue('Total estates'),
      IntCellValue(estates.length),
    ]);
    summary.appendRow([
      TextCellValue('Published estates'),
      IntCellValue(estates.where((e) => e.isPublished).length),
    ]);
    summary.appendRow([
      TextCellValue('Featured estates'),
      IntCellValue(estates.where((e) => e.isFeatured).length),
    ]);
    summary.appendRow([
      TextCellValue('Total properties'),
      IntCellValue(properties.length),
    ]);
    summary.appendRow([
      TextCellValue('Published properties'),
      IntCellValue(properties.where((p) => p.isPublished).length),
    ]);
    summary.appendRow([
      TextCellValue('Featured properties'),
      IntCellValue(properties.where((p) => p.isFeatured).length),
    ]);

    final estateSheet = excel['Estates'];
    estateSheet.appendRow([
      TextCellValue('Name'),
      TextCellValue('Location'),
      TextCellValue('Status'),
      TextCellValue('Published'),
      TextCellValue('Featured'),
      TextCellValue('From'),
      TextCellValue('Slug'),
    ]);
    for (final estate in estates) {
      estateSheet.appendRow([
        TextCellValue(estate.name),
        TextCellValue(estate.location),
        TextCellValue(estate.displayStatus),
        TextCellValue(estate.isPublished ? 'Yes' : 'No'),
        TextCellValue(estate.isFeatured ? 'Yes' : 'No'),
        TextCellValue(estate.priceFromLabel ?? ''),
        TextCellValue(estate.slug),
      ]);
    }

    final propertySheet = excel['Properties'];
    propertySheet.appendRow([
      TextCellValue('Title'),
      TextCellValue('Estate'),
      TextCellValue('Location'),
      TextCellValue('Price'),
      TextCellValue('Published'),
      TextCellValue('Featured'),
      TextCellValue('Code'),
      TextCellValue('Slug'),
    ]);
    for (final property in properties) {
      propertySheet.appendRow([
        TextCellValue(property.title),
        TextCellValue(property.estateName ?? ''),
        TextCellValue(property.location),
        TextCellValue(property.displayPrice),
        TextCellValue(property.isPublished ? 'Yes' : 'No'),
        TextCellValue(property.isFeatured ? 'Yes' : 'No'),
        TextCellValue(property.propertyCode ?? ''),
        TextCellValue(property.slug),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) {
      throw StateError('Failed to encode Excel workbook');
    }
    return Uint8List.fromList(bytes);
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: onRetry, child: const Text('Try again')),
        ],
      ),
    );
  }
}

class _InventorySection extends StatelessWidget {
  const _InventorySection({
    required this.title,
    required this.empty,
    required this.rows,
    required this.onOpen,
  });

  final String title;
  final String empty;
  final List<_InventoryRow> rows;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return AdminCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$title (${rows.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              TextButton(onPressed: onOpen, child: const Text('Manage')),
            ],
          ),
          if (rows.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                empty,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.slate500,
                    ),
              ),
            )
          else
            ...rows,
        ],
      ),
    );
  }
}

class _InventoryRow extends StatelessWidget {
  const _InventoryRow({
    required this.title,
    required this.detail,
    required this.onTap,
  });

  final String title;
  final String detail;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: Text(detail),
      trailing: const Icon(LucideIcons.arrowRight, size: 14),
      onTap: onTap,
    );
  }
}

class _ReportLinkCard extends StatelessWidget {
  const _ReportLinkCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 260,
      child: AdminCard(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: AppColors.gold),
            const SizedBox(height: 10),
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.slate500,
                  ),
            ),
            const SizedBox(height: 10),
            const Row(
              children: [
                Text('Open dashboard'),
                SizedBox(width: 4),
                Icon(LucideIcons.arrowRight, size: 14),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
