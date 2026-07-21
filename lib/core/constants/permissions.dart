/// Permission slugs — must match Supabase `permissions` table.
abstract final class PermissionSlugs {
  static const viewProperties = 'view_properties';
  static const createProperty = 'create_property';
  static const editProperty = 'edit_property';
  static const deleteProperty = 'delete_property';
  static const publishProperty = 'publish_property';
  static const manageUsers = 'manage_users';
  static const manageRoles = 'manage_roles';
  static const managePayments = 'manage_payments';
  static const manageBlog = 'manage_blog';
  static const manageMarketing = 'manage_marketing';
  static const manageConstruction = 'manage_construction';
  static const manageCrm = 'manage_crm';
  static const manageReports = 'manage_reports';
  static const manageSettings = 'manage_settings';
  static const viewExecutiveDashboard = 'view_executive_dashboard';
  static const customizeDashboard = 'customize_dashboard';
  static const generateExecutiveReports = 'generate_executive_reports';
  static const viewBusinessHealth = 'view_business_health';

  static const propertiesRead = 'properties.read';
  static const propertiesWrite = 'properties.write';
  static const propertiesApprove = 'properties.approve';
  static const propertiesMedia = 'properties.media';
  static const propertiesDocuments = 'properties.documents';
  static const propertiesPricing = 'properties.pricing';
  static const propertiesInspections = 'properties.inspections';
  static const propertiesOwnership = 'properties.ownership';
  static const propertiesAnalytics = 'properties.analytics';
  static const propertiesBulk = 'properties.bulk';
  static const propertiesAi = 'properties.ai';

  static const crmRead = 'crm.read';
  static const crmWrite = 'crm.write';
  static const crmLeads = 'crm.leads';
  static const crmPipeline = 'crm.pipeline';
  static const crmTasks = 'crm.tasks';
  static const crmCommunications = 'crm.communications';
  static const crmDocuments = 'crm.documents';
  static const crmAnalytics = 'crm.analytics';
  static const crmAi = 'crm.ai';
  static const crmAssign = 'crm.assign';

  static const investorsRead = 'investors.read';
  static const investorsWrite = 'investors.write';
  static const investorsOpportunities = 'investors.opportunities';
  static const investorsPortfolio = 'investors.portfolio';
  static const investorsDistributions = 'investors.distributions';
  static const investorsDocuments = 'investors.documents';
  static const investorsAnalytics = 'investors.analytics';
  static const investorsAi = 'investors.ai';
  static const investorsAssign = 'investors.assign';
  static const investorsKyc = 'investors.kyc';

  static const salesRead = 'sales.read';
  static const salesWrite = 'sales.write';
  static const salesReservations = 'sales.reservations';
  static const salesBookings = 'sales.bookings';
  static const salesQuotes = 'sales.quotes';
  static const salesContracts = 'sales.contracts';
  static const salesCommissions = 'sales.commissions';
  static const salesApprovals = 'sales.approvals';
  static const salesAnalytics = 'sales.analytics';
  static const salesAi = 'sales.ai';

  static const constructionRead = 'construction.read';
  static const constructionWrite = 'construction.write';
  static const constructionProjects = 'construction.projects';
  static const constructionMilestones = 'construction.milestones';
  static const constructionTasks = 'construction.tasks';
  static const constructionProcurement = 'construction.procurement';
  static const constructionBudget = 'construction.budget';
  static const constructionQuality = 'construction.quality';
  static const constructionSafety = 'construction.safety';
  static const constructionAnalytics = 'construction.analytics';
  static const constructionAi = 'construction.ai';
  static const constructionApprovals = 'construction.approvals';

  static const financeRead = 'finance.read';
  static const financeWrite = 'finance.write';
  static const financeLedger = 'finance.ledger';
  static const financeInvoices = 'finance.invoices';
  static const financePayments = 'finance.payments';
  static const financeBanking = 'finance.banking';
  static const financeBudgets = 'finance.budgets';
  static const financeExpenses = 'finance.expenses';
  static const financeApprovals = 'finance.approvals';
  static const financeAnalytics = 'finance.analytics';
  static const financeAi = 'finance.ai';
  static const financeTax = 'finance.tax';

