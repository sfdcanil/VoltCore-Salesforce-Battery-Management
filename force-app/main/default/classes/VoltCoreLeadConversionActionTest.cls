@IsTest
private class VoltCoreLeadConversionActionTest {

    @IsTest
    static void testLeadConversion() {

        Lead testLead = new Lead(
            FirstName = 'VoltCore',
            LastName = 'TestDealer',
            Company = 'VoltCore Test Company',
            Status = 'New',
            GSTIN__c = '37ABCDF1234E1Z5',
            PAN_Number__c = 'ABCDE1234F'
        );

        insert testLead;

        VoltCoreLeadConversionAction.Request request =
            new VoltCoreLeadConversionAction.Request();

        request.leadId = testLead.Id;

        List<VoltCoreLeadConversionAction.Request> requests =
            new List<VoltCoreLeadConversionAction.Request>();

        requests.add(request);

        Test.startTest();

        VoltCoreLeadConversionAction.convertLeads(requests);

        Test.stopTest();

        Lead convertedLead = [
            SELECT Id,
                   IsConverted,
                   ConvertedAccountId,
                   ConvertedContactId
            FROM Lead
            WHERE Id = :testLead.Id
        ];

        System.assertEquals(true, convertedLead.IsConverted);
        System.assertNotEquals(null, convertedLead.ConvertedAccountId);
        System.assertNotEquals(null, convertedLead.ConvertedContactId);

        Account convertedAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :convertedLead.ConvertedAccountId
        ];

        System.assertEquals(
            'VoltCore Test Company',
            convertedAccount.Name
        );

        Contact convertedContact = [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id = :convertedLead.ConvertedContactId
        ];

        System.assertEquals(
            'VoltCore',
            convertedContact.FirstName
        );

        System.assertEquals(
            'TestDealer',
            convertedContact.LastName
        );

        List<Opportunity> opportunities = [
            SELECT Id
            FROM Opportunity
            WHERE AccountId = :convertedLead.ConvertedAccountId
        ];

        System.assertEquals(0, opportunities.size());
    }
}