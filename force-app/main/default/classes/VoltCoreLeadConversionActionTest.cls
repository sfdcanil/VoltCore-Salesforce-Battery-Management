@IsTest
private class VoltCoreLeadConversionActionTest {

    @IsTest
    static void testLeadConversion() {

        // Create test Lead
        Lead testLead = new Lead(
            FirstName = 'VoltCore',
            LastName = 'TestDealer',
            Company = 'VoltCore Test Company',
            Status = 'New'
        );

        insert testLead;

        // Prepare Invocable request
        VoltCoreLeadConversionAction.Request request =
            new VoltCoreLeadConversionAction.Request();

        request.leadId = testLead.Id;

        List<VoltCoreLeadConversionAction.Request> requests =
            new List<VoltCoreLeadConversionAction.Request>();

        requests.add(request);

        Test.startTest();

        VoltCoreLeadConversionAction.convertLeads(requests);

        Test.stopTest();

        // Verify Lead was converted
        Lead convertedLead = [
            SELECT Id, IsConverted, ConvertedAccountId, ConvertedContactId
            FROM Lead
            WHERE Id = :testLead.Id
        ];

        System.assertEquals(
            true,
            convertedLead.IsConverted,
            'Lead should be converted.'
        );

        System.assertNotEquals(
            null,
            convertedLead.ConvertedAccountId,
            'An Account should be created.'
        );

        System.assertNotEquals(
            null,
            convertedLead.ConvertedContactId,
            'A Contact should be created.'
        );

        // Verify Account exists
        Account convertedAccount = [
            SELECT Id, Name
            FROM Account
            WHERE Id = :convertedLead.ConvertedAccountId
        ];

        System.assertEquals(
            'VoltCore Test Company',
            convertedAccount.Name,
            'Account should be created from the Lead Company.'
        );

        // Verify Contact exists
        Contact convertedContact = [
            SELECT Id, FirstName, LastName
            FROM Contact
            WHERE Id = :convertedLead.ConvertedContactId
        ];

        System.assertEquals(
            'VoltCore',
            convertedContact.FirstName,
            'Contact first name should come from the Lead.'
        );

        System.assertEquals(
            'TestDealer',
            convertedContact.LastName,
            'Contact last name should come from the Lead.'
        );

        // Verify no Opportunity was created
        List<Opportunity> opportunities = [
            SELECT Id
            FROM Opportunity
            WHERE AccountId = :convertedLead.ConvertedAccountId
        ];

        System.assertEquals(
            0,
            opportunities.size(),
            'VoltCore Lead conversion should not create an Opportunity.'
        );
    }
}