  static const marketingRead = 'marketing.read';
  static const marketingWrite = 'marketing.write';
  static const marketingCms = 'marketing.cms';
  static const marketingCampaigns = 'marketing.campaigns';
  static const marketingMedia = 'marketing.media';
  static const marketingSeo = 'marketing.seo';
  static const marketingForms = 'marketing.forms';
  static const marketingAnalytics = 'marketing.analytics';
  static const marketingAi = 'marketing.ai';
  static const marketingPublish = 'marketing.publish';
  static const marketingSocial = 'marketing.social';

  static const hrRead = 'hr.read';
  static const hrWrite = 'hr.write';
  static const hrEmployees = 'hr.employees';
  static const hrRecruitment = 'hr.recruitment';
  static const hrAttendance = 'hr.attendance';
  static const hrLeave = 'hr.leave';
  static const hrPerformance = 'hr.performance';
  static const hrPayroll = 'hr.payroll';
  static const hrAnalytics = 'hr.analytics';
  static const hrAi = 'hr.ai';
  static const hrApprovals = 'hr.approvals';
  static const hrAssets = 'hr.assets';

  static const eocRead = 'eoc.read';
  static const eocWrite = 'eoc.write';
  static const eocKpis = 'eoc.kpis';
  static const eocSearch = 'eoc.search';
  static const eocAi = 'eoc.ai';
  static const eocWorkflows = 'eoc.workflows';
  static const eocApprovals = 'eoc.approvals';
  static const eocAlerts = 'eoc.alerts';
  static const eocTasks = 'eoc.tasks';
  static const eocMeetings = 'eoc.meetings';
  static const eocReports = 'eoc.reports';
  static const eocAnalytics = 'eoc.analytics';
  static const eocAudit = 'eoc.audit';

  static const supportRead = 'support.read';
  static const supportWrite = 'support.write';
  static const supportTickets = 'support.tickets';
  static const supportInbox = 'support.inbox';
  static const supportChat = 'support.chat';
  static const supportEmail = 'support.email';
  static const supportWhatsapp = 'support.whatsapp';
  static const supportKnowledge = 'support.knowledge';
  static const supportSla = 'support.sla';
  static const supportEscalations = 'support.escalations';
  static const supportAnalytics = 'support.analytics';
  static const supportAi = 'support.ai';
  static const supportReports = 'support.reports';

  static const documentsRead = 'documents.read';
  static const documentsWrite = 'documents.write';
  static const documentsUpload = 'documents.upload';
  static const documentsApprove = 'documents.approve';
  static const documentsContracts = 'documents.contracts';
  static const documentsSignatures = 'documents.signatures';
  static const documentsDam = 'documents.dam';
  static const documentsShare = 'documents.share';
  static const documentsArchive = 'documents.archive';
  static const documentsRetention = 'documents.retention';
  static const documentsAi = 'documents.ai';
  static const documentsAnalytics = 'documents.analytics';
  static const documentsReports = 'documents.reports';
  static const documentsAdmin = 'documents.admin';

  static const procurementRead = 'procurement.read';
  static const procurementWrite = 'procurement.write';
  static const procurementVendors = 'procurement.vendors';
  static const procurementRequisitions = 'procurement.requisitions';
  static const procurementRfq = 'procurement.rfq';
  static const procurementOrders = 'procurement.orders';
  static const procurementReceiving = 'procurement.receiving';
  static const procurementInventory = 'procurement.inventory';
  static const procurementWarehouse = 'procurement.warehouse';
  static const procurementLogistics = 'procurement.logistics';
  static const procurementApprovals = 'procurement.approvals';
  static const procurementAnalytics = 'procurement.analytics';
  static const procurementAi = 'procurement.ai';
  static const procurementReports = 'procurement.reports';

  static const assetsRead = 'assets.read';
  static const assetsWrite = 'assets.write';
  static const assetsRegister = 'assets.register';
  static const assetsAssign = 'assets.assign';
  static const assetsMaintenance = 'assets.maintenance';
  static const assetsWorkorders = 'assets.workorders';
  static const assetsInspections = 'assets.inspections';
  static const assetsFleet = 'assets.fleet';
  static const assetsFacilities = 'assets.facilities';
  static const assetsUtilities = 'assets.utilities';
  static const assetsDepreciation = 'assets.depreciation';
  static const assetsApprovals = 'assets.approvals';
  static const assetsAnalytics = 'assets.analytics';
  static const assetsAi = 'assets.ai';
  static const assetsReports = 'assets.reports';

