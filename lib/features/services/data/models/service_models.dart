// Services CMS models (Supabase wired in Volume 1.5).

enum ServiceCategoryId {
  realEstate,
  construction,
  designPlanning,
  propertyManagement,
  professionalServices,
}

extension ServiceCategoryIdLabel on ServiceCategoryId {
  String get label => switch (this) {
        ServiceCategoryId.realEstate => 'Real Estate',
        ServiceCategoryId.construction => 'Construction',
        ServiceCategoryId.designPlanning => 'Design & Planning',
        ServiceCategoryId.propertyManagement => 'Property Management',
        ServiceCategoryId.professionalServices => 'Professional Services',
      };

  String get slug => switch (this) {
        ServiceCategoryId.realEstate => 'real-estate',
        ServiceCategoryId.construction => 'construction',
        ServiceCategoryId.designPlanning => 'design-planning',
        ServiceCategoryId.propertyManagement => 'property-management',
        ServiceCategoryId.professionalServices => 'professional-services',
      };
}

enum ServiceBadge { featured, popular, newService }

class ServiceCategory {
  const ServiceCategory({
    required this.id,
    required this.description,
    required this.iconName,
  });

  final ServiceCategoryId id;
  final String description;
  final String iconName;
}

class ServiceSummary {
  const ServiceSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.shortDescription,
    required this.categoryId,
    required this.iconName,
    this.badges = const [],
    this.keyBenefits = const [],
    this.isFeatured = false,
  });

  final String id;
  final String slug;
  final String name;
  final String shortDescription;
  final ServiceCategoryId categoryId;
  final String iconName;
  final List<ServiceBadge> badges;
  final List<String> keyBenefits;
  final bool isFeatured;
}

class ServicesPageCms {
  const ServicesPageCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.categories,
    required this.whyChoose,
    required this.processSteps,
    required this.caseStudies,
    required this.technologies,
    required this.industries,
    required this.testimonials,
    required this.faqs,
    required this.knowledgeArticles,
    required this.experts,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<ServiceCategory> categories;
  final List<ServiceWhyChooseItem> whyChoose;
  final List<String> processSteps;
  final List<ServiceCaseStudy> caseStudies;
  final List<ServiceTechnology> technologies;
  final List<ServiceIndustry> industries;
  final List<ServiceTestimonial> testimonials;
  final List<ServiceFaqItem> faqs;
  final List<ServiceKnowledgeArticle> knowledgeArticles;
  final List<ServiceExpert> experts;
}

class ServiceWhyChooseItem {
  const ServiceWhyChooseItem({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class ServiceCaseStudy {
  const ServiceCaseStudy({
    required this.client,
    required this.service,
    required this.challenge,
    required this.solution,
    required this.results,
    required this.serviceSlug,
  });

  final String client;
  final String service;
  final String challenge;
  final String solution;
  final String results;
  final String serviceSlug;
}

class ServiceTechnology {
  const ServiceTechnology({required this.name, required this.description, required this.iconName});

  final String name;
  final String description;
  final String iconName;
}

class ServiceIndustry {
  const ServiceIndustry({required this.name, required this.description, required this.iconName});

  final String name;
  final String description;
  final String iconName;
}

class ServiceTestimonial {
  const ServiceTestimonial({
    required this.name,
    required this.role,
    required this.comment,
    required this.rating,
    required this.verified,
    required this.serviceSlug,
  });

  final String name;
  final String role;
  final String comment;
  final double rating;
  final bool verified;
  final String serviceSlug;
}

class ServiceFaqItem {
  const ServiceFaqItem({required this.question, required this.answer, this.category});

  final String question;
  final String answer;
  final String? category;
}

class ServiceKnowledgeArticle {
  const ServiceKnowledgeArticle({
    required this.title,
    required this.excerpt,
    required this.category,
    required this.readMinutes,
  });

  final String title;
  final String excerpt;
  final String category;
  final int readMinutes;
}

class ServiceExpert {
  const ServiceExpert({
    required this.name,
    required this.department,
    required this.isOnline,
    required this.responseTime,
    required this.specializations,
  });

  final String name;
  final String department;
  final bool isOnline;
  final String responseTime;
  final List<String> specializations;
}

class ServiceDetailContent {
  const ServiceDetailContent({
    required this.summary,
    required this.overview,
    required this.audience,
    required this.businessValue,
    required this.benefits,
    required this.processSteps,
    required this.deliverables,
    required this.pricing,
    required this.gallery,
    required this.relatedProjects,
    required this.faqs,
    required this.aiRecommendations,
    required this.eligibilityQuestions,
  });

  final ServiceSummary summary;
  final String overview;
  final String audience;
  final String businessValue;
  final List<String> benefits;
  final List<ServiceProcessStep> processSteps;
  final List<String> deliverables;
  final ServicePricing? pricing;
  final ServiceGallery gallery;
  final List<ServiceRelatedProject> relatedProjects;
  final List<ServiceFaqItem> faqs;
  final List<String> aiRecommendations;
  final List<ServiceEligibilityQuestion> eligibilityQuestions;
}

class ServiceProcessStep {
  const ServiceProcessStep({required this.title, required this.description});

  final String title;
  final String description;
}

class ServicePricing {
  const ServicePricing({
    required this.label,
    required this.startingPrice,
    required this.pricingType,
    required this.note,
  });

  final String label;
  final String startingPrice;
  final String pricingType;
  final String note;
}

class ServiceGallery {
  const ServiceGallery({required this.images, required this.hasVideo, required this.hasBeforeAfter});

  final List<String> images;
  final bool hasVideo;
  final bool hasBeforeAfter;
}

class ServiceRelatedProject {
  const ServiceRelatedProject({
    required this.name,
    required this.location,
    required this.outcome,
  });

  final String name;
  final String location;
  final String outcome;
}

class ServiceEligibilityQuestion {
  const ServiceEligibilityQuestion({
    required this.question,
    required this.options,
    required this.recommendedServiceSlugs,
  });

  final String question;
  final List<String> options;
  final Map<String, List<String>> recommendedServiceSlugs;
}

class ProjectEstimateResult {
  const ProjectEstimateResult({
    required this.costRange,
    required this.duration,
    required this.suggestedServices,
    required this.consultationNote,
  });

  final String costRange;
  final String duration;
  final List<String> suggestedServices;
  final String consultationNote;
}

class EligibilityResult {
  const EligibilityResult({
    required this.suitableServices,
    required this.readiness,
    required this.documentsRequired,
    required this.budgetFit,
    required this.nextSteps,
  });

  final List<String> suitableServices;
  final String readiness;
  final List<String> documentsRequired;
  final String budgetFit;
  final List<String> nextSteps;
}
