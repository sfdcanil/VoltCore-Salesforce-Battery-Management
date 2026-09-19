@IsTest(SeeAllData=true)
private class PartnerProductOrderControllerTest {

    @IsTest
    static void testSubmitOrderForPartner() {

        /*
         * ---------------------------------------------------------
         * 1. Find an active Partner User
         * ---------------------------------------------------------
         */
        User partnerUser = [
            SELECT Id,
                   Name,
                   UserType,
                   ContactId,
                   Contact.AccountId,
                   Contact.Account.Name,
                   Contact.Account.IsPartner
            FROM User
            WHERE UserType = 'PowerPartner'
            AND IsActive = true
            AND ContactId != null
            AND Contact.AccountId != null
            AND Contact.Account.IsPartner = true
            LIMIT 1
        ];

        System.assertNotEquals(
            null,
            partnerUser.Contact.AccountId,
            'Partner User must have a Partner Account.'
        );

        System.assertEquals(
            true,
            partnerUser.Contact.Account.IsPartner,
            'The Partner Account must have IsPartner = true.'
        );


        /*
         * ---------------------------------------------------------
         * 2. Get Standard Price Book
         * ---------------------------------------------------------
         */
        Pricebook2 standardPricebook = [
            SELECT Id,
                   Name,
                   IsActive,
                   IsStandard
            FROM Pricebook2
            WHERE IsStandard = true
            LIMIT 1
        ];

        System.assertEquals(
            true,
            standardPricebook.IsStandard,
            'The Standard Price Book must be used.'
        );

        System.assertEquals(
            true,
            standardPricebook.IsActive,
            'The Standard Price Book must be active.'
        );


        /*
         * ---------------------------------------------------------
         * 3. Get active Standard Price Book Entries
         * ---------------------------------------------------------
         */
        List<PricebookEntry> pricebookEntries = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.ProductCode,
                   Product2.IsActive,
                   Pricebook2Id,
                   UnitPrice,
                   IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebook.Id
            AND IsActive = true
            AND Product2.IsActive = true
            ORDER BY Product2.Name
            LIMIT 2
        ];

        System.assert(
            pricebookEntries.size() > 0,
            'At least one active Standard Price Book Entry is required.'
        );


        /*
         * ---------------------------------------------------------
         * 4. Build product selections
         * ---------------------------------------------------------
         *
         * Only Product Id and Quantity are supplied.
         *
         * No price is supplied by the test/client.
         */
        List<PartnerProductOrderController.ProductSelection> selections =
            new List<PartnerProductOrderController.ProductSelection>();

        for (PricebookEntry pbe : pricebookEntries) {

            PartnerProductOrderController.ProductSelection selection =
                new PartnerProductOrderController.ProductSelection();

            selection.productId = pbe.Product2Id;
            selection.quantity = 2;

            selections.add(selection);
        }

        System.assertEquals(
            pricebookEntries.size(),
            selections.size(),
            'Each selected product must have a selection.'
        );


        /*
         * ---------------------------------------------------------
         * 5. Run the actual portal submission as Partner User
         * ---------------------------------------------------------
         */
        Test.startTest();

