trigger CaseParticipantTrigger on CaseParticipant__c (after insert, after update, after delete) {
    RecordSharingService.routeToSharingConfigs(Trigger.isDelete ? Trigger.old : Trigger.new);
}