  static const grcRead = 'grc.read';
  static const grcWrite = 'grc.write';
  static const grcRisks = 'grc.risks';
  static const grcCompliance = 'grc.compliance';
  static const grcPolicies = 'grc.policies';
  static const grcAudit = 'grc.audit';
  static const grcLegal = 'grc.legal';
  static const grcEthics = 'grc.ethics';
  static const grcInvestigations = 'grc.investigations';
  static const grcBoard = 'grc.board';
  static const grcBcm = 'grc.bcm';
  static const grcApprovals = 'grc.approvals';
  static const grcAnalytics = 'grc.analytics';
  static const grcAi = 'grc.ai';
  static const grcReports = 'grc.reports';

  static const analyticsRead = 'analytics.read';
  static const analyticsWrite = 'analytics.write';
  static const analyticsWarehouse = 'analytics.warehouse';
  static const analyticsEtl = 'analytics.etl';
  static const analyticsKpis = 'analytics.kpis';
  static const analyticsDashboards = 'analytics.dashboards';
  static const analyticsReports = 'analytics.reports';
  static const analyticsForecasts = 'analytics.forecasts';
  static const analyticsGovernance = 'analytics.governance';
  static const analyticsQuality = 'analytics.quality';
  static const analyticsAi = 'analytics.ai';
  static const analyticsSchedule = 'analytics.schedule';
  static const analyticsAdmin = 'analytics.admin';

  static const aihubRead = 'aihub.read';
  static const aihubWrite = 'aihub.write';
  static const aihubCopilots = 'aihub.copilots';
  static const aihubModels = 'aihub.models';
  static const aihubPredictions = 'aihub.predictions';
  static const aihubRecommendations = 'aihub.recommendations';
  static const aihubSearch = 'aihub.search';
  static const aihubRag = 'aihub.rag';
  static const aihubAutomation = 'aihub.automation';
  static const aihubGovernance = 'aihub.governance';
  static const aihubObservability = 'aihub.observability';
  static const aihubApprovals = 'aihub.approvals';
  static const aihubAnalytics = 'aihub.analytics';
  static const aihubAdmin = 'aihub.admin';

  static const integrationRead = 'integration.read';
  static const integrationWrite = 'integration.write';
  static const integrationApis = 'integration.apis';
  static const integrationWorkflows = 'integration.workflows';
  static const integrationEvents = 'integration.events';
  static const integrationWebhooks = 'integration.webhooks';
  static const integrationQueues = 'integration.queues';
  static const integrationConnectors = 'integration.connectors';
  static const integrationSecurity = 'integration.security';
  static const integrationMonitoring = 'integration.monitoring';
  static const integrationAi = 'integration.ai';
  static const integrationAdmin = 'integration.admin';

