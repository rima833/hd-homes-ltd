import 'package:hdhomesproject/features/cms/domain/entities/cms_models.dart';
import 'package:hdhomesproject/features/cms/domain/services/cms_service.dart';
import 'package:hdhomesproject/features/pms/domain/entities/pms_models.dart';
import 'package:hdhomesproject/features/properties/data/models/property_detail_extras.dart';

String slugifyPropertyTitle(String title) {
  final base = title
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) {
    return 'property-${DateTime.now().millisecondsSinceEpoch}';
  }
  return base;
}

PmsWizardDraft wizardDraftFromCms(CmsPropertyFeatured property) {
  final type = (property.propertyType ?? 'apartment').trim().toLowerCase();
  return PmsWizardDraft(
    existingId: property.id,
    title: property.title,
    slug: property.slug,
    propertyCode: property.propertyCode ?? '',
    propertyType: type.isEmpty ? 'apartment' : type,
    description: property.description ?? property.summary ?? '',
    estateName: property.estateName ?? '',
    city: property.city ?? '',
    state: property.state ?? '',
    addressLine: property.addressLine ?? '',
    bedrooms: property.bedrooms ?? 0,
    bathrooms: property.bathrooms ?? 0,
    toilets: property.toilets ?? 0,
    kitchens: property.kitchens ?? 0,
    builtUpAreaSqm: property.buildingSizeSqm,
    landSizeSqm: property.landSizeSqm,
    parkingSpaces: property.parkingSpaces ?? 0,
    floors: property.floors ?? 0,
    yearBuilt: property.yearBuilt?.trim().isNotEmpty == true
        ? property.yearBuilt!.trim()
        : '',
    powerSupply: property.powerSupply?.trim() ?? '',
    waterSupply: property.waterSupply?.trim() ?? '',
    internetConnectivity: property.internetConnectivity?.trim() ?? '',
    architecturalConcept: property.architecturalConcept ?? '',
    investmentPotential: property.investmentPotential ?? '',
    amenities: property.amenities,
    listingPrice: property.listingPrice,
    promoPrice: property.promoPrice,
    priceLabel: property.priceLabel ?? '',
    existingGalleryUrls: property.galleryUrls,
    documentsNote: property.summary ?? '',
    detailExtras:
        property.detailExtras ?? PropertyDetailExtras.emptyForWizard(),
    publishStatus: property.isPublished
        ? PublishWorkflowStatus.published
        : PublishWorkflowStatus.draft,
    inventoryStatus: InventoryStatus.available,
    marketingStatus: MarketingStatus.fromSlug(property.marketingStatus),
    featureOnHomepage: property.isFeatured,
  );
}

