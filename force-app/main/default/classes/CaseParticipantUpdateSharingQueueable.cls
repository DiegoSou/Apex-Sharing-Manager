public without sharing class CaseParticipantUpdateSharingQueueable implements RecordSharingService.ISharingHandler, System.Queueable {
    private Database.Cursor locator;
    private Integer position;
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<SObject> records) {
        locator = Database.getCursorWithBinds(
            'SELECT Id, User__c, Role__c, Case__c FROM CaseParticipant__c WHERE Id IN :recordIds', 
            new Map<String, Object> {
                'recordIds' => new Map<String, CaseParticipant__c>((List<CaseParticipant__c>) records).keySet()
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
        List<CaseParticipant__c> scope = locator.fetch(position, Math.min(200, remainingRows));
        System.debug('Execution scope: '+scope);
        position += scope.size();
        
        // Do manual sharing
        new CaseParticipantUpdateSharingService().executeSharing(scope);
        
        if (position != 0 && position < locator.getNumRecords()) {
            // process the next chunk
            System.enqueueJob(this);
        }
    }
}