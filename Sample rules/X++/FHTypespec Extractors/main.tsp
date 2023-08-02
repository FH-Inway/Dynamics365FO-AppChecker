import "@typespec/rest";
import "@typespec/openapi3";
import "@typespec/http";

using TypeSpec.Http;

@service({
  title: "Microsoft Dynamics 365 Finance and Operations Custom Services API3",
  version: "0.0.1.20230730",
})
@server(
  "https://usnconeboxax1aos.cloud.onebox.dynamics.com/api/services",
  "Microsoft Dynamics 365 Finance and Operations Local OneBox Environment"
)
namespace Microsoft.Dynamics.Services;

@route("/TSTimesheetServices")
//@tag("/TSTimesheetServices")
namespace TSTimesheetServices {
  @route("/TSTimesheetSubmissionService")
  @tag("/TSTimesheetSubmissionService")
  namespace TSTimesheetSubmissionService {
    @route("/getTimesheetSettingsForCurrentUser")
    @post
    op getTimesheetSettingsForCurrentUser(): void;

    @route("/createNewTimesheet")
    @post
    op createNewTimesheet(_resource: int64, _timesheetDate: utcDateTime): void;

    @route("/findOrCreateTimesheet")
    @post
    op findOrCreateTimesheet(
      _resource: int64,
      _timesheetDate: utcDateTime,
    ): void;

    @route("/createOrUpdateTimesheetLine")
    @post
    op createOrUpdateTimesheetLine(_tsTimesheetEntryList: unknown): void;

    @route("/deleteTimesheetLine")
    @post
    op deleteTimesheetLine(_resource: int64, _timesheetLineRecId: int64): void;

    @route("/deleteTimesheets")
    @post
    op deleteTimesheets(_resource: int64, _timesheetNbrs: unknown): void;

    @route("/getTimesheetDetailsByNumber")
    @post
    op getTimesheetDetailsByNumber(
      _resource: int64,
      _timesheetNumber: string,
    ): void;

    @route("/getTimesheetSummary")
    @post
    op getTimesheetSummary(_resource: int64): void;

    @route("/getCompletedTimesheets")
    @post
    op getCompletedTimesheets(_numOfTimesheets: int32, _resource: int64): void;

    @route("/getLegalEntityReferenceInformation")
    @post
    op getLegalEntityReferenceInformation(_resource: int64): void;

    @route("/getRecentAndAssignedProjects")
    @post
    op getRecentAndAssignedProjects(
      _legalEntity: string,
      _resource: int64,
      _timeEntryDate: utcDateTime,
    ): void;

    @route("/getProjectDetailsSearch")
    @post
    op getProjectDetailsSearch(
      _legalEntity: string,
      _resource: int64,
      _searchString: string,
    ): void;

    @route("/submitTimesheet")
    @post
    op submitTimesheet(_comment: string, _recId: int64, _resource: int64): void;

    @route("/recallTimesheet")
    @post
    op recallTimesheet(_comment: string, _recId: int64, _resource: int64): void;

    @route("/getLabelTranslations")
    @post
    op getLabelTranslations(
      _labelsToTranslate: unknown,
      _language: string,
    ): void;

    @route("/saveTimesheetLinesAsFavorite")
    @post
    op saveTimesheetLinesAsFavorite(_tsTimesheetEntryList: unknown): void;

    @route("/copyLinesFromFavorites")
    @post
    op copyLinesFromFavorites(
      _entryDate: utcDateTime,
      _resource: int64,
      _timesheetTo: string,
    ): void;

    @route("/copyLinesFromAssignments")
    @post
    op copyLinesFromAssignments(
      _entryDate: utcDateTime,
      _resource: int64,
      _timesheetTo: string,
    ): void;

    @route("/copyLinesFromTimesheet")
    @post
    op copyLinesFromTimesheet(
      _resource: int64,
      _timesheetFrom: string,
      _timesheetTo: string,
    ): void;

    @route("/getProjectDetailsByProjId")
    @post
    op getProjectDetailsByProjId(
      _legalEntity: string,
      _projId: string,
      _resource: int64,
    ): void;

    @route("/getServerVersion")
    @post
    op getServerVersion(): void;
  }

  @route("/TSTimesheetApprovalService")
  @tag("/TSTimesheetApprovalService")
  namespace TSTimesheetApprovalService {
    @route("/getTimesheetsForMyApproval")
    @post
    op getTimesheetsForMyApproval(): void;

    @route("/getTimesheetDetailsForMyApproval")
    @post
    op getTimesheetDetailsForMyApproval(_recId: int64): void;

    @route("/approveTimesheets")
    @post
    op approveTimesheets(_comment: string, _timesheetRecIds: unknown): void;

    @route("/approveTimesheetLines")
    @post
    op approveTimesheetLines(
      _comment: string,
      _timesheetLineRecIds: unknown,
    ): void;

    @route("/rejectTimesheets")
    @post
    op rejectTimesheets(_comment: string, _timesheetRecIds: unknown): void;

    @route("/rejectTimesheetLines")
    @post
    op rejectTimesheetLines(
      _comment: string,
      _timesheetLineRecIds: unknown,
    ): void;

    @route("/delegateTimesheets")
    @post
    op delegateTimesheets(
      _comment: string,
      _timesheetRecIds: unknown,
      _user: string,
    ): void;

    @route("/delegateTimesheetLines")
    @post
    op delegateTimesheetLines(
      _comment: string,
      _timesheetLineRecIds: unknown,
      _user: string,
    ): void;

    @route("/getDelegatesForApproval")
    @post
    op getDelegatesForApproval(_timesheetRecId: int64): void;

    @route("/getDelegatesForLineApproval")
    @post
    op getDelegatesForLineApproval(_timesheetLineRecId: int64): void;
  }
}