/// Persists a 9-step wizard draft through [CmsService] (create or update).
Future<CmsPropertyFeatured> persistWizardDraft({
  required CmsService cms,
  required PmsWizardDraft draft,
}) async {
  final title =
      draft.title.trim().isEmpty ? 'Untitled property' : draft.title.trim();
  final slug = draft.slug.trim().isNotEmpty
      ? draft.slug.trim()
      : slugifyPropertyTitle(title);
  final published = draft.publishStatus == PublishWorkflowStatus.published;
  final featured = draft.featureOnHomepage ||
      draft.marketingStatus == MarketingStatus.featured;

  final overview = draft.description.trim().isNotEmpty
      ? draft.description.trim()
      : null;
  final docs = draft.documentsNote.trim();
  final summary = [
    if (docs.isNotEmpty) docs,
    if (draft.mediaNote.trim().isNotEmpty) draft.mediaNote.trim(),
  ].join('\n\n');

  final priceLabel =
      draft.priceLabel.trim().isEmpty ? null : draft.priceLabel.trim();
  final rawExtras =
      draft.detailExtras ?? PropertyDetailExtras.emptyForWizard();
  final extras = rawExtras.copyWith(
    paymentPlans: [
      for (final plan in rawExtras.paymentPlans)
        if (plan.name.trim().isNotEmpty && plan.months > 0) plan,
    ],
  );

  late final CmsPropertyFeatured saved;
  final existingId = draft.existingId;

  if (existingId != null && existingId.isNotEmpty) {
    await cms.upsertPropertyBasic(
      id: existingId,
      title: title,
      slug: slug,
      description: overview,
      summary: summary.isEmpty ? null : summary,
      city: draft.city.trim().isEmpty ? null : draft.city.trim(),
      state: draft.state.trim().isEmpty ? null : draft.state.trim(),
      addressLine:
          draft.addressLine.trim().isEmpty ? null : draft.addressLine.trim(),
      estateName:
          draft.estateName.trim().isEmpty ? null : draft.estateName.trim(),
      propertyCode:
          draft.propertyCode.trim().isEmpty ? null : draft.propertyCode.trim(),
      categorySlug: draft.propertyType,
      bedrooms: draft.bedrooms,
      bathrooms: draft.bathrooms,
      toilets: draft.toilets,
      kitchens: draft.kitchens,
      parkingSpaces: draft.parkingSpaces,
      floors: draft.floors,
      landSizeSqm: (draft.landSizeSqm ?? 0) > 0 ? draft.landSizeSqm : null,
      buildingSizeSqm:
          (draft.builtUpAreaSqm ?? 0) > 0 ? draft.builtUpAreaSqm : null,
      yearBuilt: draft.yearBuilt.trim(),
      powerSupply: draft.powerSupply.trim(),
      waterSupply: draft.waterSupply.trim(),
      internetConnectivity: draft.internetConnectivity.trim(),
      architecturalConcept: draft.architecturalConcept.trim(),
      investmentPotential: draft.investmentPotential.trim(),
      listingPrice: (draft.listingPrice ?? 0) > 0 ? draft.listingPrice : null,
      promoPrice: (draft.promoPrice ?? 0) > 0 ? draft.promoPrice : null,
      investorPrice:
          (draft.investorPrice ?? 0) > 0 ? draft.investorPrice : null,
      rentalPrice: (draft.rentalPrice ?? 0) > 0 ? draft.rentalPrice : null,
      homepageBadge: draft.inventoryStatus.label,
      priceLabel: priceLabel,
      marketingStatus: draft.marketingStatus.slug,
      inventoryStatus: draft.inventoryStatus.slug,
      amenities: draft.amenities,
      detailExtras: extras,
    );
    await cms.setPropertyPublished(existingId, published);
    await cms.setPropertyFeatured(existingId, featured);
    saved = await cms.getPropertyById(existingId) ??
        CmsPropertyFeatured(
          id: existingId,
          title: title,
          slug: slug,
          description: overview,
          isFeatured: featured,
          isPublished: published,
        );
  } else {
    saved = await cms.createProperty(
      title: title,
      slug: slug,
      description: overview,
      summary: summary.isEmpty ? null : summary,
      city: draft.city.trim().isEmpty ? null : draft.city.trim(),
      state: draft.state.trim().isEmpty ? null : draft.state.trim(),
      addressLine:
          draft.addressLine.trim().isEmpty ? null : draft.addressLine.trim(),
      estateName:
          draft.estateName.trim().isEmpty ? null : draft.estateName.trim(),
      propertyCode:
          draft.propertyCode.trim().isEmpty ? null : draft.propertyCode.trim(),
      categorySlug: draft.propertyType,
      bedrooms: draft.bedrooms,
      bathrooms: draft.bathrooms,
      toilets: draft.toilets,
      kitchens: draft.kitchens,
      parkingSpaces: draft.parkingSpaces,
      floors: draft.floors,
      landSizeSqm: (draft.landSizeSqm ?? 0) > 0 ? draft.landSizeSqm : null,
      buildingSizeSqm:
          (draft.builtUpAreaSqm ?? 0) > 0 ? draft.builtUpAreaSqm : null,
      yearBuilt: draft.yearBuilt.trim(),
      powerSupply: draft.powerSupply.trim(),
      waterSupply: draft.waterSupply.trim(),
      internetConnectivity: draft.internetConnectivity.trim(),
      architecturalConcept: draft.architecturalConcept.trim(),
      investmentPotential: draft.investmentPotential.trim(),
      listingPrice: (draft.listingPrice ?? 0) > 0 ? draft.listingPrice : null,
      promoPrice: (draft.promoPrice ?? 0) > 0 ? draft.promoPrice : null,
      investorPrice:
          (draft.investorPrice ?? 0) > 0 ? draft.investorPrice : null,
      rentalPrice: (draft.rentalPrice ?? 0) > 0 ? draft.rentalPrice : null,
      homepageBadge: draft.inventoryStatus.label,
      priceLabel: priceLabel,
      marketingStatus: draft.marketingStatus.slug,
      inventoryStatus: draft.inventoryStatus.slug,
      publishWorkflowStatus: draft.publishStatus.slug,
      amenities: draft.amenities,
      detailExtras: extras,
      featureAndPublish: published && featured,
    );

    if (published && !featured) {
      await cms.setPropertyPublished(saved.id, true);
    } else if (!published && featured) {
      await cms.setPropertyFeatured(saved.id, true);
    }
  }

  final startOrder = draft.existingGalleryUrls.length;
  for (var i = 0; i < draft.mediaFiles.length; i++) {
    final file = draft.mediaFiles[i];
    await cms.uploadPropertyGalleryImage(
      propertyId: saved.id,
      bytes: file.bytes,
      contentType: file.contentType,
      asCover: file.isCover ||
          (draft.existingGalleryUrls.isEmpty && i == 0),
      sortOrder: startOrder + i,
    );
  }

  final hasPendingAssets = draft.pendingDocumentFiles.any((e) => e != null) ||
      draft.pendingFloorPlanFiles.any((e) => e != null) ||
      draft.pendingVideoTour != null ||
      draft.pendingDroneTour != null;

  if (hasPendingAssets) {
    final resolved = await _resolvePendingAssetUploads(
      cms: cms,
      propertyId: saved.id,
      draft: draft,
      extras: extras,
    );
    await cms.upsertPropertyBasic(
      id: saved.id,
      title: title,
      slug: slug,
      detailExtras: resolved,
    );
  }

  return saved;
}