  static const List<String> all = [
    viewProperties,
    createProperty,
    editProperty,
    deleteProperty,
    publishProperty,
    manageUsers,
    manageRoles,
    managePayments,
    manageBlog,
    manageMarketing,
    manageConstruction,
    manageCrm,
    manageReports,
    manageSettings,
    viewExecutiveDashboard,
    customizeDashboard,
    generateExecutiveReports,
    viewBusinessHealth,
    propertiesRead,
    propertiesWrite,
    propertiesApprove,
    propertiesMedia,
    propertiesDocuments,
    propertiesPricing,
    propertiesInspections,
    propertiesOwnership,
    propertiesAnalytics,
    propertiesBulk,
    propertiesAi,
    crmRead,
    crmWrite,
    crmLeads,
    crmPipeline,
    crmTasks,
    crmCommunications,
    crmDocuments,
    crmAnalytics,
    crmAi,
    crmAssign,
    investorsRead,
    investorsWrite,
    investorsOpportunities,
    investorsPortfolio,
    investorsDistributions,
    investorsDocuments,
    investorsAnalytics,
    investorsAi,
    investorsAssign,
    investorsKyc,
    salesRead,
    salesWrite,
    salesReservations,
    salesBookings,
    salesQuotes,
    salesContracts,
    salesCommissions,
    salesApprovals,
    salesAnalytics,
    salesAi,
    constructionRead,
    constructionWrite,
    constructionProjects,
    constructionMilestones,
    constructionTasks,
    constructionProcurement,
    constructionBudget,
    constructionQuality,
    constructionSafety,
    constructionAnalytics,
    constructionAi,
    constructionApprovals,
    financeRead,
    financeWrite,
    financeLedger,
    financeInvoices,
    financePayments,
    financeBanking,
    financeBudgets,
    financeExpenses,
    financeApprovals,
    financeAnalytics,
    financeAi,
    financeTax,
    marketingRead,
    marketingWrite,
    marketingCms,
    marketingCampaigns,
    marketingMedia,
    marketingSeo,
    marketingForms,
    marketingAnalytics,
    marketingAi,
    marketingPublish,
    marketingSocial,
    hrRead,
    hrWrite,
    hrEmployees,
    hrRecruitment,
    hrAttendance,
    hrLeave,
    hrPerformance,
    hrPayroll,
    hrAnalytics,
    hrAi,
    hrApprovals,
    hrAssets,
    eocRead,
    eocWrite,
    eocKpis,
    eocSearch,
    eocAi,
    eocWorkflows,
    eocApprovals,
    eocAlerts,
    eocTasks,
    eocMeetings,
    eocReports,
    eocAnalytics,
    eocAudit,
    supportRead,
    supportWrite,
    supportTickets,
    supportInbox,
    supportChat,
    supportEmail,
    supportWhatsapp,
    supportKnowledge,
    supportSla,
    supportEscalations,
    supportAnalytics,
    supportAi,
    supportReports,
    documentsRead,
    documentsWrite,
    documentsUpload,
    documentsApprove,
    documentsContracts,
    documentsSignatures,
    documentsDam,
    documentsShare,
    documentsArchive,
    documentsRetention,
    documentsAi,
    documentsAnalytics,
    documentsReports,
    documentsAdmin,
    procurementRead,
    procurementWrite,
    procurementVendors,
    procurementRequisitions,
    procurementRfq,
    procurementOrders,
    procurementReceiving,
    procurementInventory,
    procurementWarehouse,
    procurementLogistics,
    procurementApprovals,
    procurementAnalytics,
    procurementAi,
    procurementReports,
    assetsRead,
    assetsWrite,
    assetsRegister,
    assetsAssign,
    assetsMaintenance,
    assetsWorkorders,
    assetsInspections,
    assetsFleet,
    assetsFacilities,
    assetsUtilities,
    assetsDepreciation,
    assetsApprovals,
    assetsAnalytics,
    assetsAi,
    assetsReports,
    grcRead,
    grcWrite,
    grcRisks,
    grcCompliance,
    grcPolicies,
    grcAudit,
    grcLegal,
    grcEthics,
    grcInvestigations,
    grcBoard,
    grcBcm,
    grcApprovals,
    grcAnalytics,
    grcAi,
    grcReports,
    analyticsRead,
    analyticsWrite,
    analyticsWarehouse,
    analyticsEtl,
    analyticsKpis,
    analyticsDashboards,
    analyticsReports,
    analyticsForecasts,
    analyticsGovernance,
    analyticsQuality,
    analyticsAi,
    analyticsSchedule,
    analyticsAdmin,
    aihubRead,
    aihubWrite,
    aihubCopilots,
    aihubModels,
    aihubPredictions,
    aihubRecommendations,
    aihubSearch,
    aihubRag,
    aihubAutomation,
    aihubGovernance,
    aihubObservability,
    aihubApprovals,
    aihubAnalytics,
    aihubAdmin,
    integrationRead,
    integrationWrite,
    integrationApis,
    integrationWorkflows,
    integrationEvents,
    integrationWebhooks,
    integrationQueues,
    integrationConnectors,
    integrationSecurity,
    integrationMonitoring,
    integrationAi,
    integrationAdmin,
  ];
}
