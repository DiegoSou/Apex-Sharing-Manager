public inherited sharing class RecordSharingService {
    
    // Interface comum entre as handlers
    public interface ISharingHandler {
        void executeSharing(List<SObject> records);
    }

    /**
     * Método principal que recebe SObjects e faz o roteamento
     * @param records Lista de registros que foram atualizados e devem ser enviados para o serviço de compartilhamento.
     */
    public static void routeToSharingConfigs(List<SObject> records) {
        if (records == null || records.isEmpty() || Trigger.isBefore) return;

        // 1. Agrupar os registros por SObjectType
        Map<String, List<SObject>> recordsByType = getMapSObjectRecordsByType(records);

        // 2. Buscar as configurações ativas no Metadado para os tipos recebidos
        List<Service_Sharing_Config__mdt> metadataConfigs = ServiceSharingConfigSelector.getSharingConfigsBySObjectType(recordsByType.keySet());

        // Organizar metadados por tipo de SObject para facilitar o loop
        Map<String, List<Service_Sharing_Config__mdt>> configsByType = getMapServiceSharingConfigsByType(metadataConfigs);

        // 3. Processar cada tipo de objeto e avaliar as fórmulas
        for (String sObjType : recordsByType.keySet()) {
            List<Service_Sharing_Config__mdt> typeConfigs = configsByType.get(sObjType);
            
            if (typeConfigs == null || typeConfigs.isEmpty()) continue;

            // Mapa para guardar quais registros vão para qual Handler
            Map<String, Map<Id, SObject>> recordsByHandler = new Map<String, Map<Id, SObject>>();

            for (Service_Sharing_Config__mdt typeConfig : typeConfigs) {
    
                // Instanciar o avaliador de fórmula dinâmico do Salesforce
                FormulaEval.FormulaInstance sharingFormula;
                try {
                    sharingFormula = buildSharingFormulaInstance(typeConfig, Trigger.operationType.toString());
                } catch (Exception e) {
                    System.debug('Error building formula: ' + typeConfig.DeveloperName + ': ' + e.getMessage());
                    continue; // Pula essa regra se a fórmula for inválida
                }

                // Avaliar os registros contra a fórmula
                for (SObject record : recordsByType.get(sObjType)) {
                    Boolean meetsSharingCriteria = false;

                    try {
                        meetsSharingCriteria = (Boolean) sharingFormula.evaluate(record);
                    } catch (Exception e) {
                        System.debug('Error evaluating the record: ' + record.Id + ': ' + e.getMessage());
                        meetsSharingCriteria = false;
                    }

                    // Se a fórmula retornou VERDADEIRO, separamos o registro para a classe Handler
                    if (meetsSharingCriteria) {
                        if (!recordsByHandler.containsKey(typeConfig.HandlerClassName__c)) {
                            recordsByHandler.put(typeConfig.HandlerClassName__c, new Map<Id, SObject>());
                        }
                        recordsByHandler.get(typeConfig.HandlerClassName__c).put(record.Id, record);
                    }
                }
            }

            // 4. Instanciar as classes que fazem o compartilhamento
            // Fica a cargo da classe escolher fazer o compartilhamento imediatamente ou enfileirar um job para fazê-lo
            for (String handlerClassName : recordsByHandler.keySet()) {
                executeHandlerSharing(handlerClassName, recordsByHandler.get(handlerClassName).values());
            }
        }
    }

    //
    // Auxiliar Methods
    //

    private static Map<String, List<SObject>> getMapSObjectRecordsByType(List<SObject> records) {
        Map<String, List<SObject>> recordsByType = new Map<String, List<SObject>>();
        
        for (SObject record : records) {
            String sObjType = record.getSObjectType().getDescribe().getName();
            if (!recordsByType.containsKey(sObjType)) {
                recordsByType.put(sObjType, new List<SObject>());
            }
            recordsByType.get(sObjType).add(record);
        }
        
        return recordsByType;
    }

    private static Map<String, List<Service_Sharing_Config__mdt>> getMapServiceSharingConfigsByType(List<Service_Sharing_Config__mdt> metadataConfigs) {
        Map<String, List<Service_Sharing_Config__mdt>> configsByType = new Map<String, List<Service_Sharing_Config__mdt>>();
        
        for (Service_Sharing_Config__mdt config : metadataConfigs) {
            if (!configsByType.containsKey(config.SObjectAPIName__c)) {
                configsByType.put(config.SObjectAPIName__c, new List<Service_Sharing_Config__mdt>());
            }
            configsByType.get(config.SObjectAPIName__c).add(config);
        }

        return configsByType;
    }

    /**
     * @description Helper method to create a formula evaluation instance using the text Formula Field from metadataConfig
     * @param metadataConfig The Service_Sharing_Config__mdt record which contains the formula
     * @param operationType Useful to determine if the service has been called from trigger context and substitute mentions to context variables
     */
    private static FormulaEval.FormulaInstance buildSharingFormulaInstance(Service_Sharing_Config__mdt metadataConfig, String operationType) {
        
        // replaces context variables
        String evaluationFormula = metadataConfig.EvaluationFormula__c
            .replaceAll('AFTER_INSERT', operationType == 'AFTER_INSERT' ? 'TRUE' : 'FALSE')
            .replaceAll('AFTER_UPDATE', operationType == 'AFTER_UPDATE' ? 'TRUE' : 'FALSE')
            .replaceAll('AFTER_DELETE', operationType == 'AFTER_DELETE' ? 'TRUE' : 'FALSE')
            .replaceAll('AFTER_UNDELETE', operationType == 'AFTER_UNDELETE' ? 'TRUE' : 'FALSE');
        
        FormulaEval.FormulaInstance sharingFormula = Formula.builder()
            .withReturnType(FormulaEval.FormulaReturnType.BOOLEAN)
            .withType(Schema.getGlobalDescribe().get(metadataConfig.SObjectAPIName__c))
            .withFormula(evaluationFormula)
            .build(); 

        return sharingFormula;
    }

    private static void executeHandlerSharing(String handlerClassName, List<SObject> recordsToShare) {
        Type handlerType = Type.forName(handlerClassName);
        if (handlerType == null) {
            System.debug('Apex Class not found: ' + handlerClassName);
            return;
        }

        ISharingHandler handler = (ISharingHandler) handlerType.newInstance();
        handler.executeSharing(recordsToShare);
    }
}