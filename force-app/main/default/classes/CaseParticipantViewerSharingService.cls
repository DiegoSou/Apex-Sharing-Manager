public without sharing class CaseParticipantViewerSharingService implements RecordSharingService.ISharingHandler, System.Queueable {
    private List<CaseParticipant__c> records;
    
    //
    // RecordSharingService.ISharingHandler methods
    //

    public void executeSharing(List<SObject> records) {
        this.records = (List<CaseParticipant__c>) records;
        System.enqueueJob(this);
    }

    //
    // Queueable Methods
    //

    public void execute(QueueableContext context) {
        
    }
}