/// Creates a CMS draft property if the wizard has no [PmsWizardDraft.existingId]
/// yet, so gallery uploads can attach immediately.
Future<PmsWizardDraft> ensureWizardDraftProperty({
  required CmsService cms,
  required PmsWizardDraft draft,
}) async {
  if (draft.existingId != null && draft.existingId!.trim().isNotEmpty) {
    return draft;
  }
  final saved = await persistWizardDraft(cms: cms, draft: draft);
  return wizardDraftFromCms(saved).copyWith(
    mediaFiles: draft.mediaFiles,
    pendingDocumentFiles: draft.pendingDocumentFiles,
    pendingFloorPlanFiles: draft.pendingFloorPlanFiles,
    pendingVideoTour: draft.pendingVideoTour,
    pendingDroneTour: draft.pendingDroneTour,
    mediaNote: draft.mediaNote,
  );
}

Future<PropertyDetailExtras> _resolvePendingAssetUploads({
  required CmsService cms,
  required String propertyId,
  required PmsWizardDraft draft,
  required PropertyDetailExtras extras,
}) async {
  final docs = [...extras.documents];
  final plans = [...extras.floorPlans];
  var videoUrl = extras.videoTourUrl;
  var droneUrl = extras.droneTourUrl;

  for (var i = 0; i < docs.length; i++) {
    final pending = i < draft.pendingDocumentFiles.length
        ? draft.pendingDocumentFiles[i]
        : null;
    if (pending == null) continue;
    final url = await cms.uploadPropertyPublicAsset(
      propertyId: propertyId,
      bytes: pending.bytes,
      contentType: pending.contentType,
      fileName: pending.name,
    );
    final title = docs[i].title.trim().isEmpty ? pending.name : docs[i].title;
    final type = pending.contentType.contains('pdf')
        ? 'PDF'
        : (docs[i].type.trim().isEmpty ? 'File' : docs[i].type);
    docs[i] = ExtrasDocument(title: title, type: type, url: url);
  }

  for (var i = 0; i < plans.length; i++) {
    final pending = i < draft.pendingFloorPlanFiles.length
        ? draft.pendingFloorPlanFiles[i]
        : null;
    if (pending == null) continue;
    final url = await cms.uploadPropertyPublicAsset(
      propertyId: propertyId,
      bytes: pending.bytes,
      contentType: pending.contentType,
      fileName: pending.name,
    );
    final label =
        plans[i].label.trim().isEmpty ? pending.name : plans[i].label;
    plans[i] = ExtrasFloorPlan(
      label: label,
      dimensions: plans[i].dimensions,
      downloadUrl: url,
    );
  }

  final video = draft.pendingVideoTour;
  if (video != null) {
    videoUrl = await cms.uploadPropertyPublicAsset(
      propertyId: propertyId,
      bytes: video.bytes,
      contentType: video.contentType,
      fileName: video.name,
    );
  }

  final drone = draft.pendingDroneTour;
  if (drone != null) {
    droneUrl = await cms.uploadPropertyPublicAsset(
      propertyId: propertyId,
      bytes: drone.bytes,
      contentType: drone.contentType,
      fileName: drone.name,
    );
  }

  return extras.copyWith(
    documents: docs,
    floorPlans: plans,
    videoTourUrl: videoUrl,
    droneTourUrl: droneUrl,
  );
}
