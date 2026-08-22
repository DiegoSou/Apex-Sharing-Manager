public without sharing class CaseParticipantSharingQueueable implements RecordSharingService.ISharingHandler, System.Queueable {
    private Database.Cursor locator;
    private Integer position;
    
    private List<CaseParticipant__c> records;
    private String operationType;
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<SObject> records, String operationType) {
        this.records = (List<CaseParticipant__c>) records;
        this.operationType = operationType;
        Set<String> recordIds = new Map<String, CaseParticipant__c>(this.records).keySet();
        
        locator = Database.getCursor(
            'SELECT Id, User__c, Role__c, Case__c FROM CaseParticipant__c WHERE Id IN :recordIds ALL ROWS', 
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
        Integer fetchSize = Math.min(200, remainingRows);

        List<CaseParticipant__c> scope = locator.fetch(position, fetchSize);
        position += scope.size();
        
        // Do manual sharing
        new CaseParticipantSharingService().executeSharing(scope, operationType);
        
        if (position < locator.getNumRecords()) {
            // process the next chunk
            System.enqueueJob(this);
        }
    }
}