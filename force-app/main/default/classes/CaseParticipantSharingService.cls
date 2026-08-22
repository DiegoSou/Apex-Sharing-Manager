public without sharing class CaseParticipantSharingService implements RecordSharingService.ISharingHandler {
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<CaseParticipant__c> records, String operationType) {
        switch on operationType {
            when  'AFTER_DELETE' {
                deleteSharing(records);
            }
            when 'AFTER_INSERT', 'AFTER_UPDATE' {
                updateSharing(records);
            }
        }
    }

    //
    // Auxiliar Methods
    //

    private void deleteSharing(List<CaseParticipant__c> recordsDeletedSharing) {
        Set<String> viewAccessCaseIds = new Set<String>();
        Set<String> viewAccessUserOrGroupIds = new Set<String>();
        Set<String> editAccessCaseIds = new Set<String>();
        Set<String> editAccessUserOrGroupIds = new Set<String>();

        for (CaseParticipant__c caseParticipant : recordsDeletedSharing) {
            switch on caseParticipant.Role__c {
                when 'Viewer' {
                    viewAccessCaseIds.add(caseParticipant.Case__c);
                    viewAccessUserOrGroupIds.add(caseParticipant.User__c);
                }
                when 'Editor', 'Manager' {
                    editAccessCaseIds.add(caseParticipant.Case__c);
                    editAccessUserOrGroupIds.add(caseParticipant.User__c);
                }
            }
        }

        List<CaseShare> existingSharingViewer = [
            SELECT Id 
            FROM CaseShare 
            WHERE CaseId IN :viewAccessCaseIds 
            AND UserOrGroupId IN :viewAccessUserOrGroupIds 
            AND CaseAccessLevel = 'Read'
            AND RowCause = 'Manual'
        ];

        List<CaseShare> existingSharingEditorOrManager = [
            SELECT Id 
            FROM CaseShare 
            WHERE CaseId IN :editAccessCaseIds 
            AND UserOrGroupId IN :editAccessUserOrGroupIds 
            AND CaseAccessLevel = 'Edit'
            AND RowCause = 'Manual'
        ];

        List<CaseShare> recordsToDelete = new List<CaseShare>();
        recordsToDelete.addAll(existingSharingViewer);
        recordsToDelete.addAll(existingSharingEditorOrManager);

        Database.DeleteResult[] deleteResults = Database.delete(recordsToDelete, false, AccessLevel.SYSTEM_MODE);
        String errorMessage = '';
        for (Database.DeleteResult deleteResult : deleteResults) {
            if (!deleteResult.isSuccess()) {
                for (Database.Error error : deleteResult.getErrors()) {
                    errorMessage += error.getStatusCode() + ': ' + error.getMessage() + '\n';
                }
            }
        }

        if (!String.isBlank(errorMessage)) { System.debug('Errors during case sharing deletion: \n' + errorMessage); }
    }

    private void updateSharing(List<CaseParticipant__c> recordsUpdatedSharing) {
        List<CaseShare> newSharing = new List<CaseShare>();

        for (CaseParticipant__c caseParticipant : recordsUpdatedSharing) {
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