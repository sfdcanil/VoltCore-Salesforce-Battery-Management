@IsTest
private class VoltCoreHomeControllerTest {

    @TestSetup
    static void setupTestData() {

        List<Lead> leads = new List<Lead>();

        // Lead awaiting approval
        leads.add(new Lead(
            FirstName = 'Test',
            LastName = 'AwaitingApproval',
            Company = 'VoltCore Test Company 1',
            Status = 'New'
        ));

        // Another Lead awaiting approval
        leads.add(new Lead(
            FirstName = 'Test',
            LastName = 'DealerApplication',
            Company = 'VoltCore Test Company 2',
            Status = 'New'
        ));

        insert leads;
    }

    @IsTest
    static void testGetDealerApplications() {

        Test.startTest();

        Integer result =
            VoltCoreHomeController.getDealerApplications();

        Test.stopTest();

        System.assertEquals(
            2,
            result,
            'Total dealer applications should be 2.'
        );
    }

    @IsTest
    static void testGetLeadsAwaitingApproval() {

        Test.startTest();

        Integer result =
            VoltCoreHomeController.getLeadsAwaitingApproval();

        Test.stopTest();

        System.assertEquals(
            2,
            result,
            'Two Leads should be awaiting approval.'
        );
    }

    @IsTest
    static void testGetApprovedDealers() {

        Test.startTest();

        Integer result =
            VoltCoreHomeController.getApprovedDealers();

        Test.stopTest();

        System.assertEquals(
            0,
            result,
            'No Leads should be converted yet.'
        );
    }

    @IsTest
    static void testGetConvertedLeads() {

        Test.startTest();

        Integer result =
            VoltCoreHomeController.getConvertedLeads();

        Test.stopTest();

        System.assertEquals(
            0,
            result,
            'No Leads should be converted yet.'
        );
    }
}