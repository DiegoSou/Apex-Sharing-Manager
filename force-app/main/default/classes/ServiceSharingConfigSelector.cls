public virtual inherited sharing class ServiceSharingConfigSelector {
    @TestVisible
    private static ServiceSharingConfigSelector instance {
        get {
            if (instance == null) instance = new ServiceSharingConfigSelector();
            return instance;
        }
        set;
    }

    //
    // Selector Methods (Protected)
    //

    protected List<Service_Sharing_Config__mdt> querySharingConfigsBySObjectType(Set<String> sobjectApiNames) {
        return [
            SELECT DeveloperName, SObjectAPIName__c, HandlerClassName__c, EvaluationFormula__c, IsActive__c
            FROM Service_Sharing_Config__mdt
            WHERE SObjectAPIName__c IN :sobjectApiNames
            AND IsActive__c = true
        ];
    }

    //
    // Public Static Entry Point
    //

    public static List<Service_Sharing_Config__mdt> getSharingConfigsBySObjectType(Set<String> sobjectApiNames) {
        return instance.querySharingConfigsBySObjectType(sobjectApiNames);
    }
}