        System.runAs(partnerUser) {

            PartnerProductOrderController.SubmissionResult result =
                PartnerProductOrderController.submitOrder(
                    selections
                );


            /*
             * -----------------------------------------------------
             * 6. Validate controller result
             * -----------------------------------------------------
             */
            System.assertNotEquals(
                null,
                result,
                'Controller should return a SubmissionResult.'
            );

            System.assertNotEquals(
                null,
                result.opportunityId,
                'Opportunity Id should be returned.'
            );

            System.assertNotEquals(
                null,
                result.opportunityName,
                'Opportunity Name should be returned.'
            );

            System.assertEquals(
                pricebookEntries.size(),
                result.productCount,
                'Product count should match selected products.'
            );


            /*
             * -----------------------------------------------------
             * 7. Query created Opportunity
             * -----------------------------------------------------
             */
            Opportunity createdOpportunity = [
                SELECT Id,
                       Name,
                       AccountId,
                       StageName,
                       CloseDate,
                       Pricebook2Id,
                       LeadSource,
                       Type,
                       Amount
                FROM Opportunity
                WHERE Id = :result.opportunityId
                LIMIT 1
            ];


            /*
             * -----------------------------------------------------
             * 8. Validate Opportunity
             * -----------------------------------------------------
             */

            // Opportunity must belong to logged-in Partner Account.
            System.assertEquals(
                partnerUser.Contact.AccountId,
                createdOpportunity.AccountId,
                'Opportunity must belong to the logged-in Partner Account.'
            );


            // Standard Price Book must be used.
            System.assertEquals(
                standardPricebook.Id,
                createdOpportunity.Pricebook2Id,
                'Opportunity must use the Standard Price Book.'
            );


            // Default Stage.
            System.assertEquals(
                'Qualification',
                createdOpportunity.StageName,
                'Opportunity Stage should be Qualification.'
            );


            // Close Date.
            System.assertEquals(
                Date.today(),
                createdOpportunity.CloseDate,
                'Opportunity Close Date should be today.'
            );


            // Lead Source.
            System.assertEquals(
                'Partner',
                createdOpportunity.LeadSource,
                'Opportunity Lead Source should be Partner.'
            );


            // Type.
            System.assertEquals(
                'New Business',
                createdOpportunity.Type,
                'Opportunity Type should be New Business.'
            );


            /*
             * -----------------------------------------------------
             * 9. Query Opportunity Products
             * -----------------------------------------------------
             */
            List<OpportunityLineItem> lineItems = [
                SELECT Id,
                       OpportunityId,
                       PricebookEntryId,
                       Quantity,
                       UnitPrice,
                       TotalPrice,
                       PricebookEntry.Product2Id,
                       PricebookEntry.UnitPrice
                FROM OpportunityLineItem
                WHERE OpportunityId = :createdOpportunity.Id
                ORDER BY CreatedDate ASC
            ];


            /*
             * -----------------------------------------------------
             * 10. Validate number of Opportunity Products
             * -----------------------------------------------------
             */
            System.assertEquals(
                pricebookEntries.size(),
                lineItems.size(),
                'There must be one Opportunity Product for each selected product.'
            );


            /*
             * -----------------------------------------------------
             * 11. Build expected Pricebook Entry map
             * -----------------------------------------------------
             */
            Map<Id, PricebookEntry> expectedPbesByProduct =
                new Map<Id, PricebookEntry>();

            for (PricebookEntry pbe : pricebookEntries) {

                expectedPbesByProduct.put(
                    pbe.Product2Id,
                    pbe
                );
            }


            /*
             * -----------------------------------------------------
             * 12. Validate quantity and authoritative price
             * -----------------------------------------------------
             */
            Decimal expectedTotal = 0;

            for (OpportunityLineItem lineItem : lineItems) {

                PricebookEntry expectedPbe =
                    expectedPbesByProduct.get(
                        lineItem.PricebookEntry.Product2Id
                    );


                System.assertNotEquals(
                    null,
                    expectedPbe,
                    'Every Opportunity Product must correspond to a selected product.'
                );


                // Correct Pricebook Entry.
                System.assertEquals(
                    expectedPbe.Id,
                    lineItem.PricebookEntryId,
                    'Incorrect Pricebook Entry.'
                );


                // Submitted quantity must be preserved.
                System.assertEquals(
                    2,
                    lineItem.Quantity,
                    'Quantity should be 2.'
                );


                /*
                 * CRITICAL:
                 *
                 * Price must come from Salesforce's
                 * PricebookEntry.UnitPrice.
                 *
                 * It must NOT come from the browser.
                 */
                System.assertEquals(
                    expectedPbe.UnitPrice,
                    lineItem.UnitPrice,
                    'Opportunity Product price must come from PricebookEntry.UnitPrice.'
                );


                expectedTotal +=
                    expectedPbe.UnitPrice *
                    lineItem.Quantity;
            }


            /*
             * -----------------------------------------------------
             * 13. Validate Opportunity Amount
             * -----------------------------------------------------
             */
            System.assertEquals(
                expectedTotal,
                createdOpportunity.Amount,
                'Opportunity Amount should equal the total of Opportunity Products.'
            );


            /*
             * -----------------------------------------------------
             * 14. Validate returned Amount
             * -----------------------------------------------------
             */
            System.assertEquals(
                expectedTotal,
                result.opportunityAmount,
                'Returned Opportunity Amount should match Opportunity Amount.'
            );
        }

        Test.stopTest();
    }
