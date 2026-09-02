public with sharing class CaseParticipantDeleteSharingQueueable implements RecordSharingService.ISharingHandler, System.Queueable {
    private Database.Cursor locator;
    private Integer position;
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<SObject> records) {
        Set<String> caseIds = new Set<String>();
        Set<String> userIds = new Set<String>();

        for (CaseParticipant__c caseParticipant : (List<CaseParticipant__c>) records) {
            caseIds.add(caseParticipant.Case__c);
            userIds.add(caseParticipant.User__c);
        }

        locator = Database.getCursorWithBinds(
            'SELECT Id, CaseId, UserOrGroupId, RowCause, CaseAccessLevel FROM CaseShare WHERE RowCause = \'Manual\' AND CaseId IN :caseIds AND UserOrGroupId IN :userIds', 
            new Map<String, Object> {
                'caseIds' => caseIds,
                'userIds' => userIds
            },
            AccessLevel.SYSTEM_MODE
        );
        position = 0;
        System.enqueueJob(this);
    }


    //
    // Queueable Methods
    //

    public void execute(QueueableContext context) {
        Integer remainingRows = locator.getNumRecords() - position;
        if (remainingRows == 0) {
            return; // Nothing to do
        }

        // Take the minimum of batch size and remaining rows to avoid over-fetching
        List<CaseShare> scope = locator.fetch(position, Math.min(200, remainingRows));
        System.debug('Execution scope: '+scope);
        position += scope.size();
        
        // Do manual sharing
        new CaseParticipantDeleteSharingService().executeSharing(scope);
        
        if (position != 0 && position < locator.getNumRecords()) {
            // process the next chunk
            System.enqueueJob(this);
        }
    }
}