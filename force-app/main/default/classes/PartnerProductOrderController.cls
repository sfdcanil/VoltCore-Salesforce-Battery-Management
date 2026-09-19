public without sharing class PartnerProductOrderController {

    /*
     * ============================================================
     * TEST SUPPORT
     * ============================================================
     *
     * Used by the test class when required to identify the Partner
     * User while running the controller in a test context.
     */
    @TestVisible
    private static Id testUserId;


    /*
     * ============================================================
     * PRODUCT OPTION
     * ============================================================
     *
     * Data returned to the Partner Portal product-selection UI.
     *
     * Price is read from Salesforce PricebookEntry.UnitPrice.
     * The browser must never provide the price.
     */
    public class ProductOption {

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public Id pricebookEntryId;

        @AuraEnabled
        public String productName;

        @AuraEnabled
        public String productCode;

        @AuraEnabled
        public Decimal unitPrice;


        public ProductOption(
            Id productId,
            Id pricebookEntryId,
            String productName,
            String productCode,
            Decimal unitPrice
        ) {
            this.productId = productId;
            this.pricebookEntryId = pricebookEntryId;
            this.productName = productName;
            this.productCode = productCode;
            this.unitPrice = unitPrice;
        }
    }


    /*
     * ============================================================
     * PRODUCT SELECTION
     * ============================================================
     *
     * Data received from the Partner Portal.
     *
     * Partner sends ONLY:
     * - Product Id
     * - Quantity
     *
     * Partner does NOT send:
     * - Opportunity Id
     * - Account Id
     * - Price
     * - Pricebook Entry Id
     */
    public class ProductSelection {

        @AuraEnabled
        public Id productId;

        @AuraEnabled
        public Decimal quantity;


        public ProductSelection() {
        }
    }


    /*
     * ============================================================
     * SUBMISSION RESULT
     * ============================================================
     */
    public class SubmissionResult {

        @AuraEnabled
        public Id opportunityId;

        @AuraEnabled
        public String opportunityName;

        @AuraEnabled
        public Decimal opportunityAmount;

        @AuraEnabled
        public Integer productCount;


        public SubmissionResult(
            Id opportunityId,
            String opportunityName,
            Decimal opportunityAmount,
            Integer productCount
        ) {
            this.opportunityId = opportunityId;
            this.opportunityName = opportunityName;
            this.opportunityAmount = opportunityAmount;
            this.productCount = productCount;
        }
    }


    /*
     * ============================================================
     * GET AVAILABLE PRODUCTS
     * ============================================================
     *
     * Returns active Products that have an active Pricebook Entry
     * in the Standard Price Book.
     *
     * IMPORTANT:
     *
     * API version 67 uses User Mode by default for database
     * operations. Partner users may not have direct access to
     * PricebookEntry records.
     *
     * Therefore PricebookEntry access is explicitly SYSTEM_MODE.
     *
     * The Standard Price Book is also explicitly selected so that
     * another active Pricebook Entry cannot accidentally appear.
     */
    @AuraEnabled(cacheable=true)
    public static List<ProductOption> getAvailableProducts() {

        List<ProductOption> results =
            new List<ProductOption>();


        /*
         * --------------------------------------------------------
         * 1. Get the active Standard Price Book
         * --------------------------------------------------------
         */
        Pricebook2 standardPricebook = [
            SELECT
                Id,
                Name,
                IsActive,
                IsStandard
            FROM Pricebook2
            WHERE IsStandard = true
            AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];


        /*
         * --------------------------------------------------------
         * 2. Get active Standard Price Book Entries
         * --------------------------------------------------------
         *
         * Price comes directly from PricebookEntry.UnitPrice.
         */
        List<PricebookEntry> entries = [
            SELECT
                Id,
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
            WITH SYSTEM_MODE
            ORDER BY Product2.Name
        ];


        /*
         * --------------------------------------------------------
         * 3. Build product options
         * --------------------------------------------------------
         */
        for (PricebookEntry pbe : entries) {

            results.add(
                new ProductOption(
                    pbe.Product2Id,
                    pbe.Id,
                    pbe.Product2.Name,
                    pbe.Product2.ProductCode,
                    pbe.UnitPrice
                )
            );
        }


        return results;
    }


    /*
     * ============================================================
     * SUBMIT ORDER
     * ============================================================
     *
     * Business flow:
     *
     * Partner User
     *      Gåô
     * User
     *      Gåô
     * Contact
     *      Gåô
     * Partner Account
     *      Gåô
     * Standard Price Book
     *      Gåô
     * Pricebook Entries
     *      Gåô
     * Opportunity
     *      Gåô
     * Opportunity Products
     *
     * The Partner supplies only Product Id + Quantity.
     *
     * Salesforce determines:
     * - Partner Account
     * - Pricebook
     * - Price
     * - Opportunity
     * - Opportunity Products
     */
    @AuraEnabled
    public static SubmissionResult submitOrder(
        List<ProductSelection> selections
    ) {

        /*
         * --------------------------------------------------------
         * 1. Validate selections
         * --------------------------------------------------------
         */
        if (
            selections == null ||
            selections.isEmpty()
        ) {

            throw new AuraHandledException(
                'Please select at least one product.'
            );
        }


        /*
         * --------------------------------------------------------
         * 2. Identify current Partner User
         * --------------------------------------------------------
         */
        Id currentUserId =
            UserInfo.getUserId();


        /*
         * Test support.
         *
         * Normally the controller always uses the logged-in user.
         * The test class can supply a Partner User when necessary.
         */
        if (
            Test.isRunningTest() &&
            testUserId != null
        ) {

            currentUserId =
                testUserId;
        }


        User currentUser = [
            SELECT
                Id,
                ContactId,
                Contact.AccountId,
                Contact.Account.IsPartner,
                Contact.Account.Name
            FROM User
            WHERE Id = :currentUserId
            LIMIT 1
        ];


        /*
         * --------------------------------------------------------
         * 3. Validate Partner User / Partner Account
         * --------------------------------------------------------
         */
        if (
            currentUser.ContactId == null
        ) {

            throw new AuraHandledException(
                'Your user is not associated with a Contact.'
            );
        }


        if (
            currentUser.Contact.AccountId == null
        ) {

            throw new AuraHandledException(
                'Your Contact is not associated with an Account.'
            );
        }


        if (
            currentUser.Contact.Account.IsPartner != true
        ) {

            throw new AuraHandledException(
                'Your Account is not configured as a Partner Account.'
            );
        }


        Id partnerAccountId =
            currentUser.Contact.AccountId;

        String partnerAccountName =
            currentUser.Contact.Account.Name;


        /*
         * --------------------------------------------------------
         * 4. Validate Product Selections
         * --------------------------------------------------------
         */
        Set<Id> productIds =
            new Set<Id>();


        for (
            ProductSelection selection :
            selections
        ) {

            if (
                selection == null ||
                selection.productId == null
            ) {

                throw new AuraHandledException(
                    'Invalid product selection.'
                );
            }


            if (
                selection.quantity == null ||
                selection.quantity <= 0
            ) {

                throw new AuraHandledException(
                    'Product quantity must be greater than zero.'
                );
            }


            if (
                selection.quantity > 100000
            ) {

                throw new AuraHandledException(
                    'Product quantity is too large.'
                );
            }


            /*
             * Prevent duplicate Product selections.
             *
             * A Product should appear only once in an order.
             */
            if (
                productIds.contains(
                    selection.productId
                )
            ) {

                throw new AuraHandledException(
                    'The same product cannot be selected more than once.'
                );
            }


            productIds.add(
                selection.productId
            );
        }


        /*
         * --------------------------------------------------------
         * 5. Get the Standard Price Book
         * --------------------------------------------------------
         *
         * This is the authoritative Price Book for the portal
         * order process.
         *
         * SYSTEM_MODE is required because Partner users may not
         * have direct Pricebook2 access under API 67 User Mode.
         */
        Pricebook2 standardPricebook = [
            SELECT
                Id,
                Name,
                IsActive,
                IsStandard
            FROM Pricebook2
            WHERE IsStandard = true
            AND IsActive = true
            WITH SYSTEM_MODE
            LIMIT 1
        ];


        /*
         * --------------------------------------------------------
         * 6. Get Authoritative Pricebook Entries
         * --------------------------------------------------------
         *
         * IMPORTANT:
         *
         * We filter by:
         *
         *     Pricebook2Id = Standard Price Book
         *
         * This prevents another active Pricebook Entry for the same
         * Product from being selected.
         *
         * Example from the current org:
         *
         * Test Battery1
         *     Dealers Price Book  = 80
         *     Standard Price Book = 100
         *
         * The portal must use 100.
         *
         * Price always comes from:
         *
         *     PricebookEntry.UnitPrice
         *
         * No price from the browser is trusted.
         */
        List<PricebookEntry> entries = [
            SELECT
                Id,
                Product2Id,
                Product2.Name,
                Product2.ProductCode,
                Product2.IsActive,
                Pricebook2Id,
                UnitPrice,
                IsActive
            FROM PricebookEntry
            WHERE Product2Id IN :productIds
            AND Pricebook2Id = :standardPricebook.Id
            AND IsActive = true
            AND Product2.IsActive = true
            WITH SYSTEM_MODE
        ];


        /*
         * --------------------------------------------------------
         * 7. Map Pricebook Entry by Product
         * --------------------------------------------------------
         */
        Map<Id, PricebookEntry>
            pricebookEntriesByProduct =
            new Map<Id, PricebookEntry>();


        for (
            PricebookEntry pbe :
            entries
        ) {

            /*
             * There must be only one active Standard Pricebook
             * Entry for each Product.
             */
            if (
                pricebookEntriesByProduct.containsKey(
                    pbe.Product2Id
                )
            ) {

                throw new AuraHandledException(
                    'Multiple active Standard Price Book entries were found for product: ' +
                    pbe.Product2.Name +
                    '. Please contact the administrator.'
                );
            }


            pricebookEntriesByProduct.put(
                pbe.Product2Id,
                pbe
            );
        }


        /*
         * --------------------------------------------------------
         * 8. Make Sure Every Selected Product Has a Price
         * --------------------------------------------------------
         */
        for (
            Id productId :
            productIds
        ) {

            if (
                !pricebookEntriesByProduct.containsKey(
                    productId
                )
            ) {

                throw new AuraHandledException(
                    'One or more selected products do not have an active price in the Standard Price Book.'
                );
            }
        }


        /*
         * --------------------------------------------------------
         * 9. Create Opportunity
         * --------------------------------------------------------
         *
         * Opportunity Account is ALWAYS derived from the logged-in
         * Partner User.
         *
         * The browser cannot select another Account.
         */
        String opportunityName =
            partnerAccountName +
            ' - Portal Order - ' +
            String.valueOf(
                Date.today()
            );


        Opportunity opportunity =
            new Opportunity();


        opportunity.Name =
            opportunityName;

        opportunity.AccountId =
            partnerAccountId;

        opportunity.StageName =
            'Qualification';

        opportunity.CloseDate =
            Date.today();

        opportunity.Pricebook2Id =
            standardPricebook.Id;

        opportunity.LeadSource =
            'Partner';

        opportunity.Type =
            'New Business';


        /*
         * Explicit SYSTEM_MODE because this operation is initiated
         * by a Partner User.
         */
        Database.insert(
            opportunity,
            AccessLevel.SYSTEM_MODE
        );


        /*
         * --------------------------------------------------------
         * 10. Create Opportunity Products
         * --------------------------------------------------------
         */
        List<OpportunityLineItem> lineItems =
            new List<OpportunityLineItem>();


        for (
            ProductSelection selection :
            selections
        ) {

            PricebookEntry pbe =
                pricebookEntriesByProduct.get(
                    selection.productId
                );


            OpportunityLineItem lineItem =
                new OpportunityLineItem();


            lineItem.OpportunityId =
                opportunity.Id;


            lineItem.PricebookEntryId =
                pbe.Id;


            lineItem.Quantity =
                selection.quantity;


            /*
             * ====================================================
             * AUTHORITATIVE SERVER-SIDE PRICE
             * ====================================================
             *
             * NEVER accept a price from the LWC/browser.
             *
             * The price is re-read from the authoritative
             * Standard Pricebook Entry.
             */
            lineItem.UnitPrice =
                pbe.UnitPrice;


            lineItems.add(
                lineItem
            );
        }


        /*
         * All Opportunity Products are inserted together.
         *
         * If the DML fails, the transaction fails rather than
         * leaving a partially created order.
         */
        Database.insert(
            lineItems,
            AccessLevel.SYSTEM_MODE
        );


        /*
         * --------------------------------------------------------
         * 11. Get Final Opportunity Amount
         * --------------------------------------------------------
         *
         * Salesforce calculates the Opportunity Amount from the
         * Opportunity Products.
         */
        Opportunity createdOpportunity = [
            SELECT
                Id,
                Name,
                Amount
            FROM Opportunity
            WHERE Id = :opportunity.Id
            WITH SYSTEM_MODE
        ];


        /*
         * --------------------------------------------------------
         * 12. Return Result to Partner Portal
         * --------------------------------------------------------
         */
        return new SubmissionResult(
            createdOpportunity.Id,
            createdOpportunity.Name,
            createdOpportunity.Amount,
            lineItems.size()
        );
    }
}