@IsTest
static void testPartnerCanQueryPricebookEntryInSystemMode() {
    User partnerUser = [
        SELECT Id, ContactId, Contact.AccountId, Contact.Account.IsPartner
        FROM User
        WHERE IsActive = true
        AND UserType = 'PowerPartner'
        AND ContactId != null
        AND Contact.AccountId != null
        AND Contact.Account.IsPartner = true
        LIMIT 1
    ];

    System.runAs(partnerUser) {
        List<PricebookEntry> entries = [
            SELECT Id,
                   Product2Id,
                   Product2.Name,
                   Product2.ProductCode,
                   Pricebook2Id,
                   UnitPrice
            FROM PricebookEntry
            WHERE IsActive = true
            AND Product2.IsActive = true
            WITH SYSTEM_MODE
            LIMIT 5
        ];

        System.assert(
            !entries.isEmpty(),
            'System Mode should be able to access active PricebookEntry records.'
        );

        System.debug('SYSTEM MODE PRICEBOOK ENTRIES = ' + entries);
    }
}
    @IsTest
    static void testSelectedProductsFindPricebookEntriesInSystemMode() {

        Pricebook2 standardPricebook = [
            SELECT Id
            FROM Pricebook2
            WHERE IsStandard = true
            AND IsActive = true
            LIMIT 1
        ];

        List<PricebookEntry> selectedPbes = [
            SELECT
                Id,
                Product2Id,
                Product2.Name,
                Product2.ProductCode,
                Pricebook2Id,
                UnitPrice,
                IsActive
            FROM PricebookEntry
            WHERE Pricebook2Id = :standardPricebook.Id
            AND IsActive = true
            AND Product2.IsActive = true
            ORDER BY Product2.Name
            LIMIT 2
        ];

        System.assert(
            !selectedPbes.isEmpty(),
            'Test data must contain active Standard Pricebook Entries.'
        );

        Set<Id> productIds = new Set<Id>();

        for (PricebookEntry pbe : selectedPbes) {
            productIds.add(pbe.Product2Id);

            System.debug(
                'TEST SELECTED PRODUCT = ' +
                pbe.Product2Id +
                ' / ' +
                pbe.Product2.Name +
                ' / PBE = ' +
                pbe.Id +
                ' / PRICE = ' +
                pbe.UnitPrice
            );
        }

        System.assertEquals(
            selectedPbes.size(),
            productIds.size(),
            'Each selected PricebookEntry should represent a unique Product.'
        );

        User partnerUser = [
            SELECT
                Id,
                ContactId,
                Contact.AccountId,
                Contact.Account.IsPartner
            FROM User
            WHERE IsActive = true
            AND UserType = 'PowerPartner'
            AND ContactId != null
            AND Contact.AccountId != null
            AND Contact.Account.IsPartner = true
            LIMIT 1
        ];

        System.runAs(partnerUser) {

            List<PricebookEntry> entries = [
                SELECT
                    Id,
                    Product2Id,
                    Product2.Name,
                    Product2.ProductCode,
                    Pricebook2Id,
                    UnitPrice,
                    IsActive
                FROM PricebookEntry
                WHERE Product2Id IN :productIds
                AND IsActive = true
                AND Product2.IsActive = true
                WITH SYSTEM_MODE
            ];

            System.debug(
                'SYSTEM MODE SELECTED ENTRIES = ' +
                entries
            );

            System.assertEquals(
                productIds.size(),
                entries.size(),
                'Every selected Product2Id must resolve to exactly one active PricebookEntry.'
            );

            Map<Id, PricebookEntry> entriesByProduct =
                new Map<Id, PricebookEntry>();

            for (PricebookEntry pbe : entries) {
                entriesByProduct.put(
                    pbe.Product2Id,
                    pbe
                );
            }

            for (Id productId : productIds) {
                System.assert(
                    entriesByProduct.containsKey(productId),
                    'No active PricebookEntry was found for Product2Id: ' +
                    productId
                );
            }

            for (PricebookEntry originalPbe : selectedPbes) {

                PricebookEntry resolvedPbe =
                    entriesByProduct.get(
                        originalPbe.Product2Id
                    );

                System.assertNotEquals(
                    null,
                    resolvedPbe,
                    'Selected product must resolve to a PricebookEntry.'
                );

                System.assertEquals(
                    originalPbe.Id,
                    resolvedPbe.Id,
                    'The resolved PricebookEntry must be the selected Standard Pricebook Entry.'
                );

                System.assertEquals(
                    originalPbe.UnitPrice,
                    resolvedPbe.UnitPrice,
                    'The resolved PricebookEntry must contain the authoritative UnitPrice.'
                );
            }
        }
    }
}
