// Careers Hub CMS models (Supabase wired in Volume 1.5).

enum CareerDepartment {
  sales,
  construction,
  design,
  marketing,
  finance,
  technology,
  operations,
  legal,
}

enum CareerEmploymentType {
  fullTime,
  partTime,
  contract,
  internship,
}

class CareerValue {
  const CareerValue({
    required this.title,
    required this.description,
    required this.iconName,
  });

  final String title;
  final String description;
  final String iconName;
}

class CareerBenefit {
  const CareerBenefit({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;
}

class CareerJob {
  const CareerJob({
    required this.id,
    required this.title,
    required this.department,
    required this.location,
    required this.employmentType,
    required this.summary,
    required this.responsibilities,
    required this.requirements,
    this.salaryRange,
    this.featured = false,
  });

  final String id;
  final String title;
  final CareerDepartment department;
  final String location;
  final CareerEmploymentType employmentType;
  final String summary;
  final List<String> responsibilities;
  final List<String> requirements;
  final String? salaryRange;
  final bool featured;
}

class CareerTestimonial {
  const CareerTestimonial({
    required this.name,
    required this.role,
    required this.quote,
  });

  final String name;
  final String role;
  final String quote;
}

class CareerFaq {
  const CareerFaq({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;
}

class CareersHubCms {
  const CareersHubCms({
    required this.heroHeadline,
    required this.heroSubheadline,
    required this.values,
    required this.benefits,
    required this.jobs,
    required this.cultureSummary,
    required this.testimonials,
    required this.faqs,
    required this.openPositionsCount,
  });

  final String heroHeadline;
  final String heroSubheadline;
  final List<CareerValue> values;
  final List<CareerBenefit> benefits;
  final List<CareerJob> jobs;
  final String cultureSummary;
  final List<CareerTestimonial> testimonials;
  final List<CareerFaq> faqs;
  final int openPositionsCount;
}

extension CareerDepartmentLabel on CareerDepartment {
  String get label => switch (this) {
        CareerDepartment.sales => 'Sales',
        CareerDepartment.construction => 'Construction',
        CareerDepartment.design => 'Design',
        CareerDepartment.marketing => 'Marketing',
        CareerDepartment.finance => 'Finance',
        CareerDepartment.technology => 'Technology',
        CareerDepartment.operations => 'Operations',
        CareerDepartment.legal => 'Legal',
      };
}

extension CareerEmploymentTypeLabel on CareerEmploymentType {
  String get label => switch (this) {
        CareerEmploymentType.fullTime => 'Full-time',
        CareerEmploymentType.partTime => 'Part-time',
        CareerEmploymentType.contract => 'Contract',
        CareerEmploymentType.internship => 'Internship',
      };
}
