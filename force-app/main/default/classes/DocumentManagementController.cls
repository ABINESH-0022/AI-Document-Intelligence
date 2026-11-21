public with sharing class DocumentManagementController {

    @AuraEnabled(cacheable=true)
    public static List<Document_Repository__c> getDocuments() {

        return [
            SELECT Id,
                   Name,
                   Document_Type__c,
                   Vendor_Name__c,
                   Document_Number__c,
                   Document_Date__c,
                   Total_Amount__c,
                   Processing_Status__c,
                   Validation_Status__c
            FROM Document_Repository__c
            WITH USER_MODE
            ORDER BY CreatedDate DESC
            LIMIT 500
        ];
    }
}