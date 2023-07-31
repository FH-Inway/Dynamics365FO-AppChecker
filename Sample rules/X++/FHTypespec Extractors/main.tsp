import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/http";

using TypeSpec.Http;

@service({
  title: "Microsoft Dynamics 365 Finance and Operations Custom Services API2",
  version: "0.0.1.20230730",
})
@server(
  "https://usnconeboxax1aos.cloud.onebox.dynamics.com/api/services",
  "Microsoft Dynamics 365 Finance and Operations Local OneBox Environment"
)
namespace Microsoft.Dynamics.Services;

@route("/TSTimesheetServices")
@tag("/TSTimesheetServices")
namespace TSTimesheetServices {
  @route("/TSTimesheetSubmissionService")
  namespace TSTimesheetSubmissionService {
    @route("/getTimesheetSettingsForCurrentUser")
    @get
    op getTimesheetSettingsForCurrentUser(): void;

    @route("/createNewTimesheet")
    @get
    op createNewTimesheet(): void;

    @route("/findOrCreateTimesheet")
    @get
    op findOrCreateTimesheet(): void;

    @route("/createOrUpdateTimesheetLine")
    @get
    op createOrUpdateTimesheetLine(): void;

    @route("/deleteTimesheetLine")
    @get
    op deleteTimesheetLine(): void;

    @route("/deleteTimesheets")
    @get
    op deleteTimesheets(): void;

    @route("/getTimesheetDetailsByNumber")
    @get
    op getTimesheetDetailsByNumber(): void;

    @route("/getTimesheetSummary")
    @get
    op getTimesheetSummary(): void;

    @route("/getCompletedTimesheets")
    @get
    op getCompletedTimesheets(): void;

    @route("/getLegalEntityReferenceInformation")
    @get
    op getLegalEntityReferenceInformation(): void;

    @route("/getRecentAndAssignedProjects")
    @get
    op getRecentAndAssignedProjects(): void;

    @route("/getProjectDetailsSearch")
    @get
    op getProjectDetailsSearch(): void;

    @route("/submitTimesheet")
    @get
    op submitTimesheet(): void;

    @route("/recallTimesheet")
    @get
    op recallTimesheet(): void;

    @route("/getLabelTranslations")
    @get
    op getLabelTranslations(): void;

    @route("/saveTimesheetLinesAsFavorite")
    @get
    op saveTimesheetLinesAsFavorite(): void;

    @route("/copyLinesFromFavorites")
    @get
    op copyLinesFromFavorites(): void;

    @route("/copyLinesFromAssignments")
    @get
    op copyLinesFromAssignments(): void;

    @route("/copyLinesFromTimesheet")
    @get
    op copyLinesFromTimesheet(): void;

    @route("/getProjectDetailsByProjId")
    @get
    op getProjectDetailsByProjId(): void;

    @route("/getServerVersion")
    @get
    op getServerVersion(): void;
  }

  @route("/TSTimesheetApprovalService")
  namespace TSTimesheetApprovalService {
    @route("/getTimesheetsForMyApproval")
    @get
    op getTimesheetsForMyApproval(): void;

    @route("/getTimesheetDetailsForMyApproval")
    @get
    op getTimesheetDetailsForMyApproval(): void;

    @route("/approveTimesheets")
    @get
    op approveTimesheets(): void;

    @route("/approveTimesheetLines")
    @get
    op approveTimesheetLines(): void;

    @route("/rejectTimesheets")
    @get
    op rejectTimesheets(): void;

    @route("/rejectTimesheetLines")
    @get
    op rejectTimesheetLines(): void;

    @route("/delegateTimesheets")
    @get
    op delegateTimesheets(): void;

    @route("/delegateTimesheetLines")
    @get
    op delegateTimesheetLines(): void;

    @route("/getDelegatesForApproval")
    @get
    op getDelegatesForApproval(): void;

    @route("/getDelegatesForLineApproval")
    @get
    op getDelegatesForLineApproval(): void;
  }
}
