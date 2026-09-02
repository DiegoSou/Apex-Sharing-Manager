public without sharing class CaseParticipantUpdateSharingService implements RecordSharingService.ISharingHandler {
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<CaseParticipant__c> records) {
        List<CaseShare> newSharing = new List<CaseShare>();

        for (CaseParticipant__c caseParticipant : records) {
            newSharing.add(
                new CaseShare(
                    RowCause = 'Manual',
                    CaseAccessLevel = caseParticipant.Role__c == 'Viewer' ? 'Read' : 'Edit',
                    CaseId = caseParticipant.Case__c,
                    UserOrGroupId = caseParticipant.User__c
                )
            );
        }

        Database.SaveResult[] saveResults = Database.insert(newSharing, false, AccessLevel.SYSTEM_MODE);
        String errorMessage = '';
        for (Database.SaveResult saveResult : saveResults) {
            if (!saveResult.isSuccess()) {
                for (Database.Error error : saveResult.getErrors()) {
                    errorMessage += error.getStatusCode() + ': ' + error.getMessage() + '\n';
                }
            }
        }

        if (!String.isBlank(errorMessage)) { System.debug('Errors during case sharing update: \n' + errorMessage); }
    }
}