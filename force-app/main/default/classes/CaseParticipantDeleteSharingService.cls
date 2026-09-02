public with sharing class CaseParticipantDeleteSharingService implements RecordSharingService.ISharingHandler {

    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<CaseShare> recordShares) {

        Map<String, CaseParticipant__c> caseParticipantByExternalId = new Map<String, CaseParticipant__c>();
        Set<String> caseIds = new Set<String>();
        Set<String> userIds = new Set<String>();

        // Mapeia Case Shares dos Case Participants que foram removidos
        for (CaseShare recordShare : recordShares) {
            caseIds.add(recordShare.CaseId);
            userIds.add(recordShare.UserOrGroupId);
        }

        List<CaseParticipant__c> caseParticipants = [
            SELECT Id, Case__c, User__c, Role__c 
            FROM CaseParticipant__c 
            WHERE Case__c IN :caseIds AND User__c IN :userIds
        ];

        // Mapeia Case Participants existentes (que não foram removidos)
        for (CaseParticipant__c caseParticipant : caseParticipants) {
            String accessLevel = caseParticipant.Role__c == 'Viewer' ? 'Read' : 'Edit';

            caseParticipantByExternalId.put(
                caseParticipant.Case__c + '|' + caseParticipant.User__c + '|' + accessLevel, caseParticipant
            );
        }

        List<CaseShare> caseShareToDelete = new List<CaseShare>();
        for (CaseShare recordShare : recordShares) {
            String matchId = recordShare.CaseId + '|' + recordShare.UserOrGroupId + '|' + recordShare.CaseAccessLevel;

            if (!caseParticipantByExternalId.containsKey(matchId)) {
                caseShareToDelete.add(recordShare);
                caseParticipantByExternalId.remove(matchId);
            }            
        }

        Database.DeleteResult[] deleteResults = Database.delete(caseShareToDelete, false, AccessLevel.SYSTEM_MODE);
        String errorMessage = '';
        for (Database.DeleteResult deleteResult : deleteResults) {
            if (!deleteResult.isSuccess()) {
                for (Database.Error error : deleteResult.getErrors()) {
                    errorMessage += error.getStatusCode() + ': ' + error.getMessage() + '\n';
                }
            }
        }

        if (!String.isBlank(errorMessage)) { System.debug('Errors during case sharing deletion: \n' + errorMessage); }

        // If any records remain with access, but their major access level has been removed, reprocess
        
        if (!caseParticipantByExternalId.isEmpty()) {
            new CaseParticipantUpdateSharingService().executeSharing(caseParticipantByExternalId.values());
        }
    }
}