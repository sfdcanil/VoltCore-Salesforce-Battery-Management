public with sharing class VoltCoreDealerDashboardController {

    @AuraEnabled(cacheable=true)
    public static DealerDashboardData getDealerDashboard() {

        User currentUser = [
            SELECT
                Id,
                ContactId,
                Contact.FirstName,
                Contact.LastName,
                Contact.Email,
                Contact.Phone,
                Contact.AccountId,
                Contact.Account.Name,
                Contact.Account.Phone,
                Contact.Account.BillingStreet,
                Contact.Account.BillingCity,
                Contact.Account.BillingState,
                Contact.Account.BillingPostalCode,
                Contact.Account.BillingCountry
            FROM User
            WHERE Id = :UserInfo.getUserId()
            LIMIT 1
        ];

        if (currentUser.ContactId == null ||
            currentUser.Contact.AccountId == null) {

            throw new AuraHandledException(
                'Your dealer account is not properly configured.'
            );
        }

        DealerDashboardData data = new DealerDashboardData();

        data.contactId = currentUser.ContactId;
        data.accountId = currentUser.Contact.AccountId;

        data.firstName = currentUser.Contact.FirstName;
        data.lastName = currentUser.Contact.LastName;
        data.email = currentUser.Contact.Email;
        data.phone = currentUser.Contact.Phone;

        data.accountName =
            currentUser.Contact.Account.Name;

        data.accountPhone =
            currentUser.Contact.Account.Phone;

        data.billingStreet =
            currentUser.Contact.Account.BillingStreet;

        data.billingCity =
            currentUser.Contact.Account.BillingCity;

        data.billingState =
            currentUser.Contact.Account.BillingState;

        data.billingPostalCode =
            currentUser.Contact.Account.BillingPostalCode;

        data.billingCountry =
            currentUser.Contact.Account.BillingCountry;

        return data;
    }

    public class DealerDashboardData {

        @AuraEnabled
        public Id contactId;

        @AuraEnabled
        public Id accountId;

        @AuraEnabled
        public String firstName;

        @AuraEnabled
        public String lastName;

        @AuraEnabled
        public String email;

        @AuraEnabled
        public String phone;

        @AuraEnabled
        public String accountName;

        @AuraEnabled
        public String accountPhone;

        @AuraEnabled
        public String billingStreet;

        @AuraEnabled
        public String billingCity;

        @AuraEnabled
        public String billingState;

        @AuraEnabled
        public String billingPostalCode;

        @AuraEnabled
        public String billingCountry;
    }
}
