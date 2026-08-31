public with sharing class VoltCoreLeadConversionAction {

    public class Request {
        @InvocableVariable(required=true)
        public Id leadId;
    }

    @InvocableMethod(
        label='Convert VoltCore Lead'
        description='Converts an approved VoltCore dealer Lead into an Account and Contact'
    )
    public static void convertLeads(List<Request> requests) {

        List<Database.LeadConvert> conversions = new List<Database.LeadConvert>();

        // Find the converted Lead Status dynamically
        String convertedStatus = [
            SELECT MasterLabel
            FROM LeadStatus
            WHERE IsConverted = true
            LIMIT 1
        ].MasterLabel;

        for (Request request : requests) {

            Database.LeadConvert conversion = new Database.LeadConvert();

            conversion.setLeadId(request.leadId);
            conversion.setConvertedStatus(convertedStatus);

            // Create Account + Contact, but no Opportunity
            conversion.setDoNotCreateOpportunity(true);

            conversions.add(conversion);
        }

        if (!conversions.isEmpty()) {
            Database.convertLead(conversions, false);
        }
    }
}