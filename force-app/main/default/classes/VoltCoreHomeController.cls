public with sharing class VoltCoreHomeController {

    @AuraEnabled(cacheable=true)
    public static Integer getDealerApplications() {
        return [
            SELECT COUNT()
            FROM Lead
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getLeadsAwaitingApproval() {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = false
            AND Status = 'New'
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getApprovedDealers() {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = true
        ];
    }

    @AuraEnabled(cacheable=true)
    public static Integer getConvertedLeads() {
        return [
            SELECT COUNT()
            FROM Lead
            WHERE IsConverted = true
        ];
